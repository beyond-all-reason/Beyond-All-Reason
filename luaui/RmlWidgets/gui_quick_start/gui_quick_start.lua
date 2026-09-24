if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Quick Start UI",
		desc = "Displays instant build resources and factory prompt",
		author = "SethDGamre",
		date = "2025-07",
		license = "GNU GPL, v2 or later",
		layer = 2, --after pregame_build
		enabled = true,
	}
end

local modOptions = Spring.GetModOptions()

if not modOptions or not modOptions.quick_start then
	return false
end

---@type table<integer, UnitDef>
local UnitDefs = UnitDefs

local quickStart = VFS.Include("common/quick_start_shared.lua")
local startingMetal = modOptions.startmetal or 1000
local _, shouldRunWidget, shouldApplyFactoryDiscount = quickStart.getModeFlags(modOptions)

if not shouldRunWidget then
	return false
end

local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetMyTeamID = Spring.GetLocalTeamID
local spI18N = BAR.I18N

---@type table<string, any>
local WG = WG

---@type any
local wgBuildMenu
---@type any
local wgGridMenu
---@type any
local wgTopbar
---@type any
local wgPregameBuild
---@type any
local wgPregameUI
---@type any
local wgPregameUIDraft
---@type any
local wgGetBuildQueueFunc
---@type any
local wgGetBuildPositionsFunc
---@type any
local wgGetPregameUnitSelectedFunc

local MODEL_NAME = "quick_start_model"
local RML_PATH = "luaui/RmlWidgets/gui_quick_start/gui_quick_start.rml"
local QUICK_START_CONDITION_KEY = "quickStartUnallocatedBudget"
local QUICK_START_GENERATED_KEY = "quickStartGenerated"
local AUTO_GENERATE_SUGGESTIONS_CONFIG = "QuickStartSuggestions"

local selectedAmountConfig = quickStart.getAmountConfig(modOptions)
local DEFAULT_INSTANT_BUILD_RANGE = selectedAmountConfig.range
local DEFAULT_TRAVERSABILITY_GRID_RANGE = selectedAmountConfig.traversabilityGridRange
local TRAVERSABILITY_GRID_RESOLUTION = quickStart.TRAVERSABILITY_GRID_RESOLUTION
local GRID_CHECK_RESOLUTION_MULTIPLIER = quickStart.GRID_CHECK_RESOLUTION_MULTIPLIER
local SAFETY_COUNT = quickStart.SAFETY_COUNT
local UNOCCUPIED = quickStart.UNOCCUPIED
local SQUARE_SIZE = 8

local traversabilityGrid = VFS.Include("common/traversability_grid.lua")
local overlapLines = VFS.Include("common/overlap_lines.lua")
local windFunctions = VFS.Include("common/wind_functions.lua")
local calculateBudgetCost = quickStart.calculateBudgetCost
local lastCommanderX = nil
local lastCommanderZ = nil
local lastPreloadedCommanderX = nil
local lastPreloadedCommanderZ = nil
local autoGenerateSuggestions = Spring.GetConfigInt(AUTO_GENERATE_SUGGESTIONS_CONFIG, 1) == 1

local cachedOverlapLines = {}
local cachedGameRules = {}
local lastRulesUpdate = 0.0
local RULES_CACHE_DURATION = 0.1
---@type integer?
local overlapLinesDisplayList = nil
local previousOverlapLines = {}
local externalSpawnPositions = {}
local externalSpawnPositionsChanged = false
local hasOverlapLines = false

local function linesHaveChanged(newLines, oldLines)
	if #newLines ~= #oldLines then
		return true
	end

	for i, newLine in ipairs(newLines) do
		local oldLine = oldLines[i]
		if
			not oldLine
			or newLine.A ~= oldLine.A
			or newLine.B ~= oldLine.B
			or newLine.C ~= oldLine.C
			or newLine.originVal ~= oldLine.originVal
		then
			return true
		end
	end

	return false
end

local function updateSpawnPositions(spawnPositions)
	if not spawnPositions then
		return
	end

	local hasChanged = false

	for teamID, oldPos in pairs(externalSpawnPositions) do
		if not spawnPositions[teamID] then
			hasChanged = true
			break
		end
		local newPos = spawnPositions[teamID]
		if oldPos.x ~= newPos.x or oldPos.z ~= newPos.z then
			hasChanged = true
			break
		end
	end

	if not hasChanged then
		for teamID, newPos in pairs(spawnPositions) do
			if not externalSpawnPositions[teamID] then
				hasChanged = true
				break
			end
		end
	end

	if not hasChanged then
		return
	end

	externalSpawnPositions = {}
	for teamID, pos in pairs(spawnPositions) do
		if pos.x and pos.z then
			externalSpawnPositions[teamID] = { x = pos.x, z = pos.z }
		end
	end

	externalSpawnPositionsChanged = true

	if WG["pregame-build"] and WG["pregame-build"].forceRefresh then
		WG["pregame-build"].forceRefresh()
	end
end

local function getCachedGameRules()
	local currentTime = os.clock()
	if currentTime - lastRulesUpdate > RULES_CACHE_DURATION then
		cachedGameRules.budgetTotal = spGetGameRulesParam("quickStartBudgetBase") or 0
		cachedGameRules.factoryDiscountAmount = spGetGameRulesParam("quickStartFactoryDiscountAmount") or 0
		cachedGameRules.instantBuildRange = spGetGameRulesParam("overridePregameBuildDistance")
			or DEFAULT_INSTANT_BUILD_RANGE
		cachedGameRules.budgetThresholdToAllowStart = spGetGameRulesParam("quickStartBudgetThresholdToAllowStart") or 0
		cachedGameRules.metalDeduction = spGetGameRulesParam("quickStartMetalDeduction") or 800
		cachedGameRules.traversabilityGridRange = spGetGameRulesParam("quickStartTraversabilityGridRange")
			or DEFAULT_TRAVERSABILITY_GRID_RANGE
		lastRulesUpdate = currentTime
	end
	return cachedGameRules
end

local function createBuildRangeCircleDisplayList(commanderX, commanderZ, buildRadius)
	return gl.CreateList(function()
		gl.LineWidth(2)
		gl.Color(1.0, 0.0, 1.0, 0.7)
		local y = Spring.GetGroundHeight(commanderX, commanderZ) + 10
		gl.DrawGroundCircle(commanderX, y, commanderZ, buildRadius, 64)
		gl.Color(1, 1, 1, 1)
		gl.LineWidth(1)
	end)
end

local function updateDisplayList(commanderX, commanderZ)
	if overlapLinesDisplayList then
		gl.DeleteList(overlapLinesDisplayList)
		overlapLinesDisplayList = nil
	end

	local gameRules = getCachedGameRules()
	local buildRadius = gameRules.instantBuildRange or DEFAULT_INSTANT_BUILD_RANGE

	if #cachedOverlapLines == 0 then
		overlapLinesDisplayList = createBuildRangeCircleDisplayList(commanderX, commanderZ, buildRadius)
		return
	end

	local drawingSegments = overlapLines.getDrawingSegments(cachedOverlapLines, commanderX, commanderZ, buildRadius)
	if not drawingSegments or #drawingSegments == 0 then
		overlapLinesDisplayList = createBuildRangeCircleDisplayList(commanderX, commanderZ, buildRadius)
		return
	end

	overlapLinesDisplayList = gl.CreateList(function()
		gl.LineWidth(2)
		gl.Color(1.0, 0.0, 1.0, 0.7)

		for _, segment in ipairs(drawingSegments) do
			local segmentStart = segment.p1
			local segmentEnd = segment.p2

			local subdivisionCount = 20
			local deltaX = (segmentEnd.x - segmentStart.x) / subdivisionCount
			local deltaZ = (segmentEnd.z - segmentStart.z) / subdivisionCount

			gl.BeginEnd(GL.LINE_STRIP, function()
				for stepIndex = 0, subdivisionCount do
					local x = segmentStart.x + deltaX * stepIndex
					local z = segmentStart.z + deltaZ * stepIndex
					local y = Spring.GetGroundHeight(x, z) + 10
					gl.Vertex(x, y, z)
				end
			end)
		end

		gl.Color(1, 1, 1, 1)
		gl.LineWidth(1)
	end)
end

---@class QuickStartBudgetBarElements
---@field fillElement RmlUi.Element?
---@field projectedElement RmlUi.Element?

---@class QuickStartWarningElements
---@field warningText RmlUi.Element?
---@field factoryText RmlUi.Element?

---@class QuickStartWidgetState
---@field rmlContext RmlUi.Context?
---@field dmHandle any
---@field document RmlUi.Document?
---@field lastUpdate number
---@field updateInterval number
---@field lastQueueLength integer
---@field budgetBarElements QuickStartBudgetBarElements
---@field lastBudgetRemaining number
---@field deductionElements RmlUi.Element[]
---@field currentDeductionIndex integer
---@field warningsHidden boolean
---@field warningElements QuickStartWarningElements
---@field lastFactoryAlreadyPlaced boolean?
---@field lastWidgetUpdate number
---@field widgetUpdateInterval number
---@field refundOverlayElement RmlUi.Element?

---@type QuickStartWidgetState
local widgetState = {
	rmlContext = nil,
	dmHandle = nil,
	document = nil,
	lastUpdate = 0.0,
	updateInterval = 0.15,
	lastQueueLength = 0,
	budgetBarElements = {
		fillElement = nil,
		projectedElement = nil,
	},
	lastBudgetRemaining = 0.0,
	deductionElements = {},
	currentDeductionIndex = 1,
	warningsHidden = false,
	warningElements = {
		warningText = nil,
		factoryText = nil,
	},
	lastFactoryAlreadyPlaced = nil,
	lastWidgetUpdate = 0.0,
	widgetUpdateInterval = 0.2,
}

local factoryUnitDefIDs = {}

local initialModel = {
	budgetTotal = 0,
	budgetUsed = 0,
	budgetRemaining = 0,
	budgetPercent = 0,
	budgetProjected = 0,
	budgetProjectedPercent = 0,
	deductionAmount1 = "", --we have multiple to allow multiple deduction animations to play simultaneously.
	deductionAmount2 = "",
	deductionAmount3 = "",
	deductionAmount4 = "",
	deductionAmount5 = "",
	actualStartingMetal = 0,
}

local function calculateBudgetWithDiscount(unitDefID, factoryDiscountAmount, shouldApplyDiscount, isFirstFactory)
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then
		return 0
	end

	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	local buildTime = unitDef.buildTime or 0
	local budgetCost = calculateBudgetCost(metalCost, energyCost, buildTime)

	return quickStart.applyFactoryDiscount(
		budgetCost,
		unitDef.isFactory,
		factoryDiscountAmount,
		isFirstFactory and shouldApplyDiscount
	)
end

local function isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, instantBuildRange)
	return quickStart.isWithinInstantBuildRange(
		commanderX,
		commanderZ,
		buildX,
		buildZ,
		instantBuildRange,
		cachedOverlapLines,
		function(positionX, positionZ)
			return traversabilityGrid.canMoveToPosition(
				"myGrid",
				positionX,
				positionZ,
				GRID_CHECK_RESOLUTION_MULTIPLIER
			)
		end
	)
end

local function updateTraversabilityGrid()
	local myTeamID = spGetMyTeamID()
	if not myTeamID then
		return false
	end

	local startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")
	if not startDefID then
		return false
	end

	local commanderX, commanderY, commanderZ = Spring.GetTeamStartPosition(myTeamID)
	-- Returns 0, 0, 0 when none chosen (was -100, -100, -100 previously)
	local startChosen = (commanderX ~= 0) or (commanderY ~= 0) or (commanderZ ~= 0)
	if not startChosen then
		if overlapLinesDisplayList then
			gl.DeleteList(overlapLinesDisplayList)
			overlapLinesDisplayList = nil
		end
		hasOverlapLines = false
		lastCommanderX = nil
		lastCommanderZ = nil
		return false
	end

	local commanderPositionChanged = lastCommanderX ~= commanderX or lastCommanderZ ~= commanderZ
	local spawnPositionsChanged = externalSpawnPositionsChanged
	if commanderPositionChanged or spawnPositionsChanged then
		externalSpawnPositionsChanged = false
		local gameRules = getCachedGameRules()
		traversabilityGrid.generateTraversableGrid(
			commanderX,
			commanderZ,
			gameRules.traversabilityGridRange,
			TRAVERSABILITY_GRID_RESOLUTION,
			"myGrid"
		)

		local neighbors = {}
		for otherTeamID, pos in pairs(externalSpawnPositions) do
			if otherTeamID ~= myTeamID and pos.x and pos.z then
				table.insert(neighbors, { x = pos.x, z = pos.z })
			end
		end

		local gameRules = getCachedGameRules()
		local newOverlapLines = overlapLines.getOverlapLines(
			commanderX,
			commanderZ,
			neighbors,
			gameRules.instantBuildRange or DEFAULT_INSTANT_BUILD_RANGE
		)

		local linesChanged = linesHaveChanged(newOverlapLines, previousOverlapLines)
		if linesChanged then
			previousOverlapLines = {}
			for i, line in ipairs(newOverlapLines) do
				previousOverlapLines[i] = {
					A = line.A,
					B = line.B,
					C = line.C,
					originVal = line.originVal,
				}
			end
		end

		cachedOverlapLines = newOverlapLines
		hasOverlapLines = true
		updateDisplayList(commanderX, commanderZ)

		lastCommanderX = commanderX
		lastCommanderZ = commanderZ
	end

	return commanderPositionChanged
end

local function getBuildingDimensions(unitDefID, facing)
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then
		return 0, 0
	end

	if facing % 2 == 1 then
		return SQUARE_SIZE * unitDef.zsize, SQUARE_SIZE * unitDef.xsize
	end

	return SQUARE_SIZE * unitDef.xsize, SQUARE_SIZE * unitDef.zsize
end

local function doBuildingsClash(firstBuildData, secondBuildData)
	local firstWidth, firstDepth = getBuildingDimensions(firstBuildData[1], firstBuildData[5])
	local secondWidth, secondDepth = getBuildingDimensions(secondBuildData[1], secondBuildData[5])
	local xDistance = math.abs(firstBuildData[2] - secondBuildData[2])
	local zDistance = math.abs(firstBuildData[4] - secondBuildData[4])

	return xDistance < (firstWidth + secondWidth) * 0.5 and zDistance < (firstDepth + secondDepth) * 0.5
end

local function isBuildPositionOpen(buildQueue, unitDefID, buildX, buildY, buildZ, facing)
	if Spring.TestBuildOrder(unitDefID, buildX, buildY, buildZ, facing) ~= UNOCCUPIED then
		return false
	end

	local buildData = { unitDefID, buildX, buildY, buildZ, facing }
	for buildIndex = 1, #buildQueue do
		if doBuildingsClash(buildData, buildQueue[buildIndex]) then
			return false
		end
	end

	return true
end

local function getCommanderBuildDefs(startDefID)
	local commanderDef = UnitDefs[startDefID]
	if not commanderDef then
		return nil
	end
	return quickStart.getCommanderBuildDefs(commanderDef.name)
end

local function calculateCheapestFactoryBudgetCost(startDefID, gameRules)
	local commanderDef = UnitDefs[startDefID]
	if not commanderDef then
		return 0
	end

	local cheapestFactoryBudgetCost = math.huge
	for buildOptionIndex = 1, #commanderDef.buildOptions do
		local unitDefID = commanderDef.buildOptions[buildOptionIndex]
		local unitDef = UnitDefs[unitDefID]
		if unitDef and unitDef.isFactory then
			local factoryBudgetCost = calculateBudgetWithDiscount(
				unitDefID,
				gameRules.factoryDiscountAmount,
				shouldApplyFactoryDiscount,
				true
			)
			cheapestFactoryBudgetCost = math.min(cheapestFactoryBudgetCost, factoryBudgetCost)
		end
	end

	if cheapestFactoryBudgetCost == math.huge then
		return 0
	end

	return math.ceil(cheapestFactoryBudgetCost)
end

local function getNearbyMexes(commanderX, commanderZ, instantBuildRange)
	local resourceSpotFinder = WG.resource_spot_finder
	if not resourceSpotFinder or resourceSpotFinder.isMetalMap or not resourceSpotFinder.metalSpotsList then
		return {}
	end

	return quickStart.getNearbyMexes(
		commanderX,
		commanderZ,
		instantBuildRange,
		resourceSpotFinder.metalSpotsList,
		cachedOverlapLines,
		function(buildX, buildZ)
			return traversabilityGrid.canMoveToPosition("myGrid", buildX, buildZ, GRID_CHECK_RESOLUTION_MULTIPLIER)
		end
	)
end

local function getBuildSpace(context, buildQueue, buildType)
	return quickStart.getBuildSpace(context, buildType, function(unitDefID, buildX, buildY, buildZ, facing)
		return isBuildPositionOpen(buildQueue, unitDefID, buildX, buildY, buildZ, facing)
	end)
end

local function getPlayerBuildQueue(buildQueue)
	local playerBuildQueue = {}
	for buildIndex = 1, #buildQueue do
		local buildData = buildQueue[buildIndex]
		if not buildData[QUICK_START_GENERATED_KEY] then
			playerBuildQueue[#playerBuildQueue + 1] = buildData
		end
	end
	return playerBuildQueue
end

local function getBuildQueueBudgetRemaining(buildQueue, gameRules, commanderX, commanderZ)
	local budgetRemaining = gameRules.budgetTotal
	local firstFactoryPlaced = false
	local factoryAlreadyQueued = false

	for buildIndex = 1, #buildQueue do
		local buildData = buildQueue[buildIndex]
		local unitDefID = buildData[1]
		local unitDef = unitDefID and unitDefID > 0 and UnitDefs[unitDefID]
		if unitDef then
			if unitDef.isFactory then
				factoryAlreadyQueued = true
			end
			if isWithinBuildRange(commanderX, commanderZ, buildData[2], buildData[4], gameRules.instantBuildRange) then
				local buildCost = calculateBudgetWithDiscount(
					unitDefID,
					gameRules.factoryDiscountAmount,
					shouldApplyFactoryDiscount,
					not firstFactoryPlaced
				)
				budgetRemaining = math.max(0, budgetRemaining - buildCost)
				if unitDef.isFactory and not firstFactoryPlaced then
					firstFactoryPlaced = true
				end
			end
		end
	end

	return budgetRemaining, factoryAlreadyQueued
end

local function createPreloadedBuildQueue(startDefID, commanderX, commanderZ, playerBuildQueue)
	local buildDefs = getCommanderBuildDefs(startDefID)
	if not buildDefs then
		return playerBuildQueue
	end

	local resourceSpotFinder = WG.resource_spot_finder
	local isMetalMap = resourceSpotFinder and resourceSpotFinder.isMetalMap or false
	local groundY = Spring.GetGroundHeight(commanderX, commanderZ)
	local isInWater = groundY < 0
	local gameRules = getCachedGameRules()
	local context = {
		baseGenerationRange = selectedAmountConfig.baseGenerationRange,
		buildDefID = isInWater and buildDefs.tidal or buildDefs.windmill,
		buildDefs = buildDefs,
		canMoveToPosition = function(buildX, buildZ)
			return traversabilityGrid.canMoveToPosition("myGrid", buildX, buildZ, GRID_CHECK_RESOLUTION_MULTIPLIER)
		end,
		commanderX = commanderX,
		commanderY = groundY,
		commanderZ = commanderZ,
		defaultFacing = quickStart.getDefaultFacing(commanderX, commanderZ),
		gridLists = {},
		isMetalMap = isMetalMap,
		nearbyMexes = getNearbyMexes(commanderX, commanderZ, gameRules.instantBuildRange),
		overlapLines = cachedOverlapLines,
	}
	local localGrid = quickStart.generateLocalGrid(context)
	context.gridLists = quickStart.generateBaseNodesFromLocalGrid(context, localGrid)

	local buildQueue = {}
	for buildIndex = 1, #playerBuildQueue do
		buildQueue[#buildQueue + 1] = playerBuildQueue[buildIndex]
	end
	local buildSequence = quickStart.getBuildSequence(isMetalMap, isInWater, windFunctions.isGoodWind())
	local budgetRemaining, factoryAlreadyPlaced =
		getBuildQueueBudgetRemaining(buildQueue, gameRules, commanderX, commanderZ)
	local factoryBudgetReserve = factoryAlreadyPlaced and 0 or calculateCheapestFactoryBudgetCost(startDefID, gameRules)
	local buildIndex = 1
	local attempts = 0

	while budgetRemaining > factoryBudgetReserve and attempts < SAFETY_COUNT do
		attempts = attempts + 1
		local buildType = buildSequence[buildIndex]
		local unitDefID = buildDefs[buildType]
		local unitDef = unitDefID and UnitDefs[unitDefID]
		local buildCost = unitDef
				and calculateBudgetCost(unitDef.metalCost or 0, unitDef.energyCost or 0, unitDef.buildTime or 0)
			or math.huge

		if buildCost > budgetRemaining - factoryBudgetReserve then
			break
		end

		local buildX, buildY, buildZ = getBuildSpace(context, buildQueue, buildType)
		if buildX then
			local generatedBuildData = {
				unitDefID,
				buildX,
				buildY,
				buildZ,
				context.defaultFacing,
				[QUICK_START_GENERATED_KEY] = true,
			}
			buildQueue[#buildQueue + 1] = generatedBuildData
			budgetRemaining = budgetRemaining - buildCost
		end

		buildIndex = buildIndex % #buildSequence + 1
	end

	return buildQueue
end

local function populatePreloadedBuildQueue(commanderPositionChanged)
	if not autoGenerateSuggestions then
		return false
	end

	local myTeamID = spGetMyTeamID()
	if not myTeamID or not wgPregameBuild or not wgPregameBuild.setBuildQueue then
		return false
	end

	local commanderX, commanderY, commanderZ = Spring.GetTeamStartPosition(myTeamID)
	local startChosen = (commanderX ~= 0) or (commanderY ~= 0) or (commanderZ ~= 0)
	if not startChosen then
		lastPreloadedCommanderX = nil
		lastPreloadedCommanderZ = nil
		return false
	end

	local positionNeedsPreload = commanderPositionChanged
		or lastPreloadedCommanderX ~= commanderX
		or lastPreloadedCommanderZ ~= commanderZ
	if not positionNeedsPreload then
		return false
	end

	local startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")
	if not startDefID then
		return false
	end

	local currentBuildQueue = wgPregameBuild.getBuildQueue and wgPregameBuild.getBuildQueue() or {}
	local playerBuildQueue = getPlayerBuildQueue(currentBuildQueue)
	local buildQueue = createPreloadedBuildQueue(startDefID, commanderX, commanderZ, playerBuildQueue)
	wgPregameBuild.setBuildQueue(buildQueue)
	if wgPregameBuild.forceRefresh then
		wgPregameBuild.forceRefresh()
	end
	lastPreloadedCommanderX = commanderX
	lastPreloadedCommanderZ = commanderZ
	return true
end

local function updateUIElementText(document, elementId, text)
	local element = document:GetElementById(elementId)
	if element then
		element.inner_rml = text
	end
end

local function showDeductionAnimation(deductionAmount)
	local currentIndex = widgetState.currentDeductionIndex
	local deductionElement = widgetState.deductionElements[currentIndex]

	if not deductionElement or not widgetState.dmHandle then
		return
	end

	local nextIndex = currentIndex % 5 + 1
	local nextElement = widgetState.deductionElements[nextIndex]

	if nextElement then
		nextElement:SetClass("animate", false) -- we have to remove the animate class on a different frame than we add it, otherwise it doesn't play.
	end

	local modelKey = "deductionAmount" .. currentIndex
	widgetState.dmHandle[modelKey] = "-" .. tostring(math.floor(deductionAmount))

	deductionElement:SetClass("animate", true)

	widgetState.currentDeductionIndex = nextIndex
end

local function createBudgetBarElements()
	if not widgetState.document then
		return
	end

	local fillElement = widgetState.document:GetElementById("qs-budget-fill")
	local projectedElement = widgetState.document:GetElementById("qs-budget-projected")

	if fillElement and projectedElement then
		widgetState.budgetBarElements.fillElement = fillElement
		widgetState.budgetBarElements.projectedElement = projectedElement
	end

	for i = 1, 5 do
		local deductionElement = widgetState.document:GetElementById("qs-deduction-amount-" .. i)
		if deductionElement then
			widgetState.deductionElements[i] = deductionElement
		end
	end

	local warningTextElement = widgetState.document:GetElementById("qs-warning-text")
	local factoryTextElement = widgetState.document:GetElementById("qs-factory-text")
	local refundOverlayElement = widgetState.document:GetElementById("qs-budget-refund-overlay")

	if warningTextElement then
		widgetState.warningElements.warningText = warningTextElement
	end
	if factoryTextElement then
		widgetState.warningElements.factoryText = factoryTextElement
	end
	if refundOverlayElement then
		widgetState.refundOverlayElement = refundOverlayElement
	end
end

local function calculateBudgetForItem(unitDefID, gameRules, shouldApplyDiscount, isFirstFactory)
	if not unitDefID or unitDefID <= 0 or not UnitDefs[unitDefID] then
		return 0
	end
	return calculateBudgetWithDiscount(unitDefID, gameRules.factoryDiscountAmount, shouldApplyDiscount, isFirstFactory)
end

local function getCommanderPosition(myTeamID)
	local commanderX, commanderY, commanderZ = Spring.GetTeamStartPosition(myTeamID)
	return commanderX or 0, commanderZ or 0
end

local function computeProjectedUsage()
	local myTeamID = spGetMyTeamID()
	local gameRules = getCachedGameRules()
	local pregame = wgGetBuildQueueFunc and wgGetBuildQueueFunc() or {}
	local pregameUnitSelected = wgGetPregameUnitSelectedFunc and wgGetPregameUnitSelectedFunc() or -1

	local budgetUsed = 0
	local firstFactoryPlaced = false
	local commanderX, commanderZ = getCommanderPosition(myTeamID)

	if pregame and #pregame > 0 then
		for i = 1, #pregame do
			local item = pregame[i]
			if item then
				local defID = item[1]
				local buildX, buildZ = item[2], item[4]

				if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
					local budgetCost =
						calculateBudgetForItem(defID, gameRules, shouldApplyFactoryDiscount, not firstFactoryPlaced)
					budgetUsed = budgetUsed + budgetCost

					local queuedUnitDef = UnitDefs[defID]
					if queuedUnitDef and queuedUnitDef.isFactory and not firstFactoryPlaced then
						firstFactoryPlaced = true
					end
				end
			end
		end
	end

	local budgetProjected = 0
	local uDef = pregameUnitSelected > 0 and UnitDefs[pregameUnitSelected]
	if uDef then
		local mx, my = Spring.GetMouseState()

		local positionsToCheck = {}
		local getBuildPositions = wgGetBuildPositionsFunc
		local buildPositions = getBuildPositions and getBuildPositions() or nil

		if buildPositions and #buildPositions > 0 then
			positionsToCheck = buildPositions
		else
			local _, pos = Spring.TraceScreenRay(mx, my, true, false, false, uDef.modCategories.underwater)
			if pos then
				positionsToCheck = { { x = pos[1], y = pos[2], z = pos[3] } }
			end
		end

		local canApplyFactoryDiscount = not firstFactoryPlaced and uDef.isFactory and shouldApplyFactoryDiscount
		local isMultiUnitMode = buildPositions and #buildPositions > 0
		local isFirstFactoryInMultiUnit = isMultiUnitMode and canApplyFactoryDiscount

		for _, pos in ipairs(positionsToCheck) do
			if isWithinBuildRange(commanderX, commanderZ, pos.x, pos.z, gameRules.instantBuildRange) then
				local isFirstFactory = isFirstFactoryInMultiUnit or (not isMultiUnitMode and canApplyFactoryDiscount)
				local cost =
					calculateBudgetForItem(pregameUnitSelected, gameRules, shouldApplyFactoryDiscount, isFirstFactory)
				budgetProjected = budgetProjected + cost
				if isFirstFactory then
					isFirstFactoryInMultiUnit = false
				end
			end
		end
	end

	local budgetRemaining = math.max(0, gameRules.budgetTotal - budgetUsed)
	local budgetPercent = gameRules.budgetTotal > 0
			and math.max(0, math.min(100, (budgetRemaining / gameRules.budgetTotal) * 100))
		or 0
	local projectedPercent = gameRules.budgetTotal > 0
			and math.max(0, math.min(100, (budgetProjected / gameRules.budgetTotal) * 100))
		or 0
	local metalDeduction = gameRules.metalDeduction or 800
	local actualStartingMetal = startingMetal - metalDeduction + budgetRemaining

	return {
		budgetTotal = gameRules.budgetTotal,
		budgetUsed = budgetUsed,
		budgetRemaining = budgetRemaining,
		budgetPercent = budgetPercent,
		budgetProjected = budgetProjected,
		budgetProjectedPercent = projectedPercent,
		actualStartingMetal = actualStartingMetal,
	}
end

local function hideWarnings()
	if widgetState.warningsHidden then
		return
	end

	widgetState.warningsHidden = true

	if widgetState.warningElements.warningText then
		widgetState.warningElements.warningText:SetAttribute("style", "opacity: 0;")
	end
	if widgetState.warningElements.factoryText then
		widgetState.warningElements.factoryText:SetAttribute("style", "opacity: 0;")
	end
end

local function updateUnitCostOverride(unitDefID, unitDef, gameRules, factoryAlreadyPlaced)
	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	local buildTime = unitDef.buildTime or 0
	local budgetCost = calculateBudgetCost(metalCost, energyCost, buildTime)

	if unitDef.isFactory and shouldApplyFactoryDiscount and not factoryAlreadyPlaced then
		budgetCost =
			calculateBudgetWithDiscount(unitDefID, gameRules.factoryDiscountAmount, shouldApplyFactoryDiscount, true)
	end

	local costOverride = {
		top = { disabled = true },
		bottom = {
			value = budgetCost,
			color = "\255\255\110\255",
			colorDisabled = "\255\200\50\200",
		},
	}

	if wgBuildMenu and wgBuildMenu.setCostOverride then
		wgBuildMenu.setCostOverride(unitDefID, costOverride)
	end
	if wgGridMenu and wgGridMenu.setCostOverride then
		wgGridMenu.setCostOverride(unitDefID, costOverride)
	end
end

local function updateAllCostOverrides(force)
	local myTeamID = spGetMyTeamID()
	local gameRules = getCachedGameRules()
	local buildQueue = wgPregameBuild and wgPregameBuild.getBuildQueue and wgPregameBuild.getBuildQueue() or {}

	local factoryAlreadyPlaced = false
	local commanderX, commanderZ = getCommanderPosition(myTeamID)

	for i = 1, #buildQueue do
		local queueItem = buildQueue[i]
		if queueItem then
			local unitDefID = queueItem[1]
			local unitDef = unitDefID and unitDefID > 0 and UnitDefs[unitDefID]
			if unitDef then
				local buildX, buildZ = queueItem[2], queueItem[4]
				if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
					if unitDef.isFactory then
						factoryAlreadyPlaced = true
						break
					end
				end
			end
		end
	end

	if not force and widgetState.lastFactoryAlreadyPlaced == factoryAlreadyPlaced then
		return
	end

	local stateChanged = (widgetState.lastFactoryAlreadyPlaced ~= nil)
		and (widgetState.lastFactoryAlreadyPlaced ~= factoryAlreadyPlaced)
	widgetState.lastFactoryAlreadyPlaced = factoryAlreadyPlaced

	if not force and stateChanged then
		for _, unitDefID in ipairs(factoryUnitDefIDs) do
			local unitDef = UnitDefs[unitDefID]
			updateUnitCostOverride(unitDefID, unitDef, gameRules, factoryAlreadyPlaced)
		end
	else
		for unitDefID, unitDef in pairs(UnitDefs) do
			updateUnitCostOverride(unitDefID, unitDef, gameRules, factoryAlreadyPlaced)
		end
	end
end

local function updateDataModel(forceUpdate)
	if not widgetState.dmHandle then
		return
	end

	local buildQueue = wgPregameBuild and wgPregameBuild.getBuildQueue and wgPregameBuild.getBuildQueue() or {}
	local currentQueueLength = #buildQueue
	local currentTime = os.clock()

	if
		not forceUpdate
		and widgetState.lastQueueLength == currentQueueLength
		and (currentTime - widgetState.lastUpdate) < widgetState.updateInterval
	then
		return
	end

	widgetState.lastUpdate = currentTime

	local modelUpdate = computeProjectedUsage()
	local currentBudgetRemaining = modelUpdate.budgetRemaining or 0

	if forceUpdate or currentQueueLength ~= widgetState.lastQueueLength then
		updateAllCostOverrides(forceUpdate)
	end

	if currentQueueLength > widgetState.lastQueueLength then
		if currentBudgetRemaining < widgetState.lastBudgetRemaining then
			if modelUpdate.budgetTotal >= modelUpdate.budgetUsed then
				Spring.PlaySoundFile("beep6", 0.5, nil, nil, nil, nil, nil, nil, "ui")
			else
				Spring.PlaySoundFile("cmd-build", 0.5, nil, nil, nil, nil, nil, nil, "ui")
			end
		elseif widgetState.lastBudgetRemaining == currentBudgetRemaining then
			Spring.PlaySoundFile("cmd-build", 1.0, nil, nil, nil, nil, nil, nil, "ui")
		end
	end

	if widgetState.lastBudgetRemaining > currentBudgetRemaining then
		local deductionAmount = widgetState.lastBudgetRemaining - currentBudgetRemaining
		showDeductionAnimation(deductionAmount)
		hideWarnings()
	end

	widgetState.lastQueueLength = currentQueueLength
	widgetState.lastBudgetRemaining = currentBudgetRemaining

	local gameRules = getCachedGameRules()
	local budgetThreshold = gameRules.budgetThresholdToAllowStart or 0
	local budgetUsed = modelUpdate.budgetUsed or 0
	local noBudgetUsed = budgetUsed == 0
	local insufficientBudgetSpent = currentBudgetRemaining > budgetThreshold
	local shouldBlockReady = noBudgetUsed or insufficientBudgetSpent

	if wgPregameUI and wgPregameUI.addReadyCondition and wgPregameUI.removeReadyCondition then
		if shouldBlockReady then
			wgPregameUI.addReadyCondition(QUICK_START_CONDITION_KEY, "ui.quickStart.unallocatedBudget")
		else
			wgPregameUI.removeReadyCondition(QUICK_START_CONDITION_KEY)
		end
	end
	if wgPregameUIDraft and wgPregameUIDraft.addReadyCondition and wgPregameUIDraft.removeReadyCondition then
		if shouldBlockReady then
			wgPregameUIDraft.addReadyCondition(QUICK_START_CONDITION_KEY, "ui.quickStart.unallocatedBudget")
		else
			wgPregameUIDraft.removeReadyCondition(QUICK_START_CONDITION_KEY)
		end
	end

	if widgetState.refundOverlayElement then
		local shouldShowRefund = not noBudgetUsed and currentBudgetRemaining <= budgetThreshold
		if shouldShowRefund then
			widgetState.refundOverlayElement:SetAttribute("style", "opacity: 1;")
		else
			widgetState.refundOverlayElement:SetAttribute("style", "opacity: 0;")
		end
	end

	for key, value in pairs(modelUpdate) do
		widgetState.dmHandle[key] = value
	end

	if widgetState.document then
		local budgetPercent = widgetState.dmHandle.budgetPercent or 0
		local budgetRemaining = math.floor(widgetState.dmHandle.budgetRemaining or 0)

		if widgetState.budgetBarElements.fillElement then
			widgetState.budgetBarElements.fillElement:SetAttribute(
				"style",
				"width: " .. string.format("%.1f%%", budgetPercent)
			)
		end

		if widgetState.budgetBarElements.projectedElement then
			local budgetProjectedPercent = widgetState.dmHandle.budgetProjectedPercent or 0
			local overlayWidth = math.min(budgetProjectedPercent, budgetPercent)
			local overlayLeft = math.max(0, budgetPercent - overlayWidth)
			local style = string.format("left: %.1f%%; width: %.1f%%;", overlayLeft, overlayWidth)
			widgetState.budgetBarElements.projectedElement:SetAttribute("style", style)
		end

		updateUIElementText(widgetState.document, "qs-budget-value-left", tostring(budgetRemaining))

		local actualStartingMetal = math.floor(widgetState.dmHandle.actualStartingMetal or 0)
		updateUIElementText(
			widgetState.document,
			"qs-budget-refund-overlay",
			"You will start with " .. actualStartingMetal .. " metal."
		)
	end
end

local function getBuildQueueSpawnStatus(buildQueue, selectedBuildData)
	local myTeamID = spGetMyTeamID()
	local gameRules = getCachedGameRules()
	local spawnResults = {
		queueSpawned = {},
		selectedSpawned = false,
	}

	local remainingBudget = gameRules.budgetTotal
	local firstFactoryPlaced = false
	local commanderX, commanderZ = getCommanderPosition(myTeamID)

	if buildQueue and #buildQueue > 0 then
		for i = 1, #buildQueue do
			local queueItem = buildQueue[i]
			local isSpawned = false
			if queueItem then
				local unitDefID = queueItem[1]
				local unitDef = unitDefID and unitDefID > 0 and UnitDefs[unitDefID]
				if unitDef then
					local buildX, buildZ = queueItem[2], queueItem[4]

					if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
						local budgetCost = calculateBudgetForItem(
							unitDefID,
							gameRules,
							shouldApplyFactoryDiscount,
							not firstFactoryPlaced
						)

						if remainingBudget >= budgetCost then
							isSpawned = true
							remainingBudget = remainingBudget - budgetCost

							if unitDef.isFactory and not firstFactoryPlaced then
								firstFactoryPlaced = true
							end
						end
					end
				end
			end

			spawnResults.queueSpawned[i] = isSpawned
		end
	end
	if selectedBuildData and selectedBuildData[1] and selectedBuildData[1] > 0 then
		local unitDefID = selectedBuildData[1]
		local buildX, buildZ = selectedBuildData[2], selectedBuildData[4]

		if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
			local budgetCost =
				calculateBudgetForItem(unitDefID, gameRules, shouldApplyFactoryDiscount, not firstFactoryPlaced)
			spawnResults.selectedSpawned = remainingBudget >= budgetCost
		else
			spawnResults.selectedSpawned = false
		end
	end

	return spawnResults
end

local function setAutoGenerateSuggestions(enabled)
	autoGenerateSuggestions = enabled and true or false
	Spring.SetConfigInt(AUTO_GENERATE_SUGGESTIONS_CONFIG, autoGenerateSuggestions and 1 or 0)
	lastPreloadedCommanderX = nil
	lastPreloadedCommanderZ = nil
	if not wgPregameBuild or not wgPregameBuild.setBuildQueue then
		return
	end
	if autoGenerateSuggestions then
		lastCommanderX = nil
		lastCommanderZ = nil
		updateTraversabilityGrid()
		if populatePreloadedBuildQueue(true) then
			updateDataModel(true)
		end
		return
	end
	local currentBuildQueue = wgPregameBuild.getBuildQueue and wgPregameBuild.getBuildQueue() or {}
	wgPregameBuild.setBuildQueue(getPlayerBuildQueue(currentBuildQueue))
	if wgPregameBuild.forceRefresh then
		wgPregameBuild.forceRefresh()
	end
	updateDataModel(true)
end

function widget:Initialize()
	local isSpectating = Spring.GetSpectatingState()
	if isSpectating then
		widgetHandler:RemoveWidget(self)
	end

	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		return false
	end

	local dm = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dm then
		return false
	end
	widgetState.dmHandle = dm

	local document = widgetState.rmlContext:LoadDocument(RML_PATH)
	if not document then
		widget:Shutdown()
		return false
	end
	widgetState.document = document
	document:Show()

	wgBuildMenu = WG.buildmenu
	wgGridMenu = WG.gridmenu
	wgTopbar = WG.topbar
	wgPregameBuild = WG["pregame-build"]
	wgPregameUI = WG.pregameui
	wgPregameUIDraft = WG.pregameui_draft
	wgGetBuildQueueFunc = wgPregameBuild and wgPregameBuild.getBuildQueue
	wgGetBuildPositionsFunc = wgPregameBuild and wgPregameBuild.getBuildPositions
	wgGetPregameUnitSelectedFunc = function()
		return WG["pregame-unit-selected"] or -1
	end

	updateUIElementText(document, "qs-budget-header", spI18N("ui.quickStart.preGameResources"))
	updateUIElementText(document, "qs-warning-text", spI18N("ui.quickStart.remainingResourcesWarning"))

	local factoryTextElement = document:GetElementById("qs-factory-text")
	if factoryTextElement then
		if shouldApplyFactoryDiscount then
			updateUIElementText(document, "qs-factory-text", spI18N("ui.quickStart.placeDiscountedFactory"))
			factoryTextElement:SetClass("visible", true)
		else
			factoryTextElement:SetAttribute("style", "display: none;")
		end
	end

	createBudgetBarElements()

	local warningTextElement = document:GetElementById("qs-warning-text")
	if warningTextElement then
		warningTextElement:SetClass("visible", true)
	end

	if wgTopbar and wgTopbar.setResourceBarsVisible then
		wgTopbar.setResourceBarsVisible(false)
	end

	WG.getBuildQueueSpawnStatus = getBuildQueueSpawnStatus
	WG.quick_start_updateSpawnPositions = updateSpawnPositions
	WG.quickStart = {
		getAutoGenerateSuggestions = function()
			return autoGenerateSuggestions
		end,
		setAutoGenerateSuggestions = setAutoGenerateSuggestions,
	}

	for id, def in pairs(UnitDefs) do
		if def.isFactory then
			table.insert(factoryUnitDefIDs, id)
		end
	end

	updateAllCostOverrides(true)

	updateDataModel(true)
	if not autoGenerateSuggestions then
		setAutoGenerateSuggestions(false)
	end
	return true
end

function widget:Shutdown()
	if wgTopbar and wgTopbar.setResourceBarsVisible then
		wgTopbar.setResourceBarsVisible(true)
	end

	WG.getBuildQueueSpawnStatus = nil
	WG.quick_start_updateSpawnPositions = nil
	WG.quickStart = nil

	if wgBuildMenu and wgBuildMenu.clearCostOverrides then
		wgBuildMenu.clearCostOverrides()
	end
	if wgGridMenu and wgGridMenu.clearCostOverrides then
		wgGridMenu.clearCostOverrides()
	end

	if wgPregameUI and wgPregameUI.removeReadyCondition then
		wgPregameUI.removeReadyCondition(QUICK_START_CONDITION_KEY)
	end
	if wgPregameUIDraft and wgPregameUIDraft.removeReadyCondition then
		wgPregameUIDraft.removeReadyCondition(QUICK_START_CONDITION_KEY)
	end

	if widgetState.rmlContext and widgetState.dmHandle then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
		widgetState.dmHandle = nil
	end
	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end
	if overlapLinesDisplayList then
		gl.DeleteList(overlapLinesDisplayList)
		overlapLinesDisplayList = nil
	end
	widgetState.rmlContext = nil
end

function widget:Update()
	local currentGameFrame = Spring.GetGameFrame()
	if currentGameFrame > 0 then
		hideWarnings()
		if wgTopbar and wgTopbar.setResourceBarsVisible then
			wgTopbar.setResourceBarsVisible(true)
		end
		widgetHandler:RemoveWidget(self)
		return
	end

	updateDataModel(false)
	local currentTime = os.clock()
	if (currentTime - widgetState.lastWidgetUpdate) < widgetState.widgetUpdateInterval then
		return
	end
	widgetState.lastWidgetUpdate = currentTime

	local commanderPositionChanged = updateTraversabilityGrid()
	if populatePreloadedBuildQueue(commanderPositionChanged) then
		updateDataModel(true)
	end
end

function widget:DrawWorld()
	if hasOverlapLines and overlapLinesDisplayList then
		gl.CallList(overlapLinesDisplayList)
	end
end

function widget:RecvLuaMsg(message, playerID)
	local document = widgetState.document
	if not document then
		return
	end

	if message:sub(1, 19) == "LobbyOverlayActive0" then
		document:Show()
	elseif message:sub(1, 19) == "LobbyOverlayActive1" then
		document:Hide()
	end
end
