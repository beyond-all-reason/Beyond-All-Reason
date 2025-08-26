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

--danger being displayed when all scores are 0
-- the score display isn't consistent with the order when changing player perspectives as a spectator.
-- need a "who am I" indicator. maybe a halo now that I know how the other bug was resolved
-- rank display?
-- the countdown is blinking red from white instead of pulsing red. It's possible that we are updating it constantly

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
	displayedTeamIds = {},
	hiddenByLobby = false,
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
	highestScore = 0,
	secondHighestScore = 0,
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
	projectedDiv.id = "projected-fill-" .. index
local projectedColor = string.format("rgba(%d, %d, %d, %d)",
		allyTeam.color.r * COLOR_MULTIPLIER, allyTeam.color.g * COLOR_MULTIPLIER, allyTeam.color.b * COLOR_MULTIPLIER,
		PROJECTED_COLOR_ALPHA)
	projectedDiv:SetAttribute("style", "background-color: " .. projectedColor)

	local fillDiv = widgetState.document:CreateElement("div")
	fillDiv.class_name = "td-bar__fill"
	fillDiv.id = "score-fill-" .. index
local fillColor = string.format("rgba(%d, %d, %d, %d)",
		allyTeam.color.r * COLOR_MULTIPLIER, allyTeam.color.g * COLOR_MULTIPLIER, allyTeam.color.b * COLOR_MULTIPLIER,
		FILL_COLOR_ALPHA)
	fillDiv:SetAttribute("style", "background-color: " .. fillColor)

	local currentScoreText = widgetState.document:CreateElement("div")
	currentScoreText.class_name = "td-text current"
	currentScoreText.id = "current-score-" .. index
	currentScoreText.inner_rml = tostring(allyTeam.score)

	local projectedScoreText = widgetState.document:CreateElement("div")
	projectedScoreText.class_name = "td-text projected"
	projectedScoreText.id = "projected-score-" .. index
	projectedScoreText.inner_rml = "+" .. tostring(allyTeam.projectedPoints)

	local dangerOverlay = widgetState.document:CreateElement("div")
	dangerOverlay.class_name = "td-danger"
	dangerOverlay.id = "danger-overlay-" .. index
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
		currentScoreElement = currentScoreText,
		projectedScoreElement = projectedScoreText,
		projectedElement = projectedDiv,
		fillElement = fillDiv,
		dangerOverlay = dangerOverlay,
	}
end
local function createDataHash(data)
	if type(data) == "table" then
		local hash = ""
		for k, v in pairs(data) do
			if type(v) == "table" then
				hash = hash .. createDataHash(v)
			else
				hash = hash .. tostring(k) .. tostring(v)
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

		if teamList and #teamList > 0 then
			local firstTeamID = teamList[1]
			table.insert(validAllyTeams, {
				name = spI18N('ui.territorialDomination.team.ally', { allyNumber = allyTeamID + 1 }),
				allyTeamID = allyTeamID,
				firstTeamID = firstTeamID,
				score = spGetTeamRulesParam(firstTeamID, "territorialDominationScore") or 0,
				projectedPoints = spGetTeamRulesParam(firstTeamID, "territorialDominationProjectedPoints") or 0,
				color = getAllyTeamColor(allyTeamID),
				teamCount = #teamList,
			})
		end
	end

	table.sort(validAllyTeams, function(a, b)
		local aCombinedScore = a.score + a.projectedPoints
		local bCombinedScore = b.score + b.projectedPoints

		if aCombinedScore ~= bCombinedScore then
			return aCombinedScore > bCombinedScore
		end
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.allyTeamID < b.allyTeamID
	end)

	widgetState.allyTeamData = validAllyTeams
	return validAllyTeams
end

local function updateRoundInfo()
	local roundEndTime = spGetGameRulesParam("territorialDominationRoundEndTimestamp") or 0
	local gameRulesPointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
	local highestScore = spGetGameRulesParam("territorialDominationHighestScore") or 0
	local secondHighestScore = spGetGameRulesParam("territorialDominationSecondHighestScore") or 0

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
		highestScore = highestScore,
		secondHighestScore = secondHighestScore,
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
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local displayed = {}
	local seen = {}

	local topTeam = allyTeams[1]
	table.insert(displayed, topTeam)
	seen[topTeam.allyTeamID] = true

	local myIndex = nil
	if myAllyTeamID ~= nil then
		for i = 1, #allyTeams do
			if allyTeams[i].allyTeamID == myAllyTeamID then
				myIndex = i
				break
			end
		end
	end

	if not myIndex then
		for i = 2, math.min(#allyTeams, 6) do
			if not seen[allyTeams[i].allyTeamID] then
				table.insert(displayed, allyTeams[i])
				seen[allyTeams[i].allyTeamID] = true
		end
	end
		return displayed
	end

	for i = math.max(2, myIndex - 2), myIndex - 1 do
		if #displayed >= 6 then break end
		local team = allyTeams[i]
		if team and not seen[team.allyTeamID] then
			table.insert(displayed, team)
			seen[team.allyTeamID] = true
		end
	end

	if #displayed < 6 then
		local myTeam = allyTeams[myIndex]
		if myTeam and not seen[myTeam.allyTeamID] then
			table.insert(displayed, myTeam)
			seen[myTeam.allyTeamID] = true
		end
	end

	for i = myIndex + 1, math.min(#allyTeams, myIndex + 2) do
		if #displayed >= 6 then break end
		local team = allyTeams[i]
		if team and not seen[team.allyTeamID] then
			table.insert(displayed, team)
			seen[team.allyTeamID] = true
		end
	end

	for i = myIndex + 3, #allyTeams do
		if #displayed >= 6 then break end
		local team = allyTeams[i]
		if team and not seen[team.allyTeamID] then
			table.insert(displayed, team)
			seen[team.allyTeamID] = true
		end
	end

	for i = math.max(2, myIndex - 3), myIndex - 3 do
		if #displayed >= 6 then break end
		local team = allyTeams[i]
		if team and not seen[team.allyTeamID] then
			table.insert(displayed, team)
			seen[team.allyTeamID] = true
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

	local needsRebuild = false
	if #widgetState.scoreElements ~= numTeams then
		needsRebuild = true
	else
		for i, elements in ipairs(widgetState.scoreElements) do
			if not elements.container or not elements.container.parent_node then
				needsRebuild = true
				break
			end
		end
		if not needsRebuild then
			for i = 1, numTeams do
				if widgetState.displayedTeamIds[i] ~= allyTeams[i].allyTeamID then
					needsRebuild = true
					break
				end
			end
		end
	end

	if needsRebuild then
		columnsContainer.inner_rml = ""
		widgetState.scoreElements = {}
		widgetState.displayedTeamIds = {}

		for i, allyTeam in ipairs(allyTeams) do
			local scoreBarElements = createScoreBarElement(columnsContainer, allyTeam, i)
			widgetState.scoreElements[i] = scoreBarElements
			widgetState.displayedTeamIds[i] = allyTeam.allyTeamID
		end
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

			scoreBarElements.projectedElement:SetAttribute("style","width: " .. projectedWidth)

			local fillWidth = "0%"
			if dm.pointsCap > 0 then
				fillWidth = string.format("%.1f%%",
					math.min(PERCENTAGE_MULTIPLIER, (allyTeam.score / dm.pointsCap) * PERCENTAGE_MULTIPLIER))
			end

			scoreBarElements.fillElement:SetAttribute("style", "width: " .. fillWidth)

			if scoreBarElements.currentScoreElement then
				scoreBarElements.currentScoreElement.inner_rml = tostring(allyTeam.score)
			end
			if scoreBarElements.projectedScoreElement then
				scoreBarElements.projectedScoreElement.inner_rml = "+" .. tostring(allyTeam.projectedPoints)
			end

			if scoreBarElements.dangerOverlay then
				local dangerThreshold = dm.pointsCap * 0.5
				local combinedScore = allyTeam.score + allyTeam.projectedPoints
				local shouldShowDanger = combinedScore < dangerThreshold
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
		dm.highestScore = roundInfo.highestScore
		dm.secondHighestScore = roundInfo.secondHighestScore
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
	document:Show()

	resetCache()
	widgetState.lastUpdateTime = Spring.GetGameSeconds()
	widgetState.lastScoreUpdateTime = Spring.GetGameSeconds()
	widgetState.lastTimeUpdateTime = Spring.GetGameSeconds()

	calculateUILayout()
	updateDataModel()
	updateCountdownColor()
	updateHeaderVisibility()

	return true
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		if widgetState.document then
			widgetState.document:Show()
			widgetState.hiddenByLobby = false
		end
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		if widgetState.document then
			hideRoundEndPopup()
			widgetState.document:Hide()
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
	
	if shouldFullUpdate or shouldUpdateScores or shouldUpdateTime then
		local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
		if pointsCap and pointsCap > 0 then
			if widgetState.document and not widgetState.hiddenByLobby then
				widgetState.document:Show()
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
			if widgetState.document then
				widgetState.document:Hide()
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

