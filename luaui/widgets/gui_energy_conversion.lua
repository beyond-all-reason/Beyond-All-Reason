
function widget:GetInfo()
	return {
		name      = 'Energy Conversion Info',
		desc      = 'Displays energy conversion info',
		author    = 'Niobium (mod by Finkky)',
		date      = 'May 2011',
		license   = 'GNU GPL v2.1',
		layer     = 0,
		enabled   = true,
	}
end
--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local efficiencyClassBoxEnabled = true

local EfficiencyThresholds = { 
	{title="S", 		color={r = 0.3, 	g = 0.6, 	b = 1, a = 0.5}, e=0.018}, 
	{title="A+", 		color={r = 0.1, 	g = 1, 		b = 0.3, 	a = 0.5}, e=0.018}, 
	{title="A+", 		color={r = 0.1, 	g = 1, 		b = 0, 	a = 0.5}, e=0.017}, 
	{title="A", 		color={r = 0.4, 	g = 1, 		b = 0, 	a = 0.5}, e=0.016}, 
	{title="B", 		color={r = 0.7, 	g = 1, 		b = 0, 	a = 0.5}, e=0.015}, 
	{title="C", 		color={r = 1, 	g = 1, 		b = 0, 	a = 0.5}, e=0.014}, 
	{title="D", 		color={r = 1, 	g = 0.5, 	b = 0, 	a = 0.5}, e=0.013}, 
	{title="E", 		color={r = 1, 	g = 0, 		b = 0, 	a = 0.5}, e=0.012}, 
	{title="E-", 		color={r = 0.8, 	g = 0, 		b = 0, 	a = 0.5}, e=0.001}, 
	{title="/", 			color={r = 0.6, 	g = 0.6, 	b = 0.6,	a = 0.5}, e=0}
}


--------------------------------------------------------------------------------
-- Var
--------------------------------------------------------------------------------
local alterLevelFormat = string.char(137) .. '%i'

local px, py = 500, 100
local sx, sy = 250, 80
local bx, by = 21, 20
local lrBorder = 7

local hoverLeft = 53
local hoverRight = sx - 7




local barTop = 40 + 10
local barThickness = 5
local barBottom = barTop - barThickness

local hoverTop = barTop + 3
local hoverBottom = barBottom - 3
local hoverHWidth = 3

local resourceRefreshRate = 16
--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local format = string.format

local glColor = gl.Color
local glRect = gl.Rect
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glBeginText = gl.BeginText
local glEndText = gl.EndText
local glText = gl.Text

local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamResources = Spring.GetTeamResources

local convertCapacities = VFS.Include('LuaRules/Configs/maker_defs.lua')

--table.sort(EfficiencyThresholds, function(a,b) return a.e>b.e end)
local WhiteStr   = "\255\255\255\255"
local BlackStr   = "\255\001\001\001"
local GreyStr    = "\255\192\192\192"
local RedStr     = "\255\255\001\001"
local GreenStr   = "\255\001\255\001"
local BlueStr    = "\255\001\001\255"
local YellowStr  = "\255\255\255\001"

local r, g, b, a
local myTeamID
local curLevel
local curUsage
local curCapacity
local curAvgEffi
local eCur, eStor
local capacityColor
local mProducedColor
local relativeCapacity
local hasData = false


local function getLetter(effi)

	for a, v in ipairs(EfficiencyThresholds) do
		if (effi >= v.e) then 
			return v
		end
	end
	return EfficiencyThresholds[#EfficiencyThresholds-1]
end 


function EfficiencyThresholds:getTextColor(effi)
	local nearestHigherT, nearestLowerT

	for a, v in ipairs(self) do
		
		if (effi >= v.e) then
			nearestLowerT = v
			break
		end
		nearestHigherT = v
	end
	
	if not nearestLowerT then 
		nearestLowerT = self[#self]
	end
	
	local rel
	
	if not nearestHigherT then 
		nearestHigherT = nearestLowerT 
		rel = 0
	else
		rel = (effi - nearestLowerT.e) / (nearestHigherT.e -  nearestLowerT.e)
	end
	
	
	return 
		(nearestLowerT.color.r + rel * (nearestHigherT.color.r - nearestLowerT.color.r)), 
		(nearestLowerT.color.g + rel * (nearestHigherT.color.g - nearestLowerT.color.g)), 
		(nearestLowerT.color.b + rel * (nearestHigherT.color.b - nearestLowerT.color.b)),
		(nearestLowerT.color.a + rel * (nearestHigherT.color.a - nearestLowerT.color.a)) 
end


local function drawBorder(x0, y0, x1, y1, t)
	glRect(x0, 		y0,		x1, 		y0 + t) -- TOP
	glRect(x0, 		y1,		x1,  		y1 - t) -- BOTTOM
	glRect(x0, 		y0 + t, 	x0 + t,  y1  - t) -- LEFT
	glRect(x1 - t, 	y0 + t,	x1, 		y1  - t) -- RIGHT
end

local function refreshData() 

	myTeamID = spGetMyTeamID()
	curLevel = spGetTeamRulesParam(myTeamID, 'mmLevel')
	curUsage = spGetTeamRulesParam(myTeamID, 'mmUse')
	curCapacity = spGetTeamRulesParam(myTeamID, 'mmCapacity')
	curAvgEffi = spGetTeamRulesParam(myTeamID, 'mmAvgEffi')
	eCur, eStor = spGetTeamResources(myTeamID, 'energy')

	mProducedColor = (curUsage > 0 and curAvgEffi > 0)  and GreenStr .. '+' or YellowStr
	eDrainedColor = (curUsage > 0 and curAvgEffi > 0)  and RedStr .. '-' or YellowStr
	
	if not (eCur and eStor) or (eStor <= 0) then 
		eStor = 1
		eCur = 1
	end

	
	local rc= curUsage/curCapacity
	
	if rc<0.8 then capacityColor = GreenStr elseif rc<1 then capacityColor = WhiteStr else capacityColor = YellowStr end
	
	r, g, b, a = EfficiencyThresholds:getTextColor(curAvgEffi)
	
	hasData = true
end
--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
function widget:Initialize()

	WG.energyConversion = {convertCapacities = convertCapacities}
		
	local playerID = Spring.GetMyPlayerID()
	local _, _, spec, _, _, _, _, _ = Spring.GetPlayerInfo(playerID)
		
	if ( spec == true ) then
		Spring.Echo("<Energy Conversion Info> Spectator mode. Widget removed.")
		widgetHandler:RemoveWidget()
	end
	
end


function widget:GameFrame(n)
	if (n % resourceRefreshRate == 1) then
		refreshData() 
	end
end

function widget:DrawScreen()
	
	if not hasData then refreshData() end

    -- Positioning
    glPushMatrix()
	glTranslate(px, py, 0)
	
	-- Panel
	glColor(0, 0, 0, 0.5)
	glRect(0, 0, sx, sy)
	glColor(0, 0, 0, 0.8)
	drawBorder(0, 0, sx, sy, 1)

	-- Class box
	if efficiencyClassBoxEnabled then
		local currentRating  = getLetter(curAvgEffi)
		local t = 1
		glColor(r, g, b, 0.5)
		drawBorder(sx - bx, 0, sx, by, t)
		
		glColor(r, g, b, 0.3)
		glRect(sx - bx + t, t, sx - t, by- t)
		
		glColor(r, g, b, 1)
		glText(currentRating.title, sx-bx/2, by/2 +1, 12, 'cv') 
	end
	
	-- Text
	glBeginText()

		glText('Energy Conversion', lrBorder, 58, 12, 'do')
		glText(format('%s%.1f m%s / %s%.0f e', mProducedColor, curAvgEffi * curUsage, WhiteStr, eDrainedColor, curUsage), sx - lrBorder, 58, 12, 'dr')
		
		glText('Hover:', lrBorder, 40, 12, 'do')
		
		glText('Usage:', lrBorder, 22, 12, 'do')
		if (curCapacity > 0) then
			glText(format('%i / %i (%s%i%%%s)', curUsage, curCapacity, capacityColor, curUsage/curCapacity*100,WhiteStr), sx - lrBorder, 22, 12, 'dr')
		else
			glText(format('no capacity', RedStr), sx - lrBorder, 22, 12, 'dr')
		end
		
		glText('Efficiency (Class)', lrBorder, 4, 12, 'do')
		glText(format('%s  %.2f m%s / 1000 e',   format("%c%c%c%c", 255, r*254 + 1, g*254 + 1, b*254 + 1),  curAvgEffi * 1000, WhiteStr), sx - lrBorder -bx, 4, 12, 'dr')

	glEndText()

	
	
	-- Bar
	glColor(0, 0, 0, 0.5)
	glRect(hoverLeft, barBottom, hoverRight, barTop)
	local energyRelative = eCur/eStor
	
	glColor(1, 1, 0, 1)
	glRect(hoverLeft+1, barBottom+1, hoverLeft+1 + energyRelative *  (hoverRight - hoverLeft - 2), barTop - 1)
	
	-- Slider
	local sliderX = hoverLeft + (hoverRight - hoverLeft) * curLevel
	glColor(1, 0, 0, 0.75)
	glRect(sliderX - hoverHWidth, hoverBottom, sliderX + hoverHWidth, hoverTop)
	
	glColor(0, 0, 0, 1)
	drawBorder(sliderX - hoverHWidth, hoverBottom, sliderX + hoverHWidth, hoverTop, 1)
        
    glPopMatrix()
end

function widget:MousePress(mx, my, mButton)
    if mButton == 2 or mButton == 3 then
        if mx >= px and my >= py and mx < px + sx and my < py + sy then
            return true
        end
    elseif mButton == 1 and not spGetSpectatingState() then
        local dx, dy = mx - px, my - py
        if dx >= hoverLeft and dy >= hoverBottom and dx < hoverRight and dy < hoverTop then
            local newShare = 100 * (dx - hoverLeft) / (hoverRight - hoverLeft) -- [0, 100)
            spSendLuaRulesMsg(format(alterLevelFormat, newShare))
            return true
        end
    end
end

function widget:MouseMove(mx, my, dx, dy, mButton)
    -- Dragging
    if mButton == 2 or mButton == 3 then
        px = px + dx
        py = py + dy
    end
end

function widget:GetConfigData()
	local vsx, vsy = gl.GetViewSizes()
	return {px / vsx, py / vsy}
end

function widget:SetConfigData(data)
	local vsx, vsy = gl.GetViewSizes()
	px = math.floor(math.max(0, vsx * math.min(data[1] or 0, 0.95)))
	py = math.floor(math.max(0, vsy * math.min(data[2] or 0, 0.95)))
end
