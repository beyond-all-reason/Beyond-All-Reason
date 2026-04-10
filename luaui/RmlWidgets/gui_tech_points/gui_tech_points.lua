if not RmlUi then
	return
end

local widget = widget

function widget:GetInfo()
	return {
		name = "Tech Points Display",
		desc = "Displays Catalyst progress toward tech level thresholds",
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
local CACHE_INTERVAL = 0.5
local popupsEnabled = false

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

local cached = {
	techLevel = 1,
	points = 0,
	t2Threshold = 2,
	t3Threshold = 4,
}

local widgetState = {
	rmlContext = nil,
	document = nil,
	dmHandle = nil,
	lastUpdate = 0,
	fillElement = nil,
	levelElement = nil,
	countElement = nil,
	popupElement = nil,
	milestoneElements = {},
	previousTechLevel = 1,
	popupEndTime = 0,
	gameStartTime = nil,
	initialPopupShown = false,
	myTeamID = nil,
	lastCacheTime = 0,
}

local initialModel = {
	techLevel = 1,
	catalystCount = 0,
	nextThreshold = 2,
	progressPercent = 0,
}

local function refreshCache()
	local now = os.clock()
	if now - widgetState.lastCacheTime < CACHE_INTERVAL then
		return
	end
	widgetState.lastCacheTime = now

	local teamID = widgetState.myTeamID
	if not teamID then
		teamID = spGetMyTeamID()
		if not teamID then return end
		widgetState.myTeamID = teamID
	end

	local rawPoints = spGetTeamRulesParam(teamID, "tech_points")
	local rawLevel = spGetTeamRulesParam(teamID, "tech_level")
	local rawT2 = spGetTeamRulesParam(teamID, "tech_t2_threshold")
	local rawT3 = spGetTeamRulesParam(teamID, "tech_t3_threshold")

	cached.points = tonumber(rawPoints or 0) or 0
	cached.techLevel = tonumber(rawLevel or 1) or 1
	if rawT2 then cached.t2Threshold = tonumber(rawT2) or cached.t2Threshold end
	if rawT3 then cached.t3Threshold = tonumber(rawT3) or cached.t3Threshold end
end

local function getProgressPercent()
	if cached.techLevel >= 3 then
		return 100
	elseif cached.techLevel >= 2 then
		if cached.t3Threshold <= 0 then return 100 end
		return math.min(100, (cached.points / cached.t3Threshold) * 100)
	else
		if cached.t2Threshold <= 0 then return 100 end
		return math.min(100, (cached.points / cached.t2Threshold) * 100)
	end
end

local function getNextThreshold()
	if cached.techLevel >= 2 then
		return cached.t3Threshold
	end
	return cached.t2Threshold
end

local function updatePopups()
	local techLevel = cached.techLevel
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

local prevLevel, prevCount, prevProgress = 0, -1, -1

local function updateUI()
	if not widgetState.document then return end

	refreshCache()

	local progress = getProgressPercent()
	local nextThresh = getNextThreshold()
	local points = cached.points
	local level = cached.techLevel

	updatePopups()

	local changed = (level ~= prevLevel) or (points ~= prevCount) or (math.floor(progress + 0.5) ~= math.floor(prevProgress + 0.5))
	if not changed then return end

	if widgetState.dmHandle then
		widgetState.dmHandle.techLevel = level
		widgetState.dmHandle.catalystCount = points
		widgetState.dmHandle.nextThreshold = nextThresh
		widgetState.dmHandle.progressPercent = progress
	end

	if widgetState.fillElement then
		local h = heightStrings[math.floor(progress + 0.5)] or "0.0%"
		widgetState.fillElement:SetAttribute("style", "height: " .. h)

		local oneMore = (level < 3) and (points + 1 >= nextThresh)
		widgetState.fillElement:SetClass("one-more", oneMore)
	end

	if widgetState.levelElement and level ~= prevLevel then
		widgetState.levelElement.inner_rml = tostring(level)
	end

	if widgetState.countElement then
		widgetState.countElement.inner_rml = tostring(points) .. " / " .. tostring(nextThresh)
	end

	-- Update milestone indicators (T1=1, T2=2, T3=3)
	for i, el in ipairs(widgetState.milestoneElements) do
		if el then
			el:SetClass("reached", i <= level)
			el:SetClass("active", i == level)
		end
	end

	prevLevel = level
	prevCount = points
	prevProgress = progress
end

function widget:Initialize()
	widgetState.gameStartTime = os.clock()
	widgetState.myTeamID = spGetMyTeamID()

	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then return false end

	local dm = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dm then return false end
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

	widgetState.fillElement = document:GetElementById("tech-points-fill")
	widgetState.levelElement = document:GetElementById("tech-level-number")
	widgetState.countElement = document:GetElementById("tech-catalyst-count")
	widgetState.popupElement = document:GetElementById("tech-level-popup")
	widgetState.milestoneElements = {
		document:GetElementById("milestone-t1"),
		document:GetElementById("milestone-t2"),
		document:GetElementById("milestone-t3"),
	}

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
	if os.clock() - widgetState.lastUpdate > UPDATE_INTERVAL then
		widgetState.lastUpdate = os.clock()
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
