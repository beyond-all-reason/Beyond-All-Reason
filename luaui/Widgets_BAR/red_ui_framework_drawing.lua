function widget:GetInfo()
	return {
	version   = "9",
	name      = "Red_Drawing",
	desc      = "Drawing widget for Red UI Framework",
	author    = "Regret",
	date      = "29 may 2015",
	license   = "GNU GPL, v2 or later",
	layer     = 20001,
	enabled   = true,
	}
end

local bgcornerSize = 8
local bgcorner = "LuaUI/Images/bgcorner.png"
	
local TN = "Red_Drawing" --WG name for function list
local version = 9


local vsx,vsy = widgetHandler:GetViewSizes()
if (vsx == 1) then --hax for windowed mode
	vsx,vsy = Spring.GetWindowGeometry()
end

local sIsGUIHidden = Spring.IsGUIHidden

local F = {} --function table
local Todo = {} --function queue
local dList = {}
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
	px,py,sx,sy = px,py,sx,sy
	
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
	px,py,sx,sy = px,py,sx,sy
	glRect(px,py,px+sx,py+sy)
end

local function DrawRectRound(px,py,sx,sy,cs)
	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)
	
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.05		-- texture offset, because else gaps could show
	
	-- top left
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end

local function RectRound(px,py,sx,sy,c,cs,scale,glone,noblur)

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
	if c and not noblur then
		newBlurRect[px..' '..py..' '..sx..' '..sy] = {px=px,py=py,sx=sx,sy=sy}
	end
	
	if scale ~= nil and scale ~= 1 then
		px = px + ((sx * (1-scale))/2)
		py = py + ((sy * (1-scale))/2)
		sx = sx * scale
		sy = sy * scale
	end
	
	sx = px+sx
	sy = py+sy
	
	gl.Texture(bgcorner)
	glBeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
	
	if glone then
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
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
	px,py,sx,sy = px,py,sx,sy
	glTranslate(px,py+sy,0)
	glScale(1,-1,1) --flip
	glTexture(texture)
	DrawRect(0,0,sx,sy)
	glTexture(false)
	glPopMatrix()
end

local function RectQuad(px,py,sx,sy)
	local o = 0.008		-- texture offset, because else grey line might show at the edges
	gl.TexCoord(o,1-o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
end

function DrawRect(px,py,sx,sy)
	gl.BeginEnd(GL.QUADS, RectQuad, px,py,sx,sy)
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
	T.RectRound = function(a,b,c,d,e,f,g,h,i)
		Todo[#Todo+1] = {6,a,b,c,d,e,f,g,h,i}
	end
	
	F[1] = Color
	F[2] = Rect
	F[3] = TexRect
	F[4] = Border
	F[5] = Text
	F[6] = RectRound
	dList[1] = {}
	dList[2] = {}
	dList[3] = {}
	dList[4] = {}
	dList[5] = {}
	dList[6] = {}
end

local dlistCount = 0
function widget:DrawScreen()
	
	newBlurRect = {}
	
	glResetState()
	glResetMatrices()
	
	glCallList(StartList)
	
	for i=1,#Todo do
		local t = Todo[i]
		
		local id = ''
		
		-- using dlists worked only for text :S
		--[[if t[1] == 1 then	-- color
			id = t[2][1]..'_'..t[2][2]..'_'..t[2][3]..'_'..t[2][4]
			
		elseif t[1] == 2 then	-- rect
			id = t[2]..'_'..t[3]..'_'..t[4]..'_'..t[5]
			if type(t[6]) == 'table' then
				id = id .. t[6][1]..'_'..t[6][2]..'_'..t[6][3]..'_'..t[6][4]
			end
			id = id .. '_' ..(t[7] or '')
			
		elseif t[1] == 3 then	-- texrect
			id = t[2]..'_'..t[3]..'_'..t[4]..'_'..t[5]..'_'..t[6]
			if type(t[7]) == 'table' then
				id = id .. t[7][1]..'_'..t[7][2]..'_'..t[7][3]..'_'..t[7][4]
			end
			id = id .. '_' ..(t[8] or '')
			
		elseif t[1] == 4 then	-- border
			id = t[2]..'_'..t[3]..'_'..t[4]..'_'..t[5]..'_'..(t[6] or '')
			if type(t[7]) == 'table' then
				id = id .. t[7][1]..'_'..t[7][2]..'_'..t[7][3]..'_'..t[7][4]
			end
			
		elseif t[1] == 6 then	-- rectround
			id = t[2]..'_'..t[3]..'_'..t[4]..'_'..t[5]
			if type(t[6]) == 'table' then
				id = id .. t[6][1]..'_'..t[6][2]..'_'..t[6][3]..'_'..t[6][4]
				if t[6][4] >= blurShaderStartColor then	-- add blur shader
					newBlurRect[t[2]..' '..t[3]..' '..t[4]..' '..t[5] ] = {px=t[2],py=t[3],sx=t[4],sy=t[5]}
				end
			end
			id = id .. '_' ..(t[7] or '')..id .. '_' ..(t[8] or '')..id .. '_' ..(t[9] and '1' or '')	
		end]]--
		
		if t[1] == 5 then	-- text
			id = t[2]..'_'..t[3]..'_'..t[4]..'_'..t[5]..'_'..t[6]
			if type(t[7]) == 'table' then
				id = id .. t[7][1]..'_'..t[7][2]..'_'..t[7][3]..'_'..t[7][4]
			end
			if dList[t[1]][id] == nil then
				dlistCount = dlistCount + 1
				dList[t[1]][id] = glCreateList(function()
					F[t[1]](t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9],t[10])
				end)
			end
			glCallList(dList[t[1]][id])
		else
			F[t[1]](t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9],t[10])
		end
			
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

local sec = 0
local flushDistsTime = 20
function widget:Update(dt)
		
	if (sIsGUIHidden()) then
		for i=1,#Todo do
			Todo[i] = nil
		end
	end
	
	sec=sec+dt
	if (sec>flushDistsTime) then
		sec = 0
		removeDLists()
	end
end

function removeDLists()
	for t, idlist in pairs(dList) do
		for id in pairs(idlist) do
			glDeleteList(dList[t][id])
		end
		dList[t] = {}
	end
end

function widget:Shutdown()
	glDeleteList(StartList)
	removeDLists()
	
	if (WG['guishader_api'] ~= nil) then
	
		-- remove blur areas
		for id, rect in pairs(blurRect) do
			if rect.id ~= nil then
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
