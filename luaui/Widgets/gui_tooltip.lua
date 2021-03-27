function widget:GetInfo()
	return {
		name = "Tooltip",
		desc = "Shows tooltips",
		author = "Floris",
		date = "April 2017",
		layer = -9999999999,
		enabled = true, --  loaded by default?
	}
end

------------------------------------------------------------------------------------
-- Info
------------------------------------------------------------------------------------
--[[

-- Availible API functions:
WG['tooltip'].AddTooltip(name, area, value, delay, x, y)  -- area: {x1,y1,x2,y2}   value: 'text'   delay(optional): #seconds   x/y(optional): display coordinates
WG['tooltip'].RemoveTooltip(name)

WG['tooltip'].ShowTooltip(name, value, x, y)    -- x/y (optional): display coordinates

You can use 'AddTooltip' to add a screen area that will display a tooltip when you hover over it

Use 'ShowTooltip' to directly show a tooltip, the name you give should be unique, and not one you desined in 'AddTooltip'
(the name will be deleted after use)

]]--
------------------------------------------------------------------------------------
-- Config
------------------------------------------------------------------------------------

local backgroundTexture = "LuaUI/Images/backgroundtile.png"
local ui_tileopacity = 0.012
local bgtexScale = tonumber(Spring.GetConfigFloat("ui_tilescale", 7) or 7)	-- lower = smaller tiles
local bgtexSize

local vsx, vsy = Spring.GetViewGeometry()

local defaultDelay = 0.4
local cfgFontSize = 14

local xOffset = 28
local yOffset = -xOffset

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")

local widgetScale = 1
local usedFontSize = cfgFontSize
local bgpadding = math.ceil(Spring.FlowUI.elementPadding * 0.66)

------------------------------------------------------------------------------------
-- Speedups
------------------------------------------------------------------------------------

local glColor = gl.Color
local glText = gl.Text
local glRect = gl.Rect
local glTranslate = gl.Translate

local spGetModKeyState = Spring.GetModKeyState
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetTooltip = Spring.GetCurrentTooltip

local RectRound = Spring.FlowUI.Draw.RectRound
local UiElement = Spring.FlowUI.Draw.Element

local math_floor = math.floor
local math_ceil = math.ceil

local vsx, vsy = Spring.GetViewGeometry()
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local tooltips = {}

local font, chobbyInterface

------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------

function widget:Initialize()
	widget:ViewResize()
	init()
end

function widget:Shutdown()
	if WG['guishader'] then
		for name, tooltip in pairs(tooltips) do
			WG['guishader'].DeleteScreenDlist('tooltip_' .. name)
		end
	end
	WG['tooltip'] = nil
end

function init()
	widgetScale = (1 + ((vsy - 850) / 900)) * (0.95 + (ui_scale - 1) / 2.5)
	usedFontSize = cfgFontSize * widgetScale
	yOffset = -xOffset - usedFontSize

	if WG['tooltip'] == nil then
		WG['tooltip'] = {}
		WG['tooltip'].AddTooltip = function(name, area, value, delay)
			if (value ~= nil and area[1] ~= nil and area[2] ~= nil and area[3] ~= nil and area[4] ~= nil) or tooltips[name] ~= nil and tooltips[name].value ~= nil then
				if delay == nil then
					delay = defaultDelay
				end
				if tooltips[name] == nil then
					tooltips[name] = {}
				end
				tooltips[name].area = area
				tooltips[name].delay = delay
				if value ~= nil then
					tooltips[name].value = tostring(value)
				end
			end
		end
		WG['tooltip'].RemoveTooltip = function(name)
			if tooltips[name] ~= nil then
				tooltips[name] = nil
			end
		end
		WG['tooltip'].ShowTooltip = function(name, value, x, y)
			if value ~= nil then
				tooltips[name] = { value = tostring(value) }
				if x ~= nil and y ~= nil then
					tooltips[name].pos = { x, y }
				end
			end
		end
	end
end

local uiSec = 0
function widget:Update(dt)
	uiSec = uiSec + dt
	if uiSec > 0.5 then
		uiSec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize(vsx, vsy)
		end
	end
end

function widget:ViewResize(x, y)
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont(fontfile)

	bgpadding = math.ceil(Spring.FlowUI.elementPadding * 0.66)

	init()
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function lines(str)
	local t = {}
	local function helper(line)
		t[#t + 1] = line
		return ""
	end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

function drawTooltip(name, x, y)
	local paddingH = math_floor(9.5 * widgetScale)
	local paddingW = math_floor(paddingH * 1.42)
	local posX = math_floor(x + paddingW)
	local posY = math_floor(y - paddingH)

	local fontSize = math_floor(usedFontSize)
	local maxWidth = 0
	local maxHeight = 0
	local lineHeight = fontSize + (fontSize / 4.5)
	local lines = lines(tooltips[name].value)

	-- get text dimentions
	for i, line in ipairs(lines) do
		maxWidth = math_ceil(math.max(maxWidth, (font:GetTextWidth(line) * fontSize)))
		maxHeight = math_ceil(maxHeight + lineHeight)
	end
	-- adjust position when needed
	if posX + maxWidth + paddingW + paddingW > vsx then
		posX = math_floor(posX - maxWidth - paddingW - paddingW - (xOffset * widgetScale * 2))
	end
	if posX - paddingW < 0 then
		posX = 0 + paddingW
	end
	if posY + paddingH > vsy then
		posY = (posY - (posY - vsy)) - paddingH
	end
	if posY - maxHeight - paddingH - paddingH < 0 then
		posY = 0 + maxHeight + paddingH + paddingH
	end

	UiElement(posX - paddingW, posY - maxHeight - paddingH, posX + maxWidth + paddingW, posY + paddingH, 1,1,1,1, 1,1,1,1, nil, {0.85, 0.85, 0.85, (WG['guishader'] and 0.72 or 0.94)}, {0, 0, 0, (WG['guishader'] and 0.52 or 0.56)}, bgpadding)
	if WG['guishader'] then
		WG['guishader'].InsertScreenDlist(gl.CreateList(function()
			RectRound(posX - paddingW, posY - maxHeight - paddingH, posX + maxWidth + paddingW, posY + paddingH, 3.3 * widgetScale)
		end), 'tooltip_' .. name)
	end

	-- draw text
	maxHeight = math_floor(-fontSize * 0.93)
	glTranslate(posX, posY, 0)
	font:Begin()
	--font:SetTextColor(0.95,0.95,0.95,1)
	--font:SetOutlineColor(0.3,0.3,0.3,0.3)
	for i, line in ipairs(lines) do
		font:Print('\255\244\244\244' .. line, 0, maxHeight, fontSize, "o")
		maxHeight = maxHeight - lineHeight
	end
	font:End()
	glTranslate(-posX, -posY, 0)
end

local cleanupGuishaderAreas = {}
function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	if (WG['topbar'] and WG['topbar'].showingQuit()) then
		return
	end
	local x, y = spGetMouseState()
	local now = os.clock()

	if WG['guishader'] then
		for name, _ in pairs(cleanupGuishaderAreas) do
			WG['guishader'].DeleteScreenDlist(name)
			cleanupGuishaderAreas[name] = nil
		end
	end
	for name, tooltip in pairs(tooltips) do
		if tooltip.area == nil or (tooltip.area[4] ~= nil and IsOnRect(x, y, tooltip.area[1], tooltip.area[2], tooltip.area[3], tooltip.area[4])) then
			if tooltip.area == nil then
				if tooltip.pos ~= nil then
					drawTooltip(name, tooltip.pos[1], tooltip.pos[2])
				else
					drawTooltip(name, x + (xOffset * widgetScale), y + (yOffset * widgetScale))
				end
				tooltips[name] = nil
				cleanupGuishaderAreas['tooltip_' .. name] = true
			else
				if tooltip.displayTime == nil then
					tooltip.displayTime = now + tooltip.delay
				elseif tooltip.displayTime <= now then
					if tooltip.pos ~= nil then
						drawTooltip(name, tooltip.pos[1], tooltip.pos[2])
					else
						drawTooltip(name, x + (xOffset * widgetScale), y + (yOffset * widgetScale))
					end
				end
			end
		else
			if tooltip.displayTime ~= nil then
				tooltip.displayTime = nil
				if WG['guishader'] then
					WG['guishader'].DeleteScreenDlist('tooltip_' .. name)
				end
			end
		end
	end
end


