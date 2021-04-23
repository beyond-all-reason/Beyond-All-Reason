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

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local vsx, vsy = Spring.GetViewGeometry()

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local glossMult = 1 + (2 - (ui_opacity * 2))    -- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local speedbuttons = {} --the 1x 2x 3x etc buttons
local buttons = {}    --other buttons (atm only pause/play)
local wantedSpeed = nil
local speeds = { 0.5, 1, 2, 3, 4, 5, 10, 20 }
local wPos = { x = 0.00, y = 0.145 }
local isPaused = false
local isActive = true --is the widget shown and reacts to clicks?
local sceduleUpdate = true
local widgetScale = (0.5 + (vsx * vsy / 5700000))

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local RectRound = Spring.FlowUI.Draw.RectRound
local UiButton = Spring.FlowUI.Draw.Button
local elementCorner = Spring.FlowUI.elementCorner

local chobbyInterface, font, backgroundGuishader, buttonsList, speedButtonsList, buttonlist, active_button, bgpadding

local function speedButtonColor(i)
	return { 0, 0, 0, 0.6 }
end

local function add_button(buttonlist, x, y, w, h, text, name, color)
	local new_button = {}
	new_button.x = x
	new_button.y = y
	new_button.w = w
	new_button.h = h
	new_button.text = text
	new_button.name = name
	if color then
		new_button.color = color
	end
	table.insert(buttonlist, new_button)
end

local function point_in_rect(x1, y1, x2, y2, px, py)
	if px > x1 and px < x2 and py > y1 and py < y2 then
		return true
	end
	return false
end

local function clicked_button(b)
	local mx, my, click = Spring.GetMouseState()
	local mousex = mx / vsx
	local mousey = my / vsy
	for i = 1, #b, 1 do
		if click and point_in_rect(b[i].x, b[i].y, b[i].x + b[i].w, b[i].y + b[i].h, mousex, mousey) then
			return b[i].name, i
		end
	end
	--keyboard:
	--if (enter_was_down and active_button > 0 and active_button < #buttons+1) then enter_was_down = false return b[active_button].name, active_button end
	return "NOBUTTONCLICKED"
end

local function setReplaySpeed(speed, i)
	local s = Spring.GetGameSpeed()
	--Spring.Echo ("setting speed to: " , speed , " current is " , s)
	if speed > s then
		--speedup
		Spring.SendCommands("setminspeed " .. speed)
		Spring.SendCommands("setminspeed " .. 0.1)
	else
		--slowdown
		wantedSpeed = speed
	end
end

local function uiRect(x, y, x2, y2, cs, tl, tr, br, bl, c1, c2)
	RectRound(math.floor((x * vsx) + 0.5), math.floor((y * vsy) + 0.5), math.floor((x2 * vsx) + 0.5), math.floor((y2 * vsy) + 0.5), cs, tl, tr, br, bl, c1, c2)
end

local function draw_buttons(b)
	font:Begin()
	for i = 1, #b do
		--UiButton(b[i].x, b[i].y, b[i].x + b[i].w, b[i].y + b[i].h, 0,1,1,0, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, { 0.2, 0.2, 0.2, 0.8 }, bgpadding * 0.5)
		gl.Color(1, 0, 0, 0.66)
		uiRect(b[i].x, b[i].y, b[i].x + b[i].w, b[i].y + b[i].h, elementCorner, 0, 1, 1, 0, { 0.05, 0.05, 0.05, ui_opacity }, { 0, 0, 0, ui_opacity })
		uiRect(b[i].x, b[i].y, b[i].x + b[i].w - (bgpadding / vsx), b[i].y + b[i].h - (bgpadding / vsy), elementCorner * 0.66, 0, 1, 1, 0, { 0.3, 0.3, 0.3, ui_opacity * 0.1 }, { 1, 1, 1, ui_opacity * 0.1 })
		-- gloss
		glBlending(GL_SRC_ALPHA, GL_ONE)
		uiRect(b[i].x, b[i].y + (b[i].h * 0.55), b[i].x + b[i].w - (bgpadding / vsx), b[i].y + b[i].h - (bgpadding / vsy), elementCorner * 0.66, 1, 1, 0, 0, { 1, 1, 1, 0.01 * glossMult }, { 1, 1, 1, 0.055 * glossMult })
		uiRect(b[i].x, b[i].y, b[i].x + b[i].w - (bgpadding / vsx), b[i].y + (b[i].h * 0.4), elementCorner * 0.66, 0, 0, 1, 1, { 1, 1, 1, 0.04 * glossMult }, { 1, 1, 1, 0 })
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		font:Print(b[i].text, math.floor((b[i].x * vsx) + 0.5), math.floor(((b[i].y + b[i].h / 2) * vsy) + 0.5), math.floor((0.0115 * vsx) + 0.5), 'vo')
	end
	font:End()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.5 + (vsx * vsy / 5700000))
	sceduleUpdate = true

	bgpadding = Spring.FlowUI.elementPadding
	elementCorner = Spring.FlowUI.elementCorner

	font = WG['fonts'].getFont(fontfile2)
end

function widget:Initialize()
	widget:ViewResize()
	if not Spring.IsReplay() then
		widgetHandler:RemoveWidget(self)
		return
	end

	local dy = 0
	local h = 0.033
	for i = 1, #speeds do
		dy = dy + h
		add_button(speedbuttons, wPos.x, wPos.y + dy, 0.037, 0.033, "  " .. speeds[i] .. "x", speeds[i], speedButtonColor(i))
	end
	speedbuttons[2].color = { 0.75, 0, 0, 0.66 }
	dy = dy + h
	add_button(buttons, wPos.x, wPos.y, 0.037, 0.033, (Spring.GetGameFrame() > 0 and "  ||" or "  skip"), "playpauseskip", { 0, 0, 0, 0.6 })
end

function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('replaybuttons')
	end
	gl.DeleteList(speedButtonsList)
	gl.DeleteList(buttonsList)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	if WG['guishader'] then
		if isActive then
			local h = 0.033
			local dy = (#speeds + 1) * h

			if backgroundGuishader then
				gl.DeleteList(backgroundGuishader)
			end
			backgroundGuishader = gl.CreateList(function()
				RectRound(math.floor((wPos.x * vsx) + 0.5), math.floor((wPos.y * vsy) + 0.5), math.floor(((wPos.x + 0.037) * vsx) + 0.5),  math.floor(((wPos.y + dy) * vsy) + 0.5), elementCorner, 0, 1, 1, 0)
			end)
			WG['guishader'].InsertDlist(backgroundGuishader, 'replaybuttons')
		else
			WG['guishader'].DeleteDlist('replaybuttons')
		end
	end

	if not isActive then
		return
	end
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
	font:Begin()
	if point_in_rect(buttons[1].x, buttons[1].y, b[topbutton].x + b[topbutton].w, b[topbutton].y + b[topbutton].h, mousex / vsx, mousey / vsy) then
		for i = 1, #b, 1 do
			if point_in_rect(b[i].x, b[i].y, b[i].x + b[i].w, b[i].y + b[i].h, mousex / vsx, mousey / vsy) or i == active_button then
				uiRect(b[i].x, b[i].y, b[i].x + b[i].w - (bgpadding / vsx), b[i].y + b[i].h - (bgpadding / vsy), elementCorner * 0.66, 0, 1, 1, 0, { 0.3, 0.3, 0.3, buttonstate and 0.25 or 0.15 }, { 1, 1, 1, buttonstate and 0.25 or 0.15 })
				-- gloss
				glBlending(GL_SRC_ALPHA, GL_ONE)
				uiRect(b[i].x, b[i].y + (b[i].h * 0.55), b[i].x + b[i].w - (bgpadding / vsx), b[i].y + b[i].h - (bgpadding / vsy), elementCorner * 0.66, 1, 1, 0, 0, { 1, 1, 1, 0.06 }, { 1, 1, 1, buttonstate and 0.4 or 0.25 })
				uiRect(b[i].x, b[i].y, b[i].x + b[i].w - (bgpadding / vsx), b[i].y + (b[i].h * 0.4), elementCorner * 0.66, 0, 0, 1, 1, { 1, 1, 1, buttonstate and 0.25 or 0.15 }, { 1, 1, 1, 0 })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
				font:Print(b[i].text, math.floor((b[i].x * vsx) + 0.5), math.floor(((b[i].y + b[i].h / 2) * vsy) + 0.5), math.floor((0.0115 * vsx) + 0.5), 'vo')
				break
			end
		end
		b = buttons
		for i = 1, #b, 1 do
			if point_in_rect(b[i].x, b[i].y, b[i].x + b[i].w, b[i].y + b[i].h, mousex / vsx, mousey / vsy) or i == active_button then
				uiRect(b[i].x, b[i].y, b[i].x + b[i].w - (bgpadding / vsx), b[i].y + b[i].h - (bgpadding / vsy), elementCorner * 0.66, 0, 1, 1, 0, { 0.3, 0.3, 0.3, buttonstate and 0.25 or 0.15 }, { 1, 1, 1, buttonstate and 0.25 or 0.15 })
				-- gloss
				glBlending(GL_SRC_ALPHA, GL_ONE)
				uiRect(b[i].x, b[i].y + (b[i].h * 0.55), b[i].x + b[i].w - (bgpadding / vsx), b[i].y + b[i].h - (bgpadding / vsy), elementCorner * 0.66, 1, 1, 0, 0, { 1, 1, 1, 0.06 }, { 1, 1, 1, buttonstate and 0.4 or 0.25 })
				uiRect(b[i].x, b[i].y, b[i].x + b[i].w - (bgpadding / vsx), b[i].y + (b[i].h * 0.4), elementCorner * 0.66, 0, 0, 1, 1, { 1, 1, 1, buttonstate and 0.25 or 0.15 }, { 1, 1, 1, 0 })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
				font:Print(b[i].text, math.floor((b[i].x * vsx) + 0.5), math.floor(((b[i].y + b[i].h / 2) * vsy) + 0.5), math.floor((0.0115 * vsx) + 0.5), 'vo')
				break
			end
		end
	end
	font:End()
end

function widget:MousePress(x, y, button)
	if not isActive then
		return
	end
	local cb, i = clicked_button(speedbuttons)
	if cb ~= "NOBUTTONCLICKED" then
		setReplaySpeed(speeds[i], i)
		--reset all buttons colors
		for i = 1, #speeds do
			speedbuttons[i].color = speedButtonColor(i)
		end
		speedbuttons[i].color = { 0.75, 0, 0, 0.66 }
		sceduleUpdate = true
		return true
	end

	local cb, i = clicked_button(buttons)
	if cb == "playpauseskip" then
		if Spring.GetGameFrame() > 1 then
			if isPaused then
				Spring.SendCommands("pause 0")
				buttons[i].text = "  ||"
				isPaused = false
			else
				Spring.SendCommands("pause 1")
				buttons[i].text = "  >>"
				isPaused = true
			end
		else
			Spring.SendCommands("skip 1")
			buttons[i].text = "  ||"
		end
		sceduleUpdate = true
		return true
	end
end

local uiOpacitySec = 0
function widget:Update(dt)
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.33 then
		uiOpacitySec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
		end
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.66)
			glossMult = 1 + (2 - (ui_opacity * 2))
			widget:ViewResize()
		end
	end

	if wantedSpeed then
		if Spring.GetGameSpeed() > wantedSpeed then
			Spring.SendCommands("slowdown")
		else
			wantedSpeed = nil
		end
	end
	isActive = #Spring.GetSelectedUnits() == 0
end

function widget:GameFrame(f)
	if f == 1 then
		buttons[1].text = "  ||"
	end
end