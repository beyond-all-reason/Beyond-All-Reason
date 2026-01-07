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

if not modOptions.tech_blocking then
	return false
end

local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetMyTeamID = Spring.GetMyTeamID
local spI18N = Spring.I18N

local POPUP_DELAY_FRAMES = Game.gameSpeed * 10
local UPDATE_INTERVAL = 1.0
local CACHE_INTERVAL = 0.5 --seconds
local popupsEnabled = false

local cachedDataTable = {
	techLevel = 1,
	currentTechPoints = 0,
	nextThreshold = 100,
	progressPercent = 0,
	isNegative = false,
}

local heightStrings = {}
for i = 0, 100 do
	heightStrings[i] = string.format("%.1f%%", i)
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
	fillElement = nil,
	levelElement = nil,
	popupElement = nil,
	previousTechLevel = 1,
	previousTechPoints = 0,
	popupEndTime = 0,
	gameStartTime = nil,
	initialPopupShown = false,
	cachedMyTeamID = nil,
	cachedTechPoints = 0,
	cachedTechLevel = 1,
	cachedT2Threshold = 100,
	cachedT3Threshold = 1000,
	cachedTeamCount = 1,
	lastTeamCountUpdate = 0,
	lastTechDataUpdate = 0,
	lastDisplayedTechLevel = 1,
	lastDisplayedTechPoints = 0,
	lastDisplayedProgressPercent = 0,
	lastDisplayedIsNegative = false,
}

local initialModel = {
	techLevel = 1,
	currentTechPoints = 0,
	nextThreshold = 100,
	progressPercent = 0,
}

local function getTechData()
	local currentTime = os.clock()
	local myTeamID = widgetState.cachedMyTeamID

	if not myTeamID then
		myTeamID = spGetMyTeamID()
		if not myTeamID then return 1, 0, 100, 1000 end
		widgetState.cachedMyTeamID = myTeamID
	end

	local needsFreshData = currentTime - widgetState.lastTechDataUpdate > CACHE_INTERVAL
	if needsFreshData then
		widgetState.lastTechDataUpdate = currentTime
		local currentTechPoints = spGetTeamRulesParam(myTeamID, "tech_points")
		currentTechPoints = tonumber(currentTechPoints) or 0

		local techLevel = spGetTeamRulesParam(myTeamID, "tech_level")
		techLevel = tonumber(techLevel) or 1

		widgetState.cachedTechPoints = currentTechPoints
		widgetState.cachedTechLevel = techLevel
	end

	local techBlockingPerTeam = modOptions.tech_blocking_per_team
	local baseT2 = modOptions.t2_tech_threshold or 100
	local baseT3 = modOptions.t3_tech_threshold or 1000
	local t2Threshold, t3Threshold

	if techBlockingPerTeam then
		if currentTime - widgetState.lastTeamCountUpdate > CACHE_INTERVAL then
			local myAllyTeamID = Spring.GetMyAllyTeamID()
			local teamList = Spring.GetTeamList(myAllyTeamID)
			local newTeamCount = #teamList

			if newTeamCount ~= widgetState.cachedTeamCount then
				widgetState.cachedTeamCount = newTeamCount
				widgetState.lastTeamCountUpdate = currentTime

				widgetState.cachedT2Threshold = baseT2 * widgetState.cachedTeamCount
				widgetState.cachedT3Threshold = baseT3 * widgetState.cachedTeamCount
			end
		end
		t2Threshold = widgetState.cachedT2Threshold
		t3Threshold = widgetState.cachedT3Threshold
	else
		t2Threshold = baseT2
		t3Threshold = baseT3
	end

	return widgetState.cachedTechLevel, widgetState.cachedTechPoints, t2Threshold, t3Threshold
end

local function calculateProgressPercent(currentPoints, nextThreshold, currentTechLevel, t2Threshold, t3Threshold)
	if nextThreshold <= 0 then
		return 0, false
	end

	if currentTechLevel >= 3 then
		return 100, false
	end

	if currentTechLevel >= 2 then
		if currentPoints >= t3Threshold then
			return 100, false
		end
		if currentPoints < t2Threshold then
			local deficit = t2Threshold - currentPoints
			local maxDeficit = t2Threshold 
			local deficitPercent = math.min(100, (deficit / maxDeficit) * 100)
			return deficitPercent, true
		end
		local progressInT2 = math.max(0, (currentPoints - t2Threshold) / (t3Threshold - t2Threshold) * 100)
		return math.min(100, progressInT2), false
	end

	if currentPoints < 0 then
		local deficitPercent = math.min(100, (math.abs(currentPoints) / 100) * 100)
		return deficitPercent, true
	end

	local progressInT1 = math.max(0, currentPoints / t2Threshold * 100)
	return math.min(100, progressInT1), false
end

local function updateTechPointsData()
	local techLevel, currentTechPoints, t2Threshold, t3Threshold = getTechData()

	local nextThreshold
	if techLevel >= 3 then
		nextThreshold = t3Threshold
	elseif techLevel >= 2 then
		nextThreshold = t3Threshold
	else
		nextThreshold = t2Threshold
	end

	local progressPercent, isNegative = calculateProgressPercent(currentTechPoints, nextThreshold, techLevel, t2Threshold, t3Threshold)

	cachedDataTable.techLevel = techLevel
	cachedDataTable.currentTechPoints = math.floor(currentTechPoints)
	cachedDataTable.nextThreshold = nextThreshold
	cachedDataTable.progressPercent = progressPercent
	cachedDataTable.isNegative = isNegative

	return cachedDataTable
end

local function createTechPointsElements()
	if not widgetState.document then
		return
	end

	local fillElement = widgetState.document:GetElementById("tech-points-fill")
	local levelElement = widgetState.document:GetElementById("tech-level-number")
	local popupElement = widgetState.document:GetElementById("tech-level-popup")

	if fillElement and levelElement then
		widgetState.fillElement = fillElement
		widgetState.levelElement = levelElement
		widgetState.popupElement = popupElement
	end
end

local function updatePopups(techLevel)
	if not widgetState.initialPopupShown and widgetState.gameStartTime and (popupsEnabled or Spring.GetGameFrame() > POPUP_DELAY_FRAMES) then
		popupsEnabled = true
		if widgetState.document then
			updateUIElementText(widgetState.document, "tech-level-popup", spI18N("ui.techBlocking.techPopup.level1"))
		end
		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", true)
		end
		widgetState.initialPopupShown = true
		widgetState.popupEndTime = os.clock() + 3.0
	elseif techLevel ~= widgetState.previousTechLevel then
		local popupKey = "ui.techBlocking.techPopup.level" .. tostring(techLevel)
		if widgetState.document then
			updateUIElementText(widgetState.document, "tech-level-popup", spI18N(popupKey))
		end
		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", true)
		end
		widgetState.previousTechLevel = techLevel
		widgetState.popupEndTime = os.clock() + 3.0
	end

	if widgetState.popupEndTime > 0 and os.clock() >= widgetState.popupEndTime then
		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", false)
		end
		widgetState.popupEndTime = 0
	end
end

local function updateUI()
	if not widgetState.document then
		return
	end

	local data = updateTechPointsData()

	local uiChanged = data.techLevel ~= widgetState.lastDisplayedTechLevel or
		data.currentTechPoints ~= widgetState.lastDisplayedTechPoints or
		data.progressPercent ~= widgetState.lastDisplayedProgressPercent or
		data.isNegative ~= widgetState.lastDisplayedIsNegative

	updatePopups(data.techLevel)

	if uiChanged and widgetState.dmHandle then
		widgetState.dmHandle.techLevel = data.techLevel
		widgetState.dmHandle.currentTechPoints = data.currentTechPoints
		widgetState.dmHandle.nextThreshold = data.nextThreshold
		widgetState.dmHandle.progressPercent = data.progressPercent
	end

	if not widgetState.fillElement or not widgetState.levelElement then
		createTechPointsElements()
	end

	if uiChanged then
		if widgetState.fillElement then
			local heightValue = heightStrings[math.floor(data.progressPercent + 0.5)] or "0.0%"

			if data.isNegative ~= widgetState.lastDisplayedIsNegative then
				widgetState.fillElement:SetClass("negative-progress", data.isNegative)
			end

			widgetState.fillElement:SetAttribute("style", "height: " .. heightValue)
		end

		if widgetState.levelElement and data.techLevel ~= widgetState.lastDisplayedTechLevel then
			widgetState.levelElement.inner_rml = tostring(data.techLevel)
		end

		widgetState.lastDisplayedTechLevel = data.techLevel
		widgetState.lastDisplayedTechPoints = data.currentTechPoints
		widgetState.lastDisplayedProgressPercent = data.progressPercent
		widgetState.lastDisplayedIsNegative = data.isNegative
	end
end

function widget:Initialize()
	widgetState.gameStartTime = os.clock()

	local myTeamID = spGetMyTeamID()
	if myTeamID then
		widgetState.cachedMyTeamID = myTeamID
		local currentTechPoints = spGetTeamRulesParam(myTeamID, "tech_points") or 0
		widgetState.previousTechPoints = currentTechPoints
		widgetState.cachedTechPoints = currentTechPoints

		local techLevel = spGetTeamRulesParam(myTeamID, "tech_level") or 1
		widgetState.cachedTechLevel = techLevel
		widgetState.lastDisplayedTechLevel = techLevel
	end

	local baseT2 = modOptions.t2_tech_threshold or 100
	local baseT3 = modOptions.t3_tech_threshold or 1000

	if modOptions.tech_blocking_per_team then
		local myAllyTeamID = Spring.GetMyAllyTeamID()
		local teamList = Spring.GetTeamList(myAllyTeamID)
		widgetState.cachedTeamCount = #teamList
		widgetState.lastTeamCountUpdate = os.clock()
		widgetState.cachedT2Threshold = baseT2 * widgetState.cachedTeamCount
		widgetState.cachedT3Threshold = baseT3 * widgetState.cachedTeamCount
	else
		widgetState.cachedT2Threshold = baseT2
		widgetState.cachedT3Threshold = baseT3
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

	if currentTime - widgetState.lastUpdate > UPDATE_INTERVAL then
		widgetState.lastUpdate = currentTime
		updateUI()
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