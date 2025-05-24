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

local floor = math.floor
local ceil = math.ceil
local format = string.format
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

local WARNING_THRESHOLD = 3
local ALERT_THRESHOLD = 10
local WARNING_SECONDS = 15
local PADDING_MULTIPLIER = 0.36
local UPDATE_FREQUENCY = 0.1
local BLINK_INTERVAL = 1
local DEFEAT_CHECK_INTERVAL = Game.gameSpeed
local AFTER_GADGET_TIMER_UPDATE_MODULO = 3

local SCORE_RULES_KEY = "territorialDominationScore"
local THRESHOLD_RULES_KEY = "territorialDominationDefeatThreshold"
local FREEZE_DELAY_KEY = "territorialDominationFreezeDelay"
local MAX_THRESHOLD_RULES_KEY = "territorialDominationMaxThreshold"
local RANK_RULES_KEY = "territorialDominationRank"

local WINDUP_SOUND_DURATION = 2
local ACTIVATE_SOUND_DURATION = 0
local CHARGE_SOUND_LOOP_DURATION = 4.7

local TIMER_WARNING_DISPLAY_TIME = 5
local TIMER_COOLDOWN = 120
local MINIMAP_GAP = 3
local BORDER_WIDTH = 2
local ICON_SIZE = 25
local TEXT_OUTLINE_OFFSET = 0.7
local TEXT_OUTLINE_ALPHA = 0.35
local COUNTDOWN_FONT_SIZE_MULTIPLIER = 1.6
local SPECTATOR_MAX_DISPLAY_HEIGHT = 256
local SPECTATOR_BAR_SPACING = 3
local SPECTATOR_COLUMN_PADDING = 4

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
local scorebarWidth = 300
local scorebarHeight = 16
local lineWidth = 2
local maxThreshold = 256
local currentTime = os.clock()
local defeatTime = 0
local gameSeconds = 0
local lastLoop = 0
local loopSoundEndTime = 0
local soundIndex = 1

local timerWarningDisplayList = nil
local lastTimerWarningMessages = nil

local lastThreshold = -1
local lastMaxThreshold = -1
local lastIsThresholdFrozen = false
local lastFreezeExpirationTime = -1
local lastScorebarWidth = -1
local lastScorebarHeight = -1
local lastMinimapDimensions = {-1, -1, -1}
local lastAmSpectating = false
local lastSelectedAllyTeamID = -1
local lastAllyTeamScores = {}
local lastTeamRanks = {}

local allyTeamDefeatTimes = {}
local allyTeamCountdownDisplayLists = {}
local lastCountdownValues = {}

local fontCache = {
	initialized = false,
	fontSizeMultiplier = 1,
	fontSize = 11,
	paddingX = 0,
	paddingY = 0
}

local backgroundColor = COLOR_BACKGROUND
local borderColor = COLOR_BORDER

local function drawTextWithOutline(text, xPosition, yPosition, fontSize, alignment, textColor)
	alignment = alignment or "l"
	textColor = textColor or COLOR_WHITE
	
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
		glText(text, xPosition + offset[1], yPosition + offset[2], fontSize, alignment)
	end
	
	glColor(textColor[1], textColor[2], textColor[3], textColor[4])
	glText(text, xPosition, yPosition, fontSize, alignment)
end

local function calculateSpectatorLayoutParameters(totalTeams, minimapSizeX)
	local fixedBarHeight = 16
	local totalBarHeight = fixedBarHeight + SPECTATOR_BAR_SPACING
	local maxBarsPerColumn = floor(SPECTATOR_MAX_DISPLAY_HEIGHT / totalBarHeight)
	
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

local function createTintedColor(baseColor, tintColor, strength)
	return {
		baseColor[1] + (tintColor[1] - baseColor[1]) * strength,
		baseColor[2] + (tintColor[2] - baseColor[2]) * strength,
		baseColor[3] + (tintColor[3] - baseColor[3]) * strength,
		baseColor[4]
	}
end

local function drawBackgroundAndBorder(left, bottom, right, top, teamColor)
	local backgroundTintStrength = 0.15
	local borderTintStrength = 0.1
	
	local tintedBackgroundColor = createTintedColor(backgroundColor, teamColor, backgroundTintStrength)
	local tintedBorderColor = createTintedColor(borderColor, teamColor, borderTintStrength)
	
	glColor(tintedBorderColor[1], tintedBorderColor[2], tintedBorderColor[3], tintedBorderColor[4])
	glRect(left - BORDER_WIDTH, bottom - BORDER_WIDTH, right + BORDER_WIDTH, top + BORDER_WIDTH)
	
	glColor(tintedBackgroundColor[1], tintedBackgroundColor[2], tintedBackgroundColor[3], tintedBackgroundColor[4])
	glRect(left, bottom, right, top)
end

local function getBarColorBasedOnDifference(difference)
	if difference <= WARNING_THRESHOLD then
		return COLOR_RED
	elseif difference <= ALERT_THRESHOLD then
		return COLOR_YELLOW
	else
		return COLOR_GREEN
	end
end

local function getFirstAliveTeamDataFromAllyTeam(allyTeamID)
	for _, teamID in ipairs(spGetTeamList(allyTeamID)) do
		local _, _, isDead = spGetTeamInfo(teamID)
		if not isDead then
			local score = spGetTeamRulesParam(teamID, SCORE_RULES_KEY)
			if score then
				local rank = spGetTeamRulesParam(teamID, RANK_RULES_KEY)
				return teamID, score, rank
			end
		end
	end
	return nil, 0, nil
end

local function getFreezeStatusInformation()
	local currentGameTime = spGetGameSeconds()
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local timeUntilUnfreeze = max(0, freezeExpirationTime - currentGameTime)
	
	return currentGameTime, freezeExpirationTime, isThresholdFrozen, timeUntilUnfreeze
end

local function drawHealthBar(left, right, bottom, top, score, threshold, barColor, isThresholdFrozen)
	local fullScorebarLeft = left
	local fullScorebarRight = right
	local barWidth = right - left
	
	local originalRight = right
	local exceedsMaxThreshold = score > maxThreshold
	
	local scorebarScoreRight = left + math.min(score / maxThreshold, 1) * barWidth
	
	if exceedsMaxThreshold then
		right = originalRight
	end
	
	local thresholdX = left + (threshold / maxThreshold) * barWidth
	
	local skullOffset = (1 / maxThreshold) * barWidth
	local skullX = thresholdX - skullOffset
	
	local borderSize = 3
	local fillPaddingLeft = fullScorebarLeft + borderSize
	local fillPaddingRight = scorebarScoreRight - borderSize
	local fillPaddingTop = top
	local fillPaddingBottom = bottom + borderSize
	
	local linePos = scorebarScoreRight
	if exceedsMaxThreshold then
		local overfillRatio = (score - maxThreshold) / maxThreshold
		overfillRatio = math.min(overfillRatio, 1)
		
		local maxWidth = originalRight - borderSize - fillPaddingLeft
		local backfillWidth = maxWidth * overfillRatio
		linePos = originalRight - borderSize - backfillWidth
		
		linePos = math.max(fillPaddingLeft, linePos)
	end
	
	local baseColor = barColor
	local topColor = {baseColor[1], baseColor[2], baseColor[3], baseColor[4]}
	local bottomColor = {baseColor[1]*0.7, baseColor[2]*0.7, baseColor[3]*0.7, baseColor[4]}
	
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	
	if fillPaddingLeft < fillPaddingRight then
		if exceedsMaxThreshold then
			local overfillRatio = (score - maxThreshold) / maxThreshold
			overfillRatio = math.min(overfillRatio, 1)
			
			local maxBarWidth = originalRight - borderSize - fillPaddingLeft
			local overfillWidth = maxBarWidth * overfillRatio
			
			local brightColorStart = originalRight - borderSize - overfillWidth
			
			if brightColorStart > fillPaddingLeft then
				local vertices = {
					{v = {fillPaddingLeft, fillPaddingBottom}, c = bottomColor},
					{v = {brightColorStart, fillPaddingBottom}, c = bottomColor},
					{v = {brightColorStart, fillPaddingTop}, c = topColor},
					{v = {fillPaddingLeft, fillPaddingTop}, c = topColor}
				}
				gl.Shape(GL.QUADS, vertices)
			end
			
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
				{v = {brightColorStart, fillPaddingBottom}, c = excessBottomColor},
				{v = {originalRight - borderSize, fillPaddingBottom}, c = excessBottomColor},
				{v = {originalRight - borderSize, fillPaddingTop}, c = excessTopColor},
				{v = {brightColorStart, fillPaddingTop}, c = excessTopColor}
			}
			gl.Shape(GL.QUADS, vertices)
		else
			local vertices = {
				{v = {fillPaddingLeft, fillPaddingBottom}, c = bottomColor},
				{v = {fillPaddingRight, fillPaddingBottom}, c = bottomColor},
				{v = {fillPaddingRight, fillPaddingTop}, c = topColor},
				{v = {fillPaddingLeft, fillPaddingTop}, c = topColor}
			}
			gl.Shape(GL.QUADS, vertices)
		end
		
		local glossHeight = (fillPaddingTop - fillPaddingBottom) * 0.4
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		
		local highlightRight = fillPaddingRight
		if exceedsMaxThreshold then
			highlightRight = originalRight - borderSize
		end
		
		local topGlossBottom = fillPaddingTop - glossHeight
		local vertices = {
			{v = {fillPaddingLeft, topGlossBottom}, c = {1, 1, 1, 0}},
			{v = {highlightRight, topGlossBottom}, c = {1, 1, 1, 0}},
			{v = {highlightRight, fillPaddingTop}, c = {1, 1, 1, 0.04}},
			{v = {fillPaddingLeft, fillPaddingTop}, c = {1, 1, 1, 0.04}}
		}
		gl.Shape(GL.QUADS, vertices)
		
		local bottomGlossHeight = (fillPaddingTop - fillPaddingBottom) * 0.2
		vertices = {
			{v = {fillPaddingLeft, fillPaddingBottom}, c = {1, 1, 1, 0.02}},
			{v = {highlightRight, fillPaddingBottom}, c = {1, 1, 1, 0.02}},
			{v = {highlightRight, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}},
			{v = {fillPaddingLeft, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}}
		}
		gl.Shape(GL.QUADS, vertices)
		
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	
	if threshold >= 1 then
		glPushMatrix()
		local skullY = bottom + (top - bottom)/2
		glTranslate(skullX, skullY, 0)
		
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
		
		local skullAlpha = 1.0
		if isThresholdFrozen then
			local currentGameTime = spGetGameSeconds()
			local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
			local timeUntilUnfreeze = freezeExpirationTime - currentGameTime
			
			if timeUntilUnfreeze <= WARNING_SECONDS then
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
				skullAlpha = 0.5
				isSkullFaded = true
			end
		else
			isSkullFaded = false
		end
		
		glColor(1, 1, 1, skullAlpha)
		glTexture(':n:LuaUI/Images/skull.dds')
		glTexRect(-ICON_SIZE/2, -ICON_SIZE/2, ICON_SIZE/2, ICON_SIZE/2)
		
		glTexture(false)
		glPopMatrix()
	end
	
	local lineExtension = 3
	
	local lineColor = exceedsMaxThreshold and COLOR_WHITE_LINE or COLOR_GREY_LINE
	
	glColor(0, 0, 0, 0.8)
	glRect(linePos - lineWidth - 1, bottom - lineExtension, 
		   linePos + lineWidth + 1, top + lineExtension)
	
	glColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glRect(linePos - lineWidth/2, bottom - lineExtension, 
		   linePos + lineWidth/2, top + lineExtension)
		   
	return linePos, originalRight, thresholdX, skullX
end

local function formatDifferenceValue(difference)
	return difference > 0 and ("+" .. difference) or difference
end

local function drawDifferenceText(xPosition, yPosition, difference, fontSize, alignment, textColor, verticalOffset)
	alignment = alignment or "l"
	textColor = textColor or COLOR_WHITE
	verticalOffset = verticalOffset or 0
	
	local formattedDifference = formatDifferenceValue(difference)
	drawTextWithOutline(formattedDifference, xPosition, yPosition + verticalOffset, fontSize, alignment, textColor)
end

local function drawCountdownText(xPosition, yPosition, secondsRemaining, fontSize, textColor)
	local text = type(secondsRemaining) == "string" and secondsRemaining or format("%d", secondsRemaining)
	drawTextWithOutline(text, xPosition, yPosition, fontSize, "c", textColor)
end

local function drawRankTextBox(xPosition, yPosition, width, height, rank, fontSize, textColor)
	local rankText = spI18N('ui.territorialDomination.rank', {rank = rank})
	
	local textWidth = glGetTextWidth(rankText) * fontSize * 1.2
	local extraPadding = 5
	local finalWidth = max(textWidth, width) + extraPadding
	local finalHeight = height + extraPadding
	
	local yOffset = -3
	local adjustedY = yPosition + yOffset
	
	glColor(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4])
	glRect(xPosition - BORDER_WIDTH, adjustedY - BORDER_WIDTH, xPosition + finalWidth + BORDER_WIDTH, adjustedY + finalHeight + BORDER_WIDTH)
	
	glColor(COLOR_BACKGROUND[1], COLOR_BACKGROUND[2], COLOR_BACKGROUND[3], COLOR_BACKGROUND[4])
	glRect(xPosition, adjustedY, xPosition + finalWidth, adjustedY + finalHeight)
	
	local centerX = xPosition + finalWidth / 2
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
	if lastTimerWarningMessages and 
	   lastTimerWarningMessages[1] == dominatedMessage and 
	   lastTimerWarningMessages[2] == conquerMessage and
	   timerWarningDisplayList then
		return timerWarningDisplayList
	end
	
	if timerWarningDisplayList then
		glDeleteList(timerWarningDisplayList)
	end

	lastTimerWarningMessages = {dominatedMessage, conquerMessage}

	timerWarningDisplayList = glCreateList(function()
		local vsx, vsy = Spring.GetViewGeometry()
		local widgetScale = 0.80 + (vsx * vsy / 6000000)
		local fontSize = 22 * widgetScale
		
		local yPosition = 0.19
		local xPosition = vsx * 0.5
		
		glPushMatrix()
		glTranslate(xPosition, vsy * yPosition, 0)
		glScale(1.5, 1.5, 1)
		
		local line1Y = 442
		local lineSpacing = line1Y * 0.06
		local line2Y = line1Y - lineSpacing
		
		local alpha = 1.0
		
		glColor(0, 0, 0, alpha * 0.5)
		glText(dominatedMessage, 0 - 1, line1Y - 1, fontSize / 1.5, "c")
		
		glColor(1, 1, 1, alpha)
		glText(dominatedMessage, 0, line1Y, fontSize / 1.5, "c")
		
		glColor(0, 0, 0, alpha * 0.5)
		glText(conquerMessage, 0 - 1, line2Y - 1, fontSize / 1.5, "c")
		
		glColor(1, 1, 1, alpha)
		glText(conquerMessage, 0, line2Y, fontSize / 1.5, "c")
		
		glPopMatrix()
	end)
	
	return timerWarningDisplayList
end

local function calculateSpectatorCountdownPosition(allyTeamID, minimapPosX, minimapPosY, minimapSizeX)
	local aliveAllyTeams = getAliveAllyTeams()
	local totalTeams = #aliveAllyTeams
	if totalTeams == 0 then return nil, nil end
	
	local layout = calculateSpectatorLayoutParameters(totalTeams, minimapSizeX)
	
	local allyTeamScores = {}
	for _, currentAllyTeamID in ipairs(aliveAllyTeams) do
		local _, score = getFirstAliveTeamDataFromAllyTeam(currentAllyTeamID)
		local defeatTimeRemaining = 0
		
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
	
	table.sort(allyTeamScores, function(a, b)
		if a.score == b.score then
			return a.defeatTimeRemaining > b.defeatTimeRemaining
		end
		return a.score > b.score
	end)
	
	local barIndex = nil
	for i, allyTeamData in ipairs(allyTeamScores) do
		if allyTeamData.allyTeamID == allyTeamID then
			barIndex = i
			break
		end
	end
	
	if barIndex then
		local columnIndex = floor((barIndex - 1) / layout.maxBarsPerColumn)
		local positionInColumn = ((barIndex - 1) % layout.maxBarsPerColumn)
		
		local columnStartX = minimapPosX + (columnIndex * layout.columnWidth)
		local scorebarLeft = columnStartX + SPECTATOR_COLUMN_PADDING
		local scorebarRight = scorebarLeft + layout.barWidth
		local startY = minimapPosY - MINIMAP_GAP
		local scorebarTop = startY - (positionInColumn * (layout.barHeight + SPECTATOR_BAR_SPACING))
		local scorebarBottom = scorebarTop - layout.barHeight
		
		local countdownY = scorebarBottom + (scorebarTop - scorebarBottom) / 2 - 7
		
		local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
		local barWidthForCalc = scorebarRight - scorebarLeft
		local thresholdX = scorebarLeft + (threshold / maxThreshold) * barWidthForCalc
		local skullOffset = (1 / maxThreshold) * barWidthForCalc
		local countdownX = thresholdX - skullOffset
		
		return countdownX, countdownY
	end
	
	return minimapPosX + minimapSizeX / 2, minimapPosY - MINIMAP_GAP - 20
end

local function createCountdownDisplayList(timeRemaining, allyTeamID)
	allyTeamID = allyTeamID or myAllyID
	
	if allyTeamCountdownDisplayLists[allyTeamID] and lastCountdownValues[allyTeamID] == timeRemaining then
		return allyTeamCountdownDisplayLists[allyTeamID]
	end
	
	if allyTeamCountdownDisplayLists[allyTeamID] then
		glDeleteList(allyTeamCountdownDisplayLists[allyTeamID])
	end
	
	lastCountdownValues[allyTeamID] = timeRemaining
	
	allyTeamCountdownDisplayLists[allyTeamID] = glCreateList(function()
		local countdownColor = COUNTDOWN_COLOR
		local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
		local countdownX, countdownY
		
		if amSpectating then
			countdownX, countdownY = calculateSpectatorCountdownPosition(allyTeamID, minimapPosX, minimapPosY, minimapSizeX)
			if not countdownX then return end
		else
			local scorebarLeft = minimapPosX + ICON_SIZE/2
			local scorebarRight = minimapPosX + minimapSizeX - ICON_SIZE/2
			local scorebarTop = minimapPosY - MINIMAP_GAP
			local scorebarBottom = scorebarTop - scorebarHeight
			local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
			local barWidth = scorebarRight - scorebarLeft
			local thresholdX = scorebarLeft + (threshold / maxThreshold) * barWidth
			local skullOffset = (1 / maxThreshold) * barWidth
			countdownX = thresholdX - skullOffset
			countdownY = scorebarBottom + (scorebarTop - scorebarBottom) / 2 - 7
		end
		
		local countdownFontSize = fontCache.fontSize * COUNTDOWN_FONT_SIZE_MULTIPLIER
		if amSpectating then
			local aliveAllyTeams = getAliveAllyTeams()
			local totalTeams = #aliveAllyTeams
			local layout = calculateSpectatorLayoutParameters(totalTeams, minimapSizeX)
			local scaleFactor = layout.barHeight / scorebarHeight
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

function widget:Update(deltaTime)
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	
	local currentGameTime, freezeExpirationTime, isThresholdFrozen, timeUntilUnfreeze = getFreezeStatusInformation()
	
	gameSeconds = currentGameTime
	
	if isThresholdFrozen then
		if amSpectating then
			for allyTeamID in pairs(allyTeamDefeatTimes) do
				allyTeamDefeatTimes[allyTeamID] = 0
			end
		else
			defeatTime = 0
			loopSoundEndTime = 0
			soundQueue = nil
			soundIndex = 1
		end
		
		for allyTeamID, countdownDisplayList in pairs(allyTeamCountdownDisplayLists) do
			if countdownDisplayList then
				glDeleteList(countdownDisplayList)
				allyTeamCountdownDisplayLists[allyTeamID] = nil
			end
		end
		lastCountdownValues = {}
	end
	
	currentTime = os.clock()
	
	local needsUpdate = false
	if isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS then
		local blinkPhase = (currentTime % BLINK_INTERVAL) / BLINK_INTERVAL
		local currentBlinkState = blinkPhase < 0.33
		if isSkullFaded ~= currentBlinkState then
			needsUpdate = true
		end
	end
	
	if needsUpdate or currentTime - lastUpdateTime > UPDATE_FREQUENCY then
		lastUpdateTime = currentTime
		updateScoreDisplayList()
	end
	
	if not amSpectating and defeatTime > gameSeconds then
		local timeRemaining = ceil(defeatTime - gameSeconds)
		local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
		local _, score = getFirstAliveTeamDataFromAllyTeam(myAllyID)
		
		local difference = score - threshold
		local territoriesNeeded = abs(difference)
		
		if difference < 0 and freezeExpirationTime < currentGameTime then
			if currentGameTime >= lastTimerWarningTime + TIMER_COOLDOWN then
				spPlaySoundFile("warning1", 1)
				local dominatedMessage, conquerMessage = createTimerWarningMessage(timeRemaining, territoriesNeeded)
				timerWarningEndTime = currentGameTime + TIMER_WARNING_DISPLAY_TIME
				
				createTimerWarningDisplayList(dominatedMessage, conquerMessage)
			end
			lastTimerWarningTime = currentGameTime
		end
	end
end

local function getPlayerTeamData()
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local teamID, score, rank = getFirstAliveTeamDataFromAllyTeam(myAllyID)
	local difference = score - threshold
	local barColor = getBarColorBasedOnDifference(difference)
	
	return {
		score = score,
		threshold = threshold,
		difference = difference,
		rank = rank,
		teamID = teamID,
		barColor = barColor
	}
end

local function getSpectatorAllyTeamData()
	local aliveAllyTeams = getAliveAllyTeams()
	local allyTeamScores = {}
	
	for _, allyTeamID in ipairs(aliveAllyTeams) do
		local teamID, score, rank = getFirstAliveTeamDataFromAllyTeam(allyTeamID)
		local teamColor = {1, 1, 1, 1}
		local defeatTimeRemaining = 0
		
		if teamID then
			local redComponent, greenComponent, blueComponent = spGetTeamColor(teamID)
			teamColor = {redComponent, greenComponent, blueComponent, 1}
		end
		
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
	
	table.sort(allyTeamScores, function(a, b)
		if a.score == b.score then
			return a.defeatTimeRemaining > b.defeatTimeRemaining
		end
		return a.score > b.score
	end)
	
	return allyTeamScores
end

local function calculateSpectatorBarPosition(index, layout, minimapPosX, minimapPosY)
	local columnIndex = floor((index - 1) / layout.maxBarsPerColumn)
	local positionInColumn = ((index - 1) % layout.maxBarsPerColumn)
	
	local columnStartX = minimapPosX + (columnIndex * layout.columnWidth)
	local scorebarLeft = columnStartX + SPECTATOR_COLUMN_PADDING
	local scorebarRight = scorebarLeft + layout.barWidth
	local startY = minimapPosY - MINIMAP_GAP
	local scorebarTop = startY - (positionInColumn * (layout.barHeight + SPECTATOR_BAR_SPACING))
	local scorebarBottom = scorebarTop - layout.barHeight
	
	return scorebarLeft, scorebarBottom, scorebarRight, scorebarTop
end

local function drawSpectatorBarText(scorebarLeft, scorebarBottom, scorebarRight, scorebarTop, allyTeamData, threshold, fontSize)
	local paddingX = fontCache.paddingX
	
	local barHeight = scorebarTop - scorebarBottom
	local scaledFontSize = barHeight * 1.1
	
	local difference = allyTeamData.score - threshold
	
	local borderSize = 3
	local innerRight = scorebarRight - borderSize - paddingX
	local differenceVerticalOffset = 3

	local differenceTextY = scorebarBottom + (barHeight - scaledFontSize) / 2
	
	drawDifferenceText(innerRight, differenceTextY, difference, scaledFontSize, "r", COLOR_WHITE, differenceVerticalOffset)
end

local function drawSpectatorModeScoreBars()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local allyTeamScores = getSpectatorAllyTeamData()
	local totalTeams = #allyTeamScores
	
	if totalTeams == 0 then return end
	
	local layout = calculateSpectatorLayoutParameters(totalTeams, minimapSizeX)
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local currentGameTime, freezeExpirationTime, isThresholdFrozen = getFreezeStatusInformation()
	local fontSize = fontCache.fontSize
	
	local scaleFactor = layout.barHeight / scorebarHeight
	fontSize = max(10, fontSize * scaleFactor)
	
	for i, allyTeamData in ipairs(allyTeamScores) do
		local scorebarLeft, scorebarBottom, scorebarRight, scorebarTop = 
			calculateSpectatorBarPosition(i, layout, minimapPosX, minimapPosY)
		
		drawBackgroundAndBorder(scorebarLeft, scorebarBottom, scorebarRight, scorebarTop, allyTeamData.teamColor)
		
		local barColor = allyTeamData.teamColor
		
		drawHealthBar(scorebarLeft, scorebarRight, scorebarBottom, scorebarTop, 
					  allyTeamData.score, threshold, barColor, isThresholdFrozen)
		
		drawSpectatorBarText(scorebarLeft, scorebarBottom, scorebarRight, scorebarTop, allyTeamData, threshold, fontSize)
	end
end

local function calculatePlayerBarPosition(minimapPosX, minimapPosY, minimapSizeX)
	local scorebarLeft = minimapPosX + ICON_SIZE/2
	local scorebarRight = minimapPosX + minimapSizeX - ICON_SIZE/2
	local scorebarTop = minimapPosY - MINIMAP_GAP
	local scorebarBottom = scorebarTop - scorebarHeight
	
	return scorebarLeft, scorebarBottom, scorebarRight, scorebarTop
end

local function drawPlayerBarText(scorebarLeft, scorebarBottom, scorebarRight, scorebarTop, teamData, fontSize)
	local paddingX = fontCache.paddingX
	
	local barHeight = scorebarTop - scorebarBottom
	local scaledFontSize = barHeight * 1.20
	
	local borderSize = 3
	local innerRight = scorebarRight - borderSize - paddingX
	
	local differenceTextY = scorebarBottom + (barHeight - scaledFontSize) / 2
	
	drawDifferenceText(innerRight, differenceTextY, teamData.difference, scaledFontSize, "r", COLOR_WHITE, 1)
end

local function drawPlayerScoreBar()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local teamData = getPlayerTeamData()
	
	if not teamData.teamID then return end
	
	local scorebarLeft, scorebarBottom, scorebarRight, scorebarTop = 
		calculatePlayerBarPosition(minimapPosX, minimapPosY, minimapSizeX)
	
	local currentGameTime, freezeExpirationTime, isThresholdFrozen = getFreezeStatusInformation()
	local fontSize = fontCache.fontSize
	
	local redComponent, greenComponent, blueComponent = spGetTeamColor(teamData.teamID)
	local teamColor = {redComponent, greenComponent, blueComponent, 1}
	
	drawBackgroundAndBorder(scorebarLeft, scorebarBottom, scorebarRight, scorebarTop, teamColor)
	
	drawHealthBar(scorebarLeft, scorebarRight, scorebarBottom, scorebarTop, 
				  teamData.score, teamData.threshold, teamData.barColor, isThresholdFrozen)
	
	drawPlayerBarText(scorebarLeft, scorebarBottom, scorebarRight, scorebarTop, teamData, fontSize)
	
	if teamData.rank then
		local rankBoxWidth = 40
		local rankBoxHeight = fontSize + 4
		local rankX = scorebarLeft
		local rankY = scorebarBottom - rankBoxHeight - 5
		drawRankTextBox(rankX, rankY, rankBoxWidth, rankBoxHeight, teamData.rank, fontSize, COLOR_WHITE)
	end
end

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
	lastScorebarWidth = scorebarWidth
	lastScorebarHeight = scorebarHeight
	lastMinimapDimensions = currentMinimapDimensions
	lastAmSpectating = amSpectating
	lastSelectedAllyTeamID = selectedAllyTeamID
	maxThreshold = currentMaxThreshold
end

local function needsDisplayListUpdate()
	local currentGameTime, freezeExpirationTime, isThresholdFrozen = getFreezeStatusInformation()
	local scoreAllyID = amSpectating and selectedAllyTeamID or myAllyID
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local currentMinimapDimensions = {minimapPosX, minimapPosY, minimapSizeX}
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local currentMaxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
	
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
		
		for allyTeamID, score in pairs(currentAllyTeamScores) do
			if lastAllyTeamScores[allyTeamID] ~= score then
				lastAllyTeamScores = currentAllyTeamScores
				lastTeamRanks = currentTeamRanks
				return true
			end
		end
		
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
		local teamData = getPlayerTeamData()
		
		if lastScore ~= teamData.score or lastDifference ~= teamData.difference or 
		   lastThreshold ~= threshold or lastMaxThreshold ~= currentMaxThreshold or
		   lastIsThresholdFrozen ~= isThresholdFrozen or lastFreezeExpirationTime ~= freezeExpirationTime or
		   lastScorebarWidth ~= scorebarWidth or 
		   lastScorebarHeight ~= scorebarHeight or
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
	scorebarWidth = minimapSizeX - ICON_SIZE
	
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

local function cleanupDisplayLists()
	if displayList then
		glDeleteList(displayList)
		displayList = nil
	end
	
	if timerWarningDisplayList then
		glDeleteList(timerWarningDisplayList)
		timerWarningDisplayList = nil
	end
	
	for allyTeamID, countdownDisplayList in pairs(allyTeamCountdownDisplayLists) do
		if countdownDisplayList then
			glDeleteList(countdownDisplayList)
		end
	end
	allyTeamCountdownDisplayLists = {}
end

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
	
	if amSpectating then
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
			local allyTeamList = spGetAllyTeamList()
			for _, allyTeamID in ipairs(allyTeamList) do
				if allyTeamID ~= gaiaAllyTeamID and isAllyTeamAlive(allyTeamID) then
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
			lastUpdateTime = 0
		end
	end

	gameSeconds = spGetGameSeconds() or 0

	if loopSoundEndTime and loopSoundEndTime > gameSeconds then
		if lastLoop <= currentTime then
			lastLoop = currentTime
			
			local timeRange = loopSoundEndTime - (defeatTime - WINDUP_SOUND_DURATION - CHARGE_SOUND_LOOP_DURATION * 10)
			local timeLeft = loopSoundEndTime - gameSeconds
			local minVolume = 0.05
			local maxVolume = 0.2
			local volumeRange = maxVolume - minVolume
			
			local volumeFactor = 1 - (timeLeft / timeRange)
			volumeFactor = math.clamp(volumeFactor, 0, 1)
			local currentVolume = minVolume + (volumeFactor * volumeRange)
			
			for unitID in pairs(myCommanders) do
				local xPosition, yPosition, zPosition = spGetUnitPosition(unitID)
				if xPosition then
					spPlaySoundFile("teleport-charge-loop", currentVolume, xPosition, yPosition, zPosition, 0, 0, 0, "sfx")
				else
					myCommanders[unitID] = nil
				end
			end
		end
	else
		local sound = soundQueue and soundQueue[soundIndex]
		if sound and gameSeconds and sound.when < gameSeconds then
			for unitID in pairs(myCommanders) do
				local xPosition, yPosition, zPosition = spGetUnitPosition(unitID)
				if xPosition then
					spPlaySoundFile(sound.sound, sound.volume, xPosition, yPosition, zPosition, 0, 0, 0, "sfx")
				else
					myCommanders[unitID] = nil
				end
			end
			soundIndex = soundIndex + 1
		end
	end
end