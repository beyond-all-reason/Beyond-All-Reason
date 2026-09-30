if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
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

local DATA_MODEL_NAME = "territorial_score_model"
local RML_PATH = "luaui/RmlWidgets/gui_territorial_domination/gui_territorial_domination.rml"
local EMOJI_FONT_PATH = "fonts/fallbacks/NotoEmoji-VariableFont_wght.ttf"
local I18N = BAR.I18N

local PANEL = {
	POSITION_X_KEY = "td_posX",
	POSITION_Y_KEY = "td_posY",
	DOCKED_KEY = "td_docked",
	DOCKED_VALUE = 1,
	UNDOCKED_VALUE = 0,
	WIDTH_DP = 240,
	COLLAPSED_HEIGHT_DP = 98,
	EXPANDED_HEIGHT_DP = 204,
	BORDER_DP = 2,
	MARGIN_DP = 10,
	ORIGIN_SNAP_DISTANCE_DP = 36,
}
local POSITION_SCALE = 10000
local FLOW_UI_PANEL_API_NAMES = {
	"advplayerlist_api",
	"music",
	"unittotals",
	"displayinfo",
	"playertv",
	"advplayerlist_mascot",
}

local DISTRIBUTION = {
	LEFT_DP = 7,
	WIDTH_DP = 222,
	HEIGHT_DP = 10,
	BORDER_DP = 1,
}
DISTRIBUTION.HEIGHT = tostring(DISTRIBUTION.HEIGHT_DP) .. "dp"
local MINIMUM_SEGMENT_HIT_FRACTION = 0.03

local VERTICAL = {
	SLOT_WIDTH_DP = 26,
	CONTENT_MINIMUM_WIDTH_DP = 222,
	CONTENT_PADDING_DP = 6,
	TRACK_HEIGHT_DP = 124,
	TRACK_BOTTOM_DP = 12,
}

local TOOLTIP = {
	OFFSET_X = 16,
	OFFSET_Y = 22,
	FONT_SIZE_DP = 17,
	CHAR_WIDTH_DP = 8,
	PADDING_X_DP = 20,
	MIN_WIDTH_DP = 80,
	TEAM_EXTRA_DP = 24,
	ROW_HEIGHT_DP = 22,
	VERTICAL_PADDING_DP = 16,
	SOURCE_CURRENT_SCORE = "currentScore",
	SOURCE_COUNTDOWN = "countdown",
	SOURCE_DANGER = "danger",
	SOURCE_DEADLINE = "deadline",
	HEADER_EXPAND = "expand",
	HEADER_SELECT = "select",
	MODE_SCORE = "score",
	MODE_SIMPLE = "simple",
	MODE_TARGET = "target",
}

local COLOR_BYTE_MAXIMUM = 255
local DARK_COLOR_MULTIPLIER = 0.48
local SEGMENT_OUTLINE_COLOR_MULTIPLIER = 0.7
local DEFAULT_COLOR = {
	red = 0.5,
	green = 0.5,
	blue = 0.5,
}
local DEADLINE_ICON_COLOR = "rgba(255, 48, 48, 255)"

local DATA_UPDATE_INTERVAL = 1.0
local POPUP_DURATION_SECONDS = 5
local POPUP_INITIAL_WINDOW_SECONDS = 10
local DANGER_POPUP_COOLDOWN_SECONDS = 60
local SECONDS_PER_MINUTE = 60
local COUNTDOWN = {
	WARNING_SECONDS = 60,
	PULSE_START_RED = 255,
	PULSE_START_GREEN = 117,
	PULSE_START_BLUE = 117,
	PULSE_END_RED = 214,
	PULSE_END_GREEN = 47,
	PULSE_END_BLUE = 47,
	PULSE_START_SCALE = 1.04,
	PULSE_END_SCALE = 1,
	IDLE_COLOR = "rgba(255, 255, 255, 255)",
	IDLE_TRANSFORM = "scale(1)",
}

local TERRITORY_POINTS_PER_DEADLINE = 10
local DEADLINE_SKULL_ICON = "💀"
local DEADLINE_LABEL_OFFSET_DP = 10
local TROPHY_ICON = "🏆"
local KEY_ESCAPE = 27
local DEADLINES_BY_CONFIG = {
	["18_minutes"] = 3,
	["24_minutes"] = 4,
	["30_minutes"] = 5,
	["42_minutes"] = 7,
	["60_minutes"] = 10,
}
local DEFAULT_MAX_DEADLINES = DEADLINES_BY_CONFIG[MOD_OPTIONS.territorial_domination_config] or 5
local DEADLINE_SCORE_MULTIPLIER = tonumber(MOD_OPTIONS.territorial_domination_elimination_threshold_multiplier) or 1.25
local DEADLINE_SCORE_PERCENT_LABEL = string.format("%d", math.round(DEADLINE_SCORE_MULTIPLIER * 100, 0))

local widgetState = {
	allyTeamsByID = {},
	distributionHitRanges = {},
	currentDeadline = 0.0,
	maxDeadlines = DEFAULT_MAX_DEADLINES + 0.0,
	deadlineEndTimestamp = 0.0,
	deadlineScore = 0.0,
	totalTerritories = 0.0,
	hasDeadline = false,
	isBelowDeadline = false,
	isExpanded = false,
	hiddenByLobby = false,
	shouldShow = false,
	updateAccumulator = DATA_UPDATE_INTERVAL,
	isDragging = false,
	isNearDockOrigin = false,
	isInDanger = false,
	isInFirstPlace = false,
	dragOffsetX = 0.0,
	dragOffsetY = 0.0,
	panelPixelX = 0.0,
	panelPixelY = 0.0,
	isUndocked = false,
	tooltipActive = false,
	tooltipRowCount = 1,
	tooltipWidthDp = TOOLTIP.MIN_WIDTH_DP,
	popupActive = false,
	popupStartClock = 0.0,
	hasObservedDeadline = false,
	lastObservedDeadline = 0,
	allyTeamColorByID = {},
	allyTeamRosterByID = {},
	rosterDirty = true,
	territoryPointsPerDeadline = TERRITORY_POINTS_PER_DEADLINE + 0.0,
	pendingVerticalScroll = false,
	verticalBarsOverflow = false,
	verticalContentWidthDp = VERTICAL.CONTENT_MINIMUM_WIDTH_DP + 0.0,
	dockedOriginPixelX = 0.0,
	dockedOriginPixelY = 0.0,
}

local function easeCubicInOut(amount)
	if amount < 0.5 then
		return 4 * amount * amount * amount
	end
	local inverted = -2 * amount + 2
	return 1 - (inverted * inverted * inverted) / 2
end

local function formatScore(value)
	return tostring(math.round(tonumber(value) or 0, 0))
end

local function getTooltipTextWidthDp(value)
	local text = tostring(value or "")
	if not widgetState.tooltipFont and WG and WG.fonts and WG.fonts.getFont then
		widgetState.tooltipFont = WG.fonts.getFont(2)
	end
	local font = widgetState.tooltipFont
	if font and font.GetTextWidth then
		return font:GetTextWidth(text) * TOOLTIP.FONT_SIZE_DP
	end
	local characterCount = #text
	return characterCount * TOOLTIP.CHAR_WIDTH_DP
end

local function applyTooltipSize(dataModel, lineWidths)
	local widestLineDp = 0
	for lineIndex = 1, #lineWidths do
		if lineWidths[lineIndex] > widestLineDp then
			widestLineDp = lineWidths[lineIndex]
		end
	end
	local tooltipWidthDp = math.max(TOOLTIP.MIN_WIDTH_DP, math.ceil(widestLineDp + TOOLTIP.PADDING_X_DP))
	widgetState.tooltipWidthDp = tooltipWidthDp
	widgetState.tooltipRowCount = math.max(1, #lineWidths)
	dataModel.tooltipWidth = tostring(tooltipWidthDp) .. "dp"
end

local function formatPercentage(value)
	return string.format("%.3f%%", math.clamp(value, 0, 100))
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

local function getCountdownTooltip(currentDeadline, maxDeadlines)
	local safeMaxDeadlines = math.max(1, math.floor(tonumber(maxDeadlines) or DEFAULT_MAX_DEADLINES))
	return I18N("ui.territorialDomination.tooltip.countdownUntilDeadlineEnds", {
		currentDeadline = math.max(1, math.min(math.floor(tonumber(currentDeadline) or 1), safeMaxDeadlines)),
		maxDeadlines = safeMaxDeadlines,
	})
end

local function getAllyTeamColor(allyTeamID, teamID)
	local cachedColor = widgetState.allyTeamColorByID[allyTeamID]
	if cachedColor then
		return cachedColor
	end

	local color = {
		red = DEFAULT_COLOR.red,
		green = DEFAULT_COLOR.green,
		blue = DEFAULT_COLOR.blue,
	}

	if teamID then
		local red, green, blue = Spring.GetTeamColor(teamID)
		color.red = red or color.red
		color.green = green or color.green
		color.blue = blue or color.blue
	end

	widgetState.allyTeamColorByID[allyTeamID] = color
	return color
end

local function makeColorString(color, multiplier)
	local colorMultiplier = multiplier or 1
	local red = math.round(math.clamp(color.red * colorMultiplier, 0, 1) * COLOR_BYTE_MAXIMUM, 0)
	local green = math.round(math.clamp(color.green * colorMultiplier, 0, 1) * COLOR_BYTE_MAXIMUM, 0)
	local blue = math.round(math.clamp(color.blue * colorMultiplier, 0, 1) * COLOR_BYTE_MAXIMUM, 0)
	return string.format("rgba(%d, %d, %d, 255)", red, green, blue)
end

local function getPlayerTeamColor(teamID, isSpectating, localTeamID, anonymousColor)
	local red, green, blue = Spring.GetTeamColor(teamID)
	local anonymousMode = MOD_OPTIONS.teamcolors_anonymous_mode

	if not isSpectating and anonymousMode ~= "disabled" and teamID ~= localTeamID then
		red = anonymousColor.red
		green = anonymousColor.green
		blue = anonymousColor.blue
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
	local isSpectating = Spring.GetSpectatingState()
	local localTeamID = Spring.GetLocalTeamID()
	if not widgetState.anonymousColor then
		widgetState.anonymousColor = {
			red = Spring.GetConfigInt("anonymousColorR", COLOR_BYTE_MAXIMUM) / COLOR_BYTE_MAXIMUM,
			green = Spring.GetConfigInt("anonymousColorG", 0) / COLOR_BYTE_MAXIMUM,
			blue = Spring.GetConfigInt("anonymousColorB", 0) / COLOR_BYTE_MAXIMUM,
		}
	end

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
						color = getPlayerTeamColor(teamID, isSpectating, localTeamID, widgetState.anonymousColor),
					}
				end
			end
		end

		if #players == initialPlayerCount then
			local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)
			if isAI then
				players[#players + 1] = {
					name = getAIName(teamID),
					color = getPlayerTeamColor(teamID, isSpectating, localTeamID, widgetState.anonymousColor),
				}
			end
		end
	end

	if #players == 0 then
		players[1] = {
			name = I18N("ui.territorialDomination.team.ally", { allyNumber = allyTeamID + 1 }),
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
	local playerMarkupParts = {}
	if players then
		for playerIndex = 1, #players do
			local player = players[playerIndex]
			playerMarkupParts[#playerMarkupParts + 1] = string.format(
				'<div class="td-tooltip-player" style="color: %s;">%s</div>',
				player.color or fallbackColor,
				escapeRmlText(player.name)
			)
		end
	end
	return table.concat(playerMarkupParts)
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

local function getAllyTeamRoster(allyTeamID)
	local cachedRoster = widgetState.allyTeamRosterByID[allyTeamID]
	if cachedRoster and not widgetState.rosterDirty then
		return cachedRoster
	end

	local teamList = Spring.GetTeamList(allyTeamID) or {}
	if #teamList == 0 then
		return nil
	end

	local firstLivingTeamID = getFirstLivingTeamID(teamList)
	local color = getAllyTeamColor(allyTeamID, firstLivingTeamID or teamList[1])
	local roster = {
		teamList = teamList,
		players = getAllyTeamPlayers(allyTeamID, teamList, makeColorString(color)),
		color = makeColorString(color),
		darkColor = makeColorString(color, DARK_COLOR_MULTIPLIER),
		outlineColor = makeColorString(color, SEGMENT_OUTLINE_COLOR_MULTIPLIER),
	}
	widgetState.allyTeamRosterByID[allyTeamID] = roster
	return roster
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
			local roster = getAllyTeamRoster(allyTeamID)
			if roster then
				local allyTeamRulesPrefix = "territorialDomination_ally_" .. allyTeamID .. "_"
				local score = tonumber(Spring.GetGameRulesParam(allyTeamRulesPrefix .. "score")) or 0
				local projectedScore = tonumber(Spring.GetGameRulesParam(allyTeamRulesPrefix .. "projectedScore"))
					or score
				local firstLivingTeamID = getFirstLivingTeamID(roster.teamList)
				local allyTeamData = {
					allyTeamID = allyTeamID,
					players = roster.players,
					score = score,
					projectedScore = math.max(score, projectedScore),
					territoryCount = tonumber(Spring.GetGameRulesParam(allyTeamRulesPrefix .. "territoryCount")) or 0,
					rank = tonumber(Spring.GetGameRulesParam(allyTeamRulesPrefix .. "rank")) or 1,
					isAlive = firstLivingTeamID ~= nil,
					firstLivingTeamID = firstLivingTeamID,
					color = roster.color,
					darkColor = roster.darkColor,
					outlineColor = roster.outlineColor,
				}
				allyTeams[#allyTeams + 1] = allyTeamData
				allyTeamsByID[allyTeamID] = allyTeamData
			end
		end
	end

	widgetState.rosterDirty = false
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

local function findProjectedLeader(allyTeams, selectedAllyTeam)
	local highestProjectedScore = 0
	for allyTeamIndex = 1, #allyTeams do
		highestProjectedScore = math.max(highestProjectedScore, allyTeams[allyTeamIndex].projectedScore)
	end

	if selectedAllyTeam and selectedAllyTeam.isAlive and selectedAllyTeam.projectedScore == highestProjectedScore then
		return selectedAllyTeam, highestProjectedScore
	end

	local projectedLeader = selectedAllyTeam
	for allyTeamIndex = 1, #allyTeams do
		local allyTeam = allyTeams[allyTeamIndex]
		if allyTeam.projectedScore == highestProjectedScore then
			if allyTeam.isAlive then
				return allyTeam, highestProjectedScore
			end
			projectedLeader = projectedLeader or allyTeam
		end
	end

	return projectedLeader or allyTeams[1], highestProjectedScore
end

local function buildDistributionData(allyTeams)
	local ascendingAllyTeams = {}
	local totalScore = 0.0

	for allyTeamIndex = 1, #allyTeams do
		local allyTeam = allyTeams[allyTeamIndex]
		ascendingAllyTeams[allyTeamIndex] = allyTeam
		totalScore = totalScore + math.max(0, allyTeam.score)
	end

	table.sort(ascendingAllyTeams, compareAscendingScores)

	local totalHitWeight = 0.0
	for allyTeamIndex = 1, #ascendingAllyTeams do
		local score = math.max(0, ascendingAllyTeams[allyTeamIndex].score)
		local hitWeight = totalScore > 0 and math.max(score / totalScore, MINIMUM_SEGMENT_HIT_FRACTION) or 1
		totalHitWeight = totalHitWeight + hitWeight
	end

	local distributionHitRanges = {}
	local segmentMarkupParts = {}
	local leftPercentage = 0.0
	local leftHitFraction = 0.0

	for allyTeamIndex = 1, #ascendingAllyTeams do
		local allyTeam = ascendingAllyTeams[allyTeamIndex]
		local startPercentage = leftPercentage
		local scoreShare = math.max(0, allyTeam.score)
		local width = totalScore > 0 and scoreShare / totalScore * 100
			or (#ascendingAllyTeams > 0 and 100 / #ascendingAllyTeams or 0)
		local flexGrow = totalScore > 0 and scoreShare or 1
		if allyTeamIndex == #ascendingAllyTeams then
			width = math.max(0, 100 - startPercentage)
		end
		segmentMarkupParts[#segmentMarkupParts + 1] = string.format(
			'<div class="td-distribution-segment" style="flex: %.6f; width: %.3f%%; height: %s; background-color: %s; box-shadow: inset 0px 0px 0px 1px %s;"></div>',
			flexGrow,
			width,
			DISTRIBUTION.HEIGHT,
			allyTeam.color,
			allyTeam.outlineColor
		)
		local hitWeight = totalScore > 0 and math.max(scoreShare / totalScore, MINIMUM_SEGMENT_HIT_FRACTION) or 1
		local endHitFraction = allyTeamIndex == #ascendingAllyTeams and 1
			or leftHitFraction + hitWeight / math.max(totalHitWeight, 1)
		distributionHitRanges[#distributionHitRanges + 1] = {
			allyTeamID = allyTeam.allyTeamID,
			startFraction = leftHitFraction,
			endFraction = endHitFraction,
		}
		leftPercentage = startPercentage + width
		leftHitFraction = endHitFraction
	end

	return table.concat(segmentMarkupParts), distributionHitRanges, ascendingAllyTeams
end

local function isAllyTeamInEliminationDanger(allyTeam, hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
	if not allyTeam or not allyTeam.isAlive or allyTeam.rank == 1 then
		return false
	end
	return (hasDeadline and allyTeam.projectedScore < deadlineScore) or currentDeadline >= maxDeadlines
end

local function buildVerticalBars(
	ascendingAllyTeams,
	verticalScale,
	localAllyTeamID,
	hasDeadline,
	deadlineScore,
	currentDeadline,
	maxDeadlines
)
	local verticalBars = {}
	local allyTeamCount = #ascendingAllyTeams
	local packedWidth = allyTeamCount * VERTICAL.SLOT_WIDTH_DP + VERTICAL.CONTENT_PADDING_DP
	local overflowing = packedWidth > VERTICAL.CONTENT_MINIMUM_WIDTH_DP
	local contentWidth = overflowing and packedWidth or VERTICAL.CONTENT_MINIMUM_WIDTH_DP
	local extraSpace = contentWidth - packedWidth
	local gap = allyTeamCount > 0 and extraSpace / (allyTeamCount + 1) or 0
	local sidePadding = VERTICAL.CONTENT_PADDING_DP / 2
	local localPlayerSlotCenterDp = nil
	local isSpectating = Spring.GetSpectatingState()
	local deadlinePercent = math.clamp(deadlineScore / math.max(1, verticalScale) * 100, 0, 100)

	for allyTeamIndex = 1, allyTeamCount do
		local allyTeam = ascendingAllyTeams[allyTeamIndex]
		local slotLeft = sidePadding + gap * allyTeamIndex + VERTICAL.SLOT_WIDTH_DP * (allyTeamIndex - 1)
		if allyTeam.allyTeamID == localAllyTeamID then
			localPlayerSlotCenterDp = slotLeft + VERTICAL.SLOT_WIDTH_DP / 2
		end
		local projectedPercent = math.clamp(allyTeam.projectedScore / math.max(1, verticalScale) * 100, 0, 100)
		local overlayTopPercent = hasDeadline and deadlinePercent or 100
		local overlayHeightPercent = math.max(0, overlayTopPercent - projectedPercent)
		local showDangerOverlay = isAllyTeamInEliminationDanger(
			allyTeam,
			hasDeadline,
			deadlineScore,
			currentDeadline,
			maxDeadlines
		) and overlayHeightPercent > 0
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
	return 1.0
end

local function getPanelPixelSize()
	local dpRatio = getDpRatio()
	local panelHeight = widgetState.isExpanded and PANEL.EXPANDED_HEIGHT_DP or PANEL.COLLAPSED_HEIGHT_DP
	return PANEL.WIDTH_DP * dpRatio, panelHeight * dpRatio
end

local function setPanelPosition(panelPixelX, panelPixelY)
	local roundedPixelX = math.round(panelPixelX, 0)
	local roundedPixelY = math.round(panelPixelY, 0)
	if widgetState.panelPixelX == roundedPixelX and widgetState.panelPixelY == roundedPixelY then
		return
	end
	widgetState.panelPixelX = roundedPixelX
	widgetState.panelPixelY = roundedPixelY

	if widgetState.dataModel then
		widgetState.dataModel.panelLeft = tostring(widgetState.panelPixelX) .. "px"
		widgetState.dataModel.panelTop = tostring(widgetState.panelPixelY) .. "px"
	end
end

local function updateHaloState()
	if not widgetState.dataModel then
		return
	end

	local showOriginHalo = widgetState.isDragging and widgetState.isNearDockOrigin
	local showFirstPlaceHalo = not widgetState.isDragging and widgetState.isInFirstPlace
	local showDangerHalo = not widgetState.isDragging and not showFirstPlaceHalo and widgetState.isInDanger
	widgetState.dataModel.showOriginHalo = showOriginHalo
	widgetState.dataModel.showFirstPlaceHalo = showFirstPlaceHalo
	widgetState.dataModel.showDangerHalo = showDangerHalo
	widgetState.dataModel.showDockGhost = widgetState.isDragging
end

local function setDragging(isDragging)
	widgetState.isDragging = isDragging
	if not isDragging then
		widgetState.isNearDockOrigin = false
	end
	if widgetState.dataModel then
		widgetState.dataModel.isDragging = isDragging
	end
end

local function clampPanelPosition(panelPixelX, panelPixelY)
	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local panelWidth, panelHeight = getPanelPixelSize()
	local maximumX = math.max(0, viewSizeX - panelWidth)
	local maximumY = math.max(0, viewSizeY - panelHeight)
	setPanelPosition(math.clamp(panelPixelX, 0, maximumX), math.clamp(panelPixelY, 0, maximumY))
end

local function isStoredPanelDocked()
	local storedDockState = tonumber(Spring.GetConfigString(PANEL.DOCKED_KEY, ""))
	if storedDockState == PANEL.DOCKED_VALUE or storedDockState == PANEL.UNDOCKED_VALUE then
		return storedDockState == PANEL.DOCKED_VALUE
	end

	local storedPositionX = tonumber(Spring.GetConfigString(PANEL.POSITION_X_KEY, ""))
	local storedPositionY = tonumber(Spring.GetConfigString(PANEL.POSITION_Y_KEY, ""))
	return not storedPositionX or not storedPositionY or storedPositionX < 0 or storedPositionY < 0
end

local function savePanelPosition()
	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	if viewSizeX <= 0 or viewSizeY <= 0 then
		return
	end

	Spring.SetConfigInt(PANEL.DOCKED_KEY, PANEL.UNDOCKED_VALUE)
	Spring.SetConfigInt(PANEL.POSITION_X_KEY, math.floor(widgetState.panelPixelX / viewSizeX * POSITION_SCALE + 0.5))
	Spring.SetConfigInt(PANEL.POSITION_Y_KEY, math.floor(widgetState.panelPixelY / viewSizeY * POSITION_SCALE + 0.5))
	widgetState.isUndocked = true
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
	return panelPosition[1]
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
	if widgetState.dockedOriginPixelX and widgetState.dockedOriginPixelY then
		return widgetState.dockedOriginPixelX, widgetState.dockedOriginPixelY
	end

	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local panelWidth, panelHeight = getPanelPixelSize()
	local margin = PANEL.MARGIN_DP * getDpRatio()
	local flowUIAnchorTop = getFlowUIAnchorTop()
	local maximumX = math.max(0, viewSizeX - panelWidth)
	local maximumY = math.max(0, viewSizeY - panelHeight)
	local panelPixelX = math.clamp(viewSizeX - panelWidth, 0, maximumX)
	local panelPixelY = math.clamp(viewSizeY - flowUIAnchorTop - panelHeight - margin, 0, maximumY)
	widgetState.dockedOriginPixelX = panelPixelX
	widgetState.dockedOriginPixelY = panelPixelY
	return panelPixelX, panelPixelY
end

local function invalidatePanelOrigin()
	widgetState.dockedOriginPixelX = nil
	widgetState.dockedOriginPixelY = nil
end

local function updateDockGhostPosition()
	if not widgetState.dataModel then
		return
	end

	local dockGhostPixelX, dockGhostPixelY = getPanelOriginPosition()
	widgetState.dataModel.dockGhostLeft = tostring(math.round(dockGhostPixelX, 0)) .. "px"
	widgetState.dataModel.dockGhostTop = tostring(math.round(dockGhostPixelY, 0)) .. "px"
end

local function positionPanelAtOrigin()
	local panelPixelX, panelPixelY = getPanelOriginPosition()
	setPanelPosition(panelPixelX, panelPixelY)
	widgetState.isUndocked = false
end

local function loadPanelPosition()
	invalidatePanelOrigin()
	if isStoredPanelDocked() then
		positionPanelAtOrigin()
		return
	end

	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local storedPositionX = Spring.GetConfigInt(PANEL.POSITION_X_KEY, -1)
	local storedPositionY = Spring.GetConfigInt(PANEL.POSITION_Y_KEY, -1)
	if storedPositionX < 0 or storedPositionY < 0 then
		positionPanelAtOrigin()
		return
	end

	widgetState.isUndocked = true
	clampPanelPosition(storedPositionX / POSITION_SCALE * viewSizeX, storedPositionY / POSITION_SCALE * viewSizeY)
end

local function finishPanelDrag()
	if not widgetState.isDragging then
		return
	end
	local shouldSnapToOrigin = widgetState.isNearDockOrigin
	setDragging(false)
	if shouldSnapToOrigin then
		positionPanelAtOrigin()
		Spring.SetConfigInt(PANEL.DOCKED_KEY, PANEL.DOCKED_VALUE)
		widgetState.isUndocked = false
	else
		savePanelPosition()
	end
	updateHaloState()
end

local function updatePanelDrag()
	if not widgetState.isDragging then
		return
	end

	local mouseX, mouseY, _, _, _, isOffscreen = Spring.GetMouseState()
	if isOffscreen then
		return
	end

	local _, viewSizeY = Spring.GetViewGeometry()
	local draggedPanelPixelX = mouseX - widgetState.dragOffsetX
	local draggedPanelPixelY = viewSizeY - mouseY - widgetState.dragOffsetY
	local previousPanelPixelX = widgetState.panelPixelX
	local previousPanelPixelY = widgetState.panelPixelY
	local originPanelPixelX, originPanelPixelY = getPanelOriginPosition()
	local originDeltaX = draggedPanelPixelX - originPanelPixelX
	local originDeltaY = draggedPanelPixelY - originPanelPixelY
	local snapDistance = PANEL.ORIGIN_SNAP_DISTANCE_DP * getDpRatio()
	widgetState.isNearDockOrigin = originDeltaX * originDeltaX + originDeltaY * originDeltaY
		<= snapDistance * snapDistance

	if widgetState.isNearDockOrigin then
		setPanelPosition(originPanelPixelX, originPanelPixelY)
	else
		clampPanelPosition(draggedPanelPixelX, draggedPanelPixelY)
	end
	if
		widgetState.isExpanded
		and (widgetState.panelPixelX ~= previousPanelPixelX or widgetState.panelPixelY ~= previousPanelPixelY)
	then
		widgetState.collapsedPanelPixelY = nil
	end
	updateDockGhostPosition()
	updateHaloState()
end

local function setTooltipActive(isActive)
	widgetState.tooltipActive = isActive
	if not isActive then
		widgetState.lastTooltipPixelX = nil
		widgetState.lastTooltipPixelY = nil
	end
	if widgetState.dataModel then
		local isVisible = isActive and widgetState.shouldShow
		if widgetState.dataModel.tooltipVisible ~= isVisible then
			widgetState.dataModel.tooltipVisible = isVisible
		end
	end
end

local function positionTooltip()
	if not widgetState.tooltipActive or not widgetState.dataModel then
		return
	end

	local mouseX, mouseY, _, _, _, isOffscreen = Spring.GetMouseState()
	if isOffscreen then
		setTooltipActive(false)
		return
	end

	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local dpRatio = getDpRatio()
	if not widgetState.tooltipElement and widgetState.document then
		widgetState.tooltipElement = widgetState.document:GetElementById("td-tooltip")
	end
	local tooltipWidth = widgetState.tooltipWidthDp * dpRatio
	local tooltipHeight = widgetState.tooltipElement and widgetState.tooltipElement.offset_height or 0.0
	if tooltipHeight < 1 then
		tooltipHeight = (TOOLTIP.VERTICAL_PADDING_DP + widgetState.tooltipRowCount * TOOLTIP.ROW_HEIGHT_DP) * dpRatio
	end
	local tooltipX = math.clamp(mouseX + TOOLTIP.OFFSET_X, 0, math.max(0, viewSizeX - tooltipWidth))
	local tooltipY = math.clamp(viewSizeY - mouseY + TOOLTIP.OFFSET_Y, 0, math.max(0, viewSizeY - tooltipHeight))
	local roundedTooltipX = math.round(tooltipX, 0)
	local roundedTooltipY = math.round(tooltipY, 0)
	if widgetState.lastTooltipPixelX == roundedTooltipX and widgetState.lastTooltipPixelY == roundedTooltipY then
		return
	end

	widgetState.lastTooltipPixelX = roundedTooltipX
	widgetState.lastTooltipPixelY = roundedTooltipY
	widgetState.dataModel.tooltipLeft = string.format("%.3fvw", tooltipX / math.max(1, viewSizeX) * 100)
	widgetState.dataModel.tooltipTop = string.format("%.3fvh", tooltipY / math.max(1, viewSizeY) * 100)
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
	return allyTeam.territoryCount * widgetState.currentDeadline * widgetState.territoryPointsPerDeadline
end

local function updateScoreTooltipContent(allyTeamID)
	local dataModel = widgetState.dataModel
	local allyTeam = widgetState.allyTeamsByID[allyTeamID]
	if not dataModel or not allyTeam then
		return false
	end

	local leader = widgetState.allyTeamsByID[widgetState.leaderAllyTeamID] or allyTeam
	local pointsBelowDeadline = math.max(0.0, widgetState.deadlineScore - allyTeam.score)
	local pointsBelowLeader = math.max(0.0, leader.score - allyTeam.score)
	local showDeadline = widgetState.hasDeadline and pointsBelowDeadline > 0
	local showLeader = pointsBelowLeader > 0

	dataModel.tooltipIsSimple = false
	dataModel.tooltipIsScore = true
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
	if widgetState.tooltipHeaderSource == TOOLTIP.HEADER_EXPAND then
		dataModel.tooltipHeader = I18N("ui.territorialDomination.tooltip.clickToExpand")
	elseif widgetState.tooltipHeaderSource == TOOLTIP.HEADER_SELECT then
		dataModel.tooltipHeader = I18N("ui.territorialDomination.tooltip.clickToSelect")
	else
		dataModel.tooltipHeader = ""
	end
	local lineWidths = {
		getTooltipTextWidthDp(dataModel.tooltipTeamLabel) + TOOLTIP.TEAM_EXTRA_DP,
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
			+ TOOLTIP.TEAM_EXTRA_DP
	end
	applyTooltipSize(dataModel, lineWidths)
	return true
end

local function updateSimpleTooltipContent()
	local dataModel = widgetState.dataModel
	if not dataModel then
		return false
	end

	local tooltipText
	local tooltipSecondaryText = ""
	if widgetState.tooltipSource == TOOLTIP.SOURCE_CURRENT_SCORE then
		tooltipText = dataModel.footerScoreTooltip
	elseif widgetState.tooltipSource == TOOLTIP.SOURCE_COUNTDOWN then
		tooltipText = dataModel.footerCountdownTooltip
	elseif widgetState.tooltipSource == TOOLTIP.SOURCE_DANGER then
		tooltipText = dataModel.dangerMarkTooltip
	elseif widgetState.tooltipSource == TOOLTIP.SOURCE_DEADLINE then
		tooltipText = dataModel.deadlineLineTooltip
		tooltipSecondaryText = dataModel.deadlineLineSecondaryTooltip
	else
		return false
	end
	dataModel.tooltipIsSimple = true
	dataModel.tooltipIsScore = false
	dataModel.tooltipText = tooltipText
	dataModel.tooltipSecondaryText = tooltipSecondaryText
	dataModel.tooltipTitle = ""
	dataModel.tooltipHeader = ""
	dataModel.tooltipShowTeam = false
	dataModel.tooltipShowLeader = false
	local lineWidths = { getTooltipTextWidthDp(tooltipText) }
	if tooltipSecondaryText ~= "" then
		lineWidths[#lineWidths + 1] = getTooltipTextWidthDp(tooltipSecondaryText)
	end
	applyTooltipSize(dataModel, lineWidths)
	return true
end

local function appendPlayerLineWidths(lineWidths, players)
	if not players then
		return
	end
	for playerIndex = 1, #players do
		lineWidths[#lineWidths + 1] = getTooltipTextWidthDp(players[playerIndex].name)
	end
end

local function updateProjectedLeaderTooltipContent()
	local dataModel = widgetState.dataModel
	local projectedLeader = widgetState.allyTeamsByID[widgetState.projectedLeaderAllyTeamID]
	if not dataModel or not projectedLeader then
		return false
	end

	local selectedAllyTeam = widgetState.allyTeamsByID[widgetState.selectedAllyTeamID]
	local isSelectedProjectedLeader = selectedAllyTeam ~= nil
		and selectedAllyTeam.allyTeamID == projectedLeader.allyTeamID

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
		getTooltipTextWidthDp(dataModel.tooltipTeamLabel) + TOOLTIP.TEAM_EXTRA_DP,
	}
	appendPlayerLineWidths(lineWidths, projectedLeader.players)
	applyTooltipSize(dataModel, lineWidths)
	return true
end

local function showScoreTooltip(event, allyTeamID, tooltipHeaderSource)
	local numericAllyTeamID = tonumber(allyTeamID)
	local contentChanged = widgetState.tooltipMode ~= TOOLTIP.MODE_SCORE
		or widgetState.tooltipAllyTeamID ~= numericAllyTeamID
		or widgetState.tooltipHeaderSource ~= tooltipHeaderSource
	widgetState.tooltipMode = TOOLTIP.MODE_SCORE
	widgetState.tooltipAllyTeamID = numericAllyTeamID
	widgetState.tooltipSource = nil
	widgetState.tooltipHeaderSource = tooltipHeaderSource
	if contentChanged then
		setTooltipActive(updateScoreTooltipContent(numericAllyTeamID))
	else
		setTooltipActive(widgetState.allyTeamsByID[numericAllyTeamID] ~= nil)
	end
	positionTooltip()
end

local function showSimpleTooltip(event, tooltipSource)
	local contentChanged = widgetState.tooltipMode ~= TOOLTIP.MODE_SIMPLE or widgetState.tooltipSource ~= tooltipSource
	widgetState.tooltipMode = TOOLTIP.MODE_SIMPLE
	widgetState.tooltipAllyTeamID = nil
	widgetState.tooltipSource = tooltipSource
	widgetState.tooltipHeaderSource = nil
	if contentChanged then
		setTooltipActive(updateSimpleTooltipContent())
	else
		setTooltipActive(true)
	end
	positionTooltip()
end

local function stopEventPropagation(event)
	if event and event.StopPropagation then
		event:StopPropagation()
	end
end

local function showDangerMarkTooltip(event)
	showSimpleTooltip(event, TOOLTIP.SOURCE_DANGER)
	stopEventPropagation(event)
end

local function showTargetTooltip(event)
	widgetState.tooltipMode = TOOLTIP.MODE_TARGET
	widgetState.tooltipAllyTeamID = widgetState.projectedLeaderAllyTeamID
	widgetState.tooltipSource = widgetState.isBelowDeadline and TOOLTIP.SOURCE_DEADLINE or nil
	widgetState.tooltipHeaderSource = nil
	setTooltipActive(
		widgetState.isBelowDeadline and updateSimpleTooltipContent() or updateProjectedLeaderTooltipContent()
	)
	positionTooltip()
end

local function hideTooltip(event)
	setTooltipActive(false)
	widgetState.tooltipMode = nil
	widgetState.tooltipAllyTeamID = nil
	widgetState.tooltipSource = nil
	widgetState.tooltipHeaderSource = nil
end

local function hideDangerMarkTooltip(event)
	if widgetState.selectedAllyTeamID ~= nil then
		showScoreTooltip(event, widgetState.selectedAllyTeamID)
	else
		hideTooltip()
	end
end

local function getDistributionAllyTeamIDAtMouse()
	local distributionHitRanges = widgetState.distributionHitRanges
	if #distributionHitRanges == 0 then
		return nil
	end

	local mouseX = Spring.GetMouseState()
	local dpRatio = getDpRatio()
	local innerLeft = widgetState.panelPixelX
		+ (PANEL.BORDER_DP + DISTRIBUTION.LEFT_DP + DISTRIBUTION.BORDER_DP) * dpRatio
	local innerWidth = math.max(1.0, (DISTRIBUTION.WIDTH_DP - DISTRIBUTION.BORDER_DP * 2) * dpRatio)
	local fraction = math.clamp((mouseX - innerLeft) / innerWidth, 0, 0.999999)

	for rangeIndex = 1, #distributionHitRanges do
		local hitRange = distributionHitRanges[rangeIndex]
		if fraction >= hitRange.startFraction and fraction < hitRange.endFraction then
			return hitRange.allyTeamID
		end
	end

	return distributionHitRanges[#distributionHitRanges].allyTeamID
end

local function showDistributionTooltip(event)
	local allyTeamID = getDistributionAllyTeamIDAtMouse()
	if allyTeamID == nil then
		hideTooltip()
		return
	end
	if
		widgetState.tooltipMode == TOOLTIP.MODE_SCORE
		and widgetState.tooltipAllyTeamID == allyTeamID
		and widgetState.tooltipHeaderSource == TOOLTIP.HEADER_EXPAND
	then
		positionTooltip()
		return
	end
	showScoreTooltip(event, allyTeamID, TOOLTIP.HEADER_EXPAND)
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
	setDragging(true)
	widgetState.isNearDockOrigin = false
	widgetState.dragOffsetX = mouseX - widgetState.panelPixelX
	widgetState.dragOffsetY = viewSizeY - mouseY - widgetState.panelPixelY
	hideTooltip()
	updateDockGhostPosition()
	updateHaloState()
	stopEventPropagation(event)
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

	return math.clamp(slotCenterDp / contentWidthDp * scrollWidth - clientWidth / 2, 0, maximumScroll)
end

local function applyExpandedScroll()
	if not widgetState.pendingVerticalScroll or not widgetState.isExpanded or not widgetState.document then
		return
	end

	if not widgetState.verticalScrollElement then
		widgetState.verticalScrollElement = widgetState.document:GetElementById("td-vertical-scroll")
	end
	local scrollElement = widgetState.verticalScrollElement
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

	scrollElement.scroll_left = math.floor(getExpandedScrollTarget(clientWidth, scrollWidth) + 0.5)
	widgetState.pendingVerticalScroll = false
end

local function setExpandedState(isExpanded)
	if widgetState.isExpanded == isExpanded then
		return
	end

	local wasExpanded = widgetState.isExpanded
	local expandedHeightDifference = (PANEL.EXPANDED_HEIGHT_DP - PANEL.COLLAPSED_HEIGHT_DP) * getDpRatio()
	widgetState.isExpanded = isExpanded
	widgetState.pendingVerticalScroll = isExpanded
	if widgetState.dataModel then
		widgetState.dataModel.isExpanded = widgetState.isExpanded
		widgetState.dataModel.showHorizontalDangerOutline = widgetState.dataModel.showDangerMark
			and not widgetState.isExpanded
	end
	invalidatePanelOrigin()
	if not widgetState.isUndocked then
		widgetState.collapsedPanelPixelY = nil
		positionPanelAtOrigin()
	else
		if isExpanded and not wasExpanded then
			widgetState.collapsedPanelPixelY = widgetState.panelPixelY
		end
		local adjustedPanelPixelY = isExpanded and widgetState.panelPixelY - expandedHeightDifference
			or widgetState.collapsedPanelPixelY
			or widgetState.panelPixelY + expandedHeightDifference
		if not isExpanded then
			widgetState.collapsedPanelPixelY = nil
		end
		clampPanelPosition(widgetState.panelPixelX, adjustedPanelPixelY)
	end
	applyExpandedScroll()
end

local function finishExpandedStateChange(event)
	hideTooltip()
	if widgetState.isUndocked then
		savePanelPosition()
	end
	stopEventPropagation(event)
end

local function toggleExpanded(event)
	setExpandedState(not widgetState.isExpanded)
	finishExpandedStateChange(event)
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
	stopEventPropagation(event)
end

---@class TerritorialDominationModel
---@field isVisible boolean
---@field isExpanded boolean
---@field isDragging boolean
---@field showOriginHalo boolean
---@field showDockGhost boolean
---@field showFirstPlaceHalo boolean
---@field showDangerHalo boolean
---@field panelLeft string
---@field panelTop string
---@field dockGhostLeft string
---@field dockGhostTop string
---@field distributionFillRml string
---@field distributionHeight string
---@field selectedAllyTeamID integer
---@field selectedProjectedWidth string
---@field selectedDarkColor string
---@field selectedActualWidth string
---@field selectedColor string
---@field showDangerMark boolean
---@field showHorizontalDangerOutline boolean
---@field dangerOverlayWidth string
---@field showDeadlineExcessBackfill boolean
---@field deadlineExcessBackfillWidth string
---@field hasDeadline boolean
---@field isBelowDeadline boolean
---@field deadlineLineBottom string
---@field deadlineLabel string
---@field deadlineLabelBottom string
---@field verticalContentWidth string
---@field verticalBarsOverflow boolean
---@field verticalBars table
---@field footerScore string
---@field countdownWarning boolean
---@field countdownPulseColor string
---@field countdownPulseTransform string
---@field footerCountdown string
---@field footerTargetIcon string
---@field footerTargetValue string
---@field footerTargetIconColor string
---@field tooltipVisible boolean
---@field tooltipLeft string
---@field tooltipTop string
---@field tooltipWidth string
---@field tooltipIsScore boolean
---@field tooltipIsSimple boolean
---@field tooltipText string
---@field tooltipSecondaryText string
---@field tooltipTitle string
---@field tooltipHeader string
---@field tooltipPlayersRml string
---@field tooltipTerritories string
---@field tooltipGainRate string
---@field tooltipCurrentScore string
---@field tooltipProjectedScore string
---@field tooltipShowDeadline boolean
---@field tooltipDeadlineDifference string
---@field tooltipShowLeader boolean
---@field tooltipShowTeam boolean
---@field tooltipTeamLabel string
---@field tooltipTeamColor string
---@field tooltipLeaderDifference string
---@field tooltipLeaderColor string
---@field footerScoreTooltip string
---@field footerCountdownTooltip string
---@field dangerMarkTooltip string
---@field deadlineLineTooltip string
---@field deadlineLineSecondaryTooltip string
---@field popupVisible boolean
---@field popupTitle string
---@field popupRateText string
---@field popupDeadlineText string
---@field beginPanelDrag fun(event: any)
---@field blockPanelDrag fun(event: any)
---@field toggleExpanded fun(event: any)
---@field selectExpandedScore fun(event: any, allyTeamID: any)
---@field hideTooltip fun(event: any)
---@field showScoreTooltip fun(event: any, allyTeamID: any, tooltipHeaderSource: any)
---@field showSimpleTooltip fun(event: any, tooltipSource: any)
---@field showDistributionTooltip fun(event: any)
---@field showTargetTooltip fun(event: any)
---@field showDangerMarkTooltip fun(event: any)
---@field hideDangerMarkTooltip fun(event: any)
---@return TerritorialDominationModel
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
		distributionHeight = DISTRIBUTION.HEIGHT,
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
		deadlineLineBottom = tostring(VERTICAL.TRACK_BOTTOM_DP) .. "dp",
		deadlineLabel = DEADLINE_SKULL_ICON,
		deadlineLabelBottom = tostring(DEADLINE_LABEL_OFFSET_DP) .. "dp",
		verticalContentWidth = tostring(VERTICAL.CONTENT_MINIMUM_WIDTH_DP) .. "dp",
		verticalBarsOverflow = false,
		verticalBars = {},
		footerScore = "0",
		countdownWarning = false,
		countdownPulseColor = COUNTDOWN.IDLE_COLOR,
		countdownPulseTransform = COUNTDOWN.IDLE_TRANSFORM,
		footerCountdown = "0:00",
		footerTargetIcon = TROPHY_ICON,
		footerTargetValue = "0",
		footerTargetIconColor = makeColorString(DEFAULT_COLOR),
		tooltipVisible = false,
		tooltipLeft = "0px",
		tooltipTop = "0px",
		tooltipWidth = tostring(TOOLTIP.MIN_WIDTH_DP) .. "dp",
		tooltipIsScore = true,
		tooltipIsSimple = false,
		tooltipText = "",
		tooltipSecondaryText = "",
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
		footerCountdownTooltip = getCountdownTooltip(1, DEFAULT_MAX_DEADLINES),
		dangerMarkTooltip = I18N("ui.territorialDomination.tooltip.eliminationDanger"),
		deadlineLineTooltip = I18N("ui.territorialDomination.tooltip.deadlineScore"),
		deadlineLineSecondaryTooltip = I18N("ui.territorialDomination.tooltip.deadlineScoreRule", {
			percentage = DEADLINE_SCORE_PERCENT_LABEL,
		}),
		popupVisible = false,
		popupTitle = "",
		popupRateText = "",
		popupDeadlineText = "",
		beginPanelDrag = beginPanelDrag,
		blockPanelDrag = stopEventPropagation,
		toggleExpanded = toggleExpanded,
		selectExpandedScore = selectExpandedScore,
		hideTooltip = hideTooltip,
		showScoreTooltip = showScoreTooltip,
		showSimpleTooltip = showSimpleTooltip,
		showDistributionTooltip = showDistributionTooltip,
		showTargetTooltip = showTargetTooltip,
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
	local dataModel = widgetState.dataModel
	if not dataModel then
		return
	end

	local shouldShow = getShouldShow()
	local popupVisible = widgetState.popupActive and shouldShow
	local tooltipVisible = widgetState.tooltipActive and shouldShow
	widgetState.shouldShow = shouldShow
	if dataModel.isVisible ~= shouldShow then
		dataModel.isVisible = shouldShow
	end
	if dataModel.popupVisible ~= popupVisible then
		dataModel.popupVisible = popupVisible
	end

	if not shouldShow then
		hideTooltip()
		tooltipVisible = false
	end
	if dataModel.tooltipVisible ~= tooltipVisible then
		dataModel.tooltipVisible = tooltipVisible
	end
end

local function hidePopup()
	widgetState.popupActive = false
	if widgetState.dataModel and widgetState.dataModel.popupVisible then
		widgetState.dataModel.popupVisible = false
	end
end

local function getFinalPopupTitle(allyTeams, livingLeader)
	local livingLeaderCount = 0
	for allyTeamIndex = 1, #allyTeams do
		local allyTeam = allyTeams[allyTeamIndex]
		if livingLeader and allyTeam.isAlive and allyTeam.rank == livingLeader.rank then
			livingLeaderCount = livingLeaderCount + 1
		end
	end
	if livingLeaderCount > 1 then
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
	local dataModel = widgetState.dataModel
	if not dataModel then
		return
	end

	dataModel.popupTitle = title
	dataModel.popupRateText = rateText or ""
	dataModel.popupDeadlineText = deadlineText or ""
	widgetState.popupActive = true
	widgetState.popupStartClock = os.clock()
	local shouldShow = getShouldShow()
	dataModel.popupVisible = shouldShow

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
		rateText = I18N(
			"ui.territorialDomination.deadlinePopup.territoryRate",
			{ points = formatScore(currentDeadline * widgetState.territoryPointsPerDeadline) }
		)
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
		widgetState.wasLocalAllyTeamLeading = nil
		return
	end

	local isInLead = localAllyTeam.isAlive
		and livingLeader ~= nil
		and livingLeader.allyTeamID == localAllyTeam.allyTeamID

	if widgetState.wasLocalAllyTeamLeading == nil then
		widgetState.wasLocalAllyTeamLeading = isInLead
		return
	end

	if isInLead ~= widgetState.wasLocalAllyTeamLeading then
		if WG.notifications and WG.notifications.addEvent then
			if isInLead then
				WG.notifications.addEvent("TerritorialDomination/GainedLead", false)
			else
				WG.notifications.addEvent("TerritorialDomination/LostLead", false)
			end
		end
		widgetState.wasLocalAllyTeamLeading = isInLead
	end
end

local function updateDangerPopup(hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
	local localAllyTeam = widgetState.allyTeamsByID[Spring.GetLocalAllyTeamID()]
	if Spring.GetSpectatingState() or not localAllyTeam then
		widgetState.wasLocalAllyTeamInDanger = nil
		return
	end

	local inDanger =
		isAllyTeamInEliminationDanger(localAllyTeam, hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
	local gameSeconds = Spring.GetGameSeconds()

	if widgetState.wasLocalAllyTeamInDanger == nil then
		widgetState.wasLocalAllyTeamInDanger = inDanger
		if inDanger then
			widgetState.lastDangerGameSeconds = gameSeconds
		end
		return
	end

	if inDanger and not widgetState.wasLocalAllyTeamInDanger then
		local lastDangerGameSeconds = widgetState.lastDangerGameSeconds
		local cooldownElapsed = lastDangerGameSeconds == nil
			or (gameSeconds - lastDangerGameSeconds) >= DANGER_POPUP_COOLDOWN_SECONDS
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

	widgetState.wasLocalAllyTeamInDanger = inDanger
	if inDanger then
		widgetState.lastDangerGameSeconds = gameSeconds
	end
end

local function readDominationRules()
	return {
		currentDeadline = tonumber(Spring.GetGameRulesParam("territorialDominationCurrentDeadline"))
			or widgetState.currentDeadline,
		maxDeadlines = tonumber(Spring.GetGameRulesParam("territorialDominationMaxDeadlines")) or DEFAULT_MAX_DEADLINES,
		deadlineEndTimestamp = tonumber(Spring.GetGameRulesParam("territorialDominationDeadlineEndTimestamp")) or 0,
		deadlineScore = tonumber(Spring.GetGameRulesParam("territorialDominationDeadlineScore")) or 0,
		totalTerritories = tonumber(Spring.GetGameRulesParam("territorialDominationTotalTerritories")) or 0,
		territoryPointsPerDeadline = tonumber(
			Spring.GetGameRulesParam("territorialDominationTerritoryPointsPerDeadline")
		) or TERRITORY_POINTS_PER_DEADLINE,
	}
end

local function refreshActiveTooltip()
	if not widgetState.tooltipActive then
		return
	end

	local isActive = false
	if widgetState.tooltipMode == TOOLTIP.MODE_TARGET then
		widgetState.tooltipSource = widgetState.isBelowDeadline and TOOLTIP.SOURCE_DEADLINE or nil
		isActive = widgetState.isBelowDeadline and updateSimpleTooltipContent() or updateProjectedLeaderTooltipContent()
	elseif widgetState.tooltipMode == TOOLTIP.MODE_SIMPLE then
		isActive = updateSimpleTooltipContent()
	elseif widgetState.tooltipMode == TOOLTIP.MODE_SCORE and widgetState.tooltipAllyTeamID then
		isActive = updateScoreTooltipContent(widgetState.tooltipAllyTeamID)
	end
	setTooltipActive(isActive)
end

local function updateDataModel()
	local dataModel = widgetState.dataModel
	if not dataModel then
		return
	end

	local rules = readDominationRules()
	local allyTeams, allyTeamsByID = collectAllyTeamData()
	local livingLeader = findLivingLeader(allyTeams)
	local selectedAllyTeam = chooseSelectedAllyTeam(allyTeams, allyTeamsByID, livingLeader)
	local selectedAllyTeamID = selectedAllyTeam and selectedAllyTeam.allyTeamID

	local currentDeadline = rules.currentDeadline
	local maxDeadlines = rules.maxDeadlines
	local deadlineEndTimestamp = rules.deadlineEndTimestamp
	local deadlineScore = rules.deadlineScore
	local projectedLeader, highestProjectedScore = findProjectedLeader(allyTeams, selectedAllyTeam)
	local hasDeadline = currentDeadline < maxDeadlines and deadlineEndTimestamp > 0 and deadlineScore > 0
	local verticalScale = math.max(1.0, highestProjectedScore, hasDeadline and deadlineScore or 0.0)
	local selectedScore = selectedAllyTeam and selectedAllyTeam.score or 0.0
	local selectedProjectedScore = selectedAllyTeam and selectedAllyTeam.projectedScore or 0.0
	local isBelowDeadline = hasDeadline and selectedScore < deadlineScore
	local horizontalScale = math.max(1.0, isBelowDeadline and deadlineScore or highestProjectedScore)
	local selectedProjectedPercent = math.clamp(selectedProjectedScore / horizontalScale * 100, 0, 100)
	local deadlineExcessPercent =
		math.clamp((selectedProjectedScore - deadlineScore) / math.max(1, deadlineScore) * 100, 0, 100)
	local distributionFillRml, distributionHitRanges, ascendingAllyTeams = buildDistributionData(allyTeams)
	local verticalBars, verticalBarsOverflow, verticalContentWidth, localPlayerSlotCenterDp = buildVerticalBars(
		ascendingAllyTeams,
		verticalScale,
		Spring.GetLocalAllyTeamID(),
		hasDeadline,
		deadlineScore,
		currentDeadline,
		maxDeadlines
	)

	widgetState.allyTeamsByID = allyTeamsByID
	widgetState.distributionHitRanges = distributionHitRanges
	widgetState.selectedAllyTeamID = selectedAllyTeamID
	widgetState.leaderAllyTeamID = livingLeader and livingLeader.allyTeamID
	widgetState.projectedLeaderAllyTeamID = projectedLeader and projectedLeader.allyTeamID
	widgetState.currentDeadline = currentDeadline
	widgetState.maxDeadlines = maxDeadlines
	widgetState.deadlineEndTimestamp = deadlineEndTimestamp
	widgetState.deadlineScore = deadlineScore
	widgetState.totalTerritories = rules.totalTerritories
	widgetState.territoryPointsPerDeadline = rules.territoryPointsPerDeadline
	widgetState.hasDeadline = hasDeadline
	widgetState.isBelowDeadline = isBelowDeadline
	widgetState.isInFirstPlace = selectedAllyTeam ~= nil and selectedAllyTeam.rank == 1
	widgetState.isInDanger =
		isAllyTeamInEliminationDanger(selectedAllyTeam, hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
	widgetState.verticalBarsOverflow = verticalBarsOverflow
	widgetState.verticalContentWidthDp = verticalContentWidth
	widgetState.localPlayerSlotCenterDp = localPlayerSlotCenterDp
	updateHaloState()

	dataModel.distributionFillRml = distributionFillRml
	dataModel.verticalBars = verticalBars
	dataModel.verticalBarsOverflow = verticalBarsOverflow
	dataModel.verticalContentWidth = string.format("%.3fdp", verticalContentWidth)
	dataModel.selectedAllyTeamID = selectedAllyTeamID or -1
	dataModel.selectedColor = selectedAllyTeam and selectedAllyTeam.color or makeColorString(DEFAULT_COLOR)
	dataModel.selectedDarkColor = selectedAllyTeam and selectedAllyTeam.darkColor
		or makeColorString(DEFAULT_COLOR, DARK_COLOR_MULTIPLIER)
	dataModel.selectedActualWidth = formatPercentage(selectedScore / horizontalScale * 100)
	dataModel.selectedProjectedWidth = formatPercentage(selectedProjectedPercent)
	dataModel.showDangerMark = widgetState.isInDanger
	dataModel.showHorizontalDangerOutline = dataModel.showDangerMark and not widgetState.isExpanded
	dataModel.dangerOverlayWidth = formatPercentage(100 - selectedProjectedPercent)
	dataModel.showDeadlineExcessBackfill = hasDeadline and isBelowDeadline and deadlineExcessPercent > 0
	dataModel.deadlineExcessBackfillWidth = formatPercentage(deadlineExcessPercent)
	dataModel.hasDeadline = hasDeadline
	dataModel.isBelowDeadline = isBelowDeadline
	dataModel.deadlineLineBottom = string.format(
		"%.3fdp",
		VERTICAL.TRACK_BOTTOM_DP + math.clamp(deadlineScore / verticalScale, 0, 1) * VERTICAL.TRACK_HEIGHT_DP
	)
	dataModel.footerScore = formatScore(selectedScore)

	dataModel.footerCountdownTooltip = getCountdownTooltip(currentDeadline, maxDeadlines)

	if isBelowDeadline then
		dataModel.footerTargetIcon = DEADLINE_SKULL_ICON
		dataModel.footerTargetValue = formatScore(deadlineScore)
		dataModel.footerTargetIconColor = DEADLINE_ICON_COLOR
	else
		dataModel.footerTargetIcon = TROPHY_ICON
		dataModel.footerTargetValue = formatScore(highestProjectedScore)
		dataModel.footerTargetIconColor = projectedLeader and projectedLeader.color or makeColorString(DEFAULT_COLOR)
	end

	refreshActiveTooltip()
	updateLeadNotification(livingLeader)
	updateDeadlinePopup(currentDeadline, maxDeadlines, deadlineScore, allyTeams, livingLeader)
	updateDangerPopup(hasDeadline, deadlineScore, currentDeadline, maxDeadlines)
end

local function updateCountdownPulse()
	local dataModel = widgetState.dataModel
	if not dataModel then
		return
	end

	local remainingSeconds = math.max(0, widgetState.deadlineEndTimestamp - Spring.GetGameSeconds())
	if
		widgetState.currentDeadline <= widgetState.maxDeadlines
		and widgetState.deadlineEndTimestamp > 0
		and remainingSeconds <= 0
		and widgetState.lastExpiredDeadlineTimestamp ~= widgetState.deadlineEndTimestamp
	then
		widgetState.lastExpiredDeadlineTimestamp = widgetState.deadlineEndTimestamp
		widgetState.updateAccumulator = DATA_UPDATE_INTERVAL
	end
	local displayedSecond = widgetState.currentDeadline > widgetState.maxDeadlines and -1 or math.ceil(remainingSeconds)
	if widgetState.lastCountdownSecond ~= displayedSecond then
		widgetState.lastCountdownSecond = displayedSecond
		local countdownText =
			formatCountdown(widgetState.deadlineEndTimestamp, widgetState.currentDeadline, widgetState.maxDeadlines)
		if dataModel.footerCountdown ~= countdownText then
			dataModel.footerCountdown = countdownText
		end
	end

	local countdownWarning = widgetState.currentDeadline <= widgetState.maxDeadlines
		and widgetState.deadlineEndTimestamp > 0
		and remainingSeconds <= COUNTDOWN.WARNING_SECONDS
	if dataModel.countdownWarning ~= countdownWarning then
		dataModel.countdownWarning = countdownWarning
	end
	if not countdownWarning then
		if dataModel.countdownPulseColor ~= COUNTDOWN.IDLE_COLOR then
			dataModel.countdownPulseColor = COUNTDOWN.IDLE_COLOR
		end
		if dataModel.countdownPulseTransform ~= COUNTDOWN.IDLE_TRANSFORM then
			dataModel.countdownPulseTransform = COUNTDOWN.IDLE_TRANSFORM
		end
		return
	end

	local pulseElapsed = remainingSeconds > 0 and math.ceil(remainingSeconds) - remainingSeconds or 1
	local pulseAmount = easeCubicInOut(math.clamp(pulseElapsed, 0, 1))
	local pulseColor = string.format(
		"rgba(%d, %d, %d, 255)",
		math.round(math.mix(COUNTDOWN.PULSE_START_RED, COUNTDOWN.PULSE_END_RED, pulseAmount), 0),
		math.round(math.mix(COUNTDOWN.PULSE_START_GREEN, COUNTDOWN.PULSE_END_GREEN, pulseAmount), 0),
		math.round(math.mix(COUNTDOWN.PULSE_START_BLUE, COUNTDOWN.PULSE_END_BLUE, pulseAmount), 0)
	)
	local pulseTransform =
		string.format("scale(%.4f)", math.mix(COUNTDOWN.PULSE_START_SCALE, COUNTDOWN.PULSE_END_SCALE, pulseAmount))
	if dataModel.countdownPulseColor ~= pulseColor then
		dataModel.countdownPulseColor = pulseColor
	end
	if dataModel.countdownPulseTransform ~= pulseTransform then
		dataModel.countdownPulseTransform = pulseTransform
	end
end

function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		return false
	end

	RmlUi.LoadFontFace(EMOJI_FONT_PATH, true)
	widgetState.dataModel = widgetState.rmlContext:OpenDataModel(DATA_MODEL_NAME, initializeModel(), self) ---@as TerritorialDominationModel?
	if not widgetState.dataModel then
		widgetState.rmlContext = nil
		return false
	end

	widgetState.document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not widgetState.document then
		widgetState.rmlContext:RemoveDataModel(DATA_MODEL_NAME)
		widgetState.dataModel = nil
		widgetState.rmlContext = nil
		return false
	end

	widgetState.document:ReloadStyleSheet()
	widgetState.document:Show()
	widgetState.document:AddEventListener("mouseup", function()
		finishPanelDrag()
	end, false)
	loadPanelPosition()
	updateDataModel()
	updateCountdownPulse()
	synchronizeVisibility()
	return true
end

function widget:Shutdown()
	finishPanelDrag()
	hidePopup()

	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end
	if widgetState.rmlContext and widgetState.dataModel then
		widgetState.rmlContext:RemoveDataModel(DATA_MODEL_NAME)
	end

	widgetState.dataModel = nil
	widgetState.rmlContext = nil
	widgetState.tooltipElement = nil
	widgetState.verticalScrollElement = nil
end

function widget:Update(deltaTime)
	updatePanelDrag()
	positionTooltip()
	updateCountdownPulse()

	local currentClock = os.clock()
	widgetState.updateAccumulator = widgetState.updateAccumulator + (tonumber(deltaTime) or 0)

	if widgetState.updateAccumulator >= DATA_UPDATE_INTERVAL then
		widgetState.updateAccumulator = widgetState.updateAccumulator % DATA_UPDATE_INTERVAL
		updateDataModel()
		if not widgetState.isDragging and not widgetState.isUndocked then
			invalidatePanelOrigin()
			positionPanelAtOrigin()
		end
		updateCountdownPulse()
	end

	if widgetState.popupActive and currentClock - widgetState.popupStartClock >= POPUP_DURATION_SECONDS then
		hidePopup()
	end

	applyExpandedScroll()
	synchronizeVisibility()
end

function widget:RecvLuaMsg(message, playerID)
	if type(message) ~= "string" then
		return
	end
	if message:sub(1, 19) == "LobbyOverlayActive0" then
		widgetState.hiddenByLobby = false
	elseif message:sub(1, 19) == "LobbyOverlayActive1" then
		widgetState.hiddenByLobby = true
		hidePopup()
	end
	synchronizeVisibility()
end

function widget:GamePaused(playerID, isPaused)
	synchronizeVisibility()
end

function widget:ViewResize()
	setDragging(false)
	widgetState.collapsedPanelPixelY = nil
	loadPanelPosition()
	positionTooltip()
	updateHaloState()
end

function widget:PlayerChanged(playerID)
	widgetState.rosterDirty = true
	widgetState.allyTeamColorByID = {}
	widgetState.anonymousColor = nil
	widgetState.updateAccumulator = DATA_UPDATE_INTERVAL
end

function widget:TeamDied(teamID)
	widgetState.rosterDirty = true
	widgetState.allyTeamColorByID = {}
	widgetState.updateAccumulator = DATA_UPDATE_INTERVAL
end

function widget:GameOver()
	updateDataModel()
	synchronizeVisibility()
end

function widget:KeyPress(key, modifiers, isRepeat)
	if key == KEY_ESCAPE and widgetState.isExpanded then
		setExpandedState(false)
		finishExpandedStateChange()
		return true
	end
	return false
end
