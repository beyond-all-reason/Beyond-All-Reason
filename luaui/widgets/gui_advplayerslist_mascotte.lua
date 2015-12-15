function widget:GetInfo()
	return {
		name		= "AdvPlayersList mascotte",
		desc		= "Shows a mascotte sitting on top of the adv-playerlist  (use /mascotte to switch)",
		author		= "Floris",
		date		= "23 may 2015",
		license		= "GNU GPL, v2 or later",
		layer		= -3,			-- set to -5 to draw mascotte on top of advplayerlist
		enabled		= false
	}
end
---------------------------------------------------------------------------------------------------
--  Config
---------------------------------------------------------------------------------------------------

local imageDirectory			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist_mascotte/"

local OPTIONS = {}
OPTIONS.defaults = {	-- these will be loaded when switching style, but the style will overwrite the those values 
	name				= "Defaults",
	imageSize			= 55,
	xOffset				= -1.6,
	yOffset				= -58/5,
	blinkDuration		= 0.12,
	blinkTimeout		= 6,
}
table.insert(OPTIONS, {
	name				= "Floris Cat",
	body				= imageDirectory.."floriscat_body.dds",
	head				= imageDirectory.."floriscat_head.dds",
	headblink			= imageDirectory.."floriscat_headblink.dds",
	santahat			= imageDirectory.."santahat.dds",
	imageSize			= 53,
	xOffset				= -1.6,
	yOffset				= -58/5,
	head_xOffset		= 0,
	head_yOffset		= 0,
})
table.insert(OPTIONS, {
	name				= "GrumpyCat",
	body				= imageDirectory.."grumpycat_body.dds",
	head				= imageDirectory.."grumpycat_head.dds",
	headblink			= imageDirectory.."grumpycat_headblink.dds",
	santahat			= imageDirectory.."santahat.dds",
	imageSize			= 53,
	xOffset				= -1.6,
	yOffset				= -58/5,
	head_xOffset		= 0,
	head_yOffset		= 0,
})
local currentOption = 1


function table.shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end
OPTIONS_original = table.shallow_copy(OPTIONS)
OPTIONS_original.defaults = nil

local function toggleOptions()
	currentOption = currentOption + 1
	if not OPTIONS[currentOption] then
		currentOption = 1
	end
	loadOption()
	updatePosition(true)
end

function loadOption()
	local appliedOption = OPTIONS_original[currentOption]
	OPTIONS[currentOption] = table.shallow_copy(OPTIONS.defaults)
	
	for option, value in pairs(appliedOption) do
		OPTIONS[currentOption][option] = value
	end
end

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

local drawSantahat = false
if os.date("%m") == "12"  and  os.date("%d") >= "24"  and  os.date("%d") <= "31" then
	drawSantahat = true
end
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
		gl.Texture(OPTIONS[currentOption]['body'])
		gl.Color(1,1,1,1)
		DrawRect(-(size/2), -(size/2), (size/2), (size/2))
		gl.Texture(false)
	end)
	
	if drawlist[2] ~= nil then
		glDeleteList(drawlist[2])
	end
	drawlist[2] = glCreateList( function()
		gl.Color(1,1,1,1)
		gl.Texture(OPTIONS[currentOption]['head'])
		glTranslate(OPTIONS[currentOption]['head_xOffset']*size, OPTIONS[currentOption]['head_yOffset']*size, 0)
		DrawRect(-(size/2), -(size/2)+(size/14), (size/2), (size/2)+(size/14))
		if drawSantahat then
			gl.Texture(OPTIONS[currentOption]['santahat'])
			DrawRect(-(size/2), -(size/2)+(size/14), (size/2), (size/2)+(size/14))
		end
		gl.Texture(false)
	end)
	if drawlist[3] ~= nil then
		glDeleteList(drawlist[3])
	end
	drawlist[3] = glCreateList( function()
		gl.Color(1,1,1,1)
		gl.Texture(OPTIONS[currentOption]['headblink'])
		glTranslate(OPTIONS[currentOption]['head_xOffset']*size, OPTIONS[currentOption]['head_yOffset']*size, 0)
		DrawRect(-(size/2), -(size/2)+(size/14), (size/2), (size/2)+(size/14))
		if drawSantahat then
			gl.Texture(OPTIONS[currentOption]['santahat'])
			DrawRect(-(size/2), -(size/2)+(size/14), (size/2), (size/2)+(size/14))
		end
		gl.Texture(false)
	end)
end

local advplayerlistPos = {}
function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		local usedImgSize = OPTIONS[currentOption]['imageSize'] * advplayerlistPos[5]
		xPos = advplayerlistPos[2]+(usedImgSize/2) + (OPTIONS[currentOption]['xOffset'] * advplayerlistPos[5])
		yPos = advplayerlistPos[1]+(usedImgSize/2) + (OPTIONS[currentOption]['yOffset'] * advplayerlistPos[5])
		if (prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5]) or force then
			createList(usedImgSize)
		end
	end
end


function widget:Initialize()
    loadOption()
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
	
	if sec > OPTIONS[currentOption]['blinkTimeout'] then
		usedDrawlist = 3
	end
	if sec > (OPTIONS[currentOption]['blinkTimeout']+OPTIONS[currentOption]['blinkDuration']) then
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


function widget:TextCommand(command)
    if (string.find(command, "mascotte") == 1  and  string.len(command) == 8) then 
		toggleOptions()
		Spring.Echo("Adv-playerlist mascotte: "..OPTIONS[currentOption].name)
	end
end


function widget:GetConfigData()
    savedTable = {}
    savedTable.currentOption = currentOption
	return savedTable
end

function widget:SetConfigData(data)
	if data.currentOption ~= nil and OPTIONS[data.currentOption] ~= nil then
		currentOption = data.currentOption or currentOption
	end
end
