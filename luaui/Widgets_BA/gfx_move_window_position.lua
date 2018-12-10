
local widgetName = "Move Window Position"
function widget:GetInfo()
	return {
		name	= widgetName,
		desc	= "Move around window position with the arrow keys or by dragging",
		author	= "Floris",
		date	= "August 2018",
		license	= "GPL v2 or later",
		layer	= -math.huge,
		enabled	= false,
		handler = true,
	}
end

local vsx, vsy = gl.GetViewSizes()
local customScale = 1.2
local widgetScale = (1 + (vsx*vsy / 4000000)) * customScale

local windowPosX = tonumber(Spring.GetConfigInt("WindowPosX",1) or 0)
local windowPosY = tonumber(Spring.GetConfigInt("WindowPosY",1) or 0)
local initialWindowPosX = windowPosX
local initialWindowPosY = windowPosY
local dlistPosX = windowPosX
local dlistPosY = windowPosY

local bgcorner = "LuaUI/Images/bgcorner.png"

local function DrawRectRound(px,py,sx,sy,cs)

	local csx = cs
	local csy = cs
	if sx-px < (cs*2) then
		csx = (sx-px)/2
		if csx < 0 then csx = 0 end
	end
	if sy-py < (cs*2) then
		csy = (sy-py)/2
		if csy < 0 then csy = 0 end
	end
	cs = math.min(csx, csy)

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

	local offset = 0.05		-- texture offset, because else gaps could show
	local o = offset

	-- top left
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)

	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end

function DrawWindow()
	dlistPosX = windowPosX
	dlistPosY = windowPosY
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(0,0,vsx,vsy, 'movewindowpos')
		WG['guishader_api'].setScreenBlur(true)
	end
	gl.Color(0,0,0,0.6)
	gl.Rect(0,0,vsx,vsy)
	gl.Text("\255\200\200\200Move window position with the arrow keys or drag it with the mouse\n(change will be applied after mouse-release).", vsx/2, (vsy/2)+(40*widgetScale), 12*widgetScale, "ocn")
	gl.Text("\255\222\255\222x = "..windowPosX.."     y = "..windowPosY, vsx/2, (vsy/2), 14*widgetScale, "ocn")
	local buttonText = '   Apply   '
	local buttonX = vsx/2
	local buttonY = (vsy/2)-(36*widgetScale)
	local buttonFontsize = 15*widgetScale
	local buttonWidth = gl.GetTextWidth(buttonText)*buttonFontsize
	local buttonHeight = buttonFontsize*2.2
	gl.Text("\255\200\200\200ESCAPE key will cancel changes", vsx/2, (vsy/2)-(50*widgetScale)-buttonHeight, 12*widgetScale, "ocn")
	if initialWindowPosX ~= dlistPosX or initialWindowPosY ~= dlistPosY then
		applyButtonPos = {buttonX-(buttonWidth/2), buttonY-(buttonHeight/2), buttonX+(buttonWidth/2), buttonY+(buttonHeight/2),buttonFontsize/5}
		gl.Color(0,0.33,0,0.8)
		RectRound(applyButtonPos[1],applyButtonPos[2],applyButtonPos[3],applyButtonPos[4],applyButtonPos[5])
		local padding = 2*widgetScale
		gl.Color(1,1,1,0.1)
		RectRound(applyButtonPos[1]+padding,applyButtonPos[2]+padding,applyButtonPos[3]-padding,applyButtonPos[4]-padding,applyButtonPos[5]*0.66)
		gl.Text("\255\200\255\200"..buttonText, buttonX, buttonY-(buttonFontsize*0.27), buttonFontsize, "ocn")
	else
		applyButtonPos = nil
	end
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = (1 + (vsx*vsy / 4000000)) * customScale
	if windowList then gl.DeleteList(windowList) end
	windowList = gl.CreateList(DrawWindow)
end

function widget:Initialize()
	widget:ViewResize()
end

function widget:Update(dt)
	if (changeClock and changeClock < os.clock()-0.7) or escape or applyChanges then
		if changeClock then
			Spring.SetConfigInt("WindowPosX", windowPosX)
			Spring.SetConfigInt("WindowPosY", windowPosY)
			Spring.SendCommands("Fullscreen 1")		--tonumber(Spring.GetConfigInt("Fullscreen",1) or 1)
			Spring.SendCommands("Fullscreen 0")
			changeClock = nil
		end
		if applyChanges then
			widgetHandler:DisableWidget(widgetName)
		end
		if escape then
			if initialWindowPosX ~= dlistPosX or initialWindowPosY ~= dlistPosY then
				Spring.SetConfigInt("WindowPosX", initialWindowPosX)
				Spring.SetConfigInt("WindowPosY", initialWindowPosY)
				Spring.SendCommands("Fullscreen 1")		--tonumber(Spring.GetConfigInt("Fullscreen",1) or 1)
				Spring.SendCommands("Fullscreen 0")
			end
			widgetHandler:DisableWidget(widgetName)
		end
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function widget:MousePress(x, y, button)
	if applyButtonPos and IsOnRect(x, y, applyButtonPos[1],applyButtonPos[2],applyButtonPos[3],applyButtonPos[4]) then
		applyChanges = true
		return true
	end
	dragging = true
	draggingStartX = x
	draggingStartY = y
	return true
end

function widget:MouseRelease(x, y, button)
	if dragging then
		dragging = nil
		windowPosX = windowPosX + (x-draggingStartX)
		windowPosY = windowPosY + (draggingStartY-y)
		if initialWindowPosX ~= dlistPosX or initialWindowPosY ~= dlistPosY then
			changeClock = os.clock()-1
		end
	end
	return true
end

function widget:MouseMove(x, y)
	windowPosX = windowPosX + (x-draggingStartX)
	windowPosY = windowPosY + (draggingStartY-y)
	draggingStartX = x
	draggingStartY = y
	if dlistPosX ~= windowPosX or dlistPosY ~= windowPosY then
		if windowList then gl.DeleteList(windowList) end
		windowList = gl.CreateList(DrawWindow)
	end
	return true
end

function widget:KeyPress(key)
	if key == 27 then	-- ESC
		escape = true
	end
	if key == 273 then	-- UP then
		windowPosY = windowPosY - 1
		changeClock = os.clock()
	end
	if key == 274 then	-- DOWN then
		windowPosY = windowPosY + 1
		changeClock = os.clock()
	end
	if key == 275 then	-- RIGHT then
		windowPosX = windowPosX + 1
		changeClock = os.clock()
	end
	if key == 276 then	-- LEFT then
		windowPosX = windowPosX - 1
		changeClock = os.clock()
	end
	if dlistPosX ~= windowPosX or dlistPosY ~= windowPosY then
		if windowList then gl.DeleteList(windowList) end
		windowList = gl.CreateList(DrawWindow)
	end
	return true
end

function widget:DrawScreen()
	gl.CallList(windowList)

	local x,y,b = Spring.GetMouseState()
	if applyButtonPos and IsOnRect(x, y, applyButtonPos[1],applyButtonPos[2],applyButtonPos[3],applyButtonPos[4]) then
		gl.Color(0.25,1,0.25,0.15)
		RectRound(applyButtonPos[1],applyButtonPos[2],applyButtonPos[3],applyButtonPos[4],applyButtonPos[5])
	end
end

function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('movewindowpos')
		WG['guishader_api'].setScreenBlur(false)
	end
	if windowList then gl.DeleteList(windowList) end
	widgetHandler:DisableWidget(widgetName)
end