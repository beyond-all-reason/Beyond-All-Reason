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

-- Only enable if tech blocking is active
if not modOptions or not modOptions.tech_blocking then
	return false
end

local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetMyTeamID = Spring.GetMyTeamID
local spI18N = Spring.I18N

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
	fillElement = nil,
	levelElement = nil,
	popupElement = nil,
	previousTechLevel = 1,
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
		return t3Threshold -- Already at max level
	elseif currentPoints >= t2Threshold then
		return t3Threshold -- Next is T3
	else
		return t2Threshold -- Next is T2
	end
end

local function calculateProgressPercent(currentPoints, nextThreshold, currentTechLevel, t2Threshold, t3Threshold)
	-- Calculate progress towards the next threshold
	-- When reaching a threshold, the progress should continue from where it left off
	-- but visually reset to show progress towards the new threshold

	if nextThreshold <= 0 then
		return 0
	end

	-- If we've reached T3 (max level), show 100%
	if currentPoints >= t3Threshold then
		return 100
	end

	-- If we've reached T2 but not T3, show progress towards T3
	if currentPoints >= t2Threshold then
		local progressInT2 = (currentPoints - t2Threshold) / (t3Threshold - t2Threshold) * 100
		return math.min(100, progressInT2)
	end

	-- If we're still in T1, show progress towards T2
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

-- Positioning function removed - using CSS viewport units instead

local function createTechPointsElements()
	if not widgetState.document then
		return
	end

	-- Try to find elements multiple times in case document isn't ready yet
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

		-- Small delay between attempts
		if attempt < 5 then
			local currentTime = os.clock()
			while os.clock() - currentTime < 0.01 do end -- 10ms delay
		end
	end
end

local function updateUI()
	if not widgetState.document then
		return
	end

	local data = updateTechPointsData()

	-- Check if 10 seconds have passed and show initial tech level popup
	if not widgetState.initialPopupShown and widgetState.gameStartTime and
	   (os.clock() - widgetState.gameStartTime) >= 10.0 then
		local popupText = spI18N("ui.techBlocking.techPopup.level1")
		if widgetState.document then
			updateUIElementText(widgetState.document, "tech-level-popup", popupText)
		end

		-- Trigger popup animation
		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", true)
		end

		widgetState.initialPopupShown = true
		widgetState.popupEndTime = os.clock() + 3.0  -- 3 seconds animation
	end

	-- Check if tech level changed and show popup
	if data.techLevel ~= widgetState.previousTechLevel then
		local popupKey = "ui.techBlocking.techPopup.level" .. tostring(data.techLevel)
		local popupText = spI18N(popupKey)
		if widgetState.document then
			updateUIElementText(widgetState.document, "tech-level-popup", popupText)
		end

		-- Trigger popup animation
		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", true)
		end

		widgetState.previousTechLevel = data.techLevel
		widgetState.popupEndTime = os.clock() + 3.0  -- 3 seconds animation
	end

	-- Hide popup after animation completes
	if widgetState.popupEndTime > 0 and os.clock() >= widgetState.popupEndTime then
		if widgetState.popupElement then
			widgetState.popupElement:SetClass("show-popup", false)
		end
		widgetState.popupEndTime = 0
	end

	-- Update data model
	if widgetState.dmHandle then
		widgetState.dmHandle.techLevel = data.techLevel
		widgetState.dmHandle.currentTechPoints = data.currentTechPoints
		widgetState.dmHandle.nextThreshold = data.nextThreshold
		widgetState.dmHandle.progressPercent = data.progressPercent
	end

	-- Ensure elements exist, recreate if needed
	if not widgetState.fillElement or not widgetState.levelElement then
		createTechPointsElements()
	end

	-- Update progress bar height (vertical fill from bottom)
	if widgetState.fillElement then
		local heightValue = string.format("%.1f%%", data.progressPercent)
		widgetState.fillElement:SetAttribute("style", "height: " .. heightValue)
	end

	-- Update tech level display
	if widgetState.levelElement then
		local levelText = tostring(data.techLevel)
		widgetState.levelElement.inner_rml = levelText
	end
end

function widget:Initialize()
	widgetState.gameStartTime = os.clock()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		return false
	end

	widget:ContinueInitialize()
	return true
end

function widget:ContinueInitialize()
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

	-- Create element references
	createTechPointsElements()

	-- Initial data update and UI refresh
	updateUI()

	return true
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

	-- Update tech points data periodically
	if currentTime - widgetState.lastUpdate > widgetState.updateInterval then
		widgetState.lastUpdate = currentTime
		updateUI()
	end
end
