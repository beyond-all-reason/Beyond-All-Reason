local quickStartConfig = VFS.Include("LuaRules/Configs/quick_start_build_defs.lua")
local aestheticCustomCostRound = VFS.Include("common/aestheticCustomCostRound.lua")
local overlapLines = VFS.Include("common/overlap_lines.lua")

local customRound = aestheticCustomCostRound.customRound

---@type table<string, UnitDef?>
local unitDefNames = UnitDefNames

local ENERGY_VALUE_CONVERSION_MULTIPLIER = 1 / 60 --60 being the energy conversion rate of t2 energy converters, statically defined so future changes not to affect this.
local BUILD_TIME_VALUE_CONVERSION_MULTIPLIER = 1 / 300 --300 being a representative of commander workertime, statically defined so future com unitdef adjustments don't change this.
local TRAVERSABILITY_GRID_RESOLUTION = 32
local GRID_CHECK_RESOLUTION_MULTIPLIER = 1
local BUILD_SPACING = 64
local COMMANDER_NO_GO_DISTANCE = 100
local CONVERTER_GRID_DISTANCE = 200
local NODE_GRID_SORT_DISTANCE = 300
local BASE_NODE_COUNT = 8
local SKIP_STEP = 3
local SAFETY_COUNT = 100
local MAX_HEIGHT_DIFFERENCE = 100
local DEFAULT_FACING = 0
local UNOCCUPIED = 2
local MIN_GRID_THRESHOLD = 0.20
local MIN_CENTER_WEIGHT = 0.5
local MAX_CENTER_WEIGHT = 1.0

---@class QuickStartGridPosition
---@field x number
---@field y number
---@field z number

---@class QuickStartBaseNode
---@field x number
---@field z number
---@field grid QuickStartGridPosition[]
---@field score integer
---@field distanceFromCenter number
---@field goodEnough boolean
---@field resultantScore number

local function getModeFlags(modOptions)
	if not modOptions or not modOptions.quick_start then
		return false, false, false
	end

	local quickStartMode = modOptions.quick_start
	local territorialDominationEnabled = modOptions.temp_enable_territorial_domination
		or modOptions.deathmode == "territorial_domination"
	local defaultModeEnabled = quickStartMode == "default" and territorialDominationEnabled
	local shouldRunGadget = quickStartMode == "enabled"
		or quickStartMode == "factory_discount"
		or quickStartMode == "factory_discount_only"
		or defaultModeEnabled
	local shouldRunWidget = quickStartMode == "enabled" or quickStartMode == "factory_discount" or defaultModeEnabled
	local shouldApplyFactoryDiscount = quickStartMode == "factory_discount"
		or quickStartMode == "factory_discount_only"
		or defaultModeEnabled

	return shouldRunGadget, shouldRunWidget, shouldApplyFactoryDiscount
end

local function getAmountConfig(modOptions)
	local configKey = modOptions and modOptions.quick_start_amount or "normal"
	return quickStartConfig.amountConfig[configKey] or quickStartConfig.amountConfig.normal
end

local function calculateBudgetCost(metalCost, energyCost, buildTime)
	return customRound(
		(metalCost or 0)
			+ (energyCost or 0) * ENERGY_VALUE_CONVERSION_MULTIPLIER
			+ (buildTime or 0) * BUILD_TIME_VALUE_CONVERSION_MULTIPLIER
	)
end

local function applyFactoryDiscount(budgetCost, isFactory, discountAmount, discountAvailable)
	if isFactory and discountAvailable then
		return math.max(0, budgetCost - discountAmount)
	end
	return budgetCost
end

local function getBuildSequence(isMetalMap, isInWater, isGoodWind)
	local mapType = isMetalMap and "metalMap" or "nonMetalMap"
	local environment = isInWater and "water" or "land"
	local windQuality = isGoodWind and "goodWind" or "badWind"
	return quickStartConfig.buildSequence[mapType][environment][windQuality]
end

local function getCommanderBuildDefs(commanderName)
	local commanderOptions = quickStartConfig.commanderNonLabOptions[commanderName]
	if not commanderOptions then
		return nil
	end

	local buildDefs = {}
	for optionName, unitName in pairs(commanderOptions) do
		local unitDef = unitDefNames[unitName]
		if unitDef then
			buildDefs[optionName] = unitDef.id
		end
	end

	return buildDefs
end

local function getDefaultFacing(originX, originZ)
	local mapCenterX = Game.mapSizeX / 2
	local mapCenterZ = Game.mapSizeZ / 2
	local directionX = mapCenterX - originX
	local directionZ = mapCenterZ - originZ
	local angle = math.atan2(directionX, directionZ)
	return math.floor((angle / (math.pi / 2)) + 0.5) % 4
end

local function isWithinInstantBuildRange(
	originX,
	originZ,
	buildX,
	buildZ,
	instantBuildRange,
	overlapLineList,
	canMoveToPosition
)
	if not buildX or not buildZ then
		return false
	end
	if math.distance2d(originX, originZ, buildX, buildZ) > instantBuildRange then
		return false
	end
	if overlapLines.isPointPastLines(buildX, buildZ, originX, originZ, overlapLineList or {}) then
		return false
	end
	return canMoveToPosition(buildX, buildZ) or false
end

local function getNearbyMexes(originX, originZ, instantBuildRange, metalSpotsList, overlapLineList, canMoveToPosition)
	local nearbyMexes = {}
	if not metalSpotsList then
		return nearbyMexes
	end

	for spotIndex = 1, #metalSpotsList do
		local metalSpot = metalSpotsList[spotIndex]
		if
			metalSpot
			and isWithinInstantBuildRange(
				originX,
				originZ,
				metalSpot.x,
				metalSpot.z,
				instantBuildRange,
				overlapLineList,
				canMoveToPosition
			)
		then
			nearbyMexes[#nearbyMexes + 1] = {
				x = metalSpot.x,
				y = metalSpot.y,
				z = metalSpot.z,
				distance = math.distance2d(metalSpot.x, metalSpot.z, originX, originZ),
			}
		end
	end

	table.sort(nearbyMexes, function(firstSpot, secondSpot)
		return firstSpot.distance < secondSpot.distance
	end)

	return nearbyMexes
end

local function generateLocalGrid(context)
	if not context.buildDefID then
		return {}
	end

	local mapCenterX = Game.mapSizeX / 2
	local mapCenterZ = Game.mapSizeZ / 2
	local directionX = mapCenterX - context.commanderX
	local directionZ = mapCenterZ - context.commanderZ
	local skipDirection = math.abs(directionX) >= math.abs(directionZ) and "x" or "z"
	local gridList = {}
	local usedPositions = {}
	local noGoZones = {
		{
			x = context.commanderX,
			z = context.commanderZ,
			distance = COMMANDER_NO_GO_DISTANCE,
		},
	}
	local nearbyMexes = context.nearbyMexes or {}
	local overlapLineList = context.overlapLines or {}
	local defaultFacing = context.defaultFacing or DEFAULT_FACING

	for mexIndex = 1, #nearbyMexes do
		local mexSpot = nearbyMexes[mexIndex]
		noGoZones[#noGoZones + 1] = {
			x = mexSpot.x,
			z = mexSpot.z,
			distance = BUILD_SPACING,
		}
	end

	for offsetX = -context.baseGenerationRange, context.baseGenerationRange, BUILD_SPACING do
		for offsetZ = -context.baseGenerationRange, context.baseGenerationRange, BUILD_SPACING do
			local gridOffset = (skipDirection == "x" and offsetZ or offsetX) + context.baseGenerationRange
			if (gridOffset / BUILD_SPACING) % SKIP_STEP ~= 0 then
				local testX = context.commanderX + offsetX
				local testZ = context.commanderZ + offsetZ
				local withinGenerationRange = math.distance2d(testX, testZ, context.commanderX, context.commanderZ)
					<= context.baseGenerationRange
				if withinGenerationRange then
					local tooClose = false
					for zoneIndex = 1, #noGoZones do
						local noGoZone = noGoZones[zoneIndex]
						if math.distance2d(testX, testZ, noGoZone.x, noGoZone.z) <= noGoZone.distance then
							tooClose = true
							break
						end
					end

					if not tooClose then
						local groundY = Spring.GetGroundHeight(testX, testZ)
						if math.abs(groundY - context.commanderY) <= MAX_HEIGHT_DIFFERENCE then
							local buildX, buildY, buildZ =
								Spring.Pos2BuildPos(context.buildDefID, testX, groundY, testZ, defaultFacing)
							local isPastFriendlyLines = buildX
								and overlapLines.isPointPastLines(
									buildX,
									buildZ,
									context.commanderX,
									context.commanderZ,
									overlapLineList
								)
							local isTraversable = buildX and context.canMoveToPosition(buildX, buildZ)
							if
								buildX
								and not isPastFriendlyLines
								and isTraversable
								and Spring.TestBuildOrder(context.buildDefID, buildX, buildY, buildZ, defaultFacing)
									== UNOCCUPIED
							then
								local positionKey = buildX .. "_" .. buildZ
								if not usedPositions[positionKey] then
									usedPositions[positionKey] = true
									gridList[#gridList + 1] = {
										x = buildX,
										y = buildY,
										z = buildZ,
									}
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

---@return QuickStartBaseNode[]
local function createBaseNodes(commanderX, commanderZ, baseGenerationRange)
	---@type QuickStartBaseNode[]
	local nodes = {}
	local angleIncrement = 2 * math.pi / BASE_NODE_COUNT
	for nodeIndex = 0, BASE_NODE_COUNT - 1 do
		local angle = nodeIndex * angleIncrement
		nodes[nodeIndex + 1] = {
			x = commanderX + (baseGenerationRange / 2) * math.cos(angle),
			z = commanderZ + (baseGenerationRange / 2) * math.sin(angle),
			grid = {},
			score = 0,
			distanceFromCenter = 0.0,
			goodEnough = false,
			resultantScore = 0.0,
		}
	end
	return nodes
end

local function populateNodeGrids(nodes, localGrid, mapCenterX, mapCenterZ)
	for nodeIndex = 1, #nodes do
		local node = nodes[nodeIndex]
		for gridIndex = 1, #localGrid do
			local position = localGrid[gridIndex]
			if math.distance2d(position.x, position.z, node.x, node.z) <= NODE_GRID_SORT_DISTANCE then
				node.grid[#node.grid + 1] = {
					x = position.x,
					y = position.y,
					z = position.z,
				}
			end
		end

		node.score = #node.grid
		node.distanceFromCenter = math.distance2d(node.x, node.z, mapCenterX, mapCenterZ)
		node.goodEnough = node.score >= math.ceil(#localGrid * MIN_GRID_THRESHOLD)
	end
end

local function generateBaseNodesFromLocalGrid(context, localGrid)
	local mapCenterX = Game.mapSizeX / 2
	local mapCenterZ = Game.mapSizeZ / 2
	local nodes = createBaseNodes(context.commanderX, context.commanderZ, context.baseGenerationRange)
	populateNodeGrids(nodes, localGrid, mapCenterX, mapCenterZ)

	local minimumDistance = math.huge
	local maximumDistance = 0.0
	for nodeIndex = 1, #nodes do
		local node = nodes[nodeIndex]
		minimumDistance = math.min(minimumDistance, node.distanceFromCenter)
		maximumDistance = math.max(maximumDistance, node.distanceFromCenter)
	end

	local distanceRange = maximumDistance - minimumDistance
	for nodeIndex = 1, #nodes do
		local node = nodes[nodeIndex]
		local centerWeight = MAX_CENTER_WEIGHT
		if distanceRange > 0 then
			centerWeight = math.clamp(
				MAX_CENTER_WEIGHT - (node.distanceFromCenter - minimumDistance) / distanceRange,
				MIN_CENTER_WEIGHT,
				MAX_CENTER_WEIGHT
			)
		end

		local averageDistance = 0.0
		for gridIndex = 1, #node.grid do
			local position = node.grid[gridIndex]
			averageDistance = averageDistance + math.distance2d(position.x, position.z, node.x, node.z)
		end
		if #node.grid > 0 then
			averageDistance = averageDistance / #node.grid
		end
		node.resultantScore = centerWeight * averageDistance
	end

	local selectedPair = nil
	local bestResultantScore = math.huge
	for nodeIndex = 1, BASE_NODE_COUNT do
		local nextNodeIndex = (nodeIndex % BASE_NODE_COUNT) + 1
		local currentNode = nodes[nodeIndex]
		local nextNode = nodes[nextNodeIndex]
		if currentNode and nextNode and currentNode.goodEnough and nextNode.goodEnough then
			local combinedScore = currentNode.resultantScore + nextNode.resultantScore
			if combinedScore < bestResultantScore then
				bestResultantScore = combinedScore
				selectedPair = { currentNode, nextNode }
			end
		end
	end

	if not selectedPair then
		return {
			other = {},
			converters = {},
		}
	end

	local firstNode = selectedPair[1]
	local secondNode = selectedPair[2]
	local converterNode = firstNode.score <= secondNode.score and firstNode or secondNode
	local otherNode = converterNode == firstNode and secondNode or firstNode
	local converterGrid = {}
	local converterPositions = {}

	for gridIndex = 1, #converterNode.grid do
		local position = converterNode.grid[gridIndex]
		if math.distance2d(position.x, position.z, converterNode.x, converterNode.z) <= CONVERTER_GRID_DISTANCE then
			converterGrid[#converterGrid + 1] = position
			converterPositions[position.x .. "_" .. position.z] = true
		end
	end

	local otherGrid = {}
	for gridIndex = 1, #localGrid do
		local position = localGrid[gridIndex]
		if not converterPositions[position.x .. "_" .. position.z] then
			otherGrid[#otherGrid + 1] = position
		end
	end

	table.sort(converterGrid, function(firstPosition, secondPosition)
		return math.distance2d(firstPosition.x, firstPosition.z, converterNode.x, converterNode.z)
			< math.distance2d(secondPosition.x, secondPosition.z, converterNode.x, converterNode.z)
	end)
	table.sort(otherGrid, function(firstPosition, secondPosition)
		return math.distance2d(firstPosition.x, firstPosition.z, otherNode.x, otherNode.z)
			< math.distance2d(secondPosition.x, secondPosition.z, otherNode.x, otherNode.z)
	end)

	return {
		other = otherGrid,
		converters = converterGrid,
	}
end

local function getBuildSpace(context, buildType, isPositionOpen)
	local unitDefID = context.buildDefs[buildType]
	if not unitDefID then
		return nil, nil, nil
	end

	local defaultFacing = context.defaultFacing or DEFAULT_FACING
	if buildType == "mex" and not context.isMetalMap then
		while #context.nearbyMexes > 0 do
			local metalSpot = table.remove(context.nearbyMexes, 1)
			local groundY = Spring.GetGroundHeight(metalSpot.x, metalSpot.z)
			local buildX, buildY, buildZ =
				Spring.Pos2BuildPos(unitDefID, metalSpot.x, groundY, metalSpot.z, defaultFacing)
			if buildX and isPositionOpen(unitDefID, buildX, buildY, buildZ, defaultFacing) then
				return buildX, buildY, buildZ
			end
		end
		return nil, nil, nil
	end

	local nodeType = quickStartConfig.optionsToNodeType[buildType] or "other"
	local gridList = context.gridLists[nodeType] or {}
	while #gridList > 0 do
		local position = table.remove(gridList, 1)
		if isPositionOpen(unitDefID, position.x, position.y, position.z, defaultFacing) then
			return position.x, position.y, position.z
		end
	end

	return nil, nil, nil
end

return {
	config = quickStartConfig,
	ENERGY_VALUE_CONVERSION_MULTIPLIER = ENERGY_VALUE_CONVERSION_MULTIPLIER,
	BUILD_TIME_VALUE_CONVERSION_MULTIPLIER = BUILD_TIME_VALUE_CONVERSION_MULTIPLIER,
	TRAVERSABILITY_GRID_RESOLUTION = TRAVERSABILITY_GRID_RESOLUTION,
	GRID_CHECK_RESOLUTION_MULTIPLIER = GRID_CHECK_RESOLUTION_MULTIPLIER,
	BUILD_SPACING = BUILD_SPACING,
	COMMANDER_NO_GO_DISTANCE = COMMANDER_NO_GO_DISTANCE,
	CONVERTER_GRID_DISTANCE = CONVERTER_GRID_DISTANCE,
	NODE_GRID_SORT_DISTANCE = NODE_GRID_SORT_DISTANCE,
	BASE_NODE_COUNT = BASE_NODE_COUNT,
	SKIP_STEP = SKIP_STEP,
	SAFETY_COUNT = SAFETY_COUNT,
	MAX_HEIGHT_DIFFERENCE = MAX_HEIGHT_DIFFERENCE,
	DEFAULT_FACING = DEFAULT_FACING,
	UNOCCUPIED = UNOCCUPIED,
	getModeFlags = getModeFlags,
	getAmountConfig = getAmountConfig,
	calculateBudgetCost = calculateBudgetCost,
	applyFactoryDiscount = applyFactoryDiscount,
	getBuildSequence = getBuildSequence,
	getCommanderBuildDefs = getCommanderBuildDefs,
	getDefaultFacing = getDefaultFacing,
	isWithinInstantBuildRange = isWithinInstantBuildRange,
	getNearbyMexes = getNearbyMexes,
	generateLocalGrid = generateLocalGrid,
	generateBaseNodesFromLocalGrid = generateBaseNodesFromLocalGrid,
	getBuildSpace = getBuildSpace,
}
