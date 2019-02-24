
function widget:GetInfo()
return {
	name    = "Changelog Info",
	desc    = "Leftmouse: scroll down,  Rightmouse: scroll up,  ctrl/shift/alt combi: speedup)",
	author  = "Floris",
	date    = "August 2015",
	layer   = -99990,
	enabled = true,
}
end

--local show = true

local loadedFontSize = 32
local font = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", loadedFontSize, 16,2)

local bgcorner = "LuaUI/Images/bgcorner.png"

local changelogFile = VFS.LoadFile("changelog.txt")

local bgMargin = 6

local closeButtonSize = 30
local screenHeight = 520-bgMargin-bgMargin
local screenWidth = 1050-bgMargin-bgMargin

local textareaMinLines = 10		-- wont scroll down more, will show at least this amount of lines

local playSounds = true
local buttonclick = 'LuaUI/Sounds/buildbar_waypoint.wav'

local customScale = 1

local startLine = 1

local vsx,vsy = Spring.GetViewGeometry()
local screenX = (vsx*0.5) - (screenWidth/2)
local screenY = (vsy*0.5) + (screenHeight/2)
  
local spIsGUIHidden = Spring.IsGUIHidden
local showHelp = false

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glText = gl.Text
local glShape = gl.Shape
local glGetTextWidth = gl.GetTextWidth
local glGetTextHeight = gl.GetTextHeight

local bgColorMultiplier = 0

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local GL_FILL = GL.FILL
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_LINE_STRIP = GL.LINE_STRIP

local widgetScale = 1
local vsx, vsy = Spring.GetViewGeometry()

local versions = {}
local changelogLines = {}
local totalChangelogLines = 0

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	screenX = (vsx*0.5) - (screenWidth/2)
	screenY = (vsy*0.5) + (screenHeight/2)
	widgetScale = (0.5 + (vsx*vsy / 5700000)) * customScale
	if changelogList then gl.DeleteList(changelogList) end
	changelogList = gl.CreateList(DrawWindow)
end

local myTeamID = Spring.GetMyTeamID()

local showOnceMore = false		-- used because of GUI shader delay

local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl)
	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)
	
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.07		-- texture offset, because else gaps could show
	
	-- bottom left
	if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl)
	gl.Texture(false)
end


local versionOffsetX = 0
local versionOffsetY = 14
local versionFontSize = 16

local versionQuickLinks = {}


function DrawSidebar(x,y,width,height)
	local fontSize		= versionFontSize
	local fontOffsetY	= versionOffsetY
	local fontOffsetX	= versionOffsetX
	
	-- background
	gl.Color(0.7,0.5,0.15,0.14)
	RectRound(x,y-height,x+width,y,2.5*widgetScale)
	
	-- version links
	versionQuickLinks = {}
	if changelogFile then
		font:Begin()
		font:SetOutlineColor(0.2,0.17,0,0.33)
		font:SetTextColor(0.8,0.65,0.15,1)
		local lineKey = 1
		local yOffset = 24
		local j = 0
		while j < 22 do	
			if ((fontSize+fontOffsetY)*j)+4 > height-yOffset then
				break;
			end
			if versions[lineKey] == nil then
				break;
			end
			local line = changelogLines[versions[lineKey]]
			
			-- version button title
			line = " " .. string.match(line, '( %d*%d.?%d+)')
			local textY = y-((fontSize+fontOffsetY)*j)-20
			font:Print(line, x+9+fontOffsetX, textY, fontSize, "on")
			
			versionQuickLinks[j] = {
				x,
				textY-(versionFontSize*0.66),
				x+70,
				textY+(versionFontSize*1.21)
			}
			
			j = j + 1
			lineKey = lineKey + 1
		end
		font:End()
	end
end


function DrawTextarea(x,y,width,height,scrollbar)
	local scrollbarOffsetTop 		= 18	-- note: wont add the offset to the bottom, only to top
	local scrollbarOffsetBottom 	= 12	-- note: wont add the offset to the top, only to bottom
	local scrollbarMargin    		= 10
	local scrollbarWidth     		= 8
	local scrollbarPosWidth  		= 4
	local scrollbarPosMinHeight 	= 8
	local scrollbarBackgroundColor	= {0,0,0,0.24}
	local scrollbarBarColor			= {1,1,1,0.08}
	
	local fontSizeTitle				= 17		-- is version number
	local fontSizeDate				= 13
	local fontSizeLine				= 15
	local lineSeparator				= 2
	
	local fontColorTitle			= {1,1,1,1}
	local fontColorDate				= {0.66,0.88,0.66,1}
	local fontColorLine				= {0.8,0.77,0.74,1}
	local fontColorLineBullet		= {0.9,0.6,0.2,1}
	
	local textRightOffset = scrollbar and scrollbarMargin+scrollbarWidth+scrollbarWidth or 0
	local maxLines = math.floor((height-5)/fontSizeLine)
	
	-- textarea scrollbar
	if scrollbar then
		if (totalChangelogLines > maxLines or startLine > 1) then	-- only show scroll above X lines
			local scrollbarTop       = y-scrollbarOffsetTop-scrollbarMargin-(scrollbarWidth-scrollbarPosWidth)
			local scrollbarBottom    = y-scrollbarOffsetBottom-height+scrollbarMargin+(scrollbarWidth-scrollbarPosWidth)
			local scrollbarPosHeight = math.max(((height-scrollbarMargin-scrollbarMargin) / totalChangelogLines) * ((height-scrollbarMargin-scrollbarMargin) / 25), scrollbarPosMinHeight)
			if scrollbarPosHeight > scrollbarTop-scrollbarBottom then scrollbarPosHeight = scrollbarTop-scrollbarBottom end
			local scrollbarPos       = scrollbarTop + (scrollbarBottom - scrollbarTop) * ((startLine-1) / totalChangelogLines)
			scrollbarPos             = scrollbarPos + ((startLine-1) / totalChangelogLines) * scrollbarPosHeight	-- correct position taking position bar height into account

			-- background
			gl.Color(scrollbarBackgroundColor)
			RectRound(
				x+width-scrollbarMargin-scrollbarWidth,
				scrollbarBottom-(scrollbarWidth-scrollbarPosWidth),
				x+width-scrollbarMargin,
				scrollbarTop+(scrollbarWidth-scrollbarPosWidth),
				scrollbarWidth/2
			)
			-- bar
			gl.Color(scrollbarBarColor)
			RectRound(
				x+width-scrollbarMargin-scrollbarWidth + (scrollbarWidth - scrollbarPosWidth),
				scrollbarPos,
				x+width-scrollbarMargin-(scrollbarWidth - scrollbarPosWidth),
				scrollbarPos - (scrollbarPosHeight),
				scrollbarPosWidth/2
			)
		end
	end
	
	-- draw textarea
	if changelogFile then
		font:Begin()
		local lineKey = startLine
		local j = 1
		while j < maxLines do	-- maxlines is not exact, just a failsafe
			if (lineSeparator+fontSizeTitle)*j > height then
				break;
			end
			if changelogLines[lineKey] == nil then
				break;
			end
			
			local line = changelogLines[lineKey]
			if string.find(line, '^([0-9][0-9][/][0-9][0-9][/][0-9][0-9])') or string.find(line, '^([0-9][/][0-9][0-9][/][0-9][0-9])') then
				-- date line
				line = "  " .. line
				font:SetTextColor(fontColorDate)
				font:Print(line, x, y-(lineSeparator+fontSizeTitle)*j, fontSizeDate, "n")
			elseif string.find(line, '^(%d*%d.?%d+)') then
				-- version line
				local versionStrip = string.match(line, '( %d*%d.?%d+)')
				if versionStrip ~= nil then
					line = " " .. versionStrip
 				else
					line = " " .. line
				end
				font:SetTextColor(fontColorTitle)
				font:Print(line, x-9, y-(lineSeparator+fontSizeTitle)*j, fontSizeTitle, "n")
				
			else
				font:SetTextColor(fontColorLine)
				if string.find(line, '^(-)') then
					-- bulletpointed line
					local firstLetterPos = 2
					if string.find(line, '^(- )') then
						firstLetterPos = 3
					end
					line = string.upper(string.sub(line, firstLetterPos, firstLetterPos))..string.sub(line, firstLetterPos+1)
					line, numLines = font:WrapText(line, (width - 40 - textRightOffset)*(loadedFontSize/fontSizeLine))
					if (lineSeparator+fontSizeTitle)*(j+numLines-1) > height then
						break;
					end
					font:Print("   - ", x, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
					font:Print(line, x+26, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
				else
					-- line
					line = "  " .. line
					line, numLines = font:WrapText(line, (width)*(loadedFontSize/fontSizeLine))
					if (lineSeparator+fontSizeTitle)*(j+numLines-1) > height then
						break;
					end
					font:Print(line, x, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
				end
				j = j + (numLines - 1)
			end

			j = j + 1
			lineKey = lineKey + 1
		end
		font:End()
	end
end


function DrawWindow()
    local vsx,vsy = Spring.GetViewGeometry()
    local x = screenX --rightwards
    local y = screenY --upwards
	
	-- background
    gl.Color(0,0,0,0.8)
	RectRound(x-bgMargin,y-screenHeight-bgMargin,x+screenWidth+bgMargin,y+bgMargin,8, 0,1,1,1)
	-- content area
	gl.Color(0.33,0.33,0.33,0.15)
	RectRound(x,y-screenHeight,x+screenWidth,y,6)
	
	-- close button
	local size = closeButtonSize*0.7
	local width = size*0.055
  gl.Color(1,1,1,1)
	gl.PushMatrix()
		gl.Translate(screenX+screenWidth-(closeButtonSize/2),screenY-(closeButtonSize/2),0)
  	gl.Rotate(-45,0,0,1)
  	gl.Rect(-width,size/2,width,-size/2)
  	gl.Rotate(90,0,0,1)
  	gl.Rect(-width,size/2,width,-size/2)
	gl.PopMatrix()
	
	-- title
    local title = "Changelog"
	local titleFontSize = 18
    gl.Color(0,0,0,0.8)
    titleRect = {x-bgMargin, y+bgMargin, x+(glGetTextWidth(title)*titleFontSize)+27-bgMargin, y+37}
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 8, 1,1,0,0)
	font:Begin()
	font:SetTextColor(1,1,1,1)
	font:SetOutlineColor(0,0,0,0.4)
	font:Print(title, x-bgMargin+(titleFontSize*0.75), y+bgMargin+8, titleFontSize, "on")
	font:End()
	
	-- version links
	DrawSidebar(x, y, 70, screenHeight)
	
	-- textarea
	DrawTextarea(x+90, y-10, screenWidth-90, screenHeight-24, 1)
end


function widget:DrawScreen()
  if spIsGUIHidden() then return end
  
  -- draw the help
  if not changelogList then
      changelogList = gl.CreateList(DrawWindow)
  end
  
  if show or showOnceMore then
    
		-- draw the changelog panel
		glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(changelogList)
		glPopMatrix()
		if (WG['guishader_api'] ~= nil) then
			local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'changelog')
			--WG['guishader_api'].setBlurIntensity(0.0017)
			--WG['guishader_api'].setScreenBlur(true)
		end
		showOnceMore = false
		
		-- draw button hover
		local usedScreenX = (vsx*0.5) - ((screenWidth/2)*widgetScale)
		local usedScreenY = (vsy*0.5) + ((screenHeight/2)*widgetScale)

		local x,y,pressed = Spring.GetMouseState()
		if changelogFile then
			local lineKey = 1
			local j = 0
			local yOffset = 24
			local yOffsetUp = (((versionFontSize*0.66)+yOffset)*widgetScale)
			local yOffsetDown = (((versionFontSize*1.21)-yOffset)*widgetScale)
			while j < 22 do	
				if ((versionFontSize+versionOffsetY)*j)+4 > (screenHeight-yOffset) then
					break;
				end
				if versions[lineKey] == nil then
					break;
				end
				if versionQuickLinks[j] == nil then
					break;
				end
				
				--local cc = (versionQuickLinks[j][1]/vsx) * vsx/widgetScale
				--Spring.Echo(usedScreenX..'  '..versionQuickLinks[j][1]..'  '..cc)
				
				-- version title
				local textX = usedScreenX-((10+versionOffsetX)*widgetScale)
				local textY = usedScreenY-((((versionFontSize+versionOffsetY)*j)-5)*widgetScale)
				local x1 = usedScreenX
				local y1 = textY-yOffsetUp
				local x2 = usedScreenX+(70*widgetScale)
				local y2 = textY+yOffsetDown
				if IsOnRect(x, y, x1, y1, x2, y2) then
					if pressed then
						gl.Color(1,0.93,0.75,0.23)
					else
						gl.Color(1,0.93,0.75,0.15)
					end
					RectRound(x1, y1, x2, y2, 3*widgetScale)
					break;
				end
				j = j + 1
				lineKey = lineKey + 1
			end
		end
  else
	if (WG['guishader_api'] ~= nil) then
		local removed = WG['guishader_api'].RemoveRect('changelog')
		if removed then
			--WG['guishader_api'].setBlurIntensity()
			WG['guishader_api'].setScreenBlur(false)
		end
	end
  end
end

function widget:KeyPress(key)
	if key == 27 then	-- ESC
		show = false
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	
	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end

--function widget:IsAbove(x, y)
--	-- on window
--	if show then
--		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
--		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
--		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
--		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
--		return IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1)
--	else
--		return false
--	end
--end
--
--function widget:GetTooltip(mx, my)
--	if show and widget:IsAbove(mx,my) then
--		return string.format(
--			"\255\255\255\1Left mouse\255\255\255\255 on textarea to scroll down.\n"..
--			"\255\255\255\1Right mouse\255\255\255\255 on textarea  to scroll up.\n\n"..
--			"Add CTRL or SHIFT to scroll faster, or combine CTRL+SHIFT (+ALT).")
--	end
--end

function widget:MouseWheel(up, value)
	
	if show then	
		local addLines = value*-3 -- direction is retarded
		
		startLine = startLine + addLines
		if startLine < 1 then startLine = 1 end
		if startLine > totalChangelogLines - textareaMinLines then startLine = totalChangelogLines - textareaMinLines end
		
		if changelogList then
			glDeleteList(changelogList)
		end
		
		changelogList = gl.CreateList(DrawWindow)
		return true
	else
		return false
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function mouseEvent(x, y, button, release)
  if spIsGUIHidden() then return end
  
  if show then 
		-- on window
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
		
			-- on close button
			local brectX1 = rectX2 - ((closeButtonSize+bgMargin+bgMargin) * widgetScale)
			local brectY2 = rectY1 - ((closeButtonSize+bgMargin+bgMargin) * widgetScale)
			if IsOnRect(x, y, brectX1, brectY2, rectX2, rectY1) then
				if release then
					showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
					show = not show
				end
				return true
			end
			
			--[[ scroll text with mouse 2
			if button == 1 or button == 3 then
				if IsOnRect(x, y, rectX1+(90*widgetScale), rectY2, rectX2, rectY1) then
					if release then
						local alt, ctrl, meta, shift = Spring.GetModKeyState()
						local addLines = 3
						
						if ctrl or shift then 
							addLines = 8
						end
						if ctrl and shift then 
							addLines = 22
						end
						if ctrl and shift and alt then 
							addLines = 66
						end
						if button == 3 then 
							addLines = -addLines
						end
						startLine = startLine + addLines
						if startLine < 1 then startLine = 1 end
						if startLine > totalChangelogLines - textareaMinLines then startLine = totalChangelogLines - textareaMinLines end
						
						if changelogList then
							glDeleteList(changelogList)
						end
						changelogList = gl.CreateList(DrawWindow)
					end
					return true
				end
			end]]--
			
			-- version buttons
			if button == 1 and release then
				local yOffset = 24
				local usedScreenX = (vsx*0.5) - ((screenWidth/2)*widgetScale)
				local usedScreenY = (vsy*0.5) + ((screenHeight/2)*widgetScale)
				
				local x,y = Spring.GetMouseState()
				if changelogFile then
					local lineKey = 1
					local j = 0
					while j < 25 do	
						if (versionFontSize+versionOffsetY)*j > (screenHeight-yOffset) then
							break;
						end
						if versions[lineKey] == nil then
							break;
						end
						
						-- version title
						local textX = usedScreenX-((10+versionOffsetX)*widgetScale)
						local textY = usedScreenY-((((versionFontSize+versionOffsetY)*j)-5)*widgetScale)
						
						local x1 = usedScreenX
						local y1 = textY-(((versionFontSize*0.66)+yOffset)*widgetScale)
						local x2 = usedScreenX+((70*widgetScale))
						local y2 = textY+(((versionFontSize*1.21)-yOffset)*widgetScale)
						if IsOnRect(x, y, x1, y1, x2, y2) then
							startLine = versions[lineKey]
							if changelogList then
								glDeleteList(changelogList)
							end
							changelogList = gl.CreateList(DrawWindow)
							if playSounds then
								Spring.PlaySoundFile(buttonclick, 0.6, 'ui')
							end
							break;
						end
						
						j = j + 1
						lineKey = lineKey + 1
					end
				end
				return true
			end
			
			if button == 1 or button == 3 then
				return true
			end
		elseif titleRect == nil or not IsOnRect(x, y, (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2), (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)) then
			if release then
				showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
				show = false
			end
			return true
		end
	end
end

function lines(str)
  local t = {}
  local function helper(line) t[#t+1] = line return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function widget:Initialize()
	if changelogFile then

		WG['changelog'] = {}
		WG['changelog'].toggle = function(state)
			if state ~= nil then
				show = state
			else
				show = not show
			end
		end
		WG['changelog'].isvisible = function()
			return show
		end
	
		-- somehow there are a few characters added at the start that we need to remove
		changelogFile = string.sub(changelogFile, 4)
		
		-- store changelog into array
		changelogLines = lines(changelogFile)
		
		local versionKey = 0
		local insertedLatest = false
		for i, line in ipairs(changelogLines) do
		
			if insertedLatest == false or string.find(line, '^(%d*%d.?%d+ [/-]> %d*%d.[0-9]0)$') or  string.find(line, '^(%d*%d.?%d+ [/-]> %d*%d.[0-9])$') then
			--if string.find(line, '^(%d*%d.?%d+ [/-]> )') then
				versionKey = versionKey + 1
				versions[versionKey] = i
				insertedLatest = true
			end
			totalChangelogLines = i
		end
		
	else
		Spring.Echo("Changelog: couldn't load the changelog file")
		widgetHandler:RemoveWidget(self)
	end
end

function widget:Shutdown()
    if buttonGL then
        glDeleteList(buttonGL)
        buttonGL = nil
    end
    if changelogList then
        glDeleteList(changelogList)
        changelogList = nil
    end
end
