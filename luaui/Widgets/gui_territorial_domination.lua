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
local format = string.format
local len = string.len
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
local spGetGameFrame = Spring.GetGameFrame

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
local LINE_ALPHA = 0.5
local BLINK_FRAMES = 10
local BLINK_INTERVAL = 1

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

local lastWarningBlinkTime = 0
local isWarningVisible = true
local isFreezeWarningVisible = true
local isSkullFaded = true

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
local function drawHealthBar(left, right, bottom, top, score, threshold, barColor, isThresholdFrozen)
	-- POSITION CALCULATIONS
	local fullHealthbarLeft = left
	local fullHealthbarRight = right
	local barWidth = right - left
	
	local originalRight = right
	local exceedsMaxThreshold = score > maxThreshold
	
	if exceedsMaxThreshold then
		right = left + (score / maxThreshold) * barWidth
	end
	
	local healthbarScoreRight = left + (score / maxThreshold) * barWidth
	local thresholdX = left + (threshold / maxThreshold) * barWidth
	
	local iconSize = 25
	
	local borderSize = 3
	local fillPaddingLeft = fullHealthbarLeft + borderSize
	local fillPaddingRight = healthbarScoreRight - borderSize
	local fillPaddingTop = top
	local fillPaddingBottom = bottom + borderSize
	
	-- COLOR SETUP - don't change bar color when frozen
	local baseColor = barColor
	local topColor = {baseColor[1], baseColor[2], baseColor[3], baseColor[4]}
	local bottomColor = {baseColor[1]*0.7, baseColor[2]*0.7, baseColor[3]*0.7, baseColor[4]}
	
	-- GRADIENT RENDERING
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	
	if fillPaddingLeft < fillPaddingRight then
		if exceedsMaxThreshold then
			-- NORMAL SECTION
			local normalPartRight = originalRight - borderSize
			
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
			
			-- EXCESS SECTION
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
		
		-- Top highlight
		local topGlossBottom = fillPaddingTop - glossHeight
		local vertices = {
			-- Bottom left
			{v = {fillPaddingLeft, topGlossBottom}, c = {1, 1, 1, 0}},
			-- Bottom right
			{v = {fillPaddingRight, topGlossBottom}, c = {1, 1, 1, 0}},
			-- Top right
			{v = {fillPaddingRight, fillPaddingTop}, c = {1, 1, 1, 0.04}},
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
			{v = {fillPaddingRight, fillPaddingBottom}, c = {1, 1, 1, 0.02}},
			-- Top right
			{v = {fillPaddingRight, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}},
			-- Top left
			{v = {fillPaddingLeft, fillPaddingBottom + bottomGlossHeight}, c = {1, 1, 1, 0}}
		}
		gl.Shape(GL.QUADS, vertices)
		
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	
	-- SKULL ICON RENDERING
	glPushMatrix()
	local skullY = bottom + (top - bottom)/2
	glTranslate(thresholdX, skullY, 0)
	
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
			local currentTime = os.clock()
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
	
	glColor(0, 0, 0, 0.8)
	glRect(healthbarScoreRight - lineWidth - 1, bottom - lineExtension, 
		   healthbarScoreRight + lineWidth + 1, top + lineExtension)
	
	glColor(COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], LINE_ALPHA)
	glRect(healthbarScoreRight - lineWidth/2, bottom - lineExtension, 
		   healthbarScoreRight + lineWidth/2, top + lineExtension)
		   
	return healthbarScoreRight, right, thresholdX
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

function widget:Initialize()
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	selectedAllyTeamID = myAllyID
	gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID()))
end

function widget:Update(dt)
	amSpectating = spGetSpectatingState()
	myAllyID = spGetMyAllyTeamID()
	
	local currentGameTime = spGetGameSeconds()
	local freezeExpirationTime = spGetGameRulesParam(FREEZE_DELAY_KEY) or 0
	local isThresholdFrozen = (freezeExpirationTime > currentGameTime)
	local timeUntilUnfreeze = max(0, freezeExpirationTime - currentGameTime)
	
	local currentTime = os.clock()
	if isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS then
		updateScoreDisplayList()
	elseif currentTime - lastUpdateTime > UPDATE_FREQUENCY then
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
	
	if not fontCache.initialized then
		local _, viewportSizeY = spGetViewGeometry()
		fontCache.fontSizeMultiplier = math.max(1.2, math.min(2.25, viewportSizeY / 1080))
		fontCache.fontSize = floor(14 * fontCache.fontSizeMultiplier)
		fontCache.paddingX = floor(fontCache.fontSize * PADDING_MULTIPLIER)
		fontCache.paddingY = fontCache.paddingX
		fontCache.initialized = true
	end

	local minimapPosX, minimapPosY, minimapSizeX = spGetMiniMapGeometry()
	local MINIMAP_GAP = 3
	
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
			
			local totalHeight = #aliveAllyTeams * (barHeight + barSpacing)
			
			local startY = minimapPosY - MINIMAP_GAP
			local currentY = startY
			
			for _, allyTeamID in ipairs(allyTeamList) do
				if isAllyTeamAlive(allyTeamID) then
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
					local adjustedBackgroundRight = exceedsMaxThreshold and actualRight or healthbarRight
					
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
					
					local healthbarScoreRight, actualRight, thresholdX = drawHealthBar(
						healthbarLeft, healthbarRight, 
						healthbarBottom, healthbarTop, 
						score, threshold, teamColor, isThresholdFrozen
					)
					
					local textX
					local textPadding = 2
					local estimatedTextWidth = fontCache.fontSize * len(tostring(difference)) * 0.7
					
					textX = thresholdX + iconSize/2 + textPadding
					
					if textX > healthbarScoreRight then
						textX = thresholdX - iconSize/2 - textPadding - estimatedTextWidth
						
						if textX < healthbarLeft then
							textX = thresholdX + iconSize/2 + textPadding
						end
					end
					
					local verticalOffset = -3
					local textY = healthbarBottom + (healthbarTop - healthbarBottom) / 2 + verticalOffset
					
					drawDifferenceText(textX, textY, difference, fontCache.fontSize, textColor)
					
					currentY = healthbarBottom - barSpacing
				end
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
			local adjustedBackgroundRight = exceedsMaxThreshold and actualRight or healthbarRight
			
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
				
				local healthbarScoreRight, actualRight, thresholdX = drawHealthBar(
					healthbarLeft, healthbarRight, 
					healthbarBottom, healthbarTop, 
					score, threshold, barColor, isThresholdFrozen
				)
				
				local textX
				local textPadding = 2
				local estimatedTextWidth = fontCache.fontSize * len(tostring(difference)) * 0.7
				
				textX = thresholdX + iconSize/2 + textPadding
				
				if textX > healthbarScoreRight then
					textX = thresholdX - iconSize/2 - textPadding - estimatedTextWidth
					
					if textX < healthbarLeft then
						textX = thresholdX + iconSize/2 + textPadding
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
	
	if isSkullFaded or (isThresholdFrozen and timeUntilUnfreeze <= WARNING_SECONDS) then
		updateScoreDisplayList()
	end
	
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