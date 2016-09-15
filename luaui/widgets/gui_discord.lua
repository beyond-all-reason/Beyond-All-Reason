function widget:GetInfo()
	return {
		name		= "Discord button",
		desc		= "located next to advplayerlist",
		author		= "Floris",
		date		= "24 july 2016",
		license		= "GNU GPL, v2 or later",
		layer		= -3,			-- set to -5 to draw mascotte on top of advplayerlist
		enabled		= true
	}
end

local iconTexture = ":n:"..LUAUI_DIRNAME.."Images/discord.png"
local iconSize = 28

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
local mouseover = false

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
		gl.Texture(iconTexture)
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
		xPos = advplayerlistPos[4]
		yPos = advplayerlistPos[1]
		if (prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5]) or force then
			createList(usedImgSize)
		end
	end
end

function widget:Initialize()
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
	if spGetGameFrame() > 0 then
		widgetHandler:RemoveWidget(self)
		return
	end
	--if spGetGameFrame() == 0 then return end
	updatePosition()
	if drawlist[1] ~= nil then
		glPushMatrix()
			glTranslate(xPos, yPos, 0)
				if mouseover then
					gl.Color(1,1,1,1)
				else
					gl.Color(1,1,1,0.55)
				end
			glCallList(drawlist[1])
		glPopMatrix()
		mouseover = false
	end
end

function isInBox(mx, my, box)
    return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:MousePress(mx, my, mb)
	if mb == 1 and isInBox(mx, my, {xPos-usedImgSize, yPos, xPos, yPos+usedImgSize}) then
		return true
	end
end

function widget:MouseRelease(mx, my, mb)
	if mb == 1 and isInBox(mx, my, {xPos-usedImgSize, yPos, xPos, yPos+usedImgSize}) then
		--Spring.SendCommands({"clearmapmarks"})
		updatePosition(true)
	end
end

function widget:IsAbove(mx, my)
	if isInBox(mx, my, {xPos-usedImgSize, yPos, xPos, yPos+usedImgSize}) then
		mouseover = true
	end
	return mouseover
end

function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("We have our own Discord server now!\nour central community hub (chat/voice/info)\n\nhttps://discordapp.com/invite/aDtX3hW")
	end
end