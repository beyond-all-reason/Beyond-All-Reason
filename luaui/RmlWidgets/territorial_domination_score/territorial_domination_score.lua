if not RmlUi then
	return
end

local widget = widget ---@type Widget

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

local modOptions = Spring.GetModOptions()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) then 
	return false 
end

-- @https://github.com/beyond-all-reason/RecoilEngine/tree/aed81b7cc721aa964f850ec9960af287f66bf98c/rts/Rml/SolLua/bind 
-- @https://github.com/beyond-all-reason/Beyond-All-Reason/blob/rmlui-example-widgets/luaui/Widgets/rml_top_bar2.lua 
-- @https://github.com/beyond-all-reason/Beyond-All-Reason/blob/rmlui-example-widgets/luaui/Widgets/rml_widget_assets/gui_top_bar2.rml 

-- Use this contexts to understand what's doable and what isn't. BAR uses a custom lua integration that is more simple than other games.

local WIDGET_NAME = "Territorial Domination Score"
local MODEL_NAME = "territorial_score_model"
local RML_PATH = "luaui/RmlWidgets/territorial_domination_score/territorial_domination_score.rml"

local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetTeamList = Spring.GetTeamList
local spGetTeamColor = Spring.GetTeamColor
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID

local SCREEN_HEIGHT = 1080

local widgetState = {
	document = nil,
	dmHandle = nil,
	rmlContext = nil,
	lastUpdateTime = 0,
	updateInterval = 0.1,
	allyTeamData = {},
	lastMinimapGeometry = {0, 0, 0, 0},
	scoreElements = {},
	uiMargins = {
		containerPadding = 3,
		columnGap = 2,
		scoreBarPadding = 1.5,
		headerPadding = 2,
		headerMargin = 1.5,
		victoryMargin = 1.5,
	},
	hiddenByLobby = false,
}

local initialModel = {
	allyTeams = {},
	currentRound = 1,
	roundEndTime = 0,
	pointsCap = 0,
	highestScore = 0,
	secondHighestScore = 0,
	timeRemaining = "00:00",
	roundDisplayText = "Round 1",
}

local function getAllyTeamColor(allyTeamID)
	local teamList = spGetTeamList(allyTeamID)
	if teamList and #teamList > 0 then
		local teamID = teamList[1]
		local r, g, b = spGetTeamColor(teamID)
		return {r = r, g = g, b = b}
	end
	return {r = 0.5, g = 0.5, b = 0.5}
end

local function updateAllyTeamData()
	local allyTeamList = spGetAllyTeamList()
	local validAllyTeams = {}
	
	for i = 1, #allyTeamList do
		local allyTeamID = allyTeamList[i] - 1
		local teamList = spGetTeamList(allyTeamID)
		
		if teamList and #teamList > 0 then
			-- Get score and projected points from the first team in the ally team
			local firstTeamID = teamList[1]
			local score = spGetTeamRulesParam(firstTeamID, "territorialDominationScore") or 0
			local projectedPoints = spGetTeamRulesParam(firstTeamID, "territorialDominationProjectedPoints") or 0
			
			-- Get team color from the first team
			local teamColor = getAllyTeamColor(allyTeamID)
			
			-- Include all ally teams, even with 0 scores, so we can see the full competition
			table.insert(validAllyTeams, {
				name = "Ally " .. (allyTeamID + 1),
				allyTeamID = allyTeamID,
				firstTeamID = firstTeamID,
				score = score,
				projectedPoints = projectedPoints,
				color = teamColor, -- Store the raw RGB values
				teamCount = #teamList,
			})
		end
	end
	
	-- Sort by combined score (current + predicted) descending (highest first)
	table.sort(validAllyTeams, function(a, b) 
		local aCombinedScore = a.score + a.projectedPoints
		local bCombinedScore = b.score + b.projectedPoints
		
		if aCombinedScore == bCombinedScore then
			-- If combined scores are equal, sort by current score
			if a.score == b.score then
				return a.allyTeamID < b.allyTeamID -- Tertiary sort by ally team ID for consistency
			end
			return a.score > b.score
		end
		return aCombinedScore > bCombinedScore 
	end)
	
	widgetState.allyTeamData = validAllyTeams
	return validAllyTeams
end

local function updateRoundInfo()
	local roundEndTime = spGetGameRulesParam("territorialDominationRoundEndTimestamp") or 0
	local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or 100
	local highestScore = spGetGameRulesParam("territorialDominationHighestScore") or 0
	local secondHighestScore = spGetGameRulesParam("territorialDominationSecondHighestScore") or 0
	
	-- Get current round directly from game rules if available
	local currentRound = spGetGameRulesParam("territorialDominationCurrentRound") or 1
	local maxRounds = spGetGameRulesParam("territorialDominationMaxRounds") or 7
	
	-- Handle overtime and calculate round if needed
	if currentRound <= 0 then
		local currentTime = Spring.GetGameSeconds()
		local roundDuration = spGetGameRulesParam("territorialDominationRoundDuration") or 300 -- Default 5 minutes
		local gameStartOffset = spGetGameRulesParam("territorialDominationStartTime") or 0
		
		-- Calculate which round we're in
		local elapsedTime = currentTime - gameStartOffset
		currentRound = math.floor(elapsedTime / roundDuration) + 1
		-- Don't clamp to max rounds - allow overtime rounds
	end
	
	-- Calculate time remaining in current round
	local timeString
	if roundEndTime == 0 then
	
		timeString = "0:00"
	else
		local timeRemaining = math.max(0, roundEndTime - Spring.GetGameSeconds())
		local minutes = math.floor(timeRemaining / 60)
		local seconds = math.floor(timeRemaining % 60)
		timeString = string.format("%d:%02d", minutes, seconds)
	end
	
	-- Format round display text
	local roundDisplayText
	if currentRound > maxRounds then
		-- For overtime rounds, just show "Overtime"
		roundDisplayText = "Overtime"
	else
		-- For regular rounds, show as "Round X/Y"
		roundDisplayText = string.format("Round %d/%d", currentRound, maxRounds)
	end
	
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
	
	if minimapPosX == widgetState.lastMinimapGeometry[1] and 
	   minimapPosY == widgetState.lastMinimapGeometry[2] and 
	   minimapSizeX == widgetState.lastMinimapGeometry[3] and 
	   minimapSizeY == widgetState.lastMinimapGeometry[4] then
		return
	end
	
	widgetState.lastMinimapGeometry = {minimapPosX, minimapPosY, minimapSizeX, minimapSizeY}
	
	-- Constrain to 300x248 area below minimap, but limit width to minimap width
	-- Account for margins: container padding (left + right) + column gaps
	local effectiveMaxWidth = math.min(300, minimapSizeX)
	local maxWidth = effectiveMaxWidth - (widgetState.uiMargins.containerPadding * 2)
	
	-- Position the score display below the minimap (growing downward)
	local scorePosX = minimapPosX
	local scorePosY = SCREEN_HEIGHT - minimapPosY -- Position directly below minimap with no gap
	
	-- Store UI state in widget state instead of data model
	widgetState.uiState = {
		position = {
			x = scorePosX,
			y = scorePosY,
			width = effectiveMaxWidth,
			height = 0, -- Will be calculated dynamically
		},
		availableWidth = maxWidth,
	}
end
local function createScoreBarElement(columnDiv, allyTeam, index)
	local scoreBarDiv = widgetState.document:CreateElement("div")
	scoreBarDiv.class_name = "score-bar"
	
	-- Create score bar container
	local containerDiv = widgetState.document:CreateElement("div")
	containerDiv.class_name = "score-bar-container"
	
	local backgroundDiv = widgetState.document:CreateElement("div")
	backgroundDiv.class_name = "score-bar-background"
	
	local darkBackgroundColor = {
		r = allyTeam.color.r * 0.25,
		g = allyTeam.color.g * 0.25,
		b = allyTeam.color.b * 0.25,
		a = 204
	}
	backgroundDiv:SetAttribute("style", string.format("background-color: rgba(%d, %d, %d, %d)", 
		math.floor(darkBackgroundColor.r * 255), 
		math.floor(darkBackgroundColor.g * 255), 
		math.floor(darkBackgroundColor.b * 255), 
		darkBackgroundColor.a))
	
	local projectedDiv = widgetState.document:CreateElement("div")
	projectedDiv.class_name = "score-bar-projected"
	projectedDiv.id = "projected-fill-" .. index
	
	local fillDiv = widgetState.document:CreateElement("div")
	fillDiv.class_name = "score-bar-fill"
	fillDiv.id = "score-fill-" .. index
	
	-- Create score text elements
	local currentScoreText = widgetState.document:CreateElement("div")
	currentScoreText.class_name = "score-text current"
	currentScoreText.id = "current-score-" .. index
	currentScoreText.inner_rml = tostring(allyTeam.score)
	
	local projectedScoreText = widgetState.document:CreateElement("div")
	projectedScoreText.class_name = "score-text projected"
	projectedScoreText.id = "projected-score-" .. index
	projectedScoreText.inner_rml = "+" .. tostring(allyTeam.projectedPoints)
	
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


local function updateDynamicHeight()
	if not widgetState.document or not widgetState.uiState then
		return
	end
	
	local allyTeams = widgetState.allyTeamData
	local numTeams = #allyTeams
	
	if numTeams == 0 then
		return
	end
	
	-- Calculate height needed for header
	local headerHeight = 18 + (widgetState.uiMargins.headerPadding * 2) + widgetState.uiMargins.headerMargin
	
	-- Calculate height needed for score bars
	-- Each score bar: 18px height + padding + gap
	local scoreBarHeight = 18 + (widgetState.uiMargins.scoreBarPadding * 2)
	local totalScoreBarHeight = numTeams * scoreBarHeight
	
	-- Add gaps between score bars (numTeams - 1 gaps)
	local totalGapsHeight = (numTeams - 1) * widgetState.uiMargins.scoreBarPadding
	
	-- Calculate total height needed
	local totalHeight = headerHeight + totalScoreBarHeight + totalGapsHeight + (widgetState.uiMargins.containerPadding * 2)
	
	-- Update UI state
	widgetState.uiState.height = totalHeight
	
	-- Update document position and size
	local rootElement = widgetState.document:GetElementById("score-container")
	if rootElement then
		local scorePosX = widgetState.uiState.position.x
		local scorePosY = widgetState.uiState.position.y
		local effectiveMaxWidth = widgetState.uiState.position.width
		local maxWidth = widgetState.uiState.availableWidth
		
		rootElement:SetAttribute("style", string.format("left: %dpx; top: %dpx; width: %dpx; height: %dpx", 
			scorePosX, scorePosY, maxWidth, totalHeight))
	end
end


local function updateScoreBarVisuals()
	if not widgetState.document then
		return
	end
	
	local dm = widgetState.dmHandle
	local allyTeams = widgetState.allyTeamData
	
	-- Update header info elements - let RML binding handle this automatically
	-- The round and time display will be updated via data model binding
	

	
	-- Get or clear the score columns container
	local columnsContainer = widgetState.document:GetElementById("score-columns")
	if not columnsContainer then
		return
	end
	
	-- Clear existing score bars
	columnsContainer.inner_rml = ""
	widgetState.scoreElements = {}
	
	local numTeams = #allyTeams
	if numTeams == 0 then
		return
	end
	
	-- Calculate optimal column layout for 300x248 area
	-- Each score bar needs ~27px height (18px bar + 9px for padding and gaps)
	-- Available height ~235px (248 - header ~10px - victory points ~3px)
	local maxTeamsPerColumn = math.floor(235 / 27)
	local teamsPerColumn = math.min(maxTeamsPerColumn, numTeams)
	local numColumns = math.ceil(numTeams / teamsPerColumn)
	
	-- Limit columns based on available width after margins
	-- Each column needs minimum width: score bar padding + text space + margins
	local minColumnWidth = widgetState.uiMargins.scoreBarPadding * 2 + 40 -- 40px for text and score display
	local maxColumnsByWidth = math.floor((widgetState.uiState and widgetState.uiState.availableWidth or 300) / minColumnWidth)
	maxColumnsByWidth = math.max(1, math.min(maxColumnsByWidth, 4)) -- Clamp between 1 and 4
	
	if numColumns > maxColumnsByWidth then
		numColumns = maxColumnsByWidth
		teamsPerColumn = math.ceil(numTeams / numColumns)
	end
	
	-- Create columns
	local columns = {}
	for i = 1, numColumns do
		local columnDiv = widgetState.document:CreateElement("div")
		columnDiv.class_name = "score-column"
		columnsContainer:AppendChild(columnDiv)
		columns[i] = columnDiv
	end
	
	-- Distribute teams across columns more evenly
	for i, allyTeam in ipairs(allyTeams) do
		local columnIndex = ((i - 1) % numColumns) + 1
		local scoreBarElements = createScoreBarElement(columns[columnIndex], allyTeam, i)
		widgetState.scoreElements[i] = scoreBarElements
		
		-- Calculate projected width (lighter color for projected points)
		local projectedWidth = "0%"
		if dm.pointsCap > 0 then
			local totalProjected = allyTeam.score + allyTeam.projectedPoints
			projectedWidth = string.format("%.1f%%", math.min(100, (totalProjected / dm.pointsCap) * 100))
		end
		scoreBarElements.projectedElement:SetAttribute("style", "width: " .. projectedWidth)
		
		-- Set projected color (lighter version of team color)
		local projectedColor = string.format("rgba(%d, %d, %d, 100)", 
			allyTeam.color.r * 255, allyTeam.color.g * 255, allyTeam.color.b * 255)
		scoreBarElements.projectedElement:SetAttribute("style", "width: " .. projectedWidth .. "; background-color: " .. projectedColor)
		
		-- Calculate current score width
		local fillWidth = "0%"
		if dm.pointsCap > 0 then
			fillWidth = string.format("%.1f%%", math.min(100, (allyTeam.score / dm.pointsCap) * 100))
		end
		
		-- Set fill color (full opacity team color)
		local fillColor = string.format("rgba(%d, %d, %d, 230)", 
			allyTeam.color.r * 255, allyTeam.color.g * 255, allyTeam.color.b * 255)
		scoreBarElements.fillElement:SetAttribute("style", "width: " .. fillWidth .. "; background-color: " .. fillColor)
		
		-- Update score text elements
		if scoreBarElements.currentScoreElement then
			scoreBarElements.currentScoreElement.inner_rml = tostring(allyTeam.score)
		end
		if scoreBarElements.projectedScoreElement then
			scoreBarElements.projectedScoreElement.inner_rml = "+" .. tostring(allyTeam.projectedPoints)
		end
	end
	
	-- Calculate and update dynamic height after all score bars are created
	updateDynamicHeight()
end

local function updateDataModel()
	if not widgetState.dmHandle then
		return
	end
	
	local allyTeams = updateAllyTeamData()
	local roundInfo = updateRoundInfo()
	
	-- Update the data model with array-based approach
	local dm = widgetState.dmHandle
	
	-- Store all ally teams in the data model
	dm.allyTeams = allyTeams
	
	dm.currentRound = roundInfo.currentRound
	dm.roundEndTime = roundInfo.roundEndTime
	dm.pointsCap = roundInfo.pointsCap
	dm.highestScore = roundInfo.highestScore
	dm.secondHighestScore = roundInfo.secondHighestScore
	dm.timeRemaining = roundInfo.timeRemaining
	dm.roundDisplayText = roundInfo.roundDisplayText
	

	
	-- Trigger rerender for data model changes
	dm:__SetDirty("allyTeams")
	dm:__SetDirty("pointsCap")
	dm:__SetDirty("currentRound")
	dm:__SetDirty("timeRemaining")
	dm:__SetDirty("roundDisplayText")
	
	calculateUILayout()
	
	-- Update visual properties of score bars
	if widgetState.document then
		updateScoreBarVisuals()
		

	end
end



function widget:Initialize()
	Spring.Echo(WIDGET_NAME .. ": Initializing widget...")
	
	-- Debug: Check all constants
	Spring.Echo(WIDGET_NAME .. ": WIDGET_NAME = '" .. tostring(WIDGET_NAME) .. "'")
	Spring.Echo(WIDGET_NAME .. ": MODEL_NAME = '" .. tostring(MODEL_NAME) .. "'")
	Spring.Echo(WIDGET_NAME .. ": RML_PATH = '" .. tostring(RML_PATH) .. "'")
	
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		Spring.Echo(WIDGET_NAME .. ": ERROR - Failed to get RML context")
		return false
	end
	
	local dmHandle = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dmHandle then
		Spring.Echo(WIDGET_NAME .. ": ERROR - Failed to create data model '" .. MODEL_NAME .. "'")
		return false
	end
	
	widgetState.dmHandle = dmHandle
	Spring.Echo(WIDGET_NAME .. ": Data model created successfully")
	
	-- Load document from RML file
	local document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not document then
		Spring.Echo(WIDGET_NAME .. ": ERROR - Failed to load document from '" .. RML_PATH .. "'")
		widget:Shutdown()
		return false
	end
	
	widgetState.document = document
	
	-- Load the stylesheet and show the document
	document:ReloadStyleSheet()
	document:Show()
	
	updateDataModel()
	
	-- Debug: Check initial data model state
	if widgetState.dmHandle then
		Spring.Echo(WIDGET_NAME .. ": Initial pointsCap in data model = " .. tostring(widgetState.dmHandle.pointsCap))
	end
	
	Spring.Echo(WIDGET_NAME .. ": Widget initialized successfully")
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
	Spring.Echo(WIDGET_NAME .. ": Shutting down widget...")
	
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
	Spring.Echo(WIDGET_NAME .. ": Shutdown complete")
end

function widget:Update()
	local currentTime = Spring.GetGameSeconds()
	if currentTime - widgetState.lastUpdateTime >= widgetState.updateInterval then
		-- Check if we have any territorial domination data
		local pointsCap = spGetGameRulesParam("territorialDominationPointsCap")
		if pointsCap and pointsCap > 0 then
			if widgetState.document and not widgetState.hiddenByLobby then
				widgetState.document:Show()
			end
			-- Only update data model if document is ready
			if widgetState.document then
				updateDataModel()
			end
			widgetState.lastUpdateTime = currentTime
		else
			-- Hide document if no data
			if widgetState.document then
				widgetState.document:Hide()
			end
		end
	end
end

function widget:DrawScreen()
	if not widgetState.document then
		return
	end
	
	-- Only render if document is visible and we have territorial domination data
	local pointsCap = spGetGameRulesParam("territorialDominationPointsCap")
	if pointsCap and pointsCap > 0 then
		widgetState.rmlContext:Render()
	end
end
