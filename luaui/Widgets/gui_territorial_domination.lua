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

--the skull is grey for a weird period of time before the end of frozen threshold period
-- it is possible for the text to clip outside of the healthbar
-- the bar can exceed the max crazy far, it needs to be bounded to some degree to prevent absurd overvalues

local modOptions = Spring.GetModOptions()
if modOptions.deathmode ~= "territorial_domination" then return false end

local floor = math.floor
local ceil = math.ceil
local format = string.format
local len = string.len
local abs = math.abs
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
local glScale = gl.Scale
local max = math.max
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitDefID = Spring.GetUnitDefID
local spGetMyTeamID = Spring.GetMyTeamID
local spGetAllUnits = Spring.GetAllUnits

local BLINK_FREQUENCY = 0.5
local WARNING_THRESHOLD = 3
local ALERT_THRESHOLD = 10
local WARNING_SECONDS = 15
local PADDING_MULTIPLIER = 0.36
local TEXT_HEIGHT_MULTIPLIER = 0.33
local SCORE_RULES_KEY = "territorialDominationScore"
local THRESHOLD_RULES_KEY = "territorialDominationDefeatThreshold"
local FREEZE_DELAY_KEY = "territorialDominationFreezeDelay"
local MAX_THRESHOLD_RULES_KEY = "territorialDominationMaxThreshold"
local UPDATE_FREQUENCY = 0.1
local BLINK_VOLUME_WARNING_RESET_SECONDS = 10
local MIN_BLINK_VOLUME = 0.15
local MAX_BLINK_VOLUME = 0.4
local TEXT_OUTLINE_OFFSET = 0.7
local TEXT_OUTLINE_ALPHA = 0.35
local BLINK_FRAMES = 10
local BLINK_INTERVAL = 1
local DEFEAT_CHECK_INTERVAL = Game.gameSpeed
local WINDUP_SOUND_DURATION = 2
local ACTIVATE_SOUND_DURATION = 0
local AFTER_GADGET_TIMER_UPDATE_MODULO = 3
local CHARGE_SOUND_LOOP_DURATION = 4.75

local COLOR_WHITE = {1, 1, 1, 1}
local COLOR_RED = {1, 0, 0, 1}
local COLOR_YELLOW = {1, 0.8, 0, 1}
local COLOR_BACKGROUND = {0, 0, 0, 0.5}
local COLOR_BORDER = {0.2, 0.2, 0.2, 0.2}
local COLOR_GREEN = {0, 0.8, 0, 0.8}
local COLOR_TEXT_OUTLINE = {0, 0, 0, TEXT_OUTLINE_ALPHA}
local RED_BLINK_COLOR = {0.9, 0, 0, 1}
local FROZEN_TEXT_COLOR = {0.6, 0.6, 0.6, 1.0}
local COLOR_ICE_BLUE = {0.5, 0.8, 1.0, 0.8}
local COLOR_GREY_LINE = {0.7, 0.7, 0.7, 0.7}
local COLOR_WHITE_LINE = {1, 1, 1, 0.8}

-- Add constants for timer warning
local TIMER_WARNING_DISPLAY_TIME = 5  -- Display warning for 5 seconds
local TIMER_COOLDOWN = 120 -- in seconds
local TIMER_WARNING_FONT_MULTIPLIER = 1.5
local MINIMAP_GAP = 3

local myCommanders = {}
local soundQueue = {}

local lastWarningBlinkTime = 0
local isWarningVisible = true
local isFreezeWarningVisible = true
local isSkullFaded = true

-- Add variables for timer warning
local lastTimerWarningTime = -TIMER_COOLDOWN -- Initialize to allow first warning to show
local timerWarningMessage = nil
local timerWarningEndTime = 0
local font = nil

local amSpectating = false
local myAllyID = -1
local selectedAllyTeamID = -1
local gaiaAllyTeamID = -1
local lastUpdateTime = 0
local lastScore = -1
local displayList = nil
local lastDifference = -1
local lastTextColor = nil
local lastBackgroundDimensions = nil
local warningSoundFadeMultiplier = 0.5
local healthbarWidth = 300
local healthbarHeight = 20
local lineWidth = 2
local maxThreshold = 256
local currentTime = os.clock()

local defeatTime = 0
local gameSeconds = 0
local lastLoop = 0
local loopSoundEndTime = 0
local soundIndex = 1

-- Countdown timer constants
local COUNTDOWN_WARNING_SECONDS = 15
local COUNTDOWN_FONT_SIZE_MULTIPLIER = 1.7  -- Back to previous size

local timerWarningDisplayList = nil
local countdownDisplayList = nil
local lastCountdownValue = -1
local lastTimerWarningMessages = nil

-- Helper functions to reduce upvalues in main functions
local function drawHealthBar(left, right, bottom, top, score, threshold, barColor, isThresholdFrozen)
	-- POSITION CALCULATIONS
	local fullHealthbarLeft = left
	local fullHealthbarRight = right
	local barWidth = right - left
	
	local originalRight = right
	local exceedsMaxThreshold = score > maxThreshold
	
	-- Calculate the actual score position without exceeding the bar width
	local healthbarScoreRight = left + math.min(score / maxThreshold, 1) * barWidth
	
	-- If score exceeds max, we won't extend the bar beyond its normal width
	if exceedsMaxThreshold then
		right = originalRight
	end
	
	local thresholdX = left + (threshold / maxThreshold) * barWidth
	
	local iconSize = 25
	

	local skullOffset = (1 / maxThreshold) * barWidth
	local skullX = thresholdX - skullOffset
	
	local borderSize = 3
	local fillPaddingLeft = fullHealthbarLeft + borderSize
	local fillPaddingRight = healthbarScoreRight - borderSize
	local fillPaddingTop = top
	local fillPaddingBottom = bottom + borderSize
	
	-- Calculate line position
	local linePos = healthbarScoreRight
	if exceedsMaxThreshold then
		-- Calculate how much the bar exceeds the max threshold
		local overfillRatio = (score - maxThreshold) / maxThreshold
		-- Cap at 1.0 (100% backfilled)
		overfillRatio = math.min(overfillRatio, 1)
		
		-- Calculate where the line should be when backfilling
		local maxWidth = originalRight - borderSize - fillPaddingLeft
		local backfillWidth = maxWidth * overfillRatio
		linePos = originalRight - borderSize - backfillWidth
		
		-- Make sure the line position doesn't go outside the bar
		linePos = math.max(fillPaddingLeft, linePos)
	end
	
	-- COLOR SETUP - don't change bar color when frozen
	local baseColor = barColor
	local topColor = {baseColor[1], baseColor[2], baseColor[3], baseColor[4]}
	local bottomColor = {baseColor[1]*0.7, baseColor[2]*0.7, baseColor[3]*0.7, baseColor[4]}
	
	-- GRADIENT RENDERING
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	
	if fillPaddingLeft < fillPaddingRight then
		if exceedsMaxThreshold then
			-- Calculate how much the bar exceeds the max threshold
			local overfillRatio = (score - maxThreshold) / maxThreshold
			-- Cap at 1.0 (100% backfilled)
			overfillRatio = math.min(overfillRatio, 1)
			
			local maxBarWidth = originalRight - borderSize - fillPaddingLeft
			local overfillWidth = maxBarWidth * overfillRatio
			
			-- The point where the bright color starts (from right side)
			local brightColorStart = originalRight - borderSize - overfillWidth
			
			-- NORMAL COLORED SECTION (left part)
			if brightColorStart > fillPaddingLeft then
				local vertices = {
					-- Bottom left
					{v = {fillPaddingLeft, fillPaddingBottom}, c = bottomColor},
					-- Bottom right
					{v = {brightColorStart, fillPaddingBottom}, c = bottomColor},
					-- Top right
					{v = {brightColorStart, fillPaddingTop}, c = topColor},
					-- Top left
					{v = {fillPaddingLeft, fillPaddingTop}, c = topColor}
				}
				gl.Shape(GL.QUADS, vertices)
			end
			
			-- BRIGHT COLORED SECTION (right part - backfill)
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
			
			local vertices = {
				-- Bottom left
				{v = {brightColorStart, fillPaddingBottom}, c = excessBottomColor},
				-- Bottom right
				{v = {originalRight - borderSize, fillPaddingBottom}, c = excessBottomColor},
				-- Top right
				{v = {originalRight - borderSize, fillPaddingTop}, c = excessTopColor},
				-- Top left
				{v = {brightColorStart, fillPaddingTop}, c = excessTopColor}
			}
			gl.Shape(GL.QUADS, vertices)
		else
			-- STANDARD SECTION
			local vertices = {
				-- Bottom left
				{v = {fillPaddingLeft, fillPaddingBottom}, c = bottomColor},
				-- Bottom right
				{v = {fillPaddingRight, fillPaddingBottom}, c = bottomColor},
				-- Top right
				{v = {fillPaddingRight, fillPaddingTop}, c = topColor},
				-- Top left
				{v = {fillPaddingLeft, fillPaddingTop}, c = topColor}
			}
			gl.Shape(GL.QUADS, vertices)
		end
		
		-- HIGHLIGHTS
		local glossHeight = (fillPaddingTop - fillPaddingBottom) * 0.4
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		
		-- Adjust highlight end position for overfilled bars
		local highlightRight = fillPaddingRight
		if exceedsMaxThreshold then
			highlightRight = originalRight - borderSize
		end
		
		-- Top highlight
		local topGlossBottom = fillPaddingTop - glossHeight
		local vertices = {
			-- Bottom left
			{v = {fillPaddingLeft, topGlossBottom}, c = {1, 1, 1, 0}},
			-- Bottom right
			{v = {highlightRight, topGlossBottom}, c = {1, 1, 1, 0}},
			-- Top right
			{v = {highlightRight, fillPaddingTop}, c = {1, 1, 1, 0.04}},
			-- Top left
			{v = {fillPaddingLeft, fillPaddingTop}, c = {1, 1, 1, 0.04}}
		}
		gl.Shape(GL.QUADS, vertices)
		
		-- Bottom highlight
		local bottomGlossHeight = (fillPaddingTop - fillPaddingBottom) * 0.2
		vertices = {
			-- Bottom left
			{v = {fillPaddingLeft, fillPaddingBottom}, c = {1, 1, 1, 0.02}},
			-- Bottom right
			{v = {highlightRight, fillPaddingBottom}, c = {1, 1, 1, 0.02}},
			-- Top right
			{v = {highlightRight, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}},
			-- Top left
			{v = {fillPaddingLeft, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}}
		}
		gl.Shape(GL.QUADS, vertices)
		
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	
	-- SKULL ICON RENDERING
	glPushMatrix()
	local skullY = bottom + (top - bottom)/2
	glTranslate(skullX, skullY, 0)
	
	-- Shadow
	local shadowOffset = 1.5
	local shadowAlpha = 0.6
	local shadowScale = 1.1
	
	glColor(0, 0, 0, shadowAlpha)
	glTexture(':n:LuaUI/Images/skull.dds')
	glTexRect(
		-iconSize/2 * shadowScale + shadowOffset, 
		-iconSize/2 * shadowScale - shadowOffset, 
		iconSize/2 * shadowScale + shadowOffset, 
		iconSize/2 * shadowScale - shadowOffset
	)
	
	-- SKULL ALPHA MANAGEMENT
	local skullAlpha = 1.0
	if isThresholdFrozen then
		local currentGameTime = spGetGameSeconds()
		local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
		local timeUntilUnfreeze = freezeExpirationTime - currentGameTime
		
		if timeUntilUnfreeze <= WARNING_SECONDS then
			-- Warning period blinking
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
			-- Normal frozen state
			skullAlpha = 0.5
			isSkullFaded = true
		end
	else
		isSkullFaded = false
	end
	
	-- Draw skull
	glColor(1, 1, 1, skullAlpha)
	glTexture(':n:LuaUI/Images/skull.dds')
	glTexRect(-iconSize/2, -iconSize/2, iconSize/2, iconSize/2)
	
	glTexture(false)
	glPopMatrix()
	
	-- SCORE LINE RENDERING
	local lineExtension = 3
	
	-- Determine line color based on whether the bar is overfilled
	local lineColor = exceedsMaxThreshold and COLOR_WHITE_LINE or COLOR_GREY_LINE
	
	-- Draw shadow/border for the line
	glColor(0, 0, 0, 0.8)
	glRect(linePos - lineWidth - 1, bottom - lineExtension, 
		   linePos + lineWidth + 1, top + lineExtension)
	
	-- Draw the actual line with the determined color
	glColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
	glRect(linePos - lineWidth/2, bottom - lineExtension, 
		   linePos + lineWidth/2, top + lineExtension)
		   
	return linePos, originalRight, thresholdX, skullX
end

-- TEXT RENDERING FUNCTION
local function drawDifferenceText(x, y, difference, fontSize, textColor)
	local formattedDifference = difference
	if difference > 0 then
		formattedDifference = "+" .. difference
	end
	
	-- Text outline
	glColor(COLOR_TEXT_OUTLINE[1], COLOR_TEXT_OUTLINE[2], COLOR_TEXT_OUTLINE[3], COLOR_TEXT_OUTLINE[4])
	glText(formattedDifference, x - TEXT_OUTLINE_OFFSET, y - TEXT_OUTLINE_OFFSET, fontSize, "l")
	glText(formattedDifference, x + TEXT_OUTLINE_OFFSET, y - TEXT_OUTLINE_OFFSET, fontSize, "l")
	glText(formattedDifference, x - TEXT_OUTLINE_OFFSET, y + TEXT_OUTLINE_OFFSET, fontSize, "l")
	glText(formattedDifference, x + TEXT_OUTLINE_OFFSET, y + TEXT_OUTLINE_OFFSET, fontSize, "l")
	glText(formattedDifference, x - TEXT_OUTLINE_OFFSET, y, fontSize, "l")
	glText(formattedDifference, x + TEXT_OUTLINE_OFFSET, y, fontSize, "l")
	glText(formattedDifference, x, y - TEXT_OUTLINE_OFFSET, fontSize, "l")
	glText(formattedDifference, x, y + TEXT_OUTLINE_OFFSET, fontSize, "l")
	
	-- Main text
	glColor(textColor[1], textColor[2], textColor[3], textColor[4])
	glText(formattedDifference, x, y, fontSize, "l")
end

-- Function to draw countdown text with outline
local function drawCountdownText(x, y, secondsRemaining, fontSize, textColor)
	local text
	if type(secondsRemaining) == "string" then
		text = secondsRemaining
	else
		text = format("%d", secondsRemaining)
	end
	
	-- Text outline
	glColor(COLOR_TEXT_OUTLINE[1], COLOR_TEXT_OUTLINE[2], COLOR_TEXT_OUTLINE[3], COLOR_TEXT_OUTLINE[4])
	glText(text, x - TEXT_OUTLINE_OFFSET, y - TEXT_OUTLINE_OFFSET, fontSize, "c")  -- Center-aligned
	glText(text, x + TEXT_OUTLINE_OFFSET, y - TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(text, x - TEXT_OUTLINE_OFFSET, y + TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(text, x + TEXT_OUTLINE_OFFSET, y + TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(text, x - TEXT_OUTLINE_OFFSET, y, fontSize, "c")
	glText(text, x + TEXT_OUTLINE_OFFSET, y, fontSize, "c")
	glText(text, x, y - TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(text, x, y + TEXT_OUTLINE_OFFSET, fontSize, "c")
	
	-- Main text
	glColor(textColor[1], textColor[2], textColor[3], textColor[4])
	glText(text, x, y, fontSize, "c")  -- Center-aligned
end

-- Function to check if an ally team is still alive
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

local fontCache = {
	initialized = false,
	fontSizeMultiplier = 1,
	fontSize = 11,
	paddingX = 0,
	paddingY = 0
}

local backgroundColor = {COLOR_BACKGROUND[1], COLOR_BACKGROUND[2], COLOR_BACKGROUND[3], COLOR_BACKGROUND[4]}
local borderColor = {COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4]}
local BORDER_WIDTH = 2

-- Add a function to create the timer warning message and its display list
local function createTimerWarningMessage(secondsRemaining, territoriesNeeded)

	local dominatedMessage = spI18N('ui.territorialDomination.losingWarning1')

	local conquerMessage = spI18N('ui.territorialDomination.losingWarning2', {seconds = ceil(secondsRemaining), needed = territoriesNeeded}) 
	
	-- Return as separate messages so we can position them separately
	return dominatedMessage, conquerMessage
end

local function createTimerWarningDisplayList(dominatedMessage, conquerMessage)
	if timerWarningDisplayList then
		glDeleteList(timerWarningDisplayList)
	end

	-- Create new display list
	timerWarningDisplayList = glCreateList(function()
		local vsx, vsy = Spring.GetViewGeometry()
		local widgetScale = 0.80 + (vsx * vsy / 6000000)
		local fontSize = 22 * widgetScale
		
		-- Position exactly like gui_game_type_info
		local y = 0.19  -- 19% up from the bottom
		local x = vsx * 0.5
		
		-- Apply font size scaling like gui_game_type_info
		glPushMatrix()
		glTranslate(x, vsy * y, 0)
		glScale(1.5, 1.5, 1)
		
		-- Calculate positions for the two lines with proper spacing
		local line1Y = 442  -- Center of first line
		local lineSpacing = line1Y * 0.06
		local line2Y = line1Y - lineSpacing
		
		-- Alpha is always 1.0 when creating the list - we'll use gl.Color when drawing to fade
		local alpha = 1.0
		
		-- Draw first line (dominated message)
		-- Text outline (shadow effect)
		glColor(0, 0, 0, alpha * 0.5)
		glText(dominatedMessage, 0 - 1, line1Y - 1, fontSize / 1.5, "c")
		
		-- Main text - WHITE
		glColor(1, 1, 1, alpha)
		glText(dominatedMessage, 0, line1Y, fontSize / 1.5, "c")
		
		-- Draw second line (conquer message)
		-- Text outline (shadow effect)
		glColor(0, 0, 0, alpha * 0.5)
		glText(conquerMessage, 0 - 1, line2Y - 1, fontSize / 1.5, "c")
		
		-- Main text - WHITE
		glColor(1, 1, 1, alpha)
		glText(conquerMessage, 0, line2Y, fontSize / 1.5, "c")
		
		glPopMatrix()
	end)
	
	return timerWarningDisplayList
end

local function createCountdownDisplayList(timeRemaining)
	if countdownDisplayList then
		glDeleteList(countdownDisplayList)
	end
	
	-- Create new display list
	countdownDisplayList = glCreateList(function()
		local countdownColor = COLOR_RED
		
		-- Get minimap dimensions to position the countdown
		local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
		local iconSize = 25
		local iconHalfWidth = iconSize / 2
		
		-- Ensure we have MINIMAP_GAP defined
		local miniMapGap = MINIMAP_GAP or 3
		
		-- Calculate skull position
		local healthbarLeft = minimapPosX + iconHalfWidth
		local healthbarRight = minimapPosX + minimapSizeX - iconHalfWidth
		local healthbarTop = minimapPosY - miniMapGap
		local healthbarBottom = healthbarTop - healthbarHeight
		local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
		local barWidth = healthbarRight - healthbarLeft
		local thresholdX = healthbarLeft + (threshold / maxThreshold) * barWidth
		local skullOffset = (1 / maxThreshold) * barWidth
		local skullX = thresholdX - skullOffset
		
		-- Use previous size
		local countdownFontSize = fontCache.fontSize * COUNTDOWN_FONT_SIZE_MULTIPLIER
		
		-- Position at the skull's center
		local countdownX = skullX
		local text = format("%d", timeRemaining)
		
		-- Set position to be centered on the skull
		local countdownY
		if amSpectating then
			-- For spectator mode
			local topY = minimapPosY - miniMapGap
			local barHeight = healthbarHeight * 0.7
			countdownY = topY - barHeight/2 - 10  -- Center on the bar and offset up by 10
		else
			-- Regular player view
			countdownY = healthbarBottom + (healthbarTop - healthbarBottom) / 2 - 7  -- Center on the bar and offset up by 10
		end
		
		-- Center-align the text
		drawCountdownText(countdownX, countdownY, text, countdownFontSize, countdownColor)
	end)
	
	return countdownDisplayList
end

function widget:Initialize()
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	selectedAllyTeamID = myAllyID
	gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID()))
	
	gameSeconds = spGetGameSeconds() or 0
	defeatTime = 0
	
	local allUnits = spGetAllUnits()
	local myTeamID = spGetMyTeamID()
	
	for _, unitID in ipairs(allUnits) do
		widget:MetaUnitAdded(unitID,  spGetUnitDefID(unitID), spGetUnitTeam(unitID), nil)
	end
	
	-- Initialize font the same way as in gui_game_type_info
	local vsx, vsy = Spring.GetViewGeometry()
	local widgetScale = 0.80 + (vsx * vsy / 6000000)
	if WG['fonts'] then
		font = WG['fonts'].getFont(nil, 1.5, 0.25, 1.25)
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

function widget:Update(dt)
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	
	local currentGameTime = spGetGameSeconds()
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local timeUntilUnfreeze = max(0, freezeExpirationTime - currentGameTime)
	
	gameSeconds = currentGameTime  -- Update game seconds every frame
	
	currentTime = os.clock()
	if isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS then
		updateScoreDisplayList()
	elseif currentTime - lastUpdateTime > UPDATE_FREQUENCY then
		lastUpdateTime = currentTime
		updateScoreDisplayList()
	end
	
	-- Force update when countdown is active
	if defeatTime and defeatTime > 0 and gameSeconds and defeatTime > gameSeconds then
		-- Check if we need to update countdown display list
		local timeRemaining = ceil(defeatTime - gameSeconds)
		if timeRemaining >= 0 and timeRemaining ~= lastCountdownValue then
			lastCountdownValue = timeRemaining
			createCountdownDisplayList(timeRemaining)
		end
		
		-- Check if we should show the timer warning
		local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
		local score = 0
		
		for _, teamID in ipairs(spGetTeamList(myAllyID)) do
			local _, _, isDead = spGetTeamInfo(teamID)
			if not isDead then
				local teamScore = spGetTeamRulesParam(teamID, SCORE_RULES_KEY)
				if teamScore then
					score = teamScore
					break
				end
			end
		end
		
		local difference = score - threshold
		local territoriesNeeded = abs(difference) + 1  -- Need one more than the negative difference
		
		-- Only show warning if difference is negative and only once per cooldown period
		if not amSpectating and difference < 0 then
			if (currentGameTime - lastTimerWarningTime) > TIMER_COOLDOWN then
				-- Create the warning message
				local domMsg, conqMsg = createTimerWarningMessage(timeRemaining, territoriesNeeded)
				timerWarningMessage = {domMsg, conqMsg}
				lastTimerWarningMessages = {domMsg, conqMsg}
				timerWarningEndTime = currentGameTime + TIMER_WARNING_DISPLAY_TIME
				
				-- Create the display list for the warning
				createTimerWarningDisplayList(domMsg, conqMsg)
			end
			lastTimerWarningTime = currentGameTime
		end
	end
end

function updateScoreDisplayList()
	local currentGameTime = spGetGameSeconds()
	local scoreAllyID = amSpectating and selectedAllyTeamID or myAllyID
	
	if scoreAllyID == gaiaAllyTeamID then 
		if displayList then
			glDeleteList(displayList)
			displayList = nil
		end
		return 
	end
	
	if not fontCache.initialized then
		local _, viewportSizeY = spGetViewGeometry()
		fontCache.fontSizeMultiplier = math.max(1.2, math.min(2.25, viewportSizeY / 1080))
		fontCache.fontSize = floor(14 * fontCache.fontSizeMultiplier)
		fontCache.paddingX = floor(fontCache.fontSize * PADDING_MULTIPLIER)
		fontCache.paddingY = fontCache.paddingX
		fontCache.initialized = true
	end

	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	
	local iconSize = 25
	local iconHalfWidth = iconSize / 2
	
	healthbarWidth = minimapSizeX - iconHalfWidth * 2
	
	if displayList then
		glDeleteList(displayList)
	end
	
	-- DISPLAY LIST CREATION
	displayList = glCreateList(function()
		if amSpectating then
			-- Show bars for all ally teams when spectating
			local allyTeamList = spGetAllyTeamList()
			local barHeight = healthbarHeight * 0.7
			local barSpacing = 12
			
			-- Count alive ally teams for spacing calculations
			local aliveAllyTeams = {}
			for _, allyTeamID in ipairs(allyTeamList) do
				if isAllyTeamAlive(allyTeamID) then
					table.insert(aliveAllyTeams, allyTeamID)
				end
			end
			-- Get scores for ally teams and sort by score (highest to lowest)
			local allyTeamScores = {}
			for _, allyTeamID in ipairs(aliveAllyTeams) do
				local score = 0
				local teamColor = {1, 1, 1, 0.8} -- Default color
				local firstTeamFound = false
				
				-- Find the first team in this ally team to get its color and score
				for _, teamID in ipairs(spGetTeamList(allyTeamID)) do
					local _, _, isDead = spGetTeamInfo(teamID)
					if not isDead then
						local teamScore = spGetTeamRulesParam(teamID, SCORE_RULES_KEY)
						if teamScore then
							score = teamScore
							
							-- Get first team's color if we haven't already
							if not firstTeamFound then
								local r, g, b = spGetTeamColor(teamID)
								teamColor = {r, g, b, 0.8}
								firstTeamFound = true
							end
							
							break
						end
					end
				end
				
				table.insert(allyTeamScores, {
					allyTeamID = allyTeamID,
					score = score,
					teamColor = teamColor
				})
			end
			
			-- Sort by score (highest to lowest)
			table.sort(allyTeamScores, function(a, b) return a.score > b.score end)
			
			-- Calculate total height for positioning
			local totalHeight = #aliveAllyTeams * (barHeight + barSpacing)
			
			local startY = minimapPosY - MINIMAP_GAP
			local currentY = startY
			
			-- Draw bars for sorted ally teams
			for _, allyTeamData in ipairs(allyTeamScores) do
				local allyTeamID = allyTeamData.allyTeamID
				local score = allyTeamData.score
				local teamColor = allyTeamData.teamColor
				
				local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
				maxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
				
				local difference = score - threshold
				local textColor = COLOR_WHITE
				
				local healthbarTop = currentY
				local healthbarBottom = healthbarTop - barHeight
				local healthbarLeft = minimapPosX + iconHalfWidth
				local healthbarRight = minimapPosX + minimapSizeX - iconHalfWidth
				
				local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
				local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
				
				local healthbarScoreRight = healthbarLeft + (score / maxThreshold) * (healthbarRight - healthbarLeft)
				local actualRight = healthbarRight
				local thresholdX = healthbarLeft + (threshold / maxThreshold) * (healthbarRight - healthbarLeft)
				
				if score > maxThreshold then
					actualRight = healthbarLeft + (score / maxThreshold) * (healthbarRight - healthbarLeft)
				end
				
				local exceedsMaxThreshold = score > maxThreshold
				-- Never extend background beyond the default width
				local adjustedBackgroundRight = healthbarRight
				
				-- Create a tinted background based on team color (very subtle)
				local bgTintStrength = 0.15  -- How strong the team color affects the background
				local tintedBackgroundColor = {
					backgroundColor[1] + (teamColor[1] - backgroundColor[1]) * bgTintStrength,
					backgroundColor[2] + (teamColor[2] - backgroundColor[2]) * bgTintStrength,
					backgroundColor[3] + (teamColor[3] - backgroundColor[3]) * bgTintStrength,
					backgroundColor[4]
				}
				
				-- Also tint the border slightly
				local borderTintStrength = 0.1  -- Border tint is more subtle
				local tintedBorderColor = {
					borderColor[1] + (teamColor[1] - borderColor[1]) * borderTintStrength,
					borderColor[2] + (teamColor[2] - borderColor[2]) * borderTintStrength,
					borderColor[3] + (teamColor[3] - borderColor[3]) * borderTintStrength,
					borderColor[4]
				}
				
				glColor(tintedBorderColor[1], tintedBorderColor[2], tintedBorderColor[3], tintedBorderColor[4])
				glRect(healthbarLeft - BORDER_WIDTH, healthbarBottom - BORDER_WIDTH, 
					   adjustedBackgroundRight + BORDER_WIDTH, healthbarTop + BORDER_WIDTH)
					   
				glColor(tintedBackgroundColor[1], tintedBackgroundColor[2], tintedBackgroundColor[3], tintedBackgroundColor[4])
				glRect(healthbarLeft, healthbarBottom, adjustedBackgroundRight, healthbarTop)
				
				local healthbarScoreRight, actualRight, thresholdX, skullX = drawHealthBar(
					healthbarLeft, healthbarRight, 
					healthbarBottom, healthbarTop, 
					score, threshold, teamColor, isThresholdFrozen
				)
				
				local textX
				local textPadding = 2
				local estimatedTextWidth = fontCache.fontSize * len(tostring(difference)) * 0.7
				
				textX = skullX + iconSize/2 + textPadding
				
				if textX > healthbarScoreRight then
					textX = skullX - iconSize/2 - textPadding - estimatedTextWidth
					
					if textX < healthbarLeft then
						textX = skullX + iconSize/2 + textPadding
					end
				end
				
				local verticalOffset = -3
				local textY = healthbarBottom + (healthbarTop - healthbarBottom) / 2 + verticalOffset
				
				drawDifferenceText(textX, textY, difference, fontCache.fontSize, textColor)
				
				currentY = healthbarBottom - barSpacing
			end
		else
			-- Single bar for the player's own team
			local score = 0
			local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
			maxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
			
			for _, teamID in ipairs(spGetTeamList(myAllyID)) do
				local _, _, isDead = spGetTeamInfo(teamID)
				if not isDead then
					local teamScore = spGetTeamRulesParam(teamID, SCORE_RULES_KEY)
					if teamScore then
						score = teamScore
						break
					end
				end
			end
			
			local difference = score - threshold
			local textColor = COLOR_WHITE
			
			local barColor
			if difference <= WARNING_THRESHOLD then
				barColor = COLOR_RED
			elseif difference <= ALERT_THRESHOLD then
				barColor = COLOR_YELLOW
			else
				barColor = COLOR_GREEN
			end
			
			local healthbarTop = minimapPosY - MINIMAP_GAP
			local healthbarBottom = healthbarTop - healthbarHeight
			local healthbarLeft = minimapPosX + iconHalfWidth
			local healthbarRight = minimapPosX + minimapSizeX - iconHalfWidth
			
			local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
			local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
			
			local healthbarScoreRight = healthbarLeft + (score / maxThreshold) * (healthbarRight - healthbarLeft)
			local actualRight = healthbarRight
			local thresholdX = healthbarLeft + (threshold / maxThreshold) * (healthbarRight - healthbarLeft)
			
			if score > maxThreshold then
				actualRight = healthbarLeft + (score / maxThreshold) * (healthbarRight - healthbarLeft)
			end
			
			local exceedsMaxThreshold = score > maxThreshold
			-- Never extend background beyond the default width
			local adjustedBackgroundRight = healthbarRight
			
			glPushMatrix()
				-- Create a tinted background based on team color (very subtle)
				local bgTintStrength = 0.15  -- How strong the team color affects the background
				local tintedBackgroundColor = {
					backgroundColor[1] + (barColor[1] - backgroundColor[1]) * bgTintStrength,
					backgroundColor[2] + (barColor[2] - backgroundColor[2]) * bgTintStrength,
					backgroundColor[3] + (barColor[3] - backgroundColor[3]) * bgTintStrength,
					backgroundColor[4]
				}
				
				-- Also tint the border slightly
				local borderTintStrength = 0.1  -- Border tint is more subtle
				local tintedBorderColor = {
					borderColor[1] + (barColor[1] - borderColor[1]) * borderTintStrength,
					borderColor[2] + (barColor[2] - borderColor[2]) * borderTintStrength,
					borderColor[3] + (barColor[3] - borderColor[3]) * borderTintStrength,
					borderColor[4]
				}
				
				glColor(tintedBorderColor[1], tintedBorderColor[2], tintedBorderColor[3], tintedBorderColor[4])
				glRect(healthbarLeft - BORDER_WIDTH, healthbarBottom - BORDER_WIDTH, 
					   adjustedBackgroundRight + BORDER_WIDTH, healthbarTop + BORDER_WIDTH)
					   
				glColor(tintedBackgroundColor[1], tintedBackgroundColor[2], tintedBackgroundColor[3], tintedBackgroundColor[4])
				glRect(healthbarLeft, healthbarBottom, adjustedBackgroundRight, healthbarTop)
				
				local healthbarScoreRight, actualRight, thresholdX, skullX = drawHealthBar(
					healthbarLeft, healthbarRight, 
					healthbarBottom, healthbarTop, 
					score, threshold, barColor, isThresholdFrozen
				)
				
				local textX
				local textPadding = 2
				local estimatedTextWidth = fontCache.fontSize * len(tostring(difference)) * 0.7
				
				textX = skullX + iconSize/2 + textPadding
				
				if textX > healthbarScoreRight then
					textX = skullX - iconSize/2 - textPadding - estimatedTextWidth
					
					if textX < healthbarLeft then
						textX = skullX + iconSize/2 + textPadding
					end
				end
				
				local verticalOffset = -3
				local textY = healthbarBottom + (healthbarTop - healthbarBottom) / 2 + verticalOffset
				
				drawDifferenceText(textX, textY, difference, fontCache.fontSize, textColor)
			glPopMatrix()
		end
	end)
end

function widget:DrawScreen()
	local currentGameTime = spGetGameSeconds()
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local timeUntilUnfreeze = freezeExpirationTime - currentGameTime
	
	-- Always update display list when countdown is active
	if defeatTime and defeatTime > 0 and currentGameTime and defeatTime > currentGameTime then
		updateScoreDisplayList()
	elseif isSkullFaded or (isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS) then
		updateScoreDisplayList()
	end
	
	if displayList then
		glCallList(displayList)
	else
		updateScoreDisplayList()
	end
	
	-- Draw the countdown timer display list if active
	if countdownDisplayList and defeatTime and defeatTime > 0 and gameSeconds and defeatTime > gameSeconds then
		glCallList(countdownDisplayList)
	end
	
	-- Draw the timer warning display list if active
	if timerWarningDisplayList and currentGameTime < timerWarningEndTime then
		-- Calculate alpha for fade out effect (if needed)
		local alpha = 1.0
		-- You could implement fade near the end:
		-- local timeLeft = timerWarningEndTime - currentGameTime
		-- if timeLeft < 1.0 then
		--     alpha = timeLeft
		-- end
		
		-- Set global alpha only - the display list contains all the drawing commands
		glColor(1, 1, 1, alpha)
		glCallList(timerWarningDisplayList)
	end
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

function widget:Shutdown()
	if displayList then
		glDeleteList(displayList)
		displayList = nil
	end
	
	if timerWarningDisplayList then
		glDeleteList(timerWarningDisplayList)
		timerWarningDisplayList = nil
	end
	
	if countdownDisplayList then
		glDeleteList(countdownDisplayList)
		countdownDisplayList = nil
	end
end

local function queueTeleportSounds()
	soundQueue = {}
	if defeatTime and defeatTime > 0 then
		table.insert(soundQueue, 1, {when = defeatTime - WINDUP_SOUND_DURATION - ACTIVATE_SOUND_DURATION, sound = "cmd-off", volume = 0.5})
		table.insert(soundQueue, 1, {when = defeatTime - WINDUP_SOUND_DURATION, sound = "teleport-windup", volume = 0.5})
	end
end


function widget:GameFrame(frame)
	if frame % DEFEAT_CHECK_INTERVAL == AFTER_GADGET_TIMER_UPDATE_MODULO + 2 then
		local myTeamID = Spring.GetMyTeamID()
		local newDefeatTime = spGetTeamRulesParam(myTeamID, "defeatTime") or 0
		Spring.Echo("newDefeatTime B", newDefeatTime, defeatTime)
		--0, number1
		--number1, number1
		if newDefeatTime > 0 then
			if newDefeatTime ~= defeatTime then
				Spring.Echo("newDefeatTime C", newDefeatTime, defeatTime)
				defeatTime = newDefeatTime
				loopSoundEndTime = defeatTime - WINDUP_SOUND_DURATION
				soundQueue = nil
				queueTeleportSounds()
			end
		else
			defeatTime = 0
			loopSoundEndTime = 0
			soundQueue = nil
			soundIndex = 1
		end
	end

	gameSeconds = spGetGameSeconds() or 0

	if loopSoundEndTime and loopSoundEndTime > gameSeconds then
		if lastLoop < currentTime then
			lastLoop = currentTime
			
			-- Calculate volume based on time until defeat
			local timeRange = loopSoundEndTime - (defeatTime - WINDUP_SOUND_DURATION - CHARGE_SOUND_LOOP_DURATION * 10)
			local timeLeft = loopSoundEndTime - gameSeconds
			local minVolume = 0.05
			local maxVolume = 0.2
			local volumeRange = maxVolume - minVolume
			
			local volumeFactor = 1 - (timeLeft / timeRange)
			volumeFactor = math.clamp(volumeFactor, 0, 1)
			local currentVolume = minVolume + (volumeFactor * volumeRange)
			
			for unitID in pairs(myCommanders) do
				local x, y, z = spGetUnitPosition(unitID)
				if x then
					spPlaySoundFile("teleport-charge-loop", currentVolume, x, y, z, 0, 0, 0, "sfx")
				else
					myCommanders[unitID] = nil
				end
			end
		end
	else
		local sound = soundQueue and soundQueue[soundIndex]
		if sound and gameSeconds and sound.when < gameSeconds then
			for unitID in pairs(myCommanders) do
				local x, y, z = spGetUnitPosition(unitID)
				if x then
					spPlaySoundFile(sound.sound, sound.volume, x, y, z, 0, 0, 0, "sfx")
				else
					myCommanders[unitID] = nil
				end
			end
			soundIndex = soundIndex + 1
		end
	end
end

function widget:ViewResize()
	-- Update font when view is resized, similar to gui_game_type_info
	local vsx, vsy = Spring.GetViewGeometry()
	local widgetScale = 0.80 + (vsx * vsy / 6000000)
	
	if WG['fonts'] then
		font = WG['fonts'].getFont(nil, 1.5, 0.25, 1.25)
	end
end