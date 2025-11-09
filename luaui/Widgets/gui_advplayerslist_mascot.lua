local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name		= "AdvPlayersList Mascot",
		desc		= "Shows a mascot sitting on top of the adv-playerlist  (use /mascot to switch)",
		author		= "Floris",
		date		= "23 may 2015",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= false,
	}
end

-- Localized functions for performance
local mathSin = math.sin
local mathPi = math.pi
local tableInsert = table.insert

---------------------------------------------------------------------------------------------------
--  Config
---------------------------------------------------------------------------------------------------

local imageDirectory			= ":l:"..LUAUI_DIRNAME.."Images/advplayerslist_mascot/"

local OPTIONS = {}
OPTIONS.defaults = {	-- these will be loaded when switching style, but the style will overwrite the those values
	name				= "Defaults",
	imageSize			= 55,
	xOffset				= -1.6,
	yOffset				= -58/5,
	blinkDuration		= 0.12,
	blinkTimeout		= 6,
}
tableInsert(OPTIONS, {
	name				= "Floris Cat",
	body				= imageDirectory.."floriscat_body.png",
	head				= imageDirectory.."floriscat_head.png",
	headblink			= imageDirectory.."floriscat_headblink.png",
	santahat			= imageDirectory.."santahat.png",
	imageSize			= 53,
	xOffset				= -1.6,
	yOffset				= -58/5,
	head_xOffset		= 0,
	head_yOffset		= 0,
})
tableInsert(OPTIONS, {
	name				= "GrumpyCat",
	body				= imageDirectory.."grumpycat_body.png",
	head				= imageDirectory.."grumpycat_head.png",
	headblink			= imageDirectory.."grumpycat_headblink.png",
	santahat			= imageDirectory.."santahat.png",
	imageSize			= 53,
	xOffset				= -1.6,
	yOffset				= -58/5,
	head_xOffset		= 0,
	head_yOffset		= 0,
})
tableInsert(OPTIONS, {
	name				= "Teifion's MrBeans",
	body				= imageDirectory.."mrbeans_body.png",
	head				= imageDirectory.."mrbeans_head.png",
	headblink			= imageDirectory.."mrbeans_headblink.png",
	santahat			= imageDirectory.."santahat.png",
	imageSize			= 50,
	xOffset				= -1.6,
	yOffset				= -58/4,
	head_xOffset		= -0.01,
	head_yOffset		= 0.13,
})
local currentOption = 1

local usedImgSize = OPTIONS[currentOption].imageSize

local function shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

local OPTIONS_original = shallow_copy(OPTIONS)
OPTIONS_original.defaults = nil

local function toggleOptions(option)
	if OPTIONS[option] then
		currentOption = option
	else
		currentOption = currentOption + 1
		if not OPTIONS[currentOption] then
			currentOption = 1
		end
	end
	loadOption()
	updatePosition(true)
end

function loadOption()
	local appliedOption = OPTIONS_original[currentOption]
	OPTIONS[currentOption] = shallow_copy(OPTIONS.defaults)

	for option, value in pairs(appliedOption) do
		OPTIONS[currentOption][option] = value
	end
end

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local myPlayerID				= Spring.GetMyPlayerID()

local glRotate					= gl.Rotate
local glTranslate				= gl.Translate
local glPushMatrix          	= gl.PushMatrix
local glPopMatrix				= gl.PopMatrix

local glCreateList				= gl.CreateList
local glDeleteList				= gl.DeleteList
local glCallList				= gl.CallList

local math_isInRect = math.isInRect

local drawlist = {}
local xPos = 0
local yPos = 0

local drawSantahat = false
if Spring.Utilities.Gametype.GetCurrentHolidays()["xmas"] then
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
		if drawSantahat and OPTIONS[currentOption]['santahat'] then
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
		if drawSantahat and OPTIONS[currentOption]['santahat'] then
			gl.Texture(OPTIONS[currentOption]['santahat'])
			DrawRect(-(size/2), -(size/2)+(size/14), (size/2), (size/2)+(size/14))
		end
		gl.Texture(false)
	end)
end

local parentPos = {}
local positionChange = os.clock()
function updatePosition(force)
	local prevPos = parentPos
	if WG['displayinfo'] ~= nil then
		parentPos = WG['displayinfo'].GetPosition()
	elseif WG['unittotals'] ~= nil then
		parentPos = WG['unittotals'].GetPosition()
	elseif WG['music'] ~= nil then
		parentPos = WG['music'].GetPosition()
	elseif WG['advplayerlist_api'] ~= nil then
		parentPos = WG['advplayerlist_api'].GetPosition()
	else
		local scale = (vsy / 880) * (1 + (Spring.GetConfigFloat("ui_scale", 1) - 1) / 1.25)
		parentPos = {0,vsx-(220*scale),0,vsx,scale}
	end
	if parentPos[5] ~= nil then
		usedImgSize = OPTIONS[currentOption]['imageSize'] * parentPos[5]
		xPos = parentPos[2]+(usedImgSize/2) + (OPTIONS[currentOption]['xOffset'] * parentPos[5])
		yPos = parentPos[1]+(usedImgSize/2) + (OPTIONS[currentOption]['yOffset'] * parentPos[5])
		positionChange = os.clock()

		if (prevPos[1] == nil or prevPos[1] ~= parentPos[1] or prevPos[2] ~= parentPos[2] or prevPos[5] ~= parentPos[5]) or force then
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

	rot = 14 + (6* mathSin(mathPi*(totalTime/4)))
	bob = (1.5*mathSin(mathPi*(totalTime/5.5)))

	if sec > OPTIONS[currentOption]['blinkTimeout'] then
		usedDrawlist = 3
	end
	if sec > (OPTIONS[currentOption]['blinkTimeout']+OPTIONS[currentOption]['blinkDuration']) then
		sec = 0
		usedDrawlist = 2
	end
	updatePosition()
end

function widget:DrawScreen()
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

function widget:MousePress(mx, my, mb)
	if mb == 1 and math_isInRect(mx, my, xPos-(usedImgSize/2), yPos-(usedImgSize/2), xPos+(usedImgSize/2), yPos+(usedImgSize/2)) then
		toggleOptions()
	end
end

function widget:TextCommand(command)
	if string.sub(command, 1, 6) == 'mascot' then
		toggleOptions(tonumber(string.sub(command, 8)))
		Spring.Echo("Playerlist mascot: "..OPTIONS[currentOption].name)
	end
end


function widget:GetConfigData()
	return {currentOption = currentOption}
end

function widget:SetConfigData(data)
	if data.currentOption ~= nil and OPTIONS[data.currentOption] ~= nil then
		currentOption = data.currentOption or currentOption
	end
end
