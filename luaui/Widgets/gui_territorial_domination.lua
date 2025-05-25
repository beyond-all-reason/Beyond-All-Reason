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
local lastTimerWarningMessages = nil

local lastThreshold = -1
local lastMaxThreshold = -1
local lastIsThresholdFrozen = false
local lastFreezeExpirationTime = -1
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

local backgroundColor = COLOR_BACKGROUND
local borderColor = COLOR_BORDER

-- Performance optimization: Add comprehensive caching and multi-layered display lists
local staticDisplayList = nil
local dynamicDisplayList = nil
local backgroundDisplayList = nil
local countdownStaticDisplayList = nil

-- Enhanced caching structures
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
	gradientColors = {}  -- Cache for gradient color interpolations
}

local drawStateCache = {
	lastBlendMode = nil,
	lastTexture = nil,
	lastColor = {-1, -1, -1, -1}
}

-- Gradient color definitions similar to healthbars GL4
local function createBarGradientColors(baseColor)
	-- Create darker and lighter versions of the base color for gradient effect
	local darkenFactor = 0.6  -- Make bottom darker
	local lightenFactor = 1.2  -- Make top brighter
	
	local minColor = {
		baseColor[1] * darkenFactor,
		baseColor[2] * darkenFactor, 
		baseColor[3] * darkenFactor,
		baseColor[4]
	}
	
	local maxColor = {
		math.min(1.0, baseColor[1] * lightenFactor),
		math.min(1.0, baseColor[2] * lightenFactor),
		math.min(1.0, baseColor[3] * lightenFactor),
		baseColor[4]
	}
	
	return minColor, maxColor
end

-- Optimization flags (replace bitwise operations with boolean flags for Lua 5.1 compatibility)
local needsBackgroundUpdate = false
local needsStaticUpdate = false
local needsDynamicUpdate = false
local needsCountdownUpdate = false

local LAYOUT_UPDATE_THRESHOLD = 2.0  -- Reduce layout update frequency from 0.5s to 2s
local DYNAMIC_UPDATE_THRESHOLD = 0.2   -- Reduce dynamic updates from 30 FPS to 5 FPS
local lastLayoutUpdate = 0
local lastDynamicUpdate = 0

-- Cache expensive rule parameter lookups
local ruleParamCache = {
	threshold = 0,
	maxThreshold = 256,
	freezeDelay = 0,
	lastUpdate = 0,
	updateInterval = 0.5  -- Reduce from 0.1s to 0.5s - rule params don't change that frequently
}

-- ===== HELPER FUNCTIONS (must be defined before widget functions) =====

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


local function updateRuleParamCache()
	local currentTime = os.clock()
	if currentTime - ruleParamCache.lastUpdate < ruleParamCache.updateInterval then
		return -- Use cached values
	end
	
	ruleParamCache.threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	ruleParamCache.maxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
	ruleParamCache.freezeDelay = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	ruleParamCache.lastUpdate = currentTime
	
	-- Update global maxThreshold for compatibility
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

local function interpolateColor(minColor, maxColor, factor)
	-- Clamp factor between 0 and 1
	factor = max(0, min(1, factor))
	
	return {
		minColor[1] + (maxColor[1] - minColor[1]) * factor,
		minColor[2] + (maxColor[2] - minColor[2]) * factor,
		minColor[3] + (maxColor[3] - minColor[3]) * factor,
		minColor[4] + (maxColor[4] - minColor[4]) * factor
	}
end

local function getCachedGradientColors(baseColor)
	-- Create cache key based on base color
	local colorKey = string.format("%.2f_%.2f_%.2f", baseColor[1], baseColor[2], baseColor[3])
	
	if not colorCache.gradientColors[colorKey] then
		local minColor, maxColor = createBarGradientColors(baseColor)
		colorCache.gradientColors[colorKey] = {minColor, maxColor}
	end
	
	return colorCache.gradientColors[colorKey][1], colorCache.gradientColors[colorKey][2]
end

local function getBarGradientType(difference)
	-- This function is no longer needed with the new approach
	-- Keeping it for compatibility but it's not used
	return "unused"
end

local function drawTextWithOutline(text, x, y, fontSize, alignment, color, outlineOffset, outlineAlpha)
	local offset = outlineOffset or TEXT_OUTLINE_OFFSET
	local alpha = outlineAlpha or TEXT_OUTLINE_ALPHA
	
	-- Simplified 2-pass outline for better performance (instead of 4-pass)
	setOptimizedColor(0, 0, 0, alpha)
	glText(text, x - offset, y, fontSize, alignment)
	glText(text, x + offset, y, fontSize, alignment)
	
	-- Draw main text
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
	setOptimizedColor(color[1], color[2], color[3], color[4])
	drawTextWithOutline(text, x, y, fontSize, "c", color)
end

local function drawOptimizedHealthBar(scorebarLeft, scorebarRight, scorebarBottom, scorebarTop, score, threshold, barColor, isThresholdFrozen)
	-- POSITION CALCULATIONS (restored from original)
	local fullHealthbarLeft = scorebarLeft
	local fullHealthbarRight = scorebarRight
	local barWidth = scorebarRight - scorebarLeft

	local originalRight = scorebarRight
	local exceedsMaxThreshold = score > maxThreshold

	-- Calculate the actual score position without exceeding the bar width
	local healthbarScoreRight = scorebarLeft + min(score / maxThreshold, 1) * barWidth

	-- If score exceeds max, we won't extend the bar beyond its normal width
	if exceedsMaxThreshold then
		scorebarRight = originalRight
	end

	local thresholdX = scorebarLeft + (threshold / maxThreshold) * barWidth
	local skullOffset = (1 / maxThreshold) * barWidth
	local skullX = thresholdX - skullOffset

	local borderSize = 3
	local fillPaddingLeft = fullHealthbarLeft + borderSize
	local fillPaddingRight = healthbarScoreRight - borderSize
	local fillPaddingTop = scorebarTop
	local fillPaddingBottom = scorebarBottom + borderSize

	-- Calculate line position (restored from original)
	local linePos = healthbarScoreRight
	if exceedsMaxThreshold then
		-- Calculate how much the bar exceeds the max threshold
		local overfillRatio = (score - maxThreshold) / maxThreshold
		-- Cap at 1.0 (100% backfilled)
		overfillRatio = min(overfillRatio, 1)

		-- Calculate where the line should be when backfilling
		local maxWidth = originalRight - borderSize - fillPaddingLeft
		local backfillWidth = maxWidth * overfillRatio
		linePos = originalRight - borderSize - backfillWidth

		-- Make sure the line position doesn't go outside the bar
		linePos = max(fillPaddingLeft, linePos)
	end

	-- COLOR SETUP - don't change bar color when frozen (restored from original)
	local baseColor = barColor
	local topColor = {baseColor[1], baseColor[2], baseColor[3], baseColor[4]}
	local bottomColor = {baseColor[1]*0.7, baseColor[2]*0.7, baseColor[3]*0.7, baseColor[4]}

	-- GRADIENT RENDERING (restored from original)
	setOptimizedBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	if fillPaddingLeft < fillPaddingRight then
		if exceedsMaxThreshold then
			-- Calculate how much the bar exceeds the max threshold
			local overfillRatio = (score - maxThreshold) / maxThreshold
			-- Cap at 1.0 (100% backfilled)
			overfillRatio = min(overfillRatio, 1)

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

		-- HIGHLIGHTS (restored from original)
		local glossHeight = (fillPaddingTop - fillPaddingBottom) * 0.4
		setOptimizedBlending(GL.SRC_ALPHA, GL.ONE)

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

		setOptimizedBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end

	-- SKULL ICON RENDERING (restored from original)
	if threshold >= 1 then
		glPushMatrix()
		local skullY = scorebarBottom + (scorebarTop - scorebarBottom)/2
		glTranslate(skullX, skullY, 0)

		-- Shadow
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

		-- SKULL ALPHA MANAGEMENT (restored from original)
		local skullAlpha = 1.0
		if isThresholdFrozen then
			local currentGameTime = spGetGameSeconds()
			local freezeExpirationTime = getCachedRuleParam(FREEZE_DELAY_KEY)
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

		-- Draw skull (restored from original)
		setOptimizedColor(1, 1, 1, skullAlpha)
		setOptimizedTexture(':n:LuaUI/Images/skull.dds')
		glTexRect(-ICON_SIZE/2, -ICON_SIZE/2, ICON_SIZE/2, ICON_SIZE/2)

		setOptimizedTexture(false)
		glPopMatrix()
	end

	-- SCORE LINE RENDERING (restored from original)
	local lineExtension = 3

	-- Determine line color based on whether the bar is overfilled
	local lineColor = exceedsMaxThreshold and COLOR_WHITE_LINE or COLOR_GREY_LINE

	-- Draw shadow/border for the line
	setOptimizedColor(0, 0, 0, 0.8)
	glRect(linePos - lineWidth - 1, scorebarBottom - lineExtension, 
		   linePos + lineWidth + 1, scorebarTop + lineExtension)

	-- Draw the actual line with the determined color
	setOptimizedColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glRect(linePos - lineWidth/2, scorebarBottom - lineExtension, 
		   linePos + lineWidth/2, scorebarTop + lineExtension)

	return linePos, originalRight, thresholdX, skullX
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
		
		-- Draw warning messages
		setOptimizedColor(COLOR_RED[1], COLOR_RED[2], COLOR_RED[3], 1)
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
	
	-- Calculate optimal number of columns to fit within height constraint
	local optimalNumColumns = totalTeams  -- fallback: one bar per column
	for numColumns = 1, totalTeams do
		local barsPerColumn = ceil(totalTeams / numColumns)
		local totalSpacingHeight = (barsPerColumn - 1) * barSpacing
		local requiredHeight = (barsPerColumn * BAR_HEIGHT) + totalSpacingHeight

		if requiredHeight <= maxDisplayHeight then
			optimalNumColumns = numColumns
			break
		end
	end

	-- Calculate final layout parameters
	local numColumns = optimalNumColumns
	local maxBarsPerColumn = ceil(totalTeams / numColumns)
	local columnWidth = minimapSizeX / numColumns
	
	-- Calculate bar width (leave some padding on sides)
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
	local threshold = getCachedRuleParam(THRESHOLD_RULES_KEY)
	local currentMaxThreshold = getCachedRuleParam(MAX_THRESHOLD_RULES_KEY)
	
	if scoreAllyID == gaiaAllyTeamID then 
		return false
	end
	
	if not fontCache.initialized then
		return true
	end

	-- Simple change detection for player mode (most common case)
	if not amSpectating then
		local teamData = getPlayerTeamData()
		
		if lastScore ~= teamData.score or lastDifference ~= teamData.difference or 
		   lastThreshold ~= threshold or lastMaxThreshold ~= currentMaxThreshold or
		   lastIsThresholdFrozen ~= isThresholdFrozen or
		   lastHealthbarWidth ~= healthbarWidth or 
		   lastMinimapDimensions[1] ~= currentMinimapDimensions[1] or
		   lastMinimapDimensions[2] ~= currentMinimapDimensions[2] or
		   lastMinimapDimensions[3] ~= currentMinimapDimensions[3] or
		   lastAmSpectating ~= amSpectating or
		   (teamData.teamID and lastTeamRanks[teamData.teamID] ~= teamData.rank) then
			
			lastScore = teamData.score
			lastDifference = teamData.difference
			lastThreshold = threshold
			lastMaxThreshold = currentMaxThreshold
			lastIsThresholdFrozen = isThresholdFrozen
			lastHealthbarWidth = healthbarWidth
			lastMinimapDimensions = currentMinimapDimensions
			lastAmSpectating = amSpectating
			if teamData.teamID then
				lastTeamRanks[teamData.teamID] = teamData.rank
			end
			return true
		end
		return false
	end

	-- Spectator mode (less optimized, but used less frequently)
	if lastAmSpectating ~= amSpectating or lastSelectedAllyTeamID ~= selectedAllyTeamID then
		return true
	end
	
	-- For spectator mode, use simplified checking
	return false  -- Reduce spectator update frequency for better performance
end

local function updateLayoutCache()
	local currentTime = os.clock()
	if currentTime - lastLayoutUpdate < LAYOUT_UPDATE_THRESHOLD and layoutCache.initialized then
		return false
	end
	
	local vsx, vsy = spGetViewGeometry()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local currentMinimapDimensions = {minimapPosX, minimapPosY, minimapSizeX}
	local currentViewportSize = {vsx, vsy}
	
	local needsUpdate = not layoutCache.initialized or
		layoutCache.minimapDimensions[1] ~= currentMinimapDimensions[1] or
		layoutCache.minimapDimensions[2] ~= currentMinimapDimensions[2] or
		layoutCache.minimapDimensions[3] ~= currentMinimapDimensions[3] or
		layoutCache.lastViewportSize[1] ~= currentViewportSize[1] or
		layoutCache.lastViewportSize[2] ~= currentViewportSize[2]
	
	if needsUpdate then
		layoutCache.minimapDimensions = currentMinimapDimensions
		layoutCache.lastViewportSize = currentViewportSize
		
		-- Cache player bar bounds - align to left side of minimap
		layoutCache.playerBarBounds = {
			left = minimapPosX + ICON_SIZE/2,
			right = minimapPosX + minimapSizeX - ICON_SIZE/2,
			top = minimapPosY - MINIMAP_GAP,
			bottom = minimapPosY - MINIMAP_GAP - BAR_HEIGHT
		}
		
		-- Cache spectator layout if in spectator mode
		if amSpectating then
			local aliveAllyTeams = getAliveAllyTeams()
			layoutCache.spectatorLayout = calculateSpectatorLayoutParameters(#aliveAllyTeams, minimapSizeX)
		end
		
		-- Clear position cache when layout changes
		positionCache.playerBar = nil
		positionCache.spectatorBars = {}
		positionCache.countdownPositions = {}
		positionCache.textPositions = {}
		
		layoutCache.initialized = true
		lastLayoutUpdate = currentTime
		needsStaticUpdate = true
		needsBackgroundUpdate = true
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
		-- Ensure font cache is initialized first
		initializeFontCache()
		
		-- Ensure layout cache is initialized
		if not layoutCache.playerBarBounds then
			updateLayoutCache()
		end
		
		local bounds = layoutCache.playerBarBounds
		if not bounds then
			-- Fallback if layout cache still not initialized
			local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
			bounds = {
				left = minimapPosX + ICON_SIZE/2,
				right = minimapPosX + minimapSizeX - ICON_SIZE/2,
				top = minimapPosY - MINIMAP_GAP,
				bottom = minimapPosY - MINIMAP_GAP - BAR_HEIGHT
			}
		end
		
		positionCache.playerBar = {
			scorebarLeft = bounds.left,
			scorebarRight = bounds.right,
			scorebarTop = bounds.top,
			scorebarBottom = bounds.bottom,
			textY = bounds.bottom + (bounds.top - bounds.bottom - fontCache.fontSize) / 2,
			innerRight = bounds.right - 3 - fontCache.paddingX
		}
	end
	return positionCache.playerBar
end

local function calculateSpectatorBarPosition(index, layout, minimapPosX, minimapPosY)
	local columnIndex = floor((index - 1) / layout.maxBarsPerColumn)
	local positionInColumn = ((index - 1) % layout.maxBarsPerColumn)
	
	local columnStartX = minimapPosX + (columnIndex * layout.columnWidth)
	local scorebarLeft = columnStartX + 4  -- columnPadding
	local scorebarRight = scorebarLeft + layout.barWidth
	local startY = minimapPosY - MINIMAP_GAP
	local scorebarTop = startY - (positionInColumn * (layout.barHeight + 3))  -- barSpacing
	local scorebarBottom = scorebarTop - layout.barHeight
	
	return scorebarLeft, scorebarBottom, scorebarRight, scorebarTop
end

local function getSpectatorBarPositionsCached(index)
	if not positionCache.spectatorBars[index] then
		-- Ensure font cache is initialized first
		initializeFontCache()
		
		-- Ensure layout cache is initialized
		if not layoutCache.minimapDimensions or not layoutCache.spectatorLayout then
			updateLayoutCache()
		end
		
		local minimapPosX, minimapPosY = layoutCache.minimapDimensions[1], layoutCache.minimapDimensions[2]
		local layout = layoutCache.spectatorLayout
		
		if not minimapPosX or not layout then
			-- Fallback calculation if cache is not ready
			minimapPosX, minimapPosY = spGetMiniMapGeometry()
			local aliveAllyTeams = getAliveAllyTeams()
			layout = calculateSpectatorLayoutParameters(#aliveAllyTeams, select(3, spGetMiniMapGeometry()))
		end
		
		local scorebarLeft, scorebarBottom, scorebarRight, scorebarTop = 
			calculateSpectatorBarPosition(index, layout, minimapPosX, minimapPosY)
	
	local barHeight = scorebarTop - scorebarBottom
	local scaledFontSize = barHeight * 1.1
	
		positionCache.spectatorBars[index] = {
			scorebarLeft = scorebarLeft,
			scorebarRight = scorebarRight,
			scorebarTop = scorebarTop,
			scorebarBottom = scorebarBottom,
			textY = scorebarBottom + (barHeight - scaledFontSize) / 2,
			innerRight = scorebarRight - 3 - fontCache.paddingX,
			fontSize = scaledFontSize
		}
	end
	return positionCache.spectatorBars[index]
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
		
		local countdownY = scorebarBottom + (scorebarTop - scorebarBottom) / 2  -- Center on the bar

		-- Calculate X position at the threshold/skull location
		local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
		local barWidthForCalc = scorebarRight - scorebarLeft
		local thresholdX = scorebarLeft + (threshold / maxThreshold) * barWidthForCalc
		local skullOffset = (1 / maxThreshold) * barWidthForCalc
		-- Position countdown directly over the skull icon (not offset)
		local countdownX = thresholdX - skullOffset
		-- Return skull center Y position (text baseline adjustment handled in countdown creation)
		local countdownY = scorebarBottom + (scorebarTop - scorebarBottom) / 2
		
		return countdownX, countdownY
	end
	
	return minimapPosX + minimapSizeX / 2, minimapPosY - MINIMAP_GAP - 20
end

-- ===== END HELPER FUNCTIONS =====

local function createOptimizedBackgroundDisplayList()
	if backgroundDisplayList then
		glDeleteList(backgroundDisplayList)
	end
	
	backgroundDisplayList = glCreateList(function()
		setOptimizedBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		
		if amSpectating then
			local allyTeamScores = getSpectatorAllyTeamData()
			-- Only draw backgrounds for teams that actually exist
			for i, allyTeamData in ipairs(allyTeamScores) do
				if allyTeamData and allyTeamData.allyTeamID then
					local pos = getSpectatorBarPositionsCached(i)
					
					-- Use cached tinted colors for spectator mode
					local tintedBg = getCachedTintedColor(backgroundColor, allyTeamData.teamColor, 0.15, "bg_" .. allyTeamData.allyTeamID)
					local tintedBorder = getCachedTintedColor(borderColor, allyTeamData.teamColor, 0.1, "border_" .. allyTeamData.allyTeamID)
					
					-- Draw border
					setOptimizedColor(tintedBorder[1], tintedBorder[2], tintedBorder[3], tintedBorder[4])
					glRect(pos.scorebarLeft - BORDER_WIDTH, pos.scorebarBottom - BORDER_WIDTH, 
						   pos.scorebarRight + BORDER_WIDTH, pos.scorebarTop + BORDER_WIDTH)
					
					-- Draw background
					setOptimizedColor(tintedBg[1], tintedBg[2], tintedBg[3], tintedBg[4])
					glRect(pos.scorebarLeft, pos.scorebarBottom, pos.scorebarRight, pos.scorebarTop)
				end
			end
		else
			-- Player mode - always draw background (even if teamID is nil)
			local teamData = getPlayerTeamData()
			local pos = getPlayerBarPositionsCached()
			
			-- Use cached tinted colors for player mode (fallback to default green if no bar color)
			local barColor = (teamData and teamData.barColor) or COLOR_GREEN
			local tintedBg = getCachedTintedColor(backgroundColor, barColor, 0.15, "bg_player")
			local tintedBorder = getCachedTintedColor(borderColor, barColor, 0.1, "border_player")
			
			-- Draw border
			setOptimizedColor(tintedBorder[1], tintedBorder[2], tintedBorder[3], tintedBorder[4])
			glRect(pos.scorebarLeft - BORDER_WIDTH, pos.scorebarBottom - BORDER_WIDTH, 
				   pos.scorebarRight + BORDER_WIDTH, pos.scorebarTop + BORDER_WIDTH)
			
			-- Draw background
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
		-- Static elements that don't change frequently
		if not amSpectating then
			local teamData = getPlayerTeamData()
			if teamData.rank and teamData.teamID then
				local pos = getPlayerBarPositionsCached()
				local rankBoxWidth = 40
				local rankBoxHeight = fontCache.fontSize + 4
				local rankX = pos.scorebarLeft
				local rankY = pos.scorebarBottom - rankBoxHeight - 5
				
				-- Draw rank box (static part)
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
				local barColor = allyTeamData.teamColor
				
				drawOptimizedHealthBar(pos.scorebarLeft, pos.scorebarRight, pos.scorebarBottom, pos.scorebarTop, 
									   allyTeamData.score, threshold, barColor, isThresholdFrozen)
				
				-- Text rendering with cached positions
				local difference = allyTeamData.score - threshold
				local differenceVerticalOffset = 3
				drawDifferenceText(pos.innerRight, pos.textY, difference, pos.fontSize, "r", COLOR_WHITE, differenceVerticalOffset)
			end
		else
			local teamData = getPlayerTeamData()
			if teamData.teamID then
				local pos = getPlayerBarPositionsCached()
				
				drawOptimizedHealthBar(pos.scorebarLeft, pos.scorebarRight, pos.scorebarBottom, pos.scorebarTop, 
									   teamData.score, teamData.threshold, teamData.barColor, isThresholdFrozen)
				
				-- Text rendering
				drawDifferenceText(pos.innerRight, pos.textY, teamData.difference, fontCache.fontSize * 1.20, "r", COLOR_WHITE, 1)
				
				-- Rank text (dynamic content)
				if teamData.rank then
					local rankBoxWidth = 40
					local rankBoxHeight = fontCache.fontSize + 4
					local rankX = pos.scorebarLeft
					local rankY = pos.scorebarBottom - rankBoxHeight - 5
					local centerX = rankX + rankBoxWidth / 2
					local textY = rankY + 4
					local rankText = spI18N('ui.territorialDomination.rank', {rank = teamData.rank})
					
					drawTextWithOutline(rankText, centerX, textY, fontCache.fontSize, "c", COLOR_WHITE)
					end
				end
		end
	end)
end

-- Optimized countdown display list with better caching
local function createOptimizedCountdownDisplayList(timeRemaining, allyTeamID)
	allyTeamID = allyTeamID or myAllyID
	
	-- Use buckets for countdown values to reduce display list churn
	local bucketedTime = ceil(timeRemaining / 5) * 5  -- Round to nearest 5 seconds
	local cacheKey = allyTeamID .. "_" .. bucketedTime
	
	if allyTeamCountdownDisplayLists[cacheKey] then
		return allyTeamCountdownDisplayLists[cacheKey]
	end
	
	-- Clean up old countdown display lists for this ally team
	for key, displayList in pairs(allyTeamCountdownDisplayLists) do
		if key:sub(1, #tostring(allyTeamID) + 1) == allyTeamID .. "_" and key ~= cacheKey then
			glDeleteList(displayList)
			allyTeamCountdownDisplayLists[key] = nil
			end
		end
		
	allyTeamCountdownDisplayLists[cacheKey] = glCreateList(function()
		local countdownColor = COUNTDOWN_COLOR
		local countdownX, countdownY
		
		if amSpectating then
			local minimapPosX, minimapPosY, minimapSizeX = layoutCache.minimapDimensions[1], layoutCache.minimapDimensions[2], layoutCache.minimapDimensions[3]
			countdownX, countdownY = calculateSpectatorCountdownPosition(allyTeamID, minimapPosX, minimapPosY, minimapSizeX)
			if not countdownX then return end
		else
			local pos = getPlayerBarPositionsCached()
			local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
			local barWidth = pos.scorebarRight - pos.scorebarLeft
			local thresholdX = pos.scorebarLeft + (threshold / maxThreshold) * barWidth
			local skullOffset = (1 / maxThreshold) * barWidth
			-- Position countdown directly over the skull icon (not offset)
			countdownX = thresholdX - skullOffset
			-- Return skull center Y position (text baseline adjustment handled in countdown creation)
			countdownY = pos.scorebarBottom + (pos.scorebarTop - pos.scorebarBottom) / 2
		end
		
		local countdownFontSize = fontCache.fontSize * COUNTDOWN_FONT_SIZE_MULTIPLIER
		if amSpectating and layoutCache.spectatorLayout then
			local scaleFactor = layoutCache.spectatorLayout.barHeight / BAR_HEIGHT
			countdownFontSize = max(10, countdownFontSize * scaleFactor)
		end
		
		-- Use actual time for display but cache based on buckets
		local text = format("%d", timeRemaining)
		
		-- Adjust Y position to properly center text on skull (account for text baseline)
		local adjustedCountdownY = countdownY - (countdownFontSize * 0.25)  -- Offset down by 25% of font size
		
		drawCountdownText(countdownX, adjustedCountdownY, text, countdownFontSize, countdownColor)
	end)
	
	return allyTeamCountdownDisplayLists[cacheKey]
end

-- Optimized main update function with smarter update detection
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

	local currentTime = os.clock()
	local layoutChanged = updateLayoutCache()
	
	-- Check what needs updating
	needsBackgroundUpdate = needsBackgroundUpdate or 
							not backgroundDisplayList or layoutChanged
	
	needsStaticUpdate = needsStaticUpdate or 
						not staticDisplayList or layoutChanged
	
	needsDynamicUpdate = needsDynamicUpdate or 
						 not dynamicDisplayList or 
						 (currentTime - lastDynamicUpdate > DYNAMIC_UPDATE_THRESHOLD) or
						 needsDisplayListUpdate()
	
	-- Update only what's necessary
	if needsBackgroundUpdate then
		createOptimizedBackgroundDisplayList()
		needsBackgroundUpdate = false
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
	
	-- Main display list just calls the sub-lists
	if layoutChanged or not displayList then
	if displayList then
		glDeleteList(displayList)
	end
	
	displayList = glCreateList(function()
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

	-- Clear update flags
	needsBackgroundUpdate = false
	needsStaticUpdate = false
	needsDynamicUpdate = false
	needsCountdownUpdate = false
end

local function cleanupOptimizedDisplayLists()
	if displayList then
		glDeleteList(displayList)
		displayList = nil
	end
	
	if staticDisplayList then
		glDeleteList(staticDisplayList)
		staticDisplayList = nil
	end
	
	if dynamicDisplayList then
		glDeleteList(dynamicDisplayList)
		dynamicDisplayList = nil
	end
	
	if backgroundDisplayList then
		glDeleteList(backgroundDisplayList)
		backgroundDisplayList = nil
	end
	
	if timerWarningDisplayList then
		glDeleteList(timerWarningDisplayList)
		timerWarningDisplayList = nil
	end
	
	for key, countdownDisplayList in pairs(allyTeamCountdownDisplayLists) do
		if countdownDisplayList then
			glDeleteList(countdownDisplayList)
		end
	end
	allyTeamCountdownDisplayLists = {}
	
	-- Clear all caches
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
	
	-- Ensure we have our main display list
	if not displayList then
		updateScoreDisplayList()
	end
	
	-- Draw the main score bars (optimized with sub-lists)
	if displayList then
		glCallList(displayList)
	end
	
	-- Optimized countdown rendering - batch process and cache
	local countdownsToRender = {}
	
	if amSpectating then
		-- Collect all countdowns that need rendering (avoid table creation in inner loop)
		for allyTeamID, allyDefeatTime in pairs(allyTeamDefeatTimes) do
			if allyDefeatTime and allyDefeatTime > 0 and gameSeconds and allyDefeatTime > gameSeconds then
				local timeRemaining = ceil(allyDefeatTime - gameSeconds)
				if timeRemaining >= 0 then
					local bucketedTime = ceil(timeRemaining / 5) * 5
					local cacheKey = allyTeamID .. "_" .. bucketedTime
					countdownsToRender[cacheKey] = {allyTeamID = allyTeamID, timeRemaining = timeRemaining}
				end
			end
		end
		
		-- Render all countdowns (create display list only once per cache key)
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
		-- Player mode countdown (single countdown, simpler logic)
		if defeatTime and defeatTime > 0 and gameSeconds and defeatTime > gameSeconds then
			local timeRemaining = ceil(defeatTime - gameSeconds)
			if timeRemaining >= 0 then
				local bucketedTime = ceil(timeRemaining / 5) * 5
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
	
	-- Timer warning rendering (cached display list)
	if currentGameTime < timerWarningEndTime and timerWarningDisplayList then
		setOptimizedColor(1, 1, 1, 1)
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
					-- Force update since ally team selection changed
					needsBackgroundUpdate = true
					needsStaticUpdate = true
					needsDynamicUpdate = true
					updateScoreDisplayList()
				end
				return
			end
		end
		if selectedAllyTeamID ~= myAllyID then
		selectedAllyTeamID = myAllyID
			needsBackgroundUpdate = true
			needsStaticUpdate = true
			needsDynamicUpdate = true
			updateScoreDisplayList()
	end
end
end

function widget:GameFrame(frame)
	if frame % DEFEAT_CHECK_INTERVAL == AFTER_GADGET_TIMER_UPDATE_MODULO + 2 then
		local dataChanged = false
		local teamStatusChanged = false
		
		if amSpectating then
			-- In spectator mode, track defeat times for all ally teams
			local allyTeamList = spGetAllyTeamList()
			for _, allyTeamID in ipairs(allyTeamList) do
				if allyTeamID ~= gaiaAllyTeamID then
					local isCurrentlyAlive = isAllyTeamAlive(allyTeamID)
					local wasAlive = lastAllyTeamScores[allyTeamID] ~= nil
					
					-- Check if team death status changed
					if isCurrentlyAlive ~= wasAlive then
						teamStatusChanged = true
					end
					
					if isCurrentlyAlive then
						-- Find first alive team in this ally team
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
						-- Team is dead, remove its defeat time
						if allyTeamDefeatTimes[allyTeamID] then
							allyTeamDefeatTimes[allyTeamID] = nil
							dataChanged = true
						end
					end
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

		-- Check for rank changes (optimized)
		local rankChanged = false
		
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
					local currentRank = spGetTeamRulesParam(teamID, RANK_RULES_KEY)
					if currentRank and lastTeamRanks[teamID] ~= currentRank then
						rankChanged = true
						break
					end
				end
			end
		end
		
		-- Trigger updates when team status changes (death/revival)
		if teamStatusChanged then
			needsBackgroundUpdate = true
			needsStaticUpdate = true
			needsDynamicUpdate = true
		end
		
		-- Trigger updates only if needed
		if rankChanged then
			needsStaticUpdate = true
			needsDynamicUpdate = true
		end
		
		if dataChanged or rankChanged or teamStatusChanged then
			lastUpdateTime = 0  -- Force update on next frame
		end
	end

	gameSeconds = spGetGameSeconds() or 0

	-- Optimized sound handling (unchanged logic but cleaner)
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
	local newAmSpectating = spGetSpectatingState()
	local newMyAllyID = spGetMyAllyTeamID()
	
	-- Check for mode changes that require background updates
	if newAmSpectating ~= amSpectating or newMyAllyID ~= myAllyID then
		amSpectating = newAmSpectating
		myAllyID = newMyAllyID
		-- Force complete regeneration when mode changes
		needsBackgroundUpdate = true
		needsStaticUpdate = true
		needsDynamicUpdate = true
		-- Clear all caches as layout and content might be completely different
		positionCache.playerBar = nil
		positionCache.spectatorBars = {}
		layoutCache.initialized = false
		-- Force immediate update
		updateScoreDisplayList()
	end
	
	local currentGameTime, freezeExpirationTime, isThresholdFrozen, timeUntilUnfreeze = getFreezeStatusInformation()
	
	gameSeconds = currentGameTime
	
	-- Optimized threshold freeze handling
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
		
		-- More efficient countdown cleanup - only clear if we have any
		if next(allyTeamCountdownDisplayLists) then
			for key, countdownDisplayList in pairs(allyTeamCountdownDisplayLists) do
				if countdownDisplayList then
					glDeleteList(countdownDisplayList)
				end
			end
			allyTeamCountdownDisplayLists = {}
			lastCountdownValues = {}
		end
	end
	
	currentTime = os.clock()
	
	-- Smart update logic - only update when necessary
	local needsUpdate = false
	local forceUpdate = false
	
	-- Check for layout changes (less frequent)
	if currentTime - lastLayoutUpdate > LAYOUT_UPDATE_THRESHOLD then
		needsUpdate = updateLayoutCache() or needsUpdate
	end
	
	-- Check for threshold freeze blinking (only if frozen and near warning)
	if isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS then
		local blinkPhase = (currentTime % BLINK_INTERVAL) / BLINK_INTERVAL
		local currentBlinkState = blinkPhase < 0.33
		if isSkullFaded ~= currentBlinkState then
			needsDynamicUpdate = true
			needsUpdate = true
		end
	end
	
	-- Check for score changes (more frequent but throttled)
	if currentTime - lastDynamicUpdate > DYNAMIC_UPDATE_THRESHOLD then
		if needsDisplayListUpdate() then
			needsDynamicUpdate = true
			needsUpdate = true
		end
	end
	
	-- Reduced force update frequency - only as a safety net for missed changes
	if currentTime - lastUpdateTime > UPDATE_FREQUENCY then
		lastUpdateTime = currentTime
		-- Only force update if we haven't updated recently due to actual changes
		if currentTime - lastDynamicUpdate > UPDATE_FREQUENCY then
			forceUpdate = true
		end
	end
	
	if needsUpdate or forceUpdate then
		updateScoreDisplayList()
	end
	
	-- Handle timer warnings (unchanged but optimized)
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