function widget:GetInfo()
	return {
		name		= "fb",
		desc		= "facebook logo next to advplayerlist",
		author		= "Floris",
		date		= "23 may 2015",
		license		= "GNU GPL, v2 or later",
		layer		= -3,			-- set to -5 to draw mascotte on top of advplayerlist
		enabled		= true
	}
end

local fbTexture = ":n:"..LUAUI_DIRNAME.."Images/facebook.dds"
local iconSize = 32

local spGetGameFrame			= Spring.GetGameFrame
local myPlayerID				= Spring.GetMyPlayerID()

local glText	          		= gl.Text
local glBlending          		= gl.Blending
local glScale          			= gl.Scale
local glRotate					= gl.Rotate
local glTranslate				= gl.Translate
local glPushMatrix          	= gl.PushMatrix
local glPopMatrix				= gl.PopMatrix

local glCreateList				= gl.CreateList
local glDeleteList				= gl.DeleteList
local glCallList				= gl.CallList

local drawlist = {}
local xPos = 0
local yPos = 0

local shown = false
local clicked = false

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

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

local function createList(size)
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	drawlist[1] = glCreateList( function()
		gl.Texture(fbTexture)
		gl.Color(1,1,1,1)
		DrawRect(-usedImgSize, 0, 0, usedImgSize)
		gl.Texture(false)
	end)
end

local advplayerlistPos = {}
function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		usedImgSize = iconSize * advplayerlistPos[5]
		xPos = advplayerlistPos[2] - 5
		yPos = 5 --advplayerlistPos[1] - iconSize
		if (prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5]) or force then
			createList(usedImgSize)
		end
	end
end

function widget:Initialize()
	if shown then
		widgetHandler:RemoveWidget(self)
	end
	updatePosition()
end

function widget:Shutdown()
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
end

function widget:PlayerChanged(playerID)
	if playerID == myPlayerID then
		
	end
end

function widget:DrawScreen()
	--if spGetGameFrame() == 0 then return end
	updatePosition()
	if drawlist[1] ~= nil then
		glPushMatrix()
			glTranslate(xPos, yPos, 0)
			glCallList(drawlist[1])
			glPushMatrix()
				--glTranslate(0, bob, 0)
				--glRotate(rot, 0, 0, 1)
				glCallList(drawlist[1])
				if clicked then
					glText('Just\nkidding', -2, 16, 12, 'or')
				end
			glPopMatrix()
		glPopMatrix()
	end
end

function isInBox(mx, my, box)
    return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:MousePress(mx, my, mb)
	if mb == 1 and isInBox(mx, my, {xPos-usedImgSize, yPos, xPos, yPos+usedImgSize}) then
		clicked = not clicked
		updatePosition(true)
	end
end

function widget:GetConfigData()
    savedTable = {}
    savedTable.shown = true
	return savedTable
end

function widget:SetConfigData(data)
	if data.shown ~= nil then
		shown = true
	end
end
