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

local widgetState = {
	document = nil,
	dmHandle = nil,
	rmlContext = nil,
	lastUpdateTime = 0,
	updateInterval = 0.1,
	allyTeamData = {},
	lastMinimapGeometry = {0, 0, 0, 0},
	scoreElements = {},
}

local initialModel = {
	allyTeams = {},
	currentRound = 1,
	roundEndTime = 0,
	pointsCap = 100,
	highestScore = 0,
	secondHighestScore = 0,
	timeRemaining = "00:00",
	uiState = {
		barWidth = 300,
		spacing = 4,
		position = {
			x = 0,
			y = 0,
			width = 300,
		},
	},
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
			local score = 0
			local projectedPoints = 0
			
			for _, teamID in ipairs(teamList) do
				local teamScore = spGetTeamRulesParam(teamID, "territorialDominationScore") or 0
				local teamProjected = spGetTeamRulesParam(teamID, "territorialDominationProjectedPoints") or 0
				score = math.max(score, teamScore)
				projectedPoints = math.max(projectedPoints, teamProjected)
			end
			
			-- Get team color
			local teamColor = getAllyTeamColor(allyTeamID)
			
			-- Include all ally teams, even with 0 scores, so we can see the full competition
			table.insert(validAllyTeams, {
				name = "Ally " .. (allyTeamID + 1),
				allyTeamID = allyTeamID,
				score = score,
				projectedPoints = projectedPoints,
				color = teamColor, -- Store the raw RGB values
				bgColor = string.format("rgba(%d, %d, %d, 200)", teamColor.r * 51, teamColor.g * 51, teamColor.b * 51),
				projectedColor = string.format("rgba(%d, %d, %d, 150)", teamColor.r * 204, teamColor.g * 204, teamColor.b * 204),
				fillColor = string.format("rgba(%d, %d, %d, 230)", teamColor.r * 255, teamColor.g * 255, teamColor.b * 255),
				projectedWidth = "0%",
				fillWidth = "0%",
				teamCount = #teamList,
			})
		end
	end
	
	table.sort(validAllyTeams, function(a, b) return a.score > b.score end)
	
	widgetState.allyTeamData = validAllyTeams
	return validAllyTeams
end

local function updateRoundInfo()
	local roundEndTime = spGetGameRulesParam("territorialDominationRoundEndTimestamp") or 0
	local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or 100
	local highestScore = spGetGameRulesParam("territorialDominationHighestScore") or 0
	local secondHighestScore = spGetGameRulesParam("territorialDominationSecondHighestScore") or 0
	
	-- Calculate current round based on time elapsed
	local currentTime = Spring.GetGameSeconds()
	local roundDuration = 300 -- 5 minutes per round from the game config
	local currentRound = math.floor((currentTime - (roundEndTime - roundDuration)) / roundDuration) + 1
	currentRound = math.max(1, math.min(currentRound, 7)) -- Clamp between 1 and 7 (max rounds)
	
	-- Calculate time remaining
	local timeRemaining = math.max(0, roundEndTime - currentTime)
	local minutes = math.floor(timeRemaining / 60)
	local seconds = math.floor(timeRemaining % 60)
	local timeString = string.format("%02d:%02d", minutes, seconds)
	
	return {
		currentRound = currentRound,
		roundEndTime = roundEndTime,
		pointsCap = pointsCap,
		highestScore = highestScore,
		secondHighestScore = secondHighestScore,
		timeRemaining = timeString,
	}
end



local function calculateUILayout()
	local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY = spGetMiniMapGeometry()
	Spring.Echo(WIDGET_NAME .. ": minimapPosX = " .. tostring(minimapPosX))
	Spring.Echo(WIDGET_NAME .. ": minimapPosY = " .. tostring(minimapPosY))
	Spring.Echo(WIDGET_NAME .. ": minimapSizeX = " .. tostring(minimapSizeX))
	Spring.Echo(WIDGET_NAME .. ": minimapSizeY = " .. tostring(minimapSizeY))	
	
	if minimapPosX == widgetState.lastMinimapGeometry[1] and 
	   minimapPosY == widgetState.lastMinimapGeometry[2] and 
	   minimapSizeX == widgetState.lastMinimapGeometry[3] and 
	   minimapSizeY == widgetState.lastMinimapGeometry[4] then
		return
	end
	
	widgetState.lastMinimapGeometry = {minimapPosX, minimapPosY, minimapSizeX, minimapSizeY}
	
	local allyTeamCount = #widgetState.allyTeamData
	Spring.Echo(WIDGET_NAME .. ": allyTeamCount = " .. tostring(allyTeamCount))
	local barWidth = minimapSizeX
	local spacing = 4
	
	-- Position the score display below the minimap
	local scorePosX = minimapPosX
	-- Calculate total height needed for all score bars
	local singleBarHeight = 40 -- Height of one score bar
	local totalScoreHeight = (allyTeamCount * singleBarHeight) + ((allyTeamCount - 1) * spacing) + 20 -- padding
	local topPadding = 8 -- Top padding from CSS
	local borderRadius = 4 -- Border radius from CSS
	local scorePosY = minimapPosY - minimapSizeY - totalScoreHeight + topPadding + borderRadius -- Position below minimap accounting for total height
	
	if widgetState.dmHandle then
		widgetState.dmHandle.uiState = {
			barWidth = barWidth,
			spacing = spacing,
			position = {
				x = scorePosX,
				y = scorePosY,
				width = minimapSizeX,
			}
		}
	end
	
	-- Update document position if it exists
	if widgetState.document then
		local rootElement = widgetState.document:GetElementById("score-container")
		if rootElement then
			rootElement.style.left = scorePosX .. "px"
			rootElement.style.top = scorePosY .. "px"
			rootElement.style.width = minimapSizeX .. "px"
		end
	end
end
local function createScoreBarElement(container, allyTeam, index)
	local barDiv = widgetState.document:CreateElement("div")
	barDiv.class_name = "score-column"
	
	local scoreBarDiv = widgetState.document:CreateElement("div")
	scoreBarDiv.class_name = "score-bar"
	
	-- Create header
	local headerDiv = widgetState.document:CreateElement("div")
	headerDiv.class_name = "score-header"
	
	local nameSpan = widgetState.document:CreateElement("span")
	nameSpan.class_name = "ally-team-name"
	nameSpan.id = "ally-name-" .. index
	nameSpan.inner_rml = allyTeam.name
	
	local scoreSpan = widgetState.document:CreateElement("span")
	scoreSpan.class_name = "score-value"
	scoreSpan.id = "score-value-" .. index
	scoreSpan.inner_rml = tostring(allyTeam.score)
	
	headerDiv:AppendChild(nameSpan)
	headerDiv:AppendChild(scoreSpan)
	
	-- Create score bar container
	local containerDiv = widgetState.document:CreateElement("div")
	containerDiv.class_name = "score-bar-container"
	
	local backgroundDiv = widgetState.document:CreateElement("div")
	backgroundDiv.class_name = "score-bar-background"
	
	local projectedDiv = widgetState.document:CreateElement("div")
	projectedDiv.class_name = "score-bar-projected"
	projectedDiv.id = "projected-fill-" .. index
	
	local fillDiv = widgetState.document:CreateElement("div")
	fillDiv.class_name = "score-bar-fill"
	fillDiv.id = "score-fill-" .. index
	
	containerDiv:AppendChild(backgroundDiv)
	containerDiv:AppendChild(projectedDiv)
	containerDiv:AppendChild(fillDiv)
	
	scoreBarDiv:AppendChild(headerDiv)
	scoreBarDiv:AppendChild(containerDiv)
	
	barDiv:AppendChild(scoreBarDiv)
	container:AppendChild(barDiv)
	
	return {
		container = barDiv,
		nameElement = nameSpan,
		scoreElement = scoreSpan,
		projectedElement = projectedDiv,
		fillElement = fillDiv,
	}
end

local function updateScoreBarVisuals()
	if not widgetState.document then
		return
	end
	
	local dm = widgetState.dmHandle
	local allyTeams = widgetState.allyTeamData
	
	-- Update round info
	local roundInfoElement = widgetState.document:GetElementById("round-info")
	if roundInfoElement and roundInfoElement.child_nodes and roundInfoElement.child_nodes[1] then
		local timeRemaining = math.max(0, dm.roundEndTime - Spring.GetGameSeconds())
		local minutes = math.floor(timeRemaining / 60)
		local seconds = math.floor(timeRemaining % 60)
		roundInfoElement.child_nodes[1].inner_rml = string.format("Round %d | Cap: %d | Time: %02d:%02d", 
			dm.currentRound, dm.pointsCap, minutes, seconds)
	end
	
	-- Get or clear the score columns container
	local columnsContainer = widgetState.document:GetElementById("score-columns")
	if not columnsContainer then
		return
	end
	
	-- Clear existing score bars
	columnsContainer.inner_rml = ""
	widgetState.scoreElements = {}
	
	-- Create score bars for each ally team
	for i, allyTeam in ipairs(allyTeams) do
		local scoreBarElements = createScoreBarElement(columnsContainer, allyTeam, i)
		widgetState.scoreElements[i] = scoreBarElements
		
		-- Update projected width
		local projectedWidth = "0%"
		if dm.pointsCap > 0 then
			projectedWidth = string.format("%f%%", (allyTeam.projectedPoints / dm.pointsCap) * 100)
		end
		scoreBarElements.projectedElement.style.width = projectedWidth
		
		-- Set projected color
		local projectedColor = string.format("rgba(%d, %d, %d, 150)", 
			allyTeam.color.r * 255, allyTeam.color.g * 255, allyTeam.color.b * 255)
		scoreBarElements.projectedElement.style["background-color"] = projectedColor
		
		-- Update fill width
		local fillWidth = "0%"
		if dm.pointsCap > 0 then
			fillWidth = string.format("%f%%", (allyTeam.score / dm.pointsCap) * 100)
		end
		scoreBarElements.fillElement.style.width = fillWidth
		
		-- Set fill color
		local fillColor = string.format("rgba(%d, %d, %d, 230)", 
			allyTeam.color.r * 255, allyTeam.color.g * 255, allyTeam.color.b * 255)
		scoreBarElements.fillElement.style["background-color"] = fillColor
	end
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
	
	Spring.Echo(WIDGET_NAME .. ": Widget initialized successfully")
	return true
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
			-- Show document if it was hidden
			if widgetState.document then
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
