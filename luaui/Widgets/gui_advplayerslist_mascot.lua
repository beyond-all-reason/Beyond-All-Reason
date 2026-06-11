local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "AdvPlayersList Mascot",
		desc = "Shows a mascot sitting on top of the adv-playerlist  (use /mascot to switch)",
		author = "Floris, biong",
		date = "2015-2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end

-- Localized functions for performance
local mathSin = math.sin
local mathPi = math.pi
local mathRandom = math.random
local tableInsert = table.insert

---------------------------------------------------------------------------------------------------
--  Config
---------------------------------------------------------------------------------------------------

local imageDirectory = ":l:" .. LUAUI_DIRNAME .. "Images/advplayerslist_mascot/"
local soundDirectory = LUAUI_DIRNAME .. "Sounds/advplayerslist_mascot/"

-- Supported formats, checked in priority order.
local IMAGE_EXTENSIONS = { "png", "jpg", "jpeg", "tga", "dds" }
local SOUND_EXTENSIONS = { "wav", "mp3", "ogg", "flac" }

local OPTIONS = {}
OPTIONS.defaults = { -- merged into every mascot by loadOption(); per-mascot overrides win
	name = "Defaults",
	imageSize = 53,
	xOffset = -1.6,
	yOffset = -58 / 5,
	head_xOffset = 0,
	head_yOffset = 0,
	blinkDuration = 0.12,
	blinkTimeout = 6,
	soundInterval = 20, -- seconds between ambient sound playbacks
	emoteInterval = 15, -- seconds between automatic random-emote triggers
	emoteDuration = 2.5, -- seconds each triggered emote is displayed
}

-- Base name (no extension) of the xmas overlay. Defined once so the exclusion set
-- below and findSantahat() can't drift apart.
local SANTAHAT_BASE = "santahat"

-- Base names (no extension) of overlay files that are not selectable mascots.
local SPECIAL_FILE_BASES = {
	[SANTAHAT_BASE] = true,
}

-- Per-mascot tuning overrides, keyed by base name (the filename minus its role suffix,
-- e.g. "mrbeans" for mrbeans_head.png). Anything not listed here uses OPTIONS.defaults.
-- Aspect ratio is corrected automatically at draw time, so source images don't need a
-- specific resolution; only add an entry when a mascot needs different positioning or a
-- different on-screen scale than the defaults. Kept in-widget (rather than an external
-- data file) so tuning ships with the code and needs nothing extra to load.
local MASCOT_OVERRIDES = {
	-- Teifion's MrBeans wanted a smaller draw size and a nudged head under the old setup.
	mrbeans = { imageSize = 50, yOffset = -58 / 4, head_xOffset = -0.01, head_yOffset = 0.13 },
}

-- Named emotes recognised by filename suffix.
-- Any file matching  <base>_<emoteName>.<ext>  is registered as an emote for that mascot.
-- Add or remove names freely; ROLE_SUFFIXES is built from this table automatically.
local EMOTE_NAMES = {
	-- Positive
	"laugh",
	"happy",
	"smile",
	"love",
	"wink",
	"excited",
	"star",
	"cheer",
	"blush",
	"smug",
	"cool",
	-- Negative
	"cry",
	"sad",
	"angry",
	"rage",
	"pain",
	"scared",
	"nervous",
	"dead",
	"tears",
	-- Neutral / physical
	"surprised",
	"shock",
	"think",
	"confused",
	"sleep",
	"yawn",
	"sweat",
	"dizzy",
	"wave",
}

-- Recognised structural suffixes that indicate a file's role within a mascot set.
-- Order matters: longer/more-specific entries must come before shorter ones
-- so that "_headblink" is matched before "_head".
-- Named-emote suffixes are inserted here before _body/_head.
local ROLE_SUFFIXES = {
	{ suffix = "_headblink", role = "headblink" },
	{ suffix = "_blink", role = "headblink" },
}
for _, emoteName in ipairs(EMOTE_NAMES) do
	tableInsert(ROLE_SUFFIXES, { suffix = "_" .. emoteName, role = "emote_" .. emoteName })
end
tableInsert(ROLE_SUFFIXES, { suffix = "_body", role = "body" })
tableInsert(ROLE_SUFFIXES, { suffix = "_head", role = "head" })

-- Classify a filename (without extension) into (mascotBase, role).
-- Returns role = "head" when no suffix matches (standalone head image).
-- Generic numbered emotes: any trailing _<digits> that don't match a named suffix
-- are treated as "emote_<number>" (e.g. mascot_1.png, mascot_42.jpg).
local function classifyFile(nameNoExt)
	for _, entry in ipairs(ROLE_SUFFIXES) do
		local s = entry.suffix
		if nameNoExt:sub(-#s) == s then
			local base = nameNoExt:sub(1, -(#s + 1))
			return base, entry.role
		end
	end
	-- Generic numbered emote: base_N where N is one or more digits
	local base, num = nameNoExt:match("^(.+)_(%d+)$")
	if base then
		return base, "emote_" .. num
	end
	-- No recognised suffix → whole filename is a standalone head
	return nameNoExt, "head"
end

-- Return the first existing file at <basePath>.<ext> across all known sound extensions.
local function findSoundFile(basePath)
	for _, ext in ipairs(SOUND_EXTENSIONS) do
		local path = basePath .. "." .. ext
		if VFS.FileExists(path, VFS.RAW_FIRST) then
			return path
		end
	end
	return nil
end

-- Locate the santahat overlay in any supported image format, or return nil.
local function findSantahat()
	for _, ext in ipairs(IMAGE_EXTENSIONS) do
		local vfsPath = LUAUI_DIRNAME .. "Images/advplayerslist_mascot/" .. SANTAHAT_BASE .. "." .. ext
		if VFS.FileExists(vfsPath, VFS.RAW_FIRST) then
			return imageDirectory .. SANTAHAT_BASE .. "." .. ext
		end
	end
	return nil
end

-- Collect all image files in the mascot directory across every supported extension.
local function listAllImages()
	local all = {}
	local seen = {}
	for _, ext in ipairs(IMAGE_EXTENSIONS) do
		local files = VFS.DirList(LUAUI_DIRNAME .. "Images/advplayerslist_mascot/", "*." .. ext, VFS.RAW_FIRST)
		if files then
			for _, f in ipairs(files) do
				if not seen[f] then
					seen[f] = true
					tableInsert(all, f)
				end
			end
		end
	end
	return all
end

local function loadMascotsFromDirectory()
	local files = listAllImages()
	if not files then
		return
	end

	-- First pass: group files by mascot base-name
	local groups = {} -- base-name -> { name, body, head, headblink, emotes={} }
	local ordering = {} -- stable cycle order

	for _, filepath in ipairs(files) do
		local filename = filepath:match("([^/\\]+)$")
		if filename then
			-- Strip any supported extension (not just .png) to obtain the base name
			local nameNoExt = filename:gsub("%.[^./\\]+$", "")

			if not SPECIAL_FILE_BASES[nameNoExt] then
				local base, role = classifyFile(nameNoExt)

				if not groups[base] then
					groups[base] = { name = base, emotes = {} }
					tableInsert(ordering, base)
				end

				if role:find("^emote_") then
					-- Emote image + optional per-emote sound.
					-- Convention: mascot_laugh.wav plays when the laugh emote triggers.
					local emoteSuffix = "_" .. role:sub(7) -- "emote_laugh" -> "_laugh"
					local sound = findSoundFile(soundDirectory .. base .. emoteSuffix)
					tableInsert(groups[base].emotes, {
						path = imageDirectory .. filename,
						sound = sound or false,
					})
				else
					-- Structural role (head / headblink / body): first file found wins
					if not groups[base][role] then
						groups[base][role] = imageDirectory .. filename
					end
				end
			end
		end
	end

	-- Sort alphabetically so the cycle order is deterministic across runs
	table.sort(ordering)

	local santahat = findSantahat()

	-- Second pass: build an OPTIONS entry for every valid mascot group
	for _, base in ipairs(ordering) do
		local g = groups[base]
		if g.head then
			-- Fall back to normal head when no dedicated blink image exists
			local headblink = g.headblink or g.head
			-- Ambient mascot sound (e.g. mascot.wav); per-emote sounds live in each emote entry
			local sound = findSoundFile(soundDirectory .. base)
			local entry = {
				name = g.name,
				body = g.body or false, -- false = head-only mascot
				head = g.head,
				headblink = headblink,
				santahat = santahat or false, -- false when no santahat overlay exists
				sound = sound or false, -- false when no sound file found
				emotes = g.emotes, -- list of { path, sound }
			}
			-- Size and offsets come from OPTIONS.defaults via loadOption(); only mascots
			-- listed in MASCOT_OVERRIDES carry their own imageSize / offset values.
			local override = MASCOT_OVERRIDES[base]
			if override then
				for k, v in pairs(override) do
					entry[k] = v
				end
			end
			tableInsert(OPTIONS, entry)
		end
		-- Groups with only a body and no head are silently skipped
	end
end

loadMascotsFromDirectory()

local currentOption = 1
local usedImgSize = (OPTIONS[currentOption] and OPTIONS[currentOption].imageSize) or OPTIONS.defaults.imageSize

local function shallow_copy(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

local OPTIONS_original = shallow_copy(OPTIONS)
OPTIONS_original.defaults = nil

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local myPlayerID = Spring.GetMyPlayerID()

local glRotate = gl.Rotate
local glTranslate = gl.Translate
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList

local math_isInRect = math.isInRect

local drawlist = {}
local xPos = 0
local yPos = 0

local drawSantahat = false
if Spring.Utilities.Gametype.GetCurrentHolidays()["xmas"] then
	drawSantahat = true
end

-- Draw-state constants: map directly to the drawlist slot used for the head layer.
local DRAW_NORMAL = 2 -- drawlist[2] = normal head
local DRAW_BLINK = 3 -- drawlist[3] = blink head
local DRAW_EMOTE = 4 -- drawlist[4] = current emote (rebuilt on each trigger)

---------------------------------------------------------------------------------------------------
--  Draw helpers
---------------------------------------------------------------------------------------------------

local function RectQuad(px, py, sx, sy)
	local o = 0.008 -- tiny texture offset to prevent grey edge artefacts
	gl.TexCoord(o, 1 - o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(1 - o, 1 - o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(1 - o, o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o, o)
	gl.Vertex(px, sy, 0)
end

function DrawRect(px, py, sx, sy)
	gl.BeginEnd(GL.QUADS, RectQuad, px, py, sx, sy)
end

-- Compute the draw width/height for a layer whose nominal box is `size`, preserving the
-- texture's aspect ratio by fitting it inside a size×size box (letterbox style). Square
-- textures return size×size, i.e. identical to the previous fixed-square behaviour, so
-- existing mascots are unaffected while non-square drop-ins no longer get stretched.
-- Falls back to square if the texture dimensions can't be read yet.
local function fitQuad(texturePath, size)
	if texturePath then
		local info = gl.TextureInfo(texturePath)
		if info and info.xsize and info.ysize and info.xsize > 0 and info.ysize > 0 then
			local aspect = info.xsize / info.ysize
			if aspect >= 1 then
				return size, size / aspect
			else
				return size * aspect, size
			end
		end
	end
	return size, size
end

-- Shared head-quad helper used by createList and createEmoteList.
-- Records GL calls into the currently-open display list. w/h are the aspect-corrected
-- quad dimensions; size still drives the head offset and the vertical nudge. The santahat
-- overlay (xmas only) shares the head's rect so it stays glued to the head footprint.
local function headQuad(w, h, size, texturePath, opt)
	gl.Color(1, 1, 1, 1)
	gl.Texture(texturePath)
	glTranslate(opt["head_xOffset"] * size, opt["head_yOffset"] * size, 0)
	DrawRect(-(w / 2), -(h / 2) + (size / 14), (w / 2), (h / 2) + (size / 14))
	if drawSantahat and opt["santahat"] then
		gl.Texture(opt["santahat"])
		DrawRect(-(w / 2), -(h / 2) + (size / 14), (w / 2), (h / 2) + (size / 14))
	end
	gl.Texture(false)
end

-- (Re-)build the three structural display lists (body, head, headblink).
-- Also clears drawlist[4] so stale emote geometry cannot linger after a position change.
local function createList(size)
	local opt = OPTIONS[currentOption]

	-- drawlist[1]: body layer (may be a GL no-op when body = false)
	if drawlist[1] then
		glDeleteList(drawlist[1])
	end
	local bw, bh = fitQuad(opt["body"], size)
	drawlist[1] = glCreateList(function()
		if opt["body"] then
			gl.Texture(opt["body"])
			gl.Color(1, 1, 1, 1)
			DrawRect(-(bw / 2), -(bh / 2), (bw / 2), (bh / 2))
			gl.Texture(false)
		end
	end)

	-- drawlist[2]: normal head
	if drawlist[2] then
		glDeleteList(drawlist[2])
	end
	local hw, hh = fitQuad(opt["head"], size)
	drawlist[2] = glCreateList(function()
		headQuad(hw, hh, size, opt["head"], opt)
	end)

	-- drawlist[3]: blink head
	if drawlist[3] then
		glDeleteList(drawlist[3])
	end
	local bkw, bkh = fitQuad(opt["headblink"], size)
	drawlist[3] = glCreateList(function()
		headQuad(bkw, bkh, size, opt["headblink"], opt)
	end)

	-- drawlist[4] belongs to the active emote; clear it whenever the base lists are rebuilt
	-- so the emote state machine re-creates it against the new size / option.
	if drawlist[4] then
		glDeleteList(drawlist[4])
		drawlist[4] = nil
	end
end

-- Build drawlist[4] for the given emote image path.
-- Called by triggerRandomEmote; safe to call while an emote is already active.
local function createEmoteList(size, emotePath)
	if drawlist[4] then
		glDeleteList(drawlist[4])
	end
	drawlist[4] = nil
	if not emotePath then
		return
	end
	local opt = OPTIONS[currentOption]
	local ew, eh = fitQuad(emotePath, size)
	drawlist[4] = glCreateList(function()
		headQuad(ew, eh, size, emotePath, opt)
	end)
end

---------------------------------------------------------------------------------------------------
--  Position
---------------------------------------------------------------------------------------------------

local parentPos = {}
local positionChange = os.clock()

function updatePosition(force)
	local prevPos = parentPos
	if WG["displayinfo"] ~= nil then
		parentPos = WG["displayinfo"].GetPosition()
	elseif WG["unittotals"] ~= nil then
		parentPos = WG["unittotals"].GetPosition()
	elseif WG["music"] ~= nil then
		parentPos = WG["music"].GetPosition()
	elseif WG["advplayerlist_api"] ~= nil then
		parentPos = WG["advplayerlist_api"].GetPosition()
	else
		local scale = (vsy / 880) * (1 + (Spring.GetConfigFloat("ui_scale", 1) - 1) / 1.25)
		parentPos = { 0, vsx - (220 * scale), 0, vsx, scale }
	end
	if parentPos[5] ~= nil then
		usedImgSize = OPTIONS[currentOption]["imageSize"] * parentPos[5]
		xPos = parentPos[2] + (usedImgSize / 2) + (OPTIONS[currentOption]["xOffset"] * parentPos[5])
		yPos = parentPos[1] + (usedImgSize / 2) + (OPTIONS[currentOption]["yOffset"] * parentPos[5])
		positionChange = os.clock()

		if (prevPos[1] == nil or prevPos[1] ~= parentPos[1] or prevPos[2] ~= parentPos[2] or prevPos[5] ~= parentPos[5]) or force then
			createList(usedImgSize)
		end
	end
end

---------------------------------------------------------------------------------------------------
--  Sound
---------------------------------------------------------------------------------------------------

local function tryPlaySound(soundPath)
	if soundPath then
		Spring.PlaySoundFile(soundPath, 1.0, "ui")
	end
end

---------------------------------------------------------------------------------------------------
--  Option loading / cycling
---------------------------------------------------------------------------------------------------

function loadOption()
	local appliedOption = OPTIONS_original[currentOption]
	OPTIONS[currentOption] = shallow_copy(OPTIONS.defaults)
	for option, value in pairs(appliedOption) do
		OPTIONS[currentOption][option] = value
	end
end

---------------------------------------------------------------------------------------------------
--  Emote state
---------------------------------------------------------------------------------------------------

local emoteActive = false -- true while an emote is being displayed
local emoteElapsed = 0 -- seconds the current emote has been visible
local emoteTimer = 0 -- counts up toward emoteInterval; triggers next emote
local currentEmote = nil -- { path, sound } of the emote being shown

-- Clear all emote state and delete drawlist[4].
-- Called on mascot switch and widget initialisation.
local function resetEmoteState()
	emoteActive = false
	emoteElapsed = 0
	emoteTimer = 0
	currentEmote = nil
	if drawlist[4] then
		glDeleteList(drawlist[4])
		drawlist[4] = nil
	end
end

-- Pick and display a random emote from the current mascot's emote list.
local function triggerRandomEmote()
	local emoteList = OPTIONS[currentOption].emotes
	if not emoteList or #emoteList == 0 then
		return
	end

	currentEmote = emoteList[mathRandom(#emoteList)]
	createEmoteList(usedImgSize, currentEmote.path)
	emoteActive = true
	emoteElapsed = 0
	-- Play the per-emote sound if one exists; otherwise fall back to the ambient mascot sound.
	tryPlaySound(currentEmote.sound or OPTIONS[currentOption]["sound"])
end

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
	resetEmoteState() -- clear emote before updatePosition so createList gets a clean state
	updatePosition(true)
end

---------------------------------------------------------------------------------------------------
--  Widget callbacks
---------------------------------------------------------------------------------------------------

function widget:Initialize()
	-- Rebuild OPTIONS from disk so newly added images/sounds are picked up on reload
	for i = #OPTIONS, 1, -1 do
		OPTIONS[i] = nil
	end
	loadMascotsFromDirectory()

	OPTIONS_original = shallow_copy(OPTIONS)
	OPTIONS_original.defaults = nil

	-- Clamp in case the mascot count changed since the config was last saved
	if not OPTIONS[currentOption] then
		currentOption = 1
	end
	if OPTIONS[currentOption] then
		loadOption()
	end

	resetEmoteState()
	updatePosition()
end

function widget:Shutdown()
	for i = 1, 4 do
		if drawlist[i] then
			glDeleteList(drawlist[i])
		end
	end
end

function widget:PlayerChanged(playerID)
	if playerID == myPlayerID then
		-- reserved for future use
	end
end

local sec = 0
local totalTime = 0
local rot = 0
local bob = 0
local soundTimer = 0
local activeDrawSlot = DRAW_NORMAL -- which drawlist slot is rendered for the head layer

function widget:Update(dt)
	sec = sec + dt
	totalTime = totalTime + dt

	rot = 14 + (6 * mathSin(mathPi * (totalTime / 4)))
	bob = 1.5 * mathSin(mathPi * (totalTime / 5.5))

	local opt = OPTIONS[currentOption]

	-- ── Emote state machine ───────────────────────────────────────────────────
	-- Emotes take full priority over blinking while active.
	local emoteList = opt.emotes
	if emoteList and #emoteList > 0 then
		if emoteActive then
			emoteElapsed = emoteElapsed + dt
			if emoteElapsed >= opt["emoteDuration"] then
				-- Emote finished; tear down and return to normal
				emoteActive = false
				emoteElapsed = 0
				currentEmote = nil
				activeDrawSlot = DRAW_NORMAL -- ← must happen before drawlist[4] is cleared
				if drawlist[4] then
					glDeleteList(drawlist[4])
					drawlist[4] = nil
				end
				sec = 0 -- reset blink timer so a blink doesn't fire immediately
			end
		else
			emoteTimer = emoteTimer + dt
			if emoteTimer >= opt["emoteInterval"] then
				emoteTimer = 0
				triggerRandomEmote()
			end
		end
	end

	-- ── Blink state machine (suspended while an emote is active) ─────────────
	if not emoteActive then
		if sec > opt["blinkTimeout"] then
			activeDrawSlot = DRAW_BLINK
		end
		if sec > (opt["blinkTimeout"] + opt["blinkDuration"]) then
			sec = 0
			activeDrawSlot = DRAW_NORMAL
		end
	else
		-- Emote is active: point at drawlist[4] (guard against nil from createList flush)
		if drawlist[4] then
			activeDrawSlot = DRAW_EMOTE
		end
	end

	-- ── Ambient mascot sound ──────────────────────────────────────────────────
	if opt["sound"] then
		soundTimer = soundTimer + dt
		if soundTimer >= opt["soundInterval"] then
			soundTimer = 0
			tryPlaySound(opt["sound"])
		end
	end

	updatePosition()
end

function widget:DrawScreen()
	if not drawlist[1] then
		return
	end
	glPushMatrix()
	glTranslate(xPos, yPos, 0)
	glCallList(drawlist[1]) -- body (may be a GL no-op when body = false)
	glPushMatrix()
	glTranslate(0, bob, 0)
	glRotate(rot, 0, 0, 1)
	local dl = drawlist[activeDrawSlot]
	if dl then
		glCallList(dl)
	end
	glPopMatrix()
	glPopMatrix()
end

function widget:MousePress(mx, my, mb)
	if mb == 1 and math_isInRect(mx, my, xPos - (usedImgSize / 2), yPos - (usedImgSize / 2), xPos + (usedImgSize / 2), yPos + (usedImgSize / 2)) then
		soundTimer = 0
		resetEmoteState()
		toggleOptions()
	end
end

function widget:TextCommand(command)
	if string.sub(command, 1, 6) == "mascot" then
		soundTimer = 0
		resetEmoteState()
		toggleOptions(tonumber(string.sub(command, 8)))
		Spring.Echo("Playerlist mascot: " .. OPTIONS[currentOption].name)
	end
end

function widget:GetConfigData()
	return { currentOption = currentOption }
end

function widget:SetConfigData(data)
	if data.currentOption ~= nil and OPTIONS[data.currentOption] ~= nil then
		currentOption = data.currentOption or currentOption
	end
end
