-- What the game info panel shows (gui_gameinfo.lua draws it): the game, the map, every modoption that is set and
-- the decoded tweaks, grouped into blocks under the categories of its column, each row with what it says and its
-- tooltip; and the rows a view of them lists. A window requires this once (each require is a model of its own):
--   model.loadLabels()             the strings: before building, and again at a language change
--   model.buildContent()           reads the game: model.categories, model.blocks
--   model.layoutCode(o)            the tweaks' source as code rows for the list's width
--   model.rebuildRows(searchText)  model.rows (and model.rowsGen bumped) for model.selectedCategory, the search and
--                                  model.changedOnly
--   model.listUnits(strip)         the units a tweakunits listing names, for the strip of pictures over it
--   model.copyRows(from, to), model.codeRange()   source to the clipboard, and the rows of it listed
--   model.readReclaimable()        the map's wrecks, once the game has loaded them
--   model.changedCount()           how much of the game is not the way it ships

local Search = require("luaui/Include/search")
-- Tweaks arrive minified, as one enormous line; this lays them out again. Wanted rather
-- than required: the engine lists the game's files once at start, so a file added since is
-- invisible until the next one, and a hard include would take the whole panel down on a
-- /luaui reload rather than costing it only the formatting.
local okSource, LuaSource = pcall(VFS.Include, "luaui/Include/lua_source.lua")
if not okSource then
	LuaSource = nil
end

local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local tableInsert = table.insert

local model = {
	L = {},
	-- every row the panel can show, grouped into blocks; a block is one heading and the rows
	-- under it, and belongs to one category
	blocks = {},
	categories = {},
	-- what the list shows right now: the rows the category, the search and the filter left
	rows = {},
	-- bumped by rebuildRows, so a window knows the list behind it changed
	rowsGen = 0,
	-- the category picked, by its key, never its translated title, so a language change cannot
	-- strand it against titles that have all moved; nil is the All entry
	---@type string?
	selectedCategory = nil,
	changedOnly = false,
}
local L = model.L

local colorTitle = "\255\235\235\235"
local colorDim = "\255\160\160\160"
local colorCode = "\255\170\185\200"
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
model.codeColors = codeColors

local blocks = {}
local categories = {}
local categoryIndex = {}
-- what the picture after a buildoptions entry takes out of its line, in characters
local optionChars = 0

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
local declared = require("modoptions") ---@type table[]
for _, o in ipairs(declared) do
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

local modoptions = BAR.GetModOptionsCopy() ---@type table<string, any>

-- options that aren't worth listing: modoptions.lua layout helpers and values fed by
-- spads/lobby
---@type table<string, boolean>
local ignoredModoptions = {
	sub_header = true,
	dummyboolfeelfreetotouch = true,
}
local function isIgnoredModoption(key)
	return ignoredModoptions[key] or string.sub(key, 1, 5) == "date_"
end

-- Map metadata the lobby fills in: listed, but not something a player needs flagged, so
-- it stays out of the change count and the changed-only filter.
local unflaggedModoptions = {
	mapmetadata_startpos = true,
	mapmetadata_startboxes_set = true,
	mapmetadata_startbox_override = true,
}

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
			-- A build option is a unit's name, and a name is not what most people know a unit
			-- by, so the line ends in a picture of the unit it adds.
			local option = path == "buildoptions" and type(v) == "string" and UnitDefNames[string.lower(v)]
			lines[#lines + 1] = { depth = depth, parts = parts, optionUnitDefID = option and option.id or nil }
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
	local changed = not unflaggedModoptions[key] and not (option and value == option.def)
	if changed then
		countChanges(block, 1)
	end

	local name = getModoptionName(key)
	value = tostring(value)
	-- What the option would have been, shown beside what it is. An empty default says
	-- nothing worth the room.
	local default = changed and option and option.def ~= nil and tostring(option.def) or nil
	block.entries[#block.entries + 1] = {
		type = "option",
		name = name,
		value = value,
		default = default ~= "" and default or nil,
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
function model.buildContent()
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
		---@cast source table
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
	model.blocks, model.categories = blocks, categories
end

----------------------------------------------------------------
-- The rows
----------------------------------------------------------------

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
-- Rebuilds the list from the blocks, honouring the category picked, the search and the
-- changed-only filter. A block whose heading matches the search shows all of its rows,
-- so hunting for a category by name works the way hunting for an option does.
function model.rebuildRows(searchText)
	local rows = {}
	model.rows = rows
	model.rowsGen = model.rowsGen + 1

	local selectedCategory, changedOnly = model.selectedCategory, model.changedOnly
	local query = Search.query(searchText)
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

	-- How many rows of its own block each opening row has under its picture, itself included.
	-- A block shows at least three unfiltered, but a search can leave it one or two, and a
	-- picture three rows tall would then run down over the next unit's. Under a search none
	-- goes past two: the results are a list of matches, not the blocks, and pictures at full
	-- size down it read as the blocks again.
	local maxRows = string.find(searchText or "", "%S") and 2 or 3
	for i = 1, #rows do
		local row = rows[i]
		if row.unitDefID then
			local k = 1
			while k < maxRows do
				local below = rows[i + k]
				if not (below and below.srcBlock == row.srcBlock and below.ownerUnitDefID == row.ownerUnitDefID) then
					break
				end
				k = k + 1
			end
			row.pictureRows = k
		end
	end
end

-- The units a tweakunits listing names, one per unit per slot in listing order, each with the
-- first row of that unit the list kept - which under a search can be a line rather than the
-- opening: strip.ids and strip.rows filled (reused between calls). Answers how many, and the
-- first row of each unit per block and overall (a buildoptions picture jumps through these).
function model.listUnits(s)
	local n = 0
	local rows = model.rows
	local selectedCategory, changedOnly = model.selectedCategory, model.changedOnly
	-- Its own category, and All while only changes are listed: that view is mostly the tweaks,
	-- and a unit block is as hard to find in it as it is in the tweakunits one.
	local listed = selectedCategory == "tweakunits" or (selectedCategory == nil and changedOnly)
	-- The first row of each unit the list shows, per block and overall. Kept whatever the
	-- category, since a buildoptions picture jumps to the unit it names through these too.
	local blockRows, anyRow = {}, {}
	for i = 1, #rows do
		local row = rows[i]
		local id = row.ownerUnitDefID
		if id then
			local named = blockRows[row.srcBlock]
			if not named then
				named = {}
				blockRows[row.srcBlock] = named
			end
			if not named[id] then
				named[id] = i
				anyRow[id] = anyRow[id] or i
				if listed then
					n = n + 1
					s.ids[n] = id
					s.rows[n] = i
				end
			end
		end
	end
	-- Under All the list is shared with every other category, so a strip of a unit or three
	-- would cost more room than the scrolling it saves.
	if selectedCategory == nil and n < 4 then
		n = 0
	end

	return n, blockRows, anyRow
end

-- Puts the rows' source on the clipboard, a whole line at a time and in the order it is
-- listed. Answers whether there was anything to copy.
function model.copyRows(from, to)
	local rows = model.rows
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

-- Every row of source the list is showing, as the first and last; nil when it shows none. In
-- a tweak category that is the whole snippet, which is what someone reaching for select-all is
-- after.
function model.codeRange()
	local rows = model.rows
	local first, last
	for i = 1, #rows do
		if rows[i].type == "code" then
			first = first or i
			last = i
		end
	end

	return first, last
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
	-- A line ending in a picture keeps room for it, so the picture is never pushed out past
	-- the edge of the column.
	if line.optionUnitDefID then
		budget = mathMax(8, budget - optionChars)
	end
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

	-- After the last of the line's rows, which is where its text ends.
	if line.optionUnitDefID and out[#out] then
		out[#out].optionUnitDefID = line.optionUnitDefID
	end
end

-- Code blocks become rows here rather than at build time, since how much of a line fits is
-- a question about the panel's width. The code face is monospaced, so that is a count of
-- characters rather than a measurement per line. o: charW (a character's width), column (the
-- list's room for source), iconSize (a block's picture), ownerChars (the most of a unit's name
-- kept in front of a line), optionChars (what the picture after a buildoptions entry takes).
function model.layoutCode(o)
	optionChars = o.optionChars
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
					gutter = o.iconSize
				end
				if line.ownerName then
					owner = mathMax(owner, mathMin(#line.ownerName, o.ownerChars))
				end
			end
			if owner > 0 then
				owner = owner + 2
			end

			local budget = mathMax(24, mathFloor((o.column - gutter) / o.charW) - owner)
			block.entries = {}
			for i, line in ipairs(block.source) do
				wrapSource(line, budget, block.entries, gutter, block, i, owner)
			end
		end
	end
end

function model.loadLabels()
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
end

local spGetAllFeatures = Spring.GetAllFeatures
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureTeam = Spring.GetFeatureTeam
local gaiaTeamId = Spring.GetGaiaTeamID()

-- The wrecks and trees the map starts with, for the map's reclaimable totals: read once the
-- game has loaded them, before the content is built again.
function model.readReclaimable()
	for _, featureID in ipairs(spGetAllFeatures()) do
		local metal, _, energy = spGetFeatureResources(featureID)
		if spGetFeatureTeam(featureID) == gaiaTeamId then
			reclaimableMetal = reclaimableMetal + metal
			reclaimableEnergy = reclaimableEnergy + energy
		end
	end
end

-- The same total the column's All entry shows, so a badge and the panel can never disagree
-- about how much of this game is not the way it ships.
function model.changedCount()
	return categories[1] and categories[1].changes or 0
end

return model
