function widget:GetInfo()
	return {
		name      = "Territorial Domination Score",
		desc      = "Displays the score for the Territorial Domination game mode.",
		author    = "SethDGamre",
		date      = "2025",
		license   = "GNU GPL, v2",
		layer     = 0,
		enabled   = true,
	}
end

-- Cache frequently used functions
local floor = math.floor
local format = string.format
local GetViewGeometry = Spring.GetViewGeometry
local GetMiniMapGeometry = Spring.GetMiniMapGeometry
local GetGameSeconds = Spring.GetGameSeconds
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GetSpectatingState = Spring.GetSpectatingState
local GetTeamInfo = Spring.GetTeamInfo
local GetSelectedUnits = Spring.GetSelectedUnits
local GetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local GetUnitTeam = Spring.GetUnitTeam
local GetTeamRulesParam = Spring.GetTeamRulesParam
local GetGameRulesParam = Spring.GetGameRulesParam
local GetTeamList = Spring.GetTeamList
local I18N = Spring.I18N -- Direct reference to Spring's i18n system
local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glGetTextWidth = gl.GetTextWidth

-- Constants
local BLINK_FREQUENCY = 0.5  -- seconds
local WARNING_THRESHOLD = 3  -- blink red if within 3 points of defeat
local ALERT_THRESHOLD = 10  -- alert if within 10 points of defeat
local PADDING_MULTIPLIER = 0.36
local TEXT_HEIGHT_MULTIPLIER = 0.33
local SCORE_RULES_KEY = "territorialScore"
local THRESHOLD_RULES_KEY = "territorialDefeatThreshold"

-- Colors
local COLOR_WHITE = {1, 1, 1, 1}
local COLOR_RED = {1, 0, 0, 1}
local COLOR_YELLOW = {1, 0.8, 0, 1}  -- Yellow for getting close to threshold
local COLOR_BG = {0, 0, 0, 0.6}  -- Semi-transparent black background
local BLINK_COLOR = {1, 0, 0, 0.5} -- Used for blinking red text alpha

-- State Variables
local lastWarningBlinkTime = 0
local isWarningVisible = true
local amSpectating = false
local myAllyID = -1
local selectedAllyTeamID = -1 -- Track the selected team for spectators
local gaiaAllyTeamID = -1

-- Font Cache
local fontCache = {
	initialized = false,
	fontSizeMultiplier = 1,
	fontSize = 11,
	paddingX = 0,
	paddingY = 0
}

-- Local color tables reused during drawing
local backgroundColor = {COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4]}
local currentTextColor = {COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], COLOR_WHITE[4]}

function widget:Initialize()
	amSpectating = GetSpectatingState()
	myAllyID = GetMyAllyTeamID()
	selectedAllyTeamID = myAllyID -- Default to own ally team
	gaiaAllyTeamID = select(6, GetTeamInfo(Spring.GetGaiaTeamID()))
end

function widget:Update()
	amSpectating = GetSpectatingState()
	myAllyID = GetMyAllyTeamID()
	-- Spectator selection is handled in UnitSelected/PlayerChanged
end

local function drawScore()
	-- Determine which ally team's score to display
	local scoreAllyID = amSpectating and selectedAllyTeamID or myAllyID
	
	-- Skip GAIA
	if scoreAllyID == gaiaAllyTeamID then return end
	
	-- Get score from team rules
	local score = 0
	local threshold = GetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	
	-- Find a team in the selected ally team to get score from
	for _, teamID in ipairs(GetTeamList()) do
		local _, _, isDead, _, _, allyTeamID = GetTeamInfo(teamID)
		if not isDead and allyTeamID == scoreAllyID then
			local teamScore = GetTeamRulesParam(teamID, SCORE_RULES_KEY)
			if teamScore then
				score = teamScore
				break -- Found a team with score, stop searching
			end
		end
	end
	
	-- Initialize cached font values if needed
	if not fontCache.initialized then
		local _, viewportSizeY = GetViewGeometry()
		fontCache.fontSizeMultiplier = math.max(1.2, math.min(2.25, viewportSizeY / 1080))
		fontCache.fontSize = floor(14 * fontCache.fontSizeMultiplier)
		fontCache.paddingX = floor(fontCache.fontSize * PADDING_MULTIPLIER)
		fontCache.paddingY = fontCache.paddingX
		fontCache.initialized = true
	end

	-- Get current score and threshold for display logic
	local difference = score - threshold

	-- Format text using I18N directly, like in cmd_share_unit.lua
	local ownedText = I18N("ui.territorialdomination.score.owned", { score = score })
	local neededText = I18N("ui.territorialdomination.score.needed", { threshold = threshold })
	local text = ownedText .. " " .. neededText

	-- Calculate dimensions
	local textWidth = glGetTextWidth(text) * fontCache.fontSize
	local backgroundWidth = textWidth + (fontCache.paddingX * 2)
	local backgroundHeight = fontCache.fontSize + (fontCache.paddingY * 2)

	-- Calculate positions based on minimap
	local minimapPosX, minimapPosY, minimapSizeX = GetMiniMapGeometry()
	-- Ensure the display is centered above the minimap, but doesn't go off-screen left
	local displayPositionX = math.max(backgroundWidth/2, minimapPosX + minimapSizeX/2)
	local backgroundTop = minimapPosY -- Position above the minimap
	local backgroundBottom = backgroundTop - backgroundHeight
	local textPositionY = backgroundBottom + (backgroundHeight * TEXT_HEIGHT_MULTIPLIER) -- Position text vertically centered within padding
	local backgroundLeft = displayPositionX - backgroundWidth/2
	local backgroundRight = displayPositionX + backgroundWidth/2

	-- Update text color based on score difference (reusing table)
	if difference <= WARNING_THRESHOLD then
		local currentTime = GetGameSeconds()
		if currentTime - lastWarningBlinkTime > BLINK_FREQUENCY then
			lastWarningBlinkTime = currentTime
			isWarningVisible = not isWarningVisible
		end
		-- Set color to red, adjust alpha for blinking effect
		currentTextColor[1], currentTextColor[2], currentTextColor[3], currentTextColor[4] = COLOR_RED[1], COLOR_RED[2], COLOR_RED[3], isWarningVisible and COLOR_RED[4] or BLINK_COLOR[4]
	elseif difference <= ALERT_THRESHOLD then
		-- Set color to yellow
		currentTextColor[1], currentTextColor[2], currentTextColor[3], currentTextColor[4] = COLOR_YELLOW[1], COLOR_YELLOW[2], COLOR_YELLOW[3], COLOR_YELLOW[4]
	else
		-- Set color to white
		currentTextColor[1], currentTextColor[2], currentTextColor[3], currentTextColor[4] = COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], COLOR_WHITE[4]
	end

	-- Draw background and text
	glPushMatrix()
		-- Draw background rectangle
		glColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
		glRect(backgroundLeft, backgroundBottom, backgroundRight, backgroundTop)

		-- Draw score text
		glColor(currentTextColor[1], currentTextColor[2], currentTextColor[3], currentTextColor[4])
		glText(text, displayPositionX, textPositionY, fontCache.fontSize, "co") -- Center horizontally, offset vertically
	glPopMatrix()
end

function widget:DrawScreen()
	drawScore()
end

-- Update selected ally for spectators when player selection changes
function widget:PlayerChanged(playerID)
	if amSpectating then
		-- Check if any units are selected, prefer unit selection over player selection for team context
		if GetSelectedUnitsCount() > 0 then
			local unitID = GetSelectedUnits()[1]
			local unitTeam = GetUnitTeam(unitID)
			if unitTeam then
				selectedAllyTeamID = select(6, GetTeamInfo(unitTeam)) or myAllyID
				return -- Prioritize selected unit's team
			end
		end
		selectedAllyTeamID = myAllyID
	end
end

-- Update selected ally for spectators when unit selection changes
function widget:UnitSelected(unitID, unitDefID, unitTeam, selected)
	if amSpectating and selected and unitTeam then
		selectedAllyTeamID = select(6, GetTeamInfo(unitTeam)) or myAllyID
	end
end

function widget:UnitDeselected(unitID, unitDefID, unitTeam)
	-- When units are deselected while spectating, reset to own team ID
	-- or potentially keep the last selected team? Resetting seems safer.
	if amSpectating and GetSelectedUnitsCount() == 0 then
		selectedAllyTeamID = myAllyID
	end
end 