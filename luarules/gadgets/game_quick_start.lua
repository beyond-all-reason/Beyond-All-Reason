function gadget:GetInfo()
	return {
		name = "Quick Start v2",
		desc = "Instantly builds structures using starting resources until they are expended",
		author = "SethDGamre",
		date = "July 2025",
		license = "GPLv2",
		layer = 0,
		enabled = true
	}
end

local isSynced = gadgetHandler:IsSyncedCode()
local modOptions = Spring.GetModOptions()

if not isSynced then return false end
local shouldRunGadget = modOptions and modOptions.quick_start and (
	modOptions.quick_start == "enabled" or
	modOptions.quick_start == "factory_discount" or
	modOptions.quick_start == "factory_discount_only" or
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))
)
if not shouldRunGadget then return false end

local shouldApplyFactoryDiscount = modOptions.quick_start == "factory_discount" or 
	modOptions.quick_start == "factory_discount_only" or
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))


----------------------------Configuration----------------------------------------
local FACTORY_DISCOUNT_MULTIPLIER = 0.90 -- The factory discount will be the budget cost of the cheapest listed factory multiplied by this value.

-- how far things will be be instantly built for the commander.
local INSTANT_BUILD_RANGE = modOptions.override_quick_start_range > 0 and modOptions.override_quick_start_range or 600

local QUICK_START_COST_ENERGY = 400      --will be deducted from commander's energy upon start.
local QUICK_START_COST_METAL = 800       --will be deducted from commander's metal upon start.
local quickStartAmountConfig = {
	small = 800,
	normal = 1200,
	large = 2400,
}

local BUILD_TIME_VALUE_CONVERSION_MULTIPLIER = 1/300 --300 being a representative of commander workertime, statically defined so future com unitdef adjustments don't change this.
local ENERGY_VALUE_CONVERSION_MULTIPLIER = 1/60 --60 being the energy conversion rate of t2 energy converters, statically defined so future changes not to affect this.
local aestheticCustomCostRound = VFS.Include('common/aestheticCustomCostRound.lua')
local customRound = aestheticCustomCostRound.customRound
local windFunctions = VFS.Include('common/wind_functions.lua')

-------------------------------------------------------------------------

local ALL_COMMANDS = -1
local UNOCCUPIED = 2
local BUILD_SPACING = 64
local COMMANDER_NO_GO_DISTANCE = 100
local CONVERTER_GRID_DISTANCE = 200
local BASE_GENERATION_RANGE = 500
local FACTORY_DISCOUNT = math.huge
local MAP_CENTER_X = Game.mapSizeX / 2
local MAP_CENTER_Z = Game.mapSizeZ / 2
local NODE_GRID_SORT_DISTANCE = 300
local PREGAME_DELAY_FRAMES = 61 --after gui_pregame_build.lua is loaded
local SKIP_STEP = 3
local UPDATE_FRAMES = Game.gameSpeed
local BASE_NODE_COUNT = 8
local MEX_OVERLAP_DISTANCE = Game.extractorRadius + Game.metalMapSquareSize
local SAFETY_COUNT = 100
local BUILT_ENOUGH_FOR_FULL = 0.9
local MAX_HEIGHT_DIFFERENCE = 100
local DEFAULT_FACING = 0
local INITIAL_BUILD_PROGRESS = 0.01
local TRAVERSABILITY_GRID_GENERATION_RANGE = 576 --must match the value in gui_quick_start.lua. It has to be slightly larger than the instant build range to account for traversability_grid snapping at TRAVERSABILITY_GRID_RESOLUTION intervals
local TRAVERSABILITY_GRID_RESOLUTION = 32
local GRID_CHECK_RESOLUTION_MULTIPLIER = 1

local spCreateUnit = Spring.CreateUnit
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spPos2BuildPos = Spring.Pos2BuildPos
local spTestBuildOrder = Spring.TestBuildOrder
local spSetUnitHealth = Spring.SetUnitHealth
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitHealth = Spring.GetUnitHealth
local spTestMoveOrder = Spring.TestMoveOrder
local random = math.random
local ceil = math.ceil
local max = math.max
local clamp = math.clamp
local abs = math.abs
local distance2d = math.distance2d
local floor = math.floor
local pi = math.pi
local min = math.min
local atan2 = math.atan2
local sin = math.sin
local cos = math.cos

local config = VFS.Include('LuaRules/Configs/quick_start_build_defs.lua')
local traversabilityGrid = VFS.Include('common/traversability_grid.lua')
local commanderNonLabOptions = config.commanderNonLabOptions
local discountableFactories = config.discountableFactories
local optionsToNodeType = config.optionsToNodeType
local unitDefs = UnitDefs
local unitDefNames = UnitDefNames

local gameFrameTryCount = 0
local initialized = false
local isGoodWind = false
local isMetalMap = false
local metalSpotsList = nil
local running = false

local allTeamsList = {}
local boostableCommanders = {}
local commanders = {}
local defMetergies = {}
local commanderFactoryDiscounts = {}
local mexDefs = {}
local optionDefIDToTypes = {}
local queuedCommanders = {}
local buildsInProgress = {}

GG.quick_start = {}

function GG.quick_start.transferCommanderData(oldUnitID, newUnitID)
	if oldUnitID and newUnitID  and spValidUnitID(oldUnitID) and spValidUnitID(newUnitID) then
		buildsInProgress[newUnitID] = buildsInProgress[oldUnitID]
		buildsInProgress[oldUnitID] = nil

		commanders[newUnitID] = commanders[oldUnitID]
		commanders[oldUnitID] = nil

		commanderFactoryDiscounts[newUnitID] = commanderFactoryDiscounts[oldUnitID]
		commanderFactoryDiscounts[oldUnitID] = nil
	end
end

local function getBuildSequence(isMetalMap, isInWater, isGoodWind)
	return config.buildSequence[isMetalMap and "metalMap" or "nonMetalMap"][isInWater and "water" or "land"]
	[isGoodWind and "goodWind" or "badWind"]
end

local function generateLocalGrid(commanderID)
	local comData = commanders[commanderID]
	local originX, originY, originZ = comData.spawnX, comData.spawnY, comData.spawnZ
	local buildDefID = comData.isInWater and (comData.buildDefs and comData.buildDefs.tidal) or
	(comData.buildDefs and comData.buildDefs.windmill)
	if not buildDefID then
		return {}
	end
	local dx = MAP_CENTER_X - originX
	local dz = MAP_CENTER_Z - originZ
	local skipDirection = abs(dx) >= abs(dz) and "x" or "z"
	local maxOffset = BASE_GENERATION_RANGE
	local gridList = {}
	local used = {}
	local noGoZones = {}
	table.insert(noGoZones, { x = originX, z = originZ, distance = COMMANDER_NO_GO_DISTANCE })
	if comData.nearbyMexes then
		for i = 1, #comData.nearbyMexes do
			local mex = comData.nearbyMexes[i]
			table.insert(noGoZones, { x = mex.x, z = mex.z, distance = BUILD_SPACING })
		end
	end
	for offsetX = -maxOffset, maxOffset, BUILD_SPACING do
		for offsetZ = -maxOffset, maxOffset, BUILD_SPACING do
			local index = (skipDirection == "x" and offsetZ or offsetX) + maxOffset
			if (index / BUILD_SPACING) % SKIP_STEP ~= 0 then
				local testX = originX + offsetX
				local testZ = originZ + offsetZ
				if distance2d(testX, testZ, originX, originZ) <= BASE_GENERATION_RANGE then
					local tooClose = false
					for i = 1, #noGoZones do
						local g = noGoZones[i]
						if distance2d(testX, testZ, g.x, g.z) <= g.distance then
							tooClose = true
							break
						end
					end
					if not tooClose then
						local searchY = spGetGroundHeight(testX, testZ)
						local heightDiff = abs(searchY - originY)
						if heightDiff <= MAX_HEIGHT_DIFFERENCE then
							local snappedX, snappedY, snappedZ = spPos2BuildPos(buildDefID, testX, searchY, testZ)
							if snappedX and spTestBuildOrder(buildDefID, snappedX, snappedY, snappedZ, DEFAULT_FACING) == UNOCCUPIED then
								local isTraversable = traversabilityGrid.canMoveToPosition(commanderID, snappedX, snappedZ, GRID_CHECK_RESOLUTION_MULTIPLIER) or false
								if isTraversable then
									local key = snappedX .. "_" .. snappedZ
									if not used[key] then
										used[key] = true
										table.insert(gridList, { x = snappedX, y = snappedY, z = snappedZ })
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return gridList
end

for unitDefID, unitDef in pairs(unitDefs) do
	local metalCost, energyCost = unitDef.metalCost or 0, unitDef.energyCost or 0
	defMetergies[unitDefID] = customRound(metalCost + energyCost * ENERGY_VALUE_CONVERSION_MULTIPLIER + unitDef.buildTime * BUILD_TIME_VALUE_CONVERSION_MULTIPLIER)
	if unitDef.extractsMetal > 0 then
		mexDefs[unitDefID] = true
	end
	if unitDef.customParams and unitDef.customParams.iscommander then
		boostableCommanders[unitDefID] = true
	end
end
for name, _ in pairs(discountableFactories) do
	if unitDefNames[name] then
		local labBudget = defMetergies[unitDefNames[name].id]
		FACTORY_DISCOUNT = min(FACTORY_DISCOUNT, customRound(labBudget * FACTORY_DISCOUNT_MULTIPLIER))
	end
end
for commanderName, nonLabOptions in pairs(commanderNonLabOptions) do
	if unitDefNames[commanderName] then
		for optionName, trueName in pairs(nonLabOptions) do
			optionDefIDToTypes[unitDefNames[trueName].id] = optionName
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
	if not shouldApplyFactoryDiscount then return 0 end
	if not unitDef or not unitDef.isFactory then return 0 end
	if commanderFactoryDiscounts[builderID] and commanderFactoryDiscounts[builderID] == true then return 0 end
	return FACTORY_DISCOUNT
end

local function queueBuildForProgression(unitID, unitDef, affordableBudget, fullBudgetCost)
	local targetProgress = affordableBudget / fullBudgetCost
	if targetProgress > BUILT_ENOUGH_FOR_FULL then --to account for tiny, necessary inaccuracy between widget and gadget
		targetProgress = 1
	end
	local rate = random() * 0.005 + 0.012 --roughly 2 seconds, staggered to produce more pleasing build progress effects
	spSetUnitHealth(unitID, { build = INITIAL_BUILD_PROGRESS, health = ceil(unitDef.health * INITIAL_BUILD_PROGRESS) })
	buildsInProgress[unitID] = { targetProgress = targetProgress, addedProgress = INITIAL_BUILD_PROGRESS, maxHealth = unitDef.health, rate = rate }
	return targetProgress
end

local function getCommanderBuildQueue(commanderID)
	local spawnQueue = {}
	local commandsToRemove = {}
	local comData = commanders[commanderID]
	local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
	local totalBudgetCost = 0
	for i, cmd in ipairs(commands) do
		if isBuildCommand(cmd.id) then
			local unitDefID = -cmd.id
			local spawnParams = { id = unitDefID, x = cmd.params[1], y = cmd.params[2], z = cmd.params[3], facing = cmd.params[4] or 1, cmdTag = cmd.tag }
			local unitDef = unitDefs[unitDefID]
			local distance = distance2d(comData.spawnX, comData.spawnZ, spawnParams.x, spawnParams.z)
			local isTraversable = traversabilityGrid.canMoveToPosition(commanderID, spawnParams.x, spawnParams.z, GRID_CHECK_RESOLUTION_MULTIPLIER) or false

			if distance <= INSTANT_BUILD_RANGE and isTraversable then
				local budgetCost = defMetergies[unitDefID] or 0
				budgetCost = max(budgetCost - getFactoryDiscount(unitDef, commanderID), 0)

				local affordableCost = min(budgetCost, comData.budget - totalBudgetCost)
				if affordableCost > 0 then
					table.insert(spawnQueue, spawnParams)
					if cmd.tag then
						table.insert(commandsToRemove, cmd.tag)
					end
					totalBudgetCost = totalBudgetCost + affordableCost
				end

				if totalBudgetCost >= comData.budget then
					comData.commandsToRemove = commandsToRemove
					return spawnQueue
				end
			end
		end
	end
	comData.commandsToRemove = commandsToRemove
	return spawnQueue
end

local function refreshAndCheckAvailableMexSpots(commanderID)
	local comData = commanders[commanderID]
	if not comData or isMetalMap then return end

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
				local nearbyUnits = spGetUnitsInCylinder(spot.x, spot.z, MEX_OVERLAP_DISTANCE)
				local hasMex = false
				for j = 1, #nearbyUnits do
					local unitDefID = spGetUnitDefID(nearbyUnits[j])
					if mexDefs[unitDefID] then
						hasMex = true
						break
					end
				end
				if not hasMex then
					spot.y = buildY
					table.insert(validSpots, spot)
				end
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

	if option ~= "mex" or isMetalMap then
		local nodeType = optionsToNodeType[option] or "other"
		local gridList = comData.gridLists[nodeType] or {}

		while #gridList > 0 do
			local candidate = gridList[1]
			table.remove(gridList, 1)
			
			if candidate.x and candidate.y and candidate.z then
				local unitDefID = comData.buildDefs[option]
				if unitDefID then
					if spTestBuildOrder(unitDefID, candidate.x, candidate.y, candidate.z, 0) == UNOCCUPIED then
						comData.gridLists[nodeType] = gridList
						return candidate.x, candidate.y, candidate.z
					end
				else
					comData.gridLists[nodeType] = gridList
					return candidate.x, candidate.y, candidate.z
				end
			end
		end
		
		comData.gridLists[nodeType] = gridList
		return nil, nil, nil
	else
		while comData.nearbyMexes and #comData.nearbyMexes > 0 do
			local mexSpot = comData.nearbyMexes[1]
			table.remove(comData.nearbyMexes, 1)
			
			if mexSpot.x and mexSpot.y and mexSpot.z then
				local mexDefID = comData.buildDefs.mex
				if mexDefID then
					if spTestBuildOrder(mexDefID, mexSpot.x, mexSpot.y, mexSpot.z, DEFAULT_FACING) == UNOCCUPIED then
						return mexSpot.x, mexSpot.y, mexSpot.z
					end
				else
					return mexSpot.x, mexSpot.y, mexSpot.z
				end
			end
		end
		return nil, nil, nil
	end
end

local function createBaseNodes(spawnX, spawnZ)
	local nodes = {}
	local angleIncrement = 2 * pi / BASE_NODE_COUNT
	for i = 0, BASE_NODE_COUNT - 1 do
		local angle = i * angleIncrement
		local nodeX = spawnX + (BASE_GENERATION_RANGE / 2) * cos(angle)
		local nodeZ = spawnZ + (BASE_GENERATION_RANGE / 2) * sin(angle)
		nodes[i + 1] = { x = nodeX, z = nodeZ, index = i + 1, grid = {}, score = 0 }
	end
	return nodes
end

local function populateNodeGrids(nodes, localGrid)
	local totalValid = #localGrid
	for i = 1, #nodes do
		local node = nodes[i]
		for j = 1, totalValid do
			local p = localGrid[j]
			if distance2d(p.x, p.z, node.x, node.z) <= NODE_GRID_SORT_DISTANCE then
				table.insert(node.grid, { x = p.x, y = p.y, z = p.z })
			end
		end
		node.score = #node.grid
		node.distanceFromCenter = distance2d(node.x, node.z, MAP_CENTER_X, MAP_CENTER_Z)
		local MIN_GRID_THRESHOLD = 0.20
		node.goodEnough = node.score >= ceil(totalValid * MIN_GRID_THRESHOLD)
	end
end

local function generateBaseNodesFromLocalGrid(commanderID, localGrid)
	local comData = commanders[commanderID]
	local spawnX, spawnZ = comData.spawnX, comData.spawnZ
	local nodes = createBaseNodes(spawnX, spawnZ)
	populateNodeGrids(nodes, localGrid)
	
	local minDistance = math.huge
	local maxDistance = 0
	for i = 1, #nodes do
		local node = nodes[i]
		minDistance = min(minDistance, node.distanceFromCenter)
		maxDistance = max(maxDistance, node.distanceFromCenter)
	end
	
	for i = 1, #nodes do
		local node = nodes[i]
		local MIN_CENTER_WEIGHT, MAX_CENTER_WEIGHT = 0.5, 1.0
		local centerWeight = clamp(1.0 - (node.distanceFromCenter - minDistance) / (maxDistance - minDistance), MIN_CENTER_WEIGHT, MAX_CENTER_WEIGHT)
		local averageDistance = 0
		if #node.grid > 0 then
			for j = 1, #node.grid do
				averageDistance = averageDistance + distance2d(node.grid[j].x, node.grid[j].z, node.x, node.z)
			end
			averageDistance = averageDistance / #node.grid
		end
		node.resultantScore = centerWeight * averageDistance
	end
	
	local selectedPair
	local bestResultantScore = math.huge
	for i = 1, BASE_NODE_COUNT do
		local j = (i % BASE_NODE_COUNT) + 1
		if nodes[i].goodEnough and nodes[j].goodEnough then
			local combinedScore = nodes[i].resultantScore + nodes[j].resultantScore
			if combinedScore < bestResultantScore then
				bestResultantScore = combinedScore
				selectedPair = { nodes[i], nodes[j] }
			end
		end
	end
	if not selectedPair then
		return { other = { x = spawnX, z = spawnZ, grid = {} }, converters = { x = spawnX, z = spawnZ, grid = {} } }
	end
	local nodeA = selectedPair[1]
	local nodeB = selectedPair[2]
	local converterNode = nodeA.score <= nodeB.score and nodeA or nodeB
	local otherNode = converterNode == nodeA and nodeB or nodeA
	local filteredConverter = {}
	local converterKeys = {}
	for i = 1, #converterNode.grid do
		local p = converterNode.grid[i]
		if distance2d(p.x, p.z, converterNode.x, converterNode.z) <= CONVERTER_GRID_DISTANCE then
			table.insert(filteredConverter, p)
			converterKeys[p.x .. "_" .. p.z] = true
		end
	end
	
	local filteredOther = {}
	for i = 1, #localGrid do
		local p = localGrid[i]
		if not converterKeys[p.x .. "_" .. p.z] then
			table.insert(filteredOther, p)
		end
	end
	
	for i = 1, #filteredConverter do
		filteredConverter[i].d = distance2d(filteredConverter[i].x, filteredConverter[i].z, converterNode.x, converterNode.z)
	end
	for i = 1, #filteredOther do
		filteredOther[i].d = distance2d(filteredOther[i].x, filteredOther[i].z, otherNode.x, otherNode.z)
	end
	table.sort(filteredConverter, function(a, b) return a.d < b.d end)
	table.sort(filteredOther, function(a, b) return a.d < b.d end)
	return { other = { x = otherNode.x, z = otherNode.z, grid = filteredOther }, converters = { x = converterNode.x, z = converterNode.z, grid = filteredConverter } }
end

local function populateNearbyMexes(commanderID)
	local comData = commanders[commanderID]
	local commanderX, _, commanderZ = comData.spawnX, comData.spawnY, comData.spawnZ

	comData.nearbyMexes = {}
	if isMetalMap or not metalSpotsList then
		return
	end

	for i = 1, #metalSpotsList do
		local metalSpot = metalSpotsList[i]
		if metalSpot then
			local distance = distance2d(metalSpot.x, metalSpot.z, commanderX, commanderZ)
			local isTraversable = traversabilityGrid.canMoveToPosition(commanderID, metalSpot.x, metalSpot.z, GRID_CHECK_RESOLUTION_MULTIPLIER) or false
			if distance <= INSTANT_BUILD_RANGE and isTraversable then
				table.insert(comData.nearbyMexes, {
					x = metalSpot.x,
					y = metalSpot.y,
					z = metalSpot.z,
					distance = distance
				})
			end
		end
	end
	if #comData.nearbyMexes > 1 then
		table.sort(comData.nearbyMexes, function(a, b) return a.distance < b.distance end)
	end
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
	local budget = (modOptions.override_quick_start_resources and modOptions.override_quick_start_resources > 0) and modOptions.override_quick_start_resources or quickStartAmountConfig[modOptions.quick_start_amount == "default" and "normal" or modOptions.quick_start_amount]

	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	if not commanderX or not commanderY or not commanderZ then
		return
	end
	local directionX = MAP_CENTER_X - commanderX
	local directionZ = MAP_CENTER_Z - commanderZ
	local angle = atan2(directionX, directionZ)
	local defaultFacing = floor((angle / (pi / 2)) + 0.5) % 4

	local commanderDefID = Spring.GetUnitDefID(commanderID)
	local commanderName = UnitDefs[commanderDefID].name
	local isInWater = commanderY < 0
	local buildDefs = {}
	local buildOptions = commanderNonLabOptions[commanderName]
	if buildOptions then
		for optionName, trueName in pairs(commanderNonLabOptions[commanderName]) do
			buildDefs[optionName] = unitDefNames[trueName].id
		end
	else
		return
	end

	local commanderBuildSequence = getBuildSequence(isMetalMap, isInWater, isGoodWind)
	local buildIndex = 1

	commanders[commanderID] = {
		teamID = teamID,
		budget = budget,
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
		unitDefID = commanderDefID
	}

	Spring.SetTeamResource(teamID, "metal", max(0, currentMetal - QUICK_START_COST_METAL))
	Spring.SetTeamResource(teamID, "energy", max(0, currentEnergy - QUICK_START_COST_ENERGY))

	local comData = commanders[commanderID]
	comData.spawnX, comData.spawnY, comData.spawnZ = spGetUnitPosition(commanderID)

	if comData.lastCommanderX ~= comData.spawnX or comData.lastCommanderZ ~= comData.spawnZ then
		traversabilityGrid.generateTraversableGrid(comData.spawnX, comData.spawnZ, TRAVERSABILITY_GRID_GENERATION_RANGE, TRAVERSABILITY_GRID_RESOLUTION, commanderID)
		comData.lastCommanderX = comData.spawnX
		comData.lastCommanderZ = comData.spawnZ
	end

	populateNearbyMexes(commanderID)
	comData.spawnQueue = getCommanderBuildQueue(commanderID)

	for i = #comData.spawnQueue, 1, -1 do
		local build = comData.spawnQueue[i]
		local distance = distance2d(build.x, build.z, comData.spawnX, comData.spawnZ)
		local isTraversable = traversabilityGrid.canMoveToPosition(commanderID, build.x, build.z, GRID_CHECK_RESOLUTION_MULTIPLIER) or false
		if distance > INSTANT_BUILD_RANGE or not isTraversable then
			table.remove(comData.spawnQueue, i)
		end
	end
	local localGrid = generateLocalGrid(commanderID)
	comData.baseNodes = generateBaseNodesFromLocalGrid(commanderID, localGrid)
	if not comData.baseNodes then
		comData.baseNodes = { other = { x = comData.spawnX, z = comData.spawnZ, grid = {} }, converters = { x = comData.spawnX, z = comData.spawnZ, grid = {} } }
	end

	comData.gridLists.other = comData.baseNodes.other.grid or {}
	comData.gridLists.converters = comData.baseNodes.converters.grid or {}
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

		if ((buildType == "mex" and not isMetalMap) and not refreshAndCheckAvailableMexSpots(commanderID)) then
			shouldQueue = false
		elseif cost > budgetRemaining then
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
	local discount = getFactoryDiscount(unitDef, commanderID)
	local cost = defMetergies[unitDefID] - discount

	local unitID = spCreateUnit(unitDef.name, buildX, buildY, buildZ, facing, comData.teamID)
	if not unitID then
		return false, nil
	end

	local affordableCost = min(comData.budget, cost)
	local projectedBuildProgress = queueBuildForProgression(unitID, unitDef, affordableCost, cost)
	comData.budget = comData.budget - affordableCost

	if unitDef.isFactory and discountableFactories[unitDef.name] and discount > 0 then
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

local function assignMexSpots()
	local claimedSpots = {}
	local toRemove = {}
	for commanderID, comData in pairs(commanders) do
		toRemove[commanderID] = {}
		for i, buildItem in ipairs(comData.spawnQueue) do
			local buildType = optionDefIDToTypes[buildItem.id]
				if buildType == "mex" then
					local spotHash
					local mexSpot
					if buildItem.x then
						mexSpot = { x = buildItem.x, y = buildItem.y, z = buildItem.z }
						spotHash = buildItem.x .. "_" .. buildItem.z
					else
						if comData.nearbyMexes and #comData.nearbyMexes > 0 then
							mexSpot = comData.nearbyMexes[1]
							table.remove(comData.nearbyMexes, 1)
							spotHash = mexSpot.x .. "_" .. mexSpot.z
						end
					end
					if spotHash and mexSpot then
						local buildX = mexSpot.x
						local buildZ = mexSpot.z
						local distance = distance2d(buildX, buildZ, comData.spawnX, comData.spawnZ)
						if claimedSpots[spotHash] then
							if distance < claimedSpots[spotHash].distance then
								local oldClaim = claimedSpots[spotHash]

								table.insert(toRemove[oldClaim.commanderID], oldClaim.index)
								claimedSpots[spotHash] = {commanderID = commanderID, index = i, distance = distance}
								buildItem.x, buildItem.y, buildItem.z = mexSpot.x, mexSpot.y, mexSpot.z
							else
								table.insert(toRemove[commanderID], i)
							end
						else
							claimedSpots[spotHash] = {commanderID = commanderID, index = i, distance = distance}
							buildItem.x, buildItem.y, buildItem.z = mexSpot.x, mexSpot.y, mexSpot.z
						end
					else
						table.insert(toRemove[commanderID], i)
					end
			end
		end
	end

	for commanderID, indices in pairs(toRemove) do
		if #indices > 0 then
			table.sort(indices, function(a, b) return a > b end)
			local comData = commanders[commanderID]
			for _, index in ipairs(indices) do
				table.remove(comData.spawnQueue, index)
			end
		end
	end
end

function gadget:GameFrame(frame)
	if not initialized and frame > PREGAME_DELAY_FRAMES then
		if #allTeamsList == 0 then
			allTeamsList = Spring.GetTeamList()
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
			if not isMetalMap then
				assignMexSpots()
			end
			for commanderID, comData in pairs(commanders) do
				if comData.spawnQueue then
					for i, buildItem in ipairs(comData.spawnQueue) do
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
			local buildProgress = select(5, spGetUnitHealth(unitID))
			if buildProgress >= 1 then
				-- due to some kind of glitch related to incrimentally increasing build progress to 1, we gotta cycle mexes off and on to get them to actually extract metal.
				Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 0 }, 0)
				Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 1 }, 0)
				buildsInProgress[unitID] = nil
			end
		elseif buildData.targetProgress > buildData.addedProgress then
			buildData.addedProgress = buildData.addedProgress + buildData.rate
			spSetUnitHealth(unitID, { build = buildData.addedProgress, health = ceil(buildData.maxHealth * buildData.addedProgress)})
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
	local discount = not Spring.GetTeamRulesParam(unitTeam, "quickStartFactoryDiscountUsed") and getFactoryDiscount(unitDef, builderID) or 0
	if discount > 0  and builderID then
		if builderID then
			commanderFactoryDiscounts[builderID] = true
		end
		Spring.SetTeamRulesParam(unitTeam, "quickStartFactoryDiscountUsed", 1)

		local fullBudgetCost = defMetergies[unitDefID]
		queueBuildForProgression(unitID, unitDef, discount, fullBudgetCost)
	end
end

function gadget:Initialize()
	local minWind = Game.windMin
	local maxWind = Game.windMax
	for _, teamID in ipairs(Spring.GetTeamList()) do
		Spring.SetTeamRulesParam(teamID, "quickStartFactoryDiscountUsed", nil)
	end
	isGoodWind = windFunctions.isGoodWind()
	isMetalMap = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].isMetalMap
	metalSpotsList = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList

	local frame = Spring.GetGameFrame()
	local quickStartAmount = modOptions.quick_start_amount or "normal"
	local immediateBudget = quickStartAmountConfig[quickStartAmount] or quickStartAmountConfig.normal
	
	local finalBudget = modOptions.override_quick_start_resources > 0 and modOptions.override_quick_start_resources or immediateBudget
	Spring.SetGameRulesParam("quickStartBudgetBase", finalBudget)
	Spring.SetGameRulesParam("quickStartFactoryDiscountAmount", FACTORY_DISCOUNT)
	local cheapestEconomicCost = calculateCheapestEconomicStructure()
	Spring.SetGameRulesParam("quickStartBudgetThresholdToAllowStart", cheapestEconomicCost)
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
			end
		end
	end
end