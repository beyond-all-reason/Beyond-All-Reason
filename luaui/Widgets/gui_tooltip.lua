local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Tooltip",
		desc = "Shows tooltips",
		author = "Floris",
		date = "April 2017",
		license = "GNU GPL, v2 or later",
		layer = -1000000,
		enabled = true,
	}
end

--[[

-- Availible API functions:
WG['tooltip'].AddTooltip(name, area, value, delay, x, y, title)  -- area: {x1,y1,x2,y2}   value(optional): 'text'   delay(optional): #seconds   x/y(optional): display coordinates   title(optional): 'text'
WG['tooltip'].RemoveTooltip(name)

WG['tooltip'].ShowTooltip(name, value, x, y, title)    -- value(optional): 'text'   x/y (optional): display coordinates   title(optional): 'text'

You can use 'AddTooltip' to add a screen area that will display a tooltip when you hover over it

Use 'ShowTooltip' to directly show a tooltip, the name you give should be unique, and not one you desined in 'AddTooltip'
(the name will be deleted after use)

]]--

local defaultDelay = 0.37
local cfgFontSize = 14

local xOffset = 12
local yOffset = -xOffset

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = 1
local usedFontSize = cfgFontSize

local spGetMouseState = Spring.GetMouseState
local math_floor = math.floor
local math_ceil = math.ceil
local math_isInRect = math.isInRect
local string_lines = string.lines

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local tooltips = {}
local cleanupGuishaderAreas = {}
local font, font2
local RectRound, UiElement, bgpadding
local uiSec = 0


function widget:Initialize()
	widget:ViewResize(vsx, vsy)

	if WG['tooltip'] == nil then
		WG['tooltip'] = {}
		WG['tooltip'].getFontsize = function()
			return usedFontSize
		end
		WG['tooltip'].AddTooltip = function(name, area, value, delay, title)
			if ((value ~= nil or title ~= nil) and area[1] ~= nil and area[2] ~= nil and area[3] ~= nil and area[4] ~= nil) or (tooltips[name] ~= nil and (tooltips[name].value ~= nil or tooltips[name].title ~= nil)) then
				if delay == nil then
					delay = defaultDelay
				end
				if tooltips[name] == nil then
					tooltips[name] = {}
				end
				tooltips[name].area = area
				tooltips[name].delay = delay
				if value ~= nil or title ~= nil then
					tooltips[name].value = value ~= nil and tostring(value) or nil
					tooltips[name].title = title ~= nil and tostring(title) or nil
					if tooltips[name].dlist then
						tooltips[name].dlist = gl.DeleteList(tooltips[name].dlist)
					end
				end
			end
		end
		WG['tooltip'].RemoveTooltip = function(name)
			if tooltips[name] ~= nil then
				if tooltips[name].dlist then
					gl.DeleteList(tooltips[name].dlist)
				end
				cleanupGuishaderAreas[name] = true
				tooltips[name] = nil
			end
		end
		WG['tooltip'].ShowTooltip = function(name, value, x, y, title)
			if value ~= nil or title ~= nil then
				if not tooltips[name] then
					tooltips[name] = {}
					if tooltips[name].value ~= nil then
						tooltips[name].value = tostring(value)
					end
					if tooltips[name].title ~= nil then
						tooltips[name].title = tostring(title)
					end
				else
					tooltips[name].disabled = false
					if tooltips[name].value ~= value or tooltips[name].title ~= title then
						tooltips[name].value = value ~= nil and tostring(value) or nil
						tooltips[name].title = title ~= nil and tostring(title) or nil
						if tooltips[name].dlist then
							tooltips[name].dlist = gl.DeleteList(tooltips[name].dlist)
							cleanupGuishaderAreas[name] = true
						end
					end
				end
				if x ~= nil and y ~= nil then
					tooltips[name].pos = { x, y }
				end
			end
		end
	end
end

function widget:Shutdown()
	if WG['guishader'] then
		for name, tooltip in pairs(tooltips) do
			WG['guishader'].RemoveScreenRect('tooltip_' .. name)
			WG['guishader'].RemoveScreenRect('2tooltip_' .. name)
			if tooltip.dlist then
				gl.DeleteList(tooltip.dlist)
			end
		end
	end
	WG['tooltip'] = nil
end

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

	local outlineMult = math.clamp(1/(vsy/1400), 1, 2)
	font, loadedFontSize = WG['fonts'].getFont(nil, 1.1, 0.22 * outlineMult, 1.1+(outlineMult*0.2))
	font2 = WG['fonts'].getFont(fontfile2, 1.35, 0.22 * outlineMult, 1.1+(outlineMult*0.2))

	widgetScale = (1 + ((vsy - 850) / 900)) * (0.95 + (ui_scale - 1) / 2.5)
	usedFontSize = cfgFontSize * widgetScale
	yOffset = -math.floor(xOffset*0.5) - usedFontSize

	bgpadding = math.ceil(WG.FlowUI.elementPadding * 0.66)
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	for name, tooltip in pairs(tooltips) do
		if WG['guishader'] then
			WG['guishader'].RemoveScreenRect('tooltip_' .. name)
			WG['guishader'].RemoveScreenRect('2tooltip_' .. name)
		end
		if tooltip.dlist then
			gl.DeleteList(tooltip.dlist)
			tooltip.dlist = nil
		end
	end
end

local function drawTooltip(name, x, y)
	local paddingH = math_floor(9.5 * widgetScale)
	local paddingW = math_floor(paddingH * 1.42)

	local addX = math.floor(vsx*0.33)	-- temp add something so flowui doesnt think its near screen edge
	local addY = math.floor(vsy*0.5)	-- temp add something so flowui doesnt think its near screen edge

	if not tooltips[name].dlist then
		tooltips[name].dlist = gl.CreateList(function()

			local titleFontSize = math_floor(usedFontSize * 1.25)
			local fontSize = math_floor(usedFontSize)
			local lineHeight = fontSize + (fontSize / 4.5)
			local lines
			local maxWidth = 0
			local maxHeight = 0
			if tooltips[name].title and tooltips[name].title ~= '' then
				maxWidth = math_ceil(math.max(maxWidth, (font:GetTextWidth(tooltips[name].title) * titleFontSize)))
				maxHeight = math_ceil(maxHeight + (titleFontSize * 1.22))
			end
			if tooltips[name].value and tooltips[name].value ~= '' then
				-- get text dimentions
				lines = string_lines(tooltips[name].value)
				for i, line in ipairs(lines) do
					maxWidth = math_ceil(math.max(maxWidth, (font:GetTextWidth(line) * fontSize)))
					maxHeight = math_ceil(maxHeight + lineHeight)
				end
			end
			tooltips[name].maxWidth = maxWidth
			tooltips[name].maxHeight = maxHeight

			local borderSize = 1
			RectRound(addX-paddingW-borderSize, addY-maxHeight - paddingH-borderSize, addX+maxWidth + paddingW+borderSize, addY+paddingH+borderSize, bgpadding*1.4, 1,1,1,1, {0,0,0,0.08})
			UiElement(addX-paddingW, addY-maxHeight-paddingH, addX+maxWidth + paddingW, addY+paddingH, 1,1,1,1, 1,1,1,1, nil, {0.85, 0.85, 0.85, (WG['guishader'] and 0.7 or 0.93)}, {0, 0, 0, (WG['guishader'] and 0.5 or 0.56)}, bgpadding)

			-- draw text
			maxHeight = math_floor(-fontSize * 0.9)

			if tooltips[name].title and tooltips[name].title ~= '' then
				maxHeight = math_ceil(maxHeight - (titleFontSize * 0.1))
				font2:Begin()
				font2:Print('\255\205\255\205'..tooltips[name].title, addX, maxHeight+addY, titleFontSize, "o")
				font2:End()
				maxHeight = math_ceil(maxHeight - (titleFontSize * 1.12))
			end

			if tooltips[name].value and tooltips[name].value ~= '' then
				font:Begin()
				for i, line in ipairs(lines) do
					font:Print('\255\244\244\244' .. line, addX, maxHeight+addY, fontSize, "o")
					maxHeight = maxHeight - lineHeight
				end
				font:End()
			end
		end)
	end

	local maxWidth = tooltips[name].maxWidth
	local maxHeight = tooltips[name].maxHeight

	if maxWidth == nil or maxHeight == nil then
		return
	end

	-- adjust position when needed
	local posX = math_floor(x + paddingW)
	local posY = math_floor(y - paddingH)
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

	if WG['guishader'] then
		WG['guishader'].InsertScreenRect(posX - paddingW + bgpadding, posY - maxHeight - paddingH, posX + maxWidth + paddingW -bgpadding, posY + paddingH, 'tooltip_' .. name)
		WG['guishader'].InsertScreenRect(posX - paddingW, posY - maxHeight - paddingH + bgpadding, posX + maxWidth + paddingW, posY + paddingH - bgpadding, '2tooltip_' .. name)
	end
	gl.Translate(posX-addX, posY-addY, 0)
	gl.CallList(tooltips[name].dlist)
	gl.Translate(-posX+addX, -posY+addY, 0)
end

function widget:DrawScreen()
	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end
	local x, y = spGetMouseState()
	local now = os.clock()

	if WG['guishader'] then
		for name, _ in pairs(cleanupGuishaderAreas) do
			WG['guishader'].RemoveScreenRect('tooltip_' .. name)
			WG['guishader'].RemoveScreenRect('2tooltip_' .. name)
			cleanupGuishaderAreas[name] = nil
		end
	end
	for name, tooltip in pairs(tooltips) do
		if (tooltip.area == nil and not tooltip.disabled) or (tooltip.area and tooltip.area[4] ~= nil and math_isInRect(x, y, tooltip.area[1], tooltip.area[2], tooltip.area[3], tooltip.area[4])) then
			if tooltip.area == nil then
				if tooltip.pos ~= nil then
					drawTooltip(name, tooltip.pos[1], tooltip.pos[2])
				else
					drawTooltip(name, x + (xOffset * widgetScale), y + (yOffset * widgetScale))
				end
				cleanupGuishaderAreas[name] = true
				tooltips[name].disabled = true
			else
				if tooltip.displayTime == nil then
					tooltip.displayTime = now + tooltip.delay
				elseif tooltip.displayTime <= now then
					if tooltip.pos ~= nil then
						drawTooltip(name, tooltip.pos[1], tooltip.pos[2])
					else
						drawTooltip(name, x + (xOffset * widgetScale), y + (yOffset * widgetScale))
					end
				else
					cleanupGuishaderAreas[name] = true
					--Spring.Echo(name, os.clock())
				end
			end
		else
			if tooltip.displayTime ~= nil then
				tooltip.displayTime = nil
				if WG['guishader'] then
					WG['guishader'].RemoveScreenRect('tooltip_' .. name)
					WG['guishader'].RemoveScreenRect('2tooltip_' .. name)
				end
			end
		end
	end
end
