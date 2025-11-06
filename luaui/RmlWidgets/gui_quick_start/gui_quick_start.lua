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
		layer = 1,
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

local MODEL_NAME = "quick_start_model"
local RML_PATH = "luaui/RmlWidgets/gui_quick_start/gui_quick_start.rml"
local QUICK_START_CONDITION_KEY = "quickStartUnallocatedBudget"

local ENERGY_VALUE_CONVERSION_MULTIPLIER = 1/60 --60 being the energy conversion rate of t2 energy converters, statically defined so future changes not to affect this.
local BUILD_TIME_VALUE_CONVERSION_MULTIPLIER = 1/300 --300 being a representative of commander workertime, statically defined so future com unitdef adjustments don't change this.
local DEFAULT_INSTANT_BUILD_RANGE = 500
local GRID_GENERATION_RANGE = 544
local GRID_RESOLUTION = 32
local GRID_CHECK_RESOLUTION_MULTIPLIER = 1

local traversabilityGrid = VFS.Include("luarules/Utilities/traversability_grid.lua")
local lastCommanderX = nil
local lastCommanderZ = nil

local function customRound(value)
	if value < 15 then
		return math.floor(value)
	elseif value < 100 then
		return math.floor(value / 5 + 0.5) * 5
	else
		return math.floor(value / 10 + 0.5) * 10
	end
end

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
	lastMousePos = {0, 0},
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

	local myTeamID = spGetMyTeamID() or 0
	local startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")

	if startDefID and traversabilityGrid.canMoveToPosition(startDefID, buildX, buildZ, GRID_CHECK_RESOLUTION_MULTIPLIER) then
		return true
	end

	return false
end

local function getCachedGameRules(myTeamID)
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
		traversabilityGrid.generateTraversableGrid(startDefID, commanderX, commanderZ, GRID_GENERATION_RANGE, GRID_RESOLUTION, startDefID)
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
	local myTeamID = spGetMyTeamID() or 0
	local gameRules = getCachedGameRules(myTeamID)
	local pregame = WG and WG["pregame-build"] and WG["pregame-build"].getBuildQueue and
		WG["pregame-build"].getBuildQueue() or {}
	local pregameUnitSelected = WG["pregame-unit-selected"] or -1

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

	local factoryHasBeenPlaced = firstFactoryPlaced
	if pregameUnitSelected > 0 and UnitDefs[pregameUnitSelected] and UnitDefs[pregameUnitSelected].isFactory then
		local uDef = UnitDefs[pregameUnitSelected]
		local mx, my = Spring.GetMouseState()

		local mouseMoved = mx ~= widgetState.lastMousePos[1] or my ~= widgetState.lastMousePos[2]
		if mouseMoved then
			widgetState.lastMousePos[1] = mx
			widgetState.lastMousePos[2] = my
		end

		local _, pos = Spring.TraceScreenRay(mx, my, true, false, false,
			uDef.modCategories and uDef.modCategories.underwater)
		if pos then
			local buildFacing = Spring.GetBuildFacing()
			local bx, by, bz = Spring.Pos2BuildPos(pregameUnitSelected, pos[1], pos[2], pos[3], buildFacing)

			if isWithinBuildRange(commanderX, commanderZ, bx, bz, gameRules.instantBuildRange) then
				factoryHasBeenPlaced = true
			end
		end
	end

	local buildMenu = WG['buildmenu']
	local gridMenu = WG['gridmenu']
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isFactory then
			local metalCost = unitDef.metalCost or 0
			local energyCost = unitDef.energyCost or 0
			local buildTime = unitDef.buildTime or 0
			local baseBudgetCost = calculateBudgetCost(metalCost, energyCost, buildTime)
			local discountedCost = calculateBudgetWithDiscount(unitDefID, gameRules.factoryDiscountAmount, shouldApplyFactoryDiscount, not factoryHasBeenPlaced)
			local displayCost = discountedCost

			local costOverride = {
				top = { disabled = true },
				bottom = {
					value = displayCost,
					color = "\255\255\110\255",
					colorDisabled = "\255\200\50\200"
				}
			}

			if buildMenu and buildMenu.setCostOverride then
				buildMenu.setCostOverride(unitDefID, costOverride)
			end
			if gridMenu and gridMenu.setCostOverride then
				gridMenu.setCostOverride(unitDefID, costOverride)
			end
		end
	end

	local budgetProjected = 0
	if pregameUnitSelected > 0 and UnitDefs[pregameUnitSelected] then
		local uDef = UnitDefs[pregameUnitSelected]
		local mx, my = Spring.GetMouseState()

		local mouseMoved = mx ~= widgetState.lastMousePos[1] or my ~= widgetState.lastMousePos[2]
		if mouseMoved then
			widgetState.lastMousePos[1] = mx
			widgetState.lastMousePos[2] = my
		end

		local _, pos = Spring.TraceScreenRay(mx, my, true, false, false,
			uDef.modCategories and uDef.modCategories.underwater)
		if pos then
			local buildFacing = Spring.GetBuildFacing()
			local bx, by, bz = Spring.Pos2BuildPos(pregameUnitSelected, pos[1], pos[2], pos[3], buildFacing)

			if isWithinBuildRange(commanderX, commanderZ, bx, bz, gameRules.instantBuildRange) then
				budgetProjected = calculateBudgetForItem(pregameUnitSelected, gameRules, shouldApplyFactoryDiscount, not firstFactoryPlaced)
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

local function updateDataModel(forceUpdate)
	if not widgetState.dmHandle then return end

	local buildQueue = WG and WG["pregame-build"] and WG["pregame-build"].getBuildQueue and
		WG["pregame-build"].getBuildQueue() or {}
	local currentQueueLength = #buildQueue
	local currentTime = os.clock()
	
	if not forceUpdate and widgetState.lastQueueLength == currentQueueLength and 
		(currentTime - widgetState.lastUpdate) < widgetState.updateInterval then
		return
	end
	
	widgetState.lastUpdate = currentTime

	local modelUpdate = computeProjectedUsage()
	local currentBudgetRemaining = modelUpdate.budgetRemaining or 0
	
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
	
	local myTeamID = spGetMyTeamID() or 0
	local gameRules = getCachedGameRules(myTeamID)
	local budgetThreshold = gameRules.budgetThresholdToAllowStart or 0
	local hasUnallocatedBudget = currentBudgetRemaining > budgetThreshold
	local pregameUI = WG['pregameui']
	local pregameUIDraft = WG['pregameui_draft']
	
	if pregameUI and pregameUI.addReadyCondition and pregameUI.removeReadyCondition then
		if hasUnallocatedBudget then
			pregameUI.addReadyCondition(QUICK_START_CONDITION_KEY, "ui.quickStart.unallocatedBudget")
		else
			pregameUI.removeReadyCondition(QUICK_START_CONDITION_KEY)
		end
	end
	if pregameUIDraft and pregameUIDraft.addReadyCondition and pregameUIDraft.removeReadyCondition then
		if hasUnallocatedBudget then
			pregameUIDraft.addReadyCondition(QUICK_START_CONDITION_KEY, "ui.quickStart.unallocatedBudget")
		else
			pregameUIDraft.removeReadyCondition(QUICK_START_CONDITION_KEY)
		end
	end
	
	for key, value in pairs(modelUpdate) do
		widgetState.dmHandle[key] = value
	end

	if widgetState.document then
		local budgetPercent = widgetState.dmHandle.budgetPercent or 0
		local budgetRemaining = math.floor(widgetState.dmHandle.budgetRemaining or 0)
		local budgetTotal = math.floor(widgetState.dmHandle.budgetTotal or 0)
		
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
	local myTeamID = spGetMyTeamID() or 0
	local gameRules = getCachedGameRules(myTeamID)
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

	if WG['topbar'] and WG['topbar'].setResourceBarsVisible then
		WG['topbar'].setResourceBarsVisible(false)
	end

	WG["getBuildQueueSpawnStatus"] = getBuildQueueSpawnStatus

	local buildMenu = WG['buildmenu']
	local gridMenu = WG['gridmenu']

	for unitDefID, unitDef in pairs(UnitDefs) do
		if not unitDef.isFactory then
			local metalCost = unitDef.metalCost or 0
			local energyCost = unitDef.energyCost or 0
			local buildTime = unitDef.buildTime or 0
			local budgetCost = calculateBudgetCost(metalCost, energyCost, buildTime)

			local costOverride = {
				top = { disabled = true },
				bottom = {
					value = budgetCost,
					color = "\255\255\110\255",
					colorDisabled = "\255\200\50\200"
				}
			}

			if buildMenu and buildMenu.setCostOverride then
				buildMenu.setCostOverride(unitDefID, costOverride)
			end
			if gridMenu and gridMenu.setCostOverride then
				gridMenu.setCostOverride(unitDefID, costOverride)
			end
		end
	end

	updateDataModel(true)
	widgetState.lastBudgetRemaining = widgetState.dmHandle.budgetRemaining or 0
	return true
end

function widget:Shutdown()
	if WG['topbar'] and WG['topbar'].setResourceBarsVisible then
		WG['topbar'].setResourceBarsVisible(true)
	end

	WG["getBuildQueueSpawnStatus"] = nil
	
	if WG['buildmenu'] and WG['buildmenu'].clearCostOverrides then
		WG['buildmenu'].clearCostOverrides()
	end
	if WG['gridmenu'] and WG['gridmenu'].clearCostOverrides then
		WG['gridmenu'].clearCostOverrides()
	end
	
	if WG['pregameui'] and WG['pregameui'].removeReadyCondition then
		WG['pregameui'].removeReadyCondition(QUICK_START_CONDITION_KEY)
	end
	if WG['pregameui_draft'] and WG['pregameui_draft'].removeReadyCondition then
		WG['pregameui_draft'].removeReadyCondition(QUICK_START_CONDITION_KEY)
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
		local topbar = WG['topbar']
		if topbar and topbar.setResourceBarsVisible then
			topbar.setResourceBarsVisible(true)
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