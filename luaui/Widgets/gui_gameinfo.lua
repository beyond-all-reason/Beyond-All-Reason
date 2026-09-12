local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Game info",
		desc = "",
		author = "Floris",
		date = "May 2017",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true,
	}
end

-- The panel is laid out the way the keybind editor lays out its own: the same inset area,
-- the title in the top-left corner over a darker card holding the category column, a
-- search field and a filter toggle in the header band, and a 14 px scrollbar standing in
-- its own channel against the right edge.
--
-- Everything shown is built once into blocks of rows, each block belonging to a category.
-- The column, the search box and the "changed only" toggle only pick which of those rows
-- the list shows, so nothing is decoded or measured again while they are used.

-- Shared with the keybind editor, which is where both were written for.
local Editbox = VFS.Include("luaui/Include/keybind_editbox.lua")
local text = VFS.Include("luaui/Include/keybind_text.lua")
local KEYSYMS = VFS.Include("luaui/Include/keybind_keysyms.lua")
local Search = VFS.Include("luaui/Include/search.lua")
-- Tweaks arrive minified, as one enormous line; this lays them out again. Wanted rather
-- than required: the engine lists the game's files once at start, so a file added since is
-- invisible until the next one, and a hard include would take the whole panel down on a
-- /luaui reload rather than costing it only the formatting.
local okSource, LuaSource = pcall(VFS.Include, "luaui/Include/lua_source.lua")
if not okSource then
	LuaSource = nil
end

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spIsGUIHidden = Spring.IsGUIHidden
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glTexture = gl.Texture
local math_isInRect = math.isInRect

local playSounds = true
local buttonclick = "LuaUI/Sounds/buildbar_waypoint.wav"

local screenHeightOrg = 610
local screenWidthOrg = 1100
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local vsx, vsy = spGetViewGeometry()
local widgetScale = (vsy / 1080)
local screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
local screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

---@type function
local RectRound
---@type function
local UiElement
---@type function
local UiScroller
---@type function
local UiScrollerAt
---@type function
local Highlight
---@type function
local UiToggle
---@type function
local UiUnit
local elementCorner
local font, fontMono

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
-- Sizes derived from the scale, in one table rather than a local each, the way the
-- keybind editor holds its own: this chunk is close to Lua's limit of 200 locals.
local metrics = {
	rowHeight = 24,
	catRowHeight = 29,
	rowFs = 13,
	-- A category heading stands taller than the rows under it and is set larger, so it
	-- reads as a divider rather than another row.
	headerRowHeight = 32,
	headerFs = 14,
	catFs = 13,
	-- Decoded tweaks are source, so they get the monospaced face on a tighter row.
	codeRowHeight = 19,
	codeFs = 12,
	-- A tweaked unit gets its picture beside it, spanning the three code rows its block takes
	-- at its shortest. What it gives up to the gaps above and below is what keeps two of them
	-- apart when a unit had only one parameter changed; more comes off the top than the
	-- bottom, so the picture sits against the fields it describes rather than the block above.
	iconSize = 45,
	iconTop = 6,
	iconBottom = 3,
	-- A search shows the lines it matched and nothing around them, so each one names its
	-- unit and shows it small. This is the most of a name that column keeps.
	tinyIcon = 15,
	ownerChars = 22,
	rowPad = 6,
	sidePad = 12,
	catInset = 4,
	-- The line along the bottom of a heading.
	underlineH = 2,
	-- The bar marking a row whose value is not the default one.
	accentW = 3,
	-- Everything that sits against the panel's right edge - the toggle and the scrollbar -
	-- is held off it by this much.
	edgeInset = 4,
	-- The band the title, the search field and the filter toggle share, and the gap below.
	headerH = 34,
	headerGap = 4,
	-- Clearance between the right edge of the rows and the scrollbar beside them.
	listGap = 12,
	-- How far the category card rises above the first entry in it.
	cardLip = 5,
	-- The panel title: its baseline below the top edge, and its size.
	titleY = 17,
	titleFs = 20,
	-- How far the category column starts below the rows beside it, to leave the title room.
	sidebarDrop = 8,
	sidebarW = 240,
	barW = 14,
	-- Rows the wheel moves per notch.
	wheelRows = 3,
	-- Corner radii, taken from FlowUI's so the panel rounds like the rest of the UI.
	csSmall = 2,
	csPanel = 4,
}
local look = {
	-- The category column sits on its own darker card, so it reads apart from the list.
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	selectedFill = { 1, 1, 1, 0.13 },
	-- Brighter than the category column's own selection: this one is over source that is
	-- already coloured, and has to read through it.
	codeSelectedFill = { 0.45, 0.62, 0.95, 0.28 },
	white = { 1, 1, 1 },
	-- Rows and categories hover with the same FlowUI highlight the settings list uses, at
	-- the strength it gives a plain row.
	rowHoverOpacity = 0.14,
	-- An adjusted option is marked three ways at once - a warm band across the row, a bar
	-- down its left edge and warm text - so it is still obvious in a list scrolled past
	-- quickly, where a colour change alone reads as noise.
	changedFill = { 1, 0.8, 0.45, 0.08 },
	changedAccent = { 1, 0.78, 0.35, 0.7 },
	-- The same three marks in the colour of something that did not work.
	failedFill = { 0.92, 0.35, 0.35, 0.1 },
	failedAccent = { 0.92, 0.35, 0.35, 0.8 },
	-- Underline under a category heading: a thin bar fading up out of the bottom edge, in
	-- the hue of the caption above it.
	headerLine = { 1, 0.78, 0.51, 0.4 },
	headerLineFade = { 1, 0.78, 0.51, 0 },
	failedLine = { 0.92, 0.35, 0.35, 0.5 },
	failedLineFade = { 0.92, 0.35, 0.35, 0 },
	sheenTop = { 1, 1, 1, 0.05 },
}
local colorTitle = "\255\235\235\235"
local colorHeader = "\255\255\200\130"
-- Names and values at their default, and the same pair once the value is not the default:
-- both halves of the row brighten, so the row reads as adjusted from either column.
local colorName = "\255\185\183\180"
local colorValue = "\255\145\145\145"
local colorNameOn = "\255\240\240\240"
local colorValueOn = "\255\255\205\100"
-- Facts read off the map and the engine rather than settings, so they take neither the
-- muted look of a default nor the warm one of a change.
local colorInfo = "\255\205\202\199"
local colorSelected = "\255\210\210\205"
local colorDim = "\255\160\160\160"
local colorCode = "\255\170\185\200"
-- A tweak the game could not load. Not a shade of the warm "adjusted" colour: this is not
-- a setting that took effect, and it must not read like one.
local colorDanger = "\255\235\090\090"
-- Decoded tweaks are source, and source is far easier to scan in colour. Keyed by the kind
-- lua_source lexed each token as; a kind with no entry here reads as a plain name.
local codeColors = {
	comment = "\255\125\140\155",
	keyword = "\255\198\146\234",
	string = "\255\180\215\140",
	number = "\255\240\165\125",
	call = "\255\130\170\245",
	op = "\255\135\185\205",
	-- Commas, dots and brackets are most of any source; tinting them like the arithmetic
	-- turns the highlighting into noise, so they stay close to the plain text.
	punct = "\255\140\148\156",
}
-- The zoom the build menu shows an idle cell at, so a unit reads the same in both.
local iconZoom = 0.0375

local L = {}

local show, showOnceMore
local panelList, windowList, backgroundGuishader, panelSig
local listTop, listBottom, listX1, listRight, valueX1, barX1 = 0, 0, 0, 0, 0, 0
local toggleHit, toggleDraw = {}, {}

-- Every row the panel can show, grouped into blocks; a block is one heading and the rows
-- under it, and belongs to one category.
local blocks = {}
local categories = {}
local categoryIndex = {}
-- What the list shows right now: the rows the column, the search box and the toggle left.
local rows = {}
-- Bumped by rebuildRows, so the baked panel knows the list behind it changed.
local rowsGen = 0
-- Bumped by setLayout. A cached row layout carries the value it was built against and is
-- measured again when it moves, without every row being walked at resize.
local layoutGen = 0
local rowMetrics = { gen = -1, rows = -1, totalH = 0 }
local scroll = 0
-- How far the category column is scrolled, in whole entries. A game with enough
-- modoption sections, or a short enough panel, has more of them than the column holds.
local catScroll = 0
local dragging = false
-- Where the thumb was taken hold of, as the distance from the cursor to its top edge. The
-- thumb then follows the cursor by that much, instead of jumping its middle to wherever
-- the press landed.
local dragGrab = 0
-- Rows of decoded tweak the cursor has dragged over, as indices into `rows`. Source is the
-- one thing in here worth taking somewhere else, so it is the one thing that selects.
local selFrom, selTo = 0, 0
local selecting = false
-- Keys taken for a copy. The engine runs a bound action on release as well as on press, so
-- consuming only the press would still fire whatever else the shortcut is bound to.
local consumedKeys = {}
-- Selection is held as the category's key, never its translated title, so a language
-- change cannot strand it against titles that have all moved. nil is the All entry.
---@type string?
local selectedCategory
local changedOnly = false
---@type table
local searchBox
-- What the cursor is over, in the terms the baked panel is painted with. Refilled in
-- place each frame rather than allocated.
local hover = { sb = 0, row = 0, tog = 0, bar = 0 }

-- Input ownership is taken once when the search field takes focus and given back when it
-- loses it, rather than every frame, so chat's handling is restored exactly as it was
-- found.
local ownsInput = false
local fieldHasInput = false
local textInputStarted = false
-- Keys already down when the field took focus. Their release has to be let through, or
-- whatever they started stays stuck on once the field starts swallowing releases.
local heldAtFocus = {}

local rebuildRows

----------------------------------------------------------------
-- The game's own settings
----------------------------------------------------------------

local raptorsEnabled = BAR.Utilities.Gametype.IsRaptors()
local scavengersEnabled = BAR.Utilities.Gametype.IsScavengers()

local tidal = Game.tidal
local map_tidal = Spring.GetModOptions().map_tidal
local reclaimableMetal = 0
local reclaimableEnergy = 0

if map_tidal == "unchanged" then
elseif map_tidal == "low" then
	tidal = 13
elseif map_tidal == "medium" then
	tidal = 18
elseif map_tidal == "high" then
	tidal = 23
end

if Spring.GetTidal then
	tidal = Spring.GetTidal()
end

-- The gamemode sections only describe the gamemode that is running: outside it their
-- options are inert, and listing sixty of them buries the ones that do something.
local function sectionApplies(section)
	if section == "raptor_defense_options" then
		return raptorsEnabled
	end
	if section == "scav_defense_options" then
		return scavengersEnabled
	end
	return true
end

-- modoptions.lua carries the options, the sections they are grouped under, and the
-- defaults every value is compared against.
local optionDefs = {}
local sectionOrder = {}
local sectionNames = {}
for _, o in ipairs(VFS.Include("modoptions.lua")) do
	if o.type == "section" then
		sectionOrder[#sectionOrder + 1] = o.key
		sectionNames[o.key] = o.name
	elseif o.key ~= "sub_header" then
		-- A key can be declared by two sections - raptors and scavengers both carry
		-- initialbox - and the one whose gamemode is running is the one that owns it.
		if not optionDefs[o.key] or sectionApplies(o.section) then
			optionDefs[o.key] = {
				name = o.name,
				desc = o.desc,
				def = o.def,
				min = o.min,
				max = o.max,
				section = o.section,
			}
		end
	end
end

local modoptions = BAR.GetModOptionsCopy()

-- options that aren't worth listing: modoptions.lua layout helpers and values fed by
-- spads/lobby
local ignoredModoptions = {
	sub_header = true,
	dummyboolfeelfreetotouch = true,
}
local function isIgnoredModoption(key)
	return ignoredModoptions[key] or string.sub(key, 1, 5) == "date_"
end

-- What puts an option in the Map category instead of the section it was declared under.
-- Matched on the key, so an option added later lands there without this list growing.
local mapOptionMarkers = { "map", "startpos", "startbox", "start_boxes" }
local function isMapOption(key)
	for i = 1, #mapOptionMarkers do
		if string.find(key, mapOptionMarkers[i], 1, true) then
			return true
		end
	end
	return false
end

-- The numbered tweak slots (tweakdefs, tweakdefs1 .. tweakdefs29) each get their own
-- block, so a game using several of them shows which snippet came from where.
local function tweakSlot(key)
	local kind, n = string.match(key, "^(tweak[du]%a+)(%d*)$")
	if kind ~= "tweakdefs" and kind ~= "tweakunits" then
		return nil
	end
	return kind, tonumber(n) or 0
end

local function stripColorCodes(str)
	return (string.gsub(str, "\255...", ""))
end

-- modoption names/descriptions live in language/<lang>/interface.json under the
-- 'modoptions' namespace, the (english) texts inside modoptions.lua are the fallback for
-- options that aren't translated yet
local function getModoptionName(key)
	local default = optionDefs[key] and optionDefs[key].name
	default = default and stripColorCodes(default) or key
	-- a few names are multi line (lobby layout), here they are shown on a single row
	return (string.gsub(BAR.I18N("modoptions." .. key .. ".name", { default = default }), "%s*\n%s*", " "))
end

local function getSectionName(key)
	local default = sectionNames[key] and stripColorCodes(sectionNames[key]) or key
	return BAR.I18N("modoptions." .. key .. ".name", { default = default })
end

local function appendTooltipLine(str, line)
	return (str ~= "" and str .. "\n" or "") .. line
end

-- description, allowed range, and (when the option isn't at its default) the value it
-- normally has
local function getModoptionTooltipText(key, showDefault)
	local option = optionDefs[key]
	local str =
		BAR.I18N("modoptions." .. key .. ".desc", { default = option and stripColorCodes(option.desc or "") or "" })
	if option then
		if option.min and option.max then
			str = appendTooltipLine(
				str,
				colorDim .. BAR.I18N("ui.gameInfo.range") .. ": " .. colorTitle .. option.min .. "  -  " .. option.max
			)
		end
		if showDefault and option.def ~= nil then
			str = appendTooltipLine(
				str,
				colorDim .. BAR.I18N("ui.gameInfo.default") .. ": " .. colorTitle .. tostring(option.def)
			)
		end
	end
	return (str ~= "" and str .. "\n\n" or "") .. colorDim .. key
end

-- Lua's reserved words. A field named after one cannot be written as a bare name.
local reservedWords = "and break do else elseif end false for function if in local nil not or "
	.. "repeat return then true until while"
local luaKeywords = {}
for word in string.gmatch(reservedWords, "%S+") do
	luaKeywords[word] = true
end

-- A value written the way Lua would have it, not the way it prints. Tweakunits is rebuilt
-- from a parsed table rather than listed as it arrived, and what is rebuilt here is meant
-- to be copied back into a file - so a string needs its quotes, and whatever is inside them
-- needs escaping.
local function luaValue(v)
	if type(v) ~= "string" then
		return tostring(v)
	end

	local str = string.gsub(v, "\\", "\\\\")
	str = string.gsub(str, '"', '\\"')
	-- A literal newline or tab would also break the one-line-per-field layout.
	str = string.gsub(str, "\n", "\\n")
	str = string.gsub(str, "\r", "\\r")
	str = string.gsub(str, "\t", "\\t")

	return '"' .. str .. '"'
end

local function valueKind(v)
	if type(v) == "number" then
		return "number"
	elseif type(v) == "boolean" then
		return "keyword"
	end

	return "string"
end

-- The key of a field: a bare name where Lua allows one, in brackets where it does not -
-- a number, or anything that is not a plain identifier.
local function addKeyParts(k, parts)
	if type(k) == "string" and string.find(k, "^[%a_][%w_]*$") and not luaKeywords[k] then
		parts[#parts + 1] = { s = k, k = "name" }

		return
	end

	parts[#parts + 1] = { s = "[", k = "punct" }
	parts[#parts + 1] = { s = luaValue(k), k = valueKind(k) }
	parts[#parts + 1] = { s = "]", k = "punct" }
end

-- What a tweakunits overwrote on this unit: the paths it set, against the values that were
-- there before. gamedata/unitdefs_post.lua records it while it still can - the before only
-- exists in the defs environment, and only until the tweak is applied.
local function overwrittenFor(name)
	local def = UnitDefNames[name]
	local recorded = def and def.customParams and def.customParams.tweaked_from
	if not recorded then
		return nil
	end

	local out = {}
	for line in string.gmatch(recorded, "[^\n]+") do
		local path, value = string.match(line, "^([^\t]*)\t(.*)$")
		-- First wins: the slots were applied in order, so the earliest record for a path is
		-- the one that predates all of them.
		if path and out[path] == nil then
			out[path] = value
		end
	end

	return out
end

-- What a value used to be, and how far it moved when both ends are numbers. The percentage
-- is of the old value, so a metalcost going 380 to 520 reads as +37%. Left off when it
-- rounds to nothing, where it would say less than the two numbers already do, and when the
-- old value was zero, which nothing can be a percentage of.
local function changeNote(old, new)
	if old == "" then
		return L.wasNew
	end

	local note = L.was .. " " .. old
	local before = tonumber(old)
	if before and before ~= 0 and type(new) == "number" then
		local pct = (new - before) / before * 100
		-- Away from zero on a half, so a drop and a rise of the same size round alike.
		pct = pct >= 0 and mathFloor(pct + 0.5) or -mathFloor(-pct + 0.5)
		if pct ~= 0 then
			note = note .. string.format(" (%+d%%)", pct)
		end
	end

	return note
end

-- Flattens a tweakunits def table into one source line per field, in the shape
-- lua_source.format hands back - parts carrying their own kind - so both kinds of tweak
-- lay out and colour through the same code. Every field is separated the way Lua needs it:
-- what is listed here is source someone can take away, not a readout of it.
local function collectDefLines(t, lines, depth, path, was)
	if depth > 10 then
		lines[#lines + 1] = { depth = depth, parts = { { s = "...", k = "comment" } } }
		return
	end
	for k, v in pairs(t) do
		local parts = {}
		addKeyParts(k, parts)
		parts[#parts + 1] = { s = " = ", k = "op" }
		-- Lowercased, because that is how the defs pass had the keys when it read the values
		-- this is about to be compared against.
		local here = string.lower(tostring(k))
		if path ~= "" then
			here = path .. "." .. here
		end
		if type(v) == "table" then
			parts[#parts + 1] = { s = "{", k = "punct" }
			lines[#lines + 1] = { depth = depth, parts = parts }
			collectDefLines(v, lines, depth + 1, here, was)
			lines[#lines + 1] = { depth = depth, parts = { { s = "},", k = "punct" } } }
		else
			parts[#parts + 1] = { s = luaValue(v), k = valueKind(v) }
			parts[#parts + 1] = { s = ",", k = "punct" }
			-- Said as a comment, so the line still reads as the source it is and still copies
			-- as source. An empty record means there was nothing there before.
			local old = was and was[here]
			if old then
				parts[#parts + 1] = { s = "  -- " .. changeNote(old, v), k = "comment" }
			end
			lines[#lines + 1] = { depth = depth, parts = parts }
		end
	end
end

-- A tweak that compiles can still throw while the game applies it, and that happens in the
-- defs environment, which is built before LuaUI exists and can say nothing to it except
-- through the defs it produces. gamedata/unitdefs_post.lua leaves what went wrong on the
-- commander defs, and this is where it is picked back up.
local function loadDefsTweakFailures()
	local failures = {}
	for _, name in ipairs({ "armcom", "corcom", "legcom" }) do
		local def = UnitDefNames and UnitDefNames[name]
		local recorded = def and def.customParams and def.customParams.tweak_errors
		if recorded then
			for line in string.gmatch(recorded, "[^\n]+") do
				local key, message = string.match(line, "^([^\t]+)\t(.*)$")
				if key then
					failures[key] = message
				end
			end

			return failures
		end
	end

	return failures
end

local defsTweakFailures = loadDefsTweakFailures()

-- Tabs draw as nothing, so tab-indented source would come out flush left. The formatter
-- decides all the indentation anyway; this only matters for the tabs inside string
-- literals and comments, which it passes through.
local function untab(str)
	return (string.gsub(str, "\t", "    "))
end

-- A tweak is whatever the lobby put in the script, so the formatter is never trusted to
-- cope with it: anything it cannot read is listed as it arrived rather than taking the
-- panel down with it. The same path runs when the formatter is not there at all, which is
-- what a /luaui reload sees until the game is started again.
local function formatSource(str)
	str = untab(str)

	if LuaSource then
		local ok, lines = pcall(LuaSource.format, str)
		if ok then
			return lines
		end
	end

	local raw = {}
	for _, line in ipairs(string.lines(str)) do
		if string.find(line, "%S") then
			raw[#raw + 1] = { depth = 0, parts = { { s = line, k = "name" } } }
		end
	end

	return raw
end

-- The decoded contents of one tweak slot, laid out, and what went wrong with it if
-- anything did. tweakdefs is a lua snippet, which is pretty-printed; tweakunits is a lua
-- table, which reads better rebuilt than printed as it was written.
--
-- A tweak that does not decode, or does not compile, is broken in a way the game will not
-- have applied - so it is said so, plainly, rather than left looking like a setting that
-- took effect.
local function decodeTweak(kind, value)
	if kind == "tweakdefs" then
		local ok, decoded = pcall(string.base64Decode, value)
		if not ok then
			return {}, BAR.I18N("ui.gameInfo.decodefailed")
		end
		-- Compiled, never run: this is the same load the game does before applying the
		-- snippet, so a snippet that fails here is one the game rejected too.
		local _, compileError = loadstring(decoded, "tweakdefs")

		return formatSource(decoded), compileError
	end

	local ok, decoded = pcall(string.base64Decode, (string.gsub(value, "_", "=")))
	if not ok then
		return {}, BAR.I18N("ui.gameInfo.decodefailed")
	end

	local parsed, tweaks = pcall(BAR.Utilities.SafeLuaTableParser, decoded)
	if parsed and type(tweaks) == "table" then
		local lines = {}
		for name, ud in pairs(tweaks) do
			if UnitDefNames[name] then
				local from = #lines + 1
				lines[#lines + 1] = {
					depth = 0,
					-- What the picture beside this block is of.
					unitDefID = UnitDefNames[name].id,
					parts = { { s = name, k = "call" }, { s = " = ", k = "op" }, { s = "{", k = "punct" } },
				}
				collectDefLines(ud, lines, 1, "", overwrittenFor(name))
				-- Comma included: each unit is a field of the tweakunits table, and a listing
				-- someone copies has to be the source it came from rather than a look at it.
				lines[#lines + 1] = { depth = 0, parts = { { s = "},", k = "punct" } } }

				-- Every line of the block remembers whose it is, not only the one that opens
				-- it: a search keeps the lines that matched and throws the rest away, and a
				-- `metalcost = 520` on its own says nothing about which unit it belongs to.
				for i = from, #lines do
					lines[i].ownerUnitDefID = UnitDefNames[name].id
					lines[i].ownerName = name
				end
			end
		end
		return lines
	end

	-- Not a table after all, so it is treated as a snippet and checked like one.
	local _, compileError = loadstring(decoded, "tweakunits")

	return formatSource(decoded), compileError or (not parsed and tostring(tweaks) or nil)
end

----------------------------------------------------------------
-- Content
----------------------------------------------------------------

-- An error message, as the words it is made of, so a long one wraps rather than being cut
-- off at the column.
local function messageParts(str)
	local parts = {}
	for word in string.gmatch(tostring(str), "%S+") do
		parts[#parts + 1] = { s = (#parts > 0 and " " or "") .. word, k = "name" }
	end

	return parts
end

-- Lights the column entry a broken tweak sits under, so a failure is visible without
-- having to open the category to find it.
local function markCategoryFailed(key)
	local category = categoryIndex[key]
	if category then
		category.failed = true
		category.fitGen = nil
	end
end

-- Counts adjustments against the category a block belongs to, so the column can say how
-- much of what it lists is not the way the game ships.
local function countChanges(block, n)
	local category = categoryIndex[block.category]
	if category then
		category.changes = category.changes + n
	end
end

local function addBlock(categoryKey, categoryLabel, title)
	local block = {
		category = categoryKey,
		title = title,
		titleLower = string.lower(title),
		header = { type = "header", name = title },
		entries = {},
	}
	blocks[#blocks + 1] = block

	if not categoryIndex[categoryKey] then
		local category = { key = categoryKey, label = categoryLabel, lower = string.lower(categoryLabel), changes = 0 }
		categoryIndex[categoryKey] = category
		categories[#categories + 1] = category
	end

	return block
end

-- A fact read off the map or the engine: never "adjusted", so it carries no default to
-- compare against and drops out under the changed-only filter.
local function addInfo(block, name, value, tooltip)
	value = tostring(value)
	block.entries[#block.entries + 1] = {
		type = "info",
		name = name,
		value = value,
		nameLower = string.lower(name),
		search = string.lower(name .. " " .. value),
		tooltip = tooltip,
	}
end

local function addOption(block, key, value)
	local option = optionDefs[key]
	-- An option modoptions.lua does not declare has no default to compare against, so it
	-- counts as adjusted: it was set by something outside the game's own list.
	local changed = not (option and value == option.def)
	if changed then
		countChanges(block, 1)
	end

	local name = getModoptionName(key)
	value = tostring(value)
	block.entries[#block.entries + 1] = {
		type = "option",
		name = name,
		value = value,
		changed = changed,
		nameLower = string.lower(name),
		search = string.lower(name .. " " .. key .. " " .. value),
		tooltip = { title = name, text = getModoptionTooltipText(key, changed) },
	}
end

local function sortEntries(block)
	table.sort(block.entries, function(a, b)
		if a.nameLower == b.nameLower then
			return a.name < b.name
		end
		return a.nameLower < b.nameLower
	end)
end

local function startPosLabel()
	if Game.startPosType == 0 then
		return BAR.I18N("ui.gameInfo.startPosFixed")
	elseif Game.startPosType == 1 then
		return BAR.I18N("ui.gameInfo.startPosRandom")
	end
	return BAR.I18N("ui.gameInfo.startPosChoose")
end

-- What the map itself says, as opposed to the options set over it.
local function buildMapInfo(block)
	-- The description can run to a paragraph, so it is the row's tooltip rather than a
	-- value shortened to nothing beside the name.
	addInfo(
		block,
		L.map,
		Game.mapName,
		Game.mapDescription and Game.mapDescription ~= "" and { title = Game.mapName, text = Game.mapDescription }
			or nil
	)
	addInfo(block, BAR.I18N("ui.gameInfo.size"), Game.mapX .. " x " .. Game.mapY)
	addInfo(block, BAR.I18N("ui.gameInfo.startPositions"), startPosLabel())
	addInfo(block, BAR.I18N("ui.gameInfo.gravity"), Game.gravity)
	addInfo(block, BAR.I18N("ui.gameInfo.hardness"), Game.mapHardness)
	addInfo(block, BAR.I18N("ui.gameInfo.tidalStrength"), tidal)
	addInfo(
		block,
		BAR.I18N("ui.gameInfo.windStrength"),
		Game.windMin == Game.windMax and Game.windMin or (Game.windMin .. "  -  " .. Game.windMax)
	)
	addInfo(block, BAR.I18N("ui.gameInfo.waterDamage"), Game.waterDamage)
	addInfo(block, BAR.I18N("ui.gameInfo.reclaimableMetal"), reclaimableMetal)
	addInfo(block, BAR.I18N("ui.gameInfo.reclaimableEnergy"), reclaimableEnergy)
end

-- Splits every modoption that is set into the block it belongs to, then hands each block
-- its rows. Options are claimed in order of how specific their home is - the map, then a
-- tweak slot, then the section they were declared under - so none can appear twice.
local function buildContent()
	blocks = {}
	categories = {}
	categoryIndex = {}

	-- The All entry stands for no filter at all, so it is the one category with no key and
	-- is placed by hand rather than by a block asking for it.
	categories[1] = { label = L.all }

	local gameBlock = addBlock("game", L.game, L.game)
	addInfo(gameBlock, L.game, Game.gameName)
	addInfo(gameBlock, BAR.I18N("ui.gameInfo.version"), Game.gameVersion)
	addInfo(gameBlock, BAR.I18N("ui.gameInfo.mutator"), Game.gameMutator)
	addInfo(
		gameBlock,
		BAR.I18N("ui.gameInfo.engine"),
		(Game and Game.version) or (Engine and Engine.version) or BAR.I18N("ui.gameInfo.engineVersionError")
	)

	local mapInfoBlock = addBlock("map", L.map, L.mapInfo)
	buildMapInfo(mapInfoBlock)
	local mapSettingsBlock = addBlock("map", L.map, L.mapSettings)

	-- The section modoptions.lua titles "Other" is the same bucket as the one leftovers go
	-- to, so it takes them rather than a second entry of the same name appearing beside it.
	local otherSection
	for _, key in ipairs(sectionOrder) do
		if getSectionName(key) == L.other then
			otherSection = key
		end
	end

	local sectionKeys = {}
	local tweakSlots = {}
	local leftovers = {}
	for key, value in pairs(modoptions) do
		if not isIgnoredModoption(key) then
			local option = optionDefs[key]
			if option and not sectionApplies(option.section) then
			-- another gamemode's option, inert here
			elseif isMapOption(key) then
				addOption(mapSettingsBlock, key, value)
			else
				local kind, slot = tweakSlot(key)
				if kind then
					-- Sixty of these are declared and all but a handful are empty, so a slot
					-- earns a block only once something has been put in it.
					if value ~= "" and not (option and value == option.def) then
						tweakSlots[#tweakSlots + 1] = { kind = kind, slot = slot, key = key, value = value }
					end
				elseif option and sectionNames[option.section] and option.section ~= otherSection then
					local keys = sectionKeys[option.section]
					if not keys then
						keys = {}
						sectionKeys[option.section] = keys
					end
					keys[#keys + 1] = key
				else
					leftovers[#leftovers + 1] = key
				end
			end
		end
	end

	sortEntries(mapSettingsBlock)

	-- Sections in the order modoptions.lua declares them, so the column reads the way the
	-- lobby's own tabs do rather than in whatever order the values came back in.
	for _, section in ipairs(sectionOrder) do
		local keys = sectionKeys[section]
		if keys then
			local title = getSectionName(section)
			local block = addBlock(section, title, title)
			for _, key in ipairs(keys) do
				addOption(block, key, modoptions[key])
			end
			sortEntries(block)
		end
	end

	-- The bucket for everything unclaimed, before the tweaks: those are a thing apart, and
	-- they belong at the bottom of the column rather than in the middle of the sections.
	if #leftovers > 0 then
		local block = addBlock("other", L.other, L.other)
		for _, key in ipairs(leftovers) do
			addOption(block, key, modoptions[key])
		end
		sortEntries(block)
	end

	-- The order the game applies them in, which gamedata/unitdefs_post.lua sorts for on
	-- purpose: tweakunits first, then tweakdefs over the top of it, so a tweakdefs can
	-- fine-tune what a tweakunits set. Reading them in that order is reading what happened.
	-- Within a kind it is slot order, not key order: "tweakdefs10" sorts before
	-- "tweakdefs2" as a string.
	table.sort(tweakSlots, function(a, b)
		if a.kind == b.kind then
			return a.slot < b.slot
		end
		return a.kind == "tweakunits"
	end)
	for _, tweak in ipairs(tweakSlots) do
		local label = tweak.kind == "tweakdefs" and L.tweakDefs or L.tweakUnits
		local block = addBlock(tweak.kind, label, getModoptionName(tweak.key))
		-- Kept as source lines rather than turned into rows here: how much of a line fits
		-- is a question about the column, so layoutCodeBlocks answers it once that exists.
		local source, failure = decodeTweak(tweak.kind, tweak.value)
		block.source = source
		-- A tweakdefs slot counts as the one thing that was changed however long it runs; a
		-- tweakunits slot counts per unit it names, which is what a reader is counting.
		local units = 0
		for _, line in ipairs(source) do
			if line.unitDefID then
				units = units + 1
			end
		end
		countChanges(block, mathMax(1, units))
		-- What the game reported when it tried to apply the tweak outranks anything worked
		-- out from the source here: it is what actually happened rather than what should.
		failure = defsTweakFailures[tweak.key] or failure
		if failure then
			-- Said at every level the eye lands on: the column entry, the heading, and a
			-- line of its own carrying what the game actually reported.
			markCategoryFailed(tweak.kind)
			block.header.failed = true
			block.header.name = block.title .. "  -  " .. L.tweakFailed
			tableInsert(source, 1, { depth = 0, failed = true, parts = messageParts(failure) })
		end
	end

	-- All stands for every category at once, so its count is theirs added up. Summed here
	-- rather than counted alongside them: it is the same adjustments, not more of them.
	local total = 0
	for i = 2, #categories do
		total = total + categories[i].changes
	end
	categories[1].changes = total
end

----------------------------------------------------------------
-- The row list
----------------------------------------------------------------

local function rowHeightOf(row)
	if row.type == "header" then
		return metrics.headerRowHeight
	elseif row.type == "code" then
		return metrics.codeRowHeight
	end
	return metrics.rowHeight
end

-- A row's position is a sum of what is above it rather than its index times one height:
-- headings and code lines are not the height of an ordinary row. The running total is
-- stamped onto the rows, and redone when the list or the layout changes.
local function ensureRowMetrics()
	if rowMetrics.gen == layoutGen and rowMetrics.rows == rowsGen then
		return
	end

	local off = 0
	for i = 1, #rows do
		rows[i].off = off
		off = off + rowHeightOf(rows[i])
	end
	rowMetrics.totalH = off
	rowMetrics.gen, rowMetrics.rows = layoutGen, rowsGen
end

-- Pixels of content above the first painted row.
local function scrollOffset()
	ensureRowMetrics()
	local first = rows[scroll + 1]

	return first and first.off or 0
end

-- Furthest offset that still fills the band. Walked from the end, so it does not depend
-- on where the list is scrolled to now.
local function maxScroll()
	ensureRowMetrics()
	local band = listTop - listBottom
	local used = 0
	local i = #rows
	while i > 0 do
		local h = rowHeightOf(rows[i])
		if used + h > band then
			break
		end
		used = used + h
		i = i - 1
	end

	return i
end

local function clampScroll()
	local top = maxScroll()
	if scroll > top then
		scroll = top
	end
	if scroll < 0 then
		scroll = 0
	end
end

-- The painted row under y, as its offset from the first painted one. Every hover test and
-- the panel signature go through this, so neither can disagree with what was drawn. nil
-- when y is outside the band or past the last whole row the band can hold.
local function rowAt(y)
	ensureRowMetrics()
	if y > listTop or y <= listBottom then
		return nil
	end

	local base = scrollOffset()
	for i = scroll + 1, #rows do
		local top = listTop - (rows[i].off - base)
		local bottom = top - rowHeightOf(rows[i])
		if bottom < listBottom then
			break
		end
		-- Half-open on the shared edge: rows stack, so one row's top is the next one's
		-- bottom and a closed test would put the cursor in both.
		if y <= top and y > bottom then
			return i - scroll
		end
	end

	return nil
end

local function setScroll(n)
	scroll = n
	clampScroll()
end

-- Indent per block level, and the extra step a line that had to be broken carries, so a
-- continuation is never mistaken for a statement of its own.
local codeIndent = "  "
local codeContinue = "    "

-- One formatted line as its own text, indent and all, with nothing wrapped. This is what a
-- copy hands over: the column's wrapping is a fact about the panel, not about the source,
-- and source pasted back in pieces is not the code it came from.
local function sourceText(line)
	local parts = {}
	for i, part in ipairs(line.parts) do
		parts[i] = i == 1 and (string.gsub(part.s, "^ ", "")) or part.s
	end

	return string.rep(codeIndent, mathMin(line.depth, 12)) .. table.concat(parts)
end
----------------------------------------------------------------
-- Selecting source
----------------------------------------------------------------

local function clearSelection()
	selFrom, selTo, selecting = 0, 0, false
end

-- The selected span, low end first, or nil when nothing is selected.
local function selectionRange()
	if selFrom == 0 then
		return nil
	end

	return mathMin(selFrom, selTo), mathMax(selFrom, selTo)
end

-- Puts the selected source on the clipboard, a whole line at a time and in the order it is
-- listed. Answers whether there was anything to copy.
local function copySelection()
	local from, to = selectionRange()
	if not from then
		return false
	end

	local out = {}
	local lastBlock, lastLine
	for i = from, to do
		local row = rows[i]
		-- One entry per source line: a line the column wrapped is several rows here, and all
		-- of them point back at the one line they came from.
		if row and row.srcBlock and (row.srcBlock ~= lastBlock or row.srcLine ~= lastLine) then
			lastBlock, lastLine = row.srcBlock, row.srcLine
			out[#out + 1] = sourceText(row.srcBlock.source[row.srcLine])
		end
	end

	if #out == 0 then
		return false
	end

	Spring.SetClipboard(table.concat(out, "\n"))

	return true
end

-- Every row of source the list is showing. In a tweak category that is the whole snippet,
-- which is what someone reaching for select-all is after.
local function selectAllCode()
	local first, last
	for i = 1, #rows do
		if rows[i].type == "code" then
			first = first or i
			last = i
		end
	end

	if not first then
		return false
	end

	selFrom, selTo, selecting = first, last, false

	return true
end

-- The thumb, where it is now. Nil when everything fits and no bar is drawn.
local function scrollerThumb()
	return UiScrollerAt(barX1, listBottom, area.x2 - metrics.edgeInset, listTop, rowMetrics.totalH, scrollOffset())
end

-- Scrolls so the thumb's top sits where the cursor has dragged it. The offset taken at the
-- grab is what keeps this relative: the thumb moves with the cursor rather than centring
-- itself on it, so taking hold of it does not shift the view before the drag begins.
local function scrollFromY(y)
	local _, _, trackTop, travel = scrollerThumb()
	if not travel or travel <= 0 then
		return
	end

	local f = (trackTop - (y - dragGrab)) / travel
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end
	setScroll(mathFloor(f * maxScroll() + 0.5))
end

-- Takes hold of the bar. On the thumb that is a grab, and the view stays where it is; on
-- the track either side of it the thumb jumps to the cursor first and is then dragged from
-- its middle, which is what a press on empty track is asking for.
local function grabScroller(y)
	local top, height = scrollerThumb()
	if not top then
		return
	end

	dragging = true
	if y <= top and y >= top - height then
		dragGrab = y - top
	else
		dragGrab = -mathFloor(height * 0.5)
		scrollFromY(y)
	end
end

-- Rebuilds the list from the blocks, honouring the category column, the search box and
-- the changed-only toggle. A block whose heading matches the search shows all of its rows,
-- so hunting for a category by name works the way hunting for an option does.
rebuildRows = function()
	rows = {}
	rowsGen = rowsGen + 1
	-- The selection is a span of row numbers, and these are about to be different rows.
	clearSelection()

	local query = Search.query(searchBox and searchBox:getText())
	for _, block in ipairs(blocks) do
		if not selectedCategory or block.category == selectedCategory then
			-- A block whose own heading matches keeps every row under it, so searching for a
			-- section's name shows the section rather than emptying it.
			local blockMatch = Search.claims(query, block.titleLower)
			local first = #rows
			-- The unit whose opening line is the last one shown. A line still under that one
			-- needs no introduction; a line whose opening was filtered away has to name the
			-- unit itself, since on its own it is a value with nothing to belong to.
			local shownOwner
			for _, entry in ipairs(block.entries) do
				if (not changedOnly or entry.changed) and (blockMatch or Search.matches(query, entry.search)) then
					if entry.unitDefID then
						shownOwner = entry.ownerUnitDefID
						entry.needsOwner = nil
					else
						entry.needsOwner = (entry.ownerLabel and entry.ownerUnitDefID ~= shownOwner) or nil
					end
					rows[#rows + 1] = entry
				end
			end
			if #rows > first then
				tableInsert(rows, first + 1, block.header)
			end
		end
	end

	clampScroll()
end

----------------------------------------------------------------
-- Layout
----------------------------------------------------------------

-- The category column starts below where the rows do, so the title above it is not
-- crowded by the first entry. Everything in the column measures from here.
local function sidebarTop()
	return listTop - metrics.sidebarDrop
end

-- `i` is the entry's place in `categories`, not its place on screen: the two differ by
-- however far the column is scrolled.
local function categoryRect(i)
	local top = sidebarTop() - (i - 1 - catScroll) * metrics.catRowHeight

	return area.x1, top - metrics.catRowHeight, area.x1 + metrics.sidebarW, top
end

-- The category entry under x,y, or nil. Half-open on the shared edge, like the rows, so
-- one point never lands in two entries.
local function sidebarIndexAt(x, y)
	local top = sidebarTop()
	if x < area.x1 or x > area.x1 + metrics.sidebarW or y > top or y <= listBottom then
		return nil
	end

	local i = mathFloor((top - y) / metrics.catRowHeight) + 1 + catScroll
	if not categories[i] then
		return nil
	end

	local _, y1 = categoryRect(i)
	if y1 < listBottom then
		return nil
	end

	return i
end

-- How many entries the column has room for, and how far it can be scrolled.
local function catPageRows()
	return mathMax(1, mathFloor((sidebarTop() - listBottom) / metrics.catRowHeight))
end

local function maxCatScroll()
	return mathMax(0, #categories - catPageRows())
end

local function setCatScroll(n)
	local m = maxCatScroll()
	catScroll = (n < 0 and 0) or (n > m and m) or n
end

-- Rebuilds every rect against the panel size. Whole pixels throughout, so glyph and
-- rectangle edges do not land between pixels.
local function setLayout()
	local s = widgetScale
	local pad = mathFloor(8 * s)
	area.x1 = screenX + pad
	area.y1 = screenY - screenHeight + pad
	area.x2 = screenX + screenWidth - pad
	area.y2 = screenY - pad

	metrics.rowHeight = mathFloor(24 * s)
	metrics.catRowHeight = mathFloor(29 * s)
	metrics.rowFs = mathFloor(metrics.rowHeight * 0.55)
	metrics.headerRowHeight = mathFloor(metrics.rowHeight * 1.35)
	metrics.headerFs = mathFloor(metrics.rowFs * 0.95 * 1.13)
	metrics.catFs = mathFloor(metrics.catRowHeight * 0.55 * 0.85)
	metrics.codeRowHeight = mathFloor(metrics.rowHeight * 0.78)
	metrics.codeFs = mathFloor(metrics.codeRowHeight * 0.62)
	metrics.iconTop = mathMax(1, mathFloor(6 * s))
	metrics.iconBottom = mathMax(1, mathFloor(3 * s))
	metrics.iconSize = metrics.codeRowHeight * 3 - metrics.iconTop - metrics.iconBottom
	-- Small enough to sit on a single row, with the same air above and below it.
	metrics.tinyIcon = metrics.codeRowHeight - mathMax(2, mathFloor(4 * s))
	metrics.underlineH = mathMax(1, mathFloor(2 * s))
	metrics.accentW = mathMax(2, mathFloor(3 * s))
	metrics.rowPad = mathFloor(6 * s)
	metrics.sidePad = mathFloor(12 * s)
	metrics.catInset = mathFloor(4 * s)
	metrics.edgeInset = mathFloor(4 * s)
	metrics.headerH = mathFloor(34 * s)
	metrics.headerGap = mathFloor(4 * s)
	metrics.listGap = mathFloor(12 * s)
	metrics.cardLip = mathFloor(5 * s)
	metrics.titleY = mathFloor(17 * s)
	metrics.titleFs = mathFloor(metrics.rowHeight * 0.85)
	metrics.sidebarDrop = mathFloor(8 * s)
	metrics.sidebarW = mathFloor(240 * s)
	metrics.barW = mathFloor(14 * s)
	metrics.catBarW = mathMax(3, mathFloor(6 * s))
	-- Rounded like the settings panel's inner elements, which take a share of this too.
	metrics.csPanel = mathFloor(elementCorner)
	metrics.csSmall = mathFloor(elementCorner * 0.66)

	listX1 = area.x1 + metrics.sidebarW + metrics.listGap
	listTop = area.y2 - metrics.headerH - metrics.headerGap
	listBottom = area.y1 + metrics.edgeInset
	-- The scrollbar owns a column of its own: its right edge lines up with the toggle
	-- above it, and the rows stop a clear gap short of it rather than running up against
	-- it, so the bar sits in a channel rather than hugging them.
	barX1 = area.x2 - metrics.edgeInset - metrics.barW
	listRight = barX1 - metrics.listGap
	valueX1 = listX1 + mathFloor((listRight - listX1) * 0.55)

	-- The header band: the search field takes the width the filter toggle leaves it.
	local rowTop = area.y2 - mathFloor(4 * s)
	local rowBottom = area.y2 - metrics.headerH + mathFloor(4 * s)
	local fs = mathFloor((rowTop - rowBottom) * 0.5)
	local togW = mathFloor(38 * s)
	local togH = mathFloor((rowTop - rowBottom) * 0.62)
	local togY = mathFloor((rowTop + rowBottom) * 0.5)
	local togX2 = area.x2 - metrics.edgeInset
	toggleDraw = { togX2 - togW, togY - mathFloor(togH * 0.5), togX2, togY - mathFloor(togH * 0.5) + togH }
	-- Measured at the size it is drawn at, not at the header's: the rect below is built off
	-- this, and a caption measured at one size and drawn at another puts it out by whatever
	-- the two happen to differ by.
	metrics.toggleFs = mathFloor(metrics.rowFs * 1.05)
	local labelW = font and mathFloor(font:GetTextWidth(L.changedOnly) * metrics.toggleFs) or mathFloor(90 * s)
	-- Outlined text spreads past the box it is measured in: gui_fonthandler builds the faces
	-- with an outline of 0.22 * 0.9 of the em, so the caption's first glyph already sits that
	-- much left of where its advance box starts. The toggle at the other end has no such
	-- bleed, so matching the two boxes does not read as matching - this buys the caption side
	-- back the room its outline took.
	metrics.captionBleed = mathFloor(metrics.toggleFs * 0.2 + 0.5)
	-- The caption is part of the control: a toggle this small is a poor click target on its
	-- own, and the words beside it are what names the thing being switched. This is also what
	-- the hover paints, so it keeps the same room in front of the caption as it does after
	-- the toggle, rather than opening wider on one side than the other.
	toggleHit = {
		toggleDraw[1] - metrics.rowPad * 2 - labelW - metrics.captionBleed,
		rowBottom,
		togX2 + metrics.rowPad,
		rowTop,
	}
	-- Wider than the gaps inside the control, so the caption reads as belonging to the
	-- toggle beside it rather than to the field it would otherwise sit against.
	searchBox:setRect(listX1, rowBottom, toggleHit[1] - mathFloor(28 * s), rowTop, fs)

	setCatScroll(catScroll)
	layoutGen = layoutGen + 1
	clampScroll()
end

-- A unit's name, cut to the column reserved for it and padded out to it, so the source
-- beside it starts at the same place on every line however long the names are.
local function ownerLabel(name, width)
	if #name > width - 2 then
		name = string.sub(name, 1, width - 4) .. ".."
	end

	return name .. string.rep(" ", width - #name)
end

-- Greedy fill of one formatted source line into the code column: broken between tokens
-- where it can be, and mid-token where a single one is wider than the column, so nothing
-- is lost to a ".." at the edge.
local function wrapSource(line, budget, out, gutter, block, srcLine, ownerWidth)
	-- Capped: source the formatter could not balance (an unclosed `do`, say) would
	-- otherwise indent until there is no column left to write in.
	local indent = string.rep(codeIndent, mathMin(line.depth, 12))
	local cont = indent .. codeContinue
	-- Only the row the block opens on carries the picture; the rows it wraps onto must not
	-- draw a second one over the first.
	local unitDefID = line.unitDefID
	local label = (line.ownerName and (ownerWidth or 0) > 0) and ownerLabel(line.ownerName, ownerWidth) or nil
	-- Two copies of the line: what it measures as, and what it draws as. Colour codes are
	-- four bytes the renderer never draws, so counting them against the column would wrap
	-- the source far short of the edge.
	local plain, painted = indent, indent
	local empty = true
	local lastColor

	local function emit()
		out[#out + 1] = {
			type = "code",
			name = painted,
			plain = plain,
			failed = line.failed,
			unitDefID = unitDefID,
			gutter = gutter,
			-- Whose block this line is inside, and its name ready to put in front of the line
			-- on the rows where a search has left nothing else to say so.
			ownerUnitDefID = line.ownerUnitDefID,
			ownerLabel = label,
			-- Where this row came from, so a copy can hand back whole source lines rather than
			-- the pieces the column had to break them into.
			srcBlock = block,
			srcLine = srcLine,
			-- The slot is only listed at all because it is set, so its lines are part of what
			-- was adjusted and stay under the changed-only filter.
			changed = true,
			search = string.lower(plain),
		}
		unitDefID = nil
		plain, painted = cont, cont
		empty, lastColor = true, nil
	end

	local function add(str, color)
		plain = plain .. str
		-- Only where it changes: a run of the same kind is one code, not one per token.
		painted = painted .. (color ~= lastColor and color or "") .. str
		lastColor = color
		empty = false
	end

	for _, part in ipairs(line.parts) do
		local color = codeColors[part.k] or colorCode
		local piece = empty and (string.gsub(part.s, "^ ", "")) or part.s
		if not empty and #plain + #piece > budget then
			emit()
			piece = (string.gsub(part.s, "^ ", ""))
		end

		-- Still over on its own - a long string, or a path inside a comment - so it is cut
		-- where it lands rather than left to be clipped.
		while #plain + #piece > budget do
			local take = budget - #plain
			if take < 1 then
				break
			end
			-- Never mid-character: half a UTF-8 sequence draws as a replacement glyph.
			while take > 1 and string.find(string.sub(piece, take + 1, take + 1), "^[\128-\191]") do
				take = take - 1
			end
			add(string.sub(piece, 1, take), color)
			piece = string.sub(piece, take + 1)
			emit()
		end

		add(piece, color)
	end

	if not empty then
		emit()
	end
end

-- Code blocks become rows here rather than at build time, since how much of a line fits is
-- a question about the panel's width. The code face is monospaced, so that is a count of
-- characters rather than a measurement per line.
local function layoutCodeBlocks()
	if not fontMono then
		return
	end

	local charW = mathMax(1, fontMono:GetTextWidth("0") * metrics.codeFs)
	local column = listRight - listX1 - metrics.rowPad * 4

	for _, block in ipairs(blocks) do
		if block.source then
			-- Tweakunits name the units they change, so those blocks get a gutter down their
			-- left for the pictures and the source moves over to make room. A tweak that
			-- named nothing the game knows has no pictures to show and keeps the full width.
			local gutter = 0
			-- Room for the longest name in the block, since a search can put any of them in
			-- front of a line. Reserved whether or not one is showing: the column then stays
			-- where it is while a search is typed, instead of the source reflowing per key.
			local owner = 0
			for _, line in ipairs(block.source) do
				if line.unitDefID then
					gutter = metrics.iconSize
				end
				if line.ownerName then
					owner = mathMax(owner, mathMin(#line.ownerName, metrics.ownerChars))
				end
			end
			if owner > 0 then
				owner = owner + 2
			end

			local budget = mathMax(24, mathFloor((column - gutter) / charW) - owner)
			block.entries = {}
			for i, line in ipairs(block.source) do
				wrapSource(line, budget, block.entries, gutter, block, i, owner)
			end
		end
	end
end

-- Category labels, shortened to the column and carrying their colour codes, so the
-- sidebar draws them as they are. Redone when the column resizes.
local function fitCategories()
	for _, c in ipairs(categories) do
		-- How much of what the category lists is not the way the game ships, in the colour an
		-- adjusted value takes in the list itself. The count is never shortened and the label
		-- gives way to it: half a number says nothing, while a shortened name still does.
		local count = (c.changes or 0) > 0 and tostring(c.changes) or nil
		c.countText = count and (colorValueOn .. count) or nil
		local countW = count and (mathFloor(font:GetTextWidth(count) * metrics.catFs) + metrics.rowPad) or 0

		local fitted = text.fit(font, c.label, metrics.sidebarW - metrics.sidePad * 2 - countW, metrics.catFs)
		-- A category holding a tweak the game refused stays red whether it is the selected
		-- one or not: it is a warning, not a state of the column.
		c.textSel = (c.failed and colorDanger or colorSelected) .. fitted
		c.textDim = (c.failed and colorDanger or colorDim) .. fitted
		c.fitGen = layoutGen
	end
end

-- A row's text, shortened to the columns it is drawn in and coloured for whether its
-- value is the default one. Cached against the layout, so a resize measures it again and
-- a scroll does not.
local function fitRow(row)
	-- The owner prefix comes and goes with the search while the layout stands still, so it
	-- is part of what the cached text was built for.
	local owner = row.needsOwner and true or false
	if row.fitGen == layoutGen and row.fitOwner == owner then
		return
	end
	row.fitGen, row.fitOwner = layoutGen, owner

	if row.type == "header" then
		row.fitName = (row.failed and colorDanger or colorHeader)
			.. text.fit(font, row.name, listRight - listX1 - metrics.rowPad * 2, metrics.headerFs)
	elseif row.type == "code" then
		-- Already coloured token by token, and already cut to the column, when the source was
		-- wrapped in this same layout pass. A failure overrides the highlighting: it has to
		-- read as something that did not work, not as source that did.
		row.fitName = row.failed and (colorDanger .. row.plain) or row.name
		if owner then
			-- The column this goes in was taken out of the wrap budget, so the source beside
			-- it still ends where every other line of the block does.
			row.fitName = codeColors.call .. row.ownerLabel .. row.fitName
		end
	else
		-- Map and engine facts are neither adjusted nor left at a default, so they take the
		-- plain reading colour rather than either of the two the options are told apart by.
		local valueColor = colorInfo
		if row.type == "option" then
			valueColor = row.changed and colorValueOn or colorValue
		end
		row.fitName = (row.changed and colorNameOn or colorName)
			.. text.fit(font, row.name, valueX1 - listX1 - metrics.rowPad * 3, metrics.rowFs)
		row.fitValue = valueColor .. text.fit(font, row.value, listRight - valueX1 - metrics.rowPad * 2, metrics.rowFs)
	end
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

-- Geometry drawn between font:Begin and font:End interleaves with the font's batched
-- glyphs and makes both flicker. The list alternates shapes and text row by row, so it
-- queues here and flushes once all the shapes are down. Held flat and refilled in place,
-- since a table per string per frame is hundreds of allocations a second.
local pending = { {}, {} }
local pendingCount = { 0, 0 }

-- The unit pictures are not baked with the rest of the panel: they bind a texture apiece,
-- and a display list is the wrong place for that. The rows note where each one goes while
-- the panel is baked, and the draw below replays those positions live - which is correct
-- for as long as the baked panel is, since anything that moves a row rebuilds both.
local pendingIcons = {}
local iconCount = 0

local function queueIcon(unitDefID, x, y, size)
	local at = iconCount * 4
	pendingIcons[at + 1] = x
	pendingIcons[at + 2] = y
	pendingIcons[at + 3] = unitDefID
	-- Its own size: a block opens with a picture three rows tall, while a line a search
	-- pulled out of one carries a picture small enough to sit on that line.
	pendingIcons[at + 4] = size
	iconCount = iconCount + 1
end

-- Drawn the way the build menu draws its own cells, at the zoom it uses for an idle one.
local function drawIcons()
	if iconCount == 0 then
		return
	end

	-- A picture is three rows tall and hangs off a row that can be the last one the band had
	-- room for, so the band is what it is allowed to paint in.
	gl.Scissor(listX1, listBottom, area.x2 - listX1, listTop - listBottom)
	for i = 0, iconCount - 1 do
		local at = i * 4
		local x, y, size = pendingIcons[at + 1], pendingIcons[at + 2], pendingIcons[at + 4]
		-- Before every one of them, the way the build menu does it: the frame Draw.Unit lays
		-- over the picture is a gradient, and it leaves its last colour behind. Setting white
		-- once outside the loop leaves every picture after the first modulated by that.
		glColor(1, 1, 1, 1)
		UiUnit(x, y - size, x + size, y, nil, 1, 1, 1, 1, iconZoom, nil, nil, "#" .. pendingIcons[at + 3])
	end
	gl.Scissor(false)
	glColor(1, 1, 1, 1)
end

local function queueText(str, x, y, size, opts, which)
	local n = pendingCount[which]
	local at = n * 5
	local list = pending[which]
	list[at + 1] = str
	list[at + 2] = x
	list[at + 3] = y
	list[at + 4] = size
	list[at + 5] = opts
	pendingCount[which] = n + 1
end

local function flushText(which, face)
	local n = pendingCount[which]
	if n == 0 then
		return
	end

	local list = pending[which]
	face:Begin()
	for i = 0, n - 1 do
		local at = i * 5
		face:Print(list[at + 1], list[at + 2], list[at + 3], list[at + 4], list[at + 5])
	end
	face:End()

	pendingCount[which] = 0
end

-- The band a category heading sits on: the sheen and the line closing it off underneath,
-- so the heading closes off the block above it rather than floating in the middle.
local function drawHeaderBand(top, bottom, caption, failed)
	RectRound(
		listX1,
		bottom,
		listRight,
		top - metrics.csSmall,
		metrics.csSmall,
		1,
		1,
		0,
		0,
		look.sheenTop,
		look.sheenTop
	)
	RectRound(
		listX1,
		bottom,
		listRight,
		bottom + metrics.underlineH,
		0,
		0,
		0,
		0,
		0,
		failed and look.failedLine or look.headerLine,
		failed and look.failedLineFade or look.headerLineFade
	)
	queueText(caption, listX1 + metrics.rowPad, mathFloor((top + bottom) * 0.5), metrics.headerFs, "ov", 1)
end

local function drawRow(row, top, bottom, hovered, selected)
	fitRow(row)
	local cy = mathFloor((top + bottom) * 0.5)

	if row.type == "header" then
		drawHeaderBand(top, bottom, row.fitName, row.failed)
		return
	end

	if row.type == "code" then
		if row.failed then
			RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.failedFill)
			RectRound(listX1, bottom, listX1 + metrics.accentW, top, 0, 0, 0, 0, 0, look.failedAccent)
		end
		if selected then
			-- Stops short of the pictures. The gutter belongs to them, and a band running
			-- under one would read as though the unit were selected rather than the lines
			-- beside it; flush against the picture it would read as part of its frame, so it
			-- keeps the same gap from it that it leaves before the source.
			local gutter = row.gutter or 0
			RectRound(
				listX1 + (gutter > 0 and metrics.rowPad * 2 + gutter or 0),
				bottom,
				listRight,
				top,
				0,
				0,
				0,
				0,
				0,
				look.codeSelectedFill
			)
		end
		if row.unitDefID then
			queueIcon(row.unitDefID, listX1 + metrics.rowPad, top - metrics.iconTop, metrics.iconSize)
		elseif row.needsOwner then
			-- Against the right of the gutter, so it reads as belonging to the name it is in
			-- front of rather than floating out at the panel edge.
			local size = metrics.tinyIcon
			queueIcon(
				row.ownerUnitDefID,
				listX1 + metrics.rowPad + (row.gutter or 0) - size,
				mathFloor(cy + size * 0.5),
				size
			)
		end
		queueText(row.fitName, listX1 + metrics.rowPad * 3 + (row.gutter or 0), cy, metrics.codeFs, "ov", 2)

		return
	end

	if row.changed then
		RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.changedFill)
		RectRound(listX1, bottom, listX1 + metrics.accentW, top, 0, 0, 0, 0, 0, look.changedAccent)
	end
	if hovered then
		Highlight(listX1, bottom, listRight, top, metrics.csSmall, look.rowHoverOpacity, look.white)
	end

	-- Indented past the accent bar and under the heading above them, so the block reads as
	-- a group rather than as rows that happen to follow a caption.
	queueText(row.fitName, listX1 + metrics.rowPad * 2, cy, metrics.rowFs, "ov", 1)
	queueText(row.fitValue, valueX1, cy, metrics.rowFs, "ov", 1)
end

-- Whole rows only: the band can end mid-row, and a row painted below it would be clipped
-- by nothing.
local function drawRows()
	local base = scrollOffset()
	local selLow, selHigh = selectionRange()
	for i = 1, #rows - scroll do
		local row = rows[scroll + i]
		if not row then
			break
		end
		local top = listTop - (row.off - base)
		local bottom = top - rowHeightOf(row)
		if bottom < listBottom then
			break
		end
		drawRow(row, top, bottom, hover.row == i, selLow and scroll + i >= selLow and scroll + i <= selHigh)
	end
end

-- The category column: its own card under the title, then one entry per category.
local function drawSidebar()
	-- Derived from the first category rather than measured from the panel top, so the card
	-- keeps its lip above the entries wherever the column starts.
	RectRound(
		area.x1,
		area.y1,
		area.x1 + metrics.sidebarW,
		sidebarTop() + metrics.cardLip,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		look.sidebarFill,
		look.sidebarFillTop
	)
	queueText(L.titleText, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov", 1)

	if categories[1] and categories[1].fitGen ~= layoutGen then
		fitCategories()
	end

	for i = catScroll + 1, #categories do
		local c = categories[i]
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 < listBottom then
			break
		end
		local selected = selectedCategory == c.key
		if selected then
			RectRound(
				x1 + metrics.catInset,
				y1,
				x2 - metrics.catInset,
				y2,
				metrics.csSmall,
				1,
				1,
				1,
				1,
				look.selectedFill
			)
		elseif i == hover.sb then
			Highlight(
				x1 + metrics.catInset,
				y1,
				x2 - metrics.catInset,
				y2,
				metrics.csSmall,
				look.rowHoverOpacity,
				look.white
			)
		end
		local ty = mathFloor((y1 + y2) * 0.5)
		queueText(selected and c.textSel or c.textDim, x1 + metrics.sidePad, ty, metrics.catFs, "ov", 1)
		if c.countText then
			queueText(c.countText, x2 - metrics.sidePad, ty, metrics.catFs, "rov", 1)
		end
	end

	-- A bar of its own, and a slim one: the column is narrow and this only shows up when
	-- there are more categories than the card has room for.
	if maxCatScroll() > 0 then
		local bx2 = area.x1 + metrics.sidebarW - metrics.catInset
		UiScroller(
			bx2 - metrics.catBarW,
			listBottom,
			bx2,
			sidebarTop(),
			#categories * metrics.catRowHeight,
			catScroll * metrics.catRowHeight
		)
	end
end

-- The filter toggle and its caption. The search field draws itself, live, so its caret
-- can blink without the panel being baked again every frame.
local function drawHeader()
	-- The plate goes behind the switch and the switch lights itself, rather than the plate
	-- being laid over it: at the plate's opacity the switch has one of its own bright enough
	-- to swallow it, and painting over the switch only dulls it.
	if hover.tog == 1 then
		Highlight(
			toggleHit[1],
			toggleHit[2],
			toggleHit[3],
			toggleHit[4],
			metrics.csSmall,
			look.rowHoverOpacity,
			look.white
		)
	end
	UiToggle(toggleDraw[1], toggleDraw[2], toggleDraw[3], toggleDraw[4], changedOnly, hover.tog == 1)
	queueText(
		(changedOnly and colorSelected or colorDim) .. L.changedOnly,
		toggleDraw[1] - metrics.rowPad,
		mathFloor((toggleHit[2] + toggleHit[4]) * 0.5),
		metrics.toggleFs,
		"rov",
		1
	)
end

-- Everything inside the panel: the column, the header controls, the list and the
-- scroller. Baked and replayed until the cursor, the list or the screen moves.
local function drawPanel()
	iconCount = 0
	drawSidebar()
	drawHeader()
	drawRows()

	local base = scrollOffset()
	if rowMetrics.totalH > 0 then
		UiScroller(
			barX1,
			listBottom,
			area.x2 - metrics.edgeInset,
			listTop,
			rowMetrics.totalH,
			base,
			hover.bar == 1,
			dragging
		)
	end

	flushText(1, font)
	flushText(2, fontMono)

	-- The toggle's glow leaves its own tint as the current colour, and this list is
	-- replayed every frame, so the leak would reach whoever draws next.
	glColor(1, 1, 1, 1)
end

local function drawWindow()
	UiElement(
		screenX,
		screenY - screenHeight,
		screenX + screenWidth,
		screenY,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		WG.FlowUI.clampedOpacity
	)
end

local function dropLists()
	if panelList then
		glDeleteList(panelList)
		panelList = nil
		panelSig = nil
	end
	if windowList then
		glDeleteList(windowList)
		windowList = nil
	end
end

local function deleteGuishader()
	if backgroundGuishader ~= nil then
		if WG.guishader then
			WG.guishader.DeleteDlist("gameinfo")
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end

-- Reads the hover state and answers a signature of everything the baked panel is painted
-- from. Same signature, same picture, so the display list is replayed as it is.
local function panelSignature(mx, my)
	hover.sb = sidebarIndexAt(mx, my) or 0
	hover.row = 0
	hover.tog = 0
	hover.bar = 0

	if toggleHit[1] and math_isInRect(mx, my, toggleHit[1], toggleHit[2], toggleHit[3], toggleHit[4]) then
		hover.tog = 1
	elseif mx >= listX1 and mx <= listRight then
		hover.row = rowAt(my) or 0
	elseif mx >= barX1 and mx <= area.x2 then
		-- The thumb itself, not the track: it is the part that can be taken hold of, so it
		-- is the part that lights up.
		local top, height = scrollerThumb()
		if top and my <= top and my >= top - height then
			hover.bar = 1
		end
	end

	return hover.sb
		.. "|"
		.. hover.row
		.. "|"
		.. hover.tog
		.. "|"
		.. hover.bar
		.. "|"
		.. scroll
		.. "|"
		.. rowsGen
		.. "|"
		.. layoutGen
		.. "|"
		.. catScroll
		.. "|"
		.. selFrom
		.. "|"
		.. selTo
		.. "|"
		.. (dragging and 1 or 0)
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

local function refreshContent()
	buildContent()
	layoutCodeBlocks()
	rebuildRows()
end

local function loadLabels()
	L.title = BAR.I18N("ui.gameInfo.title")
	L.all = BAR.I18N("ui.gameInfo.all")
	L.other = BAR.I18N("categories.other")
	L.search = BAR.I18N("ui.gameInfo.search")
	L.changedOnly = BAR.I18N("ui.gameInfo.changedOnly")
	L.tweakFailed = BAR.I18N("ui.gameInfo.tweakFailed")
	L.was = BAR.I18N("ui.gameInfo.was")
	L.wasNew = BAR.I18N("ui.gameInfo.wasNew")
	-- No title: it would only name the panel the hint is already inside, where an option's
	-- tooltip has a name of its own worth heading.
	L.copyHint = { text = BAR.I18N("ui.gameInfo.copyHint") }
	L.game = BAR.I18N("ui.gameInfo.game")
	L.map = BAR.I18N("ui.gameInfo.map")
	L.mapInfo = BAR.I18N("ui.gameInfo.mapInfo")
	L.mapSettings = BAR.I18N("ui.gameInfo.mapSettings")
	L.tweakDefs = getModoptionName("tweakdefs")
	L.tweakUnits = getModoptionName("tweakunits")
	L.titleText = colorTitle .. L.title
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
	screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

	font = WG.fonts.getFont()
	-- Decoded tweaks are source, so they take the monospaced face the changelog gives code.
	fontMono = WG.fonts.getFont(3)
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller
	UiScrollerAt = WG.FlowUI.Draw.ScrollerGeometry
	Highlight = WG.FlowUI.Draw.SelectHighlight
	UiToggle = WG.FlowUI.Draw.Toggle
	UiUnit = WG.FlowUI.Draw.Unit

	if not searchBox then
		searchBox = Editbox.new({
			placeholder = L.search,
			onChange = function()
				setScroll(0)
				rebuildRows()
			end,
		})
	end

	setLayout()
	-- The code column moved, so how much of a source line fits it did too.
	layoutCodeBlocks()
	rebuildRows()
	dropLists()
	deleteGuishader()
end

function widget:DrawScreen()
	if not (show or showOnceMore) then
		deleteGuishader()
		return
	end

	-- Pinned rather than assumed: widgets on lower layers draw first and leave blending,
	-- colour and the texture wherever they finished.
	glTexture(false)
	glColor(1, 1, 1, 1)

	local mx, my, lmb = spGetMouseState()
	if dragging then
		if lmb then
			scrollFromY(my)
		else
			dragging = false
		end
	end

	if selecting then
		if lmb then
			-- Only over source: dragging off the end of a snippet holds the selection where it
			-- was rather than reaching into whatever block follows.
			local r = rowAt(my)
			local row = r and rows[scroll + r]
			if row and row.type == "code" then
				selTo = scroll + r
			end
		else
			selecting = false
		end
	end

	local sig = panelSignature(show and mx or -1, show and my or -1)
	if sig ~= panelSig then
		if panelList then
			glDeleteList(panelList)
		end
		panelList = glCreateList(drawPanel)
		panelSig = sig
	end

	if not windowList then
		windowList = glCreateList(drawWindow)
	end
	glCallList(windowList)
	glCallList(panelList)
	drawIcons()
	if show then
		searchBox:draw()
	end

	if WG.guishader and backgroundGuishader == nil then
		backgroundGuishader = glCreateList(function()
			RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1)
		end)
		WG.guishader.InsertDlist(backgroundGuishader, "gameinfo", nil, widget)
	end
	showOnceMore = false

	if math_isInRect(mx, my, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		Spring.SetMouseCursor("cursornormal")

		local row = hover.row > 0 and rows[scroll + hover.row]
		-- Source says how to take it somewhere else, since nothing about a row of it looks
		-- like something you could drag across.
		local tip = row and (row.tooltip or (row.type == "code" and L.copyHint))
		if tip and WG.tooltip then
			WG.tooltip.ShowTooltip("gameinfo", tip.text, nil, nil, tip.title)
		end
	end
end

local function closePanel()
	show = false
	clearSelection()
	if searchBox then
		searchBox:blur()
	end
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("gameinfo")
	end
end

-- Keys are only taken while the search field has focus. This is a panel to read, not one
-- to edit in, so leaving it open must not cost the player their hotkeys - unlike the
-- keybind editor, which has to swallow everything because it is editing the binds.
function widget:KeyPress(key)
	if not show then
		return false
	end

	-- Escape, before the field gets a look at it: it undoes the most recent thing first
	-- and closes the panel only when there is nothing left to undo. The selection is the
	-- thing most recently picked up, and closing over it would throw away what was about
	-- to be copied. A search comes next: the list being read is the one the search made,
	-- and the first Escape is asking for that back rather than for the panel to go.
	if key == 27 then
		if selectionRange() then
			clearSelection()
		elseif searchBox:getText() ~= "" then
			-- Focus stays, so the next thing typed starts a new search.
			searchBox:setText("")
		else
			showOnceMore = true
			closePanel()
		end

		return true
	end

	if searchBox:isFocused() then
		searchBox:keyPress(key)

		return true
	end

	-- Copy and select-all are taken only while there is source selected, which is also the
	-- only time this panel owns the keyboard. Both are bound to something in the shipped
	-- profiles - Ctrl+C focuses the commander - so without that ownership the action handler
	-- would have had them first.
	local _, ctrl = Spring.GetModKeyState()
	if ctrl and (key == KEYSYMS.C or key == KEYSYMS.A) then
		local took = key == KEYSYMS.C and copySelection() or (key == KEYSYMS.A and selectAllCode())
		if took then
			consumedKeys[key] = true

			return true
		end
	end

	return false
end

-- The engine runs bound actions on release as well as on press, so a release has to be
-- swallowed wherever its press was. A key already down when the field took focus is let
-- through instead, or whatever it started stays stuck on.
function widget:KeyRelease(key)
	-- A shortcut taken on the way down has to be taken on the way up too, or the action it
	-- was bound to fires its release half anyway.
	if consumedKeys[key] then
		consumedKeys[key] = nil

		return true
	end

	if not show or not searchBox:isFocused() then
		return false
	end

	if heldAtFocus[key] then
		heldAtFocus[key] = nil

		return false
	end

	return true
end

function widget:TextInput(utf8char)
	if show and searchBox:isFocused() then
		return searchBox:textInput(utf8char)
	end

	return false
end

-- Swallowed across the whole panel, not just the list: a wheel that gets through zooms
-- the camera behind it.
function widget:MouseWheel(up, _value)
	if not show then
		return false
	end

	local x, y = spGetMouseState()
	if not math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		return false
	end

	-- Over the column it scrolls the column, over anything else the list. A wheel that
	-- moved the list while the cursor was on the categories would read as broken.
	if x <= area.x1 + metrics.sidebarW and y > listBottom and y <= sidebarTop() then
		setCatScroll(catScroll + (up and -1 or 1))
	else
		setScroll(scroll + (up and -metrics.wheelRows or metrics.wheelRows))
	end

	return true
end

local function selectCategory(key)
	if selectedCategory == key then
		return
	end
	selectedCategory = key
	setScroll(0)
	rebuildRows()
	if playSounds then
		Spring.PlaySoundFile(buttonclick, 0.6, "ui")
	end
end

-- Clicks inside the panel go to the field, the toggle, the column or the scrollbar; a
-- press outside closes it.
local function mouseEvent(x, y, button, release)
	if spIsGUIHidden() then
		return false
	end

	if not show then
		return false
	end

	-- A press on a top bar button is the top bar's to handle: it closes the open windows
	-- and opens the one that was clicked. Closing (and consuming) here would swallow it.
	if WG.topbar and WG.topbar.buttonAt and WG.topbar.buttonAt(x, y) then
		return false
	end

	if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		if not release and button == 1 then
			if searchBox:mousePress(x, y) then
				clearSelection()
			else
				searchBox:blur()

				local i = sidebarIndexAt(x, y)
				if math_isInRect(x, y, toggleHit[1], toggleHit[2], toggleHit[3], toggleHit[4]) then
					clearSelection()
					changedOnly = not changedOnly
					setScroll(0)
					rebuildRows()
					if playSounds then
						Spring.PlaySoundFile(buttonclick, 0.6, "ui")
					end
				elseif i then
					selectCategory(categories[i].key)
				elseif math_isInRect(x, y, barX1, listBottom, area.x2, listTop) then
					-- The strip between the bar and the panel edge stays grabbable too. The
					-- selection survives it: scrolling to reach more of the source is part of
					-- selecting it, not a change of mind.
					grabScroller(y)
				elseif math_isInRect(x, y, listX1, listBottom, listRight, listTop) then
					-- Source is the only thing here worth taking elsewhere, so it is the only
					-- thing that selects; a press on any other row puts the selection down.
					local r = rowAt(y)
					local row = r and rows[scroll + r]
					if row and row.type == "code" then
						selFrom, selTo = scroll + r, scroll + r
						selecting = true
					else
						clearSelection()
					end
				end
			end
		end

		return true
	elseif not release then
		-- Only a press outside closes. A release out here belongs to a drag that started
		-- on the scrollbar.
		showOnceMore = true -- show once more because the guishader lags behind
		closePanel()

		return true
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

-- Holds input ownership while the search field has focus, or while source is selected.
-- Text ownership is what puts this panel ahead of actionHandler, which otherwise runs
-- before every widget: it would fire the keybinds being typed over, and it has Ctrl+C.
function widget:Update()
	if show and searchBox and (searchBox:isFocused() or selectionRange()) then
		if not fieldHasInput then
			fieldHasInput = true
			heldAtFocus = Spring.GetPressedKeys and Spring.GetPressedKeys() or {}
			ownsInput = widgetHandler:OwnText()

			-- Chat has to be asked to let go, and toggling its input flag is the only public
			-- way to make it cancel. The flag goes straight back because gui_chat persists it,
			-- and a config save while the field is focused would leave chat input dead next
			-- launch.
			if not ownsInput and WG.chat and WG.chat.isInputActive and WG.chat.isInputActive() then
				WG.chat.setHandleInput(false)
				WG.chat.setHandleInput(true)
				ownsInput = widgetHandler:OwnText()
			end
		elseif not ownsInput then
			ownsInput = widgetHandler:OwnText()
		end

		-- Only once it is ours. Starting SDL text input for a field we never took, then
		-- stopping it again on the way out, is what kills that field.
		if ownsInput and not textInputStarted then
			textInputStarted = true
			if Spring.SDLStartTextInput then
				Spring.SDLStartTextInput()
			end
		end
	elseif fieldHasInput then
		fieldHasInput = false
		if ownsInput then
			ownsInput = false
			widgetHandler:DisownText()
		end
		if textInputStarted then
			textInputStarted = false
			if Spring.SDLStopTextInput then
				Spring.SDLStopTextInput()
			end
		end
	end
end

local spGetAllFeatures = Spring.GetAllFeatures
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureTeam = Spring.GetFeatureTeam
local gaiaTeamId = Spring.GetGaiaTeamID()

function widget:GamePreload()
	for _, featureID in ipairs(spGetAllFeatures()) do
		local metal, _, energy = spGetFeatureResources(featureID)
		if spGetFeatureTeam(featureID) == gaiaTeamId then
			reclaimableMetal = reclaimableMetal + metal
			reclaimableEnergy = reclaimableEnergy + energy
		end
	end

	refreshContent()
end

-- Single way in and out, so the action, the top bar and a keybind all open the panel the
-- same way: opening hands the other windows to the top bar to close first.
local function setShown(wanted)
	if not wanted then
		closePanel()

		return
	end

	if not show and WG.topbar then
		WG.topbar.hideWindows()
	end
	show = true
end

function widget:Initialize()
	loadLabels()
	widget:ViewResize()
	refreshContent()

	widgetHandler:AddAction("customgameinfo", function()
		setShown(not show)

		return true
	end, nil, "p")

	widgetHandler:AddAction("customgameinfo_close", function()
		if show then
			setShown(false)

			return true
		end
	end, nil, "p")

	-- lets the handler hide the rest of the interface while the panel is open
	widgetHandler:RegisterModalWindow(function()
		return show == true
	end)

	WG.gameinfo = {}
	WG.gameinfo.toggle = function(state)
		if state == nil then
			state = not show
		end
		setShown(state)
	end
	WG.gameinfo.isvisible = function()
		return show
	end
	-- amount of modoptions that aren't set to their default value
	WG.gameinfo.getChangedModoptionsCount = function()
		-- The same total the column's All entry shows, so the badge and the panel can never
		-- disagree about how much of this game is not the way it ships.
		return categories[1] and categories[1].changes or 0
	end
end

function widget:Shutdown()
	if searchBox then
		searchBox:blur()
	end
	widgetHandler:DisownText()
	if ownsInput then
		ownsInput = false
		if Spring.SDLStopTextInput then
			Spring.SDLStopTextInput()
		end
	end
	dropLists()
	deleteGuishader()
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("gameinfo")
	end
end

function widget:LanguageChanged()
	loadLabels()
	if searchBox then
		-- The field keeps the coloured placeholder it was built with; both have to go for
		-- the new language's wording to be the one drawn.
		searchBox.placeholder = L.search
		searchBox.placeholderShown = nil
	end
	refreshContent()
	widget:ViewResize()
end
