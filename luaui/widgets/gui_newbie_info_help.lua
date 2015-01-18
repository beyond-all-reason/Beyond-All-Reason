
function widget:GetInfo()
return {
	name    = "Help - Newbie Info",
	desc    = "Makes newbie info accessible by clicking 'help'",
	author  = "Bluestone",
	date    = "Jan 2015",
	license = "Mouthwash",
	layer   = 0,
	enabled = true,
}
end


local spIsGUIHidden = Spring.IsGUIHidden

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
end

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
local gameStarted = (Spring.GetGameFrame()>0)
function widget:GameStart()
    gameStarted = true
end

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
    glText("Help", textMargin, textMargin, textSize, "no")
end

function DeleteLists()
    if buttonGL then
        glDeleteList(buttonGL)
        buttonGL = nil
    end
    if battlesGL then
        glDeleteList(battlesGL)
        battlesGL = nil
    end
end

function widget:DrawScreen()
    if spIsGUIHidden() then return end
    if amNewbie and not gameStarted then return end
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
end

function widget:MousePress(x, y, button)
	if spIsGUIHidden() then return false end
    
	tx = (x - posX*vsx)/16
    ty = (y - posY*vsy)/16
    if tx < 0 or tx > 8 or ty < 0 or ty > 1 then return false end

    Spring.SendLuaRulesMsg("togglehelp")
end

function widget:Shutdown()
    Spring.SendLuaRulesMsg("closehelp")
end
