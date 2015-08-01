
function widget:GetInfo()
return {
	name    = "Keybind/Mouse Info",
	desc    = "Provides information on the controls",
	author  = "Bluestone",
	date    = "April 2015",
	license = "Mouthwash",
	layer   = 0,
	enabled = true,
}
end


local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local closeButtonTex = ":n:"..LUAUI_DIRNAME.."Images/close.dds"

local bgMargin = 10
local closeButtonSize = 30
local screenHeight = 486
local screenWidth = (350*3)-8

local customScale = 1

local spIsGUIHidden = Spring.IsGUIHidden
local showHelp = false

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glText = gl.Text
local glShape = gl.Shape
local glGetTextWidth = gl.GetTextWidth
local glGetTextHeight = gl.GetTextHeight

local bgColorMultiplier = 1

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local GL_FILL = GL.FILL
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_LINE_STRIP = GL.LINE_STRIP

local widgetScale = 1
local vsx, vsy = Spring.GetViewGeometry()
function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  screenX = (vsx*0.5) - (screenWidth/2)
  screenY = (vsy*0.5) + (screenHeight/2)
  widgetScale = (0.75 + (vsx*vsy / 7500000)) * customScale
  if keybinds then gl.DeleteList(keybinds) end
  keybinds = gl.CreateList(KeyBindScreen)
end

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
local gameStarted = (Spring.GetGameFrame()>0)
function widget:GameStart()
    gameStarted = true
end

-- button
local textSize = 0.75
local textMargin = 0.25
local lineWidth = 0.0625

local posX = 0.3
local posY = 0
local showOnceMore = false
local buttonGL
local startPosX = posX

local function DrawL()
	local vertices = {
		{v = {0, 1, 0}},
		{v = {0, 0, 0}},
		{v = {1, 0, 0}},
	}
	glShape(GL_LINE_STRIP, vertices)
end

function RectRound(px,py,sx,sy,cs)
	
	--local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.floor(sx),math.floor(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	gl.Texture(bgcorner)
	--if py <= 0 or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, py+cs, px+cs, py)		-- top left
	
	--if py <= 0 or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, py+cs, sx-cs, py)		-- top right
	
	--if sy >= vsy or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	--if sy >= vsy or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	gl.Texture(false)
end

function DrawButton()
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	RectRound(0,0,4,1,0.25)
    DrawL()
    glText("Keybinds", textMargin, textMargin, textSize, "no")
end

-- keybind info

include("configs/BA_HotkeyInfo.lua")
local bindColor			= "\255\255\210\070"
local titleColor		= "\255\254\254\254"
local descriptionColor	= "\255\192\190\180"

function DrawTextTable(t,x,y)
    local j = 0
    local height = 0
    local width = 0
    for _,t in pairs(t) do
      if t.blankLine then
        -- nothing here
      elseif t.title then
        -- title line
        local title = t[1] or ""
        local line = " " .. titleColor .. title -- a WTF whitespace is needed here, the colour doesn't show without it...
        gl.Text(line, x-16, y-((13)*j)+5, 14)
		screenWidth = math.max(glGetTextWidth(line)*13,screenWidth)
      else
        -- keybind line
        local bind = string.upper(t[1]) or ""
        local effect = t[2] or ""
        local line = " " .. bindColor .. bind .. "   " .. descriptionColor .. effect
        gl.Text(line, x-7, y-(13)*j, 11)
		width = math.max(glGetTextWidth(line)*11,width)
      end
      height = height + 13
      
	  j = j + 1
    end
    --screenHeight = math.max(screenHeight, height)
    --screenWidth = screenWidth + width
    return x,j
end

function KeyBindScreen()
    local vsx,vsy = Spring.GetViewGeometry()
    local x = screenX --rightwards
    local y = screenY --upwards
    
    gl.Color(0,0,0,0.8)
	RectRound(x-20-bgMargin,y-screenHeight-bgMargin,x+screenWidth+bgMargin,y+24+bgMargin,8)
	--glRect(x-20-bgMargin,y+24+bgMargin,x+screenWidth+bgMargin,y-screenHeight-bgMargin)
	
    gl.Color(1,1,1,1)
	gl.Texture(closeButtonTex)
	gl.TexRect(screenX+screenWidth-closeButtonSize,screenY+24,screenX+screenWidth,screenY+24-closeButtonSize)
	gl.Texture(false)
	
    DrawTextTable(General,x,y)
    x = x + 350
    DrawTextTable(Units_I_II,x,y)
    x = x + 350
    DrawTextTable(Units_III,x,y)
	
    gl.Color(1,1,1,1)
    gl.Text("These keybinds are set by default. If you remove/replace hotkey widgets, or use your own uikeys, they might stop working!", screenX-8, y-43*11, 12.5)
end


function widget:GameFrame(n)
	if n>0 and posX > 0 then
		posX = posX - 0.005
		if posX < 0 then posX = 0 end
		
		bgColorMultiplier = posX / startPosX
	end
end

function widget:DrawScreen()
    if spIsGUIHidden() then return end
    if amNewbie and not gameStarted then return end
    
    -- draw the button
    if not buttonGL then
        buttonGL = gl.CreateList(DrawButton)
    end
    
    glLineWidth(lineWidth)

    glPushMatrix()
        glTranslate(posX*vsx, posY*vsy, 0)
        glScale(17*widgetScale, 17*widgetScale, 1)
		glColor(0, 0, 0, (0.3*bgColorMultiplier))
        glCallList(buttonGL)
    glPopMatrix()

    glColor(1, 1, 1, 1)
    glLineWidth(1)
    
    -- draw the help
    if not keybinds then
        keybinds = gl.CreateList(KeyBindScreen)
    end
    
    if show or showOnceMore then
		glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(keybinds)
		glPopMatrix()
		if (WG['guishader_api'] ~= nil) then
			local rectX1 = ((screenX-20-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY1 = ((screenY+24+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'keybindinfo')
		end
		showOnceMore = false
    else
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].RemoveRect('keybindinfo')
		end
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	
	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end

function widget:MousePress(x, y, button)
	if spIsGUIHidden() then return false end
    if amNewbie and not gameStarted then return end
    
    if show then 
		-- on window
		local rectX1 = ((screenX-20-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+24+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
			
			-- on close button
			rectX1 = rectX2 - (closeButtonSize+bgMargin+bgMargin * widgetScale)
			rectY2 = rectY1 - (closeButtonSize+bgMargin+bgMargin * widgetScale)
			if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
				showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
				show = not show
			end
		else
			showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
			show = not show
		end
    else
		
		tx = (x - posX*vsx)/(17*widgetScale)
		ty = (y - posY*vsy)/(17*widgetScale)
		if tx < 0 or tx > 4 or ty < 0 or ty > 1 then return false end
		
		showOnceMore = show		-- show once more because the guishader lags behind, though this will not fully fix it
		show = not show
    end
end

function widget:Shutdown()
    if buttonGL then
        glDeleteList(buttonGL)
        buttonGL = nil
    end
    if keybinds then
        glDeleteList(keybinds)
        keybinds = nil
    end
end
