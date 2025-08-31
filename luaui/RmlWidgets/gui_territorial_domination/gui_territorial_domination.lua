if not RmlUi then
	return
end

local widget = widget

function widget:GetInfo()
	return {
		name = "Territorial Domination Score Display",
		desc = "Displays score bars for territorial domination game mode",
		author = "Mupersega",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local modOptions = Spring.GetModOptions()
if modOptions.deathmode ~= "territorial_domination" then return false end

if Spring.Utilities.Gametype.IsRaptors() or Spring.Utilities.Gametype.IsScavengers() then return false end

local MODEL_NAME = "territorial_score_model"
local RML_PATH = "luaui/RmlWidgets/gui_territorial_domination/gui_territorial_domination.rml"

local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetTeamList = Spring.GetTeamList
local spGetTeamColor = Spring.GetTeamColor
local spGetSpectatingState = Spring.GetSpectatingState
local spI18N = Spring.I18N
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetTeamInfo = Spring.GetTeamInfo

local DISPLAY_LIMIT = 8
local DEFAULT_MAX_ROUNDS = 7
local DEFAULT_POINTS_CAP = 100

local COLOR_MULTIPLIER = 255
local DEFAULT_COLOR_VALUE = 0.5
local DARK_COLOR_MULTIPLIER = 0.25
local BACKGROUND_COLOR_ALPHA = 204
local PROJECTED_COLOR_ALPHA = 100
local FILL_COLOR_ALPHA = 230

local SECONDS_PER_MINUTE = 60
local COUNTDOWN_ALERT_THRESHOLD = 60
local COUNTDOWN_WARNING_THRESHOLD = 10
local ROUND_END_POPUP_DELAY = 3
local POPUP_FADE_OUT_DURATION = 0.5
local DANGER_INITIAL_DURATION = 8

local UPDATE_INTERVAL = 0.5
local SCORE_UPDATE_INTERVAL = 2.0

local NON_SPECTATOR_LEFT = 1720
local NON_SPECTATOR_TOP = 44
local SPECTATOR_LEFT = 1609
local SPECTATOR_TOP = 44

local PERCENTAGE_MULTIPLIER = 100
local TIME_ZERO_STRING = "0:00"

local GAIA_ALLY_TEAM_ID = select(6, spGetTeamInfo(spGetGaiaTeamID()))

local widgetState = {
	document = nil,
	dmHandle = nil,
	rmlContext = nil,
	lastUpdateTime = 0,
	lastTimeUpdateTime = 0,
	lastScoreUpdateTime = 0,
	allyTeamData = {},
	scoreElements = {},
	displayedTeamIds = {},
	hiddenByLobby = false,
	isDocumentVisible = false,
	popupState = {
		isVisible = false,
		showTime = 0,
		fadeOutStartTime = nil,
	},
	dangerStates = {},
	cachedData = {
		allyTeams = {},
		roundInfo = {},
		lastTimeHash = "",
	},
	lastSpectatingState = nil,
	lastPointsCap = 0,
	lastRoundEndTime = 0,
	lastCurrentRound = 0,
	lastMaxRounds = 0,
	lastTimeRemaining = "",
	lastRoundDisplayText = "",
	lastCountdownWarning = false,
	lastAllyTeamCount = 0,
	lastTeamOrderHash = "",
	lastGameTime = 0,
	updateCounter = 0,
	lastTimeRemainingSeconds = 0,
}

local initialModel = {
	allyTeams = {},
	currentRound = 0,
	roundEndTime = 0,
	maxRounds = 0,
	pointsCap = 0,
	prevHighestScore = 0,
	timeRemaining = TIME_ZERO_STRING,
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
	if not widgetState.document then return end
	
	local rootElement = widgetState.document:GetElementById("td-root") or
		widgetState.document:GetElementById("score-container")
	if not rootElement then return end
	
	local isSpectating = select(1, spGetSpectatingState())
	if isSpectating == widgetState.lastSpectatingState then return end
	
	widgetState.lastSpectatingState = isSpectating
	local left, top = isSpectating and SPECTATOR_LEFT or NON_SPECTATOR_LEFT,
		isSpectating and SPECTATOR_TOP or NON_SPECTATOR_TOP
	
	rootElement:SetAttribute("style", string.format("left: %dpx; top: %dpx;", left, top))
end

local function createColorStyle(color, alpha)
	return string.format("rgba(%d, %d, %d, %d)",
		color.r * COLOR_MULTIPLIER, color.g * COLOR_MULTIPLIER, color.b * COLOR_MULTIPLIER, alpha)
end

local function createScoreBarElement(parentDiv, allyTeam)
	local document = widgetState.document
	
	local scoreBarDiv = document:CreateElement("div")
	scoreBarDiv.class_name = "td-bar"

	local containerDiv = document:CreateElement("div")
	containerDiv.class_name = "td-bar__track"

	local backgroundDiv = document:CreateElement("div")
	backgroundDiv.class_name = "td-bar__background"
	local darkColor = {
		r = math.floor(allyTeam.color.r * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		g = math.floor(allyTeam.color.g * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		b = math.floor(allyTeam.color.b * DARK_COLOR_MULTIPLIER * COLOR_MULTIPLIER),
		a = BACKGROUND_COLOR_ALPHA
	}
	backgroundDiv:SetAttribute("style", "background-color: rgba(" .. darkColor.r .. "," .. darkColor.g .. "," .. darkColor.b .. "," .. darkColor.a .. ")")

	local projectedDiv = document:CreateElement("div")
	projectedDiv.class_name = "td-bar__projected"
	projectedDiv.id = "projected-fill-" .. tostring(allyTeam.allyTeamID)
	projectedDiv:SetAttribute("style", "background-color: " .. createColorStyle(allyTeam.color, PROJECTED_COLOR_ALPHA))

	local fillDiv = document:CreateElement("div")
	fillDiv.class_name = "td-bar__fill"
	fillDiv.id = "score-fill-" .. tostring(allyTeam.allyTeamID)
	fillDiv:SetAttribute("style", "background-color: " .. createColorStyle(allyTeam.color, FILL_COLOR_ALPHA))

	local currentScoreText = document:CreateElement("div")
	currentScoreText.class_name = "td-text current"
	currentScoreText.id = "current-score-" .. tostring(allyTeam.allyTeamID)
	currentScoreText.inner_rml = tostring(allyTeam.score)

	local projectedScoreText = document:CreateElement("div")
	projectedScoreText.class_name = "td-text projected"
	projectedScoreText.id = "projected-score-" .. tostring(allyTeam.allyTeamID)
	projectedScoreText.inner_rml = "+" .. tostring(allyTeam.projectedPoints)

	local dangerOverlay = document:CreateElement("div")
	dangerOverlay.class_name = "td-danger"
	dangerOverlay.id = "danger-overlay-" .. tostring(allyTeam.allyTeamID)
	dangerOverlay.inner_rml = spI18N('ui.territorialDomination.danger')

	local dangerInitialOverlay = document:CreateElement("div")
	dangerInitialOverlay.class_name = "td-danger-initial"
	dangerInitialOverlay.id = "danger-initial-overlay-" .. tostring(allyTeam.allyTeamID)
	dangerInitialOverlay.inner_rml = spI18N('ui.territorialDomination.danger')

	containerDiv:AppendChild(backgroundDiv)
	containerDiv:AppendChild(projectedDiv)
	containerDiv:AppendChild(fillDiv)
	containerDiv:AppendChild(currentScoreText)
	containerDiv:AppendChild(projectedScoreText)
	containerDiv:AppendChild(dangerOverlay)
	containerDiv:AppendChild(dangerInitialOverlay)

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
		dangerInitialOverlay = dangerInitialOverlay,
		lastFillWidth = nil,
		lastProjectedWidth = nil,
		lastScoreText = nil,
		lastProjectedText = nil,
		lastTrackClass = nil,
		lastDangerClass = nil,
		lastDangerText = nil,
		lastDangerInitialClass = nil,
		lastEliminated = nil,
	}
end

local function createDataHash(data)
	if type(data) == "table" then
		local hash = ""
		if #data > 0 then
			for i = 1, math.min(#data, 10) do
				local item = data[i]
				if type(item) == "table" and item.score and item.projectedPoints then
					hash = hash .. tostring(item.score) .. ":" .. tostring(item.projectedPoints) .. "|"
				end
			end
		end
		return hash
	end
	return tostring(data)
end

local function createTeamOrderHash(allyTeams)
	local hash = ""
	for i = 1, math.min(#allyTeams, 8) do
		local team = allyTeams[i]
		hash = hash .. tostring(team.allyTeamID) .. ":" .. tostring(team.score) .. "|"
	end
	return hash
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
	if #allyTeams < 2 then return false end

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
		local maxRounds = (widgetState.dmHandle and widgetState.dmHandle.maxRounds) or DEFAULT_MAX_ROUNDS
		if roundNumber == maxRounds then
			popupText = spI18N('ui.territorialDomination.roundOverPopup.finalRound')
		else
			popupText = spI18N('ui.territorialDomination.roundOverPopup.round', { roundNumber = roundNumber })
		end
	end

	popupTextElement.inner_rml = popupText
	popupElement.class_name = "round-end-popup visible"
	widgetState.popupState.isVisible = true
	widgetState.popupState.showTime = os.clock()
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
		if allyTeamID == GAIA_ALLY_TEAM_ID then 
			-- Skip GAIA team
		else
			local teamList = spGetTeamList(allyTeamID)
			if teamList and #teamList > 0 then
				local firstTeamID = teamList[1]
				local score = spGetTeamRulesParam(firstTeamID, "territorialDominationScore") or 0
				local projectedPoints = spGetTeamRulesParam(firstTeamID, "territorialDominationProjectedPoints") or 0
				
				local hasAliveTeam = false
				for j = 1, #teamList do
					local _, _, isDead = spGetTeamInfo(teamList[j])
					if not isDead then
						hasAliveTeam = true
						break
					end
				end

				table.insert(validAllyTeams, {
					name = spI18N('ui.territorialDomination.team.ally', { allyNumber = allyTeamID + 1 }),
					allyTeamID = allyTeamID,
					firstTeamID = firstTeamID,
					score = score,
					projectedPoints = projectedPoints,
					color = getAllyTeamColor(allyTeamID),
					rank = spGetTeamRulesParam(firstTeamID, "territorialDominationDisplayRank") or 1,
					teamCount = #teamList,
					isAlive = hasAliveTeam,
					teamList = teamList,
				})
			end
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
	local maxRounds = spGetGameRulesParam("territorialDominationMaxRounds") or DEFAULT_MAX_ROUNDS

	local highestPlayerCombinedScore = 0
	if widgetState.allyTeamData and #widgetState.allyTeamData > 0 then
		local topTeam = widgetState.allyTeamData[1]
		highestPlayerCombinedScore = topTeam.score + topTeam.projectedPoints
	end

	local pointsCap = math.max(gameRulesPointsCap, highestPlayerCombinedScore)

	local timeString = TIME_ZERO_STRING
	local timeRemainingSeconds = 0
	local isCountdownWarning = false

	if roundEndTime > 0 then
		timeRemainingSeconds = math.max(0, roundEndTime - Spring.GetGameSeconds())
		timeString = string.format("%d:%02d", math.floor(timeRemainingSeconds / SECONDS_PER_MINUTE),
			math.floor(timeRemainingSeconds % SECONDS_PER_MINUTE))
		if timeRemainingSeconds < 1 then timeString = TIME_ZERO_STRING end
	end

	isCountdownWarning = (currentRound > maxRounds) or (timeRemainingSeconds <= COUNTDOWN_ALERT_THRESHOLD)

	local roundDisplayText
	if currentRound > maxRounds then
		roundDisplayText = spI18N('ui.territorialDomination.round.overtime')
	elseif currentRound == 0 then
		roundDisplayText = ""
	elseif currentRound == maxRounds then
		roundDisplayText = spI18N('ui.territorialDomination.round.finalRound')
	else
		roundDisplayText = spI18N('ui.territorialDomination.round.displayWithMax',
			{ currentRound = currentRound, maxRounds = maxRounds })
	end

	local isFinalRound = currentRound >= maxRounds and timeRemainingSeconds <= 0

	return {
		currentRound = currentRound,
		roundEndTime = roundEndTime,
		maxRounds = maxRounds,
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
	local currentRoundParam = spGetGameRulesParam("territorialDominationCurrentRound") or 0
	local maxRoundsParam = (widgetState.dmHandle and widgetState.dmHandle.maxRounds) or DEFAULT_MAX_ROUNDS
	local inOvertime = currentRoundParam > maxRoundsParam
	local dataModel = widgetState.dmHandle
	local timeSecs = (dataModel and dataModel.timeRemainingSeconds) or 0
	local hasTimeInfo = timeElement.inner_rml and (timeSecs > 0 or inOvertime)

	headerElement:SetClass("hidden", not (hasRoundInfo or hasTimeInfo))
	roundElement:SetClass("hidden", not hasRoundInfo)
	timeElement:SetClass("hidden", not hasTimeInfo)
end

local function updateCountdownColor()
	if not widgetState.document then return end

	local timeDisplayElement = widgetState.document:GetElementById("time-display")
	if not timeDisplayElement then return end

	local dataModel = widgetState.dmHandle
	if dataModel and dataModel.isCountdownWarning then
		local timeRemaining = dataModel.timeRemainingSeconds or 0
		local isAlert = timeRemaining <= COUNTDOWN_ALERT_THRESHOLD
		local isWarning = timeRemaining <= COUNTDOWN_WARNING_THRESHOLD
		timeDisplayElement:SetClass("warning", isAlert)
		timeDisplayElement:SetClass("pulsing", isWarning)
	else
		timeDisplayElement:SetClass("warning", false)
		timeDisplayElement:SetClass("pulsing", false)
	end
	timeDisplayElement:SetAttribute("style", "")
end

local function getDisplayedTeams()
	local allyTeams = widgetState.allyTeamData
	if not allyTeams or #allyTeams == 0 then return {} end

	local limit = math.min(#allyTeams, DISPLAY_LIMIT)
	local myAllyTeamID = Spring.GetMyAllyTeamID()

	local livingTeams = {}
	local deadTeams = {}
	for i = 1, #allyTeams do
		local teamInfo = allyTeams[i]
		if teamInfo.isAlive then
			livingTeams[#livingTeams + 1] = teamInfo
		else
			deadTeams[#deadTeams + 1] = teamInfo
		end
	end

	local function sortByScoreDesc(a, b)
		if (a.score or 0) ~= (b.score or 0) then
			return (a.score or 0) > (b.score or 0)
		end
		return a.allyTeamID < b.allyTeamID
	end
	
	if #livingTeams > 1 then table.sort(livingTeams, sortByScoreDesc) end
	if #deadTeams > 1 then table.sort(deadTeams, sortByScoreDesc) end

	local displayed = {}
	for i = 1, math.min(#livingTeams, limit) do
		displayed[#displayed + 1] = livingTeams[i]
	end
	
	if #displayed < limit then
		local remaining = limit - #displayed
		for i = 1, math.min(#deadTeams, remaining) do
			displayed[#displayed + 1] = deadTeams[i]
		end
	end

	local function containsAlly(list, allyTeamID)
		for i = 1, #list do 
			if list[i].allyTeamID == allyTeamID then return true end 
		end
		return false
	end

	if myAllyTeamID and not containsAlly(displayed, myAllyTeamID) then
		local myTeam
		for i = 1, #allyTeams do
			if allyTeams[i].allyTeamID == myAllyTeamID then
				myTeam = allyTeams[i]
				break
			end
		end
		
		if myTeam then
			if #displayed < limit then
				displayed[#displayed + 1] = myTeam
			else
				displayed[#displayed] = myTeam
			end
		end
	end

	return displayed
end

local function updateScoreBarVisuals()
	if not widgetState.document then return end

	local dataModel = widgetState.dmHandle
	local allyTeams = getDisplayedTeams()
	local columnsContainer = widgetState.document:GetElementById("td-scores") or
		widgetState.document:GetElementById("score-columns")
	if not columnsContainer then return end

	local numTeams = #allyTeams
	if numTeams == 0 then return end

	local newTeamOrderHash = createTeamOrderHash(allyTeams)
	if newTeamOrderHash == widgetState.lastTeamOrderHash and #allyTeams == widgetState.lastAllyTeamCount then
		return
	end

	widgetState.lastTeamOrderHash = newTeamOrderHash
	widgetState.lastAllyTeamCount = #allyTeams

	columnsContainer.inner_rml = ""
	widgetState.scoreElements = {}
	for i = 1, #allyTeams do
		local elements = createScoreBarElement(columnsContainer, allyTeams[i])
		widgetState.scoreElements[i] = elements
	end

	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local myScoreRank = nil
	for i = 1, #widgetState.allyTeamData do
		local team = widgetState.allyTeamData[i]
		if team.allyTeamID == myAllyTeamID then
			myScoreRank = spGetTeamRulesParam(team.firstTeamID, "territorialDominationDisplayRank") or team.rank or 1
			break
		end
	end

	local insertedSpacer = false
	local existingSpacer = widgetState.document:GetElementById("rank-spacer")
	if existingSpacer then
		columnsContainer:RemoveChild(existingSpacer)
	end

	for i, allyTeam in ipairs(allyTeams) do
		local scoreBarElements = widgetState.scoreElements[i]
		if scoreBarElements then
			if not insertedSpacer and myScoreRank and myScoreRank > DISPLAY_LIMIT and allyTeam.allyTeamID == myAllyTeamID then
				local spacer = widgetState.document:CreateElement("div")
				spacer.class_name = "td-rank-spacer"
				spacer.id = "rank-spacer"
				spacer.inner_rml = spI18N('ui.territorialDomination.rank', { rank = myScoreRank })
				columnsContainer:InsertBefore(spacer, scoreBarElements.container)
				insertedSpacer = true
			end

			local projectedWidth = "0%"
			if dataModel.pointsCap > 0 then
				local totalProjected = allyTeam.score + allyTeam.projectedPoints
				projectedWidth = string.format("%.1f%%",
					math.min(PERCENTAGE_MULTIPLIER, (totalProjected / dataModel.pointsCap) * PERCENTAGE_MULTIPLIER))
			end

			scoreBarElements.projectedElement:SetAttribute("style", "width: " .. projectedWidth)
			scoreBarElements.lastProjectedWidth = projectedWidth

			local fillWidth = "0%"
			if dataModel.pointsCap > 0 then
				fillWidth = string.format("%.1f%%",
					math.min(PERCENTAGE_MULTIPLIER, (allyTeam.score / dataModel.pointsCap) * PERCENTAGE_MULTIPLIER))
			end

			scoreBarElements.fillElement:SetAttribute("style", "width: " .. fillWidth)
			scoreBarElements.lastFillWidth = fillWidth

			scoreBarElements.currentScoreElement.inner_rml = tostring(allyTeam.score)
			scoreBarElements.lastScoreText = tostring(allyTeam.score)
			
			scoreBarElements.projectedScoreElement.inner_rml = "+" .. tostring(allyTeam.projectedPoints)
			scoreBarElements.lastProjectedText = "+" .. tostring(allyTeam.projectedPoints)

			local isPlayersTeam = allyTeam.allyTeamID == myAllyTeamID
			local desiredClass = isPlayersTeam and "td-bar__track selected" or "td-bar__track"
			scoreBarElements.trackElement.class_name = desiredClass
			scoreBarElements.lastTrackClass = desiredClass

			local prevHighest = dataModel.prevHighestScore or 0
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
			local isPlayersTeamDanger = (allyTeam.allyTeamID == myAllyTeamID)
			local state = widgetState.dangerStates[allyTeam.allyTeamID]
			
			if not state then
				state = { wasInDanger = false, initialActive = false, initialEndTime = 0 }
				widgetState.dangerStates[allyTeam.allyTeamID] = state
			end

			if eliminated then
				local classBase = "td-danger visible defeated"
				scoreBarElements.dangerOverlay.class_name = classBase
				scoreBarElements.lastDangerClass = classBase
				
				local defeatedText = spI18N('ui.territorialDomination.defeated')
				scoreBarElements.dangerOverlay.inner_rml = defeatedText
				scoreBarElements.lastDangerText = defeatedText
				
				if scoreBarElements.dangerInitialOverlay then
					scoreBarElements.dangerInitialOverlay.class_name = "td-danger-initial"
					scoreBarElements.lastDangerInitialClass = "td-danger-initial"
				end
				state.wasInDanger = false
				state.initialActive = false
				state.initialEndTime = 0
				scoreBarElements.lastEliminated = true
			elseif shouldShowDanger then
				local classBase = "td-danger visible"
				scoreBarElements.dangerOverlay.class_name = classBase
				scoreBarElements.lastDangerClass = classBase
				
				local desiredText = spI18N('ui.territorialDomination.danger')
				scoreBarElements.dangerOverlay.inner_rml = desiredText
				scoreBarElements.lastDangerText = desiredText
				
				if scoreBarElements.dangerInitialOverlay then
					if isPlayersTeamDanger then
						if not state.wasInDanger then
							local initClass = "td-danger-initial visible"
							scoreBarElements.dangerInitialOverlay.class_name = initClass
							scoreBarElements.lastDangerInitialClass = initClass
							
							local desiredInitText = spI18N('ui.territorialDomination.danger')
							scoreBarElements.dangerInitialOverlay.inner_rml = desiredInitText
							
							state.initialActive = true
							state.initialEndTime = os.clock() + DANGER_INITIAL_DURATION
							state.wasInDanger = true
						else
							if state.initialActive and os.clock() >= state.initialEndTime then
								scoreBarElements.dangerInitialOverlay.class_name = "td-danger-initial"
								scoreBarElements.lastDangerInitialClass = "td-danger-initial"
								state.initialActive = false
							end
						end
					else
						scoreBarElements.dangerInitialOverlay.class_name = "td-danger-initial"
						scoreBarElements.lastDangerInitialClass = "td-danger-initial"
						state.wasInDanger = true
						state.initialActive = false
						state.initialEndTime = 0
					end
				end
				scoreBarElements.lastEliminated = false
			else
				scoreBarElements.dangerOverlay.class_name = "td-danger"
				scoreBarElements.lastDangerClass = "td-danger"
				
				if scoreBarElements.dangerInitialOverlay then
					scoreBarElements.dangerInitialOverlay.class_name = "td-danger-initial"
					scoreBarElements.lastDangerInitialClass = "td-danger-initial"
				end
				state.wasInDanger = false
				state.initialActive = false
				state.initialEndTime = 0
				scoreBarElements.lastEliminated = false
			end
		end
	end
end

local function resetCache()
	widgetState.cachedData = {
		allyTeams = {},
		roundInfo = {},
		lastTimeHash = "",
	}
	widgetState.lastTeamOrderHash = ""
	widgetState.lastAllyTeamCount = 0
end

local function shouldSkipUpdate()
	local currentTime = Spring.GetGameSeconds()
	
	if currentTime <= 0 then return true end
	if not widgetState.document or widgetState.hiddenByLobby or not widgetState.isDocumentVisible then return true end
	
	local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
	if pointsCap <= 0 then return true end
	
	if currentTime == widgetState.lastGameTime then return true end
	
	widgetState.lastGameTime = currentTime
	return false
end

local function shouldUpdateScores()
	local currentTime = Spring.GetGameSeconds()
	return currentTime - widgetState.lastScoreUpdateTime >= SCORE_UPDATE_INTERVAL
end

local function shouldUpdateTime()
	local currentTime = Spring.GetGameSeconds()
	local roundEndTime = spGetGameRulesParam("territorialDominationRoundEndTimestamp") or 0
	
	if roundEndTime <= 0 then return false end
	
	local timeRemaining = math.max(0, roundEndTime - currentTime)
	local currentDisplayedSeconds = math.floor(timeRemaining)
	local lastDisplayedSeconds = math.floor(widgetState.lastTimeRemainingSeconds or 0)
	
	return currentDisplayedSeconds ~= lastDisplayedSeconds
end

local function shouldFullUpdate()
	local currentTime = Spring.GetGameSeconds()
	return currentTime - widgetState.lastUpdateTime >= UPDATE_INTERVAL
end

local function checkDocumentVisibility()
	local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
	
	if pointsCap ~= widgetState.lastPointsCap then
		widgetState.lastPointsCap = pointsCap
		
		if pointsCap and pointsCap > 0 then
			if widgetState.document and not widgetState.hiddenByLobby and not widgetState.isDocumentVisible then
				widgetState.document:Show()
				widgetState.isDocumentVisible = true
			end
		else
			if widgetState.document and widgetState.isDocumentVisible then
				widgetState.document:Hide()
				widgetState.isDocumentVisible = false
			end
		end
	end
end

local function updateDataModel()
	if not widgetState.dmHandle then return end

	checkDocumentVisibility()
	
	local allyTeams = updateAllyTeamData()
	local roundInfo = updateRoundInfo()
	local dataModel = widgetState.dmHandle

	local previousRound = dataModel.currentRound or 0
	local previousTimeRemaining = dataModel.timeRemainingSeconds or 0

	local scoresChanged = hasDataChanged(allyTeams, widgetState.cachedData, "allyTeams")
	local roundChanged = hasDataChanged(roundInfo, widgetState.cachedData, "roundInfo")
	local timeChanged = hasDataChanged(math.floor(roundInfo.timeRemainingSeconds or 0), widgetState.cachedData, "lastTimeHash")

	if roundChanged and (dataModel.currentRound or 0) ~= roundInfo.currentRound then
		resetCache()
		scoresChanged = true
		roundChanged = true
	end

	if scoresChanged or roundChanged then
		dataModel.allyTeams = allyTeams
		dataModel.currentRound = roundInfo.currentRound
		dataModel.roundEndTime = roundInfo.roundEndTime
		dataModel.maxRounds = roundInfo.maxRounds
		dataModel.pointsCap = roundInfo.pointsCap
		dataModel.prevHighestScore = roundInfo.prevHighestScore
		dataModel.timeRemaining = roundInfo.timeRemaining
		dataModel.roundDisplayText = roundInfo.roundDisplayText
		dataModel.timeRemainingSeconds = roundInfo.timeRemainingSeconds
		dataModel.isCountdownWarning = roundInfo.isCountdownWarning
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
		end

		if roundInfo.isFinalRound and previousTimeRemaining > 0 and roundInfo.timeRemainingSeconds <= 0 then
			showRoundEndPopup(roundInfo.currentRound, true)
		elseif previousRound ~= roundInfo.currentRound and previousRound > 0 then
			showRoundEndPopup(roundInfo.currentRound, false)
		end
	end
end

local function updateTimeOnly()
	if not widgetState.document then return end
	
	local roundInfo = updateRoundInfo()
	local timeChanged = hasDataChanged(math.floor(roundInfo.timeRemainingSeconds or 0), widgetState.cachedData, "lastTimeHash")
	
	if timeChanged and widgetState.dmHandle then
		widgetState.dmHandle.timeRemainingSeconds = roundInfo.timeRemainingSeconds
		widgetState.dmHandle.isCountdownWarning = roundInfo.isCountdownWarning
		widgetState.dmHandle.timeRemaining = roundInfo.timeRemaining
		updateCountdownColor()
		
		-- Store the last displayed seconds for smooth countdown
		widgetState.lastTimeRemainingSeconds = roundInfo.timeRemainingSeconds
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
	if not widgetState.hiddenByLobby and Spring.GetGameSeconds() > 0 then
		document:Show()
		widgetState.isDocumentVisible = true
	end

	resetCache()
	widgetState.lastUpdateTime = Spring.GetGameSeconds()
	widgetState.lastScoreUpdateTime = Spring.GetGameSeconds()
	widgetState.lastTimeUpdateTime = Spring.GetGameSeconds()

	calculateUILayout()
	if Spring.GetGameSeconds() > 0 then
		updateDataModel()
		updateCountdownColor()
	end
	updateHeaderVisibility()

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
		if currentOSClock - widgetState.popupState.fadeOutStartTime >= POPUP_FADE_OUT_DURATION then
			completePopupFadeOut()
		end
	end

	if shouldSkipUpdate() then return end

	widgetState.updateCounter = widgetState.updateCounter + 1
	
	if shouldFullUpdate() or shouldUpdateScores() then
		updateDataModel()
		widgetState.lastScoreUpdateTime = currentTime
		widgetState.lastUpdateTime = currentTime
	elseif shouldUpdateTime() then
		updateTimeOnly()
		widgetState.lastTimeUpdateTime = currentTime
	end
end

function widget:DrawScreen()
	if Spring.GetGameSeconds() <= 0 then
		return
	end
end
