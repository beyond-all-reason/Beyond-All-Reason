function widget:GetInfo()
	return {
		name = "Replay Speed Buttons",
		desc = "Add buttons to change replay speed",
		author = "knorke",
		version = "1",
		date = "June 2013",
		license = "click button magic",
		layer = 10,
		enabled = true,		
	}
end

local speedbuttons={} --the 1x 2x 3x etc buttons
local buttons={}	--other buttons (atm only pause/play)
local wantedSpeed = nil
local speeds = {0.5, 1, 2, 3, 4, 5,10,20}
wPos = {x=0.00, y=0.15}
local isPaused = false
local isActive = true --is the widget shown and reacts to clicks?

function widget:Initialize()
	if (not Spring.IsReplay()) then
		widgetHandler:RemoveWidget(self)
		return
	end
	

	local dy = 0
	local h = 0.04	
	for i = 1, #speeds do	
		dy=dy+h
		add_button (speedbuttons, wPos.x, wPos.y+dy, 0.05, 0.04, " " .. speeds[i].."x", speeds[i], speedButtonColor (i))
	end
	speedbuttons[2].color = {1,0,0,1}
	dy=dy+h
	add_button (buttons, wPos.x, wPos.y, 0.05, 0.04, "skip","playpauseskip", {0.5,0.5,1,0.4})	
	
end

function speedButtonColor (i)
	return{0,0+i/10,1,0.4}
end

function widget:DrawScreen()
	if not isActive then return end
	draw_buttons(speedbuttons)
	draw_buttons(buttons)
end

function widget:MousePress(x,y,button)	
	if not isActive then return end
	local cb,i = clicked_button (speedbuttons)
	if cb ~= "NOBUTTONCLICKED" then
		setReplaySpeed (speeds[i], i)
		for i = 1, #speeds do --reset all buttons colors
			speedbuttons[i].color = speedButtonColor (i)
		end
		speedbuttons[i].color = {1,0,0,1}
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
				buttons[i].text = " >>"
				isPaused = true
			end
		else
			Spring.SendCommands ("skip 1")
			buttons[i].text = "  ||"
		end
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


function widget:Update()
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
local glText           = gl.Text
local vsx, vsy = widgetHandler:GetViewSizes()
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
	vsx = viewSizeX
	vsy = viewSizeY
end
----zeichen funktionen---------
function uiRect (x,y,x2,y2)
	gl.Rect (sX(x), sY(y), sX(x2), sY(y2))
end

function uiText (text, x,y,s,options)
	if (text==" " or text=="  ") then return end --archivement: unlock +20 fps
	glText (text, sX(x), sY(y), sX(s), options)
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
	if (message.frame) then		
		glText (frame2time (message.frame), sX(x+offx), sY(y), sX(s/2), 'vo')
		offx=offx+(2*s)
	end	
	glText (message.text, sX(x+offx), sY(y), sX(s), 'vo')	
end

--X, Y and size in UI scale
function drawmessage (message, x, y, s)	
	if (message.bgcolor) then 
		gl.Color (unpack(message.bgcolor))
		uiRect (x,y+s/2, x+1, y-s/2)
	end	
	offx=0
	if (message.frame) then		
		glText (frame2time (message.frame), sX(x+offx), sY(y), sX(s/2), 'vo')
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
	glText (message.text, sX(x+offx), sY(y), sX(s), 'vo')	
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
function draw_buttons (b)
	local mousex, mousey = Spring.GetMouseState()
	for i = 1, #b, 1 do	
		if (b[i].color) then gl.Color (unpack(b[i].color)) else gl.Color (1 ,0,0,1) end
		if (point_in_rect (b[i].x, b[i].y, b[i].x+b[i].w, b[i].y+b[i].h,  uiX(mousex), uiY(mousey)) or i == active_button) then
			gl.Color (1,1,0.5,0.8)
		end
		if (b[i].name == selected_missionid) then gl.Color (0,1,1,0.9) end --highlight selected mission, bit unnice this way w/e
		uiRect (b[i].x, b[i].y, b[i].x+b[i].w, b[i].y+b[i].h)
		uiText (b[i].text, b[i].x, b[i].y+b[i].h/2,  0.02, 'vo')
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
		end
	return "NOBUTTONCLICKED"
end
