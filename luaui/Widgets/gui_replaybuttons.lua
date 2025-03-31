--http://springrts.com/phpbb/viewtopic.php?f=23&t=30560
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Replay buttons",
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

local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)
local ui_scale = Spring.GetConfigFloat("ui_scale", 1)

local buttonWidth = 0.037
local buttonHeight = 0.033
local bWidth = buttonWidth * ui_scale
local bHeight = buttonHeight * ui_scale

local buttons = {}
local speeds = { 0.5, 1, 2, 3, 4, 6, 8, 10, 15, 20 }
local wPos = { x = 0.00, y = 0.145 }
local isPaused = false
local isActive = true --is the widget shown and reacts to clicks?
local sceduleUpdate = true
local widgetScale = (0.5 + (vsx * vsy / 5700000))

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local RectRound, UiButton, elementCorner

local font, backgroundGuishader, buttonsList, buttonlist, active_button, bgpadding

local function add_button(x, y, text, name)
	local new_button = {}
	new_button.x = x
	new_button.y = y
	new_button.text = text
	new_button.name = name
	table.insert(buttons, new_button)
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
		if click and point_in_rect(b[i].x, b[i].y, b[i].x + bWidth, b[i].y + bHeight, mousex, mousey) then
			return b[i].name, i
		end
	end

	return "NOBUTTONCLICKED"
end

local function setReplaySpeed(speed)
	Spring.SendCommands("setspeed " .. speed)
end

local function draw_buttons(b)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 0.7)
	for i = 1, #b do
		UiButton(math.floor((b[i].x * vsx) + 0.5), math.floor((b[i].y * vsy) + 0.5), math.floor(((b[i].x + bWidth) * vsx) + 0.5), math.floor(((b[i].y + bHeight) * vsy) + 0.5), 0,1,1,0, 1,1,1,1, nil, { 0, 0, 0, ui_opacity }, { 0.2, 0.2, 0.2, ui_opacity }, bgpadding * 0.5)
		font:Print(b[i].text, math.floor((b[i].x * vsx) + 0.5), math.floor(((b[i].y + bHeight / 2) * vsy) + 0.5), math.floor((0.0115 * vsx) + 0.5), 'vo')
	end
	font:End()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.5 + (vsx * vsy / 5700000))
	sceduleUpdate = true

	bHeight = buttonHeight * ui_scale
	bWidth = buttonWidth * ui_scale

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiButton = WG.FlowUI.Draw.Button

	font = WG['fonts'].getFont(fontfile2)
end

function widget:Initialize()
	widget:ViewResize()
	if not Spring.IsReplay() then
		widgetHandler:RemoveWidget()
		return
	end

	local dy = 0
	for i = 1, #speeds do
		dy = dy + bHeight
		add_button(wPos.x, wPos.y + dy, "  " .. speeds[i] .. "x", speeds[i])
	end
	dy = dy + bHeight
	add_button(wPos.x, wPos.y, (Spring.GetGameFrame() > 0 and "  ||" or "  skip"), "playpauseskip")
end

function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('replaybuttons')
	end
	gl.DeleteList(buttonsList)
end



function widget:DrawScreen()
	if WG['guishader'] then
		if isActive then
			local dy = (#speeds + 1) * bHeight

			if backgroundGuishader then
				gl.DeleteList(backgroundGuishader)
			end
			backgroundGuishader = gl.CreateList(function()
				RectRound(math.floor((wPos.x * vsx) + 0.5), math.floor((wPos.y * vsy) + 0.5), math.floor(((wPos.x + bWidth) * vsx) + 0.5),  math.floor(((wPos.y + dy) * vsy) + 0.5), elementCorner, 0, 1, 1, 0)
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
		if buttonsList then
			gl.DeleteList(buttonsList)
		end
		buttonsList = gl.CreateList(draw_buttons, buttons)
		sceduleUpdate = false
	end
	if buttonsList then
		gl.CallList(buttonsList)
	end
	local mousex, mousey, buttonstate = Spring.GetMouseState()
	local b = buttons
	local topbutton = #buttons-1
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 0.7)
	if point_in_rect(b[#buttons].x, b[#buttons].y, b[topbutton].x + bWidth, b[topbutton].y + bHeight, mousex / vsx, mousey / vsy) then

		for i = 1, #b do
			if point_in_rect(b[i].x, b[i].y, b[i].x + bWidth, b[i].y + bHeight, mousex / vsx, mousey / vsy) or i == active_button then

				glBlending(GL_SRC_ALPHA, GL_ONE)
				RectRound(math.floor((b[i].x * vsx) + 0.5), math.floor((b[i].y * vsy) + 0.5), math.floor(((b[i].x + bWidth) * vsx) + 0.5), math.floor(((b[i].y + bHeight) * vsy) + 0.5), bgpadding * 0.5, 0,1,1,0, { 0.3, 0.3, 0.3, buttonstate and 0.25 or 0.15 }, { 1, 1, 1, buttonstate and 0.25 or 0.15 })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

				font:Print(b[i].text, math.floor((b[i].x * vsx) + 0.5), math.floor(((b[i].y + bHeight / 2) * vsy) + 0.5), math.floor((0.0115 * vsx) + 0.5), 'vo')
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

	local cb, i = clicked_button(buttons)
	if cb == "playpauseskip" then
		if Spring.GetGameFrame() > 1 then
			isPaused = not isPaused
			Spring.SendCommands('pause '..(isPaused and '1' or '0'))
			buttons[i].text = (isPaused and '  >>' or '  ||')
		else
			Spring.SendCommands("skip 1")
			buttons[i].text = "  ||"
		end
		sceduleUpdate = true
		return true
    elseif cb ~= "NOBUTTONCLICKED" then
        setReplaySpeed(speeds[i])
        sceduleUpdate = true
        return true
    end
end

function widget:Update(dt)
	isActive = #Spring.GetSelectedUnits() == 0
end

function widget:GameStart()
	widget:ViewResize()
	buttons[#buttons].text = "  ||"
end
