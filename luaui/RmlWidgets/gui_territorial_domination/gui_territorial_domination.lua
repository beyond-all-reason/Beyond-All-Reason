if not RmlUi then
	return
end

local WIDGET = widget

function WIDGET:GetInfo()
	return {
		name = "Territorial Domination Score Display",
		desc = "Displays Territorial Domination scores and Deadlines",
		author = "SethDGamre",
		date = "2026-09",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true,
	}
end

local MOD_OPTIONS = Spring.GetModOptions() or {}

if MOD_OPTIONS.deathmode ~= "territorial_domination" then
	return false
end

if BAR.Utilities.Gametype.IsRaptors() or BAR.Utilities.Gametype.IsScavengers() then
	return false
end

local MODEL_NAME = "territorial_score_model"
local RML_PATH = "luaui/RmlWidgets/gui_territorial_domination/gui_territorial_domination.rml"
local PANEL_POSITION_X_KEY = "td_posX"
local PANEL_POSITION_Y_KEY = "td_posY"
local PANEL_DOCKED_KEY = "td_docked"
local PANEL_DOCKED_VALUE = 1
local PANEL_UNDOCKED_VALUE = 0
local EMOJI_FONT_PATH = "fonts/fallbacks/NotoEmoji-VariableFont_wght.ttf"
local PANEL_WIDTH_DP = 240
local PANEL_COLLAPSED_HEIGHT_DP = 98
local PANEL_EXPANDED_HEIGHT_DP = 204
local PANEL_MARGIN_DP = 10
local DISTRIBUTION_LEFT_DP = 7
local DISTRIBUTION_WIDTH_DP = 222
local DISTRIBUTION_HEIGHT_DP = 10
local DISTRIBUTION_BORDER_DP = 1
local DISTRIBUTION_HEIGHT = tostring(DISTRIBUTION_HEIGHT_DP) .. "dp"
local PANEL_ORIGIN_SNAP_DISTANCE_DP = 36
local REVERT_TO_ORIGIN_POSITION = false
local VERTICAL_SLOT_WIDTH_DP = 26
local VERTICAL_CONTENT_MINIMUM_WIDTH_DP = 222
local VERTICAL_CONTENT_PADDING_DP = 6
local VERTICAL_TRACK_HEIGHT_DP = 124
local VERTICAL_TRACK_BOTTOM_DP = 12
local TOOLTIP_OFFSET_X = 16
local TOOLTIP_OFFSET_Y = 22
local TOOLTIP_FONT_SIZE_DP = 17
local TOOLTIP_CHAR_WIDTH_DP = 8
local TOOLTIP_PADDING_X_DP = 20
local TOOLTIP_MIN_WIDTH_DP = 80
local TOOLTIP_TEAM_EXTRA_DP = 24
local TOOLTIP_ROW_HEIGHT_DP = 22
local TOOLTIP_VERTICAL_PADDING_DP = 16
local POSITION_SCALE = 10000
local COLOR_BYTE_MAXIMUM = 255
local DARK_COLOR_MULTIPLIER = 0.48
local SEGMENT_OUTLINE_COLOR_MULTIPLIER = 0.7
local DATA_UPDATE_INTERVAL = 0.2
local POPUP_DURATION_SECONDS = 5
local POPUP_INITIAL_WINDOW_SECONDS = 10
local DANGER_POPUP_COOLDOWN_SECONDS = 60
local COUNTDOWN_WARNING_SECONDS = 60
local COUNTDOWN_PULSE_START_RED = 255
local COUNTDOWN_PULSE_START_GREEN = 117
local COUNTDOWN_PULSE_START_BLUE = 117
local COUNTDOWN_PULSE_END_RED = 214
local COUNTDOWN_PULSE_END_GREEN = 47
local COUNTDOWN_PULSE_END_BLUE = 47
local COUNTDOWN_PULSE_START_SCALE = 1.04
local COUNTDOWN_PULSE_END_SCALE = 1
local COUNTDOWN_IDLE_COLOR = "rgba(255, 255, 255, 255)"
local COUNTDOWN_IDLE_TRANSFORM = "scale(1)"
local SECONDS_PER_MINUTE = 60
local TERRITORY_POINTS_PER_DEADLINE = 10
local DEADLINE_SKULL_ICON = "💀"
local DEADLINE_LABEL_OFFSET_DP = 10
local DEADLINE_ICON_COLOR = "rgba(255, 48, 48, 255)"
local TROPHY_ICON = "🏆"
local KEY_ESCAPE = 27
local TOOLTIP_SOURCE_CURRENT_SCORE = "currentScore"
local TOOLTIP_SOURCE_COUNTDOWN = "countdown"
local TOOLTIP_SOURCE_TARGET = "target"
local TOOLTIP_SOURCE_DANGER = "danger"
local TOOLTIP_SOURCE_DEADLINE = "deadline"
local TOOLTIP_HEADER_EXPAND = "expand"
local TOOLTIP_HEADER_SELECT = "select"
local DEFAULT_COLOR = {
	red = 0.5,
	green = 0.5,
	blue = 0.5,
}
local DEADLINES_BY_CONFIG = {
	["20_minutes"] = 4,
	["25_minutes"] = 5,
	["30_minutes"] = 6,
	["35_minutes"] = 7,
}
local DEFAULT_MAX_DEADLINES = DEADLINES_BY_CONFIG[MOD_OPTIONS.territorial_domination_config] or 5
local I18N = BAR.I18N
local FLOW_UI_PANEL_API_NAMES = {
	"advplayerlist_api",
	"music",
	"unittotals",
	"displayinfo",
	"playertv",
	"advplayerlist_mascot",
}

local widgetState = {
	rmlContext = nil,
	dmHandle = nil,
	document = nil,
		allyTeams = {},
	allyTeamsByID = {},
	distributionHits = {},
	selectedAllyTeamID = -1,
	spectatorSelectedAllyTeamID = nil,
	leaderAllyTeamID = -1,
	projectedLeaderAllyTeamID = -1,
	currentDeadline = 0,
	maxDeadlines = DEFAULT_MAX_DEADLINES,
	deadlineEndTimestamp = 0,
	deadlineScore = 0,
	totalTerritories = 0,
	hasDeadline = false,
	isBelowDeadline = false,
	isExpanded = false,
	hiddenByLobby = false,
	shouldShow = false,
	updateAccumulator = DATA_UPDATE_INTERVAL,
	lastUpdateClock = os.clock(),
	dragActive = false,
	isDragging = false,
	isNearOrigin = false,
	isInDanger = false,
	isInFirstPlace = false,
	dragOffsetX = 0,
	dragOffsetY = 0,
	panelPixelX = 0,
	panelPixelY = 0,
	hasUserPosition = false,
	tooltipActive = false,
	tooltipIsScore = true,
	tooltipIsSimple = false,
	tooltipAllyTeamID = nil,
	tooltipSimpleSource = nil,
	tooltipHeaderSource = nil,
	tooltipRowCount = 1,
	tooltipWidthDp = TOOLTIP_MIN_WIDTH_DP,
	popupActive = false,
	popupStartClock = 0,
	hasObservedDeadline = false,
	lastObservedDeadline = 0,
	lastWasInLead = nil,
	lastLocalPlayerInDanger = nil,
	lastDangerBelowGameSeconds = nil,
	cachedTeamColors = {},
	pendingVerticalScroll = false,
	verticalBarsOverflow = false,
	verticalContentWidthDp = VERTICAL_CONTENT_MINIMUM_WIDTH_DP,
	localPlayerSlotCenterDp = nil,
	appliedDistributionFillRml = nil,
	appliedTooltipPlayersRml = nil,
}

local function clampNumber(value, minimum, maximum)
	if value < minimum then
		return minimum
	end
	if value > maximum then
		return maximum
	end
	return value
end

local function roundNumber(value)
	return math.floor(value + 0.5)
end

local function lerpNumber(fromValue, toValue, amount)
	return fromValue + (toValue - fromValue) * amount
end

local function easeCubicInOut(amount)
	if amount < 0.5 then
		return 4 * amount * amount * amount
	end
	local inverted = -2 * amount + 2
	return 1 - (inverted * inverted * inverted) / 2
end

local function formatScore(value)
	return tostring(roundNumber(tonumber(value) or 0))
end

local function getTooltipTextLength(value)
	local text = tostring(value or "")
	if utf8 and utf8.len then
		return utf8.len(text) or #text
	end
	local length = 0
	local index = 1
	local textLength = #text
	while index <= textLength do
		local byte = string.byte(text, index)
		if byte < 128 then
			index = index + 1
		elseif byte < 224 then
			index = index + 2
		elseif byte < 240 then
			index = index + 3
		else
			index = index + 4
		end
		length = length + 1
	end
	return length
end

local function getTooltipFont()
	if not WG or not WG.fonts or not WG.fonts.getFont then
		return nil
	end
	return WG.fonts.getFont(2)
end

local function getTooltipTextWidthDp(value)
	local text = tostring(value or "")
	local font = getTooltipFont()
	if font and font.GetTextWidth then
		return font:GetTextWidth(text) * TOOLTIP_FONT_SIZE_DP
	end
	return getTooltipTextLength(text) * TOOLTIP_CHAR_WIDTH_DP
end

local function applyTooltipSize(dataModel, lineWidths)
	local widestLineDp = 0
	for lineIndex = 1, #lineWidths do
		if lineWidths[lineIndex] > widestLineDp then
			widestLineDp = lineWidths[lineIndex]
		end
	end
	local tooltipWidthDp = math.max(TOOLTIP_MIN_WIDTH_DP, math.ceil(widestLineDp + TOOLTIP_PADDING_X_DP))
	widgetState.tooltipWidthDp = tooltipWidthDp
	widgetState.tooltipRowCount = math.max(1, #lineWidths)
	dataModel.tooltipWidth = tostring(tooltipWidthDp) .. "dp"
end

local function formatPercentage(value)
	return string.format("%.3f%%", clampNumber(value, 0, 100))
end

local function formatOrdinal(place)
	local numericPlace = math.max(0, math.floor(tonumber(place) or 0))
	local finalTwoDigits = numericPlace % 100
	local suffix = "th"

	if finalTwoDigits < 11 or finalTwoDigits > 13 then
		local finalDigit = numericPlace % 10
		if finalDigit == 1 then
			suffix = "st"
		elseif finalDigit == 2 then
			suffix = "nd"
		elseif finalDigit == 3 then
			suffix = "rd"
		end
	end

	return tostring(numericPlace) .. suffix
end

local function formatCountdown(deadlineEndTimestamp, currentDeadline, maxDeadlines)
	if currentDeadline > maxDeadlines then
		return I18N("ui.territorialDomination.deadline.end"), 0
	end

	if deadlineEndTimestamp <= 0 then
		return "0:00", 0
	end

	local remainingSeconds = math.max(0, deadlineEndTimestamp - Spring.GetGameSeconds())
	local displayedSeconds = math.ceil(remainingSeconds)
	local minutes = math.floor(displayedSeconds / SECONDS_PER_MINUTE)
	local seconds = displayedSeconds % SECONDS_PER_MINUTE
	return string.format("%d:%02d", minutes, seconds), remainingSeconds
end

local function getFallbackAllyTeamTitle(allyTeamID)
	return I18N("ui.territorialDomination.team.ally", { allyNumber = allyTeamID + 1 })
end

local function getAllyTeamColor(allyTeamID, teamList)
	local cachedColor = widgetState.cachedTeamColors[allyTeamID]
	if cachedColor then
		return cachedColor
	end

	local color = {
		red = DEFAULT_COLOR.red,
		green = DEFAULT_COLOR.green,
		blue = DEFAULT_COLOR.blue,
	}

	if teamList[1] then
		local red, green, blue = Spring.GetTeamColor(teamList[1])
		color.red = red or color.red
		color.green = green or color.green
		color.blue = blue or color.blue
	end

	widgetState.cachedTeamColors[allyTeamID] = color
	return color
end

local function makeColorString(color, multiplier)
	local colorMultiplier = multiplier or 1
	local red = roundNumber(clampNumber(color.red * colorMultiplier, 0, 1) * COLOR_BYTE_MAXIMUM)
	local green = roundNumber(clampNumber(color.green * colorMultiplier, 0, 1) * COLOR_BYTE_MAXIMUM)
	local blue = roundNumber(clampNumber(color.blue * colorMultiplier, 0, 1) * COLOR_BYTE_MAXIMUM)
	return string.format("rgba(%d, %d, %d, 255)", red, green, blue)
end

local function getPlayerTeamColor(teamID)
	local red, green, blue = Spring.GetTeamColor(teamID)
	local isSpectating = Spring.GetSpectatingState()
	local anonymousMode = MOD_OPTIONS.teamcolors_anonymous_mode

	if not isSpectating and anonymousMode ~= "disabled" and teamID ~= Spring.GetLocalTeamID() then
		red = Spring.GetConfigInt("anonymousColorR", COLOR_BYTE_MAXIMUM) / COLOR_BYTE_MAXIMUM
		green = Spring.GetConfigInt("anonymousColorG", 0) / COLOR_BYTE_MAXIMUM
		blue = Spring.GetConfigInt("anonymousColorB", 0) / COLOR_BYTE_MAXIMUM
	end

	return makeColorString({
		red = red or DEFAULT_COLOR.red,
		green = green or DEFAULT_COLOR.green,
		blue = blue or DEFAULT_COLOR.blue,
	})
end

local function getAIName(teamID)
	local _, _, _, aiName = Spring.GetAIInfo(teamID)
	aiName = Spring.GetGameRulesParam("ainame_" .. teamID) or aiName or Spring.GetTeamLuaAI(teamID)
	return I18N("ui.playersList.aiName", { name = aiName or "AI" })
end

local function getAllyTeamPlayers(allyTeamID, teamList, fallbackColor)
	local players = {}
	local seenPlayerIDs = {}

	for teamIndex = 1, #teamList do
		local teamID = teamList[teamIndex]
		local playerList = Spring.GetPlayerList(teamID) or {}
		local initialPlayerCount = #players

		for playerIndex = 1, #playerList do
			local playerID = playerList[playerIndex]
			if not seenPlayerIDs[playerID] then
				local playerName, _, isSpectator = Spring.GetPlayerInfo(playerID, false)
				if playerName and not isSpectator then
					seenPlayerIDs[playerID] = true
					if WG.playernames and WG.playernames.getPlayername then
						playerName = WG.playernames.getPlayername(playerID) or playerName
					end
					players[#players + 1] = {
						name = playerName,
						color = getPlayerTeamColor(teamID),
					}
				end
			end
		end

		if #players == initialPlayerCount then
			local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)
			if isAI then
				players[#players + 1] = {
					name = getAIName(teamID),
					color = getPlayerTeamColor(teamID),
				}
			end
		end
	end

	if #players == 0 then
		players[1] = {
			name = getFallbackAllyTeamTitle(allyTeamID),
			color = fallbackColor,
		}
	end

	return players
end

local function escapeRmlText(value)
	return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function buildTooltipPlayersRml(players)
	local fallbackColor = makeColorString(DEFAULT_COLOR)
	local fillParts = {}
	if players then
		for playerIndex = 1, #players do
			local player = players[playerIndex]
			fillParts[#fillParts + 1] = string.format(
				'<div class="td-tooltip-player" style="color: %s;">%s</div>',
				player.color or fallbackColor,
				escapeRmlText(player.name)
			)
		end
	end
	return table.concat(fillParts)
end

local function applyTooltipPlayers(tooltipPlayersRml)
	if not widgetState.document then
		return
	end

	local playersElement = widgetState.document:GetElementById("td-tooltip-players")
	if not playersElement then
		widgetState.appliedTooltipPlayersRml = nil
		return
	end
	if widgetState.appliedTooltipPlayersRml == tooltipPlayersRml then
		return
	end

	playersElement.inner_rml = tooltipPlayersRml
	widgetState.appliedTooltipPlayersRml = tooltipPlayersRml
end

local function getFirstLivingTeamID(teamList)
	local firstLivingTeamID = nil
	for teamIndex = 1, #teamList do
		local teamID = teamList[teamIndex]
		local _, _, isDead = Spring.GetTeamInfo(teamID, false)
		if not isDead and (firstLivingTeamID == nil or teamID < firstLivingTeamID) then
			firstLivingTeamID = teamID
		end
	end
	return firstLivingTeamID
end

local function compareRankedAllyTeams(firstAllyTeam, secondAllyTeam)
	if firstAllyTeam.rank ~= secondAllyTeam.rank then
		return firstAllyTeam.rank < secondAllyTeam.rank
	end
	if firstAllyTeam.score ~= secondAllyTeam.score then
		return firstAllyTeam.score > secondAllyTeam.score
	end
	if firstAllyTeam.territoryCount ~= secondAllyTeam.territoryCount then
		return firstAllyTeam.territoryCount > secondAllyTeam.territoryCount
	end
	return firstAllyTeam.allyTeamID < secondAllyTeam.allyTeamID
end

local function compareAscendingScores(firstAllyTeam, secondAllyTeam)
	if firstAllyTeam.score ~= secondAllyTeam.score then
		return firstAllyTeam.score < secondAllyTeam.score
	end
	if firstAllyTeam.territoryCount ~= secondAllyTeam.territoryCount then
		return firstAllyTeam.territoryCount < secondAllyTeam.territoryCount
	end
	return firstAllyTeam.allyTeamID < secondAllyTeam.allyTeamID
end

local function collectAllyTeamData()
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	local allyTeamList = Spring.GetAllyTeamList() or {}
	local allyTeams = {}
	local allyTeamsByID = {}

	for allyTeamIndex = 1, #allyTeamList do
		local allyTeamID = allyTeamList[allyTeamIndex]
		if allyTeamID ~= gaiaAllyTeamID then
			local teamList = Spring.GetTeamList(allyTeamID) or {}
			if #teamList > 0 then
				local parameterPrefix = "territorialDomination_ally_" .. allyTeamID .. "_"
				local color = getAllyTeamColor(allyTeamID, teamList)
				local score = tonumber(Spring.GetGameRulesParam(parameterPrefix .. "score")) or 0
				local projectedScore = tonumber(Spring.GetGameRulesParam(parameterPrefix .. "projectedScore")) or score
				local firstLivingTeamID = getFirstLivingTeamID(teamList)
				local allyTeamData = {
					allyTeamID = allyTeamID,
					players = getAllyTeamPlayers(allyTeamID, teamList, makeColorString(color)),
					score = score,
					projectedScore = math.max(score, projectedScore),
					territoryCount = tonumber(Spring.GetGameRulesParam(parameterPrefix .. "territoryCount")) or 0,
					rank = tonumber(Spring.GetGameRulesParam(parameterPrefix .. "rank")) or 1,
					isAlive = firstLivingTeamID ~= nil,
					firstLivingTeamID = firstLivingTeamID,
					color = makeColorString(color),
					darkColor = makeColorString(color, DARK_COLOR_MULTIPLIER),
					outlineColor = makeColorString(color, SEGMENT_OUTLINE_COLOR_MULTIPLIER),
				}
				allyTeams[#allyTeams + 1] = allyTeamData
				allyTeamsByID[allyTeamID] = allyTeamData
		end
	end
	end

	table.sort(allyTeams, compareRankedAllyTeams)
	return allyTeams, allyTeamsByID
end

local function findLivingLeader(allyTeams)
	for allyTeamIndex = 1, #allyTeams do
		if allyTeams[allyTeamIndex].isAlive then
			return allyTeams[allyTeamIndex]
		end
	end
	return allyTeams[1]
end

local function chooseSelectedAllyTeam(allyTeams, allyTeamsByID, livingLeader)
	local isSpectating = Spring.GetSpectatingState()
	local localAllyTeamID = Spring.GetLocalAllyTeamID()

	if isSpectating then
		local spectatorSelectedAllyTeamID = widgetState.spectatorSelectedAllyTeamID
		if spectatorSelectedAllyTeamID then
			if spectatorSelectedAllyTeamID == localAllyTeamID then
				widgetState.spectatorSelectedAllyTeamID = nil
			else
				local spectatorSelectedAllyTeam = allyTeamsByID[spectatorSelectedAllyTeamID]
				if spectatorSelectedAllyTeam and spectatorSelectedAllyTeam.isAlive then
					return spectatorSelectedAllyTeam
				end
				widgetState.spectatorSelectedAllyTeamID = nil
			end
		end
	else
		widgetState.spectatorSelectedAllyTeamID = nil
	end

	local localAllyTeam = localAllyTeamID and allyTeamsByID[localAllyTeamID]
	return localAllyTeam or livingLeader or allyTeams[1]
end

local function getHighestProjectedScore(allyTeams)
	local highestProjectedScore = 0
	for allyTeamIndex = 1, #allyTeams do
		highestProjectedScore = math.max(highestProjectedScore, allyTeams[allyTeamIndex].projectedScore)
	end
	return highestProjectedScore
end

local function findHighestProjectedAllyTeam(allyTeams, selectedAllyTeam, highestProjectedScore)
	if
		selectedAllyTeam
		and selectedAllyTeam.isAlive
		and selectedAllyTeam.projectedScore == highestProjectedScore
	then
		return selectedAllyTeam
	end

	local fallbackAllyTeam = selectedAllyTeam
	for allyTeamIndex = 1, #allyTeams do
		local allyTeam = allyTeams[allyTeamIndex]
		if allyTeam.projectedScore == highestProjectedScore then
			if allyTeam.isAlive then
				return allyTeam
			end
			if fallbackAllyTeam == nil then
				fallbackAllyTeam = allyTeam
			end
		end
	end

	return fallbackAllyTeam or allyTeams[1]
end

local function buildDistributionData(allyTeams)
	local ascendingAllyTeams = {}
	local totalScore = 0

	for allyTeamIndex = 1, #allyTeams do
		local allyTeam = allyTeams[allyTeamIndex]
		ascendingAllyTeams[allyTeamIndex] = allyTeam
		totalScore = totalScore + math.max(0, allyTeam.score)
	end

	table.sort(ascendingAllyTeams, compareAscendingScores)

	local distributionHits = {}
	local fillParts = {}
	local equalFlex = 1
	local leftPercentage = 0

	for allyTeamIndex = 1, #ascendingAllyTeams do
		local allyTeam = ascendingAllyTeams[allyTeamIndex]
		local startPercentage = leftPercentage
		local scoreShare = math.max(0, allyTeam.score)
		local width = totalScore > 0 and scoreShare / totalScore * 100 or (#ascendingAllyTeams > 0 and 100 / #ascendingAllyTeams or 0)
		local flexGrow = totalScore > 0 and scoreShare or equalFlex
		if allyTeamIndex == #ascendingAllyTeams then
			width = math.max(0, 100 - startPercentage)
		end
		fillParts[#fillParts + 1] = string.format(
			'<div class="td-distribution-segment" style="flex: %.6f; width: %.3f%%; height: %s; background-color: %s; box-shadow: inset 0px 0px 0px 1px %s;"></div>',
			flexGrow,
			width,
			DISTRIBUTION_HEIGHT,
			allyTeam.color,
			allyTeam.outlineColor
		)
		distributionHits[#distributionHits + 1] = {
			allyTeamID = allyTeam.allyTeamID,
			startFraction = startPercentage / 100,
			endFraction = (startPercentage + width) / 100,
		}
		leftPercentage = startPercentage + width
	end

	return table.concat(fillParts), distributionHits, ascendingAllyTeams
end

local function buildVerticalBars(ascendingAllyTeams, verticalScale, localAllyTeamID, hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
	local verticalBars = {}
	local allyTeamCount = #ascendingAllyTeams
	local packedWidth = allyTeamCount * VERTICAL_SLOT_WIDTH_DP + VERTICAL_CONTENT_PADDING_DP
	local overflowing = packedWidth > VERTICAL_CONTENT_MINIMUM_WIDTH_DP
	local contentWidth = overflowing and packedWidth or VERTICAL_CONTENT_MINIMUM_WIDTH_DP
	local extraSpace = contentWidth - packedWidth
	local gap = allyTeamCount > 0 and extraSpace / (allyTeamCount + 1) or 0
	local sidePadding = VERTICAL_CONTENT_PADDING_DP / 2
	local localPlayerSlotCenterDp = nil
	local isSpectating = Spring.GetSpectatingState()
	local isFinalRound = currentDeadline >= maxDeadlines
	local deadlinePercent = clampNumber(deadlineScore / math.max(1, verticalScale) * 100, 0, 100)

	for allyTeamIndex = 1, allyTeamCount do
		local allyTeam = ascendingAllyTeams[allyTeamIndex]
		local slotLeft = sidePadding + gap * allyTeamIndex + VERTICAL_SLOT_WIDTH_DP * (allyTeamIndex - 1)
		if allyTeam.allyTeamID == localAllyTeamID then
			localPlayerSlotCenterDp = slotLeft + VERTICAL_SLOT_WIDTH_DP / 2
		end
		local projectedPercent = clampNumber(allyTeam.projectedScore / math.max(1, verticalScale) * 100, 0, 100)
		local overlayTopPercent = hasDeadline and deadlinePercent or 100
		local overlayHeightPercent = math.max(0, overlayTopPercent - projectedPercent)
		local showDangerOverlay = allyTeam.isAlive
			and allyTeam.rank ~= 1
			and overlayHeightPercent > 0
			and ((hasDeadline and allyTeam.projectedScore < deadlineScore) or isFinalRound)
		verticalBars[#verticalBars + 1] = {
			allyTeamID = allyTeam.allyTeamID,
			rank = formatOrdinal(allyTeam.rank),
			isAlive = allyTeam.isAlive,
			isLocalPlayer = not isSpectating and allyTeam.allyTeamID == localAllyTeamID,
			projectedHeight = formatPercentage(projectedPercent),
			darkColor = allyTeam.darkColor,
			actualHeight = formatPercentage(allyTeam.score / math.max(1, verticalScale) * 100),
			color = allyTeam.color,
			slotLeft = string.format("%.3fdp", slotLeft),
			showDangerOverlay = showDangerOverlay,
			dangerOverlayBottom = formatPercentage(projectedPercent),
			dangerOverlayHeight = formatPercentage(overlayHeightPercent),
		}
	end

	return verticalBars, overflowing, contentWidth, localPlayerSlotCenterDp
end

local function getDpRatio()
	if widgetState.rmlContext and widgetState.rmlContext.dp_ratio then
		return widgetState.rmlContext.dp_ratio
	end
	return 1
end

local function getPanelPixelSize()
	local dpRatio = getDpRatio()
	local panelHeight = widgetState.isExpanded and PANEL_EXPANDED_HEIGHT_DP or PANEL_COLLAPSED_HEIGHT_DP
	return PANEL_WIDTH_DP * dpRatio, panelHeight * dpRatio
end

local function setPanelPosition(panelPixelX, panelPixelY)
	widgetState.panelPixelX = roundNumber(panelPixelX)
	widgetState.panelPixelY = roundNumber(panelPixelY)

	if widgetState.dmHandle then
		widgetState.dmHandle.panelLeft = tostring(widgetState.panelPixelX) .. "px"
		widgetState.dmHandle.panelTop = tostring(widgetState.panelPixelY) .. "px"
	end
end

local function updateHaloState()
	if not widgetState.dmHandle then
		return
	end

	local showOriginHalo = widgetState.dragActive and widgetState.isNearOrigin
	local showFirstPlaceHalo = not widgetState.dragActive and widgetState.isInFirstPlace
	local showDangerHalo = not widgetState.dragActive and not showFirstPlaceHalo and widgetState.isInDanger
	widgetState.dmHandle.showOriginHalo = showOriginHalo
	widgetState.dmHandle.showFirstPlaceHalo = showFirstPlaceHalo
	widgetState.dmHandle.showDangerHalo = showDangerHalo
	widgetState.dmHandle.showDockGhost = widgetState.dragActive
end

local function clampPanelPosition(panelPixelX, panelPixelY)
	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local panelWidth, panelHeight = getPanelPixelSize()
	local maximumX = math.max(0, viewSizeX - panelWidth)
	local maximumY = math.max(0, viewSizeY - panelHeight)
	setPanelPosition(clampNumber(panelPixelX, 0, maximumX), clampNumber(panelPixelY, 0, maximumY))
end

local function isStoredPanelDocked()
	local dockedString = Spring.GetConfigString(PANEL_DOCKED_KEY, "")
	if dockedString == tostring(PANEL_DOCKED_VALUE) then
		return true
	end
	if dockedString == tostring(PANEL_UNDOCKED_VALUE) then
		return false
	end

	local positionXString = Spring.GetConfigString(PANEL_POSITION_X_KEY, "")
	local positionYString = Spring.GetConfigString(PANEL_POSITION_Y_KEY, "")
	if positionXString == "" or positionYString == "" then
		return true
	end

	local storedPositionX = tonumber(positionXString)
	local storedPositionY = tonumber(positionYString)
	if not storedPositionX or not storedPositionY then
		return true
	end

	return storedPositionX < 0 or storedPositionY < 0
end

local function savePanelPosition()
	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	if viewSizeX <= 0 or viewSizeY <= 0 then
		return
	end

	Spring.SetConfigInt(PANEL_DOCKED_KEY, PANEL_UNDOCKED_VALUE)
	Spring.SetConfigInt(PANEL_POSITION_X_KEY, roundNumber(widgetState.panelPixelX / viewSizeX * POSITION_SCALE))
	Spring.SetConfigInt(PANEL_POSITION_Y_KEY, roundNumber(widgetState.panelPixelY / viewSizeY * POSITION_SCALE))
	widgetState.hasUserPosition = true
end

local function savePanelDocked()
	Spring.SetConfigInt(PANEL_DOCKED_KEY, PANEL_DOCKED_VALUE)
	widgetState.hasUserPosition = false
end

local function getFlowUIPanelTop(panelAPI)
	if not panelAPI or not panelAPI.GetPosition then
		return nil, nil
	end
	if panelAPI.isActive and not panelAPI.isActive() then
		return nil, nil
	end

	local panelPosition = panelAPI.GetPosition()
	if type(panelPosition) ~= "table" or type(panelPosition[1]) ~= "number" then
		return nil, nil
	end
	return panelPosition[1], tonumber(panelPosition[5]) or 1
end

local function getFlowUIAnchorTop()
	local highestPanelTop = 0

	for panelIndex = 1, #FLOW_UI_PANEL_API_NAMES do
		local panelTop = getFlowUIPanelTop(WG[FLOW_UI_PANEL_API_NAMES[panelIndex]])
		if panelTop and panelTop > highestPanelTop then
			highestPanelTop = panelTop
		end
	end

	return highestPanelTop
end

local function getPanelOriginPosition()
	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local panelWidth, panelHeight = getPanelPixelSize()
	local margin = PANEL_MARGIN_DP * getDpRatio()
	local flowUIAnchorTop = getFlowUIAnchorTop()
	local maximumX = math.max(0, viewSizeX - panelWidth)
	local maximumY = math.max(0, viewSizeY - panelHeight)
	local panelPixelX = clampNumber(viewSizeX - panelWidth, 0, maximumX)
	local panelPixelY = clampNumber(viewSizeY - flowUIAnchorTop - panelHeight - margin, 0, maximumY)
	return panelPixelX, panelPixelY
end

local function updateDockGhostPosition()
	if not widgetState.dmHandle then
		return
	end

	local dockGhostPixelX, dockGhostPixelY = getPanelOriginPosition()
	widgetState.dmHandle.dockGhostLeft = tostring(roundNumber(dockGhostPixelX)) .. "px"
	widgetState.dmHandle.dockGhostTop = tostring(roundNumber(dockGhostPixelY)) .. "px"
end

local function positionPanelAtOrigin()
	local panelPixelX, panelPixelY = getPanelOriginPosition()
	setPanelPosition(panelPixelX, panelPixelY)
	widgetState.hasUserPosition = false
end

local function loadPanelPosition()
	if REVERT_TO_ORIGIN_POSITION or isStoredPanelDocked() then
		positionPanelAtOrigin()
		return
	end

	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local storedPositionX = Spring.GetConfigInt(PANEL_POSITION_X_KEY, -1)
	local storedPositionY = Spring.GetConfigInt(PANEL_POSITION_Y_KEY, -1)
	if storedPositionX < 0 or storedPositionY < 0 then
		positionPanelAtOrigin()
		return
	end

	widgetState.hasUserPosition = true
	clampPanelPosition(storedPositionX / POSITION_SCALE * viewSizeX, storedPositionY / POSITION_SCALE * viewSizeY)
end

local function finishPanelDrag()
	if not widgetState.dragActive then
		return
	end
	widgetState.dragActive = false
	widgetState.isDragging = false
	local shouldSnapToOrigin = widgetState.isNearOrigin or REVERT_TO_ORIGIN_POSITION
	widgetState.isNearOrigin = false
	if widgetState.dmHandle then
		widgetState.dmHandle.isDragging = false
	end
	if shouldSnapToOrigin then
		positionPanelAtOrigin()
		savePanelDocked()
	else
		savePanelPosition()
	end
	updateHaloState()
end

local function updatePanelDrag()
	if not widgetState.dragActive then
		return
	end

	local mouseX, mouseY, _, _, _, isOffscreen = Spring.GetMouseState()
	if isOffscreen then
		return
	end

	local _, viewSizeY = Spring.GetViewGeometry()
	local draggedPanelPixelX = mouseX - widgetState.dragOffsetX
	local draggedPanelPixelY = viewSizeY - mouseY - widgetState.dragOffsetY
	local originPanelPixelX, originPanelPixelY = getPanelOriginPosition()
	local originDeltaX = draggedPanelPixelX - originPanelPixelX
	local originDeltaY = draggedPanelPixelY - originPanelPixelY
	local snapDistance = PANEL_ORIGIN_SNAP_DISTANCE_DP * getDpRatio()
	widgetState.isNearOrigin = originDeltaX * originDeltaX + originDeltaY * originDeltaY <= snapDistance * snapDistance

	if widgetState.isNearOrigin then
		setPanelPosition(originPanelPixelX, originPanelPixelY)
	else
		clampPanelPosition(draggedPanelPixelX, draggedPanelPixelY)
	end
	updateDockGhostPosition()
	updateHaloState()
end

local function getTooltipElement()
	if not widgetState.document then
		return nil
	end
	return widgetState.document:GetElementById("td-tooltip")
end

local function positionTooltip()
	if not widgetState.tooltipActive or not widgetState.dmHandle then
		return
	end

	local mouseX, mouseY, _, _, _, isOffscreen = Spring.GetMouseState()
	if isOffscreen then
		widgetState.tooltipActive = false
		widgetState.dmHandle.tooltipVisible = false
		return
	end

	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local dpRatio = getDpRatio()
	local tooltipElement = getTooltipElement()
	local tooltipWidth = widgetState.tooltipWidthDp * dpRatio
	local tooltipHeight = tooltipElement and tooltipElement.offset_height or 0
	if tooltipHeight < 1 then
		tooltipHeight = (TOOLTIP_VERTICAL_PADDING_DP + widgetState.tooltipRowCount * TOOLTIP_ROW_HEIGHT_DP) * dpRatio
	end
	local tooltipX = clampNumber(mouseX + TOOLTIP_OFFSET_X, 0, math.max(0, viewSizeX - tooltipWidth))
	local tooltipY = clampNumber(viewSizeY - mouseY + TOOLTIP_OFFSET_Y, 0, math.max(0, viewSizeY - tooltipHeight))

	widgetState.dmHandle.tooltipLeft = string.format("%.3fvw", tooltipX / math.max(1, viewSizeX) * 100)
	widgetState.dmHandle.tooltipTop = string.format("%.3fvh", tooltipY / math.max(1, viewSizeY) * 100)
end

local function getAllyTeamGainRate(allyTeam)
	if
		not allyTeam
		or not allyTeam.isAlive
		or widgetState.currentDeadline > widgetState.maxDeadlines
		or widgetState.currentDeadline <= 0
	then
		return 0
	end
	return allyTeam.territoryCount * widgetState.currentDeadline * TERRITORY_POINTS_PER_DEADLINE
end

local function getTooltipHeaderText()
	if widgetState.tooltipHeaderSource == TOOLTIP_HEADER_EXPAND then
		return I18N("ui.territorialDomination.tooltip.clickToExpand")
	end
	if widgetState.tooltipHeaderSource == TOOLTIP_HEADER_SELECT then
		return I18N("ui.territorialDomination.tooltip.clickToSelect")
	end
	return ""
end

local function updateScoreTooltipContent(allyTeamID)
	local dataModel = widgetState.dmHandle
	local allyTeam = widgetState.allyTeamsByID[allyTeamID]
	if not dataModel or not allyTeam then
		return false
	end

	local leader = widgetState.allyTeamsByID[widgetState.leaderAllyTeamID] or allyTeam
	local pointsBelowDeadline = math.max(0, widgetState.deadlineScore - allyTeam.score)
	local pointsBelowLeader = math.max(0, leader.score - allyTeam.score)
	local showDeadline = widgetState.hasDeadline and pointsBelowDeadline > 0
	local showLeader = pointsBelowLeader > 0

	widgetState.tooltipIsSimple = false
	widgetState.tooltipSimpleSource = nil
	dataModel.tooltipIsSimple = false
	dataModel.tooltipPlayersRml = buildTooltipPlayersRml(allyTeam.players)
	dataModel.tooltipTerritories =
		I18N("ui.territorialDomination.tooltip.territories", { count = allyTeam.territoryCount })
	dataModel.tooltipGainRate =
		I18N("ui.territorialDomination.tooltip.gainRate", { points = formatScore(getAllyTeamGainRate(allyTeam)) })
	dataModel.tooltipCurrentScore =
		I18N("ui.territorialDomination.tooltip.currentPoints", { points = formatScore(allyTeam.score) })
	dataModel.tooltipProjectedScore =
		I18N("ui.territorialDomination.tooltip.projectedPoints", { points = formatScore(allyTeam.projectedScore) })
	dataModel.tooltipShowDeadline = showDeadline
	dataModel.tooltipDeadlineDifference =
		I18N("ui.territorialDomination.tooltip.belowDeadline", { points = formatScore(pointsBelowDeadline) })
	dataModel.tooltipShowLeader = showLeader
	dataModel.tooltipShowTeam = true
	dataModel.tooltipTeamLabel = I18N("ui.territorialDomination.tooltip.team")
	dataModel.tooltipTeamColor = allyTeam.color
	dataModel.tooltipLeaderDifference =
		I18N("ui.territorialDomination.tooltip.belowLeader", { points = formatScore(pointsBelowLeader) })
	dataModel.tooltipLeaderColor = leader.color
	dataModel.tooltipTitle = ""
	dataModel.tooltipHeader = getTooltipHeaderText()
	local lineWidths = {
		getTooltipTextWidthDp(dataModel.tooltipTeamLabel) + TOOLTIP_TEAM_EXTRA_DP,
		getTooltipTextWidthDp(dataModel.tooltipTerritories),
		getTooltipTextWidthDp(dataModel.tooltipGainRate),
		getTooltipTextWidthDp(dataModel.tooltipCurrentScore),
		getTooltipTextWidthDp(dataModel.tooltipProjectedScore),
	}
	if dataModel.tooltipHeader ~= "" then
		lineWidths[#lineWidths + 1] = getTooltipTextWidthDp(dataModel.tooltipHeader)
	end
	if allyTeam.players then
		for playerIndex = 1, #allyTeam.players do
			lineWidths[#lineWidths + 1] = getTooltipTextWidthDp(allyTeam.players[playerIndex].name)
		end
	end
	if showDeadline then
		lineWidths[#lineWidths + 1] = getTooltipTextWidthDp(dataModel.tooltipDeadlineDifference)
	end
	if showLeader then
		lineWidths[#lineWidths + 1] = getTooltipTextWidthDp(dataModel.tooltipLeaderDifference)
			+ getTooltipTextWidthDp(dataModel.tooltipTeamLabel)
			+ TOOLTIP_TEAM_EXTRA_DP
	end
	applyTooltipSize(dataModel, lineWidths)
	return true
end

local function updateSimpleTooltipContent()
	local dataModel = widgetState.dmHandle
	if not dataModel then
		return false
	end

	local tooltipText
	if widgetState.tooltipSimpleSource == TOOLTIP_SOURCE_CURRENT_SCORE then
		tooltipText = dataModel.footerScoreTooltip
	elseif widgetState.tooltipSimpleSource == TOOLTIP_SOURCE_COUNTDOWN then
		tooltipText = dataModel.footerCountdownTooltip
	elseif widgetState.tooltipSimpleSource == TOOLTIP_SOURCE_TARGET then
		tooltipText = dataModel.footerTargetTooltip
	elseif widgetState.tooltipSimpleSource == TOOLTIP_SOURCE_DANGER then
		tooltipText = dataModel.dangerMarkTooltip
	elseif widgetState.tooltipSimpleSource == TOOLTIP_SOURCE_DEADLINE then
		tooltipText = dataModel.deadlineLineTooltip
	else
		return false
	end

	dataModel.tooltipIsSimple = true
	dataModel.tooltipIsScore = false
	dataModel.tooltipText = tooltipText
	dataModel.tooltipTitle = ""
	dataModel.tooltipHeader = ""
	dataModel.tooltipShowTeam = false
	dataModel.tooltipShowLeader = false
	applyTooltipSize(dataModel, { getTooltipTextWidthDp(tooltipText) })
	return true
end

local function updateProjectedLeaderTooltipContent()
	local dataModel = widgetState.dmHandle
	local projectedLeader = widgetState.allyTeamsByID[widgetState.projectedLeaderAllyTeamID]
	if not dataModel or not projectedLeader then
		return false
	end

	local selectedAllyTeam = widgetState.allyTeamsByID[widgetState.selectedAllyTeamID]
	local isSelectedProjectedLeader = selectedAllyTeam ~= nil
		and selectedAllyTeam.allyTeamID == projectedLeader.allyTeamID

	widgetState.tooltipIsSimple = false
	widgetState.tooltipIsScore = false
	widgetState.tooltipSimpleSource = TOOLTIP_SOURCE_TARGET
	dataModel.tooltipIsSimple = false
	dataModel.tooltipIsScore = false
	dataModel.tooltipTitle = isSelectedProjectedLeader
			and I18N("ui.territorialDomination.tooltip.highestProjectedScoreYou")
		or I18N("ui.territorialDomination.tooltip.highestProjectedScore")
	dataModel.tooltipHeader = ""
	dataModel.tooltipShowTeam = true
	dataModel.tooltipShowLeader = false
	dataModel.tooltipTeamLabel = I18N("ui.territorialDomination.tooltip.team")
	dataModel.tooltipTeamColor = projectedLeader.color
	dataModel.tooltipLeaderColor = projectedLeader.color
	dataModel.tooltipPlayersRml = buildTooltipPlayersRml(projectedLeader.players)
	dataModel.tooltipText = ""
	local lineWidths = {
		getTooltipTextWidthDp(dataModel.tooltipTitle),
		getTooltipTextWidthDp(dataModel.tooltipTeamLabel) + TOOLTIP_TEAM_EXTRA_DP,
	}
	if projectedLeader.players then
		for playerIndex = 1, #projectedLeader.players do
			lineWidths[#lineWidths + 1] = getTooltipTextWidthDp(projectedLeader.players[playerIndex].name)
		end
	end
	applyTooltipSize(dataModel, lineWidths)
	return true
end

local function showScoreTooltip(event, allyTeamID, tooltipHeaderSource)
	widgetState.tooltipIsScore = true
	widgetState.tooltipAllyTeamID = tonumber(allyTeamID)
	widgetState.tooltipHeaderSource = tooltipHeaderSource
	widgetState.tooltipActive = updateScoreTooltipContent(widgetState.tooltipAllyTeamID)

	if widgetState.dmHandle then
		widgetState.dmHandle.tooltipIsScore = true
		widgetState.dmHandle.tooltipVisible = widgetState.tooltipActive and widgetState.shouldShow
		applyTooltipPlayers(widgetState.dmHandle.tooltipPlayersRml)
	end
	positionTooltip()
end

local function showSimpleTooltip(tooltipSource)
	widgetState.tooltipIsScore = false
	widgetState.tooltipIsSimple = true
	widgetState.tooltipAllyTeamID = nil
	widgetState.tooltipSimpleSource = tooltipSource
	widgetState.tooltipHeaderSource = nil
	widgetState.tooltipActive = updateSimpleTooltipContent()

	if widgetState.dmHandle then
		widgetState.dmHandle.tooltipVisible = widgetState.tooltipActive and widgetState.shouldShow
	end
	positionTooltip()
end

local function showDangerMarkTooltip(event)
	showSimpleTooltip(TOOLTIP_SOURCE_DANGER)
	if event and event.StopPropagation then
		event:StopPropagation()
	end
end

local function showCurrentScoreTooltip(event)
	showSimpleTooltip(TOOLTIP_SOURCE_CURRENT_SCORE)
end

local function showCountdownTooltip(event)
	showSimpleTooltip(TOOLTIP_SOURCE_COUNTDOWN)
end

local function showTargetTooltip(event)
	if widgetState.isBelowDeadline then
		showSimpleTooltip(TOOLTIP_SOURCE_DEADLINE)
		return
	end

	widgetState.tooltipIsScore = false
	widgetState.tooltipIsSimple = false
	widgetState.tooltipAllyTeamID = widgetState.projectedLeaderAllyTeamID
	widgetState.tooltipSimpleSource = TOOLTIP_SOURCE_TARGET
	widgetState.tooltipHeaderSource = nil
	widgetState.tooltipActive = updateProjectedLeaderTooltipContent()

	if widgetState.dmHandle then
		widgetState.dmHandle.tooltipIsScore = false
		widgetState.dmHandle.tooltipVisible = widgetState.tooltipActive and widgetState.shouldShow
		applyTooltipPlayers(widgetState.dmHandle.tooltipPlayersRml)
	end
	positionTooltip()
end

local function showDeadlineLineTooltip(event)
	showSimpleTooltip(TOOLTIP_SOURCE_DEADLINE)
end

local function hideTooltip(event)
	widgetState.tooltipActive = false
	widgetState.tooltipAllyTeamID = nil
	widgetState.tooltipSimpleSource = nil
	widgetState.tooltipHeaderSource = nil
	if widgetState.dmHandle then
		widgetState.dmHandle.tooltipVisible = false
	end
end

local function hideDangerMarkTooltip(event)
	if widgetState.selectedAllyTeamID ~= nil then
		showScoreTooltip(event, widgetState.selectedAllyTeamID)
	else
		hideTooltip()
	end
end

local function getDistributionAllyTeamIDAtMouse()
	local distributionHits = widgetState.distributionHits
	if not distributionHits or #distributionHits == 0 then
		return nil
	end

	local mouseX = Spring.GetMouseState()
	local dpRatio = getDpRatio()
	local innerLeft = widgetState.panelPixelX + (DISTRIBUTION_LEFT_DP + DISTRIBUTION_BORDER_DP) * dpRatio
	local innerWidth = math.max(1, (DISTRIBUTION_WIDTH_DP - DISTRIBUTION_BORDER_DP * 2) * dpRatio)
	local fraction = clampNumber((mouseX - innerLeft) / innerWidth, 0, 0.999999)

	for hitIndex = 1, #distributionHits do
		local distributionHit = distributionHits[hitIndex]
		if fraction >= distributionHit.startFraction and fraction < distributionHit.endFraction then
			return distributionHit.allyTeamID
		end
	end

	return distributionHits[#distributionHits].allyTeamID
end

local function showDistributionTooltip(event)
	local allyTeamID = getDistributionAllyTeamIDAtMouse()
	if allyTeamID == nil then
		hideTooltip()
		return
	end
	showScoreTooltip(event, allyTeamID, TOOLTIP_HEADER_EXPAND)
end

local function showVerticalBarTooltip(event, allyTeamID)
	showScoreTooltip(event, allyTeamID, TOOLTIP_HEADER_SELECT)
end

local function isScrollbarElement(element)
	while element do
		local tagName = element.tag_name
		if
			tagName == "scrollbarhorizontal"
			or tagName == "scrollbarvertical"
			or tagName == "sliderbar"
			or tagName == "slidertrack"
			or tagName == "sliderarrowdec"
			or tagName == "sliderarrowinc"
		then
			return true
		end
		element = element.parent_node
	end
	return false
end

local function beginPanelDrag(event)
	local eventParameters = event and event.parameters
	if eventParameters and eventParameters.button and eventParameters.button ~= 0 then
		return
	end

	if event and isScrollbarElement(event.target_element) then
		return
	end

	local mouseX, mouseY = Spring.GetMouseState()
	local _, viewSizeY = Spring.GetViewGeometry()
	widgetState.dragActive = true
	widgetState.isDragging = true
	widgetState.isNearOrigin = false
	widgetState.dragOffsetX = mouseX - widgetState.panelPixelX
	widgetState.dragOffsetY = viewSizeY - mouseY - widgetState.panelPixelY
	if widgetState.dmHandle then
		widgetState.dmHandle.isDragging = true
	end
	hideTooltip()
	updateDockGhostPosition()
	updateHaloState()

	if event and event.StopPropagation then
		event:StopPropagation()
	end
end

local function blockPanelDrag(event)
	if event and event.StopPropagation then
		event:StopPropagation()
	end
end

local function getExpandedScrollTarget(clientWidth, scrollWidth)
	local maximumScroll = math.max(0, scrollWidth - clientWidth)
	if Spring.GetSpectatingState() then
		return maximumScroll
	end

	local slotCenterDp = widgetState.localPlayerSlotCenterDp
	local contentWidthDp = widgetState.verticalContentWidthDp
	if slotCenterDp == nil or contentWidthDp == nil or contentWidthDp <= 0 then
		return 0
	end

	return clampNumber(slotCenterDp / contentWidthDp * scrollWidth - clientWidth / 2, 0, maximumScroll)
end

local function applyExpandedScroll()
	if not widgetState.pendingVerticalScroll or not widgetState.isExpanded or not widgetState.document then
		return
	end

	-- rml-dom-escape: RmlUi cannot data-bind scroll_left; initial expand viewport must be measured after layout
	local scrollElement = widgetState.document:GetElementById("td-vertical-scroll")
	if not scrollElement then
		return
	end

	local clientWidth = scrollElement.client_width or 0
	local scrollWidth = scrollElement.scroll_width or 0
	if clientWidth <= 0 then
		return
	end
	if widgetState.verticalBarsOverflow and scrollWidth <= clientWidth then
		return
	end

	scrollElement.scroll_left = roundNumber(getExpandedScrollTarget(clientWidth, scrollWidth))
	widgetState.pendingVerticalScroll = false
end

local function applyDistributionFill(distributionFillRml)
	if not widgetState.document then
		return
	end

	local fillElement = widgetState.document:GetElementById("td-distribution-fill")
	if not fillElement then
		return
	end
	if widgetState.appliedDistributionFillRml == distributionFillRml then
		return
	end

	-- rml-dom-escape: Recoil data-for walks Lua tables with pairs(), so sorted arrays never reach layout
	fillElement.inner_rml = distributionFillRml
	widgetState.appliedDistributionFillRml = distributionFillRml
end

local function setExpandedState(isExpanded)
	if widgetState.isExpanded == isExpanded then
		return
	end

	local expandedHeightDifference = (PANEL_EXPANDED_HEIGHT_DP - PANEL_COLLAPSED_HEIGHT_DP) * getDpRatio()
	widgetState.isExpanded = isExpanded
	widgetState.pendingVerticalScroll = isExpanded
	if widgetState.dmHandle then
		widgetState.dmHandle.isExpanded = widgetState.isExpanded
		widgetState.dmHandle.showHorizontalDangerOutline = widgetState.dmHandle.showDangerMark and not widgetState.isExpanded
	end
	if REVERT_TO_ORIGIN_POSITION or not widgetState.hasUserPosition then
		positionPanelAtOrigin()
	else
		local adjustedPanelPixelY = widgetState.panelPixelY
			+ (isExpanded and -expandedHeightDifference or expandedHeightDifference)
		clampPanelPosition(widgetState.panelPixelX, adjustedPanelPixelY)
	end
	applyExpandedScroll()
end

local function toggleExpanded(event)
	setExpandedState(not widgetState.isExpanded)
	hideTooltip()
	if widgetState.hasUserPosition and not REVERT_TO_ORIGIN_POSITION then
		savePanelPosition()
	end

	if event and event.StopPropagation then
		event:StopPropagation()
		end
	end

local function adoptSpectatorTeam(teamID)
	local oldMapDrawMode = Spring.GetMapDrawMode()
	if Spring.SelectUnitArray then
		Spring.SelectUnitArray({})
	end
	Spring.SendCommands("specteam " .. teamID)
	local newMapDrawMode = Spring.GetMapDrawMode()
	if oldMapDrawMode == "los" and oldMapDrawMode ~= newMapDrawMode then
		Spring.SendCommands("togglelos")
		end
	end

local function selectExpandedScore(event, allyTeamID)
	if not widgetState.isExpanded then
		return
	end

	if Spring.GetSpectatingState() then
		local selectedAllyTeamID = tonumber(allyTeamID)
		local selectedAllyTeam = selectedAllyTeamID and widgetState.allyTeamsByID[selectedAllyTeamID]
		if selectedAllyTeam and selectedAllyTeam.firstLivingTeamID then
			widgetState.spectatorSelectedAllyTeamID = selectedAllyTeamID
			adoptSpectatorTeam(selectedAllyTeam.firstLivingTeamID)
		else
			widgetState.spectatorSelectedAllyTeamID = nil
		end
	else
		widgetState.spectatorSelectedAllyTeamID = nil
	end

	setExpandedState(false)
	hideTooltip()
	widgetState.updateAccumulator = DATA_UPDATE_INTERVAL

	if event and event.StopPropagation then
		event:StopPropagation()
	end
end

local function initializeModel()
	return {
		isVisible = false,
		isExpanded = false,
		isDragging = false,
		showOriginHalo = false,
		showDockGhost = false,
		showFirstPlaceHalo = false,
		showDangerHalo = false,
		panelLeft = "0px",
		panelTop = "0px",
		dockGhostLeft = "0px",
		dockGhostTop = "0px",
		distributionFillRml = "",
		distributionHeight = DISTRIBUTION_HEIGHT,
		selectedAllyTeamID = -1,
		selectedProjectedWidth = "0%",
		selectedDarkColor = makeColorString(DEFAULT_COLOR, DARK_COLOR_MULTIPLIER),
		selectedActualWidth = "0%",
		selectedColor = makeColorString(DEFAULT_COLOR),
		showDangerMark = false,
		showHorizontalDangerOutline = false,
		dangerOverlayWidth = "100%",
		showDeadlineExcessBackfill = false,
		deadlineExcessBackfillWidth = "0%",
		hasDeadline = false,
		isBelowDeadline = false,
		deadlineLineBottom = tostring(VERTICAL_TRACK_BOTTOM_DP) .. "dp",
		deadlineLabel = DEADLINE_SKULL_ICON,
		deadlineLabelBottom = tostring(DEADLINE_LABEL_OFFSET_DP) .. "dp",
		verticalContentWidth = tostring(VERTICAL_CONTENT_MINIMUM_WIDTH_DP) .. "dp",
		verticalBarsOverflow = false,
		verticalBars = {},
		footerScore = "0",
		countdownWarning = false,
		countdownPulseColor = COUNTDOWN_IDLE_COLOR,
		countdownPulseTransform = COUNTDOWN_IDLE_TRANSFORM,
		footerCountdown = "0:00",
		footerTargetIcon = TROPHY_ICON,
		footerTargetValue = "0",
		footerTargetIconColor = makeColorString(DEFAULT_COLOR),
		tooltipVisible = false,
		tooltipLeft = "0px",
		tooltipTop = "0px",
		tooltipWidth = tostring(TOOLTIP_MIN_WIDTH_DP) .. "dp",
		tooltipIsScore = true,
		tooltipIsSimple = false,
		tooltipText = "",
		tooltipTitle = "",
		tooltipHeader = "",
		tooltipPlayersRml = "",
		tooltipTerritories = "",
		tooltipGainRate = "",
		tooltipCurrentScore = "",
		tooltipProjectedScore = "",
		tooltipShowDeadline = false,
		tooltipDeadlineDifference = "",
		tooltipShowLeader = false,
		tooltipShowTeam = false,
		tooltipTeamLabel = "",
		tooltipTeamColor = makeColorString(DEFAULT_COLOR),
		tooltipLeaderDifference = "",
		tooltipLeaderColor = makeColorString(DEFAULT_COLOR),
		footerScoreTooltip = I18N("ui.territorialDomination.tooltip.currentScore"),
		footerCountdownTooltip = I18N("ui.territorialDomination.tooltip.timeUntilFirstDeadline"),
		footerTargetTooltip = I18N("ui.territorialDomination.tooltip.highestScore"),
		dangerMarkTooltip = I18N("ui.territorialDomination.tooltip.eliminationDanger"),
		deadlineLineTooltip = I18N("ui.territorialDomination.tooltip.deadlineScore"),
		popupVisible = false,
		popupTitle = "",
		popupRateText = "",
		popupDeadlineText = "",
		beginPanelDrag = beginPanelDrag,
		blockPanelDrag = blockPanelDrag,
		toggleExpanded = toggleExpanded,
		selectExpandedScore = selectExpandedScore,
		hideTooltip = hideTooltip,
		showScoreTooltip = showScoreTooltip,
		showDistributionTooltip = showDistributionTooltip,
		showVerticalBarTooltip = showVerticalBarTooltip,
		showCurrentScoreTooltip = showCurrentScoreTooltip,
		showCountdownTooltip = showCountdownTooltip,
		showTargetTooltip = showTargetTooltip,
		showDeadlineLineTooltip = showDeadlineLineTooltip,
		showDangerMarkTooltip = showDangerMarkTooltip,
		hideDangerMarkTooltip = hideDangerMarkTooltip,
	}
end

local function getShouldShow()
	local _, _, isClientPaused = Spring.GetGameState()
	local isGUIHidden = Spring.IsGUIHidden and Spring.IsGUIHidden()
	return Spring.GetGameSeconds() > 0
		and widgetState.totalTerritories > 0
		and not isClientPaused
		and not isGUIHidden
		and not widgetState.hiddenByLobby
end

local function synchronizeVisibility()
	if not widgetState.dmHandle then
		return
	end

	widgetState.shouldShow = getShouldShow()
	widgetState.dmHandle.isVisible = widgetState.shouldShow
	widgetState.dmHandle.popupVisible = widgetState.popupActive and widgetState.shouldShow

	if not widgetState.shouldShow then
		widgetState.tooltipActive = false
		widgetState.tooltipAllyTeamID = nil
	end
	widgetState.dmHandle.tooltipVisible = widgetState.tooltipActive and widgetState.shouldShow
end

local function hidePopup()
	widgetState.popupActive = false
	if widgetState.dmHandle then
		widgetState.dmHandle.popupVisible = false
	end
end

local function countLivingLeaders(allyTeams, livingLeader)
	if not livingLeader then
		return 0
	end

	local livingLeaderCount = 0
	for allyTeamIndex = 1, #allyTeams do
		local allyTeam = allyTeams[allyTeamIndex]
		if allyTeam.isAlive and allyTeam.rank == livingLeader.rank then
			livingLeaderCount = livingLeaderCount + 1
		end
	end
	return livingLeaderCount
end

local function getFinalPopupTitle(allyTeams, livingLeader)
	if countLivingLeaders(allyTeams, livingLeader) > 1 then
		return I18N("ui.territorialDomination.deadline.end")
	end

	local isSpectating = Spring.GetSpectatingState()
	if isSpectating then
		return I18N("ui.territorialDomination.deadlinePopup.gameOver")
	end

	local localAllyTeamID = Spring.GetLocalAllyTeamID()
	if livingLeader and livingLeader.allyTeamID == localAllyTeamID then
		return I18N("ui.territorialDomination.deadlinePopup.victory")
	end
	return I18N("ui.territorialDomination.deadlinePopup.defeat")
end

local function showPopup(title, rateText, deadlineText)
	if not widgetState.dmHandle then
		return
	end

	widgetState.dmHandle.popupTitle = title
	widgetState.dmHandle.popupRateText = rateText or ""
	widgetState.dmHandle.popupDeadlineText = deadlineText or ""
	widgetState.popupActive = true
	widgetState.popupStartClock = os.clock()
	local shouldShow = getShouldShow()
	widgetState.dmHandle.popupVisible = shouldShow

	if shouldShow then
		Spring.PlaySoundFile("sounds/global-events/scavlootdrop.wav", 0.8, "ui")
		Spring.PlaySoundFile("sounds/replies/servlrg3.wav", 1, "ui")
	end
end

local function showDeadlinePopup(currentDeadline, maxDeadlines, deadlineScore, allyTeams, livingLeader)
	local title
	local rateText = ""
	local deadlineText = ""

	if currentDeadline > maxDeadlines then
		title = getFinalPopupTitle(allyTeams, livingLeader)
	else
		if currentDeadline == maxDeadlines then
			title = I18N("ui.territorialDomination.deadlinePopup.finalDeadline")
		else
			title = I18N("ui.territorialDomination.deadlinePopup.deadline", { deadlineNumber = currentDeadline })
		end
		rateText =
			I18N("ui.territorialDomination.deadlinePopup.territoryRate", { points = formatScore(currentDeadline * TERRITORY_POINTS_PER_DEADLINE) })
		if deadlineScore > 0 and currentDeadline < maxDeadlines then
			deadlineText = I18N(
				"ui.territorialDomination.deadlinePopup.eliminationBelow",
				{ threshold = formatScore(deadlineScore) }
			)
		end
	end

	showPopup(title, rateText, deadlineText)
end

local function updateDeadlinePopup(currentDeadline, maxDeadlines, deadlineScore, allyTeams, livingLeader)
	if currentDeadline <= 0 or maxDeadlines <= 0 or Spring.GetGameSeconds() <= 0 then
		return
	end

	if not widgetState.hasObservedDeadline then
		widgetState.hasObservedDeadline = true
		widgetState.lastObservedDeadline = currentDeadline
		if currentDeadline == 1 and Spring.GetGameSeconds() <= POPUP_INITIAL_WINDOW_SECONDS then
			showDeadlinePopup(currentDeadline, maxDeadlines, deadlineScore, allyTeams, livingLeader)
		end
		return
	end

	if currentDeadline ~= widgetState.lastObservedDeadline then
		widgetState.lastObservedDeadline = currentDeadline
		showDeadlinePopup(currentDeadline, maxDeadlines, deadlineScore, allyTeams, livingLeader)
	end
end

local function updateLeadNotification(livingLeader)
	local isSpectating = Spring.GetSpectatingState()
	local localAllyTeamID = Spring.GetLocalAllyTeamID()
	local localAllyTeam = widgetState.allyTeamsByID[localAllyTeamID]

	if isSpectating or not localAllyTeam then
		widgetState.lastWasInLead = nil
		return
	end

	local isInLead = (localAllyTeam.isAlive and livingLeader and livingLeader.allyTeamID == localAllyTeam.allyTeamID)
			and true
		or false

	if widgetState.lastWasInLead == nil then
		widgetState.lastWasInLead = isInLead
		return
	end

	if isInLead ~= widgetState.lastWasInLead then
		if WG.notifications and WG.notifications.addEvent then
			if isInLead then
				WG.notifications.addEvent("TerritorialDomination/GainedLead", false)
			else
				WG.notifications.addEvent("TerritorialDomination/LostLead", false)
			end
		end
		widgetState.lastWasInLead = isInLead
	end
end

local function isLocalPlayerInDanger(localAllyTeam, hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
	if Spring.GetSpectatingState() or not localAllyTeam or not localAllyTeam.isAlive then
		return false
	end
	if localAllyTeam.rank == 1 then
		return false
	end
	return (hasDeadline and localAllyTeam.projectedScore < deadlineScore) or (currentDeadline >= maxDeadlines)
end

local function updateDangerPopup(hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
	local localAllyTeam = widgetState.allyTeamsByID[Spring.GetLocalAllyTeamID()]
	if Spring.GetSpectatingState() or not localAllyTeam then
		widgetState.lastLocalPlayerInDanger = nil
		return
	end

	local inDanger = isLocalPlayerInDanger(localAllyTeam, hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
	local gameSeconds = Spring.GetGameSeconds()

	if widgetState.lastLocalPlayerInDanger == nil then
		widgetState.lastLocalPlayerInDanger = inDanger
		if inDanger then
			widgetState.lastDangerBelowGameSeconds = gameSeconds
		end
		return
	end

	if inDanger and not widgetState.lastLocalPlayerInDanger then
		local lastBelow = widgetState.lastDangerBelowGameSeconds
		local cooldownElapsed = lastBelow == nil or (gameSeconds - lastBelow) >= DANGER_POPUP_COOLDOWN_SECONDS
		if cooldownElapsed then
			if WG.notifications and WG.notifications.addEvent then
				WG.notifications.addEvent("TerritorialDomination/EliminationDanger", false)
			end
			if not widgetState.popupActive then
				local deadlineText = ""
				if hasDeadline then
					deadlineText = I18N(
						"ui.territorialDomination.deadlinePopup.eliminationBelow",
						{ threshold = formatScore(deadlineScore) }
					)
				end
				showPopup(I18N("ui.territorialDomination.deadlinePopup.eliminationDanger"), "", deadlineText)
			end
		end
	end

	widgetState.lastLocalPlayerInDanger = inDanger
	if inDanger then
		widgetState.lastDangerBelowGameSeconds = gameSeconds
	end
end

local function updateDataModel()
	local dataModel = widgetState.dmHandle
	if not dataModel then
		return
	end

	local currentDeadline = tonumber(Spring.GetGameRulesParam("territorialDominationCurrentDeadline"))
		or widgetState.currentDeadline
	local maxDeadlines = tonumber(Spring.GetGameRulesParam("territorialDominationMaxDeadlines"))
		or DEFAULT_MAX_DEADLINES
	local deadlineEndTimestamp = tonumber(Spring.GetGameRulesParam("territorialDominationDeadlineEndTimestamp")) or 0
	local deadlineScore = tonumber(Spring.GetGameRulesParam("territorialDominationDeadlineScore")) or 0
	local totalTerritories = tonumber(Spring.GetGameRulesParam("territorialDominationTotalTerritories")) or 0
	local allyTeams, allyTeamsByID = collectAllyTeamData()
	local livingLeader = findLivingLeader(allyTeams)
	local selectedAllyTeam = chooseSelectedAllyTeam(allyTeams, allyTeamsByID, livingLeader)
	local highestProjectedScore = getHighestProjectedScore(allyTeams)
	local projectedLeader = findHighestProjectedAllyTeam(allyTeams, selectedAllyTeam, highestProjectedScore)
	local hasDeadline = currentDeadline < maxDeadlines
		and deadlineEndTimestamp > 0
		and deadlineScore > 0
	local verticalScale = math.max(1, highestProjectedScore, hasDeadline and deadlineScore or 0)
	local selectedScore = selectedAllyTeam and selectedAllyTeam.score or 0
	local selectedProjectedScore = selectedAllyTeam and selectedAllyTeam.projectedScore or 0
	local isBelowDeadline = hasDeadline and selectedScore < deadlineScore
	local horizontalScale

	if isBelowDeadline then
		horizontalScale = math.max(1, deadlineScore)
	else
		horizontalScale = math.max(1, highestProjectedScore)
	end

	local selectedProjectedPercent = clampNumber(selectedProjectedScore / horizontalScale * 100, 0, 100)
	local deadlineExcessPercent = clampNumber(
		(selectedProjectedScore - deadlineScore) / math.max(1, deadlineScore) * 100,
		0,
		100
	)

	local distributionFillRml, distributionHits, ascendingAllyTeams = buildDistributionData(allyTeams)

	widgetState.allyTeams = allyTeams
	widgetState.allyTeamsByID = allyTeamsByID
	widgetState.selectedAllyTeamID = selectedAllyTeam and selectedAllyTeam.allyTeamID or -1
	widgetState.leaderAllyTeamID = livingLeader and livingLeader.allyTeamID or -1
	widgetState.projectedLeaderAllyTeamID = projectedLeader and projectedLeader.allyTeamID or -1
	widgetState.currentDeadline = currentDeadline
	widgetState.maxDeadlines = maxDeadlines
	widgetState.deadlineEndTimestamp = deadlineEndTimestamp
	widgetState.deadlineScore = deadlineScore
	widgetState.totalTerritories = totalTerritories
	widgetState.hasDeadline = hasDeadline
	widgetState.isBelowDeadline = isBelowDeadline
	widgetState.isInFirstPlace = selectedAllyTeam ~= nil and selectedAllyTeam.rank == 1
	widgetState.isInDanger = not widgetState.isInFirstPlace
		and (
			(hasDeadline and selectedProjectedScore < deadlineScore)
			or (currentDeadline >= maxDeadlines and selectedAllyTeam ~= nil)
		)
	updateHaloState()

	local verticalBars, verticalBarsOverflow, verticalContentWidth, localPlayerSlotCenterDp =
		buildVerticalBars(
			ascendingAllyTeams,
			verticalScale,
			Spring.GetLocalAllyTeamID(),
			hasDeadline,
			deadlineScore,
			currentDeadline,
			maxDeadlines
		)

	widgetState.distributionHits = distributionHits
	widgetState.verticalBarsOverflow = verticalBarsOverflow
	widgetState.verticalContentWidthDp = verticalContentWidth
	widgetState.localPlayerSlotCenterDp = localPlayerSlotCenterDp
	dataModel.distributionFillRml = distributionFillRml
	applyDistributionFill(distributionFillRml)
	dataModel.verticalBars = verticalBars
	dataModel.verticalBarsOverflow = verticalBarsOverflow
	dataModel.verticalContentWidth = string.format("%.3fdp", verticalContentWidth)
	dataModel.selectedAllyTeamID = widgetState.selectedAllyTeamID
	dataModel.selectedColor = selectedAllyTeam and selectedAllyTeam.color or makeColorString(DEFAULT_COLOR)
	dataModel.selectedDarkColor = selectedAllyTeam and selectedAllyTeam.darkColor
		or makeColorString(DEFAULT_COLOR, DARK_COLOR_MULTIPLIER)
	dataModel.selectedActualWidth = formatPercentage(selectedScore / horizontalScale * 100)
	dataModel.selectedProjectedWidth = formatPercentage(selectedProjectedPercent)
	dataModel.showDangerMark = widgetState.isInDanger and selectedAllyTeam ~= nil and selectedAllyTeam.isAlive
	dataModel.showHorizontalDangerOutline = dataModel.showDangerMark and not widgetState.isExpanded
	dataModel.dangerOverlayWidth = formatPercentage(100 - selectedProjectedPercent)
	dataModel.showDeadlineExcessBackfill = hasDeadline and isBelowDeadline and deadlineExcessPercent > 0
	dataModel.deadlineExcessBackfillWidth = formatPercentage(deadlineExcessPercent)
	dataModel.hasDeadline = hasDeadline
	dataModel.isBelowDeadline = isBelowDeadline
	dataModel.deadlineLineBottom = string.format(
		"%.3fdp",
		VERTICAL_TRACK_BOTTOM_DP + clampNumber(deadlineScore / verticalScale, 0, 1) * VERTICAL_TRACK_HEIGHT_DP
	)
	dataModel.deadlineLabel = DEADLINE_SKULL_ICON
	dataModel.deadlineLabelBottom = tostring(DEADLINE_LABEL_OFFSET_DP) .. "dp"
	dataModel.footerScore = formatScore(selectedScore)
	dataModel.footerScoreTooltip = I18N("ui.territorialDomination.tooltip.currentScore")
	dataModel.dangerMarkTooltip = I18N("ui.territorialDomination.tooltip.eliminationDanger")
	dataModel.deadlineLineTooltip = I18N("ui.territorialDomination.tooltip.deadlineScore")

	local countdownText, remainingSeconds = formatCountdown(deadlineEndTimestamp, currentDeadline, maxDeadlines)
	dataModel.footerCountdown = countdownText
	dataModel.countdownWarning = currentDeadline <= maxDeadlines
		and deadlineEndTimestamp > 0
		and remainingSeconds <= COUNTDOWN_WARNING_SECONDS

	if currentDeadline >= maxDeadlines then
		dataModel.footerCountdownTooltip = I18N("ui.territorialDomination.tooltip.timeUntilHighestScoreWins")
	elseif currentDeadline <= 1 or not hasDeadline then
		dataModel.footerCountdownTooltip = I18N("ui.territorialDomination.tooltip.timeUntilFirstDeadline")
	else
		dataModel.footerCountdownTooltip = I18N("ui.territorialDomination.tooltip.timeUntilNextDeadline")
	end

	if isBelowDeadline then
		dataModel.footerTargetIcon = DEADLINE_SKULL_ICON
		dataModel.footerTargetValue = formatScore(deadlineScore)
		dataModel.footerTargetIconColor = DEADLINE_ICON_COLOR
		dataModel.footerTargetTooltip = I18N("ui.territorialDomination.tooltip.deadlineScore")
	else
		dataModel.footerTargetIcon = TROPHY_ICON
		dataModel.footerTargetValue = formatScore(highestProjectedScore)
		dataModel.footerTargetIconColor = projectedLeader and projectedLeader.color or makeColorString(DEFAULT_COLOR)
		dataModel.footerTargetTooltip = I18N("ui.territorialDomination.tooltip.highestProjectedScore")
	end

	if widgetState.tooltipActive then
		if widgetState.tooltipSimpleSource == TOOLTIP_SOURCE_TARGET and not widgetState.isBelowDeadline then
			widgetState.tooltipActive = updateProjectedLeaderTooltipContent()
		elseif widgetState.tooltipIsSimple then
			widgetState.tooltipActive = updateSimpleTooltipContent()
		elseif widgetState.tooltipAllyTeamID and widgetState.tooltipIsScore then
			widgetState.tooltipActive = updateScoreTooltipContent(widgetState.tooltipAllyTeamID)
		end
		if widgetState.tooltipActive then
			applyTooltipPlayers(dataModel.tooltipPlayersRml)
		end
	end

	updateLeadNotification(livingLeader)
	updateDeadlinePopup(currentDeadline, maxDeadlines, deadlineScore, allyTeams, livingLeader)
	updateDangerPopup(hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
end

function WIDGET:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		return false
	end

	RmlUi.LoadFontFace(EMOJI_FONT_PATH, true)
	widgetState.dmHandle = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initializeModel(), self)
	if not widgetState.dmHandle then
		widgetState.rmlContext = nil
		return false
	end

	widgetState.document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not widgetState.document then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
		widgetState.dmHandle = nil
		widgetState.rmlContext = nil
		return false
	end

	widgetState.document:ReloadStyleSheet(true)
	widgetState.document:Show()
	widgetState.document:AddEventListener("mouseup", function()
		finishPanelDrag()
	end, false)
	loadPanelPosition()
		updateDataModel()
	synchronizeVisibility()
	return true
end

function WIDGET:Shutdown()
	finishPanelDrag()
	hidePopup()

		if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end
	if widgetState.rmlContext and widgetState.dmHandle then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
	end

	widgetState.dmHandle = nil
	widgetState.rmlContext = nil
	widgetState.appliedDistributionFillRml = nil
	widgetState.appliedTooltipPlayersRml = nil
end

local function updateCountdownPulse()
	local dataModel = widgetState.dmHandle
	if not dataModel then
		return
	end

	local countdownText, remainingSeconds = formatCountdown(
		widgetState.deadlineEndTimestamp,
		widgetState.currentDeadline,
		widgetState.maxDeadlines
	)
	dataModel.footerCountdown = countdownText
	local countdownWarning = widgetState.currentDeadline <= widgetState.maxDeadlines
		and widgetState.deadlineEndTimestamp > 0
		and remainingSeconds <= COUNTDOWN_WARNING_SECONDS
	dataModel.countdownWarning = countdownWarning

	if not countdownWarning then
		dataModel.countdownPulseColor = COUNTDOWN_IDLE_COLOR
		dataModel.countdownPulseTransform = COUNTDOWN_IDLE_TRANSFORM
		return
	end

	local pulseElapsed = 1
	if remainingSeconds > 0 then
		pulseElapsed = math.ceil(remainingSeconds) - remainingSeconds
	end
	local pulseAmount = easeCubicInOut(clampNumber(pulseElapsed, 0, 1))
	dataModel.countdownPulseColor = string.format(
		"rgba(%d, %d, %d, 255)",
		roundNumber(lerpNumber(COUNTDOWN_PULSE_START_RED, COUNTDOWN_PULSE_END_RED, pulseAmount)),
		roundNumber(lerpNumber(COUNTDOWN_PULSE_START_GREEN, COUNTDOWN_PULSE_END_GREEN, pulseAmount)),
		roundNumber(lerpNumber(COUNTDOWN_PULSE_START_BLUE, COUNTDOWN_PULSE_END_BLUE, pulseAmount))
	)
	dataModel.countdownPulseTransform = string.format(
		"scale(%.4f)",
		lerpNumber(COUNTDOWN_PULSE_START_SCALE, COUNTDOWN_PULSE_END_SCALE, pulseAmount)
	)
end

function WIDGET:Update(deltaTime)
	updatePanelDrag()
	positionTooltip()
	updateCountdownPulse()

	local currentClock = os.clock()
	local elapsedTime = tonumber(deltaTime) or math.max(0, currentClock - widgetState.lastUpdateClock)
	widgetState.lastUpdateClock = currentClock
	widgetState.updateAccumulator = widgetState.updateAccumulator + elapsedTime

	if widgetState.updateAccumulator >= DATA_UPDATE_INTERVAL then
		widgetState.updateAccumulator = widgetState.updateAccumulator % DATA_UPDATE_INTERVAL
		updateDataModel()
		if not widgetState.dragActive and (REVERT_TO_ORIGIN_POSITION or not widgetState.hasUserPosition) then
			positionPanelAtOrigin()
				end
			end

	if widgetState.popupActive and currentClock - widgetState.popupStartClock >= POPUP_DURATION_SECONDS then
		hidePopup()
	end

	applyExpandedScroll()
	synchronizeVisibility()
end

function WIDGET:RecvLuaMsg(message, playerID)
	if message:sub(1, 19) == "LobbyOverlayActive0" then
		widgetState.hiddenByLobby = false
	elseif message:sub(1, 19) == "LobbyOverlayActive1" then
		widgetState.hiddenByLobby = true
		hidePopup()
	end
	synchronizeVisibility()
end

function WIDGET:GamePaused(playerID, isPaused)
	synchronizeVisibility()
end

function WIDGET:ViewResize()
	widgetState.dragActive = false
	widgetState.isDragging = false
	widgetState.isNearOrigin = false
	if widgetState.dmHandle then
		widgetState.dmHandle.isDragging = false
	end
	loadPanelPosition()
	positionTooltip()
	updateHaloState()
end

function WIDGET:PlayerChanged(playerID)
	widgetState.updateAccumulator = DATA_UPDATE_INTERVAL
end

function WIDGET:GameOver()
	updateDataModel()
	synchronizeVisibility()
end

function WIDGET:KeyPress(key, modifiers, isRepeat)
	if key == KEY_ESCAPE and widgetState.isExpanded then
		setExpandedState(false)
		hideTooltip()
		if widgetState.hasUserPosition and not REVERT_TO_ORIGIN_POSITION then
			savePanelPosition()
		end
			return true
	end
	return false
end
