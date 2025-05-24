function widget:GetInfo()
	return {
		name      = "Territorial Domination Score",
		desc      = "Displays the score for the Territorial Domination game mode.",
		author    = "SethDGamre",
		date      = "2025",
		license   = "GNU GPL, v2",
		layer     = -9,
		enabled   = true,
	}
end

local modOptions = Spring.GetModOptions()
if modOptions.deathmode ~= "territorial_domination" then return false end

-- Spring API functions
local floor = math.floor
local ceil = math.ceil
local format = string.format
local len = string.len
local abs = math.abs
local max = math.max
local min = math.min
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetGameSeconds = Spring.GetGameSeconds
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamInfo = Spring.GetTeamInfo
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetUnitTeam = Spring.GetUnitTeam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetTeamList = Spring.GetTeamList
local spGetTeamColor = Spring.GetTeamColor
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetUnitPosition = Spring.GetUnitPosition
local spPlaySoundFile = Spring.PlaySoundFile
local spI18N = Spring.I18N
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitDefID = Spring.GetUnitDefID
local spGetMyTeamID = Spring.GetMyTeamID
local spGetAllUnits = Spring.GetAllUnits

-- OpenGL functions
local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glGetTextWidth = gl.GetTextWidth
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glTranslate = gl.Translate
local glScale = gl.Scale

-- Game constants
local WARNING_THRESHOLD = 3
local ALERT_THRESHOLD = 10
local WARNING_SECONDS = 15
local PADDING_MULTIPLIER = 0.36
local UPDATE_FREQUENCY = 0.1
local BLINK_INTERVAL = 1
local DEFEAT_CHECK_INTERVAL = Game.gameSpeed
local AFTER_GADGET_TIMER_UPDATE_MODULO = 3

-- Rules parameter keys
local SCORE_RULES_KEY = "territorialDominationScore"
local THRESHOLD_RULES_KEY = "territorialDominationDefeatThreshold"
local FREEZE_DELAY_KEY = "territorialDominationFreezeDelay"
local MAX_THRESHOLD_RULES_KEY = "territorialDominationMaxThreshold"
local RANK_RULES_KEY = "territorialDominationRank"

-- Sound timing constants
local WINDUP_SOUND_DURATION = 2
local ACTIVATE_SOUND_DURATION = 0
local CHARGE_SOUND_LOOP_DURATION = 4.7

-- UI layout constants
local TIMER_WARNING_DISPLAY_TIME = 5
local TIMER_COOLDOWN = 120
local MINIMAP_GAP = 3
local BORDER_WIDTH = 2
local ICON_SIZE = 25
local TEXT_OUTLINE_OFFSET = 0.7
local TEXT_OUTLINE_ALPHA = 0.35
local COUNTDOWN_FONT_SIZE_MULTIPLIER = 1.6
local SPECTATOR_MAX_DISPLAY_HEIGHT = 256
local SPECTATOR_MIN_BAR_HEIGHT = 16
local SPECTATOR_BAR_SPACING = 3
local SPECTATOR_COLUMN_PADDING = 4

-- Color definitions
local COLOR_WHITE = {1, 1, 1, 1}
local COLOR_RED = {1, 0, 0, 1}
local COUNTDOWN_COLOR = {1, 0.2, 0.2, 1}
local COLOR_YELLOW = {1, 0.8, 0, 1}
local COLOR_BACKGROUND = {0, 0, 0, 0.5}
local COLOR_BORDER = {0.2, 0.2, 0.2, 0.2}
local COLOR_GREEN = {0, 0.8, 0, 0.8}
local COLOR_TEXT_OUTLINE = {0, 0, 0, TEXT_OUTLINE_ALPHA}
local COLOR_GREY_LINE = {0.7, 0.7, 0.7, 0.7}
local COLOR_WHITE_LINE = {1, 1, 1, 0.8}

-- Widget state variables
local myCommanders = {}
local soundQueue = {}
local isSkullFaded = true
local lastTimerWarningTime = 0
local timerWarningEndTime = 0
local amSpectating = false
local myAllyID = -1
local selectedAllyTeamID = -1
local gaiaAllyTeamID = -1
local lastUpdateTime = 0
local lastScore = -1
local displayList = nil
local lastDifference = -1
local healthbarWidth = 300
local healthbarHeight = 16
local lineWidth = 2
local maxThreshold = 256
local currentTime = os.clock()
local defeatTime = 0
local gameSeconds = 0
local lastLoop = 0
local loopSoundEndTime = 0
local soundIndex = 1

-- Display list caching variables
local timerWarningDisplayList = nil
local countdownDisplayList = nil
local lastTimerWarningMessages = nil

-- Tracking variables for display list updates
local lastThreshold = -1
local lastMaxThreshold = -1
local lastIsThresholdFrozen = false
local lastFreezeExpirationTime = -1
local lastHealthbarWidth = -1
local lastHealthbarHeight = -1
local lastMinimapDimensions = {-1, -1, -1}
local lastAmSpectating = false
local lastSelectedAllyTeamID = -1
local lastAllyTeamScores = {}
local lastTeamRanks = {}

-- Ally team tracking for spectator mode
local allyTeamDefeatTimes = {}
local allyTeamCountdownDisplayLists = {}
local lastCountdownValues = {}

-- Font cache for performance
local fontCache = {
	initialized = false,
	fontSizeMultiplier = 1,
	fontSize = 11,
	paddingX = 0,
	paddingY = 0
}

-- Cached color values
local backgroundColor = {COLOR_BACKGROUND[1], COLOR_BACKGROUND[2], COLOR_BACKGROUND[3], COLOR_BACKGROUND[4]}
local borderColor = {COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4]}

-- Helper function to draw text with outline (reduces code duplication)
local function drawTextWithOutline(text, x, y, fontSize, alignment, textColor)
	alignment = alignment or "l"
	textColor = textColor or COLOR_WHITE
	
	-- Draw outline
	glColor(COLOR_TEXT_OUTLINE[1], COLOR_TEXT_OUTLINE[2], COLOR_TEXT_OUTLINE[3], COLOR_TEXT_OUTLINE[4])
	local outlineOffsets = {
		{-TEXT_OUTLINE_OFFSET, -TEXT_OUTLINE_OFFSET},
		{TEXT_OUTLINE_OFFSET, -TEXT_OUTLINE_OFFSET},
		{-TEXT_OUTLINE_OFFSET, TEXT_OUTLINE_OFFSET},
		{TEXT_OUTLINE_OFFSET, TEXT_OUTLINE_OFFSET},
		{-TEXT_OUTLINE_OFFSET, 0},
		{TEXT_OUTLINE_OFFSET, 0},
		{0, -TEXT_OUTLINE_OFFSET},
		{0, TEXT_OUTLINE_OFFSET}
	}
	
	for _, offset in ipairs(outlineOffsets) do
		glText(text, x + offset[1], y + offset[2], fontSize, alignment)
	end
	
	-- Draw main text
	glColor(textColor[1], textColor[2], textColor[3], textColor[4])
	glText(text, x, y, fontSize, alignment)
end

-- Helper function to calculate spectator layout parameters
local function calculateSpectatorLayout(totalTeams, minimapSizeX)
	-- Use fixed bar height of 16 pixels
	local fixedBarHeight = 16
	local totalBarHeight = fixedBarHeight + SPECTATOR_BAR_SPACING
	local maxBarsPerColumn = floor(SPECTATOR_MAX_DISPLAY_HEIGHT / totalBarHeight)
	
	-- Calculate number of columns needed
	local numColumns = ceil(totalTeams / maxBarsPerColumn)
	local columnWidth = minimapSizeX / numColumns
	local barWidth = columnWidth - (SPECTATOR_COLUMN_PADDING * 2)
	
	return {
		numColumns = numColumns,
		maxBarsPerColumn = maxBarsPerColumn,
		columnWidth = columnWidth,
		barHeight = fixedBarHeight,
		barWidth = barWidth
	}
end

-- Helper function to check if an ally team is still alive
local function isAllyTeamAlive(allyTeamID)
	if allyTeamID == gaiaAllyTeamID then
		return false
	end
	
	local teamList = spGetTeamList(allyTeamID)
	for _, teamID in ipairs(teamList) do
		local _, _, isDead = spGetTeamInfo(teamID)
		if not isDead then
			return true
		end
	end
	
	return false
end

-- Helper function to get alive ally teams
local function getAliveAllyTeams()
	local aliveAllyTeams = {}
	local allyTeamList = spGetAllyTeamList()
	
	for _, allyTeamID in ipairs(allyTeamList) do
		if isAllyTeamAlive(allyTeamID) then
			table.insert(aliveAllyTeams, allyTeamID)
		end
	end
	
	return aliveAllyTeams
end

-- Helper function to create tinted colors
local function createTintedColor(baseColor, tintColor, strength)
	return {
		baseColor[1] + (tintColor[1] - baseColor[1]) * strength,
		baseColor[2] + (tintColor[2] - baseColor[2]) * strength,
		baseColor[3] + (tintColor[3] - baseColor[3]) * strength,
		baseColor[4]
	}
end

-- Helper function to draw background and border with tinting
local function drawBackgroundAndBorder(left, bottom, right, top, teamColor)
	local bgTintStrength = 0.15
	local borderTintStrength = 0.1
	
	local tintedBackgroundColor = createTintedColor(backgroundColor, teamColor, bgTintStrength)
	local tintedBorderColor = createTintedColor(borderColor, teamColor, borderTintStrength)
	
	-- Draw border
	glColor(tintedBorderColor[1], tintedBorderColor[2], tintedBorderColor[3], tintedBorderColor[4])
	glRect(left - BORDER_WIDTH, bottom - BORDER_WIDTH, right + BORDER_WIDTH, top + BORDER_WIDTH)
	
	-- Draw background
	glColor(tintedBackgroundColor[1], tintedBackgroundColor[2], tintedBackgroundColor[3], tintedBackgroundColor[4])
	glRect(left, bottom, right, top)
end

-- Helper function to calculate bar color based on difference
local function getBarColor(difference)
	if difference <= WARNING_THRESHOLD then
		return COLOR_RED
	elseif difference <= ALERT_THRESHOLD then
		return COLOR_YELLOW
	else
		return COLOR_GREEN
	end
end

-- Helper functions to reduce upvalues in main functions
local function drawHealthBar(left, right, bottom, top, score, threshold, barColor, isThresholdFrozen)
	-- POSITION CALCULATIONS
	local fullHealthbarLeft = left
	local fullHealthbarRight = right
	local barWidth = right - left
	
	local originalRight = right
	local exceedsMaxThreshold = score > maxThreshold
	
	-- Calculate the actual score position without exceeding the bar width
	local healthbarScoreRight = left + math.min(score / maxThreshold, 1) * barWidth
	
	-- If score exceeds max, we won't extend the bar beyond its normal width
	if exceedsMaxThreshold then
		right = originalRight
	end
	
	local thresholdX = left + (threshold / maxThreshold) * barWidth
	
	local skullOffset = (1 / maxThreshold) * barWidth
	local skullX = thresholdX - skullOffset
	
	local borderSize = 3
	local fillPaddingLeft = fullHealthbarLeft + borderSize
	local fillPaddingRight = healthbarScoreRight - borderSize
	local fillPaddingTop = top
	local fillPaddingBottom = bottom + borderSize
	
	-- Calculate line position
	local linePos = healthbarScoreRight
	if exceedsMaxThreshold then
		-- Calculate how much the bar exceeds the max threshold
		local overfillRatio = (score - maxThreshold) / maxThreshold
		-- Cap at 1.0 (100% backfilled)
		overfillRatio = math.min(overfillRatio, 1)
		
		-- Calculate where the line should be when backfilling
		local maxWidth = originalRight - borderSize - fillPaddingLeft
		local backfillWidth = maxWidth * overfillRatio
		linePos = originalRight - borderSize - backfillWidth
		
		-- Make sure the line position doesn't go outside the bar
		linePos = math.max(fillPaddingLeft, linePos)
	end
	
	-- COLOR SETUP - don't change bar color when frozen
	local baseColor = barColor
	local topColor = {baseColor[1], baseColor[2], baseColor[3], baseColor[4]}
	local bottomColor = {baseColor[1]*0.7, baseColor[2]*0.7, baseColor[3]*0.7, baseColor[4]}
	
	-- GRADIENT RENDERING
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	
	if fillPaddingLeft < fillPaddingRight then
		if exceedsMaxThreshold then
			-- Calculate how much the bar exceeds the max threshold
			local overfillRatio = (score - maxThreshold) / maxThreshold
			-- Cap at 1.0 (100% backfilled)
			overfillRatio = math.min(overfillRatio, 1)
			
			local maxBarWidth = originalRight - borderSize - fillPaddingLeft
			local overfillWidth = maxBarWidth * overfillRatio
			
			-- The point where the bright color starts (from right side)
			local brightColorStart = originalRight - borderSize - overfillWidth
			
			-- NORMAL COLORED SECTION (left part)
			if brightColorStart > fillPaddingLeft then
				local vertices = {
					-- Bottom left
					{v = {fillPaddingLeft, fillPaddingBottom}, c = bottomColor},
					-- Bottom right
					{v = {brightColorStart, fillPaddingBottom}, c = bottomColor},
					-- Top right
					{v = {brightColorStart, fillPaddingTop}, c = topColor},
					-- Top left
					{v = {fillPaddingLeft, fillPaddingTop}, c = topColor}
				}
				gl.Shape(GL.QUADS, vertices)
			end
			
			-- BRIGHT COLORED SECTION (right part - backfill)
			local excessTopColor = {
				topColor[1] + (1 - topColor[1]) * 0.5,
				topColor[2] + (1 - topColor[2]) * 0.5,
				topColor[3] + (1 - topColor[3]) * 0.5,
				topColor[4]
			}
			local excessBottomColor = {
				bottomColor[1] + (1 - bottomColor[1]) * 0.5,
				bottomColor[2] + (1 - bottomColor[2]) * 0.5,
				bottomColor[3] + (1 - bottomColor[3]) * 0.5,
				bottomColor[4]
			}
			
			local vertices = {
				-- Bottom left
				{v = {brightColorStart, fillPaddingBottom}, c = excessBottomColor},
				-- Bottom right
				{v = {originalRight - borderSize, fillPaddingBottom}, c = excessBottomColor},
				-- Top right
				{v = {originalRight - borderSize, fillPaddingTop}, c = excessTopColor},
				-- Top left
				{v = {brightColorStart, fillPaddingTop}, c = excessTopColor}
			}
			gl.Shape(GL.QUADS, vertices)
		else
			-- STANDARD SECTION
			local vertices = {
				-- Bottom left
				{v = {fillPaddingLeft, fillPaddingBottom}, c = bottomColor},
				-- Bottom right
				{v = {fillPaddingRight, fillPaddingBottom}, c = bottomColor},
				-- Top right
				{v = {fillPaddingRight, fillPaddingTop}, c = topColor},
				-- Top left
				{v = {fillPaddingLeft, fillPaddingTop}, c = topColor}
			}
			gl.Shape(GL.QUADS, vertices)
		end
		
		-- HIGHLIGHTS
		local glossHeight = (fillPaddingTop - fillPaddingBottom) * 0.4
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		
		-- Adjust highlight end position for overfilled bars
		local highlightRight = fillPaddingRight
		if exceedsMaxThreshold then
			highlightRight = originalRight - borderSize
		end
		
		-- Top highlight
		local topGlossBottom = fillPaddingTop - glossHeight
		local vertices = {
			-- Bottom left
			{v = {fillPaddingLeft, topGlossBottom}, c = {1, 1, 1, 0}},
			-- Bottom right
			{v = {highlightRight, topGlossBottom}, c = {1, 1, 1, 0}},
			-- Top right
			{v = {highlightRight, fillPaddingTop}, c = {1, 1, 1, 0.04}},
			-- Top left
			{v = {fillPaddingLeft, fillPaddingTop}, c = {1, 1, 1, 0.04}}
		}
		gl.Shape(GL.QUADS, vertices)
		
		-- Bottom highlight
		local bottomGlossHeight = (fillPaddingTop - fillPaddingBottom) * 0.2
		vertices = {
			-- Bottom left
			{v = {fillPaddingLeft, fillPaddingBottom}, c = {1, 1, 1, 0.02}},
			-- Bottom right
			{v = {highlightRight, fillPaddingBottom}, c = {1, 1, 1, 0.02}},
			-- Top right
			{v = {highlightRight, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}},
			-- Top left
			{v = {fillPaddingLeft, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}}
		}
		gl.Shape(GL.QUADS, vertices)
		
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	
	-- SKULL ICON RENDERING
	if threshold >= 1 then
		glPushMatrix()
		local skullY = bottom + (top - bottom)/2
		glTranslate(skullX, skullY, 0)
		
		-- Shadow
		local shadowOffset = 1.5
		local shadowAlpha = 0.6
		local shadowScale = 1.1
		
		glColor(0, 0, 0, shadowAlpha)
		glTexture(':n:LuaUI/Images/skull.dds')
		glTexRect(
			-ICON_SIZE/2 * shadowScale + shadowOffset, 
			-ICON_SIZE/2 * shadowScale - shadowOffset, 
			ICON_SIZE/2 * shadowScale + shadowOffset, 
			ICON_SIZE/2 * shadowScale - shadowOffset
		)
		
		-- SKULL ALPHA MANAGEMENT
		local skullAlpha = 1.0
		if isThresholdFrozen then
			local currentGameTime = spGetGameSeconds()
			local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
			local timeUntilUnfreeze = freezeExpirationTime - currentGameTime
			
			if timeUntilUnfreeze <= WARNING_SECONDS then
				-- Warning period blinking
				currentTime = os.clock()
				local blinkPhase = (currentTime % BLINK_INTERVAL) / BLINK_INTERVAL
				if blinkPhase < 0.33 then
					skullAlpha = 1.0
					isSkullFaded = false
				else
					skullAlpha = 0.5
					isSkullFaded = true
				end
			else
				-- Normal frozen state
				skullAlpha = 0.5
				isSkullFaded = true
			end
		else
			isSkullFaded = false
		end
		
		-- Draw skull
		glColor(1, 1, 1, skullAlpha)
		glTexture(':n:LuaUI/Images/skull.dds')
		glTexRect(-ICON_SIZE/2, -ICON_SIZE/2, ICON_SIZE/2, ICON_SIZE/2)
		
		glTexture(false)
		glPopMatrix()
	end
	
	-- SCORE LINE RENDERING
	local lineExtension = 3
	
	-- Determine line color based on whether the bar is overfilled
	local lineColor = exceedsMaxThreshold and COLOR_WHITE_LINE or COLOR_GREY_LINE
	
	-- Draw shadow/border for the line
	glColor(0, 0, 0, 0.8)
	glRect(linePos - lineWidth - 1, bottom - lineExtension, 
		   linePos + lineWidth + 1, top + lineExtension)
	
	-- Draw the actual line with the determined color
	glColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glRect(linePos - lineWidth/2, bottom - lineExtension, 
		   linePos + lineWidth/2, top + lineExtension)
		   
	return linePos, originalRight, thresholdX, skullX
end

-- TEXT RENDERING FUNCTION
local function drawDifferenceText(x, y, difference, fontSize, textColor)
	local formattedDifference = difference
	if difference > 0 then
		formattedDifference = "+" .. difference
	end
	
	drawTextWithOutline(formattedDifference, x, y, fontSize, "l", textColor)
end

-- Function to draw countdown text with outline
local function drawCountdownText(x, y, secondsRemaining, fontSize, textColor)
	local text
	if type(secondsRemaining) == "string" then
		text = secondsRemaining
	else
		text = format("%d", secondsRemaining)
	end
	
	drawTextWithOutline(text, x, y, fontSize, "c", textColor)
end

-- Function to draw rank text with outline using i18n
local function drawRankTextBox(x, y, width, height, rank, fontSize, textColor)
	-- Get i18n formatted rank text
	local rankText = spI18N('ui.territorialDomination.rank', {rank = rank})
	
	-- Calculate dynamic width based on text
	local textWidth = glGetTextWidth(rankText) * fontSize * 1.2
	local extraPadding = 5
	local finalWidth = max(textWidth, width) + extraPadding
	local finalHeight = height + extraPadding
	
	-- Move the box down by 2 pixels
	local yOffset = -3
	local adjustedY = y + yOffset
	
	-- Draw background and border
	glColor(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4])
	glRect(x - BORDER_WIDTH, adjustedY - BORDER_WIDTH, x + finalWidth + BORDER_WIDTH, adjustedY + finalHeight + BORDER_WIDTH)
	
	glColor(COLOR_BACKGROUND[1], COLOR_BACKGROUND[2], COLOR_BACKGROUND[3], COLOR_BACKGROUND[4])
	glRect(x, adjustedY, x + finalWidth, adjustedY + finalHeight)
	
	-- Position text at bottom of box with padding
	local centerX = x + finalWidth / 2
	local bottomPadding = 4
	local textY = adjustedY + bottomPadding
	
	drawTextWithOutline(rankText, centerX, textY, fontSize, "c", textColor)
end

local function createTimerWarningMessage(secondsRemaining, territoriesNeeded)
	local dominatedMessage = spI18N('ui.territorialDomination.losingWarning1', {seconds = ceil(secondsRemaining)})
	local conquerMessage = spI18N('ui.territorialDomination.losingWarning2', {needed = territoriesNeeded})
	return dominatedMessage, conquerMessage
end

local function createTimerWarningDisplayList(dominatedMessage, conquerMessage)
	-- Check if the messages are the same as last time
	if lastTimerWarningMessages and 
	   lastTimerWarningMessages[1] == dominatedMessage and 
	   lastTimerWarningMessages[2] == conquerMessage and
	   timerWarningDisplayList then
		return timerWarningDisplayList
	end
	
	if timerWarningDisplayList then
		glDeleteList(timerWarningDisplayList)
	end

	-- Store current messages for future comparison
	lastTimerWarningMessages = {dominatedMessage, conquerMessage}

	-- Create new display list
	timerWarningDisplayList = glCreateList(function()
		local vsx, vsy = Spring.GetViewGeometry()
		local widgetScale = 0.80 + (vsx * vsy / 6000000)
		local fontSize = 22 * widgetScale
		
		-- Position exactly like gui_game_type_info
		local y = 0.19  -- 19% up from the bottom
		local x = vsx * 0.5
		
		-- Apply font size scaling like gui_game_type_info
		glPushMatrix()
		glTranslate(x, vsy * y, 0)
		glScale(1.5, 1.5, 1)
		
		-- Calculate positions for the two lines with proper spacing
		local line1Y = 442  -- Center of first line
		local lineSpacing = line1Y * 0.06
		local line2Y = line1Y - lineSpacing
		
		-- Alpha is always 1.0 when creating the list - we'll use gl.Color when drawing to fade
		local alpha = 1.0
		
		-- Draw first line (dominated message)
		-- Text outline (shadow effect)
		glColor(0, 0, 0, alpha * 0.5)
		glText(dominatedMessage, 0 - 1, line1Y - 1, fontSize / 1.5, "c")
		
		-- Main text - WHITE
		glColor(1, 1, 1, alpha)
		glText(dominatedMessage, 0, line1Y, fontSize / 1.5, "c")
		
		-- Draw second line (conquer message)
		-- Text outline (shadow effect)
		glColor(0, 0, 0, alpha * 0.5)
		glText(conquerMessage, 0 - 1, line2Y - 1, fontSize / 1.5, "c")
		
		-- Main text - WHITE
		glColor(1, 1, 1, alpha)
		glText(conquerMessage, 0, line2Y, fontSize / 1.5, "c")
		
		glPopMatrix()
	end)
	
	return timerWarningDisplayList
end

-- Helper function to calculate countdown position for spectator mode
local function calculateSpectatorCountdownPosition(allyTeamID, minimapPosX, minimapPosY, minimapSizeX)
	local aliveAllyTeams = getAliveAllyTeams()
	local totalTeams = #aliveAllyTeams
	if totalTeams == 0 then return nil, nil end
	
	local layout = calculateSpectatorLayout(totalTeams, minimapSizeX)
	
	-- Get scores and sort them the same way as in drawSpectatorModeScoreBars
	local allyTeamScores = {}
	for _, currentAllyTeamID in ipairs(aliveAllyTeams) do
		local score = 0
		local defeatTimeRemaining = 0
		
		for _, tid in ipairs(spGetTeamList(currentAllyTeamID)) do
			local _, _, isDead = spGetTeamInfo(tid)
			if not isDead then
				local teamScore = spGetTeamRulesParam(tid, SCORE_RULES_KEY)
				if teamScore then
					score = teamScore
					break
				end
			end
		end
		
		if allyTeamDefeatTimes[currentAllyTeamID] and allyTeamDefeatTimes[currentAllyTeamID] > 0 then
			defeatTimeRemaining = max(0, allyTeamDefeatTimes[currentAllyTeamID] - gameSeconds)
		else
			defeatTimeRemaining = math.huge
		end
		
		table.insert(allyTeamScores, {
			allyTeamID = currentAllyTeamID,
			score = score,
			defeatTimeRemaining = defeatTimeRemaining
		})
	end
	
	-- Sort by score first (highest = 1st place), then by defeat time remaining (lowest timer = last place)
	table.sort(allyTeamScores, function(a, b)
		if a.score == b.score then
			-- When scores are tied, more time remaining = better rank (lower timer = worse rank)
			return a.defeatTimeRemaining > b.defeatTimeRemaining
		end
		-- Higher score = better rank (1st place)
		return a.score > b.score
	end)
	
	-- Find the position index of our allyTeamID
	local barIndex = nil
	for i, allyTeamData in ipairs(allyTeamScores) do
		if allyTeamData.allyTeamID == allyTeamID then
			barIndex = i
			break
		end
	end
	
	if barIndex then
		-- Calculate column and position within column
		local columnIndex = floor((barIndex - 1) / layout.maxBarsPerColumn)
		local positionInColumn = ((barIndex - 1) % layout.maxBarsPerColumn)
		
		-- Calculate bar position
		local columnStartX = minimapPosX + (columnIndex * layout.columnWidth)
		local healthbarLeft = columnStartX + SPECTATOR_COLUMN_PADDING
		local healthbarRight = healthbarLeft + layout.barWidth
		local startY = minimapPosY - MINIMAP_GAP
		local healthbarTop = startY - (positionInColumn * (layout.barHeight + SPECTATOR_BAR_SPACING))
		local healthbarBottom = healthbarTop - layout.barHeight
		
		local countdownY = healthbarBottom + (healthbarTop - healthbarBottom) / 2 - 7
		
		-- Calculate X position at the threshold/skull location
		local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
		local barWidthForCalc = healthbarRight - healthbarLeft
		local thresholdX = healthbarLeft + (threshold / maxThreshold) * barWidthForCalc
		local skullOffset = (1 / maxThreshold) * barWidthForCalc
		local countdownX = thresholdX - skullOffset
		
		return countdownX, countdownY
	end
	
	-- Fallback if ally team not found
	return minimapPosX + minimapSizeX / 2, minimapPosY - MINIMAP_GAP - 20
end

local function createCountdownDisplayList(timeRemaining, allyTeamID)
	allyTeamID = allyTeamID or myAllyID
	
	-- Only recreate if the time has changed for this ally team
	if allyTeamCountdownDisplayLists[allyTeamID] and lastCountdownValues[allyTeamID] == timeRemaining then
		return allyTeamCountdownDisplayLists[allyTeamID]
	end
	
	if allyTeamCountdownDisplayLists[allyTeamID] then
		glDeleteList(allyTeamCountdownDisplayLists[allyTeamID])
	end
	
	-- Store current countdown value for future comparison
	lastCountdownValues[allyTeamID] = timeRemaining
	
	-- Create new display list
	allyTeamCountdownDisplayLists[allyTeamID] = glCreateList(function()
		local countdownColor = COUNTDOWN_COLOR
		local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
		local countdownX, countdownY
		
		if amSpectating then
			countdownX, countdownY = calculateSpectatorCountdownPosition(allyTeamID, minimapPosX, minimapPosY, minimapSizeX)
			if not countdownX then return end
		else
			-- Regular player view (non-spectator)
			local healthbarLeft = minimapPosX + ICON_SIZE/2
			local healthbarRight = minimapPosX + minimapSizeX - ICON_SIZE/2
			local healthbarTop = minimapPosY - MINIMAP_GAP
			local healthbarBottom = healthbarTop - healthbarHeight
			local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
			local barWidth = healthbarRight - healthbarLeft
			local thresholdX = healthbarLeft + (threshold / maxThreshold) * barWidth
			local skullOffset = (1 / maxThreshold) * barWidth
			countdownX = thresholdX - skullOffset
			countdownY = healthbarBottom + (healthbarTop - healthbarBottom) / 2 - 7
		end
		
		-- Use cached font size (scale for spectator mode)
		local countdownFontSize = fontCache.fontSize * COUNTDOWN_FONT_SIZE_MULTIPLIER
		if amSpectating then
			local aliveAllyTeams = getAliveAllyTeams()
			local totalTeams = #aliveAllyTeams
			local layout = calculateSpectatorLayout(totalTeams, minimapSizeX)
			local scaleFactor = layout.barHeight / healthbarHeight
			countdownFontSize = max(10, countdownFontSize * scaleFactor)
		end
		
		local text = format("%d", timeRemaining)
		drawCountdownText(countdownX, countdownY, text, countdownFontSize, countdownColor)
	end)
	
	return allyTeamCountdownDisplayLists[allyTeamID]
end

function widget:Initialize()
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	selectedAllyTeamID = myAllyID
	gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID()))
	
	gameSeconds = spGetGameSeconds() or 0
	defeatTime = 0
	
	local allUnits = spGetAllUnits()
	local myTeamID = spGetMyTeamID()
	
	for _, unitID in ipairs(allUnits) do
		widget:MetaUnitAdded(unitID,  spGetUnitDefID(unitID), spGetUnitTeam(unitID), nil)
	end
end

function widget:MetaUnitAdded(unitID, unitDefID, unitTeam, builderID)
	if unitTeam == spGetMyTeamID() then
		local unitDef = UnitDefs[unitDefID]
		
		if unitDef.customParams and unitDef.customParams.iscommander then
			myCommanders[unitID] = true
		end
	end
end

function widget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	if myCommanders[unitID] then
		myCommanders[unitID] = nil
	end
end

function widget:Update(dt)
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	
	local currentGameTime = spGetGameSeconds()
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local timeUntilUnfreeze = max(0, freezeExpirationTime - currentGameTime)
	
	gameSeconds = currentGameTime  -- Update game seconds every frame
	
	-- Force clear all defeat timers when threshold is frozen
	if isThresholdFrozen then
		if amSpectating then
			-- Clear all ally team defeat times in spectator mode
			for allyTeamID in pairs(allyTeamDefeatTimes) do
				allyTeamDefeatTimes[allyTeamID] = 0
			end
		else
			-- Clear player defeat time
			defeatTime = 0
			loopSoundEndTime = 0
			soundQueue = nil
			soundIndex = 1
		end
		
		-- Clear countdown display lists for all ally teams
		for allyTeamID, countdownDisplayList in pairs(allyTeamCountdownDisplayLists) do
			if countdownDisplayList then
				glDeleteList(countdownDisplayList)
				allyTeamCountdownDisplayLists[allyTeamID] = nil
			end
		end
		lastCountdownValues = {} -- Clear cached countdown values
	end
	
	currentTime = os.clock()
	
	-- Check if forced update is needed for warning blinking
	local needsUpdate = false
	if isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS then
		-- Skull is blinking - check if we're in a new blink phase
		local blinkPhase = (currentTime % BLINK_INTERVAL) / BLINK_INTERVAL
		local currentBlinkState = blinkPhase < 0.33
		if isSkullFaded ~= currentBlinkState then
			needsUpdate = true
		end
	end
	
	-- Regular update check on interval
	if needsUpdate or currentTime - lastUpdateTime > UPDATE_FREQUENCY then
		lastUpdateTime = currentTime
		updateScoreDisplayList()
	end
	
	-- Check if we should show the timer warning (player mode only)
	if not amSpectating and defeatTime > gameSeconds then
		local timeRemaining = ceil(defeatTime - gameSeconds)
		local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
		local score = 0
		
		for _, teamID in ipairs(spGetTeamList(myAllyID)) do
			local _, _, isDead = spGetTeamInfo(teamID)
			if not isDead then
				local teamScore = spGetTeamRulesParam(teamID, SCORE_RULES_KEY)
				if teamScore then
					score = teamScore
					break
				end
			end
		end
		
		local difference = score - threshold
		local territoriesNeeded = abs(difference)  -- Need one more than the negative difference
		
		-- Only show warning if difference is negative and only once per cooldown period
		if difference < 0 and freezeExpirationTime < currentGameTime then
			if currentGameTime >= lastTimerWarningTime + TIMER_COOLDOWN then
				spPlaySoundFile("warning1", 1)
				-- Create the warning message
				local domMsg, conqMsg = createTimerWarningMessage(timeRemaining, territoriesNeeded)
				timerWarningEndTime = currentGameTime + TIMER_WARNING_DISPLAY_TIME
				
				-- Create the display list for the warning
				createTimerWarningDisplayList(domMsg, conqMsg)
			end
			lastTimerWarningTime = currentGameTime
		end
	end
	
	-- Note: Countdown display is now handled in DrawScreen function
	-- This ensures proper positioning for each ally team in spectator mode
end

-- Helper function to get player team data
local function getPlayerTeamData()
	local score = 0
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local teamID = nil
	local rank = nil
	
	-- Find the first alive team in our ally team
	for _, tid in ipairs(spGetTeamList(myAllyID)) do
		local _, _, isDead = spGetTeamInfo(tid)
		if not isDead then
			local teamScore = spGetTeamRulesParam(tid, SCORE_RULES_KEY)
			if teamScore then
				score = teamScore
				teamID = tid
				rank = spGetTeamRulesParam(tid, RANK_RULES_KEY)
				break
			end
		end
	end
	
	local difference = score - threshold
	local barColor = getBarColor(difference)
	
	return {
		score = score,
		threshold = threshold,
		difference = difference,
		rank = rank,
		teamID = teamID,
		barColor = barColor
	}
end

-- Helper function to get spectator ally team data
local function getSpectatorAllyTeamData()
	local aliveAllyTeams = getAliveAllyTeams()
	local allyTeamScores = {}
	
	-- Gather all ally team data
	for _, allyTeamID in ipairs(aliveAllyTeams) do
		local score = 0
		local teamColor = {1, 1, 1, 1}
		local rank = nil
		local defeatTimeRemaining = 0
		
		-- Find first alive team in this ally team
		for _, teamID in ipairs(spGetTeamList(allyTeamID)) do
			local _, _, isDead = spGetTeamInfo(teamID)
			if not isDead then
				local teamScore = spGetTeamRulesParam(teamID, SCORE_RULES_KEY)
				if teamScore then
					score = teamScore
					rank = spGetTeamRulesParam(teamID, RANK_RULES_KEY)
					local r, g, b = spGetTeamColor(teamID)
					teamColor = {r, g, b, 1}
					break
				end
			end
		end
		
		-- Calculate defeat time remaining
		if allyTeamDefeatTimes[allyTeamID] and allyTeamDefeatTimes[allyTeamID] > 0 then
			defeatTimeRemaining = max(0, allyTeamDefeatTimes[allyTeamID] - gameSeconds)
		else
			defeatTimeRemaining = math.huge
		end
		
		table.insert(allyTeamScores, {
			allyTeamID = allyTeamID,
			score = score,
			teamColor = teamColor,
			rank = rank,
			defeatTimeRemaining = defeatTimeRemaining
		})
	end
	
	-- Sort by score first (highest = 1st place), then by defeat time remaining (lowest timer = last place)
	table.sort(allyTeamScores, function(a, b)
		if a.score == b.score then
			-- When scores are tied, more time remaining = better rank (lower timer = worse rank)
			return a.defeatTimeRemaining > b.defeatTimeRemaining
		end
		-- Higher score = better rank (1st place)
		return a.score > b.score
	end)
	
	return allyTeamScores
end

-- Helper function to calculate spectator bar position
local function calculateSpectatorBarPosition(index, layout, minimapPosX, minimapPosY)
	local columnIndex = floor((index - 1) / layout.maxBarsPerColumn)
	local positionInColumn = ((index - 1) % layout.maxBarsPerColumn)
	
	local columnStartX = minimapPosX + (columnIndex * layout.columnWidth)
	local healthbarLeft = columnStartX + SPECTATOR_COLUMN_PADDING
	local healthbarRight = healthbarLeft + layout.barWidth
	local startY = minimapPosY - MINIMAP_GAP
	local healthbarTop = startY - (positionInColumn * (layout.barHeight + SPECTATOR_BAR_SPACING))
	local healthbarBottom = healthbarTop - layout.barHeight
	
	return healthbarLeft, healthbarBottom, healthbarRight, healthbarTop
end

-- Helper function to draw spectator bar text
local function drawSpectatorBarText(healthbarLeft, healthbarBottom, healthbarRight, healthbarTop, allyTeamData, threshold, fontSize)
	local paddingX = fontCache.paddingX
	local paddingY = fontCache.paddingY
	
	-- Scale font size to height of the score bar + 20%
	local barHeight = healthbarTop - healthbarBottom
	local scaledFontSize = barHeight * 1.1  -- Use 120% of bar height for the font
	
	-- Display difference - positioned inside the bar, aligned to the right
	local difference = allyTeamData.score - threshold
	
	-- Account for border width to position text inside the bar bounds
	local borderSize = 3
	local innerRight = healthbarRight - borderSize - paddingX
	local differenceVerticalOffset = 3

	-- Center vertically in the bar, moved up 1 pixel
	local differenceTextY = healthbarBottom + (barHeight - scaledFontSize) / 2 + differenceVerticalOffset
	
	-- Format the difference text
	local formattedDifference = difference
	if difference > 0 then
		formattedDifference = "+" .. difference
	end
	
	-- Draw text with right alignment inside the bar
	drawTextWithOutline(formattedDifference, innerRight, differenceTextY, scaledFontSize, "r", COLOR_WHITE)
	
	-- Rank display is hidden in spectator mode
end

-- Function to draw spectator mode score bars
local function drawSpectatorModeScoreBars()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local allyTeamScores = getSpectatorAllyTeamData()
	local totalTeams = #allyTeamScores
	
	if totalTeams == 0 then return end
	
	local layout = calculateSpectatorLayout(totalTeams, minimapSizeX)
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local currentGameTime = spGetGameSeconds()
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local fontSize = fontCache.fontSize
	
	-- Scale font size based on bar height
	local scaleFactor = layout.barHeight / healthbarHeight
	fontSize = max(10, fontSize * scaleFactor)
	
	-- Draw bars for each ally team
	for i, allyTeamData in ipairs(allyTeamScores) do
		local healthbarLeft, healthbarBottom, healthbarRight, healthbarTop = 
			calculateSpectatorBarPosition(i, layout, minimapPosX, minimapPosY)
		
		-- Draw background and border with team color tinting
		drawBackgroundAndBorder(healthbarLeft, healthbarBottom, healthbarRight, healthbarTop, allyTeamData.teamColor)
		
		-- Use ally team color for bar in spectator mode instead of red/green/yellow
		local barColor = allyTeamData.teamColor
		
		-- Draw health bar
		drawHealthBar(healthbarLeft, healthbarRight, healthbarBottom, healthbarTop, 
					  allyTeamData.score, threshold, barColor, isThresholdFrozen)
		
		-- Draw text
		drawSpectatorBarText(healthbarLeft, healthbarBottom, healthbarRight, healthbarTop, allyTeamData, threshold, fontSize)
	end
end

-- Helper function to calculate player bar position
local function calculatePlayerBarPosition(minimapPosX, minimapPosY, minimapSizeX)
	local healthbarLeft = minimapPosX + ICON_SIZE/2
	local healthbarRight = minimapPosX + minimapSizeX - ICON_SIZE/2
	local healthbarTop = minimapPosY - MINIMAP_GAP
	local healthbarBottom = healthbarTop - healthbarHeight
	
	return healthbarLeft, healthbarBottom, healthbarRight, healthbarTop
end

-- Helper function to draw player bar text
local function drawPlayerBarText(healthbarLeft, healthbarBottom, healthbarRight, healthbarTop, teamData, fontSize)
	local paddingX = fontCache.paddingX
	local paddingY = fontCache.paddingY
	
	-- Scale font size to height of the score bar + 20%
	local barHeight = healthbarTop - healthbarBottom
	local scaledFontSize = barHeight * 1.20  -- Use 120% of bar height for the font
	
	-- Display difference - positioned inside the bar, aligned to the right
	
	-- Account for border width to position text inside the bar bounds
	local borderSize = 3
	local innerRight = healthbarRight - borderSize - paddingX
	
	-- Center vertically in the bar, moved up 1 pixel
	local differenceTextY = healthbarBottom + (barHeight - scaledFontSize) / 2 + 1
	
	-- Format the difference text
	local formattedDifference = teamData.difference
	if teamData.difference > 0 then
		formattedDifference = "+" .. teamData.difference
	end
	
	-- Draw text with right alignment inside the bar
	drawTextWithOutline(formattedDifference, innerRight, differenceTextY, scaledFontSize, "r", COLOR_WHITE)
end

-- Function to draw player score bar
local function drawPlayerScoreBar()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local teamData = getPlayerTeamData()
	
	if not teamData.teamID then return end
	
	local healthbarLeft, healthbarBottom, healthbarRight, healthbarTop = 
		calculatePlayerBarPosition(minimapPosX, minimapPosY, minimapSizeX)
	
	local currentGameTime = spGetGameSeconds()
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local fontSize = fontCache.fontSize
	
	-- Get team color for background tinting
	local r, g, b = spGetTeamColor(teamData.teamID)
	local teamColor = {r, g, b, 1}
	
	-- Draw background and border with team color tinting
	drawBackgroundAndBorder(healthbarLeft, healthbarBottom, healthbarRight, healthbarTop, teamColor)
	
	-- Draw health bar
	drawHealthBar(healthbarLeft, healthbarRight, healthbarBottom, healthbarTop, 
				  teamData.score, teamData.threshold, teamData.barColor, isThresholdFrozen)
	
	-- Draw text
	drawPlayerBarText(healthbarLeft, healthbarBottom, healthbarRight, healthbarTop, teamData, fontSize)
	
	-- Draw rank if available - positioned below the score bar, aligned to left
	if teamData.rank then
		local rankBoxWidth = 40
		local rankBoxHeight = fontSize + 4
		local rankX = healthbarLeft
		local rankY = healthbarBottom - rankBoxHeight - 5
		drawRankTextBox(rankX, rankY, rankBoxWidth, rankBoxHeight, teamData.rank, fontSize, COLOR_WHITE)
	end
end

-- Helper function to check if display list needs updating
local function needsDisplayListUpdate()
	local currentGameTime = spGetGameSeconds()
	local scoreAllyID = amSpectating and selectedAllyTeamID or myAllyID
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local currentMinimapDimensions = {minimapPosX, minimapPosY, minimapSizeX}
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local currentMaxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	
	if scoreAllyID == gaiaAllyTeamID then 
		return false
	end
	
	if not fontCache.initialized then
		return true
	end

	if amSpectating then
		if lastAmSpectating ~= amSpectating or lastSelectedAllyTeamID ~= selectedAllyTeamID then
			return true
		end
		
		-- Check spectator scores and ranks
		local aliveAllyTeams = getAliveAllyTeams()
		local currentAllyTeamScores = {}
		local currentTeamRanks = {}
		
		for _, allyTeamID in ipairs(aliveAllyTeams) do
			local score = 0
			local rank = nil
			local teamID = nil
			
			for _, tid in ipairs(spGetTeamList(allyTeamID)) do
				local _, _, isDead = spGetTeamInfo(tid)
				if not isDead then
					local teamScore = spGetTeamRulesParam(tid, SCORE_RULES_KEY)
					if teamScore then
						score = teamScore
						teamID = tid
						rank = spGetTeamRulesParam(tid, RANK_RULES_KEY)
						break
					end
				end
			end
			
			currentAllyTeamScores[allyTeamID] = score
			
			if teamID then
				currentTeamRanks[teamID] = rank
				if lastTeamRanks[teamID] ~= rank then
					return true
				end
			end
		end
		
		-- Compare with last scores
		for allyTeamID, score in pairs(currentAllyTeamScores) do
			if lastAllyTeamScores[allyTeamID] ~= score then
				lastAllyTeamScores = currentAllyTeamScores
				lastTeamRanks = currentTeamRanks
				return true
			end
		end
		
		-- Check if any ally teams changed state
		for allyTeamID, _ in pairs(lastAllyTeamScores) do
			if currentAllyTeamScores[allyTeamID] == nil then
				lastAllyTeamScores = currentAllyTeamScores
				lastTeamRanks = currentTeamRanks
				return true
			end
		end
		
		lastAllyTeamScores = currentAllyTeamScores
		lastTeamRanks = currentTeamRanks
	else
		-- Player mode update check
		local teamData = getPlayerTeamData()
		
		if lastScore ~= teamData.score or lastDifference ~= teamData.difference or 
		   lastThreshold ~= threshold or lastMaxThreshold ~= currentMaxThreshold or
		   lastIsThresholdFrozen ~= isThresholdFrozen or lastFreezeExpirationTime ~= freezeExpirationTime or
		   lastHealthbarWidth ~= healthbarWidth or 
		   lastHealthbarHeight ~= healthbarHeight or
		   lastMinimapDimensions[1] ~= currentMinimapDimensions[1] or
		   lastMinimapDimensions[2] ~= currentMinimapDimensions[2] or
		   lastMinimapDimensions[3] ~= currentMinimapDimensions[3] or
		   lastAmSpectating ~= amSpectating or
		   (teamData.teamID and lastTeamRanks[teamData.teamID] ~= teamData.rank) then
			
			lastScore = teamData.score
			lastDifference = teamData.difference
			if teamData.teamID then
				lastTeamRanks[teamData.teamID] = teamData.rank
			end
			return true
		end
	end
	
	return false
end

-- Update tracking variables for next comparison
local function updateTrackingVariables()
	local currentGameTime = spGetGameSeconds()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local currentMinimapDimensions = {minimapPosX, minimapPosY, minimapSizeX}
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local currentMaxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	
	lastThreshold = threshold
	lastMaxThreshold = currentMaxThreshold
	lastIsThresholdFrozen = isThresholdFrozen
	lastFreezeExpirationTime = freezeExpirationTime
	lastHealthbarWidth = healthbarWidth
	lastHealthbarHeight = healthbarHeight
	lastMinimapDimensions = currentMinimapDimensions
	lastAmSpectating = amSpectating
	lastSelectedAllyTeamID = selectedAllyTeamID
	maxThreshold = currentMaxThreshold
end

-- Initialize font cache if needed
local function initializeFontCache()
	if not fontCache.initialized then
		local _, viewportSizeY = spGetViewGeometry()
		fontCache.fontSizeMultiplier = max(1.2, math.min(2.25, viewportSizeY / 1080))
		fontCache.fontSize = floor(14 * fontCache.fontSizeMultiplier)
		fontCache.paddingX = floor(fontCache.fontSize * PADDING_MULTIPLIER)
		fontCache.paddingY = fontCache.paddingX
		fontCache.initialized = true
	end
end

function updateScoreDisplayList()
	local scoreAllyID = amSpectating and selectedAllyTeamID or myAllyID
	
	if scoreAllyID == gaiaAllyTeamID then 
		if displayList then
			glDeleteList(displayList)
			displayList = nil
		end
		return 
	end
	
	initializeFontCache()

	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	healthbarWidth = minimapSizeX - ICON_SIZE
	
	local needsUpdate = needsDisplayListUpdate()
	updateTrackingVariables()
	
	if not needsUpdate and displayList then
		return
	end
	
	if displayList then
		glDeleteList(displayList)
	end
	
	displayList = glCreateList(function()
		if amSpectating then
			drawSpectatorModeScoreBars()
		else
			drawPlayerScoreBar()
		end
	end)
end

-- Helper function to clean up display lists
local function cleanupDisplayLists()
	if displayList then
		glDeleteList(displayList)
		displayList = nil
	end
	
	if timerWarningDisplayList then
		glDeleteList(timerWarningDisplayList)
		timerWarningDisplayList = nil
	end
	
	-- Clean up all ally team countdown display lists
	for allyTeamID, countdownDisplayList in pairs(allyTeamCountdownDisplayLists) do
		if countdownDisplayList then
			glDeleteList(countdownDisplayList)
		end
	end
	allyTeamCountdownDisplayLists = {}
	
	-- Legacy cleanup for old single countdown display list (in case it still exists)
	if countdownDisplayList then
		glDeleteList(countdownDisplayList)
		countdownDisplayList = nil
	end
end

-- Helper function to queue teleport sounds
local function queueTeleportSounds()
	soundQueue = {}
	if defeatTime and defeatTime > 0 then
		table.insert(soundQueue, 1, {when = defeatTime - WINDUP_SOUND_DURATION - ACTIVATE_SOUND_DURATION, sound = "cmd-off", volume = 0.4})
		table.insert(soundQueue, 1, {when = defeatTime - WINDUP_SOUND_DURATION, sound = "teleport-windup", volume = 0.225})
	end
end

function widget:DrawScreen()
	local currentGameTime = spGetGameSeconds()
	
	if not displayList then
		updateScoreDisplayList()
	end
	
	if displayList then
		glCallList(displayList)
	end
	
	-- Draw countdowns
	if amSpectating then
		-- In spectator mode, draw countdowns for all ally teams that have active defeat times
		for allyTeamID, allyDefeatTime in pairs(allyTeamDefeatTimes) do
			if allyDefeatTime and allyDefeatTime > 0 and gameSeconds and allyDefeatTime > gameSeconds then
				local timeRemaining = ceil(allyDefeatTime - gameSeconds)
				if timeRemaining >= 0 and (timeRemaining ~= lastCountdownValues[allyTeamID] or not allyTeamCountdownDisplayLists[allyTeamID]) then
					createCountdownDisplayList(timeRemaining, allyTeamID)
				end
				
				if allyTeamCountdownDisplayLists[allyTeamID] then
					glCallList(allyTeamCountdownDisplayLists[allyTeamID])
				end
			end
		end
	else
		-- Player mode - draw countdown for own team only
		if defeatTime and defeatTime > 0 and gameSeconds and defeatTime > gameSeconds then
			local timeRemaining = ceil(defeatTime - gameSeconds)
			if timeRemaining >= 0 and (timeRemaining ~= lastCountdownValues[myAllyID] or not allyTeamCountdownDisplayLists[myAllyID]) then
				createCountdownDisplayList(timeRemaining, myAllyID)
			end
			
			if allyTeamCountdownDisplayLists[myAllyID] then
				glCallList(allyTeamCountdownDisplayLists[myAllyID])
			end
		end
	end
	
	if currentGameTime < timerWarningEndTime then
		local alpha = 1.0
		
		if timerWarningDisplayList then
			glColor(1, 1, 1, alpha)
			glCallList(timerWarningDisplayList)
		end
	end
end

function widget:PlayerChanged(playerID)
	if amSpectating then
		if spGetSelectedUnitsCount() > 0 then
			local unitID = spGetSelectedUnits()[1]
			local unitTeam = spGetUnitTeam(unitID)
			if unitTeam then
				selectedAllyTeamID = select(6, spGetTeamInfo(unitTeam)) or myAllyID
				return
			end
		end
		selectedAllyTeamID = myAllyID
	end
end

function widget:Shutdown()
	cleanupDisplayLists()
end

function widget:GameFrame(frame)
	if frame % DEFEAT_CHECK_INTERVAL == AFTER_GADGET_TIMER_UPDATE_MODULO + 2 then
		if amSpectating then
			-- In spectator mode, track defeat times for all ally teams
			local allyTeamList = spGetAllyTeamList()
			for _, allyTeamID in ipairs(allyTeamList) do
				if allyTeamID ~= gaiaAllyTeamID and isAllyTeamAlive(allyTeamID) then
					-- Find first alive team in this ally team
					local allyDefeatTime = 0
					for _, teamID in ipairs(spGetTeamList(allyTeamID)) do
						local _, _, isDead = spGetTeamInfo(teamID)
						if not isDead then
							allyDefeatTime = spGetTeamRulesParam(teamID, "defeatTime") or 0
							break
						end
					end
					allyTeamDefeatTimes[allyTeamID] = allyDefeatTime
				end
			end
		else
			-- For player mode, just track own team
			local myTeamID = Spring.GetMyTeamID()
			local newDefeatTime = spGetTeamRulesParam(myTeamID, "defeatTime") or 0
			if newDefeatTime > 0 then
				if newDefeatTime ~= defeatTime then
					defeatTime = newDefeatTime
					loopSoundEndTime = defeatTime - WINDUP_SOUND_DURATION
					soundQueue = nil
					queueTeleportSounds()
				end
			else
				defeatTime = 0
				loopSoundEndTime = 0
				soundQueue = nil
				soundIndex = 1
			end
		end
		
		local rankChanged = false
		local currentRank = nil
		
		if amSpectating then
			-- For spectator mode, check all ranks
			local allyTeamList = spGetAllyTeamList()
			for _, allyTeamID in ipairs(allyTeamList) do
				for _, teamID in ipairs(spGetTeamList(allyTeamID)) do
					local _, _, isDead = spGetTeamInfo(teamID)
					if not isDead then
						local newRank = spGetTeamRulesParam(teamID, RANK_RULES_KEY)
						if newRank and lastTeamRanks[teamID] ~= newRank then
							rankChanged = true
							break
						end
					end
				end
				if rankChanged then break end
			end
		else
			-- For player mode, just check own team
			for _, teamID in ipairs(spGetTeamList(myAllyID)) do
				local _, _, isDead = spGetTeamInfo(teamID)
				if not isDead then
					currentRank = spGetTeamRulesParam(teamID, RANK_RULES_KEY)
					if currentRank and lastTeamRanks[teamID] ~= currentRank then
						rankChanged = true
						break
					end
				end
			end
		end
		
		if rankChanged then
			if displayList then
				glDeleteList(displayList)
				displayList = nil
			end
			-- Force update by setting lastUpdateTime to old value
			lastUpdateTime = 0
		end
	end

	gameSeconds = spGetGameSeconds() or 0

	if loopSoundEndTime and loopSoundEndTime > gameSeconds then
		if lastLoop <= currentTime then
			lastLoop = currentTime
			
			-- Calculate volume based on time until defeat
			local timeRange = loopSoundEndTime - (defeatTime - WINDUP_SOUND_DURATION - CHARGE_SOUND_LOOP_DURATION * 10)
			local timeLeft = loopSoundEndTime - gameSeconds
			local minVolume = 0.05
			local maxVolume = 0.2
			local volumeRange = maxVolume - minVolume
			
			local volumeFactor = 1 - (timeLeft / timeRange)
			volumeFactor = math.clamp(volumeFactor, 0, 1)
			local currentVolume = minVolume + (volumeFactor * volumeRange)
			
			for unitID in pairs(myCommanders) do
				local x, y, z = spGetUnitPosition(unitID)
				if x then
					spPlaySoundFile("teleport-charge-loop", currentVolume, x, y, z, 0, 0, 0, "sfx")
				else
					myCommanders[unitID] = nil
				end
			end
		end
	else
		local sound = soundQueue and soundQueue[soundIndex]
		if sound and gameSeconds and sound.when < gameSeconds then
			for unitID in pairs(myCommanders) do
				local x, y, z = spGetUnitPosition(unitID)
				if x then
					spPlaySoundFile(sound.sound, sound.volume, x, y, z, 0, 0, 0, "sfx")
				else
					myCommanders[unitID] = nil
				end
			end
			soundIndex = soundIndex + 1
		end
	end
end