
function widget:GetInfo()
	return {
		name      = 'Energy Conversion Info',
		desc      = 'Displays energy conversion info',
		author    = 'Niobium',
		date      = 'May 2011',
		license   = 'GNU GPL v2',
		layer     = 0,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Var
--------------------------------------------------------------------------------
local enableAsSpec = true

local alterLevelFormat = string.char(137) .. '%i'

local customScale			= 0.85
local bgcorner				= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local barbg					= ":n:"..LUAUI_DIRNAME.."Images/resbar.dds"
local sliderMinimum			= 12
local sliderMaximum			= 88

local customPanelWidth 		= 115
local customPanelHeight 	= 37
local customPanelPadding	= 4
local customFontSize 		= 12

local xRelPos, yRelPos		= 0.88, 0.963
local vsx, vsy				= gl.GetViewSizes()
local widgetScale			= customScale
local panelWidth 			= customPanelWidth
local panelHeight 			= customPanelHeight
local panelPadding			= customPanelPadding
local fontSize				= customFontSize
local xPos, yPos            = xRelPos*vsx, yRelPos*vsy

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local format = string.format

local glBeginText = gl.BeginText
local glEndText = gl.EndText
local glTranslate			= gl.Translate
local glColor				= gl.Color
local glPushMatrix			= gl.PushMatrix
local glPopMatrix			= gl.PopMatrix
local glTexture				= gl.Texture
local glRect				= gl.Rect
local glTexRect				= gl.TexRect
local glText				= gl.Text
local glGetTextWidth		= gl.GetTextWidth
local glCreateList			= gl.CreateList
local glCallList			= gl.CallList
local glDeleteList			= gl.DeleteList
local enabled				= true

local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
local spGetSpectatingState = Spring.GetSpectatingState

local myPlayerID = Spring.GetMyPlayerID()
local _, _, spec, _, _, _, _, _ = Spring.GetPlayerInfo(myPlayerID)

--------------------------------------------------------------------------------
-- Funcs
--------------------------------------------------------------------------------

function widget:PlayerChanged()
	_, _, spec, _, _, _, _, _ = Spring.GetPlayerInfo(myPlayerID)
	if spec and not enableAsSpec then
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	
	if ( spec == true and not enableAsSpec) then
		Spring.Echo("<Energy Conversion Info> Spectator mode. Widget removed.")
		widgetHandler:RemoveWidget()
	else
		processGuishader()
	end
end

function processGuishader()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(xPos-panelPadding, yPos-panelPadding, xPos+panelWidth+panelPadding, yPos+panelHeight+panelPadding, 'energyconversion')
	end
end

function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('energyconversion')
	end
end

function RectRound(xPos,yPos,sx,sy,cs)
	local xPos,yPos,sx,sy,cs = math.floor(xPos),math.floor(yPos),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	glRect(xPos+cs, yPos, sx-cs, sy)
	glRect(sx-cs, yPos+cs, sx, sy-cs)
	glRect(xPos+cs, yPos+cs, xPos, sy-cs)
	
	if yPos <= 0 or xPos <= 0 then glTexture(false) else glTexture(bgcorner) end
	glTexRect(xPos, yPos+cs, xPos+cs, yPos)		-- top left
	
	if yPos <= 0 or sx >= vsx then glTexture(false) else glTexture(bgcorner) end
	glTexRect(sx, yPos+cs, sx-cs, yPos)		-- top right
	
	if sy >= vsy or xPos <= 0 then glTexture(false) else glTexture(bgcorner) end
	glTexRect(xPos, sy-cs, xPos+cs, sy)		-- bottom left
	
	if sy >= vsy or sx >= vsx then glTexture(false) else glTexture(bgcorner) end
	glTexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	glTexture(false)
end


function widget:DrawScreen()
    -- Var
    local myTeamID = spGetMyTeamID()
    local curLevel = spGetTeamRulesParam(myTeamID, 'mmLevel')
    local curUsage = spGetTeamRulesParam(myTeamID, 'mmUse')
    local curCapacity = spGetTeamRulesParam(myTeamID, 'mmCapacity')
    
    -- Positioning
    glPushMatrix()
        
        -- Panel
        glColor(0, 0, 0, 0.6)
        --glRect(0, 0, panelWidth, panelHeight)
        RectRound(xPos-panelPadding, yPos-panelPadding, xPos+panelWidth+panelPadding, yPos+panelHeight+panelPadding, 6*widgetScale)
        
        glTranslate(xPos, yPos, 0)
        -- Text
        glColor(1, 1, 1, 1)
        glBeginText()
            glText('Energy Conversion',panelPadding, panelHeight-panelPadding-fontSize, fontSize, 'od')
            --glText('Hover:', panelPadding, (panelHeight/2.3)-fontSize, fontSize, 'd')
            --glText('E usage:', panelPadding, panelPadding, fontSize, 'd')
            --glText(format('%i / %i', curUsage, curCapacity), panelWidth-panelPadding, panelPadding, fontSize, 'dr')
        glEndText()
        
        local sliderX = (panelWidth-(panelPadding*4)) * curLevel
        -- Bar
        glColor(0,0,0, 0.16)
        glRect((panelWidth-(panelPadding*2))-1, panelPadding+(panelHeight/7.5)-1, (panelPadding*2)+1, panelPadding+(panelHeight/4.7)+1)
        glColor(1,1,1,1)
        glTexture(barbg)
        glTexRect((panelWidth-(panelPadding*2)), panelPadding+(panelHeight/7.5), panelPadding*2, panelPadding+(panelHeight/4.7))
        
        glColor(1, 1, 0, 0.77)
        glTexture(barbg)
        glTexRect(sliderX + (panelPadding*2), panelPadding+(panelHeight/7.5), panelPadding*2, panelPadding+(panelHeight/4.7))
        
        -- Slider
        glColor(0, 0, 0, 0.33)
        glRect(sliderX + (panelPadding*2) + (panelWidth/50)+1, panelPadding-1, sliderX + (panelPadding*2) - (panelWidth/50)-1, panelPadding+(panelHeight/3.1)+1)
        glColor(0.88, 0.88, 0.1, 1)
        glTexRect(sliderX + (panelPadding*2)  + (panelWidth/50), panelPadding, sliderX + (panelPadding*2) - (panelWidth/50), panelPadding+(panelHeight/3.1))
        glTexture(false)
        
    glPopMatrix()
end

function widget:TweakMousePress(mx, my, mButton)
    if mButton == 2 then
        if mx >= xPos and my >= yPos and mx < xPos + panelWidth and my < yPos + panelHeight then
            return true
        end
    end
end
local draggingSlider = false
function widget:MousePress(mx, my, mButton)
	if mButton == 1 and not spGetSpectatingState() then
        local dx, dy = mx - xPos, my - yPos
        
        local hoverRight	= panelWidth-(panelPadding*2)
        local hoverBottom	= 0-customPanelPadding
        local hoverLeft		= panelPadding*2
        local hoverTop		= panelHeight+customPanelPadding
        if dx >= hoverLeft and dy >= hoverBottom and dx < hoverRight and dy < hoverTop then
            local newShare = 100 * (dx - hoverLeft) / (hoverRight - hoverLeft) -- [0, 100)
            if newShare < sliderMinimum then
				newShare = sliderMinimum
			end
            if newShare > sliderMaximum then
				newShare = sliderMaximum
			end
            spSendLuaRulesMsg(format(alterLevelFormat, newShare))
            draggingSlider = true
            return true
        end
    end
end

function widget:TweakMouseMove(mx, my, dx, dy, mButton)
    -- Dragging widget position
    if mButton == 2 then
		if xPos + dx >= panelPadding and xPos + panelWidth + dx + panelPadding<= vsx then 
			xRelPos = xRelPos + dx/vsx
		end
		if yPos + dy >= panelPadding and yPos + panelHeight + dy + panelPadding<= vsy then 
			yRelPos = yRelPos + dy/vsy
		end
		xPos, yPos = xRelPos * vsx,yRelPos * vsy
		
		processGuishader()
    end
end

function widget:MouseMove(mx, my, dx, dy, mButton)
	if mButton == 1 and draggingSlider then
        local dx, dy = mx - xPos, my - yPos
        local hoverRight	= panelWidth-(panelPadding*2)
        local hoverLeft		= panelPadding*2
		local newShare = 100 * (dx - hoverLeft) / (hoverRight - hoverLeft) -- [0, 100)
		if newShare < sliderMinimum then
			newShare = sliderMinimum
		end
		if newShare > sliderMaximum then
			newShare = sliderMaximum
		end
		if newShare > 100 then newShare = 100 end
		spSendLuaRulesMsg(format(alterLevelFormat, newShare))
	end
end

function widget:MouseRelease(mx, my, dx, dy, mButton)
	if draggingSlider then
		draggingSlider = false
	end
end

function widget:IsAbove(mx, my)
	local xPos = xPos-panelPadding
	local yPos = yPos-panelPadding
	local x2Pos = xPos+panelWidth+panelPadding
	local y2Pos = yPos+panelHeight+panelPadding
	return mx > xPos and my > yPos and mx < x2Pos and my < y2Pos
end

function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("In CTRL+F11 mode: Hold \255\255\255\1middle mouse button\255\255\255\255 to drag this display.\n\n"..
			"This controls when your metalmakers convert energy into metal.\n\nClick on it or drag to set a new value.")
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	
	widgetScale		= (0.60 + (vsx*vsy / 5000000)) * customScale
	panelWidth 		= customPanelWidth * widgetScale
	panelHeight		= customPanelHeight * widgetScale
	panelPadding	= customPanelPadding * widgetScale
	fontSize		= customFontSize * widgetScale
	
	processGuishader()
end

function widget:GetConfigData()
	return {xRelPos = xRelPos, yRelPos = yRelPos}
end

function widget:SetConfigData(data)
	xRelPos = data.xRelPos or xRelPos
	yRelPos = data.yRelPos or yRelPos
	xPos = xRelPos * vsx
	yPos = yRelPos * vsy
end
