local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name		= "AdvPlayersList Mascot",
		desc		= "Shows a mascot sitting on top of the adv-playerlist  (use /mascot to switch)",
		author		= "Floris, biong",
		date		= "2015-2026",
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
local soundDirectory			= LUAUI_DIRNAME.."Sounds/advplayerslist_mascot/"   -- no :l: prefix, used for VFS check and PlaySoundFile

local OPTIONS = {}
OPTIONS.defaults = {	-- these will be loaded when switching style, but the style will overwrite those values
	name				= "Defaults",
	imageSize			= 55,
	xOffset				= -1.6,
	yOffset				= -58/5,
	blinkDuration		= 0.12,
	blinkTimeout		= 6,
	soundInterval		= 20,    -- seconds between sound playbacks (only used if a sound file exists)
}

-- Files that are overlays/decorations and should not be treated as selectable mascots
local SPECIAL_FILES = {
	["santahat.png"] = true,
}

-- Recognised suffixes that indicate a file's role within a mascot set.
-- Order matters: longer/more-specific suffixes must come before shorter ones
-- so that "_headblink" is matched before "_head".
local ROLE_SUFFIXES = {
	{ suffix = "_headblink", role = "headblink" },
	{ suffix = "_blink",     role = "headblink" },
	{ suffix = "_body",      role = "body"      },
	{ suffix = "_head",      role = "head"      },
}

local function classifyFile(nameNoExt)
	for _, entry in ipairs(ROLE_SUFFIXES) do
		local s = entry.suffix
		if nameNoExt:sub(-#s) == s then
			local base = nameNoExt:sub(1, -(#s + 1))
			return base, entry.role
		end
	end
	-- No recognised suffix → treat the whole image as a standalone head
	return nameNoExt, "head"
end

local function findSoundForBase(base)
	for _, ext in ipairs({ "wav", "mp3" }) do
		local path = soundDirectory..base.."."..ext
		if VFS.FileExists(path, VFS.RAW_FIRST) then
			return path
		end
	end
	return nil
end

local function buildOptionsFromDirectory()
	local files = VFS.DirList(LUAUI_DIRNAME.."Images/advplayerslist_mascot/", "*.png", VFS.RAW_FIRST)
	if not files then return end

	-- First pass: group files by mascot base-name
	local groups   = {}   -- base-name string -> { body, head, headblink }
	local ordering = {}   -- keeps insertion order for deterministic cycling

	for _, filepath in ipairs(files) do
		local filename = filepath:match("([^/\\]+)$")
		if filename and not SPECIAL_FILES[filename] then
			local nameNoExt = filename:gsub("%.png$", "")
			local base, role = classifyFile(nameNoExt)

			if not groups[base] then
				groups[base] = { name = base }
				tableInsert(ordering, base)
			end

			-- Don't overwrite a role that was already filled
			-- (e.g. _headblink takes priority over _blink for the same base)
			if not groups[base][role] then
				groups[base][role] = imageDirectory..filename
			end
		end
	end

	-- Second pass: finalise each group and insert into OPTIONS
	-- Sort ordering alphabetically so the cycle order is stable across runs
	table.sort(ordering)

	for _, base in ipairs(ordering) do
		local g = groups[base]
		if g.head then
			-- If no dedicated blink image exists, reuse the normal head
			local headblink = g.headblink or g.head
			-- Sound is optional; nil means no sound for this mascot
			local sound = findSoundForBase(base)
			tableInsert(OPTIONS, {
				name			= g.name,
				body			= g.body or false,   -- false = no body layer
				head			= g.head,
				headblink		= headblink,
				santahat		= imageDirectory.."santahat.png",
				sound			= sound,             -- nil if no sound file found
				imageSize		= 53,
				xOffset			= -1.6,
				yOffset			= -58/5,
				head_xOffset	= 0,
				head_yOffset	= 0,
			})
		end
		-- Groups with only a _body and no _head are silently skipped
	end
end

buildOptionsFromDirectory()

local currentOption = 1

local usedImgSize = (OPTIONS[currentOption] and OPTIONS[currentOption].imageSize) or OPTIONS.defaults.imageSize

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
		-- Body is optional; some mascots are head-only
		if OPTIONS[currentOption]['body'] then
			gl.Texture(OPTIONS[currentOption]['body'])
			gl.Color(1,1,1,1)
			DrawRect(-(size/2), -(size/2), (size/2), (size/2))
			gl.Texture(false)
		end
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

local function tryPlaySound()
	local soundPath = OPTIONS[currentOption] and OPTIONS[currentOption]['sound']
	if soundPath then
		-- volume 1.0, no loop, plays as UI sound (not positional)
		Spring.PlaySoundFile(soundPath, 1.0, 'ui')
	end
end

function widget:Initialize()
	-- Rebuild OPTIONS from disk so any newly added images/sounds are picked up on reload
	for i = #OPTIONS, 1, -1 do
		OPTIONS[i] = nil
	end
	buildOptionsFromDirectory()

	OPTIONS_original = shallow_copy(OPTIONS)
	OPTIONS_original.defaults = nil

	-- Clamp currentOption in case the mascot count changed since last save
	if not OPTIONS[currentOption] then
		currentOption = 1
	end

	if OPTIONS[currentOption] then
		loadOption()
	end
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
local soundTimer = 0   -- counts up toward soundInterval; reset on sound play or mascot switch

function widget:Update(dt)
	sec = sec + dt
	totalTime = totalTime + dt

	rot = 14 + (6 * mathSin(mathPi * (totalTime / 4)))
	bob = (1.5 * mathSin(mathPi * (totalTime / 5.5)))

	-- Blink handling
	if sec > OPTIONS[currentOption]['blinkTimeout'] then
		usedDrawlist = 3
	end
	if sec > (OPTIONS[currentOption]['blinkTimeout'] + OPTIONS[currentOption]['blinkDuration']) then
		sec = 0
		usedDrawlist = 2
	end

	-- Sound handling: only tick if a sound is configured for the current mascot
	if OPTIONS[currentOption]['sound'] then
		soundTimer = soundTimer + dt
		if soundTimer >= OPTIONS[currentOption]['soundInterval'] then
			soundTimer = 0
			tryPlaySound()
		end
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
		soundTimer = 0   -- reset sound timer on manual switch so it doesn't fire immediately
		toggleOptions()
	end
end

function widget:TextCommand(command)
	if string.sub(command, 1, 6) == 'mascot' then
		soundTimer = 0
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
