
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

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	movewitharrows = "\255\170\170\170Move window position with the \255\255\255\255arrow keys\255\170\170\170 or \255\255\255\255drag\255\170\170\170 using the mouse.",
	escape = "\255\255\255\255ESCAPE\255\170\170\170 key will cancel changes",
	apply = 'Apply',
}

local vsx,vsy = Spring.GetViewGeometry()

local customScale = 1.2
local widgetScale = (1 + (vsx*vsy / 4000000)) * customScale

local windowPosX = tonumber(Spring.GetConfigInt("WindowPosX",1) or 0)
local windowPosY = tonumber(Spring.GetConfigInt("WindowPosY",1) or 0)
local initialWindowPosX = windowPosX
local initialWindowPosY = windowPosY
local dlistPosX = windowPosX
local dlistPosY = windowPosY

local font, applyButtonPos, windowList, changeClock, escape, applyChanges, draggingStartX, draggingStartY, chobbyInterface, dragging

local RectRound = Spring.FlowUI.Draw.RectRound

function DrawWindow()
	dlistPosX = windowPosX
	dlistPosY = windowPosY
	if WG['guishader'] then
		WG['guishader'].InsertRect(0,0,vsx,vsy, 'movewindowpos')
		WG['guishader'].setScreenBlur(true)
	end
	font:Begin()
	gl.Color(0,0,0,0.6)
	gl.Rect(0,0,vsx,vsy)
	font:Print(texts.movewitharrows, vsx/2, (vsy/2)+(50*widgetScale), 12*widgetScale, "ocn")
	font:Print("\255\222\255\222x = "..windowPosX.."     y = "..windowPosY, vsx/2, (vsy/2), 14*widgetScale, "ocn")
	local buttonText = '   '..texts.apply..'   '
	local buttonX = vsx/2
	local buttonY = (vsy/2)-(36*widgetScale)
	local buttonFontsize = 15*widgetScale
	local buttonWidth = font:GetTextWidth(buttonText)*buttonFontsize
	local buttonHeight = buttonFontsize*2.2
	font:Print(texts.escape, vsx/2, (vsy/2)-(50*widgetScale)-buttonHeight, 12*widgetScale, "ocn")
	if initialWindowPosX ~= dlistPosX or initialWindowPosY ~= dlistPosY then
		applyButtonPos = {buttonX-(buttonWidth/2), buttonY-(buttonHeight/2), buttonX+(buttonWidth/2), buttonY+(buttonHeight/2),buttonFontsize/5}
		gl.Color(0,0.33,0,0.8)
		RectRound(applyButtonPos[1],applyButtonPos[2],applyButtonPos[3],applyButtonPos[4],applyButtonPos[5])
		local padding = 2*widgetScale
		gl.Color(1,1,1,0.1)
		RectRound(applyButtonPos[1]+padding,applyButtonPos[2]+padding,applyButtonPos[3]-padding,applyButtonPos[4]-padding,applyButtonPos[5]*0.66)
		font:Print("\255\222\255\222"..buttonText, buttonX, buttonY-(buttonFontsize*0.27), buttonFontsize, "ocn")
	else
		applyButtonPos = nil
	end
	font:End()
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = (1 + (vsx*vsy / 4000000)) * customScale

	font = WG['fonts'].getFont()

	if windowList then gl.DeleteList(windowList) end
	windowList = gl.CreateList(DrawWindow)
end

function widget:Initialize()
	if WG['lang'] then
		texts = WG['lang'].getText('movewindowpos')
	end
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

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
	gl.CallList(windowList)

	local x,y,b = Spring.GetMouseState()
	if applyButtonPos and IsOnRect(x, y, applyButtonPos[1],applyButtonPos[2],applyButtonPos[3],applyButtonPos[4]) then
		gl.Color(0.25,1,0.25,0.15)
		RectRound(applyButtonPos[1],applyButtonPos[2],applyButtonPos[3],applyButtonPos[4],applyButtonPos[5])
	end
end

function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].RemoveRect('movewindowpos')
		WG['guishader'].setScreenBlur(false)
	end
	if windowList then gl.DeleteList(windowList) end
	widgetHandler:DisableWidget(widgetName)
end
