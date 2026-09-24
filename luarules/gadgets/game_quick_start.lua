function gadget:GetInfo()
	return {
		name = "Quick Start v2",
		desc = "Instantly builds structures using starting resources until they are expended",
		author = "SethDGamre",
		date = "July 2025",
		license = "GPLv2",
		layer = 0,
		enabled = true,
	}
end

local isSynced = gadgetHandler:IsSyncedCode()
local modOptions = Spring.GetModOptions()

if not isSynced then
	return false
end
local quickStart = VFS.Include("common/quick_start_shared.lua")
local shouldRunGadget, _, shouldApplyFactoryDiscount = quickStart.getModeFlags(modOptions)
if not shouldRunGadget then
	return false
end

---@type boolean
local overridesEnabled = modOptions.enable_quickstart_overrides and true or false
local overrideQuickStartBudget = overridesEnabled and tonumber(modOptions.override_quick_start_budget)

local FACTORY_DISCOUNT_MULTIPLIER = 0.90 -- The factory discount will be the budget cost of the cheapest listed factory multiplied by this value.

local QUICK_START_COST_ENERGY = 400 --will be deducted from commander's energy upon start.
local QUICK_START_COST_METAL = 800 --will be deducted from commander's metal upon start.
local READY_REFUNDABLE_BUDGET = 800 -- Budget threshold when players are allowed to "ready" the game

local MIN_OVERRIDE_BUILD_RANGE = 200

local selectedConfig = quickStart.getAmountConfig(modOptions)
local BUDGET = overrideQuickStartBudget or selectedConfig.budget
local overrideQuickStartRange = nil
if overridesEnabled then
	local overrideRangeValue = tonumber(modOptions.override_quick_start_range) or 0
	if overrideRangeValue > 0 then
		overrideQuickStartRange = math.max(overrideRangeValue, MIN_OVERRIDE_BUILD_RANGE)
	end
end
local INSTANT_BUILD_RANGE = overrideQuickStartRange or selectedConfig.range
local BASE_GENERATION_RANGE = selectedConfig.baseGenerationRange
local TRAVERSABILITY_GRID_GENERATION_RANGE = selectedConfig.traversabilityGridRange

local aestheticCustomCostRound = VFS.Include("common/aestheticCustomCostRound.lua")
local customRound = aestheticCustomCostRound.customRound
local windFunctions = VFS.Include("common/wind_functions.lua")

-------------------------------------------------------------------------

local ALL_COMMANDS = -1
local UNOCCUPIED = quickStart.UNOCCUPIED
local FACTORY_DISCOUNT = math.huge
local PREGAME_DELAY_FRAMES = 61 --after gui_pregame_build.lua is loaded
local UPDATE_FRAMES = Game.gameSpeed
local SAFETY_COUNT = quickStart.SAFETY_COUNT
local BUILT_ENOUGH_FOR_FULL = 0.9
local DEFAULT_FACING = quickStart.DEFAULT_FACING
local INITIAL_BUILD_PROGRESS = 0.01
local TRAVERSABILITY_GRID_RESOLUTION = quickStart.TRAVERSABILITY_GRID_RESOLUTION
local GRID_CHECK_RESOLUTION_MULTIPLIER = quickStart.GRID_CHECK_RESOLUTION_MULTIPLIER

local spCreateUnit = Spring.CreateUnit
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spPos2BuildPos = Spring.Pos2BuildPos
local spTestBuildOrder = Spring.TestBuildOrder
local spSetUnitHealth = Spring.SetUnitHealth
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitHealth = Spring.GetUnitHealth
local random = math.random
local ceil = math.ceil
local max = math.max
local min = math.min

local config = quickStart.config
local traversabilityGrid = VFS.Include("common/traversability_grid.lua")
local overlapLines = VFS.Include("common/overlap_lines.lua")
local commanderNonLabOptions = config.commanderNonLabOptions
---@type table<integer, UnitDef>
local unitDefs = UnitDefs
---@type table<string, UnitDef?>
local unitDefNames = UnitDefNames

-- factories carrying customparams.quickstart_discountable earn the quick-start factory
-- discount; scav copies are excluded so their altered costs can't lower FACTORY_DISCOUNT
local discountableFactories = {}
for unitDefID, unitDef in pairs(unitDefs) do
	if unitDef.isFactory and unitDef.customParams.quickstart_discountable and not unitDef.customParams.isscavenger then
		discountableFactories[unitDefID] = true
	end
end

local gameFrameTryCount = 0
local initialized = false
local isGoodWind = false
local isMetalMap = false
local metalSpotsList = nil
local running = false

---@type integer[]
local allTeamsList = {}
---@type table<integer, boolean>
local boostableCommanders = {}
---@type table<integer, table>
local commanders = {}
---@type table<integer, number>
local defMetergies = {}
---@type table<integer, boolean>
local commanderFactoryDiscounts = {}
---@type table<any, any>
local optionDefIDToTypes = {}
---@type table<any, any>
local queuedCommanders = {}
---@type table<integer, table>
local buildsInProgress = {}

GG.quick_start = {}

---Moves tracked state from one commander unit to another.
---@param oldUnitID UnitID?
---@param newUnitID UnitID?
function GG.quick_start.transferCommanderData(oldUnitID, newUnitID)
	if oldUnitID and newUnitID and spValidUnitID(oldUnitID) and spValidUnitID(newUnitID) then
		buildsInProgress[newUnitID] = buildsInProgress[oldUnitID]
		buildsInProgress[oldUnitID] = nil

		commanders[newUnitID] = commanders[oldUnitID]
		commanders[oldUnitID] = nil

		commanderFactoryDiscounts[newUnitID] = commanderFactoryDiscounts[oldUnitID]
		commanderFactoryDiscounts[oldUnitID] = nil
	end
end

for unitDefID, unitDef in pairs(unitDefs) do
	defMetergies[unitDefID] = quickStart.calculateBudgetCost(unitDef.metalCost, unitDef.energyCost, unitDef.buildTime)
	if unitDef.customParams and unitDef.customParams.iscommander then
		boostableCommanders[unitDefID] = true
	end
end
for unitDefID, _ in pairs(discountableFactories) do
	local labBudget = defMetergies[unitDefID] or 0
	FACTORY_DISCOUNT = min(FACTORY_DISCOUNT, customRound(labBudget * FACTORY_DISCOUNT_MULTIPLIER))
end
for commanderName, nonLabOptions in pairs(commanderNonLabOptions) do
	if unitDefNames[commanderName] then
		for optionName, trueName in pairs(nonLabOptions) do
			local namedDef = unitDefNames[trueName]
			if namedDef then
				optionDefIDToTypes[namedDef.id] = optionName
			end
		end
	end
end

local function calculateCheapestEconomicStructure()
	local cheapestCost = math.huge
	local uniqueUnitNames = {}

	for commanderName, nonLabOptions in pairs(commanderNonLabOptions) do
		for optionName, unitName in pairs(nonLabOptions) do
			uniqueUnitNames[unitName] = true
		end
	end

	for unitName, _ in pairs(uniqueUnitNames) do
		if unitDefNames[unitName] then
			local unitDefID = unitDefNames[unitName].id
			local budgetCost = defMetergies[unitDefID] or math.huge
			if budgetCost < cheapestCost then
				cheapestCost = budgetCost
			end
		end
	end

	return cheapestCost == math.huge and 0 or cheapestCost
end

local function isBuildCommand(cmdID)
	return cmdID < 0
end

local function getFactoryDiscount(unitDef, builderID)
	if not shouldApplyFactoryDiscount then
		return 0
	end
	if not unitDef or not unitDef.isFactory then
		return 0
	end
	if commanderFactoryDiscounts[builderID] and commanderFactoryDiscounts[builderID] == true then
		return 0
	end
	return FACTORY_DISCOUNT
end

local function queueBuildForProgression(unitID, unitDef, affordableBudget, fullBudgetCost)
	local targetProgress = affordableBudget / fullBudgetCost
	if targetProgress > BUILT_ENOUGH_FOR_FULL then --to account for tiny, necessary inaccuracy between widget and gadget
		targetProgress = 1
	end
	local rate = random() * 0.005 + 0.012 --roughly 2 seconds, staggered to produce more pleasing build progress effects
	spSetUnitHealth(unitID, { build = INITIAL_BUILD_PROGRESS, health = ceil(unitDef.health * INITIAL_BUILD_PROGRESS) })
	buildsInProgress[unitID] = {
		targetProgress = targetProgress,
		addedProgress = INITIAL_BUILD_PROGRESS,
		maxHealth = unitDef.health,
		rate = rate,
	}
	return targetProgress
end

local function generateOverlapLines(commanderID)
	local comData = commanders[commanderID]
	if not comData then
		return
	end

	local neighbors = {}
	for _, otherTeamID in ipairs(allTeamsList) do
		if otherTeamID ~= comData.teamID and Spring.AreTeamsAllied(comData.teamID, otherTeamID) then
			local sx, sy, sz = Spring.GetTeamStartPosition(otherTeamID)
			if sx and sx >= 0 then -- Check for valid start pos (allow 0, ignore -100)
				table.insert(neighbors, { x = sx, z = sz })
			end
		end
	end

	comData.overlapLines = overlapLines.getOverlapLines(comData.spawnX, comData.spawnZ, neighbors, INSTANT_BUILD_RANGE)
end

---@class QuickStartSpawnParams
---@field id integer
---@field x number?
---@field y number?
---@field z number?
---@field facing integer
---@field cmdTag any

---@return QuickStartSpawnParams[]
local function getCommanderBuildQueue(commanderID)
	---@type QuickStartSpawnParams[]
	local spawnQueue = {}
	local commandsToRemove = {}
	local comData = commanders[commanderID]
	if not comData then
		return spawnQueue
	end
	local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
	local totalBudgetCost = 0.0
	local discountUsedLocal = commanderFactoryDiscounts[commanderID]

	if not comData.overlapLines then
		generateOverlapLines(commanderID)
	end

	for _, cmd in ipairs(commands or {}) do
		if isBuildCommand(cmd.id) then
			local unitDefID = -cmd.id
			local cmdParams = cmd.params
			local unitDef = unitDefs[unitDefID]
			if cmdParams and unitDef then
				local spawnParams = {
					id = unitDefID,
					x = cmdParams[1],
					y = cmdParams[2],
					z = cmdParams[3],
					facing = cmdParams[4] or 0,
					cmdTag = cmd.tag,
				}
				local isWithinBuildRange = quickStart.isWithinInstantBuildRange(
					comData.spawnX,
					comData.spawnZ,
					spawnParams.x,
					spawnParams.z,
					INSTANT_BUILD_RANGE,
					comData.overlapLines,
					function(buildX, buildZ)
						return traversabilityGrid.canMoveToPosition(
							commanderID,
							buildX,
							buildZ,
							GRID_CHECK_RESOLUTION_MULTIPLIER
						)
					end
				)

				if isWithinBuildRange then
					local budgetCost = defMetergies[unitDefID] or 0

					local currentDiscount = 0.0
					if shouldApplyFactoryDiscount and unitDef.isFactory and not discountUsedLocal then
						currentDiscount = FACTORY_DISCOUNT
					end

					budgetCost = quickStart.applyFactoryDiscount(budgetCost, unitDef.isFactory, currentDiscount, true)

					if currentDiscount > 0 then
						discountUsedLocal = true
					end

					table.insert(spawnQueue, spawnParams)
					comData.hasBuildsIntercepted = true

					totalBudgetCost = totalBudgetCost + budgetCost
					if totalBudgetCost > comData.budget then
						comData.commandsToRemove = commandsToRemove
						return spawnQueue
					end

					if cmd.tag then
						table.insert(commandsToRemove, cmd.tag)
					end
				end
			end
		end
	end
	comData.commandsToRemove = commandsToRemove
	return spawnQueue
end

local function refreshAndCheckAvailableMexSpots(commanderID)
	local comData = commanders[commanderID]
	if not comData or isMetalMap then
		return
	end

	if not comData.nearbyMexes or #comData.nearbyMexes == 0 then
		return false
	end

	local validSpots = {}
	local mexDefID = comData.buildDefs.mex
	if mexDefID then
		for i = 1, #comData.nearbyMexes do
			local spot = comData.nearbyMexes[i]
			local groundY = spGetGroundHeight(spot.x, spot.z)
			local buildX, buildY, buildZ = spPos2BuildPos(mexDefID, spot.x, groundY, spot.z)
			if buildX and spTestBuildOrder(mexDefID, buildX, buildY, buildZ, DEFAULT_FACING) == UNOCCUPIED then
				spot.x, spot.y, spot.z = buildX, buildY, buildZ
				table.insert(validSpots, spot)
			end
		end
	end

	comData.nearbyMexes = validSpots
	return #validSpots > 0
end

local function getBuildSpace(commanderID, option)
	local comData = commanders[commanderID]
	if not comData then
		return nil, nil, nil
	end
	return quickStart.getBuildSpace(
		{
			buildDefs = comData.buildDefs,
			defaultFacing = DEFAULT_FACING,
			gridLists = comData.gridLists,
			isMetalMap = isMetalMap,
			nearbyMexes = comData.nearbyMexes,
		},
		option,
		function(unitDefID, buildX, buildY, buildZ, facing)
			return spTestBuildOrder(unitDefID, buildX, buildY, buildZ, facing) == UNOCCUPIED
		end
	)
end

local function populateNearbyMexes(commanderID)
	local comData = commanders[commanderID]
	if isMetalMap or not metalSpotsList then
		comData.nearbyMexes = {}
		return
	end

	if not comData.overlapLines then
		generateOverlapLines(commanderID)
	end

	comData.nearbyMexes = quickStart.getNearbyMexes(
		comData.spawnX,
		comData.spawnZ,
		INSTANT_BUILD_RANGE,
		metalSpotsList,
		comData.overlapLines,
		function(buildX, buildZ)
			return traversabilityGrid.canMoveToPosition(commanderID, buildX, buildZ, GRID_CHECK_RESOLUTION_MULTIPLIER)
		end
	)
end

local function initializeCommander(commanderID, teamID)
	if not spValidUnitID(commanderID) then
		return
	end

	if shouldApplyFactoryDiscount then
		commanderFactoryDiscounts[commanderID] = false
		if modOptions.quick_start == "factory_discount_only" then
			return
		end
	end

	local currentMetal = Spring.GetTeamResources(teamID, "metal") or 0
	local currentEnergy = Spring.GetTeamResources(teamID, "energy") or 0

	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	if not commanderX or not commanderY or not commanderZ then
		return
	end
	local defaultFacing = quickStart.getDefaultFacing(commanderX, commanderZ)

	local commanderDefID = Spring.GetUnitDefID(commanderID)
	local commanderName = UnitDefs[commanderDefID].name
	local isInWater = commanderY < 0
	local buildDefs = quickStart.getCommanderBuildDefs(commanderName)
	if not buildDefs then
		return
	end

	local commanderBuildSequence = quickStart.getBuildSequence(isMetalMap, isInWater, isGoodWind)
	local buildIndex = 1

	commanders[commanderID] = {
		teamID = teamID,
		budget = BUDGET,
		thingsMade = {},
		defaultFacing = defaultFacing,
		isInWater = isInWater,
		buildDefs = buildDefs,
		gridLists = { other = {}, converters = {} },
		buildSequence = commanderBuildSequence,
		buildIndex = buildIndex,
		nearbyMexes = {},
		lastCommanderX = nil,
		lastCommanderZ = nil,
		unitDefID = commanderDefID,
	}

	Spring.SetTeamResource(teamID, "metal", max(0, currentMetal - QUICK_START_COST_METAL))
	Spring.SetTeamResource(teamID, "energy", max(0, currentEnergy - QUICK_START_COST_ENERGY))

	local comData = commanders[commanderID]
	comData.spawnX, comData.spawnY, comData.spawnZ = spGetUnitPosition(commanderID)

	if comData.lastCommanderX ~= comData.spawnX or comData.lastCommanderZ ~= comData.spawnZ then
		traversabilityGrid.generateTraversableGrid(
			comData.spawnX,
			comData.spawnZ,
			TRAVERSABILITY_GRID_GENERATION_RANGE,
			TRAVERSABILITY_GRID_RESOLUTION,
			commanderID
		)
		comData.lastCommanderX = comData.spawnX
		comData.lastCommanderZ = comData.spawnZ
	end

	populateNearbyMexes(commanderID)
	local spawnQueue = getCommanderBuildQueue(commanderID)
	comData.spawnQueue = spawnQueue

	for buildIndex = #spawnQueue, 1, -1 do
		local build = spawnQueue[buildIndex]
		local isWithinBuildRange = quickStart.isWithinInstantBuildRange(
			comData.spawnX,
			comData.spawnZ,
			build.x,
			build.z,
			INSTANT_BUILD_RANGE,
			comData.overlapLines,
			function(buildX, buildZ)
				return traversabilityGrid.canMoveToPosition(
					commanderID,
					buildX,
					buildZ,
					GRID_CHECK_RESOLUTION_MULTIPLIER
				)
			end
		)
		if not isWithinBuildRange then
			table.remove(spawnQueue, buildIndex)
		end
	end
	local placementContext = {
		baseGenerationRange = BASE_GENERATION_RANGE,
		buildDefID = comData.isInWater and comData.buildDefs.tidal or comData.buildDefs.windmill,
		canMoveToPosition = function(buildX, buildZ)
			return traversabilityGrid.canMoveToPosition(commanderID, buildX, buildZ, GRID_CHECK_RESOLUTION_MULTIPLIER)
		end,
		commanderX = comData.spawnX,
		commanderY = comData.spawnY,
		commanderZ = comData.spawnZ,
		defaultFacing = DEFAULT_FACING,
		nearbyMexes = comData.nearbyMexes,
		overlapLines = comData.overlapLines,
	}
	local localGrid = quickStart.generateLocalGrid(placementContext)
	comData.baseNodes = quickStart.generateBaseNodesFromLocalGrid(placementContext, localGrid)
	comData.gridLists.other = comData.baseNodes.other
	comData.gridLists.converters = comData.baseNodes.converters
end

local function generateBuildCommands(commanderID)
	local comData = commanders[commanderID]
	local budgetRemaining = comData.budget
	local attempts = 0

	while budgetRemaining > 0 and attempts < SAFETY_COUNT and comData.buildIndex <= #comData.buildSequence do
		attempts = attempts + 1
		local buildType = comData.buildSequence[comData.buildIndex]
		local unitDefID = comData.buildDefs[buildType]
		local unitDef = unitDefs[unitDefID]
		local discount = getFactoryDiscount(unitDef, commanderID)
		local cost = defMetergies[unitDefID] - discount
		local shouldQueue = true

		if (buildType == "mex" and not isMetalMap) and not refreshAndCheckAvailableMexSpots(commanderID) then
			shouldQueue = false
		elseif
			comData.hasBuildsIntercepted and budgetRemaining <= READY_REFUNDABLE_BUDGET or cost > budgetRemaining
		then
			shouldQueue = false
			local refundAmount = budgetRemaining
			Spring.AddTeamResource(comData.teamID, "metal", refundAmount)
			comData.budget = comData.budget - budgetRemaining
			break
		end

		if shouldQueue then
			table.insert(comData.spawnQueue, 1, { id = unitDefID })
			if cost <= budgetRemaining then
				budgetRemaining = budgetRemaining - cost
			else
				budgetRemaining = 0
			end
		end

		comData.buildIndex = comData.buildIndex + 1
		if comData.buildIndex > #comData.buildSequence then
			comData.buildIndex = 1
		end
	end
end

local function removeCommanderCommands(commanderID)
	local comData = commanders[commanderID]
	if comData and comData.commandsToRemove and #comData.commandsToRemove > 0 then
		for _, cmdTag in ipairs(comData.commandsToRemove) do
			Spring.GiveOrderToUnit(commanderID, CMD.REMOVE, { cmdTag }, {})
		end
		comData.commandsToRemove = {}
	end
end

local function tryToSpawnBuild(commanderID, unitDefID, buildX, buildY, buildZ, facing)
	local unitDef, comData = unitDefs[unitDefID], commanders[commanderID]
	if not unitDef or not comData or not unitDef.name then
		return false, nil
	end
	local discount = getFactoryDiscount(unitDef, commanderID)
	local cost = defMetergies[unitDefID] - discount

	local unitID = spCreateUnit(unitDef.name, buildX, buildY, buildZ, facing, comData.teamID)
	if not unitID then
		return false, nil
	end

	local affordableCost = min(comData.budget, cost)
	local projectedBuildProgress = queueBuildForProgression(unitID, unitDef, affordableCost, cost)
	comData.budget = comData.budget - affordableCost

	if discountableFactories[unitDefID] and discount > 0 then
		commanderFactoryDiscounts[commanderID] = true
	end

	local buildType = optionDefIDToTypes[unitDefID]
	if buildType then
		comData.thingsMade[buildType] = (comData.thingsMade[buildType] or 0) + 1
	end

	if projectedBuildProgress < 1 then
		Spring.GiveOrderToUnit(commanderID, CMD.INSERT, { 0, CMD.REPAIR, CMD.OPT_SHIFT, unitID }, CMD.OPT_ALT)
	end

	return projectedBuildProgress >= 1
end

function gadget:GameFrame(frame)
	if not initialized and frame > PREGAME_DELAY_FRAMES then
		if #allTeamsList == 0 then
			allTeamsList = Spring.GetTeamList() or allTeamsList
		end

		local modulo = frame % #allTeamsList
		local teamID = allTeamsList[modulo + 1]
		local commanderID = queuedCommanders[teamID]

		if commanderID then
			initializeCommander(commanderID, teamID)
			queuedCommanders[teamID] = nil
		end

		local allInitialized = next(queuedCommanders) == nil

		if allInitialized then
			initialized = true
			running = true
		end
	end

	while running and frame > PREGAME_DELAY_FRAMES + 1 do
		gameFrameTryCount = gameFrameTryCount + 1
		if gameFrameTryCount > SAFETY_COUNT then
			running = false
			break
		end
		local loop = modOptions.quick_start ~= "factory_discount_only"
		while loop do
			loop = false
			for commanderID, comData in pairs(commanders) do
				if comData.spawnQueue then
					for _, buildItem in ipairs(comData.spawnQueue) do
						local buildType = optionDefIDToTypes[buildItem.id]
						local buildX, buildY, buildZ = buildItem.x, buildItem.y, buildItem.z
						if not buildX or not buildZ or not buildY then
							buildX, buildY, buildZ = getBuildSpace(commanderID, buildType)
						end
						local facing = buildItem.facing or comData.defaultFacing or 0
						if buildItem.id and buildX and comData.budget > 0 then
							local success = tryToSpawnBuild(commanderID, buildItem.id, buildX, buildY, buildZ, facing)
							if success then
								loop = true
							end
						end
					end
				end
				comData.spawnQueue = {}
				removeCommanderCommands(commanderID)
			end
		end
		local allQueuesEmpty = true
		for commanderID, comData in pairs(commanders) do
			if comData.budget > 0 then
				generateBuildCommands(commanderID)
			end
			if comData.spawnQueue and #comData.spawnQueue > 0 then
				allQueuesEmpty = false
			end
		end
		if allQueuesEmpty then
			running = false
		end
	end

	local allBuildsCompleted = true
	for unitID, buildData in pairs(buildsInProgress) do
		allBuildsCompleted = false
		if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
			buildsInProgress[unitID] = nil
		elseif buildData.addedProgress >= buildData.targetProgress then
			local buildProgress = select(5, spGetUnitHealth(unitID)) or 0
			if buildProgress >= 1 then
				-- due to some kind of glitch related to incrimentally increasing build progress to 1, we gotta cycle mexes off and on to get them to actually extract metal.
				Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 0 }, 0)
				Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 1 }, 0)
				buildsInProgress[unitID] = nil
			end
		elseif buildData.targetProgress > buildData.addedProgress then
			buildData.addedProgress = buildData.addedProgress + buildData.rate
			spSetUnitHealth(
				unitID,
				{ build = buildData.addedProgress, health = ceil(buildData.maxHealth * buildData.addedProgress) }
			)
		end
	end

	local allDiscountsUsed = false
	if frame % UPDATE_FRAMES == 0 then
		allDiscountsUsed = true
		for commanderID, used in pairs(commanderFactoryDiscounts) do
			if not used then
				allDiscountsUsed = false
				break
			end
		end
	end
	if initialized and allDiscountsUsed and not running and allBuildsCompleted then
		for commanderID, comData in pairs(commanders) do
			if comData.budget and comData.budget > 0 then
				Spring.AddTeamResource(comData.teamID, "metal", comData.budget)
			end
		end
		gadgetHandler:RemoveGadget()
	end
end

function gadget:UnitDestroyed(unitID)
	commanders[unitID] = nil
	commanderFactoryDiscounts[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if boostableCommanders[unitDefID] and not commanders[unitID] then
		queuedCommanders[unitTeam] = unitID
	end

	local unitDef = unitDefs[unitDefID]
	local discount = not Spring.GetTeamRulesParam(unitTeam, "quickStartFactoryDiscountUsed")
			and getFactoryDiscount(unitDef, builderID)
		or 0
	if discount > 0 and builderID then
		commanderFactoryDiscounts[builderID] = true
		Spring.SetTeamRulesParam(unitTeam, "quickStartFactoryDiscountUsed", 1)

		local fullBudgetCost = defMetergies[unitDefID]
		queueBuildForProgression(unitID, unitDef, discount, fullBudgetCost)
	end
end

function gadget:Initialize()
	local teamList = Spring.GetTeamList() or {}
	for _, teamID in ipairs(teamList) do
		Spring.SetTeamRulesParam(teamID, "quickStartFactoryDiscountUsed", nil)
	end
	isGoodWind = windFunctions.isGoodWind()
	isMetalMap = GG and GG.resource_spot_finder and GG.resource_spot_finder.isMetalMap
	metalSpotsList = GG and GG.resource_spot_finder and GG.resource_spot_finder.metalSpotsList

	local frame = Spring.GetGameFrame()
	Spring.SetGameRulesParam("quickStartBudgetBase", BUDGET)
	Spring.SetGameRulesParam("quickStartFactoryDiscountAmount", FACTORY_DISCOUNT)
	Spring.SetGameRulesParam("quickStartMetalDeduction", QUICK_START_COST_METAL)
	Spring.SetGameRulesParam("quickStartTraversabilityGridRange", TRAVERSABILITY_GRID_GENERATION_RANGE)
	local cheapestEconomicCost = calculateCheapestEconomicStructure()
	local anyCommanderHasBuildsIntercepted = false
	for commanderID, comData in pairs(commanders) do
		if comData.hasBuildsIntercepted then
			anyCommanderHasBuildsIntercepted = true
			break
		end
	end
	local budgetThresholdToAllowStart = not anyCommanderHasBuildsIntercepted and READY_REFUNDABLE_BUDGET
		or cheapestEconomicCost
	Spring.SetGameRulesParam("quickStartBudgetThresholdToAllowStart", budgetThresholdToAllowStart)
	if modOptions.quick_start ~= "factory_discount_only" then
		Spring.SetGameRulesParam("overridePregameBuildDistance", INSTANT_BUILD_RANGE)
	end

	if frame > 1 then
		local allUnits = Spring.GetAllUnits()
		for _, unitID in ipairs(allUnits) do
			local unitDefinitionID = spGetUnitDefID(unitID)
			local unitTeam = spGetUnitTeam(unitID)
			if boostableCommanders[unitDefinitionID] then
				initializeCommander(unitID, unitTeam)
				queuedCommanders[unitTeam] = nil
			end
		end
	end
end
