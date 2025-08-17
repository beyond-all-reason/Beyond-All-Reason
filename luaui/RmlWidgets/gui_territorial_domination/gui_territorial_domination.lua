if not RmlUi then
	return
end

local widget = widget

function widget:GetInfo()
	return {
		name = "Territorial Domination Score Display",
		desc = "Displays score bars for territorial domination game mode below the minimap",
		author = "Mupersega",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end
-- notes
-- TODO:
-- - the countdown timer needs to do something attention grabbing when it gets close to round end
-- need to detect and disable itself if scavengers or raptors enabled or else handle the modes
-- need to add halo effect to your allyteam or the team that's selected anyway.
local modOptions = Spring.GetModOptions()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) then
	return false
end

local MODEL_NAME = "territorial_score_model"
local RML_PATH = "luaui/RmlWidgets/gui_territorial_domination/gui_territorial_domination.rml"

local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetTeamList = Spring.GetTeamList
local spGetTeamColor = Spring.GetTeamColor

local SCREEN_HEIGHT = 1080
local HEADER_HEIGHT = 18
local MAX_HEIGHT = 248
local MAX_COLUMNS = 4
local MAX_TEAMS_PER_COLUMN_HEIGHT = 220
local BACKGROUND_COLOR_ALPHA = 204
local DEFAULT_POINTS_CAP = 100
local PROJECTED_COLOR_ALPHA = 100
local PERCENTAGE_MULTIPLIER = 100
local FILL_COLOR_ALPHA = 230
local COLOR_MULTIPLIER = 255
local DEFAULT_COLOR_VALUE = 0.5
local DARK_COLOR_MULTIPLIER = 0.25
local UPDATE_INTERVAL = 0.1
local SECONDS_PER_MINUTE = 60
local SMALL_MARGIN = 2
local BIG_MARGIN = 4
local SCORE_BAR_MIN_WIDTH = 80
local SCORE_BAR_HEIGHT = 18
local MAX_CONTAINER_WIDTH = 300

local uiDimensions = {
	scoreBarHeightWithPadding = SCORE_BAR_HEIGHT + (SMALL_MARGIN * 3),
	headerHeight = HEADER_HEIGHT + (SMALL_MARGIN * 3),
}

local widgetState = {
	document = nil,
	dmHandle = nil,
	rmlContext = nil,
	lastUpdateTime = 0,
	updateInterval = UPDATE_INTERVAL,
	allyTeamData = {},
	lastMinimapGeometry = { 0, 0, 0, 0 },
	scoreElements = {},
	hiddenByLobby = false,
}

local initialModel = {
	allyTeams = {},
	currentRound = 1,
	roundEndTime = 0,
	pointsCap = 0,
	highestScore = 0,
	secondHighestScore = 0,
	timeRemaining = "0:00",
	roundDisplayText = "Round 1",
}

local function getAllyTeamColor(allyTeamID)
	local teamList = spGetTeamList(allyTeamID)
	if teamList and #teamList > 0 then
		local teamID = teamList[1]
		local r, g, b = spGetTeamColor(teamID)
		return { r = r, g = g, b = b }
	end
	return { r = DEFAULT_COLOR_VALUE, g = DEFAULT_COLOR_VALUE, b = DEFAULT_COLOR_VALUE }
end

local function updateAllyTeamData()
	local allyTeamList = spGetAllyTeamList()
	local validAllyTeams = {}

	for i = 1, #allyTeamList do
		local allyTeamID = allyTeamList[i] - 1
		local teamList = spGetTeamList(allyTeamID)

		if teamList and #teamList > 0 then
			local firstTeamID = teamList[1]
			table.insert(validAllyTeams, {
				name = "Ally " .. (allyTeamID + 1),
				allyTeamID = allyTeamID,
				firstTeamID = firstTeamID,
				score = spGetTeamRulesParam(firstTeamID, "territorialDominationScore") or 0,
				projectedPoints = spGetTeamRulesParam(firstTeamID, "territorialDominationProjectedPoints") or 0,
				color = getAllyTeamColor(allyTeamID),
				teamCount = #teamList,
			})
		end
	end

	table.sort(validAllyTeams, function(a, b)
		local aCombinedScore = a.score + a.projectedPoints
		local bCombinedScore = b.score + b.projectedPoints

		if aCombinedScore ~= bCombinedScore then
			return aCombinedScore > bCombinedScore
		end
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.allyTeamID < b.allyTeamID
	end)

	widgetState.allyTeamData = validAllyTeams
	return validAllyTeams
end

local function updateRoundInfo()
	local roundEndTime = spGetGameRulesParam("territorialDominationRoundEndTimestamp") or 0
	local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
	local highestScore = spGetGameRulesParam("territorialDominationHighestScore") or 0
	local secondHighestScore = spGetGameRulesParam("territorialDominationSecondHighestScore") or 0

	local currentRound = spGetGameRulesParam("territorialDominationCurrentRound") or 1
	local maxRounds = spGetGameRulesParam("territorialDominationMaxRounds") or 7

	if currentRound <= 0 then
		local currentTime = Spring.GetGameSeconds()
		local roundDuration = spGetGameRulesParam("territorialDominationRoundDuration") or 300
		local gameStartOffset = spGetGameRulesParam("territorialDominationStartTime") or 0

		local elapsedTime = currentTime - gameStartOffset
		currentRound = math.floor(elapsedTime / roundDuration) + 1
	end

	local timeString = "0:00"
	if roundEndTime > 0 then
		local timeRemaining = math.max(0, roundEndTime - Spring.GetGameSeconds())
		local minutes = math.floor(timeRemaining / SECONDS_PER_MINUTE)
		local seconds = math.floor(timeRemaining % SECONDS_PER_MINUTE)
		timeString = string.format("%d:%02d", minutes, seconds)
	end

	local roundDisplayText = currentRound > maxRounds and "Overtime" or string.format("Round %d/%d", currentRound, maxRounds)

	return {
		currentRound = currentRound,
		roundEndTime = roundEndTime,
		pointsCap = pointsCap,
		highestScore = highestScore,
		secondHighestScore = secondHighestScore,
		timeRemaining = timeString,
		roundDisplayText = roundDisplayText,
	}
end

local function calculateUILayout()
	local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY = spGetMiniMapGeometry()
	local currentGeometry = { minimapPosX, minimapPosY, minimapSizeX, minimapSizeY }

	if currentGeometry[1] == widgetState.lastMinimapGeometry[1] and
		currentGeometry[2] == widgetState.lastMinimapGeometry[2] and
		currentGeometry[3] == widgetState.lastMinimapGeometry[3] and
		currentGeometry[4] == widgetState.lastMinimapGeometry[4] then
		return
	end

	widgetState.lastMinimapGeometry = currentGeometry

	local effectiveMaxWidth = math.min(MAX_CONTAINER_WIDTH, minimapSizeX)

	widgetState.uiState = {
		position = {
			x = minimapPosX,
			y = SCREEN_HEIGHT - minimapPosY,
			width = effectiveMaxWidth,
			height = nil,
		},
		availableWidth = effectiveMaxWidth - (BIG_MARGIN * 2),
		maxHeight = MAX_HEIGHT,
	}
end

local function calculateColumnWidth(numColumns)
	local totalGapWidth = (numColumns - 1) * SMALL_MARGIN
	local availableWidthForColumns = widgetState.uiState.availableWidth - totalGapWidth
	return math.floor(availableWidthForColumns / numColumns)
end

local function createScoreBarElement(columnDiv, allyTeam, index)
	local scoreBarDiv = widgetState.document:CreateElement("div")
	scoreBarDiv.class_name = "score-bar"
	scoreBarDiv:SetAttribute("style",
		string.format("padding: %dpx %dpx; border-radius: %dpx; min-width: %dpx; margin-bottom: %dpx;",
			SMALL_MARGIN, SMALL_MARGIN, SMALL_MARGIN,
			SCORE_BAR_MIN_WIDTH, SMALL_MARGIN))

	local containerDiv = widgetState.document:CreateElement("div")
	containerDiv.class_name = "score-bar-container"
	containerDiv:SetAttribute("style", string.format("height: %dpx; border-radius: %dpx;",
		SCORE_BAR_HEIGHT, SMALL_MARGIN))

	local backgroundDiv = widgetState.document:CreateElement("div")
	backgroundDiv.class_name = "score-bar-background"

	local darkBackgroundColor = {
		r = math.floor(allyTeam.color.r * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		g = math.floor(allyTeam.color.g * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		b = math.floor(allyTeam.color.b * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		a = BACKGROUND_COLOR_ALPHA
	}
	backgroundDiv:SetAttribute("style", string.format("background-color: rgba(%d, %d, %d, %d)",
		darkBackgroundColor.r, darkBackgroundColor.g, darkBackgroundColor.b, darkBackgroundColor.a))

	local projectedDiv = widgetState.document:CreateElement("div")
	projectedDiv.class_name = "score-bar-projected"
	projectedDiv.id = "projected-fill-" .. index

	local fillDiv = widgetState.document:CreateElement("div")
	fillDiv.class_name = "score-bar-fill"
	fillDiv.id = "score-fill-" .. index

	local currentScoreText = widgetState.document:CreateElement("div")
	currentScoreText.class_name = "score-text current"
	currentScoreText.id = "current-score-" .. index
	currentScoreText.inner_rml = tostring(allyTeam.score)
	currentScoreText:SetAttribute("style", string.format("left: %dpx;", SMALL_MARGIN))

	local projectedScoreText = widgetState.document:CreateElement("div")
	projectedScoreText.class_name = "score-text projected"
	projectedScoreText.id = "projected-score-" .. index
	projectedScoreText.inner_rml = "+" .. tostring(allyTeam.projectedPoints)
	projectedScoreText:SetAttribute("style", string.format("right: %dpx;", SMALL_MARGIN))

	containerDiv:AppendChild(backgroundDiv)
	containerDiv:AppendChild(projectedDiv)
	containerDiv:AppendChild(fillDiv)
	containerDiv:AppendChild(currentScoreText)
	containerDiv:AppendChild(projectedScoreText)

	scoreBarDiv:AppendChild(containerDiv)
	columnDiv:AppendChild(scoreBarDiv)

	return {
		container = scoreBarDiv,
		currentScoreElement = currentScoreText,
		projectedScoreElement = projectedScoreText,
		projectedElement = projectedDiv,
		fillElement = fillDiv,
	}
end

local function updateElementStyles()
	if not widgetState.document then return end
	
	local function updateElementsByClass(className, styleFormat, ...)
		local elements = widgetState.document:GetElementsByClassName(className)
		for i = 0, elements:GetNumElements() - 1 do
			elements:GetElement(i):SetAttribute("style", string.format(styleFormat, ...))
		end
	end

	local function updateScoreElements()
		if not widgetState.scoreElements then return end
		for i, scoreElements in ipairs(widgetState.scoreElements) do
			if scoreElements.currentScoreElement then
				scoreElements.currentScoreElement:SetAttribute("style", string.format("left: %dpx;", SMALL_MARGIN))
			end
			if scoreElements.projectedScoreElement then
				scoreElements.projectedScoreElement:SetAttribute("style", string.format("right: %dpx;", SMALL_MARGIN))
			end
		end
	end

	updateScoreElements()
	updateElementsByClass("score-bar", "padding: %dpx %dpx; border-radius: %dpx; min-width: %dpx; margin-bottom: %dpx;",
		SMALL_MARGIN, SMALL_MARGIN, SMALL_MARGIN, SCORE_BAR_MIN_WIDTH, SMALL_MARGIN)
	updateElementsByClass("score-bar-container", "height: %dpx; border-radius: %dpx;",
		SCORE_BAR_HEIGHT, SMALL_MARGIN)
	updateElementsByClass("score-column", "padding: 0px %dpx;", SMALL_MARGIN)
end

local function setCSSVariables()
	if not widgetState.document then return end
	
	local function setElementStyle(elementId, styleFormat, ...)
		local element = widgetState.document:GetElementById(elementId)
		if element then
			element:SetAttribute("style", string.format(styleFormat, ...))
		end
	end

	setElementStyle("score-container", "padding: %dpx; border-radius: %dpx; max-width: %dpx;",
		BIG_MARGIN, BIG_MARGIN, MAX_CONTAINER_WIDTH)
	setElementStyle("header-info", "margin-bottom: %dpx; padding: %dpx %dpx; border-radius: %dpx;",
		SMALL_MARGIN, SMALL_MARGIN, SMALL_MARGIN, SMALL_MARGIN)
	setElementStyle("victory-points", "margin-top: %dpx; padding: %dpx %dpx;",
		SMALL_MARGIN, SMALL_MARGIN, SMALL_MARGIN)
end

local function updateDynamicHeight()
	if not widgetState.document or not widgetState.uiState then return end

	local allyTeams = widgetState.allyTeamData
	local numTeams = #allyTeams
	local headerHeight = uiDimensions.headerHeight

	if numTeams == 0 then
		local minHeight = headerHeight + (BIG_MARGIN * 2)
		widgetState.uiState.height = minHeight
		widgetState.uiState.numColumns = 1
		widgetState.uiState.teamsPerColumn = 0

		local rootElement = widgetState.document:GetElementById("score-container")
		if rootElement then
			local scorePosX = widgetState.uiState.position.x
			local scorePosY = widgetState.uiState.position.y
			local containerWidth = widgetState.uiState.position.width
			rootElement:SetAttribute("style", string.format("left: %dpx; top: %dpx; width: %dpx; height: %dpx",
				scorePosX, scorePosY, containerWidth, minHeight))
		end
		return
	end

	local maxTeamsPerColumn = math.floor(MAX_TEAMS_PER_COLUMN_HEIGHT / uiDimensions.scoreBarHeightWithPadding)
	local teamsPerColumn = math.min(maxTeamsPerColumn, numTeams)
	local numColumns = math.ceil(numTeams / teamsPerColumn)

	local minColumnWidth = SMALL_MARGIN * 2 + SCORE_BAR_MIN_WIDTH
	local maxColumnsByWidth = math.floor((widgetState.uiState and widgetState.uiState.availableWidth or MAX_CONTAINER_WIDTH) / minColumnWidth)
	maxColumnsByWidth = math.max(1, math.min(maxColumnsByWidth, MAX_COLUMNS))

	if numColumns > maxColumnsByWidth then
		numColumns = maxColumnsByWidth
		teamsPerColumn = math.ceil(numTeams / numColumns)
	end

	local scoreBarHeight = uiDimensions.scoreBarHeightWithPadding
	local actualTeamsPerColumn = math.ceil(numTeams / numColumns)
	local heightPerColumn = (actualTeamsPerColumn * scoreBarHeight) + BIG_MARGIN
	local totalHeight = headerHeight + heightPerColumn + (BIG_MARGIN * 2)

	widgetState.uiState.height = totalHeight
	widgetState.uiState.numColumns = numColumns
	widgetState.uiState.teamsPerColumn = teamsPerColumn

	local rootElement = widgetState.document:GetElementById("score-container")
	if rootElement then
		local scorePosX = widgetState.uiState.position.x
		local scorePosY = widgetState.uiState.position.y
		local containerWidth = widgetState.uiState.position.width
		local requiredWidth = (numColumns * calculateColumnWidth(numColumns)) + ((numColumns - 1) * SMALL_MARGIN) + (BIG_MARGIN * 2)
		local finalWidth = math.max(containerWidth, requiredWidth)
		
		rootElement:SetAttribute("style", string.format("left: %dpx; top: %dpx; width: %dpx; height: %dpx",
			scorePosX, scorePosY, finalWidth, totalHeight))

		local columnsContainer = widgetState.document:GetElementById("score-columns")
		if columnsContainer then
			columnsContainer:SetAttribute("style", string.format("height: %dpx", heightPerColumn))
		end
	end
end

local function updateScoreBarVisuals()
	if not widgetState.document then return end

	local dm = widgetState.dmHandle
	local allyTeams = widgetState.allyTeamData
	local columnsContainer = widgetState.document:GetElementById("score-columns")
	if not columnsContainer then return end

	columnsContainer.inner_rml = ""
	widgetState.scoreElements = {}

	local numTeams = #allyTeams
	if numTeams == 0 then return end

	local numColumns = widgetState.uiState.numColumns or 1
	local teamsPerColumn = widgetState.uiState.teamsPerColumn or numTeams

	local columns = {}
	for i = 1, numColumns do
		local columnDiv = widgetState.document:CreateElement("div")
		columnDiv.class_name = "score-column"
		local columnWidth = calculateColumnWidth(numColumns)
		local columnLeft = (i - 1) * (columnWidth + SMALL_MARGIN)
		columnDiv:SetAttribute("style",
			string.format("position: absolute; left: %dpx; width: %dpx; top: 0px; padding: 0px %dpx; height: 100%%;",
				columnLeft, columnWidth, SMALL_MARGIN))
		columnsContainer:AppendChild(columnDiv)
		columns[i] = columnDiv
	end

	for i, allyTeam in ipairs(allyTeams) do
		local columnIndex = ((i - 1) % numColumns) + 1
		local scoreBarElements = createScoreBarElement(columns[columnIndex], allyTeam, i)
		widgetState.scoreElements[i] = scoreBarElements

		local projectedWidth = "0%"
		if dm.pointsCap > 0 then
			local totalProjected = allyTeam.score + allyTeam.projectedPoints
			projectedWidth = string.format("%.1f%%",
				math.min(PERCENTAGE_MULTIPLIER, (totalProjected / dm.pointsCap) * PERCENTAGE_MULTIPLIER))
		end

		local projectedColor = string.format("rgba(%d, %d, %d, %d)",
			allyTeam.color.r * COLOR_MULTIPLIER, allyTeam.color.g * COLOR_MULTIPLIER, allyTeam.color.b * COLOR_MULTIPLIER,
			PROJECTED_COLOR_ALPHA)
		scoreBarElements.projectedElement:SetAttribute("style",
			"width: " .. projectedWidth .. "; background-color: " .. projectedColor)

		local fillWidth = "0%"
		if dm.pointsCap > 0 then
			fillWidth = string.format("%.1f%%",
				math.min(PERCENTAGE_MULTIPLIER, (allyTeam.score / dm.pointsCap) * PERCENTAGE_MULTIPLIER))
		end

		local fillColor = string.format("rgba(%d, %d, %d, %d)",
			allyTeam.color.r * COLOR_MULTIPLIER, allyTeam.color.g * COLOR_MULTIPLIER, allyTeam.color.b * COLOR_MULTIPLIER,
			FILL_COLOR_ALPHA)
		scoreBarElements.fillElement:SetAttribute("style", "width: " .. fillWidth .. "; background-color: " .. fillColor)

		if scoreBarElements.currentScoreElement then
			scoreBarElements.currentScoreElement.inner_rml = tostring(allyTeam.score)
		end
		if scoreBarElements.projectedScoreElement then
			scoreBarElements.projectedScoreElement.inner_rml = "+" .. tostring(allyTeam.projectedPoints)
		end
	end

	updateDynamicHeight()
end

local function updateDataModel()
	if not widgetState.dmHandle then return end

	local allyTeams = updateAllyTeamData()
	local roundInfo = updateRoundInfo()
	local dm = widgetState.dmHandle

	dm.allyTeams = allyTeams
	dm.currentRound = roundInfo.currentRound
	dm.roundEndTime = roundInfo.roundEndTime
	dm.pointsCap = roundInfo.pointsCap
	dm.highestScore = roundInfo.highestScore
	dm.secondHighestScore = roundInfo.secondHighestScore
	dm.timeRemaining = roundInfo.timeRemaining
	dm.roundDisplayText = roundInfo.roundDisplayText

	dm:__SetDirty("allyTeams")
	dm:__SetDirty("pointsCap")
	dm:__SetDirty("currentRound")
	dm:__SetDirty("timeRemaining")
	dm:__SetDirty("roundDisplayText")

	calculateUILayout()

	if widgetState.document then
		updateScoreBarVisuals()
	end
end

local function rebuildUIDimensions()
	uiDimensions = {
		scoreBarHeightWithPadding = SCORE_BAR_HEIGHT + (SMALL_MARGIN * 3),
		headerHeight = HEADER_HEIGHT + (SMALL_MARGIN * 3),
	}
end

local function updateUIAndLayout()
	setCSSVariables()
	updateElementStyles()

	local rootElement = widgetState.document:GetElementById("score-container")
	if rootElement then
		rootElement:SetAttribute("style", string.format("padding: %dpx; border-radius: %dpx; max-width: %dpx;",
			BIG_MARGIN, BIG_MARGIN, MAX_CONTAINER_WIDTH))
	end

	if widgetState.uiState then
		calculateUILayout()
		updateDynamicHeight()
	end
end

function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then return false end

	local dmHandle = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dmHandle then
		widget:Shutdown()
		return false
	end

	widgetState.dmHandle = dmHandle

	local document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not document then
		widget:Shutdown()
		return false
	end

	widgetState.document = document

	document:ReloadStyleSheet()
	document:Show()

	calculateUILayout()
	updateDynamicHeight()
	updateDataModel()
	setCSSVariables()

	return true
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		if widgetState.document then
			widgetState.document:Show()
			widgetState.hiddenByLobby = false
		end
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		if widgetState.document then
			widgetState.document:Hide()
			widgetState.hiddenByLobby = true
		end
	end
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
	widgetState.scoreElements = {}
end

function widget:updateMargins(newSmallMargin, newBigMargin)
	SMALL_MARGIN = newSmallMargin or SMALL_MARGIN
	BIG_MARGIN = newBigMargin or BIG_MARGIN

	rebuildUIDimensions()
	updateUIAndLayout()
end

function widget:updateUIConstants(newScoreBarMinWidth, newScoreBarHeight, newMaxContainerWidth)
	SCORE_BAR_MIN_WIDTH = newScoreBarMinWidth or SCORE_BAR_MIN_WIDTH
	SCORE_BAR_HEIGHT = newScoreBarHeight or SCORE_BAR_HEIGHT
	MAX_CONTAINER_WIDTH = newMaxContainerWidth or MAX_CONTAINER_WIDTH

	rebuildUIDimensions()
	updateUIAndLayout()
end

function widget:Update()
	local currentTime = Spring.GetGameSeconds()
	if currentTime - widgetState.lastUpdateTime >= widgetState.updateInterval then
		local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
		if pointsCap and pointsCap > 0 then
			if widgetState.document and not widgetState.hiddenByLobby then
				widgetState.document:Show()
			end
			if widgetState.document then
				updateDataModel()
			end
			widgetState.lastUpdateTime = currentTime
		else
			if widgetState.document then
				widgetState.document:Hide()
			end
		end
	end
end

function widget:DrawScreen()
	if widgetState.document then
		local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
		if pointsCap and pointsCap > 0 then
			widgetState.rmlContext:Render()
		end
	end
end
