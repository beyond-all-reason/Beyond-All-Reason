function widget:GetInfo()
    return {
        name      = "Wind Speed",
        desc      = "Shows the current wind speed - Can be moved whilst middle or right click is held",
        author    = "Jazcash",
        date      = "Dec 9, 2012",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

-- Config
local rotationOn            = true
local vsSolarOn             = true -- If true, color is more of a guide of when winds are good to make

local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"

local customScale			= 1
local customPanelWidth 		= 46
local customPanelHeight 	= 39
local xRelPos, yRelPos		= 0.84, 0.963

local spEcho                = Spring.Echo
local spGetGameFrame        = Spring.GetGameFrame
local spGetMouseState		= Spring.GetMouseState
local spWind                = Spring.GetWind
local minWind               = Game.windMin
local maxWind               = Game.windMax

local glTranslate           = gl.Translate
local glRotate              = gl.Rotate
local glColor               = gl.Color
local glPushMatrix          = gl.PushMatrix
local glPopMatrix           = gl.PopMatrix
local glTexture             = gl.Texture
local glRect                = gl.Rect
local glTexRect             = gl.TexRect
local glText                = gl.Text
local glGetTextWidth		= gl.GetTextWidth

local glCreateList			= gl.CreateList
local glDeleteList			= gl.DeleteList
local glCallList			= gl.CallList

local format                = string.format
local upper                 = string.upper
local floor                 = math.floor
local max                   = math.max
local min                   = math.min

local textSize              = 13
local vsx, vsy				= gl.GetViewSizes()
local xPos, yPos            = xRelPos*vsx, yRelPos*vsy
local widgetScale			= customScale
local panelWidth 			= customPanelWidth
local panelHeight 			= customPanelHeight
local panelColor            = {0, 0, 0, 0.6}
local oorx, oory            = 10, 13
local count                 = 0
local speedMultiplier       = 8
local currentWind           = 0
local actualMax             = maxWind - minWind
local printWind             = ""
local curModID              = upper(Game.modShortName or "")
local check1x, check1y      = 6, 28 
local check2x, check2y      = 6, 6
local avgWind = math.floor((maxWind + minWind) / 2)
local speedTextPosX			= 0
local avgSpeedTextPosX		= 0
local avgSpeedTextPosY		= 0


--------------------------------------------------------------------------------

function GetWind()
    local _, _, _, currentWind = spWind()
    if currentWind > maxWind then currentWind = maxWind end
    local windPercent
    if vsSolarOn then
        windPercent = vsSolar(currentWind)
    else
        windPercent = vsWind(currentWind)
    end
    printWind = format('%.1f', currentWind)
    if minWind == maxWind then
        count = count + 1
    else
        count = count + windPercent*speedMultiplier
    end
end

function widget:GameFrame(frame)
	GetWind()
end

function vsSolar(currentWind)
    --return currentWind/solarEnergy[curModID]
    return currentWind/20
end

function vsWind(currentWind)
    return (currentWind-minWind)/actualMax
end

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	glRect(px+cs, py, sx-cs, sy)
	glRect(sx-cs, py+cs, sx, sy-cs)
	glRect(px+cs, py+cs, px, sy-cs)
	
	if py <= 0 or px <= 0 then glTexture(false) else glTexture(bgcorner) end
	glTexRect(px, py+cs, px+cs, py)		-- top left
	
	if py <= 0 or sx >= vsx then glTexture(false) else glTexture(bgcorner) end
	glTexRect(sx, py+cs, sx-cs, py)		-- top right
	
	if sy >= vsy or px <= 0 then glTexture(false) else glTexture(bgcorner) end
	glTexRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	if sy >= vsy or sx >= vsx then glTexture(false) else glTexture(bgcorner) end
	glTexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	glTexture(false)
end

-- using listst didnt improve much in performance
function createBackgroundList()
	backgroundList = glCreateList(function()
        glPushMatrix()
			glColor(panelColor)
			RectRound(xPos, yPos, xPos+panelWidth, yPos+panelHeight, 6)
			local borderPadding = 3.5
			glColor(1,1,1,0.025)
			RectRound(xPos+borderPadding, yPos+borderPadding, xPos+panelWidth-borderPadding, yPos+panelHeight-borderPadding, 6)
			
			glTranslate(xPos, yPos, 0)
			glTranslate(12*widgetScale, (panelHeight-(36*widgetScale))/2, 0) -- Spacing of icon
			glColor(1,1,1,0.25)
			glText(avgWind, -(15*widgetScale)+panelWidth, ((textSize*0.75*widgetScale)/8), textSize*0.75*widgetScale, 'r') -- Wind speed text
			glPushMatrix() -- Blades
				glTranslate(0, 9*widgetScale, 0)
	end)
end
function createBackgroundList2()
	backgroundList2 = glCreateList(function()
				glColor(1,1,1,0.3)
				glTexture(':c:LuaUI/Images/blades.png')
				glTexRect(0, 0, 27*widgetScale, 28*widgetScale)
				glTexture(false)
			glPopMatrix()    
			x,y = 9*widgetScale, 2*widgetScale -- Pole
			glTexture('LuaUI/Images/pole.png')
			glTexRect(x, y, (7*widgetScale)+x, y+(18*widgetScale))
			glTexture(false)
	end)
end

function widget:DrawScreen()
	glCallList(backgroundList)
	if rotationOn then -- Rotation
		glTranslate(oorx*widgetScale, oory*widgetScale, 0)
		glRotate(count, 0, 0, 1)
		glTranslate(-oorx*widgetScale, -oory*widgetScale, 0)
	end
	glCallList(backgroundList2)
	if spGetGameFrame() > 1 then
		glText(printWind, windTextPosX, windTextPosY, textSize*widgetScale, 'oc') -- Wind speed text
	end
	glPopMatrix()
end

function widget:TweakDrawScreen()
    glPushMatrix()
        glColor(panelColor)
        RectRound(xPos, yPos, xPos+panelWidth, yPos+panelHeight, 6)
        glTranslate(xPos, yPos, 0)
        drawCheckbox(check1x, check1y, rotationOn, "Rotation")
        --drawCheckbox(check2x, check2y, vsSolarOn, "Vs Solar")
    glPopMatrix() 
end

function widget:IsAbove(mx, my)
	return mx > xPos and my > yPos and mx < xPos + panelWidth and my < yPos + panelHeight
end

function drawCheckbox(x, y, state, text)
    glPushMatrix()
        glTranslate(x, y, 0)
        glColor(1, 1, 1, 0.2)
        glRect(0, 0, 16, 16)
        glColor(1, 1, 1, 1)
        if state then
            glTexture('LuaUI/Images/tick.png')
            glTexRect(0, 0, 16, 16)
            glTexture(false)
        end
        glText(text, 20, 4, 11, "n") 
    glPopMatrix()
end

function widget:TweakMousePress(mx, my, mb)
    if widgetHandler:InTweakMode() and mx > xPos and my > yPos and mx < xPos + panelWidth and my < yPos + panelHeight then
		if mb == 1 then 
			if mx > xPos+check1x and my > yPos+check1y and mx < (xPos+check1x+16) and my < (yPos+check1y+16) then
				rotationOn = not rotationOn
			elseif mx > xPos+check2x and my > yPos+check2y and mx < (xPos+check2x+16) and my < (yPos+check2y+16) then
				vsSolarOn = not vsSolarOn
			end
		elseif mb == 2 then
			return true
		end
    end
end

function widget:TweakMouseMove(mx, my, dx, dy)
    if xPos + dx >= -1 and xPos + panelWidth + dx - 1 <= vsx then 
		xRelPos = xRelPos + dx/vsx
	end
    if yPos + dy >= -1 and yPos + panelHeight + dy - 1<= vsy then 
		yRelPos = yRelPos + dy/vsy
	end
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	processGuishader()
	createBackgroundList()
end

function widget:GetConfigData()
	return {xRelPos = xRelPos, yRelPos = yRelPos, rotationOn = rotationOn, vsSolarOn = vsSolarOn}
end

function widget:SetConfigData(data)
	xRelPos = data.xRelPos or xRelPos
	yRelPos = data.yRelPos or yRelPos
	xPos = xRelPos * vsx
	yPos = yRelPos * vsy
    rotationOn = data.rotationOn
    vsSolarOn = data.vsSolarOn
end

function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("In CTRL+F11 mode: Hold \255\255\255\1middle mouse button\255\255\255\255 to drag the this display.\n\n"..
			"Small number in bottom right is the average map wind.")
	end
end

function init()
	vsx, vsy = gl.GetViewSizes()
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	widgetScale = (0.60 + (vsx*vsy / 5000000)) * customScale
	panelWidth 	= customPanelWidth * widgetScale
	panelHeight	= customPanelHeight * widgetScale
	windTextPosX = -(12*widgetScale)+(panelWidth*0.5)
	windTextPosY = (panelHeight/2)-((textSize*widgetScale)/2)
	createBackgroundList()
	createBackgroundList2()
	processGuishader()
end

function widget:ViewResize(newX,newY)
	init()
end

function processGuishader()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(xPos, yPos, xPos+panelWidth, yPos+panelHeight, 'winddisplay')
	end
end

function widget:Initialize()
	init()
	
	GetWind()
    --if maxWind > maxWindEnergy[curModID] then maxWind = maxWindEnergy[curModID] end
    if maxWind > 25 then maxWind = 25 end
    
	processGuishader()
end

function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('winddisplay')
	end
	
	if backgroundList ~= nil then
		glDeleteList(backgroundList)
		glDeleteList(backgroundList2)
	end
end
