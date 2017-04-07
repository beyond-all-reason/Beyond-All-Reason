
function widget:GetInfo()
	return {
		name      = "Tooltip",
		desc      = "Shows detailed unit stats",
		author    = "Floris",
		date      = "April 2017",
		license   = "GNU GPL, v2 or later",
		layer     = -9999999999,
		enabled   = true,  --  loaded by default?
	}
end

------------------------------------------------------------------------------------
-- Config
------------------------------------------------------------------------------------

local defaultDelay = 0.5
local usedFontSize = 13
local xOffset = 32
local yOffset = -32-usedFontSize

------------------------------------------------------------------------------------
-- Speedups
------------------------------------------------------------------------------------

local bgcorner				= LUAUI_DIRNAME.."Images/bgcorner.png"
local glColor = gl.Color
local glText = gl.Text
local glRect = gl.Rect
local glTranslate = gl.Translate

local spGetModKeyState = Spring.GetModKeyState
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetTooltip = Spring.GetCurrentTooltip

local vsx, vsy = Spring.GetViewGeometry()

local tooltips = {}

------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------


function RectRound(px,py,sx,sy,cs)
	
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.floor(sx),math.floor(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	gl.Texture(bgcorner)
	gl.TexRect(px, py+cs, px+cs, py)		-- top left
	gl.TexRect(sx, py+cs, sx-cs, py)		-- top right
	gl.TexRect(px, sy-cs, px+cs, sy)		-- bottom left
	gl.TexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	gl.Texture(false)
end

------------------------------------------------------------------------------------
-- Code
------------------------------------------------------------------------------------

function widget:Initialize()
	init()
end

function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('tooltip')
	end
end

function init()
	vsx, vsy = gl.GetViewSizes()
	widgetScale = (0.60 + (vsx*vsy / 5000000))
	
	WG['tooltip'] = {}
	WG['tooltip'].AddTooltip = function(name, area, value, delay)
		if value ~= nil or tooltips[name] ~= nil and tooltips[name].value ~= nil then
			if delay == nil then delay = defaultDelay end
			tooltips[name] = {area=area, delay=delay}
			if value ~= nil then
				tooltips[name].value = value
			end
		end
	end
	WG['tooltip'].ShowTooltip = function(name, value)
		if value ~= nil then
			tooltips[name] = {value=value}
		end
	end
end


function widget:ViewResize(x,y)
	init()
end


function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end


function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function drawTooltip(name, x, y)
	--Spring.Echo('Showing tooltip:  '..name)
	
	local maxWidth = 0
  
	local padding = 7 *widgetScale
	local posX = x + (xOffset*widgetScale) + padding
	local posY = y + (yOffset*widgetScale) + padding
	
	local fontSize = usedFontSize*widgetScale
	local maxWidth = 0
	local maxHeight = 0
	local lineHeight = fontSize + (fontSize/4)
	local lines = lines(tooltips[name].value)
	
	-- get text dimentions
	for i, line in ipairs(lines) do
		maxWidth = math.max(maxWidth, (gl.GetTextWidth(line)*fontSize), maxWidth)
		maxHeight = maxHeight + lineHeight
	end
	
	-- adjust position when needed
	if posX+maxWidth+padding+padding > vsx then
		posX = (posX - (posX - vsX)) - padding - padding
	end
	if posX - padding < 0 then
		posX = 0 + padding
	end
	if posY + padding > vsy then
		posY = (posY - (posY - vsy)) - padding
	end
	if posY-maxHeight-padding-padding < 0 then
		posY = 0 + maxHeight + padding + padding
	end
	
	-- draw background
	local cornersize = 0
	glColor(0.7,0.7,0.7,0.8)
	RectRound(posX-padding+cornersize, posY-maxHeight-padding+cornersize, posX+maxWidth+padding-cornersize, posY+padding-cornersize, 5*widgetScale)
	cornersize = 1.66*widgetScale
	glColor(0,0,0,0.25)
	RectRound(posX-padding+cornersize, posY-maxHeight-padding+cornersize, posX+maxWidth+padding-cornersize, posY+padding-cornersize, 4*widgetScale)
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(posX-padding-cornersize, posY-maxHeight-padding-cornersize, posX+maxWidth+padding+cornersize, posY+padding+cornersize, 'tooltip_'..name)
	end
	
	-- draw text
	maxHeight = -fontSize*0.9
	glTranslate(posX, posY, 0)
	glColor(1,1,1,1)
	for i, line in ipairs(lines) do
		glText(line, 0, maxHeight, fontSize, "o")
		maxHeight = maxHeight - lineHeight
	end
	glTranslate(-posX, -posY, 0)
end


function widget:DrawScreen()
	local x, y = spGetMouseState()
	local now = os.clock()
	
	for name, tooltip in pairs(tooltips) do
		if tooltip.area == nil or IsOnRect(x, y, tooltip.area[1], tooltip.area[2], tooltip.area[3], tooltip.area[4]) then
			if tooltip.area == nil then
				drawTooltip(name, x, y)
				tooltips[name] = nil
			else
				if tooltip.displayTime == nil then
					tooltip.displayTime = now + tooltip.delay
				elseif tooltip.displayTime <= now then
					drawTooltip(name, x, y)
				end
			end
		else
			if tooltip.displayTime ~= nil then
				tooltip.displayTime = nil
				if (WG['guishader_api'] ~= nil)  and not show then
					WG['guishader_api'].RemoveRect('tooltip_'..name)
				end
			end
		end
	end
end

------------------------------------------------------------------------------------
