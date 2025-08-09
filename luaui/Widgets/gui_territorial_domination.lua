function widget:GetInfo()
	return {
		name    = "Territorial Domination Score",
		desc    = "Displays player vs enemy score for Territorial Domination mode",
		author  = "SethDGamre",
		date    = "2025",
		license = "GNU GPL, v2",
		layer   = 1,
		enabled = true,
	}
end

local modOptions = Spring.GetModOptions()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) then 
	return false 
end

-- Constants
local SCORE_RULES_KEY = "territorialDominationScore"
local UPDATE_FREQUENCY = 15
local BAR_WIDTH = 300
local BAR_HEIGHT = 20
local BORDER_WIDTH = 2
local TEXT_OUTLINE_ALPHA = 0.6
local TEXT_OUTLINE_OFFSET = 1.0

-- Colors
local COLOR_PLAYER = { 0, 0.8, 0, 0.9 }        -- Green for player
local COLOR_ENEMY = { 1, 0.2, 0.2, 0.9 }       -- Red for enemy
local COLOR_BACKGROUND = { 0, 0, 0, 0.6 }
local COLOR_BORDER = { 0.3, 0.3, 0.3, 0.8 }
local COLOR_TEXT = { 1, 1, 1, 1 }
local COLOR_OUTLINE = { 0, 0, 0, TEXT_OUTLINE_ALPHA }

-- Spring API shortcuts
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetTeamList = Spring.GetTeamList
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetGameSeconds = Spring.GetGameSeconds

-- OpenGL shortcuts
local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local glGetTextWidth = gl.GetTextWidth

-- Variables
local myAllyTeamID = -1
local isSpectating = false
local lastUpdateFrame = 0
local playerScore = 0
local highestScore = 0
local highestEnemyScore = 0
local displayList = nil

local function getAllyTeamScore(allyTeamID)
	local teamList = spGetTeamList(allyTeamID)
	if not teamList or #teamList == 0 then return 0 end
	
	-- Use first team as representative
	local representativeTeamID = teamList[1]
	return spGetTeamRulesParam(representativeTeamID, SCORE_RULES_KEY) or 0
end

local function updateScores()
	playerScore = 0
	highestScore = 0
	highestEnemyScore = 0
	
	if isSpectating then
		return
	end
	
	-- Get player score
	playerScore = getAllyTeamScore(myAllyTeamID)
	
	-- Get highest and second highest scores from GameRulesParam
	highestScore = spGetGameRulesParam("territorialDominationHighestScore") or 0
	local secondHighestScore = spGetGameRulesParam("territorialDominationSecondHighestScore") or 0
	
	-- Determine enemy score for display
	if playerScore == highestScore then
		-- If we have the highest score, the enemy score is the second highest
		highestEnemyScore = secondHighestScore
	else
		-- If we don't have the highest score, the enemy score is the highest
		highestEnemyScore = highestScore
	end
end

local function formatTimeRemaining(seconds)
	if seconds <= 0 then
		return ""
	end
	
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = math.floor(seconds % 60)
	
	if minutes > 0 then
		return string.format("%d:%02d", minutes, remainingSeconds)
	else
		return string.format("%ds", remainingSeconds)
	end
end

local function drawTextWithOutline(text, x, y, fontSize, alignment, color)
	-- Draw outline
	glColor(COLOR_OUTLINE[1], COLOR_OUTLINE[2], COLOR_OUTLINE[3], COLOR_OUTLINE[4])
	glText(text, x - TEXT_OUTLINE_OFFSET, y, fontSize, alignment)
	glText(text, x + TEXT_OUTLINE_OFFSET, y, fontSize, alignment)
	glText(text, x, y - TEXT_OUTLINE_OFFSET, fontSize, alignment)
	glText(text, x, y + TEXT_OUTLINE_OFFSET, fontSize, alignment)
	
	-- Draw main text
	glColor(color[1], color[2], color[3], color[4])
	glText(text, x, y, fontSize, alignment)
end

local function drawGradientRect(left, bottom, right, top, bottomColor, topColor)
	local vertices = {
		{ v = { left, bottom }, c = bottomColor },
		{ v = { right, bottom }, c = bottomColor },
		{ v = { right, top }, c = topColor },
		{ v = { left, top }, c = topColor }
	}
	gl.Shape(GL.QUADS, vertices)
end

local function drawSplitBar()
	local minimapX, minimapY, minimapSizeX = spGetMiniMapGeometry()
	
	-- Position bar below minimap
	local barLeft = minimapX
	local barRight = minimapX + BAR_WIDTH
	local barTop = minimapY - 10
	local barBottom = barTop - BAR_HEIGHT
	

	
	-- Calculate total score for proportions
	local totalScore = playerScore + highestEnemyScore
	if totalScore <= 0 then
		totalScore = 1 -- Avoid division by zero
	end
	
	-- Calculate split position
	local playerProportion = playerScore / totalScore
	local splitX = barLeft + (BAR_WIDTH * playerProportion)
	
	-- Draw border
	glColor(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4])
	glRect(barLeft - BORDER_WIDTH, barBottom - BORDER_WIDTH, barRight + BORDER_WIDTH, barTop + BORDER_WIDTH)
	
	-- Draw background
	glColor(COLOR_BACKGROUND[1], COLOR_BACKGROUND[2], COLOR_BACKGROUND[3], COLOR_BACKGROUND[4])
	glRect(barLeft, barBottom, barRight, barTop)
	
	-- Draw player section (left, green)
	if playerScore > 0 then
		local playerTopColor = { COLOR_PLAYER[1], COLOR_PLAYER[2], COLOR_PLAYER[3], COLOR_PLAYER[4] }
		local playerBottomColor = { COLOR_PLAYER[1] * 0.7, COLOR_PLAYER[2] * 0.7, COLOR_PLAYER[3] * 0.7, COLOR_PLAYER[4] }
		drawGradientRect(barLeft, barBottom, splitX, barTop, playerBottomColor, playerTopColor)
	end
	
	-- Draw enemy section (right, red)
	if highestEnemyScore > 0 then
		local enemyTopColor = { COLOR_ENEMY[1], COLOR_ENEMY[2], COLOR_ENEMY[3], COLOR_ENEMY[4] }
		local enemyBottomColor = { COLOR_ENEMY[1] * 0.7, COLOR_ENEMY[2] * 0.7, COLOR_ENEMY[3] * 0.7, COLOR_ENEMY[4] }
		drawGradientRect(splitX, barBottom, barRight, barTop, enemyBottomColor, enemyTopColor)
	end
	
	-- Draw center divider line
	local lineWidth = 1
	glColor(0.8, 0.8, 0.8, 0.8)
	glRect(splitX - lineWidth, barBottom, splitX + lineWidth, barTop)
	
	-- Draw score text
	local fontSize = 14
	local textY = barBottom + 5   -- Position text well below the bar to avoid overlap
	
	-- Player score (left)
	local playerText = tostring(playerScore)
	drawTextWithOutline(playerText, barLeft + 5, textY, fontSize, "l", COLOR_TEXT)
	
	-- Enemy score (right)
	local enemyText = tostring(highestEnemyScore)
	drawTextWithOutline(enemyText, barRight - 5, textY, fontSize, "r", COLOR_TEXT)
	
	-- Time remaining text in center of bar
	local roundEndTimestamp = spGetGameRulesParam("territorialDominationRoundEndTimestamp") or 0
	local currentTime = spGetGameSeconds()
	local timeRemaining = math.max(0, roundEndTimestamp - currentTime)
	local timeText = formatTimeRemaining(timeRemaining)
	local timeY = barBottom + (BAR_HEIGHT / 2) - (fontSize / 2)
	local centerX = barLeft + (BAR_WIDTH / 2)
	drawTextWithOutline(timeText, centerX, timeY, fontSize, "c", COLOR_TEXT)
end

function widget:DrawScreen()
	if isSpectating then
		return
	end
	
	drawSplitBar()
end

function widget:GameFrame(frame)
	-- Update scores periodically
	if frame - lastUpdateFrame >= UPDATE_FREQUENCY then
		lastUpdateFrame = frame
		updateScores()
	end
end

function widget:Initialize()
	myAllyTeamID = spGetMyAllyTeamID()
	isSpectating = spGetSpectatingState()
	
	if isSpectating then
		return
	end
	
	updateScores()
end

function widget:PlayerChanged()
	local newSpectating = spGetSpectatingState()
	local newAllyTeamID = spGetMyAllyTeamID()
	
	if newSpectating ~= isSpectating or newAllyTeamID ~= myAllyTeamID then
		isSpectating = newSpectating
		myAllyTeamID = newAllyTeamID
		
		if not isSpectating then
			updateScores()
		end
	end
end
