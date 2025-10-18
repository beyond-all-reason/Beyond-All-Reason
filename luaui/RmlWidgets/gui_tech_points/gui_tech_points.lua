if not RmlUi then
	return
end

local widget = widget

function widget:GetInfo()
	return {
		name = "Tech Points Display",
		desc = "Displays tech points, thresholds, and current tech level",
		author = "SethDGamre",
		date = "2025-10",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local modOptions = Spring.GetModOptions()

if not modOptions or not modOptions.tech_blocking then
	return false
end

local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetMyTeamID = Spring.GetMyTeamID
local spI18N = Spring.I18N

local blockTechDefs = {}
local blockTechCount = 0
local blockedDefs = {}

local function initializeTechBlocking()
	for unitDefID, unitDef in pairs(UnitDefs) do
		local customParams = unitDef.customParams
		if customParams and customParams.tech_build_blocked_until_level then
			local techLevel = tonumber(customParams.tech_build_blocked_until_level)
			blockTechDefs[unitDefID] = techLevel
			blockTechCount = blockTechCount + 1
		end
	end
end

local function updateUIElementText(document, elementId, text)
	local element = document:GetElementById(elementId)
	if element then
		element.inner_rml = text
	end
end

local MODEL_NAME = "tech_points_model"
local RML_PATH = "luaui/RmlWidgets/gui_tech_points/gui_tech_points.rml"

local widgetState = {
	rmlContext = nil,
	document = nil,
	dmHandle = nil,
	lastUpdate = 0,
	updateInterval = 0.5,
	lastBlockingUpdate = 0,
	blockingUpdateInterval = 0.1,
	fillElement = nil,
	levelElement = nil,
	popupElement = nil,
	previousTechLevel = 1,
	previousTechPoints = 0,
	popupEndTime = 0,
	gameStartTime = nil,
	initialPopupShown = false,
}

local initialModel = {
	techLevel = 1,
	currentTechPoints = 0,
	nextThreshold = 100,
	progressPercent = 0,
}

local function calculateNextThreshold(currentPoints, t2Threshold, t3Threshold)
	if currentPoints >= t3Threshold then
		return t3Threshold
	elseif currentPoints >= t2Threshold then
		return t3Threshold
	else
		return t2Threshold
	end
end

local function calculateProgressPercent(currentPoints, nextThreshold, currentTechLevel, t2Threshold, t3Threshold)
	if nextThreshold <= 0 then
		return 0
	end

	if currentPoints >= t3Threshold then
		return 100
	end

	if currentPoints >= t2Threshold then
		local progressInT2 = (currentPoints - t2Threshold) / (t3Threshold - t2Threshold) * 100
		return math.min(100, progressInT2)
	end

	local progressInT1 = currentPoints / t2Threshold * 100
	return math.min(100, progressInT1)
end

local function updateTechPointsData()
	local myTeamID = spGetMyTeamID()
	if not myTeamID then
		return {
			techLevel = 1,
			currentTechPoints = 0,
			nextThreshold = 100,
			progressPercent = 0,
		}
	end

	local currentTechPoints = spGetTeamRulesParam(myTeamID, "tech_points")
	if currentTechPoints == nil then currentTechPoints = 0 end
	currentTechPoints = tonumber(currentTechPoints) or 0
	local t2Threshold = modOptions.t2_tech_threshold or 100
	local t3Threshold = modOptions.t3_tech_threshold or 1000

	local techLevel = 1
	if currentTechPoints >= t3Threshold then
		techLevel = 3
	elseif currentTechPoints >= t2Threshold then
		techLevel = 2
	end

	local nextThreshold = calculateNextThreshold(currentTechPoints, t2Threshold, t3Threshold)

	local progressPercent = calculateProgressPercent(currentTechPoints, nextThreshold, techLevel, t2Threshold, t3Threshold)

	return {
		techLevel = techLevel,
		currentTechPoints = math.floor(currentTechPoints),
		nextThreshold = nextThreshold,
		progressPercent = progressPercent,
	}
end


local function createTechPointsElements()
	if not widgetState.document then
		return
	end

	for attempt = 1, 5 do
		local fillElement = widgetState.document:GetElementById("tech-points-fill")
		local levelElement = widgetState.document:GetElementById("tech-level-number")
		local popupElement = widgetState.document:GetElementById("tech-level-popup")

		if fillElement and levelElement then
			widgetState.fillElement = fillElement
			widgetState.levelElement = levelElement
			widgetState.popupElement = popupElement
			return
		end

		if attempt < 5 then
			local currentTime = os.clock()
			while os.clock() - currentTime < 0.01 do end
		end
	end
end

local function updateBlocking()
	if not modOptions or not modOptions.tech_blocking then
		return
	end

	local myTeamID = spGetMyTeamID()
	if not myTeamID then
		return
	end

	local currentTechPoints = spGetTeamRulesParam(myTeamID, "tech_points")
	if currentTechPoints == nil then currentTechPoints = 0 end
	currentTechPoints = tonumber(currentTechPoints) or 0
	local t2Threshold = modOptions.t2_tech_threshold or 100
	local t3Threshold = modOptions.t3_tech_threshold or 1000

	local techLevel = 1
	if currentTechPoints >= t3Threshold then
		techLevel = 3
	elseif currentTechPoints >= t2Threshold then
		techLevel = 2
	end

	local techLevelChanged = techLevel ~= widgetState.previousTechLevel
	local techPointsChangedSignificantly = math.abs(currentTechPoints - widgetState.previousTechPoints) >= 10

	if techLevelChanged or techPointsChangedSignificantly then
		Spring.Echo("[TechPoints Debug] Tech level changed or points changed significantly - calling clearBlockReasons")
		if WG["gridmenu"] and WG["gridmenu"].clearBlockReasons then
			WG["gridmenu"].clearBlockReasons()
		end
		if WG["buildmenu"] and WG["buildmenu"].clearBlockReasons then
			WG["buildmenu"].clearBlockReasons()
		end

		for unitDefID in pairs(blockedDefs) do
			blockedDefs[unitDefID] = nil
		end

		for unitDefID, requiredLevel in pairs(blockTechDefs) do
			if techLevel < requiredLevel then
				if not blockedDefs[unitDefID] then
					blockedDefs[unitDefID] = {}
				end
				table.insert(blockedDefs[unitDefID], "tech_level_" .. requiredLevel)

				if WG["gridmenu"] and WG["gridmenu"].addBlockReason then
					WG["gridmenu"].addBlockReason(unitDefID, "tech_block")
				end
				if WG["buildmenu"] and WG["buildmenu"].addBlockReason then
					WG["buildmenu"].addBlockReason(unitDefID, "tech_block")
				end
			end
		end

		widgetState.previousTechLevel = techLevel
		widgetState.previousTechPoints = currentTechPoints
	end
end

local function updateUI()
	if not widgetState.document then
		return
	end

	local data = updateTechPointsData()

	updateBlocking()

	if not widgetState.initialPopupShown and widgetState.gameStartTime and
	   (os.clock() - widgetState.gameStartTime) >= 10.0 and Spring.GetGameFrame() > 0 then
		local popupText = spI18N("ui.techBlocking.techPopup.level1")
		if widgetState.document then
			updateUIElementText(widgetState.document, "tech-level-popup", popupText)
		end

		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", true)
		end

		widgetState.initialPopupShown = true
		widgetState.popupEndTime = os.clock() + 3.0
	end

	if data.techLevel ~= widgetState.previousTechLevel then
		local popupKey = "ui.techBlocking.techPopup.level" .. tostring(data.techLevel)
		local popupText = spI18N(popupKey)
		if widgetState.document then
			updateUIElementText(widgetState.document, "tech-level-popup", popupText)
		end

		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", true)
		end

		widgetState.previousTechLevel = data.techLevel
		widgetState.popupEndTime = os.clock() + 3.0
	end

	if widgetState.popupEndTime > 0 and os.clock() >= widgetState.popupEndTime then
		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", false)
		end
		widgetState.popupEndTime = 0
	end

	if widgetState.dmHandle then
		widgetState.dmHandle.techLevel = data.techLevel
		widgetState.dmHandle.currentTechPoints = data.currentTechPoints
		widgetState.dmHandle.nextThreshold = data.nextThreshold
		widgetState.dmHandle.progressPercent = data.progressPercent
	end

	if not widgetState.fillElement or not widgetState.levelElement then
		createTechPointsElements()
	end

	if widgetState.fillElement then
		local heightValue = string.format("%.1f%%", data.progressPercent)
		widgetState.fillElement:SetAttribute("style", "height: " .. heightValue)
	end

	if widgetState.levelElement then
		local levelText = tostring(data.techLevel)
		widgetState.levelElement.inner_rml = levelText
	end
end

function widget:Initialize()
	initializeTechBlocking()

	widgetState.gameStartTime = os.clock()

	local myTeamID = spGetMyTeamID()
	if myTeamID then
		local currentTechPoints = spGetTeamRulesParam(myTeamID, "tech_points") or 0
		widgetState.previousTechPoints = currentTechPoints
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

	updateUIElementText(document, "tech-level-header", spI18N('ui.techBlocking.techLevel'))
	updateUIElementText(document, "tech-level-popup", spI18N('ui.techBlocking.techPopup.level1'))

	createTechPointsElements()

	updateUI()
end

function widget:Shutdown()
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

function widget:Update(dt)
	local currentTime = os.clock()

	if currentTime - widgetState.lastUpdate > widgetState.updateInterval then
		widgetState.lastUpdate = currentTime
		updateUI()
	end

	if currentTime - widgetState.lastBlockingUpdate > widgetState.blockingUpdateInterval then
		widgetState.lastBlockingUpdate = currentTime
		updateBlocking()
	end
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