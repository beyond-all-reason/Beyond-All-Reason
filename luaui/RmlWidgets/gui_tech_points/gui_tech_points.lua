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

local MODEL_NAME = "tech_points_model"
local RML_PATH = "luaui/RmlWidgets/gui_tech_points/gui_tech_points.rml"

local widgetState = {
	rmlContext = nil,
	document = nil,
	dmHandle = nil,
	lastUpdate = 0,
	updateInterval = 0.5,
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
	-- For tech level transitions, reset progress when reaching new levels
	if currentTechLevel and currentTechLevel == 1 and currentPoints >= t2Threshold then
		return 0 -- Reset for T2
	elseif currentTechLevel and currentTechLevel == 2 and currentPoints >= t3Threshold then
		return 0 -- Reset for T3
	else
		if nextThreshold <= 0 then return 0 end
		return math.min(100, (currentPoints / nextThreshold) * 100)
	end
end

local function updateTechPointsData()
	local myTeamID = spGetMyTeamID()
	if not myTeamID then return end

	local currentTechPoints = spGetTeamRulesParam(myTeamID, "tech_points") or 0
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

local function updateUI()
	if not widgetState.document then return end

	local data = updateTechPointsData()

	-- Update data model
	if widgetState.dmHandle then
		widgetState.dmHandle.techLevel = data.techLevel
		widgetState.dmHandle.currentTechPoints = data.currentTechPoints
		widgetState.dmHandle.nextThreshold = data.nextThreshold
		widgetState.dmHandle.progressPercent = data.progressPercent
	end

	-- Update progress bar height (vertical fill from bottom)
	local fillElement = widgetState.document:GetElementById("tech-points-fill")
	if fillElement then
		fillElement:SetAttribute("style", string.format("height: %.1f%%", data.progressPercent))
	end

	-- Update tech level display
	local levelElement = widgetState.document:GetElementById("tech-level-number")
	if levelElement then
		levelElement.inner_rml = tostring(data.techLevel)
	end
end

function widget:Initialize()
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

	-- Initial data update
	updateTechPointsData()

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

-- ViewResize removed - using CSS viewport units for responsive positioning
