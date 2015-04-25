
function widget:GetInfo()
return {
	name    = "Keybind Info",
	desc    = "Provides menu to display default keybinds",
	author  = "Bluestone",
	date    = "April 2015",
	license = "Mouthwash",
	layer   = 0,
	enabled = true,
}
end


local spIsGUIHidden = Spring.IsGUIHidden
local showHelp = false

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glText = gl.Text
local glShape = gl.Shape

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

local vsx, vsy = Spring.GetViewGeometry()
function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  if keybinds then gl.DeleteList(keybinds) end
end

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
local gameStarted = (Spring.GetGameFrame()>0)
function widget:GameStart()
    gameStarted = true
end

-- button
local textSize = 0.75
local textMargin = 0.125
local lineWidth = 0.0625

local posX = 0.4
local posY = 0

local buttonGL

local function DrawL()
	local vertices = {
		{v = {0, 1, 0}},
		{v = {0, 0, 0}},
		{v = {1, 0, 0}},
	}
	glShape(GL_LINE_STRIP, vertices)
end

function DrawButton()
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
    glColor(0, 0, 0, 0.2)
    glRect(0, 0, 8, 1)
    DrawL()
    glText("Keybinds", textMargin, textMargin, textSize, "no")
end

-- keybind info

include("configs/BA_HotkeyInfo.lua")
local blue = "\255\21\21\255"
local white = "\255\255\255\255"
local green = "\255\151\255\151"

function DrawTextTable(t,x,y)
    local j = 0
    for _,t in pairs(t) do
      if t.blankLine then
        -- nothing here
      elseif t.title then
        -- title line
        local title = t[1] or ""
        local line = " " .. green .. title -- a WTF whitespace is needed here, the colour doesn't show without it...
        gl.Text(line, x+10, y-(13)*j, 11)     
      else
        -- keybind line
        local bind = t[1] or ""
        local effect = t[2] or ""
        local line = blue .. bind .. " : " .. white .. effect
        gl.Text(line, x, y-(13)*j, 11) 
      end
      
	  j = j + 1
    end
    
    return x,j
end

function KeyBindScreen()
    local vsx,vsy = Spring.GetViewGeometry()
    local x = vsx*0.2 --rightwards
    local y = vsy*(1-0.27) --upwards
    
    DrawTextTable(General,x,y)
    x = x + 350
    DrawTextTable(Units_I_II,x,y)
    x = x + 350
    DrawTextTable(Units_III,x,y)   

    gl.Text("These keybinds are set by default. If you remove/replace hotkey widgets, or use your own uikeys, they might stop working!", vsx*0.2, y-43*11, 11)
end

--

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
        glScale(16, 16, 1)
        glCallList(buttonGL)
    glPopMatrix()

    glColor(1, 1, 1, 1)
    glLineWidth(1)
    
    -- draw the help
    if not keybinds then
        keybinds = gl.CreateList(KeyBindScreen)
    end
    
    if show then
        glCallList(keybinds)
    end
end

function widget:MousePress(x, y, button)
	if spIsGUIHidden() then return false end
    if amNewbie and not gameStarted then return end
    
	tx = (x - posX*vsx)/16
    ty = (y - posY*vsy)/16
    if tx < 0 or tx > 8 or ty < 0 or ty > 1 then return false end

    show = not show
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
