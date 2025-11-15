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
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetAIInfo = Spring.GetAIInfo
local ColorString = Spring.Utilities.Color.ToString
local ordinals = VFS.Include('common/ordinal.lua')
local ordinalFunc = ordinals.en -- default to English

local DEFAULT_MAX_ROUNDS = 7
local DEFAULT_POINTS_CAP = 100
local DEFAULT_COLOR_VALUE = 0.5

local SECONDS_PER_MINUTE = 60
local COUNTDOWN_ALERT_THRESHOLD = 60
local COUNTDOWN_WARNING_THRESHOLD = 10
local ROUND_END_POPUP_DELAY = 5

local UPDATE_INTERVAL = 0.5
local SCORE_UPDATE_INTERVAL = 2.0

local TIME_ZERO_STRING = "0:00"
local KEY_ESCAPE = 27
local AESTHETIC_POINTS_MULTIPLIER = 2 -- because bigger number feels good, and to help destinguish points from territory counts in round 1.

local DEFAULT_PANEL_HEIGHT = 240
local LEADERBOARD_GAP_BASE = 50
local LEADERBOARD_GAP_SPECTATOR = 25

local COLOR_BACKGROUND_ALPHA = 35
local COLOR_BYTE_MAX = 255
local DEFAULT_TEAM_COLOR = 0.5

local MIN_TEAM_LIST_SIZE = 1
local MAX_DATA_ITEMS = 10

local GAIA_ALLY_TEAM_ID = select(6, spGetTeamInfo(spGetGaiaTeamID()))

local widgetState = {
	document = nil,
	dmHandle = nil,
	rmlContext = nil,
	lastUpdateTime = 0,
	lastTimeUpdateTime = 0,
	lastScoreUpdateTime = 0,
	allyTeamData = {},
	hiddenByLobby = false,
	isDocumentVisible = false,
	popupState = {
		isVisible = false,
		showTime = 0,
	},
	cachedData = {
		allyTeams = {},
		roundInfo = {},
		lastTimeHash = "",
	},
	lastPointsCap = 0,
	lastAllyTeamCount = 0,
	lastTeamOrderHash = "",
	lastGameTime = 0,
	updateCounter = 0,
	lastTimeRemainingSeconds = 0,
	leaderboardPanel = nil,
	isLeaderboardVisible = false,
	cachedPlayerNames = {},
	cachedTeamColors = {},
	knownAllyTeamIDs = {},
	hasCachedInitialNames = false,
	hasValidAdvPlayerListPosition = false,
}

local initialModel = {
	allyTeams = {},
	currentRound = 0,
	roundEndTime = 0,
	maxRounds = 0,
	pointsCap = 0,
	prevHighestScore = 0,
	timeRemaining = TIME_ZERO_STRING,
	roundDisplayText = spI18N('ui.territorialDomination.round.displayDefault', { maxRounds = DEFAULT_MAX_ROUNDS }),
	timeRemainingSeconds = 0,
	isCountdownWarning = false,
	territoryCount = 0,
	territoryPoints = 0,
	pointsPerTerritory = 0,
	territoryWorthText = "",
	currentScore = 0,
	combinedScore = 0,
	teamName = "",
	eliminationThreshold = 0,
	rankDisplayText = "",
	eliminationText = "",
	isAboveElimination = false,
	isFinalRound = false,
	leaderboardTeams = {},
}

local function getAIName(teamID)
	local _, _, _, name, _, options = spGetAIInfo(teamID)
	local niceName = Spring.GetGameRulesParam('ainame_' .. teamID)
	
	if niceName then
		name = niceName
		
		if Spring.Utilities.ShowDevUI() and options.profile then
			name = name .. " [" .. options.profile .. "]"
		end
	end
	
	return Spring.I18N('ui.playersList.aiName', { name = name })
end

local function fetchAllyTeamPlayerNames(allyTeamID)
	local teamList = spGetTeamList(allyTeamID)
	if not teamList or #teamList == 0 then
		return spI18N('ui.territorialDomination.team.ally', { allyNumber = allyTeamID + 1 })
	end
	
	local playerNames = {}
	local seenPlayerIDs = {}
	local myTeamID = Spring.GetMyTeamID()
	local mySpecStatus = spGetSpectatingState()
	local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
	
	for i = 1, #teamList do
		local teamID = teamList[i]
		local _, playerID, _, isAI = spGetTeamInfo(teamID, false)
		
		if isAI then
			local name = getAIName(teamID)
			local r, g, b = spGetTeamColor(teamID)
			if (not mySpecStatus) and anonymousMode ~= "disabled" and teamID ~= myTeamID then
				local anonymousColorR = Spring.GetConfigInt("anonymousColorR", COLOR_BYTE_MAX) / COLOR_BYTE_MAX
				local anonymousColorG = Spring.GetConfigInt("anonymousColorG", 0) / COLOR_BYTE_MAX
				local anonymousColorB = Spring.GetConfigInt("anonymousColorB", 0) / COLOR_BYTE_MAX
				r, g, b = anonymousColorR, anonymousColorG, anonymousColorB
			end
			
			local rByte = math.floor(r * COLOR_BYTE_MAX)
			local gByte = math.floor(g * COLOR_BYTE_MAX)
			local bByte = math.floor(b * COLOR_BYTE_MAX)
			local colorHex = string.format("#%02X%02X%02X", rByte, gByte, bByte)
			
			table.insert(playerNames, {
				name = name,
				color = colorHex
			})
		elseif playerID and not seenPlayerIDs[playerID] then
			seenPlayerIDs[playerID] = true
			local name, _, spec = spGetPlayerInfo(playerID, false)
			if name and not spec then
				if WG.playernames and WG.playernames.getPlayername then
					name = WG.playernames.getPlayername(playerID) or name
				end
				
				local r, g, b = spGetTeamColor(teamID)
				if (not mySpecStatus) and anonymousMode ~= "disabled" and teamID ~= myTeamID then
					local anonymousColorR = Spring.GetConfigInt("anonymousColorR", COLOR_BYTE_MAX) / COLOR_BYTE_MAX
					local anonymousColorG = Spring.GetConfigInt("anonymousColorG", 0) / COLOR_BYTE_MAX
					local anonymousColorB = Spring.GetConfigInt("anonymousColorB", 0) / COLOR_BYTE_MAX
					r, g, b = anonymousColorR, anonymousColorG, anonymousColorB
				end
				
				local rByte = math.floor(r * COLOR_BYTE_MAX)
				local gByte = math.floor(g * COLOR_BYTE_MAX)
				local bByte = math.floor(b * COLOR_BYTE_MAX)
				local colorHex = string.format("#%02X%02X%02X", rByte, gByte, bByte)
				
				table.insert(playerNames, {
					name = name,
					color = colorHex
				})
			end
		end
	end
	
	if #playerNames == 0 then
		return spI18N('ui.territorialDomination.team.ally', { allyNumber = allyTeamID + 1 })
	end
	
	return playerNames
end

local function getAllyTeamPlayerNames(allyTeamID)
	if widgetState.cachedPlayerNames[allyTeamID] then
		return widgetState.cachedPlayerNames[allyTeamID]
	end
	
	local fallbackName = spI18N('ui.territorialDomination.team.ally', { allyNumber = allyTeamID + 1 })
	widgetState.cachedPlayerNames[allyTeamID] = fallbackName
	return fallbackName
end

local function getAllyTeamColor(allyTeamID)
	if widgetState.cachedTeamColors[allyTeamID] then
		return widgetState.cachedTeamColors[allyTeamID]
	end
	
	local teamList = spGetTeamList(allyTeamID)
	if teamList and #teamList > 0 then
		local teamID = teamList[1]
		local r, g, b = spGetTeamColor(teamID)
		local color = { r = r, g = g, b = b }
		widgetState.cachedTeamColors[allyTeamID] = color
		return color
	end
	
	local defaultColor = { r = DEFAULT_COLOR_VALUE, g = DEFAULT_COLOR_VALUE, b = DEFAULT_COLOR_VALUE }
	
	local existingTeam = nil
	for i = 1, #widgetState.allyTeamData do
		if widgetState.allyTeamData[i].allyTeamID == allyTeamID then
			existingTeam = widgetState.allyTeamData[i]
			break
		end
	end
	
	if existingTeam and existingTeam.color then
		widgetState.cachedTeamColors[allyTeamID] = existingTeam.color
		return existingTeam.color
	end
	
	widgetState.cachedTeamColors[allyTeamID] = defaultColor
	return defaultColor
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

local function buildLeaderboardRow(team, rank, isEliminated, isDead)
	local row = widgetState.document:CreateElement("div")
	row.class_name = "scoreboard-team-row"
	if isDead then
		row:SetClass("eliminated", true)
	end
	
	local teamColor = team.color or { r = DEFAULT_TEAM_COLOR, g = DEFAULT_TEAM_COLOR, b = DEFAULT_TEAM_COLOR }
	local rByte = math.floor(teamColor.r * COLOR_BYTE_MAX)
	local gByte = math.floor(teamColor.g * COLOR_BYTE_MAX)
	local bByte = math.floor(teamColor.b * COLOR_BYTE_MAX)
	local bgColor = string.format("rgba(%d, %d, %d, %d)", rByte, gByte, bByte, COLOR_BACKGROUND_ALPHA)
	row:SetAttribute("style", "background-color: " .. bgColor .. ";")
	
	local rankDiv = widgetState.document:CreateElement("div")
	rankDiv.class_name = "scoreboard-rank"
	rankDiv.inner_rml = ordinalFunc(rank)
	
	local nameDiv = widgetState.document:CreateElement("div")
	nameDiv.class_name = "scoreboard-name"
	
	if type(team.name) == "table" then
		for i = 1, #team.name do
			local playerName = team.name[i]
			local nameSpan = widgetState.document:CreateElement("div")
			nameSpan.class_name = "scoreboard-player-name"
			if not isDead then
				local styleStr = "color: " .. playerName.color .. ";"
				nameSpan:SetAttribute("style", styleStr)
			end
			nameSpan.inner_rml = playerName.name
			nameDiv:AppendChild(nameSpan)
		end
	else
		nameDiv.inner_rml = team.name or ""
	end
	
	local totalDiv = widgetState.document:CreateElement("div")
	totalDiv.class_name = "scoreboard-score"
	local previousScore = team.score or 0
	local gains = team.projectedPoints or 0
	local totalScore = previousScore + gains
	totalDiv.inner_rml = tostring(totalScore) .. "pts"

	local dataModel = widgetState.dmHandle
	local territoryCount = team.territoryCount or 0

	local territoriesDiv = widgetState.document:CreateElement("div")
	territoriesDiv.class_name = "scoreboard-territories"
	territoriesDiv.inner_rml = tostring(territoryCount)

	row:AppendChild(rankDiv)
	row:AppendChild(nameDiv)
	row:AppendChild(totalDiv)
	row:AppendChild(territoriesDiv)
	
	return row
end

local function calculateDisplayRanks(teams)
	local currentRank = 1
	local previousScore = nil
	for i = 1, #teams do
		local team = teams[i]
		local combinedScore = (team.score or 0) + (team.projectedPoints or 0)
		if previousScore ~= nil and combinedScore ~= previousScore then
			currentRank = currentRank + 1
		end
		team.displayRank = currentRank
		previousScore = combinedScore
	end
end

local function updateLeaderboard()
	if not widgetState.document then return end
	
	local leaderboardPanel = widgetState.document:GetElementById("leaderboard-panel")
	if not leaderboardPanel then return end
	
	local teamsContainer = widgetState.document:GetElementById("leaderboard-teams")
	local eliminatedContainer = widgetState.document:GetElementById("leaderboard-eliminated")
	local separatorElement = widgetState.document:GetElementById("elimination-separator")
	local separatorTextElement = widgetState.document:GetElementById("elimination-separator-text")
	
	if not teamsContainer or not eliminatedContainer or not separatorElement or not separatorTextElement then return end
	
	while teamsContainer:HasChildNodes() do
		local child = teamsContainer:GetChild(0)
		if child then
			teamsContainer:RemoveChild(child)
		else
			break
		end
	end
	
	while eliminatedContainer:HasChildNodes() do
		local child = eliminatedContainer:GetChild(0)
		if child then
			eliminatedContainer:RemoveChild(child)
		else
			break
		end
	end
	
	local allyTeams = widgetState.allyTeamData
	if not allyTeams or #allyTeams == 0 then return end
	
	local dataModel = widgetState.dmHandle
	local eliminationThreshold = (dataModel and dataModel.prevHighestScore) or 0
	
	local livingTeams = {}
	local eliminatedTeams = {}
	
	for i = 1, #allyTeams do
		local team = allyTeams[i]
		local combinedScore = (team.score or 0) + (team.projectedPoints or 0)
		local isEliminated = false
		
		if eliminationThreshold > 0 then
			isEliminated = not team.isAlive or combinedScore < eliminationThreshold
		else
			isEliminated = not team.isAlive
		end
		
		if isEliminated then
			table.insert(eliminatedTeams, { team = team, rank = i })
		else
			table.insert(livingTeams, { team = team, rank = i })
		end
	end
	
	for i = 1, #livingTeams do
		local entry = livingTeams[i]
		local displayRank = entry.team.displayRank or i
		local row = buildLeaderboardRow(entry.team, displayRank, false, not entry.team.isAlive)
		teamsContainer:AppendChild(row)
	end
	
	if eliminationThreshold > 0 then
		separatorTextElement.inner_rml = spI18N('ui.territorialDomination.elimination.threshold', { threshold = eliminationThreshold })
		separatorElement:SetClass("hidden", false)
	else
		separatorElement:SetClass("hidden", true)
	end
	
	if #eliminatedTeams > 0 then
		for i = 1, #eliminatedTeams do
			local entry = eliminatedTeams[i]
			local displayRank = entry.team.displayRank or entry.rank or i
			local row = buildLeaderboardRow(entry.team, displayRank, true, not entry.team.isAlive)
			eliminatedContainer:AppendChild(row)
		end
	end
end

local function showLeaderboard()
	if not widgetState.document then return end
	
	local leaderboardPanel = widgetState.document:GetElementById("leaderboard-panel")
	if not leaderboardPanel then return end
	
	widgetState.isLeaderboardVisible = true
	leaderboardPanel:SetClass("hidden", false)
	updateLeaderboard()
end

local function hideLeaderboard()
	if not widgetState.document then return end
	
	local leaderboardPanel = widgetState.document:GetElementById("leaderboard-panel")
	if not leaderboardPanel then return end
	
	widgetState.isLeaderboardVisible = false
	leaderboardPanel:SetClass("hidden", true)
end

local function checkDocumentVisibility()
	local pointsCap = spGetGameRulesParam("territorialDominationPointsCap") or DEFAULT_POINTS_CAP
	local currentTime = Spring.GetGameSeconds()
	local _, _, isClientPaused, _ = Spring.GetGameState()
	local isGameStarted = currentTime > 0
	local shouldShow = pointsCap and pointsCap > 0 and isGameStarted and not isClientPaused and not widgetState.hiddenByLobby and widgetState.hasValidAdvPlayerListPosition
	
	if widgetState.document then
		if shouldShow and not widgetState.isDocumentVisible then
			widgetState.document:Show()
			widgetState.isDocumentVisible = true
		elseif not shouldShow and widgetState.isDocumentVisible then
			widgetState.document:Hide()
			widgetState.isDocumentVisible = false
		end
	end
	
	if pointsCap ~= widgetState.lastPointsCap then
		widgetState.lastPointsCap = pointsCap
	end
end

local function calculateUILayout()
	if not widgetState.document then return end

	local tdRootElement = widgetState.document:GetElementById("td-root")
	if not tdRootElement then return end

	local advPlayerListAPI = WG['advplayerlist_api']
	if not advPlayerListAPI or not advPlayerListAPI.GetPosition then
		widgetState.hasValidAdvPlayerListPosition = false
		checkDocumentVisibility()
		return
	end

	local apiAbsPosition = advPlayerListAPI.GetPosition()
	if not apiAbsPosition or #apiAbsPosition < 4 then
		widgetState.hasValidAdvPlayerListPosition = false
		checkDocumentVisibility()
		return
	end

	widgetState.hasValidAdvPlayerListPosition = true

	local screenWidth, screenHeight = Spring.GetViewGeometry()
	if not screenWidth or screenWidth <= 0 then
		return
	end

	local GL_BASE_WIDTH = 1920
	local GL_BASE_HEIGHT = 1080
	local scaleX = screenWidth / GL_BASE_WIDTH
	local scaleY = screenHeight / GL_BASE_HEIGHT

	local leaderboardTop = apiAbsPosition[1]
	local gap = (LEADERBOARD_GAP_BASE + (spGetSpectatingState() and LEADERBOARD_GAP_SPECTATOR or 0)) * scaleY
	local panelHeight = tdRootElement.offset_height or DEFAULT_PANEL_HEIGHT

	local leaderboardTopCss = screenHeight - leaderboardTop
	local desiredBottomCss = leaderboardTopCss - gap

	if desiredBottomCss >= 0 and desiredBottomCss < screenHeight then
		local topVh = (desiredBottomCss / screenHeight) * 100
		local newStyle = string.format("left: 100vw; top: %.2fvh; transform: translate(-100%%, -100%%);", topVh)
		tdRootElement:SetAttribute("style", newStyle)
	else
		local fallbackTopVh = 100
		local newStyle = string.format("left: 100vw; top: %.2fvh; transform: translate(-100%%, -100%%);", fallbackTopVh)
		tdRootElement:SetAttribute("style", newStyle)
	end


	checkDocumentVisibility()
end

local function createDataHash(data)
	if type(data) == "table" then
		local hash = ""
		if #data > 0 then
			for i = 1, math.min(#data, MAX_DATA_ITEMS) do
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
	local territoryInfoElement = widgetState.document:GetElementById("popup-territory-info")
	local eliminationInfoElement = widgetState.document:GetElementById("popup-elimination-info")
	if not popupElement or not popupTextElement or not territoryInfoElement or not eliminationInfoElement then return end

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

	local dataModel = widgetState.dmHandle
	local pointsPerTerritory = (dataModel and dataModel.pointsPerTerritory) or 0
	local eliminationThreshold = (dataModel and dataModel.eliminationThreshold) or 0

	territoryInfoElement.inner_rml = spI18N('ui.territorialDomination.roundOverPopup.territoryWorth', { points = pointsPerTerritory })

	if eliminationThreshold > 0 and not isFinalRound then
		eliminationInfoElement.inner_rml = spI18N('ui.territorialDomination.roundOverPopup.eliminationBelow', { threshold = eliminationThreshold })
	else
		eliminationInfoElement.inner_rml = ""
	end

	popupElement.class_name = "popup-round-end visible"
	widgetState.popupState.isVisible = true
	widgetState.popupState.showTime = os.clock()
	Spring.PlaySoundFile("sounds/global-events/scavlootdrop.wav", 0.8, 'ui')
	Spring.PlaySoundFile("sounds/replies/servlrg3.wav", 1.0, 'ui')
end


local function hideRoundEndPopup()
	if not widgetState.document then return end

	local popupElement = widgetState.document:GetElementById("round-end-popup")
	if not popupElement then return end

	popupElement.class_name = "popup-round-end"
	widgetState.popupState.isVisible = false
end

local function getSelectedPlayerTeam()
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	if not myAllyTeamID then return nil end
	
	local teamList = spGetTeamList(myAllyTeamID)
	if not teamList or #teamList < MIN_TEAM_LIST_SIZE then return nil end
	
	local firstTeamID = teamList[1]
	local score = spGetTeamRulesParam(firstTeamID, "territorialDominationScore") or 0
	local projectedPoints = spGetTeamRulesParam(firstTeamID, "territorialDominationProjectedPoints") or 0
	local territoryCount = spGetTeamRulesParam(firstTeamID, "territorialDominationTerritoryCount") or 0

	return {
		name = getAllyTeamPlayerNames(myAllyTeamID),
		allyTeamID = myAllyTeamID,
		firstTeamID = firstTeamID,
		score = score,
		projectedPoints = projectedPoints,
		territoryCount = territoryCount,
		color = getAllyTeamColor(myAllyTeamID),
		rank = spGetTeamRulesParam(firstTeamID, "territorialDominationDisplayRank") or 1,
		teamCount = #teamList,
		teamList = teamList,
	}
end

local function updateAllyTeamData()
	local allyTeamList = spGetAllyTeamList()
	local validAllyTeams = {}
	
	for i = 1, #allyTeamList do
		local allyTeamID = allyTeamList[i]
		if allyTeamID ~= GAIA_ALLY_TEAM_ID then
			widgetState.knownAllyTeamIDs[allyTeamID] = true
			if not widgetState.cachedPlayerNames[allyTeamID] then
				widgetState.cachedPlayerNames[allyTeamID] = fetchAllyTeamPlayerNames(allyTeamID)
			end
		end
	end
	
	for allyTeamID, _ in pairs(widgetState.knownAllyTeamIDs) do
		if allyTeamID == GAIA_ALLY_TEAM_ID then
			-- Skip GAIA team
		else
			local teamList = spGetTeamList(allyTeamID)
			local hasTeamList = teamList and #teamList > 0
			local firstTeamID = nil
			local score = 0
			local projectedPoints = 0
			local territoryCount = 0
			local hasAliveTeam = false
			local teamCount = 0

			if hasTeamList then
				firstTeamID = teamList[1]
				score = spGetTeamRulesParam(firstTeamID, "territorialDominationScore") or 0
				projectedPoints = spGetTeamRulesParam(firstTeamID, "territorialDominationProjectedPoints") or 0
				territoryCount = spGetTeamRulesParam(firstTeamID, "territorialDominationTerritoryCount") or 0

				for j = 1, #teamList do
					local _, _, isDead = spGetTeamInfo(teamList[j])
					if not isDead then
						hasAliveTeam = true
						break
					end
				end
				
				teamCount = #teamList
			else
				local existingTeam = nil
				for i = 1, #widgetState.allyTeamData do
					if widgetState.allyTeamData[i].allyTeamID == allyTeamID then
						existingTeam = widgetState.allyTeamData[i]
						break
					end
				end
				
				if existingTeam then
					firstTeamID = existingTeam.firstTeamID
					score = existingTeam.score or 0
					projectedPoints = existingTeam.projectedPoints or 0
					territoryCount = existingTeam.territoryCount or 0
					teamCount = existingTeam.teamCount or 0
				end
			end

			local rank = 1
			if firstTeamID then
				rank = spGetTeamRulesParam(firstTeamID, "territorialDominationDisplayRank") or 1
			end

			table.insert(validAllyTeams, {
				name = getAllyTeamPlayerNames(allyTeamID),
				allyTeamID = allyTeamID,
				firstTeamID = firstTeamID,
				score = score,
				projectedPoints = projectedPoints,
				territoryCount = territoryCount,
				color = getAllyTeamColor(allyTeamID),
				rank = rank,
				teamCount = teamCount,
				isAlive = hasAliveTeam,
				teamList = teamList or {},
			})
		end
	end

	table.sort(validAllyTeams, function(a, b)
		local aCombinedScore = (a.score or 0) + (a.projectedPoints or 0)
		local bCombinedScore = (b.score or 0) + (b.projectedPoints or 0)
		if aCombinedScore ~= bCombinedScore then
			return aCombinedScore > bCombinedScore
		end
		return a.allyTeamID < b.allyTeamID
	end)

	calculateDisplayRanks(validAllyTeams)

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
		roundDisplayText = spI18N('ui.territorialDomination.round.displayMax', { maxRounds = maxRounds })
	elseif currentRound == 0 then
		roundDisplayText = spI18N('ui.territorialDomination.round.displayDefault', { maxRounds = maxRounds })
	else
		roundDisplayText = spI18N('ui.territorialDomination.round.displayWithMax', { currentRound = currentRound, maxRounds = maxRounds })
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
	local dataModel = widgetState.dmHandle
	local roundDisplayText = (dataModel and dataModel.roundDisplayText) or ""
	if roundDisplayText ~= "" then
		hasRoundInfo = true
	end
	local currentRoundParam = spGetGameRulesParam("territorialDominationCurrentRound") or 0
	local maxRoundsParam = (widgetState.dmHandle and widgetState.dmHandle.maxRounds) or DEFAULT_MAX_ROUNDS
	local inOvertime = currentRoundParam > maxRoundsParam
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

local function updatePlayerDisplay()
	if not widgetState.document then return end
	
	local dataModel = widgetState.dmHandle
	if not dataModel then return end
	
	local selectedTeam = getSelectedPlayerTeam()
	if not selectedTeam then return end
	
	local currentRound = dataModel.currentRound or 0
	local pointsPerTerritory = currentRound > 0 and currentRound * AESTHETIC_POINTS_MULTIPLIER or AESTHETIC_POINTS_MULTIPLIER
	local projectedPoints = selectedTeam.projectedPoints or 0
	local territoryCount = selectedTeam.territoryCount or 0
	local currentScore = selectedTeam.score or 0
	local teamName = selectedTeam.name or ""
	local eliminationThreshold = dataModel.prevHighestScore or 0
	
	local allyTeams = widgetState.allyTeamData
	local playerRank = 1
	local rankDisplayText = ""
	
	if allyTeams and #allyTeams > 0 then
		for i = 1, #allyTeams do
			local team = allyTeams[i]
			if team.allyTeamID == selectedTeam.allyTeamID then
				playerRank = team.displayRank or i
				break
			end
		end
		
		if playerRank > 0 then
			rankDisplayText = ordinalFunc(playerRank) .. spI18N('ui.territorialDomination.rank.place')
		end
		
	local playerCombinedScore = currentScore + projectedPoints
	local eliminationText = ""
	local isAboveElimination = false
	local maxRounds = dataModel.maxRounds or DEFAULT_MAX_ROUNDS
	local isFinalRound = (currentRound == maxRounds) or (dataModel.isFinalRound or false)
	
	if isFinalRound then
		eliminationText = spI18N('ui.territorialDomination.elimination.finalRound')
		isAboveElimination = false
	elseif eliminationThreshold > 0 then
		local difference = playerCombinedScore - eliminationThreshold
		if difference > 0 then
			eliminationText = spI18N('ui.territorialDomination.elimination.aboveElimination', { points = difference })
			isAboveElimination = true
		elseif difference < 0 then
			eliminationText = spI18N('ui.territorialDomination.elimination.belowElimination', { points = math.abs(difference) })
			isAboveElimination = false
		else
			eliminationText = spI18N('ui.territorialDomination.elimination.zeroAboveElimination')
			isAboveElimination = true
		end
	else
		eliminationText = spI18N('ui.territorialDomination.elimination.eliminationsNextRound')
		isAboveElimination = true
	end
		
		dataModel.eliminationText = eliminationText
		dataModel.isAboveElimination = isAboveElimination
		dataModel.isFinalRound = isFinalRound
	end
	
	dataModel.territoryCount = territoryCount .. " x " .. pointsPerTerritory .. "pts"
	dataModel.territoryPoints = projectedPoints
	dataModel.pointsPerTerritory = tostring(pointsPerTerritory)
	dataModel.territoryWorthText = spI18N('ui.territorialDomination.territories.worth', { points = pointsPerTerritory })
	dataModel.currentScore = currentScore
	dataModel.combinedScore = currentScore + projectedPoints
	dataModel.teamName = teamName
	dataModel.eliminationThreshold = eliminationThreshold
	dataModel.rankDisplayText = rankDisplayText
	
	local rankDisplayElement = widgetState.document:GetElementById("rank-display")
	if rankDisplayElement then
		if rankDisplayText ~= "" then
			rankDisplayElement:SetClass("hidden", false)
		else
			rankDisplayElement:SetClass("hidden", true)
		end
	end
	
	
	local eliminationWarningElement = widgetState.document:GetElementById("elimination-warning")
	local currentScoreElement = widgetState.document:GetElementById("current-score")
	
	if eliminationWarningElement then
		if dataModel.eliminationText ~= "" then
			eliminationWarningElement:SetClass("hidden", false)
			if dataModel.isFinalRound then
				eliminationWarningElement:SetClass("above-elimination", false)
				eliminationWarningElement:SetClass("below-elimination", true)
				eliminationWarningElement:SetClass("next-round", false)
			elseif dataModel.isAboveElimination then
				if dataModel.eliminationThreshold == 0 then
					eliminationWarningElement:SetClass("above-elimination", false)
					eliminationWarningElement:SetClass("below-elimination", false)
					eliminationWarningElement:SetClass("next-round", true)
				else
					eliminationWarningElement:SetClass("above-elimination", true)
					eliminationWarningElement:SetClass("below-elimination", false)
					eliminationWarningElement:SetClass("next-round", false)
				end
			else
				eliminationWarningElement:SetClass("above-elimination", false)
				eliminationWarningElement:SetClass("below-elimination", true)
				eliminationWarningElement:SetClass("next-round", false)
			end
		else
			eliminationWarningElement:SetClass("hidden", true)
		end
	end
	
	if currentScoreElement then
		local isBelowElimination = false
		if dataModel.eliminationText ~= "" then
			if dataModel.isFinalRound then
				if playerRank ~= 1 then
					isBelowElimination = true
				end
			elseif not dataModel.isAboveElimination and dataModel.eliminationThreshold > 0 then
				isBelowElimination = true
			end
		end
		
		if isBelowElimination then
			currentScoreElement:SetClass("warning", true)
			currentScoreElement:SetClass("pulsing", true)
		else
			currentScoreElement:SetClass("warning", false)
			currentScoreElement:SetClass("pulsing", false)
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
		dataModel.roundEndTime = tostring(roundInfo.roundEndTime)
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
		updatePlayerDisplay()
		
		if scoresChanged or roundChanged then
			-- Data model updates already handled above
			if widgetState.isLeaderboardVisible then
				updateLeaderboard()
			end
		end

		if timeChanged then
			updateCountdownColor()
		end

		if roundChanged then
			updateHeaderVisibility()
		end

		if roundInfo.isFinalRound and previousTimeRemaining > 0 and roundInfo.timeRemainingSeconds <= 0 then
			showRoundEndPopup(roundInfo.currentRound, true)
		elseif previousRound ~= roundInfo.currentRound and (previousRound > 0 or roundInfo.currentRound == 1) then
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
		updatePlayerDisplay()
		
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

	local language = Spring.GetConfigString('language', 'en')
	ordinalFunc = ordinals[language] or ordinals.en

	local document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not document then
		widget:Shutdown()
		return false
	end

	widgetState.document = document

	document:ReloadStyleSheet()
	checkDocumentVisibility()
	
	local leaderboardButton = document:GetElementById("leaderboard-button")
	if leaderboardButton then
		leaderboardButton:AddEventListener("click", function(event)
			if widgetState.isLeaderboardVisible then
				hideLeaderboard()
			else
				showLeaderboard()
			end
			event:StopPropagation()
		end, false)
	end
	
	local leaderboardOverlay = document:GetElementById("leaderboard-overlay")
	if leaderboardOverlay then
		leaderboardOverlay:AddEventListener("click", function(event)
			hideLeaderboard()
			event:StopPropagation()
		end, false)
	end
	
	local leaderboardContent = document:GetElementById("leaderboard-content")
	if leaderboardContent then
		leaderboardContent:AddEventListener("click", function(event)
			event:StopPropagation()
		end, false)
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
end

function widget:Update()
	local currentTime = Spring.GetGameSeconds()
	local currentOSClock = os.clock()

	checkDocumentVisibility()

	if not widgetState.hasCachedInitialNames and currentTime > 0 then
		local allyTeamList = spGetAllyTeamList()
		for i = 1, #allyTeamList do
			local allyTeamID = allyTeamList[i]
			if allyTeamID ~= GAIA_ALLY_TEAM_ID then
				widgetState.knownAllyTeamIDs[allyTeamID] = true
				if not widgetState.cachedPlayerNames[allyTeamID] then
					widgetState.cachedPlayerNames[allyTeamID] = fetchAllyTeamPlayerNames(allyTeamID)
				end
			end
		end
		widgetState.hasCachedInitialNames = true
	end

	if widgetState.popupState.isVisible then
		if os.clock() - widgetState.popupState.showTime >= ROUND_END_POPUP_DELAY then
			hideRoundEndPopup()
		end
	end

	if shouldSkipUpdate() then return end

	widgetState.updateCounter = widgetState.updateCounter + 1
	
	if widgetState.updateCounter % 10 == 0 then
		calculateUILayout()
	end
	
	if shouldFullUpdate() or shouldUpdateScores() then
		updateDataModel()
		widgetState.lastScoreUpdateTime = currentTime
		widgetState.lastUpdateTime = currentTime
	elseif shouldUpdateTime() then
		updateTimeOnly()
		widgetState.lastTimeUpdateTime = currentTime
	end
end

function widget:GamePaused(playerID, isPaused)
	checkDocumentVisibility()
end

function widget:ViewResize()
	calculateUILayout()
end

function widget:KeyPress(key)
	if key == KEY_ESCAPE then
		if widgetState.isLeaderboardVisible then
			hideLeaderboard()
			return true
		end
	end
	return false
end

function widget:DrawScreen()
	if Spring.GetGameSeconds() <= 0 then
		return
	end
end
