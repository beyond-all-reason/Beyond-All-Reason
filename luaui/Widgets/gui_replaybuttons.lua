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


-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMouseState = Spring.GetMouseState
local spGetViewGeometry = Spring.GetViewGeometry

local vsx, vsy = spGetViewGeometry()

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
local isActive = false
local prevIsActive = false
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
	local mx, my, click = spGetMouseState()
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
		UiButton(mathFloor((b[i].x * vsx) + 0.5), mathFloor((b[i].y * vsy) + 0.5), mathFloor(((b[i].x + bWidth) * vsx) + 0.5), mathFloor(((b[i].y + bHeight) * vsy) + 0.5), 0,1,1,0, 1,1,1,1, nil, { 0, 0, 0, ui_opacity }, { 0.2, 0.2, 0.2, ui_opacity }, bgpadding * 0.5)
		font:Print(b[i].text, mathFloor((b[i].x * vsx) + 0.5), mathFloor(((b[i].y + bHeight / 2) * vsy) + 0.5), mathFloor((0.0115 * vsx) + 0.5), 'vo')
	end
	font:End()
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (0.5 + (vsx * vsy / 5700000))
	sceduleUpdate = true

	bHeight = buttonHeight * ui_scale
	bWidth = buttonWidth * ui_scale

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiButton = WG.FlowUI.Draw.Button

	font = WG['fonts'].getFont(2, 1.6)
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
	add_button(wPos.x, wPos.y, (spGetGameFrame() > 0 and "  ||" or "  skip"), "playpauseskip")
end

function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('replaybuttons')
	end
	gl.DeleteList(buttonsList)
end



function widget:DrawScreen()
	if not isActive then
		if WG['guishader'] and prevIsActive ~= isActive then
			WG['guishader'].RemoveDlist('replaybuttons')
		end
		return
	end

	if sceduleUpdate then
		sceduleUpdate = false
		if buttonsList then
			gl.DeleteList(buttonsList)
		end
		buttonsList = gl.CreateList(draw_buttons, buttons)

		local dy = (#speeds + 1) * bHeight
		if backgroundGuishader then
			gl.DeleteList(backgroundGuishader)
		end
		backgroundGuishader = gl.CreateList(function()
			RectRound(mathFloor((wPos.x * vsx) + 0.5), mathFloor((wPos.y * vsy) + 0.5), mathFloor(((wPos.x + bWidth) * vsx) + 0.5),  mathFloor(((wPos.y + dy) * vsy) + 0.5), elementCorner, 0, 1, 1, 0)
		end)
	end
	
	if WG['guishader'] and isActive and prevIsActive ~= isActive then
		WG['guishader'].InsertDlist(backgroundGuishader, 'replaybuttons')
	end

	if buttonsList then
		gl.CallList(buttonsList)
	end
	local mousex, mousey, buttonstate = spGetMouseState()
	local b = buttons
	local topbutton = #buttons-1
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 0.7)
	if point_in_rect(b[#buttons].x, b[#buttons].y, b[topbutton].x + bWidth, b[topbutton].y + bHeight, mousex / vsx, mousey / vsy) then

		for i = 1, #b do
			if point_in_rect(b[i].x, b[i].y, b[i].x + bWidth, b[i].y + bHeight, mousex / vsx, mousey / vsy) or i == active_button then

				glBlending(GL_SRC_ALPHA, GL_ONE)
				RectRound(mathFloor((b[i].x * vsx) + 0.5), mathFloor((b[i].y * vsy) + 0.5), mathFloor(((b[i].x + bWidth) * vsx) + 0.5), mathFloor(((b[i].y + bHeight) * vsy) + 0.5), bgpadding * 0.5, 0,1,1,0, { 0.3, 0.3, 0.3, buttonstate and 0.25 or 0.15 }, { 1, 1, 1, buttonstate and 0.25 or 0.15 })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

				font:Print(b[i].text, mathFloor((b[i].x * vsx) + 0.5), mathFloor(((b[i].y + bHeight / 2) * vsy) + 0.5), mathFloor((0.0115 * vsx) + 0.5), 'vo')
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
		if spGetGameFrame() > 1 then
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
	prevIsActive = isActive
	isActive = #Spring.GetSelectedUnits() == 0
end

function widget:GameStart()
	widget:ViewResize()
	buttons[#buttons].text = "  ||"
end
