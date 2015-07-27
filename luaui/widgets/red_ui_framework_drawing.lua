function widget:GetInfo()
	return {
	version   = "9",
	name      = "Red_Drawing",
	desc      = "Drawing widget for Red UI Framework",
	author    = "Regret",
	date      = "29 may 2015",
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = true,
	}
end

local consoleBlur = false
local blurShaderStartColor = 0.31		-- will add guishader if alpha >= ...

function widget:TextCommand(command)
	if (string.find(command, "consoleblur") == 1  and  string.len(command) == 11) then 
		if (WG['guishader_api'] ~= nil) then
			consoleBlur = not consoleBlur
			processConsoleBlur()
			if consoleBlur then
				Spring.Echo("Console blur:  enabled")
			else
				Spring.Echo("Console blur:  disabled")
			end
		else
			Spring.Echo("Console blur: enable 'GUI-Shader' widget first!")
		end
	end
end

function processConsoleBlur()
	if not consoleBlur then
		blurShaderStartColor = 0.34		-- will add guishader if alpha >= ...
	else
		blurShaderStartColor = 0
	end
end

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.consoleBlur = consoleBlur
    return savedTable
end

function widget:SetConfigData(data)
    if data.consoleBlur ~= nil 	then
		consoleBlur = data.consoleBlur 
		processConsoleBlur()
	end
end

local bgcornerSize = 8
local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
	
local TN = "Red_Drawing" --WG name for function list
local version = 9


local vsx,vsy = widgetHandler:GetViewSizes()
if (vsx == 1) then --hax for windowed mode
	vsx,vsy = Spring.GetWindowGeometry()
end

local sIsGUIHidden = Spring.IsGUIHidden

local F = {} --function table
local Todo = {} --function queue
local StartList

local glText = gl.Text
local glTexture = gl.Texture
local glColor = gl.Color
local glRect = gl.Rect
local glTexRect = gl.TexRect
local glMatrixMode = gl.MatrixMode
local glLoadIdentity = gl.LoadIdentity
local glOrtho = gl.Ortho
local glTranslate = gl.Translate
local glResetState = gl.ResetState
local glResetMatrices = gl.ResetMatrices
local glDepthTest = gl.DepthTest
local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glCreateList = gl.CreateList
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glScale = gl.Scale

local GL_ONE                   = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA   = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA             = GL.SRC_ALPHA
local glBlending               = gl.Blending

local GL_LINE_LOOP = GL.LINE_LOOP
local GL_COLOR_BUFFER_BIT = GL.COLOR_BUFFER_BIT
local GL_PROJECTION = GL.PROJECTION
local GL_MODELVIEW = GL.MODELVIEW

local blurRect = {}
local newBlurRect = {}


local function Color(c)
	glColor(c[1],c[2],c[3],c[4])
end

local function Text(px,py,fontsize,text,options,c)
	glPushMatrix()
	if (c) then
		glColor(c[1],c[2],c[3],c[4])
	else
		glColor(1,1,1,1)
	end
	glTranslate(px,py+fontsize,0)
	if (options) then
		options = options.."d" --fuck you jK
	else
		options = "d"
	end
	glScale(1,-1,1) --flip
	glText(text,0,0,fontsize,options)
	glPopMatrix()
end

local function Border(px,py,sx,sy,width,c)
	if (width == nil) then
		width = 1
	elseif (width == 0) then
		return
	end
	px,py,sx,sy = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy)
	
	glPushMatrix()
	if (c) then
		glColor(c[1],c[2],c[3],c[4])
	else
		glColor(1,1,1,1)
	end
	glTranslate(px,py,0)
	glRect(0,0,sx,width) --top
	glRect(0,width,width,sy) --left
	glRect(width,sy-width,sx-width,sy) --bottom
	glRect(sx-width,width,sx,sy) --right
	glPopMatrix()
	
	-- add blur shader
	if c and c[4] >= blurShaderStartColor then
		newBlurRect[px..' '..py..' '..sx..' '..sy] = {px=px,py=py,sx=sx,sy=sy}
	end
end

local function Rect(px,py,sx,sy,c,scale)
	if (c) then
		glColor(c[1],c[2],c[3],c[4])
	else
		glColor(1,1,1,1)
	end
	if scale ~= nil and scale ~= 1 then
		px = px + ((sx * (1-scale))/2)
		py = py + ((sy * (1-scale))/2)
		sx = sx * scale
		sy = sy * scale
	end
	px,py,sx,sy = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy)
	glRect(px,py,px+sx,py+sy)
end

local function RectRound(px,py,sx,sy,c,cs,scale,glone)

	-- add the missing border size (cause normal border will not be used when this function gets called)
	px = px - 1
	py = py - 1
	sx = sx + 2
	sy = sy + 2
	
	if (c) then
		glColor(c[1],c[2],c[3],c[4])
	else
		glColor(1,1,1,1)
	end
	
	if cs == nil then
		cs = 4
	end
	
	if glone then
		glBlending(GL_SRC_ALPHA, GL_ONE)
	end
	-- add blur shader
	if c and c[4] >= blurShaderStartColor then
		newBlurRect[px..' '..py..' '..sx..' '..sy] = {px=px,py=py,sx=sx,sy=sy}
	end
	
	--[[px = math.floor(px)
	py = math.floor(py)
	sx = math.ceil(px+sx)
	sy = math.ceil(p+sy)
	]]--
	
	if scale ~= nil and scale ~= 1 then
		px = px + ((sx * (1-scale))/2)
		py = py + ((sy * (1-scale))/2)
		sx = sx * scale
		sy = sy * scale
	end
	
	px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	sx = px+sx
	sy = py+sy
	
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
		
	if glone then
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
end
local function RectRound22(px,py,sx,sy,c,cs,scale,glone)

	if (c) then
		glColor(c[1],c[2],c[3],c[4])
	else
		glColor(1,1,1,1)
	end
	
	if cs == nil then
		cs = 4
	end
	
	if glone then
		glBlending(GL_SRC_ALPHA, GL_ONE)
	end
	-- add blur shader
	if c and c[4] >= blurShaderStartColor then
		newBlurRect[px..' '..py..' '..sx..' '..sy] = {px=px,py=py,sx=sx,sy=sy}
	end
	
	--[[px = math.floor(px)
	py = math.floor(py)
	sx = math.ceil(px+sx)
	sy = math.ceil(p+sy)
	]]--
	
	if scale ~= nil and scale ~= 1 then
		px = px + ((sx * (1-scale))/2)
		py = py + ((sy * (1-scale))/2)
		sx = sx * scale
		sy = sy * scale
	end
	
	px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	sx = px+sx
	sy = py+sy
	
	glBeginEnd(GL.QUADS, DrawGroundquad,px,py,sx,sy,cs)
		
	if glone then
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
end

local function DrawGroundquad(x,y,z,size)
	gl.TexCoord(0,0)
	gl.Vertex(x-size,y,z-size)
	gl.TexCoord(0,1)
	gl.Vertex(x-size,y,z+size)
	gl.TexCoord(1,1)
	gl.Vertex(x+size,y,z+size)
	gl.TexCoord(1,0)
	gl.Vertex(x+size,y,z-size)
end

local function DrawRectRound(px,py,sx,sy,cs)
	
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

local function TexRect(px,py,sx,sy,texture,c,scale)
	glPushMatrix()
	if (c) then
		glColor(c[1],c[2],c[3],c[4])
	else
		glColor(1,1,1,1)
	end
	if scale ~= nil and scale ~= 1 then
		px = px + ((sx * (1-scale))/2)
		py = py + ((sy * (1-scale))/2)
		sx = sx * scale
		sy = sy * scale
	end
	px,py,sx,sy = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy)
	glTranslate(px,py+sy,0)
	glScale(1,-1,1) --flip
	glTexture(texture)
	glTexRect(0,0,sx,sy)
	glTexture(false)
	glPopMatrix()
end

local function CreateStartList()
	if (StartList) then glDeleteList(StartList) end
	StartList = glCreateList(function()
		glMatrixMode(GL_PROJECTION)
		glLoadIdentity()
		glOrtho(0,vsx,vsy,0,0,1) --top left is 0,0
		glDepthTest(false)
		glMatrixMode(GL_MODELVIEW)
		glLoadIdentity()
		glTranslate(0.375,0.375,0) -- for exact pixelization
	end)
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = widgetHandler:GetViewSizes()
	CreateStartList()
end

function widget:Initialize()
	vsx,vsy = widgetHandler:GetViewSizes()
	CreateStartList()
	
	local T = {}
	WG[TN] = T
	T.version = version
	
	T.Color = function(a,b,c,d) --using (...) seems slower
		Todo[#Todo+1] = {1,a,b,c,d}
	end
	T.Rect = function(a,b,c,d,e,f)
		Todo[#Todo+1] = {2,a,b,c,d,e,f}
	end
	T.TexRect = function(a,b,c,d,e,f,g)
		Todo[#Todo+1] = {3,a,b,c,d,e,f,g}
	end
	T.Border = function(a,b,c,d,e,f)
		Todo[#Todo+1] = {4,a,b,c,d,e,f}
	end
	T.Text = function(a,b,c,d,e,f)
		Todo[#Todo+1] = {5,a,b,c,d,e,f}
	end
	T.RectRound = function(a,b,c,d,e,f,g,h)
		Todo[#Todo+1] = {6,a,b,c,d,e,f,g,h}
	end
	
	F[1] = Color
	F[2] = Rect
	F[3] = TexRect
	F[4] = Border
	F[5] = Text
	F[6] = RectRound
end

function widget:DrawScreen()
	
	newBlurRect = {}
	
	glResetState()
	glResetMatrices()
	
	glCallList(StartList)
	for i=1,#Todo do
		local t = Todo[i]
		F[t[1]](t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9])
		Todo[i] = nil
	end
	
	glResetState()
	glResetMatrices()
	
	CleanedTodo = true
	
	if (WG['guishader_api'] ~= nil) then
	
		-- remove changed blur areas
		for id, rect in pairs(blurRect) do
			if newBlurRect[id] == nil and rect.id ~= nil then
				WG['guishader_api'].RemoveRect('red_ui_'..rect.id)
				blurRect[id] = nil
			else
				newBlurRect[id] = rect
			end
		end
		-- add new blur areas
		local count = 0
		for id, rect in pairs(newBlurRect) do
			if blurRect[id] == nil then
				local x = rect.px
				local y = vsy-rect.py
				local x2 = (rect.px+rect.sx)
				local y2 = vsy-(rect.py+rect.sy)
				
				local rectid = rect.px..' '..rect.py..' '..rect.sx..' '..rect.sy
				WG['guishader_api'].InsertRect(x,y,x2,y2,'red_ui_'..rectid)
				newBlurRect[rectid].id = rectid
			end
			count = count + 1
		end
		--Spring.Echo(count)
		blurRect = newBlurRect
	else
		blurRect = {}
	end
end

function widget:Update()
	if (sIsGUIHidden()) then
		for i=1,#Todo do
			Todo[i] = nil
		end
	end
end

function widget:Shutdown()
	glDeleteList(StartList)
	
	if (WG['guishader_api'] ~= nil) then
	
		-- remove blur areas
		for id, rect in pairs(blurRect) do
			if newBlurRect[id] == nil and rect.id ~= nil then
				WG['guishader_api'].RemoveRect('red_ui_'..rect.id)
				blurRect[id] = nil
			end
		end
	end
	
	if (WG[TN].LastWidget) then
		Spring.Echo(widget:GetInfo().name..">> last processed widget was \""..WG[TN].LastWidget.."\"") --for debugging
	end
	
	WG[TN]=nil
end
