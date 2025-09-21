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
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetMyTeamID = Spring.GetMyTeamID
local spI18N = Spring.I18N

local MODEL_NAME = "quick_start_model"
local RML_PATH = "luaui/RmlWidgets/gui_quick_start/gui_quick_start.rml"

local ENERGY_VALUE_CONVERSION_DIVISOR = 10
local MAX_QUEUE_HASH_ITEMS = 50
local DEFAULT_INSTANT_BUILD_RANGE = 600
local ALPHA_AFFORDABLE = 1.0
local ALPHA_UNAFFORDABLE = 0.5

local function calculateMetergyCost(metalCost, energyCost)
	return metalCost + (energyCost / ENERGY_VALUE_CONVERSION_DIVISOR)
end

local widgetState = {
	rmlContext = nil,
	dmHandle = nil,
	document = nil,
	lastUpdate = 0,
	updateInterval = 0.2,
	lastQueueHash = "",
	isDocumentVisible = true,
	hiddenByLobby = false,
	metergyBarElements = {
		fillElement = nil,
		projectedElement = nil,
	},
	lastMetergyRemaining = 0,
	deductionElements = {},
	currentDeductionIndex = 1,
}

local initialModel = {
	metergyTotal = 0,
	metergyUsed = 0,
	metergyRemaining = 0,
	metergyPercent = 0,
	metergyProjected = 0,
	metergyProjectedPercent = 0,
	showBar = false,
	factoryDiscountUsed = false,
	deductionAmount1 = "", --we have multiple to allow multiple deduction animations to play simultaneously.
	deductionAmount2 = "",
	deductionAmount3 = "",
	deductionAmount4 = "",
	deductionAmount5 = "",
}

local function calculateMetergyWithDiscount(unitDefID, factoryDiscountAmount, shouldApplyDiscount, isFirstFactory)
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then return 0 end

	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	local metergyCost = calculateMetergyCost(metalCost, energyCost)

	if unitDef.isFactory and isFirstFactory and shouldApplyDiscount then
		return math.max(0, metergyCost - factoryDiscountAmount)
	end
	return metergyCost
end

local function isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, instantBuildRange)
	local distance = math.distance2d(commanderX, commanderZ, buildX, buildZ)
	return distance <= instantBuildRange
end

local function getGameRulesParams(myTeamID)
	return {
		metergyTotal = spGetGameRulesParam("quickStartMetergyBase") or 0,
		factoryDiscountAmount = spGetGameRulesParam("quickStartFactoryDiscountAmount") or 0,
		factoryDiscountUsed = spGetTeamRulesParam(myTeamID, "quickStartFactoryDiscountUsed") or 0,
		instantBuildRange = spGetGameRulesParam("overridePregameBuildDistance") or DEFAULT_INSTANT_BUILD_RANGE,
	}
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


local function hashQueue(queue)
	if not queue or #queue == 0 then return "" end
	local hash = ""
	for i = 1, math.min(#queue, MAX_QUEUE_HASH_ITEMS) do
		local q = queue[i]
		hash = hash .. tostring(q[1]) .. ":" .. tostring(q[2]) .. ":" .. tostring(q[4]) .. ":" .. tostring(q[5]) .. "|"
	end
	return hash
end

local function createMetergyBarElements()
	if not widgetState.document then
		return
	end

	local fillElement = widgetState.document:GetElementById("qs-metergy-fill")
	local projectedElement = widgetState.document:GetElementById("qs-metergy-projected")

	if fillElement and projectedElement then
		widgetState.metergyBarElements.fillElement = fillElement
		widgetState.metergyBarElements.projectedElement = projectedElement
	end
	
	for i = 1, 5 do
		local deductionElement = widgetState.document:GetElementById("qs-deduction-amount-" .. i)
		if deductionElement then
			widgetState.deductionElements[i] = deductionElement
		end
	end
end

local function computeProjectedUsage()
	local myTeamID = spGetMyTeamID() or 0
	local gameRules = getGameRulesParams(myTeamID)
	local pregame = WG and WG["pregame-build"] and WG["pregame-build"].getBuildQueue and
	WG["pregame-build"].getBuildQueue() or {}
	local pregameUnitSelected = WG["pregame-unit-selected"] or -1

	local metergyUsed = 0
	local firstFactoryPlaced = false
	local shouldApplyDiscount = shouldApplyFactoryDiscount

	local commanderX, commanderY, commanderZ = Spring.GetTeamStartPosition(myTeamID)
	if not commanderX or not commanderZ then
		commanderX, commanderY, commanderZ = 0, 0, 0
	end

	if pregame and #pregame > 0 then
		for i = 1, #pregame do
			local item = pregame[i]
			local defID = item[1]
			if defID and defID > 0 and UnitDefs[defID] then
				local buildX, buildZ = item[2], item[4]

				if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
					local metergyCost = calculateMetergyWithDiscount(defID, gameRules.factoryDiscountAmount,
						shouldApplyDiscount, not firstFactoryPlaced)
					metergyUsed = metergyUsed + metergyCost

					if UnitDefs[defID].isFactory and not firstFactoryPlaced then
						firstFactoryPlaced = true
					end
				end
			end
		end
	end

	local metergyProjected = 0
	if pregameUnitSelected and pregameUnitSelected > 0 and UnitDefs[pregameUnitSelected] then
		local uDef = UnitDefs[pregameUnitSelected]
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true, false, false,
			uDef.modCategories and uDef.modCategories.underwater)
		if pos then
			local buildFacing = Spring.GetBuildFacing()
			local bx, by, bz = Spring.Pos2BuildPos(pregameUnitSelected, pos[1], pos[2], pos[3], buildFacing)

			if isWithinBuildRange(commanderX, commanderZ, bx, bz, gameRules.instantBuildRange) then
				metergyProjected = calculateMetergyWithDiscount(pregameUnitSelected, gameRules.factoryDiscountAmount,
					shouldApplyDiscount, not firstFactoryPlaced)
			end
		end
	end

	local metergyRemaining = math.max(0, gameRules.metergyTotal - metergyUsed)
	local percent = gameRules.metergyTotal > 0 and
	math.max(0, math.min(100, (metergyRemaining / gameRules.metergyTotal) * 100)) or 0
	local projectedPercent = gameRules.metergyTotal > 0 and
	math.max(0, math.min(100, (metergyProjected / gameRules.metergyTotal) * 100)) or 0

	return {
		metergyTotal = gameRules.metergyTotal,
		metergyUsed = metergyUsed,
		metergyRemaining = metergyRemaining,
		metergyPercent = percent,
		metergyProjected = metergyProjected,
		metergyProjectedPercent = projectedPercent,
		factoryDiscountUsed = gameRules.factoryDiscountUsed == 1,
	}
end

local function updateDataModel(force)
	if not widgetState.dmHandle then return end

	local queue = WG and WG["pregame-build"] and WG["pregame-build"].getBuildQueue and
	WG["pregame-build"].getBuildQueue() or {}
	local newHash = hashQueue(queue)
	if not force and widgetState.lastQueueHash == newHash and (os.clock() - widgetState.lastUpdate) < widgetState.updateInterval then
		return
	end
	widgetState.lastQueueHash = newHash
	widgetState.lastUpdate = os.clock()

	local modelUpdate = computeProjectedUsage()
	local currentMetergyRemaining = modelUpdate.metergyRemaining or 0
	
	if widgetState.lastMetergyRemaining > currentMetergyRemaining then
		local deductionAmount = widgetState.lastMetergyRemaining - currentMetergyRemaining
		showDeductionAnimation(deductionAmount)
	end
	
	widgetState.lastMetergyRemaining = currentMetergyRemaining
	
	for key, value in pairs(modelUpdate) do
		widgetState.dmHandle[key] = value
	end

	if widgetState.document then
		local metergyPercent = widgetState.dmHandle.metergyPercent or 0
		if widgetState.metergyBarElements.fillElement then
			widgetState.metergyBarElements.fillElement:SetAttribute("style",
				"width: " .. string.format("%.1f%%", metergyPercent))
		end

		if widgetState.metergyBarElements.projectedElement then
			local metergyProjectedPercent = widgetState.dmHandle.metergyProjectedPercent or 0
			local overlayWidth = math.min(metergyProjectedPercent, metergyPercent)
			local overlayLeft = math.max(0, metergyPercent - overlayWidth)
			local style = string.format("left: %.1f%%; width: %.1f%%;", overlayLeft, overlayWidth)
			widgetState.metergyBarElements.projectedElement:SetAttribute("style", style)
		end

		updateUIElementText(widgetState.document, "qs-metergy-remaining",
			tostring(math.floor(widgetState.dmHandle.metergyRemaining or 0)))
		updateUIElementText(widgetState.document, "qs-metergy-total",
			tostring(math.floor(widgetState.dmHandle.metergyTotal or 0)))
		updateUIElementText(widgetState.document, "qs-metergy-value-left",
			tostring(math.floor(widgetState.dmHandle.metergyRemaining or 0)))
	end
end


local function getBuildQueueAlphaValues(buildQueue, selectedBuildData)
	local myTeamID = spGetMyTeamID() or 0
	local gameRules = getGameRulesParams(myTeamID)
	local alphaResults = {
		queueAlphas = {},
		selectedAlpha = ALPHA_AFFORDABLE
	}
	
	local metergyRemaining = gameRules.metergyTotal
	local firstFactoryPlaced = false
	local shouldApplyDiscount = shouldApplyFactoryDiscount
	
	local commanderX, commanderY, commanderZ = Spring.GetTeamStartPosition(myTeamID)
	if not commanderX or not commanderZ then
		commanderX, commanderY, commanderZ = 0, 0, 0
	end
	
	if buildQueue and #buildQueue > 0 then
		for i = 1, #buildQueue do
			local item = buildQueue[i]
			local defID = item[1]
			local alpha = ALPHA_UNAFFORDABLE
			
			if defID and defID > 0 and UnitDefs[defID] then
				local buildX, buildZ = item[2], item[4]
				
				if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
					local metergyCost = calculateMetergyWithDiscount(defID, gameRules.factoryDiscountAmount,
						shouldApplyDiscount, not firstFactoryPlaced)
					
					if metergyRemaining >= metergyCost then
						alpha = ALPHA_AFFORDABLE
						metergyRemaining = metergyRemaining - metergyCost
						
						if UnitDefs[defID].isFactory and not firstFactoryPlaced then
							firstFactoryPlaced = true
						end
					end
				end
			end
			
			alphaResults.queueAlphas[i] = alpha
		end
	end
	
	if selectedBuildData and selectedBuildData[1] and selectedBuildData[1] > 0 then
		local defID = selectedBuildData[1]
		local buildX, buildZ = selectedBuildData[2], selectedBuildData[4]
		
		if isWithinBuildRange(commanderX, commanderZ, buildX, buildZ, gameRules.instantBuildRange) then
			local metergyCost = calculateMetergyWithDiscount(defID, gameRules.factoryDiscountAmount,
				shouldApplyDiscount, not firstFactoryPlaced)
			
			if metergyRemaining >= metergyCost then
				alphaResults.selectedAlpha = ALPHA_AFFORDABLE
			else
				alphaResults.selectedAlpha = ALPHA_UNAFFORDABLE
			end
		else
			alphaResults.selectedAlpha = ALPHA_UNAFFORDABLE
		end
	end
	
	return alphaResults
end

function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		return false
	end

	local dm = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dm then
		return false
	end
	widgetState.dmHandle = dm

	widgetState.dmHandle.showBar = true

	local document = widgetState.rmlContext:LoadDocument(RML_PATH)
	if not document then
		widget:Shutdown()
		return false
	end
	widgetState.document = document
	document:Show()

	updateUIElementText(document, "qs-metergy-header", spI18N('ui.quickStart.preGameResources'))
	updateUIElementText(document, "qs-warning-text", spI18N('ui.quickStart.remainingResourcesWarning'))
	updateUIElementText(document, "qs-factory-text", spI18N('ui.quickStart.placeDiscountedFactory'))

	createMetergyBarElements()

	if WG['topbar'] and WG['topbar'].setResourceBarsVisible then
		WG['topbar'].setResourceBarsVisible(false)
	end

	WG["getBuildQueueAlphaValues"] = getBuildQueueAlphaValues
	
	WG["buildMenuCostOverride"] = {}
	WG["buildMenuCostOverrideColors"] = {
		allowed = "\255\100\255\100",
		blocked = "\255\100\200\100"
	}
	
	for unitDefID, unitDef in pairs(UnitDefs) do
		local metalCost = unitDef.metalCost or 0
		local energyCost = unitDef.energyCost or 0
		WG["buildMenuCostOverride"][unitDefID] = calculateMetergyCost(metalCost, energyCost)
	end

	updateDataModel(true)
	widgetState.lastMetergyRemaining = widgetState.dmHandle.metergyRemaining or 0
	return true
end

function widget:Shutdown()
	if WG['topbar'] and WG['topbar'].setResourceBarsVisible then
		WG['topbar'].setResourceBarsVisible(true)
	end

	WG["getBuildQueueAlphaValues"] = nil
	
	WG["buildMenuCostOverride"] = nil
	WG["buildMenuCostOverrideColors"] = nil

	if WG['buildmenu'] and WG['buildmenu'].forceRefresh then
		WG['buildmenu'].forceRefresh()
	end
	if WG['gridmenu'] and WG['gridmenu'].forceRefresh then
		WG['gridmenu'].forceRefresh()
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
	local gameFrame = Spring.GetGameFrame()
	if gameFrame > 0 then
		if WG['topbar'] and WG['topbar'].setResourceBarsVisible then
			WG['topbar'].setResourceBarsVisible(true)
		end
		widgetHandler:RemoveWidget(self)
		return
	end
	updateDataModel(false)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		if widgetState.document then
			if not widgetState.isDocumentVisible then
				widgetState.document:Show()
				widgetState.isDocumentVisible = true
			end
			widgetState.hiddenByLobby = false
		end
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		if widgetState.document then
			if widgetState.isDocumentVisible then
				widgetState.document:Hide()
				widgetState.isDocumentVisible = false
			end
			widgetState.hiddenByLobby = true
		end
	end
end