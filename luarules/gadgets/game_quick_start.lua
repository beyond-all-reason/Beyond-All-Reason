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
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))
)
if not shouldRunGadget then return false end

----------------------------Configuration----------------------------------------
local QUICK_START_COST_ENERGY = 400      --will be deducted from commander's energy upon start.
local BONUS_ENERGY = 2500                --bonus energy added directly into the "juice" pool, free of charge.

local QUICK_START_COST_METAL = 800       --will be deducted from commander's metal upon start.
local BONUS_METAL = 450                  --bonus metal added directly into the "juice" pool, free of charge.

local FACTORY_DISCOUNT_MULTIPLIER = 0.90 -- The factory discount will be the juice cost of the cheapest listed factory multiplied by this value.

local INSTANT_BUILD_RANGE = 600          -- how far things will be be instantly built for the commander.

local quickStartAmountConfig = {
	small = {
		bonusMetal = 225,
		bonusEnergy = 1250,
	},
	normal = {
		bonusMetal = 450,
		bonusEnergy = 2500,
	},
	large = {
		bonusMetal = 675,
		bonusEnergy = 3750,
	},
}
-------------------------------------------------------------------------

local ALL_COMMANDS = -1
local BUILD_ORDER_FREE = 2
local BUILD_SPACING = 64
local CONVERTER_GRID_DISTANCE = 200
local ENERGY_VALUE_CONVERSION_DIVISOR = 10
local FACTORY_DISCOUNT = math.huge
local MAP_CENTER_X = Game.mapSizeX / 2
local MAP_CENTER_Z = Game.mapSizeZ / 2
local NODE_GRID_SORT_DISTANCE = 500
local PREGAME_DELAY_FRAMES = 61 --after gui_pregame_build.lua is loaded
local SKIP_STEP = 3
local UPDATE_FRAMES = Game.gameSpeed
local BASE_NODE_COUNT = 8
local MEX_OVERLAP_DISTANCE = 32
local SAFETY_COUNT = 15

local spCreateUnit = Spring.CreateUnit
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spPos2BuildPos = Spring.Pos2BuildPos
local spSpawnCEG = Spring.SpawnCEG
local spTestBuildOrder = Spring.TestBuildOrder

local config = VFS.Include('LuaRules/Configs/quick_start_build_defs.lua')
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
local defJuices = {}
local factoryDiscounts = {}
local mexDefs = {}
local mexOverlapCheckTable = {}
local optionDefIDToTypes = {}
local queuedCommanders = {}

local function getQuotas(isMetalMap, isInWater, isGoodWind)
	return config.quotas[isMetalMap and "metalMap" or "nonMetalMap"][isInWater and "water" or "land"]
	[isGoodWind and "goodWind" or "noWind"]
end

local function getBonusResources()
	local quickStartAmount = modOptions.quick_start_amount or "normal"
	local config = quickStartAmountConfig[quickStartAmount] or quickStartAmountConfig.normal
	return config.bonusMetal, config.bonusEnergy
end

local function generateLocalGrid(commanderID)
	local comData = commanders[commanderID]
	local originX, originZ = comData.spawnX, comData.spawnZ
	local buildDefID
	if comData.isInWater then
		buildDefID = comData.buildDefs and comData.buildDefs.tidal or nil
	else
		buildDefID = comData.buildDefs and comData.buildDefs.windmill or nil
	end
	if not buildDefID then
		return {}
	end
	local dx = MAP_CENTER_X - originX
	local dz = MAP_CENTER_Z - originZ
	local skipDirection = math.abs(dx) >= math.abs(dz) and "x" or "z"
	local maxOffset = INSTANT_BUILD_RANGE
	local gridList = {}
	local used = {}
	local noGoZones = {}
	table.insert(noGoZones, { x = originX, z = originZ, distance = 100 })
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
				if math.distance2d(testX, testZ, originX, originZ) <= INSTANT_BUILD_RANGE then
					local tooClose = false
					for i = 1, #noGoZones do
						local g = noGoZones[i]
						if math.distance2d(testX, testZ, g.x, g.z) <= g.distance then
							tooClose = true
							break
						end
					end
					if not tooClose then
						local searchY = spGetGroundHeight(testX, testZ)
						local snappedX, snappedY, snappedZ = spPos2BuildPos(buildDefID, testX, searchY, testZ)
						if snappedX and spTestBuildOrder(buildDefID, snappedX, snappedY, snappedZ, 0) == BUILD_ORDER_FREE then
							local key = snappedX .. "_" .. snappedZ
							if not used[key] then
								used[key] = true
								table.insert(gridList, { x = snappedX, z = snappedZ })
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
	local metalCost, energyCost = unitDef.metalCost or 1, unitDef.energyCost or 1
	defJuices[unitDefID] = metalCost + (energyCost / ENERGY_VALUE_CONVERSION_DIVISOR)
	if unitDef.extractsMetal > 0 then
		mexDefs[unitDefID] = true
	end
	if unitDef.customParams and unitDef.customParams.iscommander then
		boostableCommanders[unitDefID] = true
	end
end
for name, _ in pairs(discountableFactories) do
	if unitDefNames[name] then
		local labJuice = defJuices[unitDefNames[name].id]
		FACTORY_DISCOUNT = math.min(FACTORY_DISCOUNT, labJuice * FACTORY_DISCOUNT_MULTIPLIER)
	end
end
for commanderName, nonLabOptions in pairs(commanderNonLabOptions) do
	if unitDefNames[commanderName] then
		for optionName, trueName in pairs(nonLabOptions) do
			optionDefIDToTypes[unitDefNames[trueName].id] = optionName
		end
	end
end

local function isBuildCommand(cmdID)
	return cmdID < 0
end

local function getBuildInstanceID(unitDefID, x, y)
	return unitDefID .. "_" .. x .. "_" .. y
end

local function getFactoryDiscount(unitDef, teamID, builderID)
	if not unitDef.isFactory then return 0 end
	if factoryDiscounts[teamID] then return 0 end
	if discountableFactories[unitDef.name] ~= true then return 0 end
	if builderID and not commanders[builderID] then return 0 end
	return FACTORY_DISCOUNT
end

local function applyBuildProgressToUnit(unitID, unitDef, affordableJuice, fullJuiceCost)
	local buildProgress = affordableJuice / fullJuiceCost
	Spring.SetUnitHealth(unitID, { build = buildProgress, health = math.ceil(unitDef.health * buildProgress) })
	return buildProgress
end

local function getCommanderBuildQueue(commanderID)
	local spawnQueue = {}
	local comData = commanders[commanderID]
	local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
	local totalJuiceCost = 0
	for i, cmd in ipairs(commands) do
		if isBuildCommand(cmd.id) then
			local spawnParams = { id = -cmd.id, x = cmd.params[1], y = cmd.params[2], z = cmd.params[3], facing = cmd
			.params[4] or 1 }
			if math.distance2d(comData.spawnX, comData.spawnZ, spawnParams.x, spawnParams.z) <= INSTANT_BUILD_RANGE then
				table.insert(spawnQueue, spawnParams)
				local unitDefID = -cmd.id
				local unitDef = unitDefs[unitDefID]
				local juiceCost = defJuices[unitDefID] or 0
				if unitDef and unitDef.isFactory and discountableFactories[unitDef.name] and not factoryDiscounts[comData.teamID] then
					juiceCost = math.max(juiceCost - FACTORY_DISCOUNT, 0)
				end
				totalJuiceCost = totalJuiceCost + juiceCost
				if totalJuiceCost > comData.juice then
					return spawnQueue
				end
			end
		end
	end
	return spawnQueue
end

local function refreshAvailableMexSpots(commanderID)
	local comData = commanders[commanderID]
	if not comData or isMetalMap then return end

	if not comData.nearbyMexes or #comData.nearbyMexes == 0 then
		return false
	end

	local availableMexes = {}
	local mexDefID = comData.buildDefs.mex
	if mexDefID then
		for i = 1, #comData.nearbyMexes do
			local mexSpot = comData.nearbyMexes[i]
			local buildY = spGetGroundHeight(mexSpot.x, mexSpot.z)
			local snappedX, snappedY, snappedZ = spPos2BuildPos(mexDefID, mexSpot.x, buildY, mexSpot.z)
			if snappedX and spTestBuildOrder(mexDefID, snappedX, snappedY, snappedZ, 0) == BUILD_ORDER_FREE then
				table.insert(availableMexes, mexSpot)
			end
		end
	end

	comData.nearbyMexes = availableMexes
	local quotas = getQuotas(isMetalMap, comData.isInWater, isGoodWind)
	comData.buildWeights.mex = #availableMexes > 0 and #availableMexes / quotas.mex or 0
end

local function getBuildSpace(commanderID, option)
	local comData = commanders[commanderID]
	if not comData then
		return nil, nil
	end

	if option == "mex" and not isMetalMap then
		if comData.nearbyMexes and #comData.nearbyMexes > 0 then
			local mexSpot = comData.nearbyMexes[1]
			table.remove(comData.nearbyMexes, 1)
			return mexSpot.x, mexSpot.z
		else
			comData.buildWeights.mex = 0
			return nil, nil
		end
	else
		local nodeType = optionsToNodeType[option] or "other"
		local gridList = comData.gridLists[nodeType] or {}

		if #gridList == 0 then
			return nil, nil
		end

		local candidate = gridList[1]
		table.remove(gridList, 1)
		comData.gridLists[nodeType] = gridList

		return candidate.x, candidate.z
	end
end

local function createBaseNodes(spawnX, spawnZ)
	local nodes = {}
	local angleIncrement = 2 * math.pi / BASE_NODE_COUNT
	for i = 0, BASE_NODE_COUNT - 1 do
		local angle = i * angleIncrement
		local nodeX = spawnX + (INSTANT_BUILD_RANGE / 2) * math.cos(angle)
		local nodeZ = spawnZ + (INSTANT_BUILD_RANGE / 2) * math.sin(angle)
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
			if math.distance2d(p.x, p.z, node.x, node.z) <= NODE_GRID_SORT_DISTANCE then
				table.insert(node.grid, { x = p.x, z = p.z })
			end
		end
		node.score = #node.grid
		node.distanceFromCenter = math.distance2d(node.x, node.z, MAP_CENTER_X, MAP_CENTER_Z)
		node.goodEnough = node.score >= math.ceil(totalValid * 0.25)
	end
end

local function generateBaseNodesFromLocalGrid(commanderID, localGrid)
	local comData = commanders[commanderID]
	local spawnX, spawnZ = comData.spawnX, comData.spawnZ
	local nodes = createBaseNodes(spawnX, spawnZ)
	populateNodeGrids(nodes, localGrid)
	local nodesByDistance = {}
	for i = 1, #nodes do
		nodesByDistance[i] = nodes[i]
	end
	table.sort(nodesByDistance, function(a, b) return a.distanceFromCenter > b.distanceFromCenter end)
	local selectedPair = nil
	for i = 1, #nodesByDistance do
		local node = nodesByDistance[i]
		if node.goodEnough then
			local leftIndex = ((node.index + BASE_NODE_COUNT - 2) % BASE_NODE_COUNT) + 1
			local rightIndex = (node.index % BASE_NODE_COUNT) + 1
			if nodes[leftIndex].goodEnough then
				selectedPair = { nodes[leftIndex], node }
				break
			end
			if nodes[rightIndex].goodEnough then
				selectedPair = { node, nodes[rightIndex] }
				break
			end
		end
	end
	if not selectedPair then
		local bestScore = -1
		for i = 1, BASE_NODE_COUNT do
			local j = (i % BASE_NODE_COUNT) + 1
			local s = nodes[i].score + nodes[j].score
			if s > bestScore then
				bestScore = s
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
	for i = 1, #converterNode.grid do
		local p = converterNode.grid[i]
		if math.distance2d(p.x, p.z, converterNode.x, converterNode.z) <= CONVERTER_GRID_DISTANCE then
			table.insert(filteredConverter, p)
		end
	end
	local converterKeys = {}
	for i = 1, #filteredConverter do
		local k = filteredConverter[i].x .. "_" .. filteredConverter[i].z
		converterKeys[k] = true
	end
	local filteredOther = {}
	for i = 1, #otherNode.grid do
		local p = otherNode.grid[i]
		local k = p.x .. "_" .. p.z
		if not converterKeys[k] then
			table.insert(filteredOther, p)
		end
	end
	local function addDistance(points, node)
		for i = 1, #points do
			points[i].d = math.distance2d(points[i].x, points[i].z, node.x, node.z)
		end
	end
	addDistance(filteredConverter, converterNode)
	addDistance(filteredOther, otherNode)
	table.sort(filteredConverter, function(a, b) return a.d < b.d end)
	table.sort(filteredOther, function(a, b) return a.d < b.d end)
	return { other = { x = otherNode.x, z = otherNode.z, grid = filteredOther }, converters = { x = converterNode.x, z = converterNode.z, grid = filteredConverter } }
end

local function populateNearbyMexes(commanderID)
	local comData = commanders[commanderID]
	local commanderX, commanderY, commanderZ = comData.spawnX, comData.spawnY, comData.spawnZ

	comData.nearbyMexes = {}
	if isMetalMap or not metalSpotsList then
		return
	end

	for i = 1, #metalSpotsList do
		local metalSpot = metalSpotsList[i]
		if metalSpot then
			local distance = math.distance2d(metalSpot.x, metalSpot.z, commanderX, commanderZ)
			if distance <= INSTANT_BUILD_RANGE then
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
	local currentMetal = Spring.GetTeamResources(teamID, "metal") or 0
	local currentEnergy = Spring.GetTeamResources(teamID, "energy") or 0
	local juice = QUICK_START_COST_METAL + BONUS_METAL +
	(QUICK_START_COST_ENERGY + BONUS_ENERGY) / ENERGY_VALUE_CONVERSION_DIVISOR

	factoryDiscounts[teamID] = false

	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	local directionX = MAP_CENTER_X - commanderX
	local directionZ = MAP_CENTER_Z - commanderZ
	local angle = math.atan2(directionX, directionZ)
	local defaultFacing = math.floor((angle / (math.pi / 2)) + 0.5) % 4

	local commanderDefID = Spring.GetUnitDefID(commanderID)
	local commanderName = UnitDefs[commanderDefID].name
	local isInWater = commanderY < 0
	local buildDefs = {}
	for optionName, trueName in pairs(commanderNonLabOptions[commanderName]) do
		buildDefs[optionName] = unitDefNames[trueName].id
	end

	local commanderBuildQuotas = getQuotas(isMetalMap, isInWater, isGoodWind)

	local totalQuota = 0
	for optionName, quota in pairs(commanderBuildQuotas) do
		totalQuota = totalQuota + quota
	end

	local buildWeights = {}
	for optionName, quota in pairs(commanderBuildQuotas) do
		if quota == 0 then
			buildWeights[optionName] = -math.huge
		else
			buildWeights[optionName] = quota / totalQuota
		end
	end

	commanders[commanderID] = {
		teamID = teamID,
		juice = juice,
		thingsMade = { windmill = 0, mex = 0, converter = 0, solar = 0, tidal = 0, floatingConverter = 0 },
		defaultFacing = defaultFacing,
		isInWater = isInWater,
		buildDefs = buildDefs,
		gridLists = { other = {}, converters = {} },
		buildWeights = buildWeights,
		nearbyMexes = {}
	}

	Spring.SetTeamResource(teamID, "metal", math.max(0, currentMetal - QUICK_START_COST_METAL))
	Spring.SetTeamResource(teamID, "energy", math.max(0, currentEnergy - QUICK_START_COST_ENERGY))

	local comData = commanders[commanderID]
	comData.spawnX, comData.spawnY, comData.spawnZ = spGetUnitPosition(commanderID)
	populateNearbyMexes(commanderID)
	comData.spawnQueue = getCommanderBuildQueue(commanderID)
	for i = #comData.spawnQueue, 1, -1 do
		local build = comData.spawnQueue[i]
		if math.distance2d(build.x, build.z, comData.spawnX, comData.spawnZ) > INSTANT_BUILD_RANGE then
			table.remove(comData.spawnQueue, i)
		elseif mexDefs[build.id] then
			mexOverlapCheckTable[getBuildInstanceID(build.id, build.x, build.z)] = { commanderID, build.x, build.z }
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

local function filterOverlappingMexes()
	local mexesToRemove = {}

	for mexKey1, mexData1 in pairs(mexOverlapCheckTable) do
		local commanderID1, x1, z1 = mexData1[1], mexData1[2], mexData1[3]
		local comData1 = commanders[commanderID1]
		local distanceToCommander1 = math.distance2d(x1, z1, comData1.spawnX, comData1.spawnZ)

		for mexKey2, mexData2 in pairs(mexOverlapCheckTable) do
			if mexKey1 ~= mexKey2 then
				local x2, z2 = mexData2[2], mexData2[3]
				local distanceBetweenMexes = math.distance2d(x1, z1, x2, z2)

				if distanceBetweenMexes <= MEX_OVERLAP_DISTANCE then
					local commanderID2 = mexData2[1]
					local comData2 = commanders[commanderID2]
					local distanceToCommander2 = math.distance2d(x2, z2, comData2.spawnX, comData2.spawnZ)

					if distanceToCommander1 < distanceToCommander2 then
						mexesToRemove[mexKey1] = true
					else
						mexesToRemove[mexKey2] = true
					end
				end
			end
		end
	end

	for mexKey, _ in pairs(mexesToRemove) do
		mexOverlapCheckTable[mexKey] = nil
	end
end

local function generateBuildCommands(commanderID)
	local comData = commanders[commanderID]
	local totalJuiceUsed = 0
	local tryCount = 0
	local maxMexes = isMetalMap and math.huge or #comData.nearbyMexes
	local mexCount = 0
	local weightedOptions = table.copy(comData.buildWeights)
	refreshAvailableMexSpots(commanderID)

	for optionName, weight in pairs(weightedOptions) do
		local currentCount = comData.thingsMade[optionName] or 0
		local delayIntervals = currentCount * comData.buildWeights[optionName]
		weightedOptions[optionName] = weight - delayIntervals
	end

	while totalJuiceUsed < comData.juice and tryCount < SAFETY_COUNT do
		local selectedOption = nil
		local bestWeight = -math.huge

		for optionName, weight in pairs(weightedOptions) do
			local newWeight = weight + comData.buildWeights[optionName]
			weightedOptions[optionName] = newWeight
			if newWeight > bestWeight and not (optionName == "mex" and mexCount >= maxMexes) then
				bestWeight = newWeight
				selectedOption = optionName
			end
		end

		if selectedOption then
			weightedOptions[selectedOption] = comData.buildWeights[selectedOption]
			if selectedOption == "mex" then
				mexCount = mexCount + 1
			end
			local buildDefID = comData.buildDefs[selectedOption]
			local unitDef = unitDefs[buildDefID]
			local discount = getFactoryDiscount(unitDef, comData.teamID, commanderID)
			local juiceCost = defJuices[buildDefID] - discount

			table.insert(comData.spawnQueue, 1, { id = buildDefID })
			totalJuiceUsed = totalJuiceUsed + juiceCost
		end
		tryCount = tryCount + 1
	end
end

local function tryToSpawnBuild(commanderID, buildDefID, buildX, buildZ, facing)
	local unitDef, comData, buildProgress = unitDefs[buildDefID], commanders[commanderID], 0
	local discount = getFactoryDiscount(unitDef, comData.teamID, commanderID)
	local juiceCost = defJuices[buildDefID] - discount
	if comData.juice <= 0 then return false end
	local buildY = spGetGroundHeight(buildX, buildZ)

	if spTestBuildOrder(buildDefID, buildX, buildY, buildZ, facing) ~= BUILD_ORDER_FREE then
		return false
	end

	local unitID = spCreateUnit(unitDef.name, buildX, buildY, buildZ, facing, comData.teamID)
	if not unitID then
		return false, nil
	end

	local affordableJuice = math.min(comData.juice, juiceCost)
	buildProgress = applyBuildProgressToUnit(unitID, unitDef, affordableJuice, juiceCost)
	comData.juice = comData.juice - affordableJuice

	local optionName = optionDefIDToTypes[buildDefID]
	if optionName then
		comData.thingsMade[optionName] = (comData.thingsMade[optionName] or 0) + 1
	end

	spSpawnCEG("quickstart-spawn-pulse-large", buildX, buildY + 10, buildZ)
	if buildProgress < 1 then
		Spring.GiveOrderToUnit(commanderID, CMD.INSERT, { 0, CMD.REPAIR, CMD.OPT_SHIFT, unitID }, CMD.OPT_ALT)
	end

	return buildProgress >= 1
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
			filterOverlappingMexes()
		end
	end

	while running and frame > PREGAME_DELAY_FRAMES + 1 do
		gameFrameTryCount = gameFrameTryCount + 1
		if gameFrameTryCount > SAFETY_COUNT then
			running = false
			break
		end
		local function processSpawnQueues()
			local loop = true
			while loop do
				loop = false
				for commanderID, comData in pairs(commanders) do
					if comData.spawnQueue then
						for i, build in ipairs(comData.spawnQueue) do
							local optionType = optionDefIDToTypes[build.id]
							local buildX, buildZ = build.x, build.z
							if not buildX or not buildZ then
								buildX, buildZ = getBuildSpace(commanderID, optionType)
							end
							local facing = build.facing or comData.defaultFacing or 0
							if buildX and buildZ then
								local fullyBuilt = tryToSpawnBuild(commanderID, build.id, buildX, buildZ, facing)
								if fullyBuilt then
									loop = true
								end
							end
						end
					end
					comData.spawnQueue = {}
				end
			end
		end
		processSpawnQueues()
		local allQueuesEmpty = true
		for commanderID, comData in pairs(commanders) do
			if comData.juice > 0 then
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

	local allDiscountsUsed = false
	if frame % UPDATE_FRAMES == 0 then
		allDiscountsUsed = true
		for teamID, used in pairs(factoryDiscounts) do
			if not used then
				allDiscountsUsed = false
				break
			end
		end
	end
	if initialized and allDiscountsUsed and not running then
		gadgetHandler:RemoveGadget()
	end
end

function gadget:UnitDestroyed(unitID)
	commanders[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if boostableCommanders[unitDefID] then
		queuedCommanders[unitTeam] = unitID
	end

	local unitDef = unitDefs[unitDefID]
	local discount = getFactoryDiscount(unitDef, unitTeam, builderID)
	if discount > 0 then
		factoryDiscounts[unitTeam] = true
		Spring.SetTeamRulesParam(unitTeam, "quickStartFactoryDiscountUsed", 1)

		local fullJuiceCost = defJuices[unitDefID]
		local buildProgress = applyBuildProgressToUnit(unitID, unitDef, discount, fullJuiceCost)
		local x, y, z = spGetUnitPosition(unitID)
		spSpawnCEG("quickstart-spawn-pulse-large", x, y + 10, z)
	end
end

function gadget:Initialize()
	local minWind = Game.windMin
	local maxWind = Game.windMax
	for _, teamID in ipairs(Spring.GetTeamList()) do
		Spring.SetTeamRulesParam(teamID, "quickStartFactoryDiscountUsed", 0)
	end
	-- precomputed average wind values, from wind random monte carlo simulation, given minWind and maxWind
	local avgWind = {[0]={[1]="0.8",[2]="1.5",[3]="2.2",[4]="3.0",[5]="3.7",[6]="4.5",[7]="5.2",[8]="6.0",[9]="6.7",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.4",[15]="11.2",[16]="11.9",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[1]={[2]="1.6",[3]="2.3",[4]="3.0",[5]="3.8",[6]="4.5",[7]="5.2",[8]="6.0",[9]="6.7",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.4",[15]="11.2",[16]="11.9",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[2]={[3]="2.6",[4]="3.2",[5]="3.9",[6]="4.6",[7]="5.3",[8]="6.0",[9]="6.8",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.5",[15]="11.2",[16]="12.0",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[3]={[4]="3.6",[5]="4.2",[6]="4.8",[7]="5.5",[8]="6.2",[9]="6.9",[10]="7.6",[11]="8.3",[12]="9.0",[13]="9.8",[14]="10.5",[15]="11.2",[16]="12.0",[17]="12.7",[18]="13.5",[19]="14.2",[20]="15.0",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.7",[26]="19.2",[27]="19.7",[28]="20.0",[29]="20.4",[30]="20.7",},[4]={[5]="4.6",[6]="5.2",[7]="5.8",[8]="6.4",[9]="7.1",[10]="7.8",[11]="8.5",[12]="9.2",[13]="9.9",[14]="10.6",[15]="11.3",[16]="12.1",[17]="12.8",[18]="13.5",[19]="14.3",[20]="15.0",[21]="15.7",[22]="16.5",[23]="17.2",[24]="18.0",[25]="18.7",[26]="19.2",[27]="19.7",[28]="20.1",[29]="20.4",[30]="20.7",},[5]={[6]="5.5",[7]="6.1",[8]="6.8",[9]="7.4",[10]="8.0",[11]="8.7",[12]="9.4",[13]="10.1",[14]="10.8",[15]="11.5",[16]="12.2",[17]="12.9",[18]="13.6",[19]="14.4",[20]="15.1",[21]="15.8",[22]="16.5",[23]="17.3",[24]="18.0",[25]="18.8",[26]="19.3",[27]="19.7",[28]="20.1",[29]="20.4",[30]="20.7",},[6]={[7]="6.5",[8]="7.1",[9]="7.7",[10]="8.4",[11]="9.0",[12]="9.7",[13]="10.3",[14]="11.0",[15]="11.7",[16]="12.4",[17]="13.1",[18]="13.8",[19]="14.5",[20]="15.2",[21]="15.9",[22]="16.7",[23]="17.4",[24]="18.1",[25]="18.8",[26]="19.4",[27]="19.8",[28]="20.2",[29]="20.5",[30]="20.8",},[7]={[8]="7.5",[9]="8.1",[10]="8.7",[11]="9.3",[12]="10.0",[13]="10.6",[14]="11.3",[15]="11.9",[16]="12.6",[17]="13.3",[18]="14.0",[19]="14.7",[20]="15.4",[21]="16.1",[22]="16.8",[23]="17.5",[24]="18.2",[25]="19.0",[26]="19.5",[27]="19.9",[28]="20.3",[29]="20.6",[30]="20.9",},[8]={[9]="8.5",[10]="9.1",[11]="9.7",[12]="10.3",[13]="11.0",[14]="11.6",[15]="12.2",[16]="12.9",[17]="13.6",[18]="14.2",[19]="14.9",[20]="15.6",[21]="16.3",[22]="17.0",[23]="17.7",[24]="18.4",[25]="19.1",[26]="19.6",[27]="20.0",[28]="20.4",[29]="20.7",[30]="21.0",},[9]={[10]="9.5",[11]="10.1",[12]="10.7",[13]="11.3",[14]="11.9",[15]="12.6",[16]="13.2",[17]="13.8",[18]="14.5",[19]="15.2",[20]="15.8",[21]="16.5",[22]="17.2",[23]="17.9",[24]="18.6",[25]="19.3",[26]="19.8",[27]="20.2",[28]="20.5",[29]="20.8",[30]="21.1",},[10]={[11]="10.5",[12]="11.1",[13]="11.7",[14]="12.3",[15]="12.9",[16]="13.5",[17]="14.2",[18]="14.8",[19]="15.4",[20]="16.1",[21]="16.8",[22]="17.4",[23]="18.1",[24]="18.8",[25]="19.5",[26]="20.0",[27]="20.4",[28]="20.7",[29]="21.0",[30]="21.2",},[11]={[12]="11.5",[13]="12.1",[14]="12.7",[15]="13.3",[16]="13.9",[17]="14.5",[18]="15.1",[19]="15.8",[20]="16.4",[21]="17.1",[22]="17.7",[23]="18.4",[24]="19.1",[25]="19.7",[26]="20.2",[27]="20.6",[28]="20.9",[29]="21.2",[30]="21.4",},[12]={[13]="12.5",[14]="13.1",[15]="13.6",[16]="14.2",[17]="14.9",[18]="15.5",[19]="16.1",[20]="16.7",[21]="17.4",[22]="18.0",[23]="18.7",[24]="19.3",[25]="20.0",[26]="20.4",[27]="20.8",[28]="21.1",[29]="21.4",[30]="21.6",},[13]={[14]="13.5",[15]="14.1",[16]="14.6",[17]="15.2",[18]="15.8",[19]="16.5",[20]="17.1",[21]="17.7",[22]="18.4",[23]="19.0",[24]="19.6",[25]="20.3",[26]="20.7",[27]="21.1",[28]="21.4",[29]="21.6",[30]="21.8",},[14]={[15]="14.5",[16]="15.0",[17]="15.6",[18]="16.2",[19]="16.8",[20]="17.4",[21]="18.1",[22]="18.7",[23]="19.3",[24]="20.0",[25]="20.6",[26]="21.0",[27]="21.3",[28]="21.6",[29]="21.8",[30]="22.0",},[15]={[16]="15.5",[17]="16.0",[18]="16.6",[19]="17.2",[20]="17.8",[21]="18.4",[22]="19.0",[23]="19.6",[24]="20.3",[25]="20.9",[26]="21.3",[27]="21.6",[28]="21.9",[29]="22.1",[30]="22.3",},[16]={[17]="16.5",[18]="17.0",[19]="17.6",[20]="18.2",[21]="18.8",[22]="19.4",[23]="20.0",[24]="20.6",[25]="21.3",[26]="21.7",[27]="21.9",[28]="22.2",[29]="22.4",[30]="22.5",},[17]={[18]="17.5",[19]="18.0",[20]="18.6",[21]="19.2",[22]="19.8",[23]="20.4",[24]="21.0",[25]="21.6",[26]="22.0",[27]="22.3",[28]="22.5",[29]="22.7",[30]="22.8",},[18]={[19]="18.5",[20]="19.0",[21]="19.6",[22]="20.2",[23]="20.8",[24]="21.4",[25]="22.0",[26]="22.4",[27]="22.6",[28]="22.8",[29]="23.0",[30]="23.1",},[19]={[20]="19.5",[21]="20.0",[22]="20.6",[23]="21.2",[24]="21.8",[25]="22.4",[26]="22.7",[27]="22.9",[28]="23.1",[29]="23.2",[30]="23.4",},[20]={[21]="20.4",[22]="21.0",[23]="21.6",[24]="22.2",[25]="22.8",[26]="23.1",[27]="23.3",[28]="23.4",[29]="23.6",[30]="23.7",},[21]={[22]="21.4",[23]="22.0",[24]="22.6",[25]="23.2",[26]="23.5",[27]="23.6",[28]="23.8",[29]="23.9",[30]="24.0",},[22]={[23]="22.4",[24]="23.0",[25]="23.6",[26]="23.8",[27]="24.0",[28]="24.1",[29]="24.2",[30]="24.2",},[23]={[24]="23.4",[25]="24.0",[26]="24.2",[27]="24.4",[28]="24.4",[29]="24.5",[30]="24.5",},[24]={[25]="24.4",[26]="24.6",[27]="24.7",[28]="24.7",[29]="24.8",[30]="24.8",},}
	local averageWind
	if avgWind[minWind] and avgWind[minWind][maxWind] then
		averageWind = tonumber(avgWind[minWind][maxWind])
	else
		averageWind = math.max(minWind, maxWind * 0.75)
	end

	isGoodWind = averageWind > 7
	isMetalMap = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].isMetalMap
	metalSpotsList = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList

	local frame = Spring.GetGameFrame()
	local bonusMetal, bonusEnergy = getBonusResources()
	local immediateJuice = QUICK_START_COST_METAL + bonusMetal +
	(QUICK_START_COST_ENERGY + bonusEnergy) / ENERGY_VALUE_CONVERSION_DIVISOR
	Spring.SetGameRulesParam("quickStartJuiceBase", immediateJuice)
	Spring.SetGameRulesParam("quickStartFactoryDiscountAmount", FACTORY_DISCOUNT)
	Spring.SetGameRulesParam("overridePregameBuildDistance", INSTANT_BUILD_RANGE)

	if frame > 1 then
		local allUnits = Spring.GetAllUnits()
		for _, unitID in ipairs(allUnits) do
			local unitDefinitionID = Spring.GetUnitDefID(unitID)
			local unitTeam = Spring.GetUnitTeam(unitID)
			if boostableCommanders[unitDefinitionID] then
				initializeCommander(unitID, unitTeam)
			end
		end
	end
end
