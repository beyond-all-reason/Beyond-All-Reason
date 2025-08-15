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

if 1 == 1 then return false end

local modOptions = Spring.GetModOptions()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) then return false end

local floor = math.floor
local ceil = math.ceil
local format = string.format
local max = math.max
local min = math.min

local spGetViewGeometry = Spring.GetViewGeometry
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetGameSeconds = Spring.GetGameSeconds
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
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
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local WINDUP_SOUND_DURATION = 2
local CHARGE_SOUND_LOOP_DURATION = 4.7

local PADDING_MULTIPLIER = 0.36
local MINIMAP_GAP = 4
local BORDER_WIDTH = 2
local ICON_SIZE = 25
local HALVED_ICON_SIZE = ICON_SIZE / 2
local BAR_HEIGHT = 16
local TEXT_OUTLINE_OFFSET = 1.0
local TEXT_OUTLINE_ALPHA = 0.6
local HALO_EXTENSION = 4
local HALO_MAX_ALPHA = 0.4

local SCORE_RULES_KEY = "territorialDominationScore"

local COLOR_WHITE = { 1, 1, 1, 1 }
local COLOR_BACKGROUND = { 0, 0, 0, 0.8 }
local COLOR_BORDER = { 0.3, 0.3, 0.3, 0.9 }
local COLOR_GREY_LINE = { 0.7, 0.7, 0.7, 0.7 }

local myCommanders = {}
local soundQueue = {}
local allyTeamDefeatTimes = {}
local aliveAllyTeams = {}
local scoreBarPositions = {}

local myAllyID = -1
local selectedAllyTeamID = -1
local gaiaAllyTeamID = -1
local lastUpdateTime = 0
local lastScore = -1
local scorebarWidth = 300
local lineWidth = 2
local currentTime = os.clock()
local defeatTime = 0
local gameSeconds = 0
local lastLoop = 0
local loopSoundEndTime = 0
local soundIndex = 1
local currentGameFrame = 0

local lastScorebarWidth = -1
local lastMinimapDimensions = { -1, -1, -1 }
local lastSelectedAllyTeamID = -1
local pointsCap = 100

local compositeDisplayList = nil
local scoreBarDisplayList = nil
local scoreBarBackgroundDisplayList = nil
local selectionHaloDisplayList = nil

local needsScoreBarBackgroundUpdate = false
local needsScoreBarUpdate = false
local needsSelectionHaloUpdate = false

local SCORE_BAR_UPDATE_THRESHOLD = 0.5
local LAYOUT_UPDATE_INTERVAL = 2.0
local UPDATE_FREQUENCY = 4.0
local DEFEAT_CHECK_INTERVAL = Game.gameSpeed
local AFTER_GADGET_TIMER_UPDATE_MODULO = 3
local lastLayoutUpdate = 0
local lastScoreBarUpdate = 0

local frameBasedUpdates = {
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
		local displayTeams = aliveAllyTeams
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

local function getCachedTintedColor(baseColor, tintColor, strength)
	local cacheKey = format(CACHE_KEYS.TINTED_COLOR, baseColor[1] .. "_" .. tintColor[1] .. "_" .. strength)
	return cache:getOrCompute(cacheKey, function()
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

local function createGradientVertices(left, right, bottom, top, topColor, bottomColor)
	return {
		{ v = { left, bottom }, c = bottomColor },
		{ v = { right, bottom }, c = bottomColor },
		{ v = { right, top },  c = topColor },
		{ v = { left, top },   c = topColor }
	}
end

local function drawBarFill(fillLeft, fillRight, fillBottom, fillTop, barColor)
	local topColor = { barColor[1], barColor[2], barColor[3], barColor[4] }
	local bottomColor = { barColor[1] * 0.7, barColor[2] * 0.7, barColor[3] * 0.7, barColor[4] }

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

local function drawScoreLineIndicator(linePos, scorebarBottom, scorebarTop)
	local lineExtension = 3
	local lineColor = COLOR_GREY_LINE

	glColor(0, 0, 0, 0.8)
	glRect(linePos - lineWidth - 1, scorebarBottom - lineExtension,
		linePos + lineWidth + 1, scorebarTop + lineExtension)

	glColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glRect(linePos - lineWidth / 2, scorebarBottom - lineExtension,
		linePos + lineWidth / 2, scorebarTop + lineExtension)
end

local function drawScoreBar(scorebarLeft, scorebarRight, scorebarBottom, scorebarTop, score, projectedPoints, barColor)
	local barWidth = scorebarRight - scorebarLeft
	local borderSize = 3

	local fillPaddingLeft = scorebarLeft + borderSize
	local fillPaddingTop = scorebarTop
	local fillPaddingBottom = scorebarBottom + borderSize

	local scaleScore = pointsCap > 0 and pointsCap or 1

	local currentScoreWidth = (score / scaleScore) * barWidth
	local currentScoreRight = fillPaddingLeft + currentScoreWidth
	
	if currentScoreWidth > 0 then
		drawBarFill(fillPaddingLeft, currentScoreRight, fillPaddingBottom, fillPaddingTop, barColor)
		drawGlossEffects(fillPaddingLeft, currentScoreRight, fillPaddingBottom, fillPaddingTop)
	end

	if projectedPoints > 0 then
		local projectedWidth = (projectedPoints / scaleScore) * barWidth
		local projectedLeft = currentScoreRight
		local projectedRight = projectedLeft + projectedWidth
		
		local projectedColor = {
			barColor[1] * 0.6,
			barColor[2] * 0.6,
			barColor[3] * 0.6,
			barColor[4] * 0.8
		}
		
		drawBarFill(projectedLeft, projectedRight, fillPaddingBottom, fillPaddingTop, projectedColor)
	end

	local linePos = fillPaddingLeft + currentScoreWidth
	drawScoreLineIndicator(linePos, scorebarBottom, scorebarTop)

	return linePos, scorebarRight
end

local function getRepresentativeTeamDataFromAllyTeam(allyTeamID)
	local teamList = spGetTeamList(allyTeamID)
	if not teamList or #teamList == 0 then
		return nil, 0, 0
	end

	local representativeTeamID = teamList[1]
	
	local score = spGetTeamRulesParam(representativeTeamID, SCORE_RULES_KEY) or 0
	local projectedPoints = spGetTeamRulesParam(representativeTeamID, "territorialDominationProjectedPoints") or 0

	return representativeTeamID, score, projectedPoints
end

local function getAllyTeamDisplayData()
	return cache:getOrCompute("all_teams", function()
		local allyTeamScores = {}

		for _, allyTeamID in ipairs(aliveAllyTeams) do
			local teamID, score, projectedPoints = getRepresentativeTeamDataFromAllyTeam(allyTeamID)
			local teamColor = { 1, 1, 1, 1 }
			local defeatTimeRemaining = 0

			if teamID then
				local redComponent, greenComponent, blueComponent = spGetTeamColor(teamID)
				teamColor = { redComponent, greenComponent, blueComponent, 1 }
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
				teamID = teamID,
				defeatTimeRemaining = defeatTimeRemaining,
				projectedPoints = projectedPoints
			})
		end

		table.sort(allyTeamScores, function(a, b)
			if a.score == b.score then
				return a.defeatTimeRemaining > b.defeatTimeRemaining
			end
			return a.score > b.score
		end)

		return allyTeamScores
	end, CACHE_TTL.NORMAL)
end

local function updateLastValues(score, scorebarWidth, minimapDimensions, selectedAllyTeamID)
	if score ~= nil then lastScore = score end
	if scorebarWidth ~= nil then lastScorebarWidth = scorebarWidth end
	if minimapDimensions ~= nil then lastMinimapDimensions = minimapDimensions end
	if selectedAllyTeamID ~= nil then lastSelectedAllyTeamID = selectedAllyTeamID end
end

local function needsDisplayListUpdate()
	if not fontCache.initialized then
		return true
	end

	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()

	local currentScore

	local cachedData = cache.data["all_teams"]
	if not cachedData or #cachedData == 0 then
		return true
	end
	local firstTeam = cachedData[1]
	currentScore = firstTeam.score

	local hasChanged = lastScore ~= currentScore
		or lastScorebarWidth ~= scorebarWidth
		or lastMinimapDimensions[1] ~= minimapPosX
		or lastMinimapDimensions[2] ~= minimapPosY
		or lastMinimapDimensions[3] ~= minimapSizeX
		or lastSelectedAllyTeamID ~= selectedAllyTeamID

	if hasChanged then
		updateLastValues(currentScore, scorebarWidth, { minimapPosX, minimapPosY, minimapSizeX }, selectedAllyTeamID)
		return true
	end

	return false
end

local function updatePointsCap()
	local newPointsCap = spGetGameRulesParam("territorialDominationPointsCap") or 100
	if newPointsCap ~= pointsCap then
		pointsCap = newPointsCap
		needsScoreBarUpdate = true
	end
end

local function updateLayoutCache()
	if currentTime - lastLayoutUpdate < LAYOUT_UPDATE_INTERVAL and layoutCache.initialized then
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
			cache:invalidate("all_teams")
		end

		scoreBarPositions = {}

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

local function createSelectionHaloDisplayList(allyTeamData)
	if selectionHaloDisplayList then
		glDeleteList(selectionHaloDisplayList)
	end

	selectionHaloDisplayList = glCreateList(function()
		if selectedAllyTeamID == gaiaAllyTeamID or selectedAllyTeamID == -1 then
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

				-- Use solid colors for debugging
				glColor(0.2, 0.2, 0.2, 0.9)
				glRect(barPosition.scorebarLeft - BORDER_WIDTH, barPosition.scorebarBottom - BORDER_WIDTH,
					barPosition.scorebarRight + BORDER_WIDTH, barPosition.scorebarTop + BORDER_WIDTH)

				glColor(0, 0, 0, 0.8)
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
		for allyTeamIndex, allyTeamDataEntry in ipairs(allyTeamData) do
			local barPosition = getBarPositionsCached(allyTeamIndex)

			drawScoreBar(barPosition.scorebarLeft, barPosition.scorebarRight, barPosition.scorebarBottom,
				barPosition.scorebarTop, allyTeamDataEntry.score, allyTeamDataEntry.projectedPoints, allyTeamDataEntry.teamColor)

			local scoreText = tostring(allyTeamDataEntry.score or 0)
			local fontSize = barPosition.fontSize
			drawTextWithOutline(scoreText, barPosition.scorebarLeft + 3, barPosition.textY, fontSize, "l", COLOR_WHITE)

			local projectedText = "+" .. (allyTeamDataEntry.projectedPoints or 0)
			drawTextWithOutline(projectedText, barPosition.innerRight, barPosition.textY, fontSize, "r", COLOR_WHITE)
		end
	end)
end

local function updateDisplayLists()
	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	scorebarWidth = minimapSizeX - HALVED_ICON_SIZE

	local layoutChanged = updateLayoutCache()

	local allyTeamData = getAllyTeamDisplayData()

	needsScoreBarBackgroundUpdate = needsScoreBarBackgroundUpdate or not scoreBarBackgroundDisplayList or layoutChanged
	needsSelectionHaloUpdate = needsSelectionHaloUpdate or not selectionHaloDisplayList or layoutChanged or
	(lastSelectedAllyTeamID ~= selectedAllyTeamID)
	needsScoreBarUpdate = needsScoreBarUpdate or not scoreBarDisplayList or
	(currentTime - lastScoreBarUpdate > SCORE_BAR_UPDATE_THRESHOLD) or needsDisplayListUpdate()

	if needsScoreBarBackgroundUpdate then
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
	end

	if layoutChanged or not compositeDisplayList then
		if compositeDisplayList then
			glDeleteList(compositeDisplayList)
		end

		compositeDisplayList = glCreateList(function()
			if scoreBarBackgroundDisplayList then
				glCallList(scoreBarBackgroundDisplayList)
			end
			if selectionHaloDisplayList then
				glCallList(selectionHaloDisplayList)
			end
			if scoreBarDisplayList then
				glCallList(scoreBarDisplayList)
			end
		end)
	end
end

local function cleanupDisplayLists()
	compositeDisplayList = cleanupDisplayList(compositeDisplayList)
	scoreBarDisplayList = cleanupDisplayList(scoreBarDisplayList)
	scoreBarBackgroundDisplayList = cleanupDisplayList(scoreBarBackgroundDisplayList)
	selectionHaloDisplayList = cleanupDisplayList(selectionHaloDisplayList)

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

	if currentGameFrame % 30 == 0 then
		needsScoreBarUpdate = true
	end

	if not compositeDisplayList then
		updateDisplayLists()
	end

	if compositeDisplayList then
		glCallList(compositeDisplayList)
	end
end

function widget:PlayerChanged()
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

function widget:GameFrame(frame)
	currentGameFrame = frame
	gameSeconds = spGetGameSeconds() or 0

	if frame % DEFEAT_CHECK_INTERVAL == AFTER_GADGET_TIMER_UPDATE_MODULO then
		updateAliveAllyTeams()
		
		cache:invalidate("all_teams")

		local dataChanged = false

		for _, allyTeamID in ipairs(aliveAllyTeams) do
			if allyTeamID ~= gaiaAllyTeamID then
				local teamList = spGetTeamList(allyTeamID)
				if teamList and #teamList > 0 then
					local representativeTeamID = teamList[1]
					local allyDefeatTime = spGetTeamRulesParam(representativeTeamID, "defeatTime") or 0
					
					if allyTeamDefeatTimes[allyTeamID] ~= allyDefeatTime then
						allyTeamDefeatTimes[allyTeamID] = allyDefeatTime
						dataChanged = true
					end
				end
			end
		end

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
		elseif defeatTime ~= 0 then
			defeatTime = 0
			loopSoundEndTime = 0
			soundQueue = nil
			soundIndex = 1
			dataChanged = true
		end

		if dataChanged then
			needsScoreBarUpdate = true
			lastUpdateTime = 0
		end
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
end

function widget:Initialize()
	myAllyID = spGetMyAllyTeamID()
	selectedAllyTeamID = myAllyID
	gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID()))

	gameSeconds = spGetGameSeconds() or 0
	defeatTime = 0

	updateLayoutCache()
	updatePointsCap()

	local teamData = getAllyTeamDisplayData()
	if #teamData > 0 then
		for i = 1, #teamData do
			getBarPositionsCached(i)

			if teamData[i].teamID then
				getCachedTeamColor(teamData[i].teamID)
			end
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

	local newMyAllyID = spGetMyAllyTeamID()

	if not compositeDisplayList then
		forceDisplayListUpdate()
		updateDisplayLists()
		return
	end

	if newMyAllyID ~= myAllyID then
		myAllyID = newMyAllyID
		scoreBarPositions = {}
		layoutCache.initialized = false

		cache:invalidate("all_teams")
		cache:invalidate("layout_params")

		forceDisplayListUpdate()
		updateDisplayLists()
		
		if WG['tooltip'] then
			WG['tooltip'].RemoveTooltip('territorialDomination')
		end
		
		return
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
		updatePointsCap()
		if currentTime - lastScoreBarUpdate > UPDATE_FREQUENCY then
			forceUpdate = true
		end
	end

	if needsUpdate or forceUpdate then
		updateDisplayLists()
	end
	
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
	
	if WG['tooltip'] then
		WG['tooltip'].RemoveTooltip('territorialDomination')
	end
end