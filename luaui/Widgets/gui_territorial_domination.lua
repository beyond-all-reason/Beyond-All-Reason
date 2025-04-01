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
local format = string.format
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
local spI18N = Spring.I18N
local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glGetTextWidth = gl.GetTextWidth

local BLINK_FREQUENCY = 0.5
local WARNING_THRESHOLD = 3
local ALERT_THRESHOLD = 10
local PADDING_MULTIPLIER = 0.36
local TEXT_HEIGHT_MULTIPLIER = 0.33
local SCORE_RULES_KEY = "territorialDominationScore"
local THRESHOLD_RULES_KEY = "territorialDominationDefeatThreshold"
local FREEZE_DELAY_KEY = "territorialDominationFreezeDelay"
local GRACE_PERIOD_KEY = "territorialDominationGracePeriod"

local COLOR_WHITE = {1, 1, 1, 1}
local COLOR_RED = {1, 0, 0, 1}
local COLOR_YELLOW = {1, 0.8, 0, 1}
local COLOR_BG = {0, 0, 0, 0.6}
local BLINK_COLOR = {1, 0, 0, 0.7}
local NEEDED_TEXT_COLOR_FROZEN = {0.6, 0.6, 0.6, 1.0}

local lastWarningBlinkTime = 0
local isWarningVisible = true
local amSpectating = false
local myAllyID = -1
local selectedAllyTeamID = -1
local gaiaAllyTeamID = -1
local gracePeriod = math.huge

local fontCache = {
	initialized = false,
	fontSizeMultiplier = 1,
	fontSize = 11,
	paddingX = 0,
	paddingY = 0
}

local backgroundColor = {COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4]}

function widget:Initialize()
	amSpectating = spGetSpectatingState()
	gracePeriod = spGetGameRulesParam(GRACE_PERIOD_KEY) or 0
	myAllyID = spGetMyAllyTeamID()
	selectedAllyTeamID = myAllyID
	gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID()))
end

function widget:Update()
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
end

local function drawScore()
	local scoreAllyID = amSpectating and selectedAllyTeamID or myAllyID
	
	if scoreAllyID == gaiaAllyTeamID then return end
	
	local score = 0
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	
	for _, teamID in ipairs(spGetTeamList()) do
		local _, _, isDead, _, _, allyTeamID = spGetTeamInfo(teamID)
		if not isDead and allyTeamID == scoreAllyID then
			local teamScore = spGetTeamRulesParam(teamID, SCORE_RULES_KEY)
			if teamScore then
				score = teamScore
				break
			end
		end
	end
	
	if not fontCache.initialized then
		local _, viewportSizeY = spGetViewGeometry()
		fontCache.fontSizeMultiplier = math.max(1.2, math.min(2.25, viewportSizeY / 1080))
		fontCache.fontSize = floor(14 * fontCache.fontSizeMultiplier)
		fontCache.paddingX = floor(fontCache.fontSize * PADDING_MULTIPLIER)
		fontCache.paddingY = fontCache.paddingX
		fontCache.initialized = true
	end

	local difference = score - threshold

	local currentTime = spGetGameSeconds()
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentTime)
	local isInGracePeriod = (currentTime < gracePeriod)
	
	local shouldGreyOutText = isThresholdFrozen or isInGracePeriod

    local displayText = spI18N("ui.territorialdomination.score", { number = difference })
	
	local textWidth = glGetTextWidth(displayText) * fontCache.fontSize
	local backgroundWidth = textWidth + (fontCache.paddingX * 2)
	local backgroundHeight = fontCache.fontSize + (fontCache.paddingY * 2)

	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local displayPositionX = math.max(backgroundWidth/2, minimapPosX + minimapSizeX/2)
	local backgroundTop = minimapPosY
	local backgroundBottom = backgroundTop - backgroundHeight
	local textPositionY = backgroundBottom + (backgroundHeight * TEXT_HEIGHT_MULTIPLIER)
	local backgroundLeft = displayPositionX - backgroundWidth/2
	local backgroundRight = displayPositionX + backgroundWidth/2

	glPushMatrix()
		glColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
		glRect(backgroundLeft, backgroundBottom, backgroundRight, backgroundTop)

		if shouldGreyOutText then
			glColor(NEEDED_TEXT_COLOR_FROZEN[1], NEEDED_TEXT_COLOR_FROZEN[2], NEEDED_TEXT_COLOR_FROZEN[3], NEEDED_TEXT_COLOR_FROZEN[4])
		else
			if difference <= WARNING_THRESHOLD then
				local currentTime = spGetGameSeconds()
				if currentTime - lastWarningBlinkTime > BLINK_FREQUENCY then
					lastWarningBlinkTime = currentTime
					isWarningVisible = not isWarningVisible
				end
				glColor(COLOR_RED[1], COLOR_RED[2], COLOR_RED[3], isWarningVisible and COLOR_RED[4] or BLINK_COLOR[4])
			elseif difference <= ALERT_THRESHOLD then
				glColor(COLOR_YELLOW[1], COLOR_YELLOW[2], COLOR_YELLOW[3], COLOR_YELLOW[4])
			else
				glColor(COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], COLOR_WHITE[4])
			end
		end
		
		glText(displayText, displayPositionX, textPositionY, fontCache.fontSize, "c")
	glPopMatrix()
end

function widget:DrawScreen()
	drawScore()
end

function widget:PlayerChanged(playerID)
	if amSpectating then
		if spGetSelectedUnitsCount() > 0 then
			local unitID = spGetSelectedUnits()[1]
			local unitTeam = spGetUnitTeam(unitID)
			if unitTeam then
				selectedAllyTeamID = select(6, spGetTeamInfo(unitTeam)) or myAllyID
				return
			end
		end
		selectedAllyTeamID = myAllyID
	end
end