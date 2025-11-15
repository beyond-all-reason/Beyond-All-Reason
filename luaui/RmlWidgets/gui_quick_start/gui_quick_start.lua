if not RmlUi then
	return
end

local widget = widget

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

local shouldRunWidget = modOptions.quick_start == "enabled" or
	modOptions.quick_start == "factory_discount" or
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))

if not shouldRunWidget then
	return false
end

local shouldApplyFactoryDiscount = modOptions.quick_start == "factory_discount" or
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))

local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetMyTeamID = Spring.GetMyTeamID
local spI18N = Spring.I18N

local wgBuildMenu, wgGridMenu, wgTopbar, wgPregameBuild, wgPregameUI, wgPregameUIDraft, wgGetBuildQueueFunc, wgGetBuildPositionsFunc, wgGetPregameUnitSelectedFunc

local MODEL_NAME = "quick_start_model"
local RML_PATH = "luaui/RmlWidgets/gui_quick_start/gui_quick_start.rml"
local QUICK_START_CONDITION_KEY = "quickStartUnallocatedBudget"

local ENERGY_VALUE_CONVERSION_MULTIPLIER = 1/60 --60 being the energy conversion rate of t2 energy converters, statically defined so future changes not to affect this.
local BUILD_TIME_VALUE_CONVERSION_MULTIPLIER = 1/300 --300 being a representative of commander workertime, statically defined so future com unitdef adjustments don't change this.
local DEFAULT_INSTANT_BUILD_RANGE = 500
local TRAVERSABILITY_GRID_GENERATION_RANGE = 576 --must match the value in game_quick_start.lua. It has to be slightly larger than the instant build range to account for traversability_grid snapping at TRAVERSABILITY_GRID_RESOLUTION intervals
local TRAVERSABILITY_GRID_RESOLUTION = 32
local GRID_CHECK_RESOLUTION_MULTIPLIER = 1

local traversabilityGrid = VFS.Include("common/traversability_grid.lua")
local aestheticCustomCostRound = VFS.Include("common/aestheticCustomCostRound.lua")
local customRound = aestheticCustomCostRound.customRound
local lastCommanderX = nil
local lastCommanderZ = nil

local cachedGameRules = {}
local lastRulesUpdate = 0
local RULES_CACHE_DURATION = 0.1

local function calculateBudgetCost(metalCost, energyCost, buildTime)
	return customRound(metalCost + energyCost * ENERGY_VALUE_CONVERSION_MULTIPLIER + buildTime * BUILD_TIME_VALUE_CONVERSION_MULTIPLIER)
end

local widgetState = {
	rmlContext = nil,
	dmHandle = nil,
	document = nil,
	lastUpdate = 0,
	updateInterval = 0.15,
	lastQueueLength = 0,
	budgetBarElements = {
		fillElement = nil,
		projectedElement = nil,
	},
	lastBudgetRemaining = 0,
	deductionElements = {},
	currentDeductionIndex = 1,
	warningsHidden = false,
	warningElements = {
		warningText = nil,
		factoryText = nil,
	},
}

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
}

local function calculateBudgetWithDiscount(unitDefID, factoryDiscountAmount, shouldApplyDiscount, isFirstFactory)
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then return 0 end

	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	local buildTime = unitDef.buildTime or 0
	local budgetCost = calculateBudgetCost(metalCost, energyCost, buildTime)

	if unitDef.isFactory and isFirstFactory and shouldApplyDiscount then
		return math.max(0, budgetCost - factoryDiscountAmount)
	end
	return budgetCost
end

local function isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, instantBuildRange)
	local distance = math.distance2d(commanderX, commanderZ, buildX, buildZ)
	if distance > instantBuildRange then
		return false
	end

	if traversabilityGrid.canMoveToPosition("myGrid", buildX, buildZ, GRID_CHECK_RESOLUTION_MULTIPLIER) then
		return true
	end

	return false
end

local function getCachedGameRules()
	local currentTime = os.clock()
	if currentTime - lastRulesUpdate > RULES_CACHE_DURATION then
		cachedGameRules.budgetTotal = spGetGameRulesParam("quickStartBudgetBase") or 0
		cachedGameRules.factoryDiscountAmount = spGetGameRulesParam("quickStartFactoryDiscountAmount") or 0
		cachedGameRules.instantBuildRange = spGetGameRulesParam("overridePregameBuildDistance") or DEFAULT_INSTANT_BUILD_RANGE
		cachedGameRules.budgetThresholdToAllowStart = spGetGameRulesParam("quickStartBudgetThresholdToAllowStart") or 0
		lastRulesUpdate = currentTime
	end
	return cachedGameRules
end

local function updateTraversabilityGrid()
	local myTeamID = spGetMyTeamID()
	if not myTeamID then
		return
	end

	local startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")
	if not startDefID then
		return
	end

	local commanderX, commanderY, commanderZ = Spring.GetTeamStartPosition(myTeamID)
	if commanderX == -100 then
		return
	end
	if lastCommanderX ~= commanderX or lastCommanderZ ~= commanderZ then
		traversabilityGrid.generateTraversableGrid(commanderX, commanderZ, TRAVERSABILITY_GRID_GENERATION_RANGE, TRAVERSABILITY_GRID_RESOLUTION, "myGrid")
		lastCommanderX = commanderX
		lastCommanderZ = commanderZ
	end
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
	
	if not deductionElement then
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
	
	if warningTextElement then
		widgetState.warningElements.warningText = warningTextElement
	end
	if factoryTextElement then
		widgetState.warningElements.factoryText = factoryTextElement
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
	return commanderX or 0, commanderY or 0, commanderZ or 0
end

local function computeProjectedUsage()
	local myTeamID = spGetMyTeamID()
	local gameRules = getCachedGameRules()
	local pregame = wgGetBuildQueueFunc and wgGetBuildQueueFunc() or {}
	local pregameUnitSelected = wgGetPregameUnitSelectedFunc and wgGetPregameUnitSelectedFunc() or -1

	local budgetUsed = 0
	local firstFactoryPlaced = false
	local commanderX, commanderY, commanderZ = getCommanderPosition(myTeamID)

	if pregame and #pregame > 0 then
		for i = 1, #pregame do
			local item = pregame[i]
			local defID = item[1]
			local buildX, buildZ = item[2], item[4]

			if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
				local budgetCost = calculateBudgetForItem(defID, gameRules, shouldApplyFactoryDiscount, not firstFactoryPlaced)
				budgetUsed = budgetUsed + budgetCost

				if UnitDefs[defID] and UnitDefs[defID].isFactory and not firstFactoryPlaced then
					firstFactoryPlaced = true
				end
			end
		end
	end

	local budgetProjected = 0
	if pregameUnitSelected > 0 and UnitDefs[pregameUnitSelected] then
		local uDef = UnitDefs[pregameUnitSelected]
		local mx, my = Spring.GetMouseState()

		local positionsToCheck = {}
		local getBuildPositions = wgGetBuildPositionsFunc
		local buildPositions = getBuildPositions and getBuildPositions() or nil

		if buildPositions and #buildPositions > 0 then
			positionsToCheck = buildPositions
		else
			local _, pos = Spring.TraceScreenRay(mx, my, true, false, false,
				uDef.modCategories and uDef.modCategories.underwater)
			if pos then
				positionsToCheck = {{x = pos[1], y = pos[2], z = pos[3]}}
			end
		end

		local canApplyFactoryDiscount = not firstFactoryPlaced and uDef.isFactory and shouldApplyFactoryDiscount
		local isMultiUnitMode = buildPositions and #buildPositions > 0
		local isFirstFactoryInMultiUnit = isMultiUnitMode and canApplyFactoryDiscount

		for _, pos in ipairs(positionsToCheck) do
			if isWithinBuildRange(commanderX, commanderZ, pos.x, pos.z, gameRules.instantBuildRange) then
				local isFirstFactory = isFirstFactoryInMultiUnit or (not isMultiUnitMode and canApplyFactoryDiscount)
				local cost = calculateBudgetForItem(pregameUnitSelected, gameRules, shouldApplyFactoryDiscount, isFirstFactory)
				budgetProjected = budgetProjected + cost
				if isFirstFactory then
					isFirstFactoryInMultiUnit = false
				end
			end
		end
	end

	local budgetRemaining = math.max(0, gameRules.budgetTotal - budgetUsed)
	local budgetPercent = gameRules.budgetTotal > 0 and math.max(0, math.min(100, (budgetRemaining / gameRules.budgetTotal) * 100)) or 0
	local projectedPercent = gameRules.budgetTotal > 0 and math.max(0, math.min(100, (budgetProjected / gameRules.budgetTotal) * 100)) or 0

	return {
		budgetTotal = gameRules.budgetTotal,
		budgetUsed = budgetUsed,
		budgetRemaining = budgetRemaining,
		budgetPercent = budgetPercent,
		budgetProjected = budgetProjected,
		budgetProjectedPercent = projectedPercent,
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

local function updateAllCostOverrides()
	if not wgBuildMenu or not wgGridMenu then
		return
	end

	local myTeamID = spGetMyTeamID()
	local gameRules = getCachedGameRules()
	local buildQueue = wgPregameBuild and wgPregameBuild.getBuildQueue and wgPregameBuild.getBuildQueue() or {}

	local factoryAlreadyPlaced = false
	local commanderX, commanderY, commanderZ = getCommanderPosition(myTeamID)

	for i = 1, #buildQueue do
		local queueItem = buildQueue[i]
		local unitDefID = queueItem[1]

		if unitDefID and unitDefID > 0 and UnitDefs[unitDefID] then
			local buildX, buildZ = queueItem[2], queueItem[4]

			if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
				if UnitDefs[unitDefID].isFactory then
					factoryAlreadyPlaced = true
					break
				end
			end
		end
	end

	for unitDefID, unitDef in pairs(UnitDefs) do
		local metalCost = unitDef.metalCost or 0
		local energyCost = unitDef.energyCost or 0
		local buildTime = unitDef.buildTime or 0
		local budgetCost = calculateBudgetCost(metalCost, energyCost, buildTime)

		if unitDef.isFactory and shouldApplyFactoryDiscount and not factoryAlreadyPlaced then
			budgetCost = calculateBudgetWithDiscount(unitDefID, gameRules.factoryDiscountAmount, shouldApplyFactoryDiscount, true)
		end

		local costOverride = {
			top = { disabled = true },
			bottom = {
				value = budgetCost,
				color = "\255\255\110\255",
				colorDisabled = "\255\200\50\200"
			}
		}

		if wgBuildMenu.setCostOverride then
			wgBuildMenu.setCostOverride(unitDefID, costOverride)
		end
		if wgGridMenu.setCostOverride then
			wgGridMenu.setCostOverride(unitDefID, costOverride)
		end
	end
end

local function updateDataModel(forceUpdate)
	if not widgetState.dmHandle then return end

	local buildQueue = wgPregameBuild and wgPregameBuild.getBuildQueue and wgPregameBuild.getBuildQueue() or {}
	local currentQueueLength = #buildQueue
	local currentTime = os.clock()

	if not forceUpdate and widgetState.lastQueueLength == currentQueueLength and
		(currentTime - widgetState.lastUpdate) < widgetState.updateInterval then
		return
	end

	widgetState.lastUpdate = currentTime

	local modelUpdate = computeProjectedUsage()
	local currentBudgetRemaining = modelUpdate.budgetRemaining or 0

	if forceUpdate or currentQueueLength ~= widgetState.lastQueueLength then
		updateAllCostOverrides()
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
	
	local myTeamID = spGetMyTeamID()
	local gameRules = getCachedGameRules()
	local budgetThreshold = gameRules.budgetThresholdToAllowStart or 0
	local hasUnallocatedBudget = currentBudgetRemaining > budgetThreshold
	
	if wgPregameUI and wgPregameUI.addReadyCondition and wgPregameUI.removeReadyCondition then
		if hasUnallocatedBudget then
			wgPregameUI.addReadyCondition(QUICK_START_CONDITION_KEY, "ui.quickStart.unallocatedBudget")
		else
			wgPregameUI.removeReadyCondition(QUICK_START_CONDITION_KEY)
		end
	end
	if wgPregameUIDraft and wgPregameUIDraft.addReadyCondition and wgPregameUIDraft.removeReadyCondition then
		if hasUnallocatedBudget then
			wgPregameUIDraft.addReadyCondition(QUICK_START_CONDITION_KEY, "ui.quickStart.unallocatedBudget")
		else
			wgPregameUIDraft.removeReadyCondition(QUICK_START_CONDITION_KEY)
		end
	end
	
	for key, value in pairs(modelUpdate) do
		widgetState.dmHandle[key] = value
	end

	if widgetState.document then
		local budgetPercent = widgetState.dmHandle.budgetPercent or 0
		local budgetRemaining = math.floor(widgetState.dmHandle.budgetRemaining or 0)
		
		if widgetState.budgetBarElements.fillElement then
			widgetState.budgetBarElements.fillElement:SetAttribute("style", "width: " .. string.format("%.1f%%", budgetPercent))
		end

		if widgetState.budgetBarElements.projectedElement then
			local budgetProjectedPercent = widgetState.dmHandle.budgetProjectedPercent or 0
			local overlayWidth = math.min(budgetProjectedPercent, budgetPercent)
			local overlayLeft = math.max(0, budgetPercent - overlayWidth)
			local style = string.format("left: %.1f%%; width: %.1f%%;", overlayLeft, overlayWidth)
			widgetState.budgetBarElements.projectedElement:SetAttribute("style", style)
		end

		updateUIElementText(widgetState.document, "qs-budget-value-left", tostring(budgetRemaining))
	end
end

local function getBuildQueueSpawnStatus(buildQueue, selectedBuildData)
	local myTeamID = spGetMyTeamID()
	local gameRules = getCachedGameRules()
	local spawnResults = {
		queueSpawned = {},
		selectedSpawned = false
	}
	
	local remainingBudget = gameRules.budgetTotal
	local firstFactoryPlaced = false
	local commanderX, commanderY, commanderZ = getCommanderPosition(myTeamID)
	
	if buildQueue and #buildQueue > 0 then
		for i = 1, #buildQueue do
			local queueItem = buildQueue[i]
			local unitDefID = queueItem[1]
			local isSpawned = false
			
			if unitDefID and unitDefID > 0 and UnitDefs[unitDefID] then
				local buildX, buildZ = queueItem[2], queueItem[4]
				
				if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
					local budgetCost = calculateBudgetForItem(unitDefID, gameRules, shouldApplyFactoryDiscount, not firstFactoryPlaced)
					
					if remainingBudget >= budgetCost then
						isSpawned = true
						remainingBudget = remainingBudget - budgetCost
						
						if UnitDefs[unitDefID].isFactory and not firstFactoryPlaced then
							firstFactoryPlaced = true
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
			local budgetCost = calculateBudgetForItem(unitDefID, gameRules, shouldApplyFactoryDiscount, not firstFactoryPlaced)
			spawnResults.selectedSpawned = remainingBudget >= budgetCost
		else
			spawnResults.selectedSpawned = false
		end
	end
	
	return spawnResults
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

	wgBuildMenu = WG['buildmenu']
	wgGridMenu = WG['gridmenu']
	wgTopbar = WG['topbar']
	wgPregameBuild = WG['pregame-build']
	wgPregameUI = WG['pregameui']
	wgPregameUIDraft = WG['pregameui_draft']
	wgGetBuildQueueFunc = wgPregameBuild and wgPregameBuild.getBuildQueue
	wgGetBuildPositionsFunc = wgPregameBuild and wgPregameBuild.getBuildPositions
	wgGetPregameUnitSelectedFunc = function() return WG['pregame-unit-selected'] or -1 end

	updateUIElementText(document, "qs-budget-header", spI18N('ui.quickStart.preGameResources'))
	updateUIElementText(document, "qs-warning-text", spI18N('ui.quickStart.remainingResourcesWarning'))
	
	local factoryTextElement = document:GetElementById("qs-factory-text")
	if factoryTextElement then
		if shouldApplyFactoryDiscount then
			updateUIElementText(document, "qs-factory-text", spI18N('ui.quickStart.placeDiscountedFactory'))
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

	WG["getBuildQueueSpawnStatus"] = getBuildQueueSpawnStatus

	updateAllCostOverrides()

	updateDataModel(true)
	widgetState.lastBudgetRemaining = widgetState.dmHandle.budgetRemaining or 0
	return true
end

function widget:Shutdown()
	if wgTopbar and wgTopbar.setResourceBarsVisible then
		wgTopbar.setResourceBarsVisible(true)
	end

	WG["getBuildQueueSpawnStatus"] = nil

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

	updateTraversabilityGrid()
	updateDataModel(false)
end

function widget:RecvLuaMsg(message, playerID)
	local document = widgetState.document
	if not document then return end
	
	if message:sub(1, 19) == 'LobbyOverlayActive0' then
		document:Show()
	elseif message:sub(1, 19) == 'LobbyOverlayActive1' then
		document:Hide()
	end
end