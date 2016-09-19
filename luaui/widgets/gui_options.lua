
function widget:GetInfo()
return {
	name    = "Options",
	desc    = "",
	author  = "Floris",
	date    = "September 2016",
	license = "Dental flush",
	layer   = -1,
	enabled = true,
}
end

--local show = true

local loadedFontSize = 32
local font = gl.LoadFont(LUAUI_DIRNAME.."Fonts/FreeSansBold.otf", loadedFontSize, 16,2)

local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local bgcorner1 = ":n:"..LUAUI_DIRNAME.."Images/bgcorner1.png"
local closeButtonTex = ":n:"..LUAUI_DIRNAME.."Images/close.dds"

local bgMargin = 6

local closeButtonSize = 30
local screenHeight = 520-bgMargin-bgMargin
local screenWidth = 1050-bgMargin-bgMargin

local textareaMinLines = 10		-- wont scroll down more, will show at least this amount of lines 

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
local glTexRect = gl.TexRect
local glRotate = gl.Rotate
local glTexture = gl.Texture
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

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
local gameStarted = (Spring.GetGameFrame()>0)

local options = {}
local optionButtons = {}
local optionHover = {}
local optionSelect = {}
local checkedCursorsets = false


function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  screenX = (vsx*0.5) - (screenWidth/2)
  screenY = (vsy*0.5) + (screenHeight/2)
  widgetScale = (0.75 + (vsx*vsy / 7500000)) * customScale
  if windowList then gl.DeleteList(windowList) end
  windowList = gl.CreateList(DrawWindow)
end

function widget:GameStart()
	gameStarted = true
end

-- button
local textSize		= 0.75
local textMargin	= 0.25
local lineWidth		= 0.0625

local posX = 0.15
local posY = 0
local showOnceMore = false		-- used because of GUI shader delay
local buttonGL
local startPosX = posX

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
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl)
	gl.Texture(false)
end

function DrawButton()
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	RectRound(0,0,4.5,1.05,0.25, 2,2,0,0)
	local vertices = {
		{v = {0, 1, 0}},
		{v = {0, 0, 0}},
		{v = {1, 0, 0}},
	}
	glShape(GL_LINE_STRIP, vertices)
  glText("Options", textMargin, textMargin, textSize, "no")
end


function DrawWindow()
	if not checkedCursorsets then
		checkedCursorsets = true
		local cursorsets = {}
		local cursor = 1
		local cursoroption
		if (WG['cursors'] ~= nil) then
			cursorsets = WG['cursors'].getcursorsets()
			local cursorname = WG['cursors'].getcursor()
			for i,c in pairs(cursorsets) do
				if c == cursorname then
					cursor = i
					break
				end
			end
			table.insert(options, {id="cursor", name="Cursor", type="select", options=cursorsets, value=cursor})
		end
	end
	
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
  gl.Color(1,1,1,1)
	gl.Texture(closeButtonTex)
	gl.TexRect(screenX+screenWidth-closeButtonSize,screenY,screenX+screenWidth,screenY-closeButtonSize)
	gl.Texture(false)
	
	-- title
  local title = "Options"
	local titleFontSize = 18
  gl.Color(0,0,0,0.8)
  titleRect = {x-bgMargin, y+bgMargin, x+(glGetTextWidth(title)*titleFontSize)+27-bgMargin, y+37}
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 8, 1,1,0,0)
	
	font:Begin()
	font:SetTextColor(1,1,1,1)
	font:SetOutlineColor(0,0,0,0.4)
	font:Print(title, x-bgMargin+(titleFontSize*0.75), y+bgMargin+8, titleFontSize, "on")
	font:End()
	
	local width = screenWidth/3
	gl.Color(0.66,0.66,0.66,0.08)
	RectRound(x+width+width+6,y-screenHeight,x+width+width+width,y,6)
	
	-- description
	gl.Color(0.72,0.5,0.12,0.14)
	RectRound(x,y-screenHeight,x+width+width,y-screenHeight+90,6)
	--glText('\255\255\210\120'..description, screenX+15, screenY-screenHeight+64.5, 16, "no")
  	
	-- draw options
	local oHeight = 15
	local oPadding = 7
	y = y - oPadding - 11
	local oWidth = (screenWidth/3)-oPadding-oPadding
	local yHeight = screenHeight-102-oPadding
	local xPos = x + oPadding + 5
	local xPosMax = xPos + oWidth - oPadding - oPadding
	local yPosMax = y-yHeight
	local boolPadding = 3.5
	local boolWidth = 40
	local sliderWidth = 110
	local selectWidth = 140
	local i = 0
	optionButtons = {}
	optionHover = {}
	for oid,option in pairs(options) do
		yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
		if yPos-oHeight < yPosMax then
			i = 0
			xPos = x + 10 + oPadding + (screenWidth/3)
			xPosMax = xPos + oWidth - oPadding - oPadding
			yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
			gl.Color(0,0,0,0.25)
			RectRound(xPos-oPadding-8-2.5,y-screenHeight+118,xPos-oPadding-8+2.5,y,2)
		end
		
		--option name
  	glText('\255\230\230\230'..option.name, xPos, yPos-(oHeight/3)-oPadding, oHeight, "no")
  	
  	-- define hover area
		optionHover[oid] = {xPos, yPos-oHeight-oPadding, xPosMax, yPos+oPadding}
			
  	-- option controller
  	if option.type == 'bool' then
			optionButtons[oid] = {}
			optionButtons[oid] = {xPosMax-boolWidth, yPos-oHeight, xPosMax, yPos}
			glColor(1,1,1,0.11)
			RectRound(xPosMax-boolWidth, yPos-oHeight, xPosMax, yPos, 3)
			if option.value == true then
				glColor(0.66,0.92,0.66,1)
				RectRound(xPosMax-oHeight+boolPadding, yPos-oHeight+boolPadding, xPosMax-boolPadding, yPos-boolPadding, 2.5)
			else
				glColor(0.92,0.66,0.66,1)
				RectRound(xPosMax-boolWidth+boolPadding, yPos-oHeight+boolPadding, xPosMax-boolWidth+oHeight-boolPadding, yPos-boolPadding, 2.5)
			end
		
		elseif option.type == 'slider' then
			local sliderSize = oHeight*0.75
			local sliderPos = (option.value-option.min) / (option.max-option.min)
			glColor(1,1,1,0.11)
			RectRound(xPosMax-(sliderSize/2)-sliderWidth, yPos-((oHeight/7)*4.2), xPosMax-(sliderSize/2), yPos-((oHeight/7)*2.8), 1)
			glColor(0.8,0.8,0.8,1)
			RectRound(xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)-(sliderSize/2), yPos-oHeight+((oHeight-sliderSize)/2), xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)+(sliderSize/2), yPos-((oHeight-sliderSize)/2), 3)
			optionButtons[oid] = {xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)-(sliderSize/2), yPos-oHeight+((oHeight-sliderSize)/2), xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)+(sliderSize/2), yPos-((oHeight-sliderSize)/2)}
			optionButtons[oid].sliderXpos = {xPosMax-(sliderSize/2)-sliderWidth, xPosMax-(sliderSize/2)}
			
		elseif option.type == 'select' then
			optionButtons[oid] = {xPosMax-selectWidth, yPos-oHeight, xPosMax, yPos}
			glColor(1,1,1,0.11)
			RectRound(xPosMax-selectWidth, yPos-oHeight, xPosMax, yPos, 3)
  		glText(option.options[tonumber(option.value)], xPosMax-selectWidth+5, yPos-(oHeight/3)-oPadding, oHeight*0.85, "no")
			glColor(1,1,1,0.11)
			RectRound(xPosMax-oHeight, yPos-oHeight, xPosMax, yPos, 2.5)
			glColor(1,1,1,0.16)
			glTexture(bgcorner1)
 			glPushMatrix()
   			glTranslate(xPosMax-(oHeight*0.5), yPos-(oHeight*0.33), 0)
				glRotate(-45,0,0,1)
				glTexRect(-(oHeight*0.25),-(oHeight*0.25),(oHeight*0.25),(oHeight*0.25))
 	 		glPopMatrix()
		end
		i = i + 1
	end
end


function correctMouseForScaling(x,y)
	local interfaceScreenCenterPosX = (screenX+(screenWidth/2))/vsx
	local interfaceScreenCenterPosY = (screenY-(screenHeight/2))/vsy
	x = x - (((x/vsx)-interfaceScreenCenterPosX) * vsx)*((widgetScale-1)/widgetScale)
	y = y - (((y/vsy)-interfaceScreenCenterPosY) * vsy)*((widgetScale-1)/widgetScale)
	return x,y
end


function widget:DrawScreen()

  if spIsGUIHidden() then return end
  if amNewbie and not gameStarted then return end
  
  -- draw the button
  if not buttonGL then
    buttonGL = gl.CreateList(DrawButton)
  end
  
  glLineWidth(lineWidth)

  glPushMatrix()
    glTranslate(posX*vsx, posY*vsy, 0)
    glScale(17*widgetScale, 17*widgetScale, 1)
		glColor(0, 0, 0, (0.3*bgColorMultiplier))
    glCallList(buttonGL)
  glPopMatrix()

  glColor(1, 1, 1, 1)
  glLineWidth(1)
  
  	
  -- draw the window
  if not windowList then
    windowList = gl.CreateList(DrawWindow)
  end
  
  -- update new slider value
	if sliderValueChanged then
		gl.DeleteList(windowList)
		windowList = gl.CreateList(DrawWindow)
		sliderValueChanged = nil
  end
  
  if show or showOnceMore then
  	
		-- draw the options panel
		glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(windowList)
			if (WG['guishader_api'] ~= nil) then
				local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
				local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
				local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
				local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
				WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'options')
			end
			showOnceMore = false
			
			-- draw button hover
			local usedScreenX = (vsx*0.5) - ((screenWidth/2)*widgetScale)
			local usedScreenY = (vsy*0.5) + ((screenHeight/2)*widgetScale)
			
			-- mouseover (highlight and tooltip)
		  local description = ''
			local x,y = Spring.GetMouseState()
			local cx, cy = correctMouseForScaling(x,y)
			for i, o in pairs(optionHover) do
				if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
					glColor(1,1,1,0.05)
					RectRound(o[1]-8, o[2], o[3]+8, o[4], 4)
					if options[i].description ~= nil then
						glText('\255\255\210\120'..options[i].description, screenX+15, screenY-screenHeight+64.5, 16, "no")
					end
				end
			end
			for i, o in pairs(optionButtons) do
				if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
					glColor(1,1,1,0.08)
					RectRound(o[1], o[2], o[3], o[4], 2.5)
				end
			end
			
			-- draw select options
			if showSelectOptions ~= nil then
				local oHeight = optionButtons[showSelectOptions][4] - optionButtons[showSelectOptions][2]
				local oPadding = 4
				y = optionButtons[showSelectOptions][4] -oPadding
				local yPos = y
				--Spring.Echo(oHeight)
				optionSelect = {}
				for i, option in pairs(options[showSelectOptions].options) do
					yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
				end
				glColor(0.22,0.22,0.22,0.85)
				RectRound(optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 4)
				glColor(1,1,1,0.07)
				RectRound(optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 4)
				for i, option in pairs(options[showSelectOptions].options) do
					yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
					if IsOnRect(cx, cy, optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding) then
						glColor(1,1,1,0.1)
						RectRound(optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding, 4)
					end
					table.insert(optionSelect, {optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding, i})
					glText('\255\255\255\255'..option, optionButtons[showSelectOptions][1]+7, yPos-(oHeight/2.25)-oPadding, oHeight*0.85, "no")
				end
			end
		glPopMatrix()
	else
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].RemoveRect('options')
		end
	end
end


function applyOptionValue(i)
	local id = options[i].id
	if options[i].type == 'bool' then
		options[i].value = not options[i].value
		local value = 0
		if options[i].value then
			value = 1
		end
		if id == 'advmapshading' then
			Spring.SendCommands("AdvMapShading "..value)
		elseif id == 'advmodelshading' then
			Spring.SendCommands("AdvModelShading "..value)
		elseif id == 'advsky' then
			Spring.SetConfigInt("AdvSky",value)
		elseif id == 'shadows' then
			Spring.SendCommands("Shadows "..value)
		elseif id == 'highresLos' then
			Spring.SetConfigInt("HighResLos",value)
		elseif id == 'fullscreen' then
			Spring.SendCommands("Fullscreen "..value)
		elseif id == 'borderless' then
			Spring.SendCommands("WindowBorderless "..value)
		elseif id == 'screenedgemove' then
			Spring.SetConfigInt("FullscreenEdgeMove",value)
			Spring.SetConfigInt("WindowedEdgeMove",value)
		elseif id == 'hwcursor' then
			Spring.SendCommands("hardwareCursor "..value)
		elseif id == 'fps' then
			Spring.SendCommands("fps "..value)
		elseif id == 'time' then
			Spring.SendCommands("clock "..value)
		elseif id == 'gamespeed' then
			Spring.SendCommands("speed "..value)
		end
	
	elseif options[i].type == 'slider' then
		local value =  options[i].value
		if id == 'fsaa' then
			Spring.SetConfigInt("FSAALevel ",value)
		elseif id == 'decals' then
			Spring.SendCommands("GroundDecals "..value)
		elseif id == 'scrollspeed' then
			Spring.SetConfigInt("ScrollWheelSpeed ",value)
		elseif id == 'disticon' then
			--Spring.SetConfigInt("UnitIconDist "..value)
			Spring.SendCommands("disticon "..value)
		elseif id == 'treeradius' then
			Spring.SetConfigInt("TreeRadius ",value)
		elseif id == 'particles' then
			Spring.SetConfigInt("MaxParticles ",value)
		elseif id == 'nanoparticles' then
			Spring.SetConfigInt("MaxNanoParticles ",value)
		elseif id == 'grassdetail' then
			Spring.SetConfigInt("GrassDetail ",value)
		elseif id == 'grounddetail' then
			--Spring.SetConfigInt("GroundDetail "..value)
			Spring.SendCommands("grounddetail "..value)
		elseif id == 'sndvolmaster' then
			Spring.SetConfigInt("snd_volmaster", value)
		end
		
	elseif options[i].type == 'select' then
		local value =  options[i].value
		if id == 'water' then
			Spring.SendCommands("water "..(value-1))
		elseif id == 'camera' then
			Spring.SetConfigInt("CamMode ",value)
			if value == 1 then 
				Spring.SendCommands('viewfps')
			elseif value == 2 then 
				Spring.SendCommands('viewta')
			elseif value == 3 then 
				Spring.SendCommands('viewspring')
			elseif value == 4 then 
				Spring.SendCommands('viewrot')
			elseif value == 5 then 
				Spring.SendCommands('viewfree')
			end
		elseif id == 'cursor' then
			WG['cursors'].setcursor(options[i].options[value])
			--Spring.SendCommands("cursor "..options[i].options[value])
		end
	end
	
	if windowList then gl.DeleteList(windowList) end
	windowList = gl.CreateList(DrawWindow)
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	
	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end

function widget:IsAbove(x, y)
	-- on window
	if show then
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		return IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1)
	else
		return false
	end
end

function widget:GetTooltip(mx, my)
	if show and widget:IsAbove(mx,my) then
		return string.format(
			"")
	end
end

function getSliderValue(draggingSlider, cx)
	local sliderWidth = optionButtons[draggingSlider].sliderXpos[2] - optionButtons[draggingSlider].sliderXpos[1]
	local value = (cx - optionButtons[draggingSlider].sliderXpos[1]) / sliderWidth
	value = options[draggingSlider].min + ((options[draggingSlider].max - options[draggingSlider].min) * value)
	if value < options[draggingSlider].min then value = options[draggingSlider].min end
	if value > options[draggingSlider].max then value = options[draggingSlider].max end
	if options[draggingSlider].step ~= nil then
		value = math.floor((value / options[draggingSlider].step)+0.5) * options[draggingSlider].step
	end
	return value
end

function widget:MouseWheel(up, value)
	local x,y = Spring.GetMouseState()
	local cx, cy = correctMouseForScaling(x,y)
	if show then	
		return true
	end
end

function widget:MouseMove(x, y)
	if draggingSlider ~= nil then
		local cx, cy = correctMouseForScaling(x,y)
		options[draggingSlider].value = getSliderValue(draggingSlider,cx)
		sliderValueChanged = true
		applyOptionValue(draggingSlider)
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function mouseEvent(x, y, button, release)
	if spIsGUIHidden() then return false end
  if amNewbie and not gameStarted then return end
  
  if show then
		-- on window
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
		
			-- on option
			local cx, cy = correctMouseForScaling(x,y)
			
	 	 -- apply new slider value
			if release and draggingSlider ~= nil then
				options[draggingSlider].value = getSliderValue(draggingSlider,cx)
				applyOptionValue(draggingSlider)
				draggingSlider = nil
			end
		
			if release then
				-- select option
				if showSelectOptions ~= nil then
					for i, o in pairs(optionSelect) do
						if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
							options[showSelectOptions].value = o[5]
							applyOptionValue(showSelectOptions)
						end
					end
					if selectClickAllowHide ~= nil or not IsOnRect(cx, cy, optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4]) then
						showSelectOptions = nil
						selectClickAllowHide = nil
					else
						selectClickAllowHide = true
					end
				end
				
				for i, o in pairs(optionButtons) do
					if options[i].type == 'bool' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						applyOptionValue(i)
					elseif options[i].type == 'slider' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
					
					elseif options[i].type == 'select' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						
					end
				end
			else
				for i, o in pairs(optionButtons) do
					if options[i].type == 'slider' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						draggingSlider = i
					elseif options[i].type == 'select' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						if showSelectOptions == nil then
							showSelectOptions = i
						elseif showSelectOptions == i then
							--showSelectOptions = nil
						end
					end
				end
			end
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
			
			if button == 1 or button == 3 then
				return true
			end
		elseif titleRect == nil or not IsOnRect(x, y, (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2), (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)) then
			if release then
				showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
				show = not show
			end
		end
		
		if show then
			if windowList then gl.DeleteList(windowList) end
			windowList = gl.CreateList(DrawWindow)
		end
		
		return true
  else
		tx = (x - posX*vsx)/(17*widgetScale)
		ty = (y - posY*vsy)/(17*widgetScale)
		if tx < 0 or tx > 4.5 or ty < 0 or ty > 1.05 then return false end
		if release then
			showOnceMore = show		-- show once more because the guishader lags behind, though this will not fully fix it
			show = not show
		end
		if show then
			if windowList then gl.DeleteList(windowList) end
			windowList = gl.CreateList(DrawWindow)
		end
		return true
  end
end

function widget:Initialize()
	options = {
		{id="advmapshading", name="Advanced map shading", type="bool", value=tonumber(Spring.GetConfigInt("AdvMapShading",1) or 1) == 1, description='When disabled: shadows are disabled too'},
		{id="advmodelshading", name="Advanced model shading", type="bool", value=tonumber(Spring.GetConfigInt("AdvModelShading",1) or 1) == 1},
		{id="advsky", name="Advanced sky", type="bool", value=tonumber(Spring.GetConfigInt("AdvSky",1) or 1) == 1, description='Changes will be applied next game'},
		{id="shadows", name="Shadows", type="bool", value=tonumber(Spring.GetConfigInt("Shadows",1) or 1) == 1, description='Requires "Advanced map shading" to be enabled'},
		{id="highreslos", name="High res LOS", type="bool", value=tonumber(Spring.GetConfigInt("HighResLos",1) or 1) == 1, description='Changes will be applied next game'},
		{id="fullscreen", name="Fullscreen", type="bool", value=tonumber(Spring.GetConfigInt("Fullscreen",1) or 1) == 1},
		{id="borderless", name="Borderless", type="bool", value=tonumber(Spring.GetConfigInt("WindowBorderless",1) or 1) == 1},
		{id="screenedgemove", name="Screen edge moves camera", type="bool", value=tonumber(Spring.GetConfigInt("FullscreenEdgeMove",1) or 1) == 1, description="If mouse is close to screen edge this will move camera\n\nChanges will be applied next game"},
		{id="hwcursor", name="Hardware-cursor", type="bool", value=tonumber(Spring.GetConfigInt("hardwareCursor",1) or 1) == 1},
		{id="fps", name="Show FPS", type="bool", value=tonumber(Spring.GetConfigInt("ShowFPS",1) or 1) == 1, description='Located at the top right of the screen'},
		{id="time", name="Show time", type="bool", value=tonumber(Spring.GetConfigInt("ShowClock",1) or 1) == 1, description='Located at the top right of the screen'},
		{id="gamespeed", name="Show game speed", type="bool", value=tonumber(Spring.GetConfigInt("ShowSpeed",0) or 0) == 1, description='Located at the top right of the screen'},
		
		{id="decals", name="Ground decals", type="slider", min =0, max=5, step=1, value=tonumber(Spring.GetConfigInt("GroundDecals",1) or 1), description='Set how much/duration map decals will be drawn\n\n(unit footsteps/tracks, darkening under buildings and scorns ground at explosions)'},
		{id="fsaa", name="Anti Aliasing", type="slider", min=0, max=16, step=1, value=tonumber(Spring.GetConfigInt("FSAALevel",1) or 2), description='Changes will be applied next game'},
		{id="scrollspeed", name="Scrollwheel speed", type="slider", min=10, max=40, step=1, value=tonumber(Spring.GetConfigInt("ScrollWheelSpeed",1) or 25), description='Changes will be applied next game'},
		{id="disticon", name="Unit icon distance", type="slider", min=0, max=1000, value=tonumber(Spring.GetConfigInt("UnitIconDist",1) or 1000)},
		{id="treeradius", name="Tree render distance", type="slider", min=0, max=2000, value=tonumber(Spring.GetConfigInt("TreeRadius",1) or 1000)},
		{id="particles", name="Max particles", type="slider", min=1000, max=6000, value=tonumber(Spring.GetConfigInt("MaxParticles",1) or 1000), description='Changes will be applied next game'},
		{id="nanoparticles", name="Max nano particles", type="slider", min=500, max=6000, value=tonumber(Spring.GetConfigInt("MaxNanoParticles",1) or 500), description='Changes will be applied next game'},
		{id="grassdetail", name="Grass", type="slider", min=0, max=10, step=1, value=tonumber(Spring.GetConfigInt("GrassDetail",1) or 5), description='Amount of grass displayed\n\nChanges will be applied next game'},
		{id="grounddetail", name="Ground mesh detail", type="slider", min=50, max=200, value=tonumber(Spring.GetConfigInt("GroundDetail",1) or 60), description='Ground mesh detail (amount of polygons)'},
		{id="sndvolmaster", name="Sound volume", type="slider", min=0, max=200, value=tonumber(Spring.GetConfigInt("snd_volmaster",1) or 100)},
		
		{id="water", name="Water type", type="select", options={'basic','reflective','reflective&refractive','dynamic','bump-mapped'}, value=(tonumber(Spring.GetConfigInt("Water",1) or 1)+1)},
		{id="camera", name="Camera", type="select", options={'fps','overhead','spring','rot overhead','free'}, value=(tonumber(Spring.GetConfigInt("CamMode",1) or 2))},
	}
	
	for oid,option in pairs(options) do
		if option.type == 'slider' then
			if option.value < option.min then option.value = option.min end
			if option.value > option.max then option.value = option.max end
		end
	end
end

function widget:Shutdown()
    if buttonGL then
        glDeleteList(buttonGL)
        buttonGL = nil
    end
    if windowList then
        glDeleteList(windowList)
        windowList = nil
    end
end
