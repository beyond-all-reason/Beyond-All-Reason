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
local max = math.max

local BLINK_FREQUENCY = 0.5
local WARNING_THRESHOLD = 3
local ALERT_THRESHOLD = 10
local WARNING_SECONDS = 10
local PADDING_MULTIPLIER = 0.36
local TEXT_HEIGHT_MULTIPLIER = 0.33
local SCORE_RULES_KEY = "territorialDominationScore"
local THRESHOLD_RULES_KEY = "territorialDominationDefeatThreshold"
local FREEZE_DELAY_KEY = "territorialDominationFreezeDelay"
local MAX_THRESHOLD_RULES_KEY = "territorialDominationMaxThreshold"
local UPDATE_FREQUENCY = 0.1  -- Update the display list every
local BLINK_VOLUME_WARNING_RESET_SECONDS = 10
local MIN_BLINK_VOLUME = 0.15
local MAX_BLINK_VOLUME = 0.4
local TEXT_OUTLINE_OFFSET = 0.7  -- Reduced from 1.2
local TEXT_OUTLINE_ALPHA = 0.35  -- Reduced from 0.6
local LINE_ALPHA = 0.5

local COLOR_WHITE = {1, 1, 1, 1}
local COLOR_RED = {1, 0, 0, 1}
local COLOR_YELLOW = {1, 0.8, 0, 1}
local COLOR_BACKGROUND = {0, 0, 0, 0.5}
local COLOR_BORDER = {0.2, 0.2, 0.2, 0.2}
local COLOR_GREEN = {0, 0.8, 0, 0.8}
local COLOR_TEXT_OUTLINE = {0, 0, 0, TEXT_OUTLINE_ALPHA}
local RED_BLINK_COLOR = {0.9, 0, 0, 1}
local FROZEN_TEXT_COLOR = {0.6, 0.6, 0.6, 1.0}

local lastWarningBlinkTime = 0
local lastFreezeBlinkTime = 0
local isWarningVisible = true
local isFreezeWarningVisible = true
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

-- Helper functions to reduce upvalues in main functions
local function drawHealthBar(left, right, bottom, top, score, threshold, textColor)
	-- Calculate healthbar positions
	local fullHealthbarLeft = left
	local fullHealthbarRight = right
	local barWidth = right - left
	
	local originalRight = right
	local exceedsMaxThreshold = score > maxThreshold
	
	-- If score exceeds maxThreshold, expand the bar
	if exceedsMaxThreshold then
		right = left + (score / maxThreshold) * barWidth
	end
	
	local healthbarScoreRight = left + (score / maxThreshold) * barWidth
	local thresholdX = left + (threshold / maxThreshold) * barWidth
	
	-- Set up skull icon size to fit within the healthbar
	local iconSize = 25
	
	-- Define a 3-pixel border around the filled portion
	local borderSize = 3
	local fillPaddingLeft = fullHealthbarLeft + borderSize
	local fillPaddingRight = healthbarScoreRight - borderSize
	local fillPaddingTop = top  -- Removed top padding
	local fillPaddingBottom = bottom + borderSize
	
	-- Main gradient (brighter on top, darker at bottom) - more subtle
	local baseGreen = COLOR_GREEN
	local topColor = {baseGreen[1], baseGreen[2], baseGreen[3], baseGreen[4]}
	-- Make bottom color less different from top color for more subtle gradient
	local bottomColor = {baseGreen[1]*0.7, baseGreen[2]*0.7, baseGreen[3]*0.7, baseGreen[4]}
	
	-- Create the gradient rectangle
	-- First draw background gradient
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	
	if fillPaddingLeft < fillPaddingRight then
		-- If score exceeds maxThreshold, draw normal part first
		if exceedsMaxThreshold then
			-- Normal part (up to originalRight)
			local normalPartRight = originalRight - borderSize
			
			-- Top to bottom gradient with 3-pixel border
			local vertices = {
				-- Bottom left
				{v = {fillPaddingLeft, fillPaddingBottom}, c = bottomColor},
				-- Bottom right
				{v = {normalPartRight, fillPaddingBottom}, c = bottomColor},
				-- Top right
				{v = {normalPartRight, fillPaddingTop}, c = topColor},
				-- Top left
				{v = {fillPaddingLeft, fillPaddingTop}, c = topColor}
			}
			gl.Shape(GL.QUADS, vertices)
			
			-- Now draw excess part with whiter color (50% whiter)
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
			
			-- Draw excess part gradient
			vertices = {
				-- Bottom left
				{v = {normalPartRight, fillPaddingBottom}, c = excessBottomColor},
				-- Bottom right
				{v = {fillPaddingRight, fillPaddingBottom}, c = excessBottomColor},
				-- Top right
				{v = {fillPaddingRight, fillPaddingTop}, c = excessTopColor},
				-- Top left
				{v = {normalPartRight, fillPaddingTop}, c = excessTopColor}
			}
			gl.Shape(GL.QUADS, vertices)
		else
			-- Standard drawing for normal cases
			-- Top to bottom gradient with 3-pixel border
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
		
		-- Add glossiness to top portion (reduced for subtlety)
		local glossHeight = (fillPaddingTop - fillPaddingBottom) * 0.4
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		
		-- Top highlight (more subtle)
		local topGlossBottom = fillPaddingTop - glossHeight
		local vertices = {
			-- Bottom left
			{v = {fillPaddingLeft, topGlossBottom}, c = {1, 1, 1, 0}},
			-- Bottom right
			{v = {fillPaddingRight, topGlossBottom}, c = {1, 1, 1, 0}},
			-- Top right
			{v = {fillPaddingRight, fillPaddingTop}, c = {1, 1, 1, 0.04}}, -- reduced from 0.07
			-- Top left
			{v = {fillPaddingLeft, fillPaddingTop}, c = {1, 1, 1, 0.04}}  -- reduced from 0.07
		}
		gl.Shape(GL.QUADS, vertices)
		
		-- Bottom highlight (more subtle)
		local bottomGlossHeight = (fillPaddingTop - fillPaddingBottom) * 0.2
		vertices = {
			-- Bottom left
			{v = {fillPaddingLeft, fillPaddingBottom}, c = {1, 1, 1, 0.02}}, -- reduced from 0.03
			-- Bottom right
			{v = {fillPaddingRight, fillPaddingBottom}, c = {1, 1, 1, 0.02}}, -- reduced from 0.03
			-- Top right
			{v = {fillPaddingRight, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}},
			-- Top left
			{v = {fillPaddingLeft, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}}
		}
		gl.Shape(GL.QUADS, vertices)
		
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	
	-- Draw skull icon at the threshold position inside the healthbar
	glPushMatrix()
	local skullY = bottom + (top - bottom)/2
	glTranslate(thresholdX, skullY, 0)
	
	-- Add shadow effect for the skull
	local shadowOffset = 1.5
	local shadowAlpha = 0.6
	local shadowScale = 1.1
	
	-- Draw shadow (slightly larger, offset, and black)
	glColor(0, 0, 0, shadowAlpha)
	glTexture(':n:LuaUI/Images/skull.dds')
	glTexRect(
		-iconSize/2 * shadowScale + shadowOffset, 
		-iconSize/2 * shadowScale - shadowOffset, 
		iconSize/2 * shadowScale + shadowOffset, 
		iconSize/2 * shadowScale - shadowOffset
	)
	
	-- Draw the actual skull icon
	glColor(1, 1, 1, 1) -- White for maximum contrast
	glTexture(':n:LuaUI/Images/skull.dds')
	glTexRect(-iconSize/2, -iconSize/2, iconSize/2, iconSize/2)
	glTexture(false)
	glPopMatrix()
	
	-- Restore the white line with black background
	local lineExtension = 3 -- How many pixels the lines extend beyond the bar
	
	-- Draw black background for white line (slightly wider than the line itself)
	glColor(0, 0, 0, 0.8)
	glRect(healthbarScoreRight - lineWidth - 1, bottom - lineExtension, 
		   healthbarScoreRight + lineWidth + 1, top + lineExtension)
	
	-- Draw the line using the same color as the fill (gradient green)
	glColor(COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], LINE_ALPHA)
	glRect(healthbarScoreRight - lineWidth/2, bottom - lineExtension, 
		   healthbarScoreRight + lineWidth/2, top + lineExtension)
		   
	-- Return both the score position and the potentially expanded right edge
	return healthbarScoreRight, right
end

local function drawDifferenceText(x, y, difference, fontSize, textColor)
	-- Format the difference with a plus sign for positive values
	local formattedDifference = difference
	if difference > 0 then
		formattedDifference = "+" .. difference
	end
	
	-- Draw fuzzy black outline
	glColor(COLOR_TEXT_OUTLINE[1], COLOR_TEXT_OUTLINE[2], COLOR_TEXT_OUTLINE[3], COLOR_TEXT_OUTLINE[4])
	glText(formattedDifference, x - TEXT_OUTLINE_OFFSET, y - TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(formattedDifference, x + TEXT_OUTLINE_OFFSET, y - TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(formattedDifference, x - TEXT_OUTLINE_OFFSET, y + TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(formattedDifference, x + TEXT_OUTLINE_OFFSET, y + TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(formattedDifference, x - TEXT_OUTLINE_OFFSET, y, fontSize, "c")
	glText(formattedDifference, x + TEXT_OUTLINE_OFFSET, y, fontSize, "c")
	glText(formattedDifference, x, y - TEXT_OUTLINE_OFFSET, fontSize, "c")
	glText(formattedDifference, x, y + TEXT_OUTLINE_OFFSET, fontSize, "c")
	
	-- Draw actual text
	glColor(textColor[1], textColor[2], textColor[3], textColor[4])
	glText(formattedDifference, x, y, fontSize, "c")
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

function widget:Initialize()
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	selectedAllyTeamID = myAllyID
	gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID()))
end

function widget:Update(dt)
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	
	-- Update the display list at the specified frequency
	local currentTime = os.clock()
	if currentTime - lastUpdateTime > UPDATE_FREQUENCY then
		lastUpdateTime = currentTime
		updateScoreDisplayList()
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
	
	local score = 0
	local threshold = spGetGameRulesParam(THRESHOLD_RULES_KEY) or 0
	maxThreshold = spGetGameRulesParam(MAX_THRESHOLD_RULES_KEY) or 256
	
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

	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local timeUntilUnfreeze = freezeExpirationTime - currentGameTime
	
	local shouldGreyOutText = isThresholdFrozen and timeUntilUnfreeze > WARNING_SECONDS

	local textColor
	if isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS then
		if currentGameTime > lastFreezeBlinkTime + BLINK_VOLUME_WARNING_RESET_SECONDS then
			warningSoundFadeMultiplier = MAX_BLINK_VOLUME
		end
		if currentGameTime - lastFreezeBlinkTime > BLINK_FREQUENCY then
			lastFreezeBlinkTime = currentGameTime
			if isFreezeWarningVisible and not amSpectating then
				spPlaySoundFile('cmd-onoff', warningSoundFadeMultiplier, "ui")
				warningSoundFadeMultiplier = math.max(MIN_BLINK_VOLUME, warningSoundFadeMultiplier * 0.9)
			end
			isFreezeWarningVisible = not isFreezeWarningVisible
		end
		
		if isFreezeWarningVisible then
			textColor = FROZEN_TEXT_COLOR
		else
			if difference <= WARNING_THRESHOLD then
				textColor = COLOR_RED
			elseif difference <= ALERT_THRESHOLD then
				textColor = COLOR_YELLOW
			else
				textColor = COLOR_WHITE
			end
		end
	else
		if shouldGreyOutText then
			textColor = FROZEN_TEXT_COLOR
		else
			if difference <= WARNING_THRESHOLD then
				if currentGameTime - lastWarningBlinkTime > BLINK_FREQUENCY then
					lastWarningBlinkTime = currentGameTime
					isWarningVisible = not isWarningVisible
					if isWarningVisible and not amSpectating then
						spPlaySoundFile('cmd-onoff', warningSoundFadeMultiplier, "ui")
						warningSoundFadeMultiplier = max(MIN_BLINK_VOLUME, warningSoundFadeMultiplier * 0.9)
					end
				end
				textColor = isWarningVisible and COLOR_RED or RED_BLINK_COLOR
			elseif difference <= ALERT_THRESHOLD then
				textColor = COLOR_YELLOW
			else
				textColor = COLOR_WHITE
			end
		end
	end

	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local MINIMAP_GAP = 3 -- Gap between minimap and our display
	
	-- Set up skull icon size to fit within the healthbar
	local iconSize = 25
	local iconHalfWidth = iconSize / 2
	
	-- Scale the healthbar width to match the minimap width, minus the skull icon size
	healthbarWidth = minimapSizeX - iconHalfWidth * 2  -- Subtract half the skull width from each side
	
	-- Set up healthbar dimensions
	local healthbarTop = minimapPosY - MINIMAP_GAP
	local healthbarBottom = healthbarTop - healthbarHeight
	local healthbarLeft = minimapPosX + iconHalfWidth  -- Start after half the skull width
	local healthbarRight = minimapPosX + minimapSizeX - iconHalfWidth  -- End before half the skull width
	
	-- Calculate text metrics and position
	local textPadding = 4  -- Fixed padding between healthbar and text
	local textHeight = fontCache.fontSize
	local textPositionY = healthbarBottom - textPadding - textHeight/2
	
	-- Calculate background to include healthbar plus text with padding
	local backgroundTop = healthbarTop
	local backgroundBottom = textPositionY - textHeight/2 - 2 -- 2 pixels bottom padding
	local backgroundLeft = healthbarLeft
	local backgroundRight = healthbarRight
	
	local exceedsMaxThreshold = score > maxThreshold
	
	local backgroundDimensions = {
		left = backgroundLeft,
		right = backgroundRight,
		top = backgroundTop,
		bottom = backgroundBottom,
		healthbarTop = healthbarTop,
		healthbarBottom = healthbarBottom,
		textY = textPositionY,
		exceedsMaxThreshold = exceedsMaxThreshold
	}
	
	-- Only recreate the display list if something has changed
	local textColorChanged = lastTextColor == nil or 
		lastTextColor[1] ~= textColor[1] or 
		lastTextColor[2] ~= textColor[2] or 
		lastTextColor[3] ~= textColor[3] or 
		lastTextColor[4] ~= textColor[4]
	
	local backgroundChanged = lastBackgroundDimensions == nil or
		lastBackgroundDimensions.left ~= backgroundDimensions.left or
		lastBackgroundDimensions.right ~= backgroundDimensions.right or
		lastBackgroundDimensions.top ~= backgroundDimensions.top or
		lastBackgroundDimensions.bottom ~= backgroundDimensions.bottom or
		lastBackgroundDimensions.healthbarTop ~= backgroundDimensions.healthbarTop or
		lastBackgroundDimensions.healthbarBottom ~= backgroundDimensions.healthbarBottom or
		lastBackgroundDimensions.textY ~= backgroundDimensions.textY or
		lastBackgroundDimensions.exceedsMaxThreshold ~= backgroundDimensions.exceedsMaxThreshold
	
	if difference ~= lastDifference or textColorChanged or backgroundChanged then
		lastDifference = difference
		lastTextColor = {textColor[1], textColor[2], textColor[3], textColor[4]}
		lastBackgroundDimensions = backgroundDimensions
		
		-- Delete the old display list if it exists
		if displayList then
			glDeleteList(displayList)
		end
		
		-- Create a new display list
		displayList = glCreateList(function()
			glPushMatrix()
				-- First, calculate the score position and actual width without drawing
				local healthbarScoreRight = healthbarLeft + (score / maxThreshold) * (healthbarRight - healthbarLeft)
				local actualRight = healthbarRight
				if score > maxThreshold then
					actualRight = healthbarLeft + (score / maxThreshold) * (healthbarRight - healthbarLeft)
				end
				
				-- Now we know the actual width, so we can draw the background to match
				-- If the score exceeds maxThreshold, adjust the background width
				local adjustedBackgroundRight = exceedsMaxThreshold and actualRight or backgroundRight
				
				-- Draw background and border with potentially adjusted width FIRST
				glColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
				glRect(backgroundLeft - BORDER_WIDTH, healthbarBottom - BORDER_WIDTH, 
					   adjustedBackgroundRight + BORDER_WIDTH, healthbarTop + BORDER_WIDTH)
					   
				glColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
				glRect(backgroundLeft, healthbarBottom, adjustedBackgroundRight, healthbarTop)
				
				-- Now draw the health bar over the background
				local healthbarScoreRight, actualRight = drawHealthBar(
					healthbarLeft, healthbarRight, 
					healthbarBottom, healthbarTop, 
					score, threshold, textColor
				)
				
				-- Draw score difference text
				local textY = healthbarBottom - textHeight
				drawDifferenceText(healthbarScoreRight, textY, difference, fontCache.fontSize, textColor)
			glPopMatrix()
		end)
	end
end

function widget:DrawScreen()
	if displayList then
		glCallList(displayList)
	else
		updateScoreDisplayList()
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
end