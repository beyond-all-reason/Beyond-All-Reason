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

--optimize update() callin

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

local WARNING_THRESHOLD = 3
local ALERT_THRESHOLD = 10
local WARNING_SECONDS = 15
local PADDING_MULTIPLIER = 0.36
local UPDATE_FREQUENCY = 2.0
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
local BAR_HEIGHT = 16
local TEXT_OUTLINE_OFFSET = 1.0
local TEXT_OUTLINE_ALPHA = 0.6
local COUNTDOWN_FONT_SIZE_MULTIPLIER = 1.6

local HALO_EXTENSION = 4
local HALO_MAX_ALPHA = 0.4

local COLOR_WHITE = {1, 1, 1, 1}
local COLOR_RED = {1, 0, 0, 1}
local COUNTDOWN_COLOR = {1, 0.2, 0.2, 1}
local COLOR_YELLOW = {1, 0.8, 0, 1}
local COLOR_BACKGROUND = {0, 0, 0, 0.5}
local COLOR_BORDER = {0.2, 0.2, 0.2, 0.2}
local COLOR_GREEN = {0, 0.8, 0, 0.8}
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
local displayList = nil
local lastDifference = -1
local healthbarWidth = 300
local lineWidth = 2
local maxThreshold = 256
local currentTime = os.clock()
local defeatTime = 0
local gameSeconds = 0
local lastLoop = 0
local loopSoundEndTime = 0
local soundIndex = 1

local timerWarningDisplayList = nil

local lastThreshold = -1
local lastMaxThreshold = -1
local lastIsThresholdFrozen = false
local lastHealthbarWidth = -1
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

local staticDisplayList = nil
local dynamicDisplayList = nil
local backgroundDisplayList = nil
local haloDisplayList = nil

local layoutCache = {
	initialized = false,
	minimapDimensions = {-1, -1, -1},
	spectatorLayout = nil,
	playerBarBounds = nil,
	lastViewportSize = {-1, -1}
}

local positionCache = {
	playerBar = nil,
	spectatorBars = {},
	countdownPositions = {},
	textPositions = {}
}

local colorCache = {
	teamColors = {},
	barColors = {},
	tintedColors = {},
	gradientColors = {}
}

local drawStateCache = {
	lastBlendMode = nil,
	lastTexture = nil,
	lastColor = {-1, -1, -1, -1}
}

local needsBackgroundUpdate = false
local needsStaticUpdate = false
local needsDynamicUpdate = false
local needsHaloUpdate = false

local LAYOUT_UPDATE_THRESHOLD = 2.0
local DYNAMIC_UPDATE_THRESHOLD = 0.2
local lastLayoutUpdate = 0
local lastDynamicUpdate = 0

local ruleParamCache = {
	threshold = 0,
	maxThreshold = 256,
	freezeDelay = 0,
	lastUpdate = 0,
	updateInterval = 0.5
}

local outlineCache = {
	defaultOffset = TEXT_OUTLINE_OFFSET,
	defaultAlpha = TEXT_OUTLINE_ALPHA,
	blackOutlineColor = {0, 0, 0, TEXT_OUTLINE_ALPHA}
}

local minimapGeometryCache = {
	posX = -1,
	posY = -1,
	sizeX = -1,
	lastUpdate = 0,
	updateInterval = 0.1
}

local function getCachedMinimapGeometry()
	local currentTime = os.clock()
	if currentTime - minimapGeometryCache.lastUpdate > minimapGeometryCache.updateInterval then
		minimapGeometryCache.posX, minimapGeometryCache.posY, minimapGeometryCache.sizeX = spGetMiniMapGeometry()
		minimapGeometryCache.lastUpdate = currentTime
	end
	return minimapGeometryCache.posX, minimapGeometryCache.posY, minimapGeometryCache.sizeX
end

local function setOptimizedTexture(texture)
	if drawStateCache.lastTexture ~= texture then
		glTexture(texture)
		drawStateCache.lastTexture = texture
	end
end

local function createTintedColor(baseColor, tintColor, strength)
	local tintedColor = {
		baseColor[1] + (tintColor[1] - baseColor[1]) * strength,
		baseColor[2] + (tintColor[2] - baseColor[2]) * strength,
		baseColor[3] + (tintColor[3] - baseColor[3]) * strength,
		baseColor[4]
	}
	return tintedColor
end

local function forceDisplayListUpdate()
	lastUpdateTime = 0
	needsBackgroundUpdate = true
	needsStaticUpdate = true
	needsDynamicUpdate = true
	needsHaloUpdate = true
end

local function cleanupDisplayList(displayList)
	if displayList then
		glDeleteList(displayList)
		return nil
	end
	return displayList
end

local function cleanupCountdowns(allyTeamIDFilter)
	local cleanedUp = false
	if allyTeamIDFilter then
		-- Clean up specific ally team countdowns
		for key, displayList in pairs(allyTeamCountdownDisplayLists) do
			if key:sub(1, #tostring(allyTeamIDFilter) + 1) == allyTeamIDFilter .. "_" then
				glDeleteList(displayList)
				allyTeamCountdownDisplayLists[key] = nil
				cleanedUp = true
			end
		end
		lastCountdownValues[allyTeamIDFilter] = nil
	else
		-- Clean up all countdowns
		for key, displayList in pairs(allyTeamCountdownDisplayLists) do
			if displayList then
				glDeleteList(displayList)
				cleanedUp = true
			end
		end
		allyTeamCountdownDisplayLists = {}
		lastCountdownValues = {}
	end
	return cleanedUp
end

local function calculateBarPosition(index, isSpectator)
	local minimapPosX, minimapPosY, minimapSizeX = getCachedMinimapGeometry()
	
	if not isSpectator then
		return {
			scorebarLeft = minimapPosX + ICON_SIZE/2,
			scorebarRight = minimapPosX + minimapSizeX - ICON_SIZE/2,
			scorebarTop = minimapPosY - MINIMAP_GAP,
			scorebarBottom = minimapPosY - MINIMAP_GAP - BAR_HEIGHT
		}
	else
		if not layoutCache.spectatorLayout then
			local aliveAllyTeams = getAliveAllyTeams()
			layoutCache.spectatorLayout = calculateSpectatorLayoutParameters(#aliveAllyTeams, minimapSizeX)
		end
		
		local layout = layoutCache.spectatorLayout
		local columnIndex = floor((index - 1) / layout.maxBarsPerColumn)
		local positionInColumn = ((index - 1) % layout.maxBarsPerColumn)
		
		local scorebarLeft = minimapPosX + (columnIndex * layout.columnWidth) + 4
		local scorebarRight = scorebarLeft + layout.barWidth
		local scorebarTop = minimapPosY - MINIMAP_GAP - (positionInColumn * (layout.barHeight + 3))
		local scorebarBottom = scorebarTop - layout.barHeight
		
		return {
			scorebarLeft = scorebarLeft,
			scorebarRight = scorebarRight,
			scorebarTop = scorebarTop,
			scorebarBottom = scorebarBottom
		}
	end
end

local function updateRuleParamCache()
	local currentTime = os.clock()
	if currentTime - ruleParamCache.lastUpdate < ruleParamCache.updateInterval then
		return
	end
	
	ruleParamCache.threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	ruleParamCache.maxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
	ruleParamCache.freezeDelay = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	ruleParamCache.lastUpdate = currentTime
	
	maxThreshold = ruleParamCache.maxThreshold
end

local function getCachedRuleParam(key)
	updateRuleParamCache()
	if key == THRESHOLD_RULES_KEY then
		return ruleParamCache.threshold
	elseif key == MAX_THRESHOLD_RULES_KEY then
		return ruleParamCache.maxThreshold
	elseif key == FREEZE_DELAY_KEY then
		return ruleParamCache.freezeDelay
	else
		return spGetGameRulesParam(key) or 0
	end
end

local function setOptimizedColor(r, g, b, a)
	local currentColor = drawStateCache.lastColor
	if currentColor[1] ~= r or currentColor[2] ~= g or currentColor[3] ~= b or currentColor[4] ~= a then
		glColor(r, g, b, a)
		drawStateCache.lastColor = {r, g, b, a}
	end
end

local function setOptimizedBlending(srcFactor, dstFactor)
	local blendMode = srcFactor .. "_" .. dstFactor
	if drawStateCache.lastBlendMode ~= blendMode then
		gl.Blending(srcFactor, dstFactor)
		drawStateCache.lastBlendMode = blendMode
	end
end

local function getCachedTeamColor(teamID)
	if not colorCache.teamColors[teamID] then
		local redComponent, greenComponent, blueComponent = spGetTeamColor(teamID)
		colorCache.teamColors[teamID] = {redComponent, greenComponent, blueComponent, 1}
	end
	return colorCache.teamColors[teamID]
end

local function getCachedTintedColor(baseColor, tintColor, strength, cacheKey)
	local key = cacheKey or (baseColor[1] .. "_" .. tintColor[1] .. "_" .. strength)
	if not colorCache.tintedColors[key] then
		colorCache.tintedColors[key] = createTintedColor(baseColor, tintColor, strength)
	end
	return colorCache.tintedColors[key]
end

local function drawTextWithOutline(text, x, y, fontSize, alignment, color, outlineOffset, outlineAlpha)
	local offset = outlineOffset or outlineCache.defaultOffset
	local alpha = outlineAlpha or outlineCache.defaultAlpha
	
	if alpha == outlineCache.defaultAlpha then
		setOptimizedColor(outlineCache.blackOutlineColor[1], outlineCache.blackOutlineColor[2], 
						  outlineCache.blackOutlineColor[3], outlineCache.blackOutlineColor[4])
	else
		setOptimizedColor(0, 0, 0, alpha)
	end
	
	glText(text, x - offset, y, fontSize, alignment)
	glText(text, x + offset, y, fontSize, alignment)
	glText(text, x, y - offset, fontSize, alignment)
	glText(text, x, y + offset, fontSize, alignment)
	
	setOptimizedColor(color[1], color[2], color[3], color[4])
	glText(text, x, y, fontSize, alignment)
end

local function drawDifferenceText(x, y, difference, fontSize, alignment, color, verticalOffset)
	local text = ""
	
	if difference > 0 then
		text = "+" .. difference
	elseif difference < 0 then
		text = tostring(difference)
	else
		text = "0"
	end
	
	local adjustedY = y + (verticalOffset or 0)
	drawTextWithOutline(text, x, adjustedY, fontSize, alignment, color)
end

local function drawCountdownText(x, y, text, fontSize, color)
	drawTextWithOutline(text, x, y, fontSize, "c", color)
end

local function drawOptimizedHealthBar(scorebarLeft, scorebarRight, scorebarBottom, scorebarTop, score, threshold, barColor, isThresholdFrozen)
	local fullHealthbarLeft = scorebarLeft
	local fullHealthbarRight = scorebarRight
	local barWidth = scorebarRight - scorebarLeft

	local originalRight = scorebarRight
	local exceedsMaxThreshold = score > maxThreshold
	
	local healthbarScoreRight = scorebarLeft + min(score / maxThreshold, 1) * barWidth
	
	if exceedsMaxThreshold then
		scorebarRight = originalRight
	end
	
	local thresholdX = scorebarLeft + (threshold / maxThreshold) * barWidth
	local skullOffset = (1 / maxThreshold) * barWidth
	local skullX = thresholdX - skullOffset
	
	local borderSize = 3
	local fillPaddingLeft = scorebarLeft + borderSize
	local fillPaddingRight = healthbarScoreRight - borderSize
	local fillPaddingTop = scorebarTop
	local fillPaddingBottom = scorebarBottom + borderSize

	local linePos = healthbarScoreRight
	if exceedsMaxThreshold then
		local overfillRatio = (score - maxThreshold) / maxThreshold
		overfillRatio = min(overfillRatio, 1)
		
		local maxWidth = scorebarRight - borderSize - fillPaddingLeft
		local backfillWidth = maxWidth * overfillRatio
		linePos = scorebarRight - borderSize - backfillWidth
		
		linePos = max(fillPaddingLeft, linePos)
	end
	
	local topColor = {barColor[1], barColor[2], barColor[3], barColor[4]}
	local bottomColor = {barColor[1]*0.7, barColor[2]*0.7, barColor[3]*0.7, barColor[4]}
	
	setOptimizedBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	
	if fillPaddingLeft < fillPaddingRight then
		if exceedsMaxThreshold then
			local overfillRatio = (score - maxThreshold) / maxThreshold
			overfillRatio = min(overfillRatio, 1)
			
			local maxBarWidth = scorebarRight - borderSize - fillPaddingLeft
			local overfillWidth = maxBarWidth * overfillRatio
			
			local brightColorStart = scorebarRight - borderSize - overfillWidth
			
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
				{v = {scorebarRight - borderSize, fillPaddingBottom}, c = excessBottomColor},
				{v = {scorebarRight - borderSize, fillPaddingTop}, c = excessTopColor},
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
		setOptimizedBlending(GL.SRC_ALPHA, GL.ONE)
		
		local highlightRight = fillPaddingRight
		if exceedsMaxThreshold then
			highlightRight = scorebarRight - borderSize
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
		
		setOptimizedBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	
	if threshold >= 1 then
		glPushMatrix()
		local skullY = scorebarBottom + (scorebarTop - scorebarBottom)/2
		glTranslate(skullX, skullY, 0)
		
		local shadowOffset = 1.5
		local shadowAlpha = 0.6
		local shadowScale = 1.1
		
		setOptimizedColor(0, 0, 0, shadowAlpha)
		setOptimizedTexture(':n:LuaUI/Images/skull.dds')
		glTexRect(
			-ICON_SIZE/2 * shadowScale + shadowOffset, 
			-ICON_SIZE/2 * shadowScale - shadowOffset, 
			ICON_SIZE/2 * shadowScale + shadowOffset, 
			ICON_SIZE/2 * shadowScale - shadowOffset
		)
		
		local skullAlpha = 1.0
		if isThresholdFrozen then
			local currentGameTime = spGetGameSeconds()
			local freezeExpirationTime = getCachedRuleParam(FREEZE_DELAY_KEY)
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
		
		setOptimizedColor(1, 1, 1, skullAlpha)
		setOptimizedTexture(':n:LuaUI/Images/skull.dds')
		glTexRect(-ICON_SIZE/2, -ICON_SIZE/2, ICON_SIZE/2, ICON_SIZE/2)
		
		setOptimizedTexture(false)
		glPopMatrix()
	end
	
	local lineExtension = 3
	
	local lineColor = exceedsMaxThreshold and COLOR_WHITE_LINE or COLOR_GREY_LINE
	
	setOptimizedColor(0, 0, 0, 0.8)
	glRect(linePos - lineWidth - 1, scorebarBottom - lineExtension, 
		   linePos + lineWidth + 1, scorebarTop + lineExtension)

	setOptimizedColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glRect(linePos - lineWidth/2, scorebarBottom - lineExtension, 
		   linePos + lineWidth/2, scorebarTop + lineExtension)
		   
	return linePos, scorebarRight, thresholdX, skullX
end

local function createTimerWarningMessage(timeRemaining, territoriesNeeded)
	local dominatedMessage = spI18N('ui.territorialDomination.beingDominated')
	local conquerMessage = spI18N('ui.territorialDomination.conquerTerritories', {count = territoriesNeeded, time = timeRemaining})
	return dominatedMessage, conquerMessage
end

local function createTimerWarningDisplayList(dominatedMessage, conquerMessage)
	if timerWarningDisplayList then
		glDeleteList(timerWarningDisplayList)
	end

	timerWarningDisplayList = glCreateList(function()
		local vsx, vsy = spGetViewGeometry()
		local centerX = vsx / 2
		local centerY = vsy / 2 + 100
		
		local fontSize = 24
		local spacing = 30
		
		drawTextWithOutline(dominatedMessage, centerX, centerY + spacing, fontSize, "c", COLOR_RED)
		drawTextWithOutline(conquerMessage, centerX, centerY - spacing, fontSize, "c", COLOR_YELLOW)
	end)
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

local function getFreezeStatusInformation()
	local currentGameTime = spGetGameSeconds()
	local freezeExpirationTime = getCachedRuleParam(FREEZE_DELAY_KEY)
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local timeUntilUnfreeze = max(0, freezeExpirationTime - currentGameTime)
	
	return currentGameTime, freezeExpirationTime, isThresholdFrozen, timeUntilUnfreeze
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

local function getBarColorBasedOnDifference(difference)
	if difference <= WARNING_THRESHOLD then
		return COLOR_RED
	elseif difference <= ALERT_THRESHOLD then
		return COLOR_YELLOW
	else
		return COLOR_GREEN
	end
end

local function calculateSpectatorLayoutParameters(totalTeams, minimapSizeX)
	local maxDisplayHeight = 256
	local barSpacing = 3
	
	local optimalNumColumns = totalTeams
	for numColumns = 1, totalTeams do
		local barsPerColumn = ceil(totalTeams / numColumns)
		local totalSpacingHeight = (barsPerColumn - 1) * barSpacing
		local requiredHeight = (barsPerColumn * BAR_HEIGHT) + totalSpacingHeight

		if requiredHeight <= maxDisplayHeight then
			optimalNumColumns = numColumns
			break
		end
	end
	
	local numColumns = optimalNumColumns
	local maxBarsPerColumn = ceil(totalTeams / numColumns)
	local columnWidth = minimapSizeX / numColumns
	local columnPadding = 4
	local barWidth = columnWidth - (columnPadding * 2)
	
	return {
		numColumns = numColumns,
		maxBarsPerColumn = maxBarsPerColumn,
		columnWidth = columnWidth,
		barHeight = BAR_HEIGHT,
		barWidth = barWidth
	}
end


local function getPlayerTeamData()
	local threshold = getCachedRuleParam(THRESHOLD_RULES_KEY)
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
	local minimapPosX, minimapPosY, minimapSizeX = getCachedMinimapGeometry()
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local currentMaxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
	local isThresholdFrozen = (spGetGameRulesParam(FREEZE_DELAY_KEY) or 0) > currentGameTime
	
	lastThreshold = threshold
	lastMaxThreshold = currentMaxThreshold
	lastIsThresholdFrozen = isThresholdFrozen
	lastHealthbarWidth = healthbarWidth
	lastMinimapDimensions = {minimapPosX, minimapPosY, minimapSizeX}
	lastAmSpectating = amSpectating
	lastSelectedAllyTeamID = selectedAllyTeamID
	maxThreshold = currentMaxThreshold
end

local function needsDisplayListUpdate()
	local currentGameTime, freezeExpirationTime, isThresholdFrozen = getFreezeStatusInformation()
	local scoreAllyID = amSpectating and selectedAllyTeamID or myAllyID
	local minimapPosX, minimapPosY, minimapSizeX = getCachedMinimapGeometry()
	local threshold = getCachedRuleParam(THRESHOLD_RULES_KEY)
	local currentMaxThreshold = getCachedRuleParam(MAX_THRESHOLD_RULES_KEY)
	
	if scoreAllyID == gaiaAllyTeamID then 
		return false
	end
	
	if not fontCache.initialized then
		return true
	end

	if not amSpectating then
		local teamData = getPlayerTeamData()
		
		if lastScore ~= teamData.score or lastDifference ~= teamData.difference or 
		   lastThreshold ~= threshold or lastMaxThreshold ~= currentMaxThreshold or
		   lastIsThresholdFrozen ~= isThresholdFrozen or
		   lastHealthbarWidth ~= healthbarWidth or 
		   lastMinimapDimensions[1] ~= minimapPosX or
		   lastMinimapDimensions[2] ~= minimapPosY or
		   lastMinimapDimensions[3] ~= minimapSizeX or
		   lastAmSpectating ~= amSpectating or
		   (teamData.teamID and lastTeamRanks[teamData.teamID] ~= teamData.rank) then
			
			lastScore = teamData.score
			lastDifference = teamData.difference
			lastThreshold = threshold
			lastMaxThreshold = currentMaxThreshold
			lastIsThresholdFrozen = isThresholdFrozen
			lastHealthbarWidth = healthbarWidth
			lastMinimapDimensions = {minimapPosX, minimapPosY, minimapSizeX}
			lastAmSpectating = amSpectating
			if teamData.teamID then
				lastTeamRanks[teamData.teamID] = teamData.rank
			end
			return true
		end
		return false
	end

	if lastAmSpectating ~= amSpectating or lastSelectedAllyTeamID ~= selectedAllyTeamID then
		return true
	end
	return false
end

local function cleanupAllCountdowns()
	return cleanupCountdowns()
end

local function updateLayoutCache()
	local currentTime = os.clock()
	if currentTime - lastLayoutUpdate < LAYOUT_UPDATE_THRESHOLD and layoutCache.initialized then
		return false
	end
	
	local vsx, vsy = spGetViewGeometry()
	local minimapPosX, minimapPosY, minimapSizeX = getCachedMinimapGeometry()
	
	local needsUpdate = not layoutCache.initialized or
		layoutCache.minimapDimensions[1] ~= minimapPosX or
		layoutCache.minimapDimensions[2] ~= minimapPosY or
		layoutCache.minimapDimensions[3] ~= minimapSizeX or
		layoutCache.lastViewportSize[1] ~= vsx or
		layoutCache.lastViewportSize[2] ~= vsy
	
	if needsUpdate then
		layoutCache.minimapDimensions = {minimapPosX, minimapPosY, minimapSizeX}
		layoutCache.lastViewportSize = {vsx, vsy}
		
		layoutCache.playerBarBounds = calculateBarPosition(1, false)
		
		if amSpectating then
			local aliveAllyTeams = getAliveAllyTeams()
			layoutCache.spectatorLayout = calculateSpectatorLayoutParameters(#aliveAllyTeams, minimapSizeX)
		end

		-- Clear position cache
		positionCache.playerBar = nil
		positionCache.spectatorBars = {}
		positionCache.countdownPositions = {}
		positionCache.textPositions = {}

		cleanupAllCountdowns()
		
		layoutCache.initialized = true
		lastLayoutUpdate = currentTime
		forceDisplayListUpdate()
		return true
	end
	
	return false
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

local function getPlayerBarPositionsCached()
	if not positionCache.playerBar then
		initializeFontCache()
		
		local bounds = layoutCache.playerBarBounds or calculateBarPosition(1, false)
		
		positionCache.playerBar = {
			scorebarLeft = bounds.scorebarLeft,
			scorebarRight = bounds.scorebarRight,
			scorebarTop = bounds.scorebarTop,
			scorebarBottom = bounds.scorebarBottom,
			textY = bounds.scorebarBottom + (bounds.scorebarTop - bounds.scorebarBottom - fontCache.fontSize) / 2,
			innerRight = bounds.scorebarRight - 3 - fontCache.paddingX
		}
	end
	return positionCache.playerBar
end

local function getSpectatorBarPositionsCached(index)
	if not positionCache.spectatorBars[index] then
		initializeFontCache()
		
		local bounds = calculateBarPosition(index, true)
		local barHeight = bounds.scorebarTop - bounds.scorebarBottom
		local scaledFontSize = barHeight * 1.1
		
		positionCache.spectatorBars[index] = {
			scorebarLeft = bounds.scorebarLeft,
			scorebarRight = bounds.scorebarRight,
			scorebarTop = bounds.scorebarTop,
			scorebarBottom = bounds.scorebarBottom,
			textY = bounds.scorebarBottom + (barHeight - scaledFontSize) / 2,
			innerRight = bounds.scorebarRight - 3 - fontCache.paddingX,
			fontSize = scaledFontSize
		}
	end
	return positionCache.spectatorBars[index]
end

local function calculateCountdownPosition(allyTeamID, isSpectator, barIndex)
	local minimapPosX, minimapPosY, minimapSizeX = getCachedMinimapGeometry()
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	
	if isSpectator then
		if not barIndex then
			local aliveAllyTeams = getAliveAllyTeams()
			local allyTeamScores = getSpectatorAllyTeamData()
			
			for i, allyTeamData in ipairs(allyTeamScores) do
				if allyTeamData.allyTeamID == allyTeamID then
					barIndex = i
					break
				end
			end
		end
		
		if barIndex then
			local bounds = calculateBarPosition(barIndex, true)
			local barWidthForCalc = bounds.scorebarRight - bounds.scorebarLeft
			local thresholdX = bounds.scorebarLeft + (threshold / maxThreshold) * barWidthForCalc
			local skullOffset = (1 / maxThreshold) * barWidthForCalc
			local countdownX = thresholdX - skullOffset
			local countdownY = bounds.scorebarBottom + (bounds.scorebarTop - bounds.scorebarBottom) / 2
			
			return countdownX, countdownY
		end
	else
		local bounds = layoutCache.playerBarBounds or calculateBarPosition(1, false)
		local barWidth = bounds.scorebarRight - bounds.scorebarLeft
		local thresholdX = bounds.scorebarLeft + (threshold / maxThreshold) * barWidth
		local skullOffset = (1 / maxThreshold) * barWidth
		local countdownX = thresholdX - skullOffset
		local countdownY = bounds.scorebarBottom + (bounds.scorebarTop - bounds.scorebarBottom) / 2
		
		return countdownX, countdownY
	end
	
	return minimapPosX + minimapSizeX / 2, minimapPosY - MINIMAP_GAP - 20
end

local function calculateSpectatorCountdownPosition(allyTeamID, minimapPosX, minimapPosY, minimapSizeX)
	return calculateCountdownPosition(allyTeamID, true)
end

local function cleanupCountdownsForAllyTeam(allyTeamID)
	return cleanupCountdowns(allyTeamID)
end

local function manageCountdownUpdates()
	local currentGameTime = spGetGameSeconds()
	local updatedCountdowns = false
	
	if amSpectating then
		local activeAllyTeams = {}
		
		for allyTeamID, allyDefeatTime in pairs(allyTeamDefeatTimes) do
			if allyDefeatTime and allyDefeatTime > 0 and currentGameTime and allyDefeatTime > currentGameTime then
				local timeRemaining = ceil(allyDefeatTime - currentGameTime)
				if timeRemaining >= 0 then
					activeAllyTeams[allyTeamID] = timeRemaining
				end
			end
		end
		
		for allyTeamID in pairs(lastCountdownValues) do
			if not activeAllyTeams[allyTeamID] then
				if cleanupCountdownsForAllyTeam(allyTeamID) then
					updatedCountdowns = true
				end
			end
		end
		
		for allyTeamID, timeRemaining in pairs(activeAllyTeams) do
			if lastCountdownValues[allyTeamID] ~= timeRemaining then
				cleanupCountdownsForAllyTeam(allyTeamID)
				lastCountdownValues[allyTeamID] = timeRemaining
				updatedCountdowns = true
			end
		end
	else
		if defeatTime and defeatTime > 0 and currentGameTime and defeatTime > currentGameTime then
			local timeRemaining = ceil(defeatTime - currentGameTime)
			if timeRemaining >= 0 then
				if lastCountdownValues[myAllyID] ~= timeRemaining then
					cleanupCountdownsForAllyTeam(myAllyID)
					lastCountdownValues[myAllyID] = timeRemaining
					updatedCountdowns = true
				end
			end
		else
			if lastCountdownValues[myAllyID] then
				if cleanupCountdownsForAllyTeam(myAllyID) then
					updatedCountdowns = true
				end
			end
		end
	end
	
	return updatedCountdowns
end

local function createOptimizedHaloDisplayList()
	if haloDisplayList then
		glDeleteList(haloDisplayList)
	end
	
	haloDisplayList = glCreateList(function()
		if not amSpectating or selectedAllyTeamID == gaiaAllyTeamID or selectedAllyTeamID == -1 then
			return
		end
		
		setOptimizedBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		
		local allyTeamScores = getSpectatorAllyTeamData()
		local targetBarIndex = nil
		
		for i, allyTeamData in ipairs(allyTeamScores) do
			if allyTeamData.allyTeamID == selectedAllyTeamID then
				targetBarIndex = i
				break
			end
		end
		
		if targetBarIndex then
			local pos = getSpectatorBarPositionsCached(targetBarIndex)
			
			local haloLeft = pos.scorebarLeft - HALO_EXTENSION
			local haloRight = pos.scorebarRight + HALO_EXTENSION
			local haloTop = pos.scorebarTop + HALO_EXTENSION
			local haloBottom = pos.scorebarBottom - HALO_EXTENSION
			
			local fadeSteps = 4
			local alphaStep = HALO_MAX_ALPHA / fadeSteps
			
			for i = fadeSteps, 1, -1 do
				local currentAlpha = alphaStep * (fadeSteps - i + 1)
				local offset = (i - 1) * (HALO_EXTENSION / fadeSteps)
				
				local currentLeft = pos.scorebarLeft - offset
				local currentRight = pos.scorebarRight + offset
				local currentTop = pos.scorebarTop + offset
				local currentBottom = pos.scorebarBottom - offset
				
				currentLeft = max(haloLeft, currentLeft)
				currentRight = min(haloRight, currentRight)
				currentTop = min(haloTop, currentTop)
				currentBottom = max(haloBottom, currentBottom)
				
				setOptimizedColor(1, 1, 1, currentAlpha)
				
				if currentTop > pos.scorebarTop then
					glRect(currentLeft, pos.scorebarTop, currentRight, currentTop)
				end
				
				if currentBottom < pos.scorebarBottom then
					glRect(currentLeft, currentBottom, currentRight, pos.scorebarBottom)
				end
				
				if currentLeft < pos.scorebarLeft then
					glRect(currentLeft, currentBottom, pos.scorebarLeft, currentTop)
				end
				
				if currentRight > pos.scorebarRight then
					glRect(pos.scorebarRight, currentBottom, currentRight, currentTop)
				end
			end
		end
	end)
end

local function createOptimizedBackgroundDisplayList()
	if backgroundDisplayList then
		glDeleteList(backgroundDisplayList)
	end
	
	backgroundDisplayList = glCreateList(function()
		setOptimizedBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		
		if amSpectating then
			local allyTeamScores = getSpectatorAllyTeamData()
			for i, allyTeamData in ipairs(allyTeamScores) do
				if allyTeamData and allyTeamData.allyTeamID then
					local pos = getSpectatorBarPositionsCached(i)
					
					local tintedBg = getCachedTintedColor(COLOR_BACKGROUND, allyTeamData.teamColor, 0.15, "bg_" .. allyTeamData.allyTeamID)
					local tintedBorder = getCachedTintedColor(COLOR_BORDER, allyTeamData.teamColor, 0.1, "border_" .. allyTeamData.allyTeamID)

					setOptimizedColor(tintedBorder[1], tintedBorder[2], tintedBorder[3], tintedBorder[4])
					glRect(pos.scorebarLeft - BORDER_WIDTH, pos.scorebarBottom - BORDER_WIDTH, 
						   pos.scorebarRight + BORDER_WIDTH, pos.scorebarTop + BORDER_WIDTH)
					
					setOptimizedColor(tintedBg[1], tintedBg[2], tintedBg[3], tintedBg[4])
					glRect(pos.scorebarLeft, pos.scorebarBottom, pos.scorebarRight, pos.scorebarTop)
				end
			end
		else
			local teamData = getPlayerTeamData()
			
			local pos
			if teamData.teamID then
				pos = getPlayerBarPositionsCached()
			else
				pos = calculateBarPosition(1, false)
			end
			
			local barColor = (teamData and teamData.barColor) or COLOR_GREEN
			local tintedBg = getCachedTintedColor(COLOR_BACKGROUND, barColor, 0.15, "bg_player")
			local tintedBorder = getCachedTintedColor(COLOR_BORDER, barColor, 0.1, "border_player")
			
			setOptimizedColor(tintedBorder[1], tintedBorder[2], tintedBorder[3], tintedBorder[4])
			glRect(pos.scorebarLeft - BORDER_WIDTH, pos.scorebarBottom - BORDER_WIDTH, 
				   pos.scorebarRight + BORDER_WIDTH, pos.scorebarTop + BORDER_WIDTH)
			
			setOptimizedColor(tintedBg[1], tintedBg[2], tintedBg[3], tintedBg[4])
			glRect(pos.scorebarLeft, pos.scorebarBottom, pos.scorebarRight, pos.scorebarTop)
		end
	end)
end

local function createOptimizedStaticDisplayList()
	if staticDisplayList then
		glDeleteList(staticDisplayList)
	end
	
	staticDisplayList = glCreateList(function()
		if not amSpectating then
			local teamData = getPlayerTeamData()
			if teamData.rank and teamData.teamID then
				local pos = getPlayerBarPositionsCached()
				
				local rankText = spI18N('ui.territorialDomination.rank', {rank = teamData.rank})
				local textWidth = glGetTextWidth(rankText) * fontCache.fontSize
				local textHeight = fontCache.fontSize
				
				local paddingX = textWidth * 0.2
				local paddingY = textHeight * 0.2
				local rankBoxWidth = textWidth + (paddingX * 1)
				local rankBoxHeight = textHeight + (paddingY * 1)
				
				local rankX = pos.scorebarLeft
				local rankY = pos.scorebarBottom - rankBoxHeight
				
				setOptimizedColor(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4])
				glRect(rankX - BORDER_WIDTH, rankY - BORDER_WIDTH, 
					   rankX + rankBoxWidth + BORDER_WIDTH, rankY + rankBoxHeight + BORDER_WIDTH)
				
				setOptimizedColor(COLOR_BACKGROUND[1], COLOR_BACKGROUND[2], COLOR_BACKGROUND[3], COLOR_BACKGROUND[4])
				glRect(rankX, rankY, rankX + rankBoxWidth, rankY + rankBoxHeight)
			end
		end
	end)
end

local function createOptimizedDynamicDisplayList()
	if dynamicDisplayList then
		glDeleteList(dynamicDisplayList)
	end
	
	dynamicDisplayList = glCreateList(function()
		local threshold = getCachedRuleParam(THRESHOLD_RULES_KEY)
		local currentGameTime, freezeExpirationTime, isThresholdFrozen = getFreezeStatusInformation()

		if amSpectating then
			local allyTeamScores = getSpectatorAllyTeamData()
			for i, allyTeamData in ipairs(allyTeamScores) do
				local pos = getSpectatorBarPositionsCached(i)
				
				drawOptimizedHealthBar(pos.scorebarLeft, pos.scorebarRight, pos.scorebarBottom, pos.scorebarTop, 
									   allyTeamData.score, threshold, allyTeamData.teamColor, isThresholdFrozen)
				
				local difference = allyTeamData.score - threshold
				local differenceVerticalOffset = 3
				drawDifferenceText(pos.innerRight, pos.textY, difference, pos.fontSize, "r", COLOR_WHITE, differenceVerticalOffset)
			end
		else
			local teamData = getPlayerTeamData()
			local pos
			if teamData.teamID then
				pos = getPlayerBarPositionsCached()
				
				drawOptimizedHealthBar(pos.scorebarLeft, pos.scorebarRight, pos.scorebarBottom, pos.scorebarTop, 
									   teamData.score, teamData.threshold, teamData.barColor, isThresholdFrozen)
				drawDifferenceText(pos.innerRight, pos.textY, teamData.difference, fontCache.fontSize * 1.20, "r", COLOR_WHITE, 1)
				
				if teamData.rank then
					local rankText = spI18N('ui.territorialDomination.rank', {rank = teamData.rank})
					local textWidth = glGetTextWidth(rankText) * fontCache.fontSize
					local textHeight = fontCache.fontSize + 2
					
					local paddingX = textWidth * 0.2
					local paddingY = textHeight * 0.2
					local rankBoxWidth = textWidth + (paddingX * 1)
					local rankBoxHeight = textHeight + (paddingY * 1)
					
					local rankX = pos.scorebarLeft
					local rankY = pos.scorebarBottom - rankBoxHeight - textHeight  * 0.2
					
					local centerX = rankX + rankBoxWidth / 2
					local centerY = rankY + rankBoxHeight / 2
					
					drawTextWithOutline(rankText, centerX, centerY, fontCache.fontSize, "c", COLOR_WHITE)
				end
			else
				pos = calculateBarPosition(1, false)
				pos.textY = pos.scorebarBottom + (pos.scorebarTop - pos.scorebarBottom) / 2
				pos.innerRight = pos.scorebarRight - 10
				
				drawOptimizedHealthBar(pos.scorebarLeft, pos.scorebarRight, pos.scorebarBottom, pos.scorebarTop, 
									   0, threshold, COLOR_GREEN, isThresholdFrozen)
				
				drawDifferenceText(pos.innerRight, pos.textY, 0, fontCache.fontSize * 1.20, "r", COLOR_WHITE, 1)
			end
		end
	end)
end

local function createOptimizedCountdownDisplayList(timeRemaining, allyTeamID)
	allyTeamID = allyTeamID or myAllyID
	
	local bucketedTime = ceil(timeRemaining)
	local cacheKey = allyTeamID .. "_" .. bucketedTime
	
	if allyTeamCountdownDisplayLists[cacheKey] then
		return allyTeamCountdownDisplayLists[cacheKey]
	end
	
	local keysToDelete = {}
	for key, displayList in pairs(allyTeamCountdownDisplayLists) do
		if key:sub(1, #tostring(allyTeamID) + 1) == allyTeamID .. "_" and key ~= cacheKey then
			local keyTime = tonumber(key:sub(#tostring(allyTeamID) + 2))
			if keyTime and (bucketedTime - keyTime > 3 or keyTime - bucketedTime > 1) then
				table.insert(keysToDelete, key)
			end
		end
	end
		
	for _, key in ipairs(keysToDelete) do
		glDeleteList(allyTeamCountdownDisplayLists[key])
		allyTeamCountdownDisplayLists[key] = nil
	end
	
	allyTeamCountdownDisplayLists[cacheKey] = glCreateList(function()
		local countdownColor = COUNTDOWN_COLOR
		local countdownX, countdownY = calculateCountdownPosition(allyTeamID, amSpectating)
		
		if not countdownX then return end
		
		initializeFontCache()
		
		local countdownFontSize = fontCache.fontSize * COUNTDOWN_FONT_SIZE_MULTIPLIER
		if amSpectating and layoutCache.spectatorLayout then
			local scaleFactor = layoutCache.spectatorLayout.barHeight / BAR_HEIGHT
			countdownFontSize = max(10, countdownFontSize * scaleFactor)
		end
		
		local text = format("%d", timeRemaining)
		local adjustedCountdownY = countdownY - (countdownFontSize * 0.25)
		
		drawCountdownText(countdownX, adjustedCountdownY, text, countdownFontSize, countdownColor)
	end)
	
	return allyTeamCountdownDisplayLists[cacheKey]
end

local function updateScoreDisplayList()
	local scoreAllyID = amSpectating and selectedAllyTeamID or myAllyID
	
	if scoreAllyID == gaiaAllyTeamID then 
		if displayList then
			glDeleteList(displayList)
			displayList = nil
		end
		return 
	end
	
	initializeFontCache()

	local minimapPosX, minimapPosY, minimapSizeX = getCachedMinimapGeometry()
	healthbarWidth = minimapSizeX - ICON_SIZE

	local currentTime = os.clock()
	local layoutChanged = updateLayoutCache()
	
	needsBackgroundUpdate = needsBackgroundUpdate or 
							not backgroundDisplayList or layoutChanged
	
	needsHaloUpdate = needsHaloUpdate or 
					  not haloDisplayList or layoutChanged or
					  (amSpectating and lastSelectedAllyTeamID ~= selectedAllyTeamID)
	
	needsStaticUpdate = needsStaticUpdate or 
						not staticDisplayList or layoutChanged
	
	needsDynamicUpdate = needsDynamicUpdate or 
						 not dynamicDisplayList or 
						 (currentTime - lastDynamicUpdate > DYNAMIC_UPDATE_THRESHOLD) or
						 needsDisplayListUpdate()
	
	if needsBackgroundUpdate then
		createOptimizedHaloDisplayList()
		createOptimizedBackgroundDisplayList()
		needsBackgroundUpdate = false
	end
	
	if needsHaloUpdate then
		createOptimizedHaloDisplayList()
		needsHaloUpdate = false
	end
	
	if needsStaticUpdate then
		createOptimizedStaticDisplayList()
		needsStaticUpdate = false
	end
	
	if needsDynamicUpdate then
		createOptimizedDynamicDisplayList()
		needsDynamicUpdate = false
		lastDynamicUpdate = currentTime
		updateTrackingVariables()
	end
	
	if layoutChanged or not displayList then
		if displayList then
			glDeleteList(displayList)
		end
		
		displayList = glCreateList(function()
			if haloDisplayList then
				glCallList(haloDisplayList)
			end
			if backgroundDisplayList then
				glCallList(backgroundDisplayList)
			end
			if staticDisplayList then
				glCallList(staticDisplayList)
			end
			if dynamicDisplayList then
				glCallList(dynamicDisplayList)
			end
		end)
	end

	needsBackgroundUpdate = false
	needsHaloUpdate = false
	needsStaticUpdate = false
	needsDynamicUpdate = false
end

local function cleanupOptimizedDisplayLists()
	displayList = cleanupDisplayList(displayList)
	staticDisplayList = cleanupDisplayList(staticDisplayList)
	dynamicDisplayList = cleanupDisplayList(dynamicDisplayList)
	backgroundDisplayList = cleanupDisplayList(backgroundDisplayList)
	haloDisplayList = cleanupDisplayList(haloDisplayList)
	timerWarningDisplayList = cleanupDisplayList(timerWarningDisplayList)
	
	cleanupAllCountdowns()
	
	layoutCache.initialized = false
	positionCache.playerBar = nil
	positionCache.spectatorBars = {}
	colorCache = {teamColors = {}, barColors = {}, tintedColors = {}, gradientColors = {}}
	drawStateCache = {lastBlendMode = nil, lastTexture = nil, lastColor = {-1, -1, -1, -1}}
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
	
	local countdownsToRender = {}
	
	if amSpectating then
		for allyTeamID, allyDefeatTime in pairs(allyTeamDefeatTimes) do
			if allyDefeatTime and allyDefeatTime > 0 and gameSeconds and allyDefeatTime > gameSeconds then
				local timeRemaining = ceil(allyDefeatTime - gameSeconds)
				if timeRemaining >= 0 then
					local bucketedTime = ceil(timeRemaining)
					local cacheKey = allyTeamID .. "_" .. bucketedTime
					countdownsToRender[cacheKey] = {allyTeamID = allyTeamID, timeRemaining = timeRemaining}
				end
			end
		end
		
		for cacheKey, countdownData in pairs(countdownsToRender) do
			if not allyTeamCountdownDisplayLists[cacheKey] then
				createOptimizedCountdownDisplayList(countdownData.timeRemaining, countdownData.allyTeamID)
			end
			
			local displayList = allyTeamCountdownDisplayLists[cacheKey]
			if displayList then
				glCallList(displayList)
			end
		end
	else
		if defeatTime and defeatTime > 0 and gameSeconds and defeatTime > gameSeconds then
			local timeRemaining = ceil(defeatTime - gameSeconds)
			if timeRemaining >= 0 then
				local bucketedTime = ceil(timeRemaining)
				local cacheKey = myAllyID .. "_" .. bucketedTime
				
				if not allyTeamCountdownDisplayLists[cacheKey] then
					createOptimizedCountdownDisplayList(timeRemaining, myAllyID)
				end
				
				local displayList = allyTeamCountdownDisplayLists[cacheKey]
				if displayList then
					glCallList(displayList)
				end
			end
		end
	end
	
	if currentGameTime < timerWarningEndTime and timerWarningDisplayList then
		glCallList(timerWarningDisplayList)
	end
end

function widget:PlayerChanged(playerID)
	if amSpectating then
		if spGetSelectedUnitsCount() > 0 then
			local unitID = spGetSelectedUnits()[1]
			local unitTeam = spGetUnitTeam(unitID)
			if unitTeam then
				local newSelectedAllyTeamID = select(6, spGetTeamInfo(unitTeam)) or myAllyID
				if newSelectedAllyTeamID ~= selectedAllyTeamID then
					selectedAllyTeamID = newSelectedAllyTeamID
					forceDisplayListUpdate()
					updateScoreDisplayList()
				end
				return
			end
		end
		if selectedAllyTeamID ~= myAllyID then
			selectedAllyTeamID = myAllyID
			forceDisplayListUpdate()
			updateScoreDisplayList()
		end
	end
end

function widget:GameFrame(frame)
	if frame % DEFEAT_CHECK_INTERVAL == AFTER_GADGET_TIMER_UPDATE_MODULO + 2 then
		local dataChanged = false
		local teamStatusChanged = false
		
		if amSpectating then
			local allyTeamList = spGetAllyTeamList()
			for _, allyTeamID in ipairs(allyTeamList) do
				if allyTeamID ~= gaiaAllyTeamID then
					local isCurrentlyAlive = isAllyTeamAlive(allyTeamID)
					local wasAlive = lastAllyTeamScores[allyTeamID] ~= nil
					
					if isCurrentlyAlive ~= wasAlive then
						teamStatusChanged = true
					end
					
					if isCurrentlyAlive then
						local allyDefeatTime = 0
						for _, teamID in ipairs(spGetTeamList(allyTeamID)) do
							local _, _, isDead = spGetTeamInfo(teamID)
							if not isDead then
								allyDefeatTime = spGetTeamRulesParam(teamID, "defeatTime") or 0
								break
							end
						end
						if allyTeamDefeatTimes[allyTeamID] ~= allyDefeatTime then
							allyTeamDefeatTimes[allyTeamID] = allyDefeatTime
							dataChanged = true
						end
					else
						if allyTeamDefeatTimes[allyTeamID] then
							allyTeamDefeatTimes[allyTeamID] = nil
							dataChanged = true
						end
					end
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
					dataChanged = true
				end
			else
				if defeatTime ~= 0 then
					defeatTime = 0
					loopSoundEndTime = 0
					soundQueue = nil
					soundIndex = 1
					dataChanged = true
				end
			end
		end
		
		local rankChanged = false
		
		local allyTeamList = amSpectating and spGetAllyTeamList() or {myAllyID}
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
		
		if teamStatusChanged then
			if amSpectating then
				local allyTeamList = spGetAllyTeamList()
				for _, allyTeamID in ipairs(allyTeamList) do
					if allyTeamID ~= gaiaAllyTeamID and not isAllyTeamAlive(allyTeamID) then
						cleanupCountdownsForAllyTeam(allyTeamID)
					end
				end
			else
				local myTeamID = Spring.GetMyTeamID()
				local _, _, isDead = spGetTeamInfo(myTeamID)
				if isDead then
					cleanupCountdownsForAllyTeam(myAllyID)
				end
			end
			
			forceDisplayListUpdate()
		end
		
		if rankChanged then
			needsStaticUpdate = true
			needsDynamicUpdate = true
		end
		
		if dataChanged or rankChanged or teamStatusChanged then
			lastUpdateTime = 0  -- Force update on next frame
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

function widget:Initialize()
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	selectedAllyTeamID = myAllyID
	gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID()))
	
	gameSeconds = spGetGameSeconds() or 0
	defeatTime = 0
	
	initializeFontCache()
	updateLayoutCache()
	updateRuleParamCache()
	updateTrackingVariables()
	
	if not amSpectating then
		local teamData = getPlayerTeamData()
		if teamData.teamID then
			getPlayerBarPositionsCached()
			
			getCachedTeamColor(teamData.teamID)
			
			lastDifference = teamData.difference
			if teamData.teamID then
				lastTeamRanks[teamData.teamID] = teamData.rank
			end
		else
			lastDifference = 0
		end
	end
	
	needsHaloUpdate = true
	needsBackgroundUpdate = true
	needsStaticUpdate = true
	needsDynamicUpdate = true
	
	updateScoreDisplayList()
	
	local allUnits = spGetAllUnits()
	
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
	local newAmSpectating = spGetSpectatingState()
	local newMyAllyID = spGetMyAllyTeamID()
	
	local gameStartTime = spGetGameSeconds()
	if gameStartTime < 5 and not displayList then
		forceDisplayListUpdate()
		updateScoreDisplayList()
	end
	
	if newAmSpectating ~= amSpectating or newMyAllyID ~= myAllyID then
		amSpectating = newAmSpectating
		myAllyID = newMyAllyID
		positionCache.playerBar = nil
		positionCache.spectatorBars = {}
		layoutCache.initialized = false
		
		cleanupAllCountdowns()
		forceDisplayListUpdate()
		updateScoreDisplayList()
	end
	
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
		
		if next(allyTeamCountdownDisplayLists) then
			cleanupAllCountdowns()
		end
	end
	
	currentTime = os.clock()

	local needsUpdate = false
	local forceUpdate = false
	
	if currentTime - lastLayoutUpdate > LAYOUT_UPDATE_THRESHOLD then
		needsUpdate = updateLayoutCache() or needsUpdate
	end
	
	if isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS then
		local blinkPhase = (currentTime % BLINK_INTERVAL) / BLINK_INTERVAL
		local currentBlinkState = blinkPhase < 0.33
		if isSkullFaded ~= currentBlinkState then
			needsDynamicUpdate = true
			needsUpdate = true
		end
	end
	
	if currentTime - lastDynamicUpdate > DYNAMIC_UPDATE_THRESHOLD then
		if needsDisplayListUpdate() then
			needsDynamicUpdate = true
			needsUpdate = true
		end
	end
	
	if currentTime - lastUpdateTime > UPDATE_FREQUENCY then
		lastUpdateTime = currentTime
		if currentTime - lastDynamicUpdate > UPDATE_FREQUENCY then
			forceUpdate = true
		end
	end
	
	if not isThresholdFrozen then
		manageCountdownUpdates()
	end
	
	if needsUpdate or forceUpdate then
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

function widget:Shutdown()
	cleanupOptimizedDisplayLists()
end