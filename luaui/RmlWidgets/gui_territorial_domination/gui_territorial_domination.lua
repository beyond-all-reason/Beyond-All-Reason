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

--need who am I indicator
-- defeatTime needs to be removed now that defeat is instaneous
-- game crashes when there's lots of allies in the same team. Either its infinite memory growth, a div by zero or an invalid key stored
-- for some reason  the score display isn't correct, we're getting more points sometimes than we are entitled to.
-- game_territorial_domination.lua the defeat isn't triggering for some reason and killing the team off
local modOptions = Spring.GetModOptions()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) then
	return false
end

if Spring.Utilities.Gametype.IsRaptors() or Spring.Utilities.Gametype.IsScavengers() then
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
local spGetSpectatingState = Spring.GetSpectatingState
local spI18N = Spring.I18N
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetTeamInfo = Spring.GetTeamInfo

local SCREEN_HEIGHT = 1080
local BACKGROUND_COLOR_ALPHA = 204
local DEFAULT_POINTS_CAP = 100
local PROJECTED_COLOR_ALPHA = 100
local PERCENTAGE_MULTIPLIER = 100
local FILL_COLOR_ALPHA = 230
local COLOR_MULTIPLIER = 255
local DEFAULT_COLOR_VALUE = 0.5
local DARK_COLOR_MULTIPLIER = 0.25
local UPDATE_INTERVAL = 0.1
local TIME_UPDATE_INTERVAL = 0.5
local SCORE_UPDATE_INTERVAL = 1.0
local SECONDS_PER_MINUTE = 60
local COUNTDOWN_WARNING_THRESHOLD = 60
local ROUND_END_POPUP_DELAY = 3
local GAIA_ALLY_TEAM_ID = select(6, spGetTeamInfo(spGetGaiaTeamID()))

local widgetState = {
	document = nil,
	dmHandle = nil,
	rmlContext = nil,
	lastUpdateTime = 0,
	lastTimeUpdateTime = 0,
	lastScoreUpdateTime = 0,
	updateInterval = UPDATE_INTERVAL,
	timeUpdateInterval = TIME_UPDATE_INTERVAL,
	scoreUpdateInterval = SCORE_UPDATE_INTERVAL,
	allyTeamData = {},
	lastMinimapGeometry = { 0, 0, 0, 0 },
	scoreElements = {},
	scoreElementsByTeamId = {},
	displayedTeamIds = {},
	hiddenByLobby = false,
	isDocumentVisible = false,

	popupState = {
		isVisible = false,
		showTime = 0,
		roundNumber = 0,
		isFinalRound = false,
		playerIsFirst = false,
		isSpectating = false,
		fadeOutStartTime = nil,
	},
	cachedData = {
		allyTeams = {},
		roundInfo = {},
		lastUpdateHash = "",
		lastScoreHash = "",
		lastRoundHash = "",
		lastTimeHash = "",
	},
}

local initialModel = {
	allyTeams = {},
	currentRound = 0,
	roundEndTime = 0,
	pointsCap = 0,
	prevHighestScore = 0,
	timeRemaining = "0:00",
	roundDisplayText = "",
	timeRemainingSeconds = 0,
	isCountdownWarning = false,
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

local function isPlayerInFirstPlace()
	local myTeamID = Spring.GetMyTeamID()
	if myTeamID == nil then return false end
	
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	if myAllyTeamID == nil then return false end
	
	local allyTeams = widgetState.allyTeamData
	if #allyTeams == 0 then return false end
	
	return allyTeams[1].allyTeamID == myAllyTeamID
end

local function calculateUILayout()
	local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY = spGetMiniMapGeometry()
	local currentGeometry = { minimapPosX, minimapPosY, minimapSizeX, minimapSizeY }
	if currentGeometry[1] == widgetState.lastMinimapGeometry[1]
		and currentGeometry[2] == widgetState.lastMinimapGeometry[2]
		and currentGeometry[3] == widgetState.lastMinimapGeometry[3]
		and currentGeometry[4] == widgetState.lastMinimapGeometry[4] then
		return
	end
	widgetState.lastMinimapGeometry = currentGeometry

	local left = minimapPosX
	local top = SCREEN_HEIGHT - minimapPosY

	if widgetState.document then
		local rootElement = widgetState.document:GetElementById("td-root") or widgetState.document:GetElementById("score-container")
		if rootElement then
			rootElement:SetAttribute("style", string.format("left: %dpx; top: %dpx;", left, top))
		end
	end
end

local function createScoreBarElement(parentDiv, allyTeam, index)
	local scoreBarDiv = widgetState.document:CreateElement("div")
	scoreBarDiv.class_name = "td-bar"

	local containerDiv = widgetState.document:CreateElement("div")
	containerDiv.class_name = "td-bar__track"

	local backgroundDiv = widgetState.document:CreateElement("div")
	backgroundDiv.class_name = "td-bar__background"

	local darkBackgroundColor = {
		r = math.floor(allyTeam.color.r * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		g = math.floor(allyTeam.color.g * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		b = math.floor(allyTeam.color.b * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		a = BACKGROUND_COLOR_ALPHA
	}
	backgroundDiv:SetAttribute("style", string.format("background-color: rgba(%d, %d, %d, %d)",
		darkBackgroundColor.r, darkBackgroundColor.g, darkBackgroundColor.b, darkBackgroundColor.a))

	local projectedDiv = widgetState.document:CreateElement("div")
	projectedDiv.class_name = "td-bar__projected"
	projectedDiv.id = "projected-fill-" .. tostring(allyTeam.allyTeamID)
local projectedColor = string.format("rgba(%d, %d, %d, %d)",
		allyTeam.color.r * COLOR_MULTIPLIER, allyTeam.color.g * COLOR_MULTIPLIER, allyTeam.color.b * COLOR_MULTIPLIER,
		PROJECTED_COLOR_ALPHA)
	projectedDiv:SetAttribute("style", "background-color: " .. projectedColor)

	local fillDiv = widgetState.document:CreateElement("div")
	fillDiv.class_name = "td-bar__fill"
	fillDiv.id = "score-fill-" .. tostring(allyTeam.allyTeamID)
local fillColor = string.format("rgba(%d, %d, %d, %d)",
		allyTeam.color.r * COLOR_MULTIPLIER, allyTeam.color.g * COLOR_MULTIPLIER, allyTeam.color.b * COLOR_MULTIPLIER,
		FILL_COLOR_ALPHA)
	fillDiv:SetAttribute("style", "background-color: " .. fillColor)

	local currentScoreText = widgetState.document:CreateElement("div")
	currentScoreText.class_name = "td-text current"
	currentScoreText.id = "current-score-" .. tostring(allyTeam.allyTeamID)
	currentScoreText.inner_rml = tostring(allyTeam.score)

	local projectedScoreText = widgetState.document:CreateElement("div")
	projectedScoreText.class_name = "td-text projected"
	projectedScoreText.id = "projected-score-" .. tostring(allyTeam.allyTeamID)
	projectedScoreText.inner_rml = "+" .. tostring(allyTeam.projectedPoints)

	local dangerOverlay = widgetState.document:CreateElement("div")
	dangerOverlay.class_name = "td-danger"
	dangerOverlay.id = "danger-overlay-" .. tostring(allyTeam.allyTeamID)
	dangerOverlay.inner_rml = spI18N('ui.territorialDomination.danger')

	containerDiv:AppendChild(backgroundDiv)
	containerDiv:AppendChild(projectedDiv)
	containerDiv:AppendChild(fillDiv)
	containerDiv:AppendChild(currentScoreText)
	containerDiv:AppendChild(projectedScoreText)
	containerDiv:AppendChild(dangerOverlay)

	scoreBarDiv:AppendChild(containerDiv)
	parentDiv:AppendChild(scoreBarDiv)

	return {
		container = scoreBarDiv,
		trackElement = containerDiv,
		currentScoreElement = currentScoreText,
		projectedScoreElement = projectedScoreText,
		projectedElement = projectedDiv,
		fillElement = fillDiv,
		dangerOverlay = dangerOverlay,
		lastFillWidth = nil,
		lastProjectedWidth = nil,
		lastSelectionStyle = nil,
		lastScoreText = nil,
		lastProjectedText = nil,
	}
end
local function createDataHash(data)
	if type(data) == "table" then
		local hash = ""
		local isArray = (#data > 0)
		if isArray then
			for i = 1, #data do
				hash = hash .. createDataHash(data[i])
			end
		else
			local keys = {}
			for k in pairs(data) do
				keys[#keys + 1] = k
			end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			for i = 1, #keys do
				local k = keys[i]
				local v = data[k]
				if type(v) == "table" then
					hash = hash .. tostring(k) .. createDataHash(v)
				else
					hash = hash .. tostring(k) .. tostring(v)
				end
			end
		end
		return hash
	end
	return tostring(data)
end

local function hasDataChanged(newData, cacheTable, cacheKey)
	local newHash = createDataHash(newData)
	if cacheTable[cacheKey] ~= newHash then
		cacheTable[cacheKey] = newHash
		return true
	end
	return false
end

local function isTie()
	local allyTeams = widgetState.allyTeamData
	if #allyTeams < 2 then
		return false
	end
	
	local topTeam = allyTeams[1]
	local topCombinedScore = topTeam.score + topTeam.projectedPoints
	
	for i = 2, #allyTeams do
		local otherTeam = allyTeams[i]
		local otherCombinedScore = otherTeam.score + otherTeam.projectedPoints
		if otherCombinedScore == topCombinedScore then
			return true
		end
	end
	
	return false
end

local function showRoundEndPopup(roundNumber, isFinalRound)
	if not widgetState.document then return end
	
	local popupElement = widgetState.document:GetElementById("round-end-popup")
	local popupTextElement = widgetState.document:GetElementById("popup-text")
	if not popupElement or not popupTextElement then return end
	
	local popupText = ""
	if isFinalRound then
		if isTie() then
			popupText = spI18N('ui.territorialDomination.round.overtime')
		elseif spGetSpectatingState() then
			popupText = spI18N('ui.territorialDomination.roundOverPopup.gameOver')
		elseif isPlayerInFirstPlace() then
			popupText = spI18N('ui.territorialDomination.roundOverPopup.victory')
		else
			popupText = spI18N('ui.territorialDomination.roundOverPopup.defeat')
		end
	elseif roundNumber > 0 then
		popupText = spI18N('ui.territorialDomination.roundOverPopup.round', { roundNumber = roundNumber })
	else
		popupText = ""
	end
	
	popupTextElement.inner_rml = popupText
	
	popupElement.class_name = "round-end-popup visible"
	
	widgetState.popupState.isVisible = true
	widgetState.popupState.showTime = os.clock()
	widgetState.popupState.roundNumber = roundNumber
	widgetState.popupState.isFinalRound = isFinalRound
	widgetState.popupState.playerIsFirst = isPlayerInFirstPlace()
	widgetState.popupState.isSpectating = spGetSpectatingState()
end

local function completePopupFadeOut()
	if not widgetState.document then return end
	
	local popupElement = widgetState.document:GetElementById("round-end-popup")
	if popupElement then
		popupElement.class_name = "round-end-popup"
	end
	widgetState.popupState.fadeOutStartTime = nil
end

local function hideRoundEndPopup()
	if not widgetState.document then return end
	
	local popupElement = widgetState.document:GetElementById("round-end-popup")
	if not popupElement then return end
	
	popupElement.class_name = "round-end-popup fade-out"
	widgetState.popupState.fadeOutStartTime = os.clock()
	widgetState.popupState.isVisible = false
end

local function updateAllyTeamData()
	local allyTeamList = spGetAllyTeamList()
	local validAllyTeams = {}

	for i = 1, #allyTeamList do
		local allyTeamID = allyTeamList[i]
		local teamList = spGetTeamList(allyTeamID)

		if teamList and #teamList > 0 and allyTeamID ~= GAIA_ALLY_TEAM_ID then
			local firstTeamID = teamList[1]
			local score = spGetTeamRulesParam(firstTeamID, "territorialDominationScore") or 0
			local projectedPoints = spGetTeamRulesParam(firstTeamID, "territorialDominationProjectedPoints") or 0
			
			
			table.insert(validAllyTeams, {
				name = spI18N('ui.territorialDomination.team.ally', { allyNumber = allyTeamID + 1 }),
				allyTeamID = allyTeamID,
				firstTeamID = firstTeamID,
				score = score,
				projectedPoints = projectedPoints,
				color = getAllyTeamColor(allyTeamID),
				rank = spGetTeamRulesParam(firstTeamID, "territorialDominationRank") or 1,
				teamCount = #teamList,
			})
		end
	end

	table.sort(validAllyTeams, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		local aCombinedScore = a.score + a.projectedPoints
		local bCombinedScore = b.score + b.projectedPoints
		if aCombinedScore ~= bCombinedScore then
			return aCombinedScore > bCombinedScore
		end
		return a.allyTeamID < b.allyTeamID
	end)

	widgetState.allyTeamData = validAllyTeams
	return validAllyTeams
end

local function updateRoundInfo()
	local roundEndTime = spGetGameRulesParam("territorialDominationRoundEndTimestamp") or 0
	local gameRulesPointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
	local prevHighestScore = spGetGameRulesParam("territorialDominationPrevHighestScore") or 0

	local currentRound = spGetGameRulesParam("territorialDominationCurrentRound") or 0
	local maxRounds = spGetGameRulesParam("territorialDominationMaxRounds") or 7

	local highestPlayerCombinedScore = 0
	if widgetState.allyTeamData and #widgetState.allyTeamData > 0 then
		local topTeam = widgetState.allyTeamData[1]
		highestPlayerCombinedScore = topTeam.score + topTeam.projectedPoints
	end

	local pointsCap = math.max(gameRulesPointsCap, highestPlayerCombinedScore)

	local timeString = "0:00"
	local timeRemainingSeconds = 0
	local isCountdownWarning = false
	
	local roundDisplayText 
	if currentRound > maxRounds then 
		roundDisplayText = spI18N('ui.territorialDomination.round.overtime')
	elseif currentRound == 0 then
		roundDisplayText = ""
	else
		roundDisplayText = spI18N('ui.territorialDomination.round.displayWithMax', { currentRound = currentRound, maxRounds = maxRounds })
	end
	
	if roundEndTime > 0 then
		timeRemainingSeconds = math.max(0, roundEndTime - Spring.GetGameSeconds())
		timeString = string.format("%d:%02d", math.floor(timeRemainingSeconds / SECONDS_PER_MINUTE), math.floor(timeRemainingSeconds % SECONDS_PER_MINUTE))
	end
	
	if currentRound > maxRounds then
		isCountdownWarning = true
	elseif timeRemainingSeconds <= COUNTDOWN_WARNING_THRESHOLD then
		isCountdownWarning = true
	end

	local isFinalRound = currentRound >= maxRounds and timeRemainingSeconds <= 0

	return {
		currentRound = currentRound,
		roundEndTime = roundEndTime,
		pointsCap = pointsCap,
		prevHighestScore = prevHighestScore,
		timeRemaining = timeString,
		roundDisplayText = roundDisplayText,
		timeRemainingSeconds = timeRemainingSeconds,
		isCountdownWarning = isCountdownWarning,
		isFinalRound = isFinalRound,
	}
end

local function updateHeaderVisibility()
	if not widgetState.document then return end
	
	local headerElement = widgetState.document:GetElementById("header-info")
	local roundElement = widgetState.document:GetElementById("round-display")
	local timeElement = widgetState.document:GetElementById("time-display")
	if not headerElement or not roundElement or not timeElement then return end
	
	local hasRoundInfo = roundElement.inner_rml and roundElement.inner_rml ~= ""
	local hasTimeInfo = timeElement.inner_rml and timeElement.inner_rml ~= "0:00"
	
	if hasRoundInfo or hasTimeInfo then
		headerElement.class_name = "header-info"
		roundElement.class_name = hasRoundInfo and "round-display" or "round-display hidden"
		timeElement.class_name = hasTimeInfo and "time-display" or "time-display hidden"
	else
		headerElement.class_name = "header-info hidden"
		roundElement.class_name = "round-display hidden"
		timeElement.class_name = "time-display hidden"
	end
end

local function updatePlayerRank()
	if not widgetState.document then return end
	local playerRankElement = widgetState.document:GetElementById("player-rank")
	if not playerRankElement then return end
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local myRank = nil
	for i = 1, #widgetState.allyTeamData do
		local t = widgetState.allyTeamData[i]
		if t.allyTeamID == myAllyTeamID then
			myRank = spGetTeamRulesParam(t.firstTeamID, "territorialDominationRank") or t.rank or 1
			break
		end
	end
	playerRankElement.inner_rml = myRank and (spI18N('ui.territorialDomination.rank', { rank = myRank })) or ""
end

local function updateCountdownColor()
	if not widgetState.document then return end
	
	local timeDisplayElement = widgetState.document:GetElementById("time-display")
	if not timeDisplayElement then return end
	
	local dm = widgetState.dmHandle
	if dm and dm.isCountdownWarning then
		local timeRemaining = dm.timeRemainingSeconds or 0
		
		local newClassName
		if timeRemaining <= 10 then
			newClassName = "time-display warning pulsing critical"
		else
			newClassName = "time-display warning pulsing"
		end
		
		if timeDisplayElement.class_name ~= newClassName then
			timeDisplayElement.class_name = newClassName
		end
	else
		local baseClassName = "time-display"
		if timeDisplayElement.class_name:find("hidden") then
			baseClassName = "time-display hidden"
		end
		
		if timeDisplayElement.class_name ~= baseClassName then
			timeDisplayElement.class_name = baseClassName
		end
	end
end

local function getDisplayedTeams()
	local allyTeams = widgetState.allyTeamData
	if not allyTeams or #allyTeams == 0 then return {} end
	local displayed = {}
	local used = {}
	local limit = math.min(#allyTeams, 6)
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local myIndex
	for i = 1, #allyTeams do
		if allyTeams[i].allyTeamID == myAllyTeamID then
			myIndex = i
			break
		end
	end
	displayed[#displayed + 1] = allyTeams[1]
	used[allyTeams[1].allyTeamID] = true
	if not myIndex then
		for i = 2, math.min(#allyTeams, limit) do
			displayed[#displayed + 1] = allyTeams[i]
		end
		return displayed
	end
	if myIndex == 1 then
		for i = 2, #allyTeams do
			if #displayed >= limit then break end
			local at = allyTeams[i]
			if not used[at.allyTeamID] then
				displayed[#displayed + 1] = at
				used[at.allyTeamID] = true
			end
		end
		return displayed
	end
	local availableAbove = math.max(0, myIndex - 2)
	local availableBelow = math.max(0, #allyTeams - myIndex)
	local aboveTake = math.min(2, availableAbove)
	local belowTake = math.min(2, availableBelow)
	if aboveTake < 2 then
		local add = math.min(2 - aboveTake, math.max(0, availableBelow - belowTake))
		belowTake = belowTake + add
	end
	if belowTake < 2 then
		local add = math.min(2 - belowTake, math.max(0, availableAbove - aboveTake))
		aboveTake = aboveTake + add
	end
	local startAbove = myIndex - aboveTake
	if startAbove < 2 then startAbove = 2 end
	for i = startAbove, myIndex - 1 do
		if #displayed >= limit then break end
		local at = allyTeams[i]
		if at and not used[at.allyTeamID] then
			displayed[#displayed + 1] = at
			used[at.allyTeamID] = true
		end
	end
	if #displayed < limit and not used[allyTeams[myIndex].allyTeamID] then
		displayed[#displayed + 1] = allyTeams[myIndex]
		used[allyTeams[myIndex].allyTeamID] = true
	end
	local endBelow = math.min(#allyTeams, myIndex + belowTake)
	for i = myIndex + 1, endBelow do
		if #displayed >= limit then break end
		local at = allyTeams[i]
		if at and not used[at.allyTeamID] then
			displayed[#displayed + 1] = at
			used[at.allyTeamID] = true
		end
	end
	if #displayed < limit then
		for i = 2, #allyTeams do
			if #displayed >= limit then break end
			local at = allyTeams[i]
			if not used[at.allyTeamID] then
				displayed[#displayed + 1] = at
				used[at.allyTeamID] = true
			end
		end
	end
	return displayed
end

local function updateScoreBarVisuals()
	if not widgetState.document then return end

	local dm = widgetState.dmHandle
	local allyTeams = getDisplayedTeams()
	local columnsContainer = widgetState.document:GetElementById("td-scores") or widgetState.document:GetElementById("score-columns")
	if not columnsContainer then return end

	local numTeams = #allyTeams
	if numTeams == 0 then return end

	-- Determine whether to rebuild (any set or order change) to avoid engine instability from re-append operations
	local oldIds = widgetState.displayedTeamIds
	local newIds = {}
	for i = 1, numTeams do newIds[i] = allyTeams[i].allyTeamID end

	local identicalOrder = (#oldIds == #newIds)
	if identicalOrder then
		for i = 1, #newIds do if oldIds[i] ~= newIds[i] then identicalOrder = false break end end
	end

	if not identicalOrder then
		columnsContainer.inner_rml = ""
		widgetState.scoreElements = {}
		widgetState.scoreElementsByTeamId = {}
		for i = 1, #newIds do
			local id = newIds[i]
			local at
			for j = 1, #allyTeams do if allyTeams[j].allyTeamID == id then at = allyTeams[j] break end end
			if at then
				local el = createScoreBarElement(columnsContainer, at, i)
				widgetState.scoreElements[i] = el
				widgetState.scoreElementsByTeamId[id] = el
			end
		end
		widgetState.displayedTeamIds = newIds

	end

	for i, allyTeam in ipairs(allyTeams) do
		local scoreBarElements = widgetState.scoreElements[i]
		if scoreBarElements then
			local projectedWidth = "0%"
			if dm.pointsCap > 0 then
				local totalProjected = allyTeam.score + allyTeam.projectedPoints
				projectedWidth = string.format("%.1f%%",
					math.min(PERCENTAGE_MULTIPLIER, (totalProjected / dm.pointsCap) * PERCENTAGE_MULTIPLIER))
			end

			if scoreBarElements.lastProjectedWidth ~= projectedWidth then
				scoreBarElements.projectedElement:SetAttribute("style","width: " .. projectedWidth)
				scoreBarElements.lastProjectedWidth = projectedWidth
			end

			local fillWidth = "0%"
			if dm.pointsCap > 0 then
				fillWidth = string.format("%.1f%%",
					math.min(PERCENTAGE_MULTIPLIER, (allyTeam.score / dm.pointsCap) * PERCENTAGE_MULTIPLIER))
			end

			if scoreBarElements.lastFillWidth ~= fillWidth then
				scoreBarElements.fillElement:SetAttribute("style", "width: " .. fillWidth)
				scoreBarElements.lastFillWidth = fillWidth
			end

			if scoreBarElements.currentScoreElement then
				local newScoreText = tostring(allyTeam.score)
				if scoreBarElements.lastScoreText ~= newScoreText then
					scoreBarElements.currentScoreElement.inner_rml = newScoreText
					scoreBarElements.lastScoreText = newScoreText
				end
			end
			if scoreBarElements.projectedScoreElement then
				local newProjectedText = "+" .. tostring(allyTeam.projectedPoints)
				if scoreBarElements.lastProjectedText ~= newProjectedText then
					scoreBarElements.projectedScoreElement.inner_rml = newProjectedText
					scoreBarElements.lastProjectedText = newProjectedText
				end
			end

			-- draw white border on selected ally only
			if scoreBarElements.trackElement and scoreBarElements.container then
				local isPlayersTeam = allyTeam.allyTeamID == Spring.GetMyAllyTeamID()
				local desiredClass = isPlayersTeam and "td-bar__track selected" or "td-bar__track"
				if scoreBarElements.trackElement.class_name ~= desiredClass then
					scoreBarElements.trackElement.class_name = desiredClass
				end
			end

			if scoreBarElements.dangerOverlay then
				local prevHighest = dm.prevHighestScore or 0
				local combinedScore = (allyTeam.score or 0) + (allyTeam.projectedPoints or 0)
				local eliminated = false
				if allyTeam.firstTeamID then
					local isDead = select(3, spGetTeamInfo(allyTeam.firstTeamID))
					if isDead then
						eliminated = true
					else
						local defeatTime = spGetTeamRulesParam(allyTeam.firstTeamID, "defeatTime")
						if defeatTime and defeatTime > 0 then eliminated = true end
						local tdElim = spGetTeamRulesParam(allyTeam.firstTeamID, "territorialDominationEliminated")
						if tdElim and tdElim == 1 then eliminated = true end
					end
				end
				local shouldShowDanger = (not eliminated) and prevHighest > 0 and combinedScore < prevHighest
				local newClassName = shouldShowDanger and "td-danger visible" or "td-danger"
				if scoreBarElements.dangerOverlay.class_name ~= newClassName then
					scoreBarElements.dangerOverlay.class_name = newClassName
				end
			end
		end
	end

end

local function resetCache()
	widgetState.cachedData = {
		allyTeams = {},
		roundInfo = {},
		lastUpdateHash = "",
		lastScoreHash = "",
		lastRoundHash = "",
		lastTimeHash = "",
	}
end

local function updateDataModel()
	if not widgetState.dmHandle then return end

	local allyTeams = updateAllyTeamData()
	local roundInfo = updateRoundInfo()
	local dm = widgetState.dmHandle

	local previousRound = dm.currentRound or 0
	local previousTimeRemaining = dm.timeRemainingSeconds or 0

	local scoresChanged = hasDataChanged(allyTeams, widgetState.cachedData, "allyTeams")
	local roundChanged = hasDataChanged(roundInfo, widgetState.cachedData, "roundInfo")
	local timeChanged = hasDataChanged(roundInfo.timeRemainingSeconds, widgetState.cachedData, "lastTimeHash")

	if roundChanged and (dm.currentRound or 0) ~= roundInfo.currentRound then
		resetCache()
		scoresChanged = true
		roundChanged = true
	end

	if scoresChanged or roundChanged then
		dm.allyTeams = allyTeams
		dm.currentRound = roundInfo.currentRound
		dm.roundEndTime = roundInfo.roundEndTime
		dm.pointsCap = roundInfo.pointsCap
		dm.prevHighestScore = roundInfo.prevHighestScore
		dm.timeRemaining = roundInfo.timeRemaining
		dm.roundDisplayText = roundInfo.roundDisplayText
		dm.timeRemainingSeconds = roundInfo.timeRemainingSeconds
		dm.isCountdownWarning = roundInfo.isCountdownWarning
	end

	calculateUILayout()

	if widgetState.document then
		if scoresChanged or roundChanged then
			updateScoreBarVisuals()
		end
		
		if timeChanged then
			updateCountdownColor()
		end
		
		if roundChanged then
			updateHeaderVisibility()
			updatePlayerRank()
		end
		
		if roundInfo.isFinalRound and previousTimeRemaining > 0 and roundInfo.timeRemainingSeconds <= 0 then
			showRoundEndPopup(roundInfo.currentRound, true)
		elseif previousRound ~= roundInfo.currentRound and previousRound > 0 then
			showRoundEndPopup(previousRound, false)
		end
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
	if not widgetState.hiddenByLobby then
		document:Show()
		widgetState.isDocumentVisible = true
	end

	resetCache()
	widgetState.lastUpdateTime = Spring.GetGameSeconds()
	widgetState.lastScoreUpdateTime = Spring.GetGameSeconds()
	widgetState.lastTimeUpdateTime = Spring.GetGameSeconds()

	calculateUILayout()
	updateDataModel()
	updateCountdownColor()
	updateHeaderVisibility()
	updatePlayerRank()

	return true
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		if widgetState.document then
			if not widgetState.isDocumentVisible then
				widgetState.document:Show()
				widgetState.isDocumentVisible = true
			end
			widgetState.hiddenByLobby = false
		end
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		if widgetState.document then
			hideRoundEndPopup()
			if widgetState.isDocumentVisible then
				widgetState.document:Hide()
				widgetState.isDocumentVisible = false
			end
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
		hideRoundEndPopup()
		widgetState.document:Close()
		widgetState.document = nil
	end

	widgetState.rmlContext = nil
	widgetState.scoreElements = {}
	widgetState.popupState.fadeOutStartTime = nil
end

function widget:Update()
	local currentTime = Spring.GetGameSeconds()
	local currentOSClock = os.clock()


	
	if widgetState.popupState.isVisible then
		if currentOSClock - widgetState.popupState.showTime >= ROUND_END_POPUP_DELAY then
			hideRoundEndPopup()
		end
	elseif widgetState.popupState.fadeOutStartTime then
		if currentOSClock - widgetState.popupState.fadeOutStartTime >= 0.5 then
			completePopupFadeOut()
		end
	end
	
	local shouldUpdateScores = currentTime - widgetState.lastScoreUpdateTime >= widgetState.scoreUpdateInterval
	
	local shouldUpdateTime = currentTime - widgetState.lastTimeUpdateTime >= widgetState.timeUpdateInterval
	
	local shouldFullUpdate = currentTime - widgetState.lastUpdateTime >= widgetState.updateInterval

	-- no halo debounce
	
	if shouldFullUpdate or shouldUpdateScores or shouldUpdateTime then
		local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
		if pointsCap and pointsCap > 0 then
			if widgetState.document and not widgetState.hiddenByLobby and not widgetState.isDocumentVisible then
				widgetState.document:Show()
				widgetState.isDocumentVisible = true
			end
			
			if widgetState.document then
				if shouldFullUpdate or shouldUpdateScores then
					updateDataModel()
					widgetState.lastScoreUpdateTime = currentTime
				elseif shouldUpdateTime then
					local roundInfo = updateRoundInfo()
					local timeChanged = hasDataChanged(roundInfo.timeRemainingSeconds, widgetState.cachedData, "lastTimeHash")
					if timeChanged and widgetState.document then
						updateCountdownColor()
					end
					widgetState.lastTimeUpdateTime = currentTime
				end
			end
			
			if shouldFullUpdate then
				widgetState.lastUpdateTime = currentTime
			end
		else
			if widgetState.document and widgetState.isDocumentVisible then
				widgetState.document:Hide()
				widgetState.isDocumentVisible = false
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

