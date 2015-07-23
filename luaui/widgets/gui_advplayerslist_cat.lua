function widget:GetInfo()
	return {
		name		= "AdvPlayersList cat",
		desc		= "Shows a decorational image",
		author		= "Floris",
		date		= "23 may 2015",
		license		= "GNU GPL, v2 or later",
		layer		= 999999,
		enabled		= true
	}
end
---------------------------------------------------------------------------------------------------
--  Config
---------------------------------------------------------------------------------------------------

local imageSize					= 58
local xOffset					= -1.6
local yOffset					= -imageSize/5

local winkDuration				= 0.12
local winkTimeout				= 6

local imageDirectory			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist_cat/"
local catbody					= imageDirectory.."catbody.dds"
local cathead					= imageDirectory.."cathead.dds"
local catheadwink				= imageDirectory.."catheadwink.dds"

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local spGetGameFrame			= Spring.GetGameFrame
local myPlayerID				= Spring.GetMyPlayerID()

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

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

local function squareTex(x, y, size)
	gl.TexCoord(0,0);
	gl.Vertex(x-(size/2), y-(size/2));

	gl.TexCoord(0,1);
	gl.Vertex(x+(size/2), y-(size/2));

	gl.TexCoord(1,1); 
	gl.Vertex(x+(size/2), y+(size/2));

	gl.TexCoord(1,0);
	gl.Vertex(x-(size/2), y+(size/2));
end

local function createList(size)
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	drawlist[1] = glCreateList( function()
		gl.Texture(catbody)
		gl.Color(1,1,1,1)
		gl.TexRect(-(size/2), -(size/2), (size/2), (size/2))
		gl.Texture(false)
	end)
	
	if drawlist[2] ~= nil then
		glDeleteList(drawlist[2])
	end
	drawlist[2] = glCreateList( function()
		gl.Color(1,1,1,1)
		gl.Texture(cathead)
		gl.TexRect(-(size/2), -(size/2)+(size/14), (size/2), (size/2)+(size/14))
		gl.Texture(false)
	end)
	--[[drawlist[2] = glCreateList( function()
		gl.Color(1,1,1,1)
		gl.Texture(cathead)
		--gl.Rotate(0.5,0,1,0)
		gl.BeginEnd(GL.QUADS, squareTex, posX, posY, size)
		--gl.Rotate(-0.5,0,1,0)
		gl.Texture(false)
	end)]]--
	if drawlist[3] ~= nil then
		glDeleteList(drawlist[3])
	end
	drawlist[3] = glCreateList( function()
		gl.Color(1,1,1,1)
		gl.Texture(catheadwink)
		gl.TexRect(-(size/2), -(size/2)+(size/14), (size/2), (size/2)+(size/14))
		gl.Texture(false)
	end)
end

local advplayerlistPos = {}
function updatePosition()
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		local usedImgSize = imageSize * advplayerlistPos[5]
		xPos = advplayerlistPos[2]+(usedImgSize/2) + (xOffset * advplayerlistPos[5])
		yPos = advplayerlistPos[1]+(usedImgSize/2) + (yOffset * advplayerlistPos[5])
		if prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5] then
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
	if drawlist[2] ~= nil then
		glDeleteList(drawlist[2])
	end
	if drawlist[3] ~= nil then
		glDeleteList(drawlist[3])
	end
end

function widget:PlayerChanged(playerID)
	if playerID == myPlayerID then
		
	end
end

local sec = 0
local totalTime = 0
local rot = 0
local bob = 0
local usedDrawlist = 2
function widget:Update(dt)
	sec=sec+dt
	totalTime=totalTime+dt
	
	rot = 14 + (6* math.sin(math.pi*(totalTime/4)))
	bob = (1.5*math.sin(math.pi*(totalTime/5.5)))
	
	if sec > winkTimeout then
		usedDrawlist = 3
	end
	if sec > (winkTimeout+winkDuration) then
		sec = 0
		usedDrawlist = 2
	end
end

function widget:DrawScreen()
	if spGetGameFrame() == 0 then return end
	updatePosition()
	if drawlist[1] ~= nil then
		glPushMatrix()
			glTranslate(xPos, yPos, 0)
			glCallList(drawlist[1])
			glPushMatrix()
				glTranslate(0, bob, 0)
				glRotate(rot, 0, 0, 1)
				glCallList(drawlist[usedDrawlist])
			glPopMatrix()
		glPopMatrix()
	end
end
