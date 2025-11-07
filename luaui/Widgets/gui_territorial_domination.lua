function widget:GetInfo()
	return {
		name    = "Territorial Domination Score",
		desc    = "Displays the score for the Territorial Domination game mode.",
		author  = "SethDGamre",
		date    = "2025",
		license = "GNU GPL, v2",
		layer   = 1, --after game_territorial_domination.lua
		enabled = true,
	}
end

local modOptions = Spring.GetModOptions()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) then return false end

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
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetMouseState = Spring.GetMouseState

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
local UPDATE_FREQUENCY = 4.0
local BLINK_INTERVAL = 1
local DEFEAT_CHECK_INTERVAL = Game.gameSpeed
local AFTER_GADGET_TIMER_UPDATE_MODULO = 3
local TIMER_COOLDOWN = 120
local LAYOUT_UPDATE_INTERVAL = 2.0

local WINDUP_SOUND_DURATION = 2
local CHARGE_SOUND_LOOP_DURATION = 4.7

local TIMER_WARNING_DISPLAY_TIME = 5
local PADDING_MULTIPLIER = 0.36
local MINIMAP_GAP = 4
local BORDER_WIDTH = 2
local ICON_SIZE = 25
local HALVED_ICON_SIZE = ICON_SIZE / 2
local BAR_HEIGHT = 16
local TEXT_OUTLINE_OFFSET = 1.0
local TEXT_OUTLINE_ALPHA = 0.6
local COUNTDOWN_FONT_SIZE_MULTIPLIER = 1.6
local HALO_EXTENSION = 4
local HALO_MAX_ALPHA = 0.4

local SCORE_RULES_KEY = "territorialDominationScore"
local THRESHOLD_RULES_KEY = "territorialDominationDefeatThreshold"
local FREEZE_DELAY_KEY = "territorialDominationPauseDelay"
local MAX_THRESHOLD_RULES_KEY = "territorialDominationMaxThreshold"
local RANK_RULES_KEY = "territorialDominationRank"

local DEFAULT_MAX_THRESHOLD = 256

local COLOR_WHITE = { 1, 1, 1, 1 }
local COLOR_RED = { 1, 0, 0, 1 }
local COUNTDOWN_COLOR = { 1, 0.2, 0.2, 1 }
local COLOR_YELLOW = { 1, 0.8, 0, 1 }
local COLOR_BACKGROUND = { 0, 0, 0, 0.5 }
local COLOR_BORDER = { 0.2, 0.2, 0.2, 0.2 }
local COLOR_GREEN = { 0, 0.8, 0, 0.8 }
local COLOR_GREY_LINE = { 0.7, 0.7, 0.7, 0.7 }
local COLOR_WHITE_LINE = { 1, 1, 1, 0.8 }

local myCommanders = {}
local soundQueue = {}
local allyTeamDefeatTimes = {}
local allyTeamCountdownDisplayLists = {}
local lastCountdownValues = {}
local aliveAllyTeams = {}
local scoreBarPositions = {}

local isSkullFaded = true
local lastTimerWarningTime = 0
local timerWarningEndTime = 0
local amSpectating = false
local myAllyID = -1
local selectedAllyTeamID = -1
local gaiaAllyTeamID = -1
local lastUpdateTime = 0
local lastScore = -1
local lastDifference = -1
local scorebarWidth = 300
local lineWidth = 2
local maxThreshold = DEFAULT_MAX_THRESHOLD
local currentTime = os.clock()
local defeatTime = 0
local gameSeconds = 0
local lastLoop = 0
local loopSoundEndTime = 0
local soundIndex = 1
local currentGameFrame = 0

local lastDefeatThreshold = -1
local lastMaxThreshold = -1
local lastIsDefeatThresholdPaused = false
local lastScorebarWidth = -1
local lastMinimapDimensions = { -1, -1, -1 }
local lastAmSpectating = false
local lastSelectedAllyTeamID = -1
local lastAllyTeamScores = {}
local lastTeamRanks = {}

local compositeDisplayList = nil
local scoreBarDisplayList = nil
local scoreBarBackgroundDisplayList = nil
local selectionHaloDisplayList = nil
local timerWarningDisplayList = nil

local needsScoreBarBackgroundUpdate = false
local needsScoreBarUpdate = false
local needsSelectionHaloUpdate = false



local LAYOUT_UPDATE_THRESHOLD = 4.0
local SCORE_BAR_UPDATE_THRESHOLD = 0.5
local lastLayoutUpdate = 0
local lastScoreBarUpdate = 0

local cachedPauseStatus = {
	isDefeatThresholdPaused = false,
	pauseExpirationTime = 0,
	timeUntilUnpause = 0,
	lastUpdate = 0
}

local cachedGameState = {
	defeatThreshold = 0,
	maxThreshold = DEFAULT_MAX_THRESHOLD,
	lastUpdate = 0
}

local frameBasedUpdates = {
	teamScoreCheck = 0,
	soundUpdate = 0
}

local cache = {
	data = {},
	dependencies = {},
	ttl = {},
	lastUpdate = {},

	set = function(self, cacheKey, value, timeToLive, dependencies)
		self.data[cacheKey] = value
		self.lastUpdate[cacheKey] = currentTime
		if timeToLive then
			self.ttl[cacheKey] = timeToLive
		end
		if dependencies then
			self.dependencies[cacheKey] = dependencies
		end
		return value
	end,

	get = function(self, cacheKey, validator)
		local entry = self.data[cacheKey]

		if not entry then
			return nil
		end

		if self.ttl[cacheKey] and (currentTime - self.lastUpdate[cacheKey]) > self.ttl[cacheKey] then
			self:invalidate(cacheKey)
			return nil
		end

		if self.dependencies[cacheKey] and validator then
			for _, dependency in ipairs(self.dependencies[cacheKey]) do
				if not validator(dependency) then
					self:invalidate(cacheKey)
					return nil
				end
			end
		end

		return entry
	end,

	getOrCompute = function(self, cacheKey, computeFunc, timeToLive, dependencies, validator)
		local value = self:get(cacheKey, validator)
		if value ~= nil then
			return value
		end

		value = computeFunc()
		return self:set(cacheKey, value, timeToLive, dependencies)
	end,

	invalidate = function(self, keyPattern)
		if type(keyPattern) == "string" and not keyPattern:find("*") then
			self.data[keyPattern] = nil
			self.lastUpdate[keyPattern] = nil
			self.ttl[keyPattern] = nil
			self.dependencies[keyPattern] = nil
		else
			local pattern = keyPattern:gsub("*", ".*")
			for cacheKey in pairs(self.data) do
				if cacheKey:match(pattern) then
					self.data[cacheKey] = nil
					self.lastUpdate[cacheKey] = nil
					self.ttl[cacheKey] = nil
					self.dependencies[cacheKey] = nil
				end
			end
		end
	end,

	clear = function(self)
		self.data = {}
		self.dependencies = {}
		self.ttl = {}
		self.lastUpdate = {}
	end
}

local CACHE_KEYS = {
	FONT_DATA = "font_data",
	LAYOUT_DATA = "layout_data",
	TEAM_COLOR = "team_color_%d",
	TINTED_COLOR = "tinted_color_%s"
}

local CACHE_TTL = {
	FAST = 0.1,
	NORMAL = 0.5,
	SLOW = 2.0,
	STATIC = nil
}

local fontCache = cache:getOrCompute(CACHE_KEYS.FONT_DATA, function()
	local _, viewportSizeY = spGetViewGeometry()
	local fontSizeMultiplier = max(1.2, math.min(2.25, viewportSizeY / 1080))
	local baseFontSize = floor(14 * fontSizeMultiplier)
	return {
		initialized = true,
		fontSizeMultiplier = fontSizeMultiplier,
		fontSize = baseFontSize,
		paddingX = floor(baseFontSize * PADDING_MULTIPLIER),
		paddingY = floor(baseFontSize * PADDING_MULTIPLIER)
	}
end, CACHE_TTL.SLOW)

local layoutCache = cache:getOrCompute(CACHE_KEYS.LAYOUT_DATA, function()
	return {
		initialized = false,
		minimapDimensions = { -1, -1, -1 },
		lastViewportSize = { -1, -1 }
	}
end, CACHE_TTL.STATIC)

local function createTintedColor(baseColor, tintColor, strength)
	local tintedColor = {
		baseColor[1] + (tintColor[1] - baseColor[1]) * strength,
		baseColor[2] + (tintColor[2] - baseColor[2]) * strength,
		baseColor[3] + (tintColor[3] - baseColor[3]) * strength,
		baseColor[4]
	}
	return tintedColor
end

local function getMaxThreshold()
	local maxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or DEFAULT_MAX_THRESHOLD
	if maxThreshold <= 0 then
		maxThreshold = DEFAULT_MAX_THRESHOLD
	end
	return maxThreshold
end

local function forceDisplayListUpdate()
	lastUpdateTime = 0
	needsScoreBarBackgroundUpdate = true
	needsScoreBarUpdate = true
	needsSelectionHaloUpdate = true

	cache:invalidate(CACHE_KEYS.LAYOUT_DATA)
end

local function cleanupDisplayList(displayList)
	if displayList then
		glDeleteList(displayList)
	end
	return nil
end

local function cleanupCountdowns(allyTeamIDFilter)
	local cleanedUp = false
	if allyTeamIDFilter then
		for cacheKey, displayList in pairs(allyTeamCountdownDisplayLists) do
			if cacheKey:sub(1, #tostring(allyTeamIDFilter) + 1) == allyTeamIDFilter .. "_" then
				glDeleteList(displayList)
				allyTeamCountdownDisplayLists[cacheKey] = nil
				cleanedUp = true
			end
		end
		lastCountdownValues[allyTeamIDFilter] = nil
	else
		for cacheKey, displayList in pairs(allyTeamCountdownDisplayLists) do
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

local function isAllyTeamAlive(allyTeamID)
	if allyTeamID == gaiaAllyTeamID then
		return false
	end

	local teamList = spGetTeamList(allyTeamID)
	for _, teamID in ipairs(teamList) do
		local _, _, isDead = spGetTeamInfo(teamID, false)
		if not isDead then
			return true
		end
	end

	return false
end

local function isHordeModeAllyTeam(allyTeamID)
	local teamList = spGetTeamList(allyTeamID)
	if not teamList then return false end

	for _, teamID in ipairs(teamList) do
		local luaAI = spGetTeamLuaAI(teamID)
		if luaAI and luaAI ~= "" then
			if string.sub(luaAI, 1, 12) == 'ScavengersAI' or string.sub(luaAI, 1, 12) == 'RaptorsAI' then
				return true
			end
		end
	end
	return false
end

local function updateAliveAllyTeams()
	aliveAllyTeams = {}
	local allyTeamList = spGetAllyTeamList()

	for _, allyTeamID in ipairs(allyTeamList) do
		if isAllyTeamAlive(allyTeamID) and not isHordeModeAllyTeam(allyTeamID) then
			table.insert(aliveAllyTeams, allyTeamID)
		end
	end
end

local function calculateLayoutParameters(totalTeams, minimapSizeX)
	local maxDisplayHeight = 256
	local barSpacing = 3

	local maxPossibleColumns = totalTeams
	for numColumns = 1, totalTeams do
		local barsPerColumn = ceil(totalTeams / numColumns)
		local totalSpacingHeight = (barsPerColumn - 1) * barSpacing
		local requiredHeight = (barsPerColumn * BAR_HEIGHT) + totalSpacingHeight

		if requiredHeight <= maxDisplayHeight then
			maxPossibleColumns = numColumns
			break
		end
	end

	local numColumns = maxPossibleColumns
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

local function calculateBarPosition(index)
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()

	local layout = cache:getOrCompute("layout_params", function()
		local displayTeams = amSpectating and aliveAllyTeams or { myAllyID }
		return calculateLayoutParameters(#displayTeams, minimapSizeX)
	end, CACHE_TTL.NORMAL)

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

local function getCachedTeamColor(teamID)
	local cacheKey = format(CACHE_KEYS.TEAM_COLOR, teamID)
	return cache:getOrCompute(cacheKey, function()
		local redComponent, greenComponent, blueComponent = spGetTeamColor(teamID)
		return { redComponent, greenComponent, blueComponent, 1 }
	end, CACHE_TTL.STATIC)
end

local function getCachedTintedColor(baseColor, tintColor, strength, cacheKey)
	local cacheKeyToUse = cacheKey or
	format(CACHE_KEYS.TINTED_COLOR, baseColor[1] .. "_" .. tintColor[1] .. "_" .. strength)
	return cache:getOrCompute(cacheKeyToUse, function()
		return createTintedColor(baseColor, tintColor, strength)
	end, CACHE_TTL.STATIC)
end

local function drawTextWithOutline(text, textPositionX, textPositionY, fontSize, alignment, color)
	glColor(0, 0, 0, TEXT_OUTLINE_ALPHA)

	glText(text, textPositionX - TEXT_OUTLINE_OFFSET, textPositionY, fontSize, alignment)
	glText(text, textPositionX + TEXT_OUTLINE_OFFSET, textPositionY, fontSize, alignment)
	glText(text, textPositionX, textPositionY - TEXT_OUTLINE_OFFSET, fontSize, alignment)
	glText(text, textPositionX, textPositionY + TEXT_OUTLINE_OFFSET, fontSize, alignment)

	glColor(color[1], color[2], color[3], color[4])
	glText(text, textPositionX, textPositionY, fontSize, alignment)
end

local function drawDifferenceText(textPositionX, textPositionY, difference, fontSize, alignment, color, verticalOffset)
	local text = ""

	if difference > 0 then
		text = "+" .. difference
	elseif difference < 0 then
		text = tostring(difference)
	else
		text = "0"
	end

	local adjustedPositionY = textPositionY + (verticalOffset or 0)
	drawTextWithOutline(text, textPositionX, adjustedPositionY, fontSize, alignment, color)
end

local function drawCountdownText(textPositionX, textPositionY, text, fontSize, color)
	drawTextWithOutline(text, textPositionX, textPositionY, fontSize, "c", color)
end

local function createGradientVertices(left, right, bottom, top, topColor, bottomColor)
	return {
		{ v = { left, bottom }, c = bottomColor },
		{ v = { right, bottom }, c = bottomColor },
		{ v = { right, top },  c = topColor },
		{ v = { left, top },   c = topColor }
	}
end

local function drawBarFill(fillLeft, fillRight, fillBottom, fillTop, barColor, isOverfill)
	local topColor = { barColor[1], barColor[2], barColor[3], barColor[4] }
	local bottomColor = { barColor[1] * 0.7, barColor[2] * 0.7, barColor[3] * 0.7, barColor[4] }

	if isOverfill then
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
		topColor = excessTopColor
		bottomColor = excessBottomColor
	end

	local vertices = createGradientVertices(fillLeft, fillRight, fillBottom, fillTop, topColor, bottomColor)
	gl.Shape(GL.QUADS, vertices)
end

local function drawGlossEffects(fillLeft, fillRight, fillBottom, fillTop)
	gl.Blending(GL.SRC_ALPHA, GL.ONE)

	local glossHeight = (fillTop - fillBottom) * 0.4
	local topGlossBottom = fillTop - glossHeight
	local vertices = createGradientVertices(fillLeft, fillRight, topGlossBottom, fillTop, { 1, 1, 1, 0.04 }, { 1, 1, 1, 0 })
	gl.Shape(GL.QUADS, vertices)

	local bottomGlossHeight = (fillTop - fillBottom) * 0.2
	vertices = createGradientVertices(fillLeft, fillRight, fillBottom, fillBottom + bottomGlossHeight, { 1, 1, 1, 0.02 },
		{ 1, 1, 1, 0 })
	gl.Shape(GL.QUADS, vertices)

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

local function drawSkullIcon(skullX, skullY, isDefeatThresholdPaused)
	glPushMatrix()
	glTranslate(skullX, skullY, 0)

	local shadowOffset = 1.5
	local shadowAlpha = 0.6
	local shadowScale = 1.1

	glColor(0, 0, 0, shadowAlpha)
	glTexture(':n:LuaUI/Images/skull.dds')
	glTexRect(
		-HALVED_ICON_SIZE * shadowScale + shadowOffset,
		-HALVED_ICON_SIZE * shadowScale - shadowOffset,
		HALVED_ICON_SIZE * shadowScale + shadowOffset,
		HALVED_ICON_SIZE * shadowScale - shadowOffset
	)

	local skullAlpha = 1.0
	if isDefeatThresholdPaused then
		local currentGameTime = spGetGameSeconds()
		local pauseExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
		local timeUntilUnpause = pauseExpirationTime - currentGameTime

		if timeUntilUnpause <= WARNING_SECONDS then
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
	glTexRect(-HALVED_ICON_SIZE, -HALVED_ICON_SIZE, HALVED_ICON_SIZE, HALVED_ICON_SIZE)

	glTexture(false)
	glPopMatrix()
end

local function drawScoreLineIndicator(linePos, scorebarBottom, scorebarTop, exceedsMaxThreshold)
	local lineExtension = 3
	local lineColor = exceedsMaxThreshold and COLOR_WHITE_LINE or COLOR_GREY_LINE

	glColor(0, 0, 0, 0.8)
	glRect(linePos - lineWidth - 1, scorebarBottom - lineExtension,
		linePos + lineWidth + 1, scorebarTop + lineExtension)

	glColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glRect(linePos - lineWidth / 2, scorebarBottom - lineExtension,
		linePos + lineWidth / 2, scorebarTop + lineExtension)
end

local function drawScoreBar(scorebarLeft, scorebarRight, scorebarBottom, scorebarTop, score, defeatThreshold, barColor,
							isDefeatThresholdPaused)
	maxThreshold = getMaxThreshold()
	
	local barWidth = scorebarRight - scorebarLeft
	local exceedsMaxThreshold = score > maxThreshold
	local borderSize = 3

	local fillPaddingLeft = scorebarLeft + borderSize
	local fillPaddingTop = scorebarTop
	local fillPaddingBottom = scorebarBottom + borderSize

	local linePos = scorebarLeft + min(score / maxThreshold, 1) * barWidth

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	if exceedsMaxThreshold then
		local overfillRatio = min((score - maxThreshold) / maxThreshold, 1)
		local maxBarWidth = scorebarRight - borderSize - fillPaddingLeft
		local overfillWidth = maxBarWidth * overfillRatio
		local brightColorStart = scorebarRight - borderSize - overfillWidth

		linePos = max(fillPaddingLeft, brightColorStart)

		if brightColorStart > fillPaddingLeft then
			drawBarFill(fillPaddingLeft, brightColorStart, fillPaddingBottom, fillPaddingTop, barColor, false)
		end

		drawBarFill(brightColorStart, scorebarRight - borderSize, fillPaddingBottom, fillPaddingTop, barColor, true)
		drawGlossEffects(fillPaddingLeft, scorebarRight - borderSize, fillPaddingBottom, fillPaddingTop)
	else
		local fillPaddingRight = linePos - borderSize
		if fillPaddingLeft < fillPaddingRight then
			drawBarFill(fillPaddingLeft, fillPaddingRight, fillPaddingBottom, fillPaddingTop, barColor, false)
			drawGlossEffects(fillPaddingLeft, fillPaddingRight, fillPaddingBottom, fillPaddingTop)
		end
	end

	if defeatThreshold >= 1 then
		local defeatThresholdX = scorebarLeft + (defeatThreshold / maxThreshold) * barWidth
		local skullOffset = (1 / maxThreshold) * barWidth
		local skullX = defeatThresholdX - skullOffset
		local skullY = scorebarBottom + (scorebarTop - scorebarBottom) / 2

		drawSkullIcon(skullX, skullY, isDefeatThresholdPaused)
	end

	drawScoreLineIndicator(linePos, scorebarBottom, scorebarTop, exceedsMaxThreshold)

	local defeatThresholdX = scorebarLeft + (defeatThreshold / maxThreshold) * barWidth
	local skullOffset = (1 / maxThreshold) * barWidth
	local skullX = defeatThresholdX - skullOffset

	return linePos, scorebarRight, defeatThresholdX, skullX
end

local function createTimerWarningMessage(timeRemaining, territoriesNeeded)
	local dominatedMessage = spI18N('ui.territorialDomination.losingWarning1', { seconds = timeRemaining })
	local conquerMessage = spI18N('ui.territorialDomination.losingWarning2', { count = territoriesNeeded })
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

		drawTextWithOutline(dominatedMessage, centerX, centerY + spacing, fontSize, "c", COLOR_WHITE)
		drawTextWithOutline(conquerMessage, centerX, centerY - spacing, fontSize, "c", COLOR_WHITE)
	end)
end

local function getRepresentativeTeamDataFromAllyTeam(allyTeamID)
	local teamList = spGetTeamList(allyTeamID)
	if not teamList or #teamList == 0 then
		return nil, 0, nil
	end

	local representativeTeamID = teamList[1]
	local score = spGetTeamRulesParam(representativeTeamID, SCORE_RULES_KEY) or 0
	local rank = spGetTeamRulesParam(representativeTeamID, RANK_RULES_KEY)

	return representativeTeamID, score, rank
end

local function teamScoresChanged()
	for _, allyTeamID in ipairs(aliveAllyTeams) do
		local teamID, currentScore = getRepresentativeTeamDataFromAllyTeam(allyTeamID)
		if teamID then
			local previousScore = lastAllyTeamScores[allyTeamID]
			if previousScore ~= currentScore then
				return true
			end
		end
	end

	return false
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

local function getAllyTeamDisplayData()
	local cacheKey = amSpectating and "spectator_teams" or "player_team"

	return cache:getOrCompute(cacheKey, function()
		local displayTeams = amSpectating and aliveAllyTeams or { myAllyID }
		local allyTeamScores = {}

		for _, allyTeamID in ipairs(displayTeams) do
			local teamID, score, rank = getRepresentativeTeamDataFromAllyTeam(allyTeamID)
			local teamColor = { 1, 1, 1, 1 }
			local defeatTimeRemaining = 0

			if teamID then
				local redComponent, greenComponent, blueComponent = spGetTeamColor(teamID)
				teamColor = { redComponent, greenComponent, blueComponent, 1 }
			end

			if not amSpectating then
				local difference = score - (spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0)
				teamColor = getBarColorBasedOnDifference(difference)
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
				teamID = teamID,
				defeatTimeRemaining = defeatTimeRemaining
			})
		end

		if amSpectating then
			table.sort(allyTeamScores, function(a, b)
				if a.score == b.score then
					return a.defeatTimeRemaining > b.defeatTimeRemaining
				end
				return a.score > b.score
			end)
		end

		return allyTeamScores
	end, CACHE_TTL.NORMAL)
end

local function updateLastValues(score, difference, defeatThreshold, maxThreshold, isDefeatThresholdPaused, scorebarWidth,
								minimapDimensions, amSpectating, selectedAllyTeamID, teamID, rank)
	if score ~= nil then lastScore = score end
	if difference ~= nil then lastDifference = difference end
	if defeatThreshold ~= nil then lastDefeatThreshold = defeatThreshold end
	if maxThreshold ~= nil then lastMaxThreshold = maxThreshold end
	if isDefeatThresholdPaused ~= nil then lastIsDefeatThresholdPaused = isDefeatThresholdPaused end
	if scorebarWidth ~= nil then lastScorebarWidth = scorebarWidth end
	if minimapDimensions ~= nil then lastMinimapDimensions = minimapDimensions end
	if amSpectating ~= nil then lastAmSpectating = amSpectating end
	if selectedAllyTeamID ~= nil then lastSelectedAllyTeamID = selectedAllyTeamID end
	if teamID ~= nil and rank ~= nil then lastTeamRanks[teamID] = rank end
end

local function needsDisplayListUpdate()
	if not fontCache.initialized then
		return true
	end

	local isDefeatThresholdPaused = cachedPauseStatus.isDefeatThresholdPaused
	local defeatThreshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local currentMaxThreshold = getMaxThreshold()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()

	local currentScore, currentDifference, currentTeamID, currentRank

	if not amSpectating then
		currentTeamID, currentScore, currentRank = getRepresentativeTeamDataFromAllyTeam(myAllyID)
		currentDifference = currentScore - defeatThreshold
	else
		local cachedData = cache.data["spectator_teams"]
		if not cachedData or #cachedData == 0 then
			return true
		end
		local firstTeam = cachedData[1]
		currentScore = firstTeam.score
		currentDifference = firstTeam.score - defeatThreshold
		currentTeamID = firstTeam.teamID
		currentRank = firstTeam.rank
	end

	local hasChanged = lastScore ~= currentScore
		or lastDifference ~= currentDifference
		or lastDefeatThreshold ~= defeatThreshold
		or lastMaxThreshold ~= currentMaxThreshold
		or lastIsDefeatThresholdPaused ~= isDefeatThresholdPaused
		or lastScorebarWidth ~= scorebarWidth
		or lastMinimapDimensions[1] ~= minimapPosX
		or lastMinimapDimensions[2] ~= minimapPosY
		or lastMinimapDimensions[3] ~= minimapSizeX
		or lastAmSpectating ~= amSpectating
		or lastSelectedAllyTeamID ~= selectedAllyTeamID
		or (currentTeamID and lastTeamRanks[currentTeamID] ~= currentRank)

	if hasChanged then
		updateLastValues(currentScore, currentDifference, defeatThreshold, currentMaxThreshold, isDefeatThresholdPaused,
			scorebarWidth, { minimapPosX, minimapPosY, minimapSizeX }, amSpectating, selectedAllyTeamID, currentTeamID,
			currentRank)
		return true
	end

	return false
end

local function updateTrackingVariables()
	local currentGameTime = spGetGameSeconds()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local defeatThreshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	local currentMaxThreshold = getMaxThreshold()
	local isDefeatThresholdPaused = (spGetGameRulesParam(FREEZE_DELAY_KEY) or 0) > currentGameTime

	updateLastValues(nil, nil, defeatThreshold, currentMaxThreshold, isDefeatThresholdPaused, scorebarWidth,
		{ minimapPosX, minimapPosY, minimapSizeX }, amSpectating, selectedAllyTeamID)
	maxThreshold = currentMaxThreshold
end

local function updateLayoutCache()
	if currentTime - lastLayoutUpdate < LAYOUT_UPDATE_THRESHOLD and layoutCache.initialized then
		return false
	end

	local vsx, vsy = spGetViewGeometry()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()

	local needsUpdate = not layoutCache.initialized or layoutCache.minimapDimensions[1] ~= minimapPosX or
	layoutCache.minimapDimensions[2] ~= minimapPosY or layoutCache.minimapDimensions[3] ~= minimapSizeX or
	layoutCache.lastViewportSize[1] ~= vsx or layoutCache.lastViewportSize[2] ~= vsy

	if needsUpdate then
		layoutCache.minimapDimensions = { minimapPosX, minimapPosY, minimapSizeX }
		layoutCache.lastViewportSize = { vsx, vsy }

		cache:invalidate("layout_params")
		if currentTime - lastLayoutUpdate > 1.0 then
			cache:invalidate("spectator_teams")
			cache:invalidate("player_team")
		end

		scoreBarPositions = {}

		cleanupCountdowns()

		layoutCache.initialized = true
		lastLayoutUpdate = currentTime
		forceDisplayListUpdate()
		return true
	end

	return false
end

local function getBarPositionsCached(index)
	if not scoreBarPositions[index] then
		local bounds = calculateBarPosition(index)
		local barHeight = bounds.scorebarTop - bounds.scorebarBottom
		local scaledFontSize = barHeight * 1.1

		scoreBarPositions[index] = {
			scorebarLeft = bounds.scorebarLeft,
			scorebarRight = bounds.scorebarRight,
			scorebarTop = bounds.scorebarTop,
			scorebarBottom = bounds.scorebarBottom,
			textY = bounds.scorebarBottom + (barHeight - scaledFontSize) / 2,
			innerRight = bounds.scorebarRight - 3 - fontCache.paddingX,
			fontSize = scaledFontSize
		}
	end
	return scoreBarPositions[index]
end

local function isMouseOverAnyScoreBar()
	if not compositeDisplayList or currentGameFrame <= 1 then
		return false
	end
	
	local mx, my = spGetMouseState()
	local allyTeamData = getAllyTeamDisplayData()
	
	if not allyTeamData or #allyTeamData == 0 then
		return false
	end
	
	for allyTeamIndex, allyTeamDataEntry in ipairs(allyTeamData) do
		if allyTeamDataEntry and allyTeamDataEntry.allyTeamID then
			local barPosition = getBarPositionsCached(allyTeamIndex)
			
			if barPosition and mx >= barPosition.scorebarLeft and mx <= barPosition.scorebarRight and
			   my >= barPosition.scorebarBottom and my <= barPosition.scorebarTop then
				return true
			end
		end
	end
	
	return false
end

local function calculateCountdownPosition(allyTeamID, barIndex)
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local defeatThreshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	
	maxThreshold = getMaxThreshold()

	if not barIndex then
		local allyTeamScores = getAllyTeamDisplayData()

		for allyTeamIndex, allyTeamData in ipairs(allyTeamScores) do
			if allyTeamData.allyTeamID == allyTeamID then
				barIndex = allyTeamIndex
				break
			end
		end
	end

	if barIndex then
		local bounds = calculateBarPosition(barIndex)
		local barWidth = bounds.scorebarRight - bounds.scorebarLeft
		local defeatThresholdX = bounds.scorebarLeft + (defeatThreshold / maxThreshold) * barWidth
		local skullOffset = (1 / maxThreshold) * barWidth
		local countdownX = defeatThresholdX - skullOffset
		local countdownY = bounds.scorebarBottom + (bounds.scorebarTop - bounds.scorebarBottom) / 2

		return countdownX, countdownY
	end

	return minimapPosX + minimapSizeX / 2, minimapPosY - MINIMAP_GAP - 20
end

local function manageCountdownUpdates()
	local currentGameTime = spGetGameSeconds()
	local updatedCountdowns = false
	local allyTeamsWithCountdowns = {}

	if amSpectating then
		for allyTeamID, allyDefeatTime in pairs(allyTeamDefeatTimes) do
			if allyDefeatTime and allyDefeatTime > 0 and currentGameTime and allyDefeatTime > currentGameTime then
				local timeRemaining = ceil(allyDefeatTime - currentGameTime)
				if timeRemaining >= 0 then
					allyTeamsWithCountdowns[allyTeamID] = timeRemaining
				end
			end
		end
	else
		if defeatTime and defeatTime > 0 and currentGameTime and defeatTime > currentGameTime then
			local timeRemaining = ceil(defeatTime - currentGameTime)
			if timeRemaining >= 0 then
				allyTeamsWithCountdowns[myAllyID] = timeRemaining
			end
		end
	end

	for allyTeamID in pairs(lastCountdownValues) do
		if not allyTeamsWithCountdowns[allyTeamID] then
			if cleanupCountdowns(allyTeamID) then
				updatedCountdowns = true
			end
		end
	end

	for allyTeamID, timeRemaining in pairs(allyTeamsWithCountdowns) do
		if lastCountdownValues[allyTeamID] ~= timeRemaining then
			cleanupCountdowns(allyTeamID)
			lastCountdownValues[allyTeamID] = timeRemaining
			updatedCountdowns = true
		end
	end

	return updatedCountdowns
end

local function createSelectionHaloDisplayList(allyTeamData)
	if selectionHaloDisplayList then
		glDeleteList(selectionHaloDisplayList)
	end

	selectionHaloDisplayList = glCreateList(function()
		if not amSpectating or selectedAllyTeamID == gaiaAllyTeamID or selectedAllyTeamID == -1 then
			return
		end

		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

		local targetBarIndex = nil
		for allyTeamIndex, allyTeamDataEntry in ipairs(allyTeamData) do
			if allyTeamDataEntry.allyTeamID == selectedAllyTeamID then
				targetBarIndex = allyTeamIndex
				break
			end
		end

		if not targetBarIndex then
			return
		end

		local barPosition = getBarPositionsCached(targetBarIndex)
		local fadeSteps = 4
		local stepSize = HALO_EXTENSION / fadeSteps
		local alphaStep = HALO_MAX_ALPHA / fadeSteps

		for step = 1, fadeSteps do
			local currentAlpha = alphaStep * step
			local offset = (step - 1) * stepSize

			glColor(1, 1, 1, currentAlpha)

			glRect(barPosition.scorebarLeft - offset, barPosition.scorebarTop, barPosition.scorebarRight + offset,
				barPosition.scorebarTop + stepSize)
			glRect(barPosition.scorebarLeft - offset, barPosition.scorebarBottom - stepSize,
				barPosition.scorebarRight + offset, barPosition.scorebarBottom)
			glRect(barPosition.scorebarLeft - offset, barPosition.scorebarBottom - offset, barPosition.scorebarLeft,
				barPosition.scorebarTop + offset)
			glRect(barPosition.scorebarRight, barPosition.scorebarBottom - offset, barPosition.scorebarRight + offset,
				barPosition.scorebarTop + offset)
		end
	end)
end

local function createScoreBarBackgroundDisplayList(allyTeamData)
	if scoreBarBackgroundDisplayList then
		glDeleteList(scoreBarBackgroundDisplayList)
	end

	scoreBarBackgroundDisplayList = glCreateList(function()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

		for allyTeamIndex, allyTeamDataEntry in ipairs(allyTeamData) do
			if allyTeamDataEntry and allyTeamDataEntry.allyTeamID then
				local barPosition = getBarPositionsCached(allyTeamIndex)

				local tintedBg = getCachedTintedColor(COLOR_BACKGROUND, allyTeamDataEntry.teamColor, 0.15,
					"bg_" .. allyTeamDataEntry.allyTeamID)
				local tintedBorder = getCachedTintedColor(COLOR_BORDER, allyTeamDataEntry.teamColor, 0.1,
					"border_" .. allyTeamDataEntry.allyTeamID)

				glColor(tintedBorder[1], tintedBorder[2], tintedBorder[3], tintedBorder[4])
				glRect(barPosition.scorebarLeft - BORDER_WIDTH, barPosition.scorebarBottom - BORDER_WIDTH,
					barPosition.scorebarRight + BORDER_WIDTH, barPosition.scorebarTop + BORDER_WIDTH)

				glColor(tintedBg[1], tintedBg[2], tintedBg[3], tintedBg[4])
				glRect(barPosition.scorebarLeft, barPosition.scorebarBottom, barPosition.scorebarRight,
					barPosition.scorebarTop)
			end
		end
	end)
end

local function createScoreBarDisplayList(allyTeamData)
	if scoreBarDisplayList then
		glDeleteList(scoreBarDisplayList)
	end

	scoreBarDisplayList = glCreateList(function()
		local defeatThreshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
		local isDefeatThresholdPaused = cachedPauseStatus.isDefeatThresholdPaused

		for allyTeamIndex, allyTeamDataEntry in ipairs(allyTeamData) do
			local barPosition = getBarPositionsCached(allyTeamIndex)

			drawScoreBar(barPosition.scorebarLeft, barPosition.scorebarRight, barPosition.scorebarBottom,
				barPosition.scorebarTop, allyTeamDataEntry.score, defeatThreshold, allyTeamDataEntry.teamColor,
				isDefeatThresholdPaused)

			local difference = allyTeamDataEntry.score - defeatThreshold
			local differenceVerticalOffset = 4
			local fontSize = amSpectating and barPosition.fontSize or (fontCache.fontSize * 1.20)
			drawDifferenceText(barPosition.innerRight, barPosition.textY, difference, fontSize, "r", COLOR_WHITE,
				differenceVerticalOffset)

			if not amSpectating and allyTeamDataEntry.rank then
				local rankText = spI18N('ui.territorialDomination.rank', { rank = allyTeamDataEntry.rank })
				local textWidth = glGetTextWidth(rankText) * fontCache.fontSize
				local textHeight = fontCache.fontSize + 2

				local paddingX = textWidth * 0.2
				local paddingY = textHeight * 0.2
				local rankBoxWidth = textWidth + (paddingX * 1)
				local rankBoxHeight = textHeight + (paddingY * 1)

				local rankPositionX = barPosition.scorebarLeft
				local rankPositionY = barPosition.scorebarBottom - rankBoxHeight
				-- Draw rank background box
				glColor(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4])
				glRect(rankPositionX - BORDER_WIDTH, rankPositionY - BORDER_WIDTH,
					rankPositionX + rankBoxWidth + BORDER_WIDTH, rankPositionY + rankBoxHeight + BORDER_WIDTH)

				glColor(COLOR_BACKGROUND[1], COLOR_BACKGROUND[2], COLOR_BACKGROUND[3], COLOR_BACKGROUND[4])
				glRect(rankPositionX, rankPositionY, rankPositionX + rankBoxWidth, rankPositionY + rankBoxHeight)

				local centerX = rankPositionX + rankBoxWidth / 2
				local centerY = rankPositionY + rankBoxHeight / 2 - paddingY

				drawTextWithOutline(rankText, centerX, centerY, fontCache.fontSize, "c", COLOR_WHITE)
			end
		end
	end)
end

local function createCountdownDisplayList(timeRemaining, allyTeamID)
	allyTeamID = allyTeamID or myAllyID

	local cacheKey = allyTeamID .. "_" .. timeRemaining

	if allyTeamCountdownDisplayLists[cacheKey] then
		return allyTeamCountdownDisplayLists[cacheKey]
	end

	local keysToDelete = {}
	for displayListKey, displayList in pairs(allyTeamCountdownDisplayLists) do
		if displayListKey:sub(1, #tostring(allyTeamID) + 1) == allyTeamID .. "_" and displayListKey ~= cacheKey then
			local keyTime = tonumber(displayListKey:sub(#tostring(allyTeamID) + 2))
			if keyTime and (timeRemaining - keyTime > 3 or keyTime - timeRemaining > 1) then
				table.insert(keysToDelete, displayListKey)
			end
		end
	end

	for _, deleteKey in ipairs(keysToDelete) do
		glDeleteList(allyTeamCountdownDisplayLists[deleteKey])
		allyTeamCountdownDisplayLists[deleteKey] = nil
	end

	allyTeamCountdownDisplayLists[cacheKey] = glCreateList(function()
		local countdownColor = COUNTDOWN_COLOR
		local countdownPositionX, countdownPositionY = calculateCountdownPosition(allyTeamID)

		if not countdownPositionX then return end

		local countdownFontSize = fontCache.fontSize * COUNTDOWN_FONT_SIZE_MULTIPLIER
		local layout = cache.data["layout_params"]
		if layout then
			local scaleFactor = layout.barHeight / BAR_HEIGHT
			countdownFontSize = max(10, countdownFontSize * scaleFactor)
		end

		local text = format("%d", timeRemaining)
		local adjustedCountdownPositionY = countdownPositionY - (countdownFontSize * 0.25)

		drawCountdownText(countdownPositionX, adjustedCountdownPositionY, text, countdownFontSize, countdownColor)
	end)

	return allyTeamCountdownDisplayLists[cacheKey]
end

local function updateDisplayLists()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	scorebarWidth = minimapSizeX - HALVED_ICON_SIZE

	local layoutChanged = updateLayoutCache()

	local allyTeamData = getAllyTeamDisplayData()

	needsScoreBarBackgroundUpdate = needsScoreBarBackgroundUpdate or not scoreBarBackgroundDisplayList or layoutChanged
	needsSelectionHaloUpdate = needsSelectionHaloUpdate or not selectionHaloDisplayList or layoutChanged or
	(amSpectating and lastSelectedAllyTeamID ~= selectedAllyTeamID)
	needsScoreBarUpdate = needsScoreBarUpdate or not scoreBarDisplayList or
	(currentTime - lastScoreBarUpdate > SCORE_BAR_UPDATE_THRESHOLD) or needsDisplayListUpdate()

	if needsScoreBarBackgroundUpdate then
		createSelectionHaloDisplayList(allyTeamData)
		createScoreBarBackgroundDisplayList(allyTeamData)
		needsScoreBarBackgroundUpdate = false
	end

	if needsSelectionHaloUpdate then
		createSelectionHaloDisplayList(allyTeamData)
		needsSelectionHaloUpdate = false
	end

	if needsScoreBarUpdate then
		createScoreBarDisplayList(allyTeamData)
		needsScoreBarUpdate = false
		lastScoreBarUpdate = currentTime
		updateTrackingVariables()
	end

	if layoutChanged or not compositeDisplayList then
		if compositeDisplayList then
			glDeleteList(compositeDisplayList)
		end

		compositeDisplayList = glCreateList(function()
			if selectionHaloDisplayList then
				glCallList(selectionHaloDisplayList)
			end
			if scoreBarBackgroundDisplayList then
				glCallList(scoreBarBackgroundDisplayList)
			end
			if scoreBarDisplayList then
				glCallList(scoreBarDisplayList)
			end
		end)
	end
end

local function updateCachedPauseStatus(forceUpdate)
	local currentGameTime = spGetGameSeconds()
	if not forceUpdate and currentGameTime == cachedPauseStatus.lastUpdate then
		return
	end

	cachedPauseStatus.pauseExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	cachedPauseStatus.isDefeatThresholdPaused = cachedPauseStatus.pauseExpirationTime > currentGameTime
	cachedPauseStatus.timeUntilUnpause = max(0, cachedPauseStatus.pauseExpirationTime - currentGameTime)
	cachedPauseStatus.lastUpdate = currentGameTime
end

local function updateCachedGameState()
	cachedGameState.defeatThreshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	cachedGameState.maxThreshold = getMaxThreshold()
	cachedGameState.lastUpdate = gameSeconds
end

local function cleanupDisplayLists()
	compositeDisplayList = cleanupDisplayList(compositeDisplayList)
	scoreBarDisplayList = cleanupDisplayList(scoreBarDisplayList)
	scoreBarBackgroundDisplayList = cleanupDisplayList(scoreBarBackgroundDisplayList)
	selectionHaloDisplayList = cleanupDisplayList(selectionHaloDisplayList)
	timerWarningDisplayList = cleanupDisplayList(timerWarningDisplayList)

	cleanupCountdowns()

	cache:clear()

	layoutCache.initialized = false
	scoreBarPositions = {}
end

local function queueTeleportSounds()
	soundQueue = {}
	if defeatTime and defeatTime > 0 then
		table.insert(soundQueue, 1, { when = defeatTime - WINDUP_SOUND_DURATION, sound = "cmd-off", volume = 0.4 })
		table.insert(soundQueue, 1,
			{ when = defeatTime - WINDUP_SOUND_DURATION, sound = "teleport-windup", volume = 0.225 })
	end
end

function widget:DrawScreen()
	if currentGameFrame <= 1 then
		return
	end

	local currentGameTime = spGetGameSeconds()

	if not compositeDisplayList then
		updateDisplayLists()
	end

	if compositeDisplayList then
		glCallList(compositeDisplayList)
	end

	local countdownsToRender = {}

	if amSpectating then
		for allyTeamID, allyDefeatTime in pairs(allyTeamDefeatTimes) do
			if allyDefeatTime and allyDefeatTime > 0 and gameSeconds and allyDefeatTime > gameSeconds then
				local timeRemaining = ceil(allyDefeatTime - gameSeconds)
				if timeRemaining >= 0 then
					local cacheKey = allyTeamID .. "_" .. timeRemaining
					countdownsToRender[cacheKey] = { allyTeamID = allyTeamID, timeRemaining = timeRemaining }
				end
			end
		end

		for cacheKey, countdownData in pairs(countdownsToRender) do
			if not allyTeamCountdownDisplayLists[cacheKey] then
				createCountdownDisplayList(countdownData.timeRemaining, countdownData.allyTeamID)
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
				local cacheKey = myAllyID .. "_" .. timeRemaining

				if not allyTeamCountdownDisplayLists[cacheKey] then
					createCountdownDisplayList(timeRemaining, myAllyID)
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
					updateDisplayLists()
				end
				return
			end
		end
		if selectedAllyTeamID ~= myAllyID then
			selectedAllyTeamID = myAllyID
			forceDisplayListUpdate()
			updateDisplayLists()
		end
	end
end

function widget:GameFrame(frame)
	currentGameFrame = frame
	gameSeconds = spGetGameSeconds() or 0

	updateCachedGameState()
	updateCachedPauseStatus(false)

	if frame % DEFEAT_CHECK_INTERVAL == AFTER_GADGET_TIMER_UPDATE_MODULO then
		updateAliveAllyTeams()

		local dataChanged = false
		local teamStatusChanged = false
		local rankChanged = false

		if amSpectating then
			for _, allyTeamID in ipairs(aliveAllyTeams) do
				if allyTeamID ~= gaiaAllyTeamID then
					local currentlyAlive = isAllyTeamAlive(allyTeamID)
					local wasAlive = lastAllyTeamScores[allyTeamID] ~= nil

					if currentlyAlive ~= wasAlive then
						teamStatusChanged = true
					end

					if currentlyAlive then
						local teamList = spGetTeamList(allyTeamID)
						local allyDefeatTime = 0

						if teamList and #teamList > 0 then
							local representativeTeamID = teamList[1]
							allyDefeatTime = spGetTeamRulesParam(representativeTeamID, "defeatTime") or 0

							local newRank = spGetTeamRulesParam(representativeTeamID, RANK_RULES_KEY)
							if newRank and lastTeamRanks[representativeTeamID] ~= newRank then
								rankChanged = true
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
			local newRank = spGetTeamRulesParam(myTeamID, RANK_RULES_KEY)

			if newRank and lastTeamRanks[myTeamID] ~= newRank then
				rankChanged = true
			end

			if newDefeatTime > 0 then
				if newDefeatTime ~= defeatTime then
					defeatTime = newDefeatTime
					loopSoundEndTime = defeatTime - WINDUP_SOUND_DURATION
					soundQueue = nil
					queueTeleportSounds()
					dataChanged = true
				end
			elseif defeatTime ~= 0 then
				defeatTime = 0
				loopSoundEndTime = 0
				soundQueue = nil
				soundIndex = 1
				dataChanged = true
			end
		end

		if teamStatusChanged then
			if amSpectating then
				for _, allyTeamID in ipairs(aliveAllyTeams) do
					if allyTeamID ~= gaiaAllyTeamID and not isAllyTeamAlive(allyTeamID) then
						cleanupCountdowns(allyTeamID)
					end
				end
			else
				local myTeamID = Spring.GetMyTeamID()
				local _, _, isDead = spGetTeamInfo(myTeamID, false)
				if isDead then
					cleanupCountdowns(myAllyID)
				end
			end

			cache:invalidate("spectator_teams")
			cache:invalidate("player_team")
			forceDisplayListUpdate()
		end

		if rankChanged or dataChanged then
			if rankChanged then
				cache:invalidate("spectator_teams")
				cache:invalidate("player_team")
			end
			needsScoreBarUpdate = true
		end

		if dataChanged or rankChanged or teamStatusChanged then
			lastUpdateTime = 0
		end
	end

	if cachedPauseStatus.isDefeatThresholdPaused then
		if frame % 30 == 0 then
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
				cleanupCountdowns()
			end
		end
		return
	end

	frameBasedUpdates.soundUpdate = frameBasedUpdates.soundUpdate + 1
	if frameBasedUpdates.soundUpdate >= 3 then
		frameBasedUpdates.soundUpdate = 0

		if loopSoundEndTime and loopSoundEndTime > gameSeconds then
			if lastLoop <= currentTime then
				lastLoop = currentTime

				local timeRange = loopSoundEndTime - (defeatTime - WINDUP_SOUND_DURATION - CHARGE_SOUND_LOOP_DURATION * 10)
				local timeLeft = loopSoundEndTime - gameSeconds
				local minVolume = 0.05
				local maxVolume = 0.2
				local volumeRange = maxVolume - minVolume

				local volumeFactor = 1 - (timeLeft / timeRange)
				volumeFactor = max(0, min(volumeFactor, 1))
				local currentVolume = minVolume + (volumeFactor * volumeRange)

				for unitID in pairs(myCommanders) do
					local xPosition, yPosition, zPosition = spGetUnitPosition(unitID)
					if xPosition then
						spPlaySoundFile("teleport-charge-loop", currentVolume, xPosition, yPosition, zPosition, 0, 0, 0,
							"sfx")
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

	frameBasedUpdates.teamScoreCheck = frameBasedUpdates.teamScoreCheck + 1
	if frameBasedUpdates.teamScoreCheck >= 15 then
		frameBasedUpdates.teamScoreCheck = 0
		if teamScoresChanged() then
			needsScoreBarUpdate = true
		end
	end

	if not amSpectating and defeatTime > gameSeconds then
		local timeRemaining = ceil(defeatTime - gameSeconds)
		local _, score = getRepresentativeTeamDataFromAllyTeam(myAllyID)
		local difference = score - cachedGameState.defeatThreshold

		if difference < 0 and gameSeconds >= lastTimerWarningTime + TIMER_COOLDOWN then
			local territoriesNeeded = abs(difference)
			spPlaySoundFile("warning1", 1)
			local dominatedMessage, conquerMessage = createTimerWarningMessage(timeRemaining, territoriesNeeded)
			timerWarningEndTime = gameSeconds + TIMER_WARNING_DISPLAY_TIME

			createTimerWarningDisplayList(dominatedMessage, conquerMessage)
			lastTimerWarningTime = gameSeconds
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

	updateLayoutCache()
	updateTrackingVariables()

	if not amSpectating then
		local teamData = getAllyTeamDisplayData()
		if #teamData > 0 then
			getBarPositionsCached(1)

			if teamData[1].teamID then
				getCachedTeamColor(teamData[1].teamID)
			end

			lastDifference = teamData[1].score - (spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0)
			if teamData[1].teamID then
				lastTeamRanks[teamData[1].teamID] = teamData[1].rank
			end
		else
			lastDifference = 0
		end
	end

	needsSelectionHaloUpdate = true
	needsScoreBarBackgroundUpdate = true
	needsScoreBarUpdate = true

	updateDisplayLists()

	local allUnits = spGetAllUnits()

	for _, unitID in ipairs(allUnits) do
		widget:MetaUnitAdded(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID), nil)
	end
	
	-- Initialize tooltip state
	-- Tooltip is now handled directly in Update function
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

local layoutUpdateTimer = 0
function widget:Update(deltaTime)
	currentTime = os.clock()

	local newAmSpectating = spGetSpectatingState()
	local newMyAllyID = spGetMyAllyTeamID()

	if not compositeDisplayList then
		forceDisplayListUpdate()
		updateDisplayLists()
		return
	end

	if newAmSpectating ~= amSpectating or newMyAllyID ~= myAllyID then
		amSpectating = newAmSpectating
		myAllyID = newMyAllyID
		scoreBarPositions = {}
		layoutCache.initialized = false

		cache:invalidate("spectator_teams")
		cache:invalidate("player_team")
		cache:invalidate("layout_params")

		cleanupCountdowns()
		forceDisplayListUpdate()
		updateDisplayLists()
		
		-- Hide tooltip when major state changes
		if WG['tooltip'] then
			WG['tooltip'].RemoveTooltip('territorialDomination')
		end
		
		return
	end

	updateCachedPauseStatus(false)

	if cachedPauseStatus.isDefeatThresholdPaused and cachedPauseStatus.timeUntilUnpause <= WARNING_SECONDS then
		local blinkPhase = (currentTime % BLINK_INTERVAL) / BLINK_INTERVAL
		local currentBlinkState = blinkPhase < 0.33
		if isSkullFaded ~= currentBlinkState then
			needsScoreBarUpdate = true
		end
	end

	layoutUpdateTimer = layoutUpdateTimer + deltaTime
	if layoutUpdateTimer >= LAYOUT_UPDATE_INTERVAL then
		layoutUpdateTimer = 0
		if updateLayoutCache() then
			needsScoreBarUpdate = true
		end
	end

	local needsUpdate = false
	local forceUpdate = false

	if currentTime - lastScoreBarUpdate > SCORE_BAR_UPDATE_THRESHOLD then
		if needsDisplayListUpdate() then
			needsScoreBarUpdate = true
			needsUpdate = true
		end
	end

	if currentTime - lastUpdateTime > UPDATE_FREQUENCY then
		lastUpdateTime = currentTime
		if currentTime - lastScoreBarUpdate > UPDATE_FREQUENCY then
			forceUpdate = true
		end
	end

	if manageCountdownUpdates() then
		needsUpdate = true
	end

	if needsUpdate or forceUpdate then
		updateDisplayLists()
	end
	
	-- Handle tooltip display
	if WG['tooltip'] then
		if isMouseOverAnyScoreBar() then
			WG['tooltip'].ShowTooltip('territorialDomination', spI18N('ui.territorialDomination.scoreBarTooltip'))
		else
			WG['tooltip'].RemoveTooltip('territorialDomination')
		end
	end
end

function widget:Shutdown()
	cleanupDisplayLists()
	
	-- Clean up tooltip
	if WG['tooltip'] then
		WG['tooltip'].RemoveTooltip('territorialDomination')
	end
end
