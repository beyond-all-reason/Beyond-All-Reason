--http://springrts.com/phpbb/viewtopic.php?f=23&t=30560
function widget:GetInfo()
	return {
		name = "replay buttons",
		desc = "click buttons to change replay speed",
		author = "knorke",
		version = "1",
		date = "June 2013",
		license = "click button magic",
		layer = 10,
		enabled = true,		
	}
end

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 25
local fontfileOutlineSize = 5
local fontfileOutlineStrength = 1.1
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local glossMult = 1 + (2-(ui_opacity*2))	-- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local speedbuttons={} --the 1x 2x 3x etc buttons
local buttons={}	--other buttons (atm only pause/play)
local wantedSpeed = nil
local speeds = {0.5, 1, 2, 3, 4, 5, 10, 20}
wPos = {x=0.00, y=0.145}
local isPaused = false
local isActive = true --is the widget shown and reacts to clicks?
local sceduleUpdate = true
local vsx,vsy = Spring.GetViewGeometry()
widgetScale = (0.5 + (vsx*vsy / 5700000))

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

function widget:Initialize()	
	if (not Spring.IsReplay()) then
		Spring.Echo ("[Replay Control] Replay not detected, Shutting Down.")
		widgetHandler:RemoveWidget(self)
		return
	end
	
	local dy = 0
	local h = 0.033
	for i = 1, #speeds do	
		dy=dy+h
		add_button (speedbuttons, wPos.x, wPos.y+dy, 0.037, 0.033, "  " .. speeds[i].."x", speeds[i], speedButtonColor (i))
	end
	speedbuttons[2].color = {0.75,0,0,0.66}
	dy=dy+h
	local text = "  skip"
	if Spring.GetGameFrame() > 0 then
		text = "  ||"
	end
	add_button (buttons, wPos.x, wPos.y, 0.037, 0.033, text,"playpauseskip", {0,0,0,0.6})	
	
end

function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('replaybuttons')
	end
	gl.DeleteList(speedButtonsList)
	gl.DeleteList(buttonsList)
	gl.DeleteFont(font)
end

function speedButtonColor (i)
	return{0,0,0,0.6}
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
	if WG['guishader'] then
		if isActive then
			local h = 0.033
			local dy = (#speeds +1) * h

			if backgroundGuishader then
				gl.DeleteList(backgroundGuishader)
			end
			backgroundGuishader = gl.CreateList( function()
				RectRound(sX(wPos.x), sY(wPos.y), sX(wPos.x+0.037), sY(wPos.y+dy), 6*widgetScale, 0,1,1,0)
			end)
			WG['guishader'].InsertDlist(backgroundGuishader, 'replaybuttons')
		else
			WG['guishader'].DeleteDlist('replaybuttons')
		end
	end
	
	if not isActive then return end
	if sceduleUpdate then
		if speedButtonsList then
			gl.DeleteList(speedButtonsList)
			gl.DeleteList(buttonsList)
		end
		speedButtonsList = gl.CreateList(draw_buttons, speedbuttons)
		buttonsList = gl.CreateList(draw_buttons, buttons)
		sceduleUpdate = false
	end
	if speedButtonsList then
		gl.CallList(speedButtonsList)
		gl.CallList(buttonsList)
	end
	local mousex, mousey, buttonstate = Spring.GetMouseState()
	local b = speedbuttons
	local topbutton = #speedbuttons
	if point_in_rect (buttons[1].x, buttons[1].y, b[topbutton].x+b[topbutton].w, b[topbutton].y+b[topbutton].h,  uiX(mousex), uiY(mousey)) then
		for i = 1, #b, 1 do
			if (point_in_rect (b[i].x, b[i].y, b[i].x+b[i].w, b[i].y+b[i].h,  uiX(mousex), uiY(mousey)) or i == active_button) then
				local padding = 4.5
				uiRect(b[i].x, b[i].y, b[i].x+b[i].w-(padding/vsx), b[i].y+b[i].h-(padding/vsy), 4, 0,1,1,0, {0.3,0.3,0.3,buttonstate and 0.25 or 0.15}, {1,1,1,buttonstate and 0.25 or 0.15})
				-- gloss
				glBlending(GL_SRC_ALPHA, GL_ONE)
				uiRect(b[i].x, b[i].y+(b[i].h*0.6), b[i].x+b[i].w-(padding/vsx), b[i].y+b[i].h-(padding/vsy), 4, 1,1,0,0, {1,1,1,0.06}, {1,1,1,buttonstate and 0.4 or 0.25})
				uiRect(b[i].x, b[i].y, b[i].x+b[i].w-(padding/vsx), b[i].y+(b[i].h*0.35), 4, 0,0,1,1, {1,1,1,buttonstate and 0.25 or 0.15}, {1,1,1,0})
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
				uiText (b[i].text, b[i].x, b[i].y+b[i].h/2, (0.0115), 'vo')
				break
			end
		end
		b = buttons
		for i = 1, #b, 1 do
			if (point_in_rect (b[i].x, b[i].y, b[i].x+b[i].w, b[i].y+b[i].h,  uiX(mousex), uiY(mousey)) or i == active_button) then
				local padding = 4.5
				uiRect(b[i].x, b[i].y, b[i].x+b[i].w-(padding/vsx), b[i].y+b[i].h-(padding/vsy), 4, 0,1,1,0, {0.3,0.3,0.3,buttonstate and 0.25 or 0.15}, {1,1,1,buttonstate and 0.25 or 0.15})
				-- gloss
				glBlending(GL_SRC_ALPHA, GL_ONE)
				uiRect(b[i].x, b[i].y+(b[i].h*0.6), b[i].x+b[i].w-(padding/vsx), b[i].y+b[i].h-(padding/vsy), 4, 1,1,0,0, {1,1,1,0.06}, {1,1,1,buttonstate and 0.4 or 0.25})
				uiRect(b[i].x, b[i].y, b[i].x+b[i].w-(padding/vsx), b[i].y+(b[i].h*0.35), 4, 0,0,1,1, {1,1,1,buttonstate and 0.25 or 0.15}, {1,1,1,0})
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
				uiText (b[i].text, b[i].x, b[i].y+b[i].h/2, (0.0115), 'vo')
				break
			end
		end
	end
end

function widget:MousePress(x,y,button)
	if not isActive then return end
	local cb,i = clicked_button (speedbuttons)
	if cb ~= "NOBUTTONCLICKED" then
		setReplaySpeed (speeds[i], i)
		for i = 1, #speeds do --reset all buttons colors
			speedbuttons[i].color = speedButtonColor (i)
		end
		speedbuttons[i].color = {0.75,0,0,0.66 }
		sceduleUpdate = true
		return true
	end

	local cb,i = clicked_button (buttons)
	if cb == "playpauseskip" then
		if Spring.GetGameFrame () > 1 then
			if (isPaused) then
				Spring.SendCommands ("pause 0")
				buttons[i].text = "  ||"
				isPaused = false
			else
				Spring.SendCommands ("pause 1")
				buttons[i].text = "  >>"
				isPaused = true
			end
		else
			Spring.SendCommands ("skip 1")
			buttons[i].text = "  ||"
		end
		sceduleUpdate = true
		return true
	end
end

function setReplaySpeed (speed, i)
	local s = Spring.GetGameSpeed()
	--Spring.Echo ("setting speed to: " , speed , " current is " , s)
	if (speed > s) then	--speedup
		Spring.SendCommands ("setminspeed " .. speed)
		Spring.SendCommands ("setminspeed " ..0.1)
	else	--slowdown
		wantedSpeed = speed
	end
end


local uiOpacitySec = 0
function widget:Update(dt)
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.33 then
		uiOpacitySec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
			ui_scale = Spring.GetConfigFloat("ui_scale",1)
			widget:ViewResize()
		end
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
			glossMult = 1 + (2-(ui_opacity*2))
			widget:ViewResize()
		end
	end

	if (wantedSpeed) then
		if (Spring.GetGameSpeed() > wantedSpeed) then
			Spring.SendCommands ("slowdown")
		else
			wantedSpeed = nil
		end
	end
	if #Spring.GetSelectedUnits () ~=0 then isActive = false else isActive = true end
end

function widget:GameFrame (f)
	if (f==1) then
		buttons[1].text= "  ||"
	end
end

------------------------------------------------------------------------------------------
--a simple UI framework with buttons
--Feb 2011 by knorke
local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix

--UI coordinaten zu scalierten screen koordinaten
function sX (uix)
	return uix*vsx
end
function sY (uiy)
	return uiy*vsy
end
---...und andersrum!
function uiX (sX)
	return sX/vsx
end
function uiY (sY)
	return sY/vsy
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = (0.5 + (vsx*vsy / 5700000))
	sceduleUpdate = true
	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
end

function uiText (text, x,y,s,options)
	if (text==" " or text=="  ") then return end --archivement: unlock +20 fps
	font:Begin()
	font:Print(text, sX(x), sY(y), sX(s), options)
	font:End()
end
--------------------------------
-----message boxxy-----
function drawmessagebox (msgbox, msg_n)
	if (msgbox.messages==nil) then return end
	local yoff = msgbox.textsize
	if (msg_n==nil) then msg_n=100 end --***
	local start = #msgbox.messages-msg_n+1
	if (start < 1) then start = 1 end
	local fade = 1
	for i =  start, #msgbox.messages , 1 do
		drawmessage (msgbox.messages[i],  msgbox.x,  msgbox.y-yoff, msgbox.textsize)
		yoff=yoff+msgbox.textsize*1.2
	end
end


function drawmessage_simple (message, x, y, s)
	offx=0
	font:Begin()
	if (message.frame) then
		font:Print(frame2time (message.frame), sX(x+offx), sY(y), sX(s/2), 'vo')
		offx=offx+(2*s)
	end
	font:Print(message.text, sX(x+offx), sY(y), sX(s), 'vo')
	font:End()
end

--X, Y and size in UI scale
function drawmessage (message, x, y, s)
	if (message.bgcolor) then
		gl.Color (unpack(message.bgcolor))
		uiRect(x,y+s/2, x+1, y-s/2, 6, 0,1,1,0)
	end
	offx=0
	font:Begin()
	if (message.frame) then
		font:Print(frame2time (message.frame), sX(x+offx), sY(y), sX(s/2), 'vo')
		offx=offx+(2*s)
	end
	if (message.icon) then
		--****!!! irgendwie malt er danach keine Rechtecke mehr
		--gl.PushMatrix()
		gl.Color (1,1,1,1)
		gl.Texture(message.icon)
		gl.TexRect(sX(x+s*1.9),sY(y-s*0.8), sX(x+s*2.9),sY(y+s*0.8)  )
		gl.Texture(false)
		--gl.PopMatrix()
		offx=offx+(s)
	end
	font:Print(message.text, sX(x+offx), sY(y), sX(s), 'vo')
	font:End()
end


function addmessage (msgbox, text, bgcolor)
	local newmessage = {}
	--newmessage.frame = gameframe
	if (bgcolor) then newmessage.bgcolor = bgcolor end---{0,0,0.8,0.5}
	newmessage.text = text
	table.insert (msgbox.messages, newmessage)
end
-------message boxxy end------
------BUTTONS------


local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
	local csyMult = 1 / ((sy-py)/cs)

	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)

	-- left side
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)

	-- right side
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)

	-- bottom left
	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then
		gl.Vertex(px, py, 0)
	else
		gl.Vertex(px+cs, py, 0)
	end
	gl.Vertex(px+cs, py, 0)
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
		gl.Vertex(sx, py, 0)
	else
		gl.Vertex(sx-cs, py, 0)
	end
	gl.Vertex(sx-cs, py, 0)
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
		gl.Vertex(px, sy, 0)
	else
		gl.Vertex(px+cs, sy, 0)
	end
	gl.Vertex(px+cs, sy, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2 then
		gl.Vertex(sx, sy, 0)
	else
		gl.Vertex(sx-cs, sy, 0)
	end
	gl.Vertex(sx-cs, sy, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(false)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
end
function uiRect(x,y,x2,y2, cs, tl,tr,br,bl, c1,c2)
	RectRound(sX(x), sY(y), sX(x2), sY(y2), cs, tl,tr,br,bl, c1,c2)
	--gl.Rect (sX(x), sY(y), sX(x2), sY(y2))
end

function draw_buttons (b)
	local mousex, mousey = Spring.GetMouseState()
	for i = 1, #b, 1 do
		if (b[i].color) then gl.Color (unpack(b[i].color)) else gl.Color (1 ,0,0,0.66) end
		--if (point_in_rect (b[i].x, b[i].y, b[i].x+b[i].w, b[i].y+b[i].h,  uiX(mousex), uiY(mousey)) or i == active_button) then
		--	gl.Color (0.4,0.4,0.4,0.6)
		--end
		if (b[i].name == selected_missionid) then gl.Color (0,1,1,0.66) end --highlight selected mission, bit unnice this way w/e

		local padding = 4.5
		uiRect(b[i].x, b[i].y, b[i].x+b[i].w, b[i].y+b[i].h, 6, 0,1,1,0, {0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
		uiRect(b[i].x, b[i].y, b[i].x+b[i].w-(padding/vsx), b[i].y+b[i].h-(padding/vsy), 4, 0,1,1,0, {0.3,0.3,0.3,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})
		-- gloss
		glBlending(GL_SRC_ALPHA, GL_ONE)
		uiRect(b[i].x, b[i].y+(b[i].h*0.6), b[i].x+b[i].w-(padding/vsx), b[i].y+b[i].h-(padding/vsy), 4, 1,1,0,0, {1,1,1,0.015*glossMult}, {1,1,1,0.07*glossMult})
		uiRect(b[i].x, b[i].y, b[i].x+b[i].w-(padding/vsx), b[i].y+(b[i].h*0.35), 4, 0,0,1,1, {1,1,1,0.025*glossMult}, {1,1,1,0})
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		uiText (b[i].text, b[i].x, b[i].y+b[i].h/2, (0.0115), 'vo')
	end
end



function add_button (buttonlist, x,y, w, h, text, name, color)
	local new_button = {}
	new_button.x=x new_button.y=y new_button.w=w new_button.h=h new_button.text=text new_button.name=name
	if(color) then new_button.color=color end
	table.insert (buttonlist, new_button)
end

function previous_button ()
	active_button = active_button -1
	if (active_button < 1) then active_button = #buttons end
end

function next_button ()
	active_button = active_button +1
	if (active_button > #buttons) then active_button = 1 end
end

function point_in_rect (x1, y1, x2, y2, px, py)
	if (px > x1 and px < x2 and py > y1 and py < y2) then return true end
	return false
end

function clicked_button (b)
	local mx, my,click = Spring.GetMouseState()
	local mousex=uiX(mx)
	local mousey=uiY(my)
	for i = 1, #b, 1 do	
		if (click == true and point_in_rect (b[i].x, b[i].y, b[i].x+b[i].w, b[i].y+b[i].h,  mousex, mousey)) then return b[i].name, i end
		--if (mouse_was_down == false and click == true and point_in_rect (b[i].x, b[i].y, b[i].x+b[i].w, b[i].y+b[i].h,  mousex, mousey)) then mouse_was_down = true end
		end
	--keyboard:
	--if (enter_was_down and active_button > 0 and active_button < #buttons+1) then enter_was_down = false return b[active_button].name, active_button end
	return "NOBUTTONCLICKED"
end
