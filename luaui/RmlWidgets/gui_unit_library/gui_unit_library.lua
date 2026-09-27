if not RmlUi then
	return
end

local widget = widget ---@type Widget

-- Captured at chunk scope: RmlUi dispatches keydown/focus listeners through its own Lua plugin,
-- where bare globals read nil (memory: rmlui-key-identifier-and-listener-env, trap 2).
local WG, Spring, RmlUi = WG, Spring, RmlUi

function widget:GetInfo()
	return {
		name = "Unit Library UI",
		desc = "Shared unit library for the mission editor and the terraform brush: pick a unit type to place",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000003,
		enabled = false, -- the terraform suite turns it on; it must never load in a normal game
	}
end

-- The UNIT LIBRARY (refactor plan, Phase U2 and U7): one window and one data model, opened by
-- whichever editor wants a unit type -- the mission editor's ROSTER, the terraform brush's
-- UNITS tab -- rather than the same markup copied into both panels. It PICKS; the caller
-- arms its own placer (luaui/Include/unit_placer) with the pick.
--
--     WG.UnitLibrary.open({ title = "MISSION EDITOR", onPick = function(unitDefName) ... end })
--
-- FINDING a unit fast is the whole job (PtaQ: "the roster is very big"): five filter rows that
-- combine (faction, tier, type, role, domain; AND across rows, OR within one), each chip
-- showing how many it would leave; a search that matches names AND tags as you type ("t2
-- arty cor"); the keyboard (focus on open, arrows, Enter picks, Escape closes); and the
-- filters remembered per editor. Classification is pure and specced (unit_catalogue.lua).
--
-- How it is built follows the RmlUi practices: every control is a fixed callback that records
-- state and raises a flag; arrays are assigned once per change from widget:Update, never
-- inside the event; at most PAGE tiles are bound.

local RML_PATH = "luaui/RmlWidgets/gui_unit_library/gui_unit_library.rml"
local MODEL_NAME = "unit_library_model"
local DOC_KEY = "unit_library"
local RECENT_KEY = "UnitLibraryRecent"
local FILTER_KEY = "UnitLibraryFilter_"
local CYCLE_KEY = "UnitLibraryCycle"
local FOLD_KEY = "UnitLibraryFolded"
local SORT_KEY = "UnitLibrarySort"
--- The collapsible sections (PtaQ's N5), each remembered folded or open.
local SECTIONS = { "filters", "blueprints", "recent", "units" }

local Catalogue = VFS.Include("luaui/RmlWidgets/gui_unit_library/unit_catalogue.lua")
local Blueprints = VFS.Include("luaui/RmlWidgets/gui_unit_library/blueprints.lua")
local Cycle = VFS.Include("luaui/Include/unit_placer/cycle.lua")

--- Where blueprints live: one file each, per user, so a blueprint is shared by copying its
--- file (U9; a project-folder location is a later decision).
local BLUEPRINT_DIR = "LuaUI/Config/UnitBlueprints/"

--- Tiles bound at once. A filter narrows faster than anyone scrolls 700 pictures.
local PAGE = 120
local RECENT_LIMIT = 8
--- Blueprint tiles bound at once.
local BLUEPRINT_PAGE = 24
--- Tiles per row in the grid, for the arrow keys (the grid is sized to fit this many).
local COLUMNS = 5

local CHIP_LABELS = {
	faction = { arm = "ARM", cor = "COR", leg = "LEG", other = "OTHER" },
	tier = { [1] = "T1", [2] = "T2", [3] = "T3", [4] = "T4" },
	type = {
		bot = "BOT",
		veh = "VEH",
		hover = "HOVER",
		ship = "SHIP",
		air = "AIR",
		seaplane = "SEAPLANE",
		turret = "TURRET",
		eco = "ECO",
		util = "UTIL",
		factory = "FACTORY",
	},
	role = { builder = "BUILDER", scout = "SCOUT", raider = "RAIDER", skirmish = "SKIRMISH", arty = "ARTY", aa = "AA" },
	domain = { land = "ALL LAND", sea = "ALL SEA", air = "ALL AIR" },
}
--- An icon before a chip's text (PtaQ, 2026-09-27). The factions wear the feature placer's own
--- faction icons; a type, role or domain wears the strategic icon of a stock unit of that kind
--- (gamedata/icontypes.lua, keyed by unit name), so the chip looks like what it finds.
local FACTION_ICONS = {
	arm = "/luaui/images/terraform_brush/cat_armada_wrecks.png",
	cor = "/luaui/images/terraform_brush/cat_cortex_wrecks.png",
	leg = "/luaui/images/terraform_brush/cat_legion_wrecks.png",
	other = "/luaui/images/terraform_brush/cat_other.png",
}
local ICON_UNITS = {
	type = {
		bot = "armpw",
		veh = "armflash",
		hover = "armsh",
		ship = "armpt",
		air = "armfig",
		seaplane = "armsfig",
		turret = "armllt",
		eco = "armsolar",
		util = "armrad",
		factory = "armlab",
	},
	role = {
		builder = "armck",
		scout = "armflea",
		raider = "armflash",
		skirmish = "armrock",
		arty = "armham",
		aa = "armjeth",
	},
	domain = { land = "armstump", sea = "armpt", air = "armfig" },
}

local CHIP_VALUES = {
	faction = Catalogue.FACTIONS,
	tier = Catalogue.TIERS,
	type = Catalogue.TYPES,
	role = Catalogue.ROLES,
	domain = Catalogue.DOMAINS,
}

-- Every field starts empty and is filled at run time, so the table is typed open: a field
-- declared `nil` here would otherwise be typed nil for good.
---@type table<string, any>
local state = {
	context = nil,
	model = nil,
	document = nil,
	root = nil,
	drag = nil,
	entries = nil, -- the catalogue, built on first open
	byName = {},
	owner = nil, -- { title, onPick }
	filter = { search = "", faction = {}, tier = {}, type = {}, role = {}, domain = {} },
	dirty = true, -- the tiles need recomputing
	wantShown = false, -- what open/close asked for; applied in Update
	shown = false,
	wantFocus = false,
	recent = {},
	lastTiles = {}, -- the names bound last, for the harness and the keyboard
	focusIndex = 1,
	keyIds = nil,
	keyWired = false,
	blueprints = nil, -- { { name, file, units }, ... } read from BLUEPRINT_DIR on first open
	-- The PICK SET (PtaQ's N2): a plain click picks one, Shift+click adds or removes. The
	-- owner cycles through it, one type per drop, in order or at random.
	picks = {},
	cycleMode = Cycle.ORDER,
	folded = {}, -- section name -> true while folded
	sort = { key = "name", desc = false }, -- the SORT chips; remembered
	iconTypes = nil, -- gamedata/icontypes.lua, loaded with the catalogue
}

--------------------------------------------------------------------------------
-- Remembering filters, per editor
--------------------------------------------------------------------------------
local function serialiseFilter(filter)
	local parts = {}
	for _, row in ipairs(Catalogue.ROWS) do
		local values = {}
		for value in pairs(filter[row] or {}) do
			values[#values + 1] = tostring(value)
		end
		table.sort(values)
		parts[#parts + 1] = row .. "=" .. table.concat(values, ",")
	end
	return table.concat(parts, ";")
end

local function parseFilter(text)
	---@type table<string, any>
	local filter = { search = "", faction = {}, tier = {}, type = {}, role = {}, domain = {} }
	for row, values in tostring(text or ""):gmatch("(%a+)=([^;]*)") do
		if filter[row] then
			for value in values:gmatch("[^,]+") do
				filter[row][row == "tier" and (tonumber(value) or value) or value] = true
			end
		end
	end
	return filter
end

local function saveFilter()
	local title = state.owner and state.owner.title
	if title then
		Spring.SetConfigString(FILTER_KEY .. title:gsub("%W", "_"), serialiseFilter(state.filter))
	end
end

local function loadSort()
	local key, dir = tostring(Spring.GetConfigString(SORT_KEY, "") or ""):match("^(%a+):(%a+)$")
	if key and Catalogue.sortKnown(key) then
		return { key = key, desc = dir == "desc" }
	end
	return { key = "name", desc = false }
end

local function loadFolded()
	local folded = {}
	for name in (Spring.GetConfigString(FOLD_KEY, "") or ""):gmatch("[^,]+") do
		folded[name] = true
	end
	return folded
end

local function saveFolded()
	local names = {}
	for _, name in ipairs(SECTIONS) do
		if state.folded[name] then
			names[#names + 1] = name
		end
	end
	Spring.SetConfigString(FOLD_KEY, table.concat(names, ","))
end

--- The model's `folded` table: every section present, so no binding reads a nil.
local function foldModel()
	local out = {}
	for _, name in ipairs(SECTIONS) do
		out[name] = state.folded[name] == true
	end
	return out
end

local function loadRecent()
	local raw = Spring.GetConfigString(RECENT_KEY, "") or ""
	local out = {}
	for name in raw:gmatch("[^,]+") do
		out[#out + 1] = name
	end
	return out
end

--------------------------------------------------------------------------------
-- Blueprints (U9)
--------------------------------------------------------------------------------
local function loadBlueprints()
	state.blueprints = {}
	Spring.CreateDir(BLUEPRINT_DIR)
	for _, path in ipairs(VFS.DirList(BLUEPRINT_DIR, "*.lua", VFS.RAW) or {}) do
		local text = VFS.LoadFile(path, VFS.RAW)
		local blueprint, why = Blueprints.parse(text)
		if blueprint then
			blueprint.file = path
			state.blueprints[#state.blueprints + 1] = blueprint
		else
			Spring.Echo("[unit library] skipped " .. tostring(path) .. ": " .. tostring(why))
		end
	end
	table.sort(state.blueprints, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
end

local function blueprintByName(name)
	for _, blueprint in ipairs(state.blueprints or {}) do
		if blueprint.name == name then
			return blueprint
		end
	end
	return nil
end

--- Save a group as a blueprint under a name (replacing one of the same name).
---@return boolean ok, string|nil pathOrWhy
local function saveBlueprint(name, units)
	if type(units) ~= "table" or #units == 0 then
		return false, "nothing to save"
	end
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return false, "a blueprint needs a name"
	end
	Spring.CreateDir(BLUEPRINT_DIR)
	local path = BLUEPRINT_DIR .. Blueprints.fileName(name)
	local handle, problem = io.open(path, "w")
	if not handle then
		return false, "cannot write " .. path .. ": " .. tostring(problem)
	end
	handle:write(Blueprints.serialise({ name = name, units = units }))
	handle:close()
	loadBlueprints()
	state.dirty = true
	return true, path
end

local function deleteBlueprint(name)
	local blueprint = blueprintByName(name)
	if not blueprint then
		return false
	end
	local ok = os.remove(blueprint.file)
	loadBlueprints()
	state.dirty = true
	return ok ~= nil
end

local function pickBlueprint(name)
	if not state.blueprints then
		loadBlueprints()
	end
	local blueprint = blueprintByName(tostring(name))
	local owner = state.owner
	if not (blueprint and owner and owner.onPickBlueprint) then
		return false
	end
	local ok, problem = pcall(owner.onPickBlueprint, blueprint)
	if not ok then
		Spring.Echo("[unit library] the blueprint handler failed: " .. tostring(problem))
	end
	return ok
end

--------------------------------------------------------------------------------
-- The render pass
--------------------------------------------------------------------------------
local function describe(entry)
	local roles = {}
	for _, role in ipairs(Catalogue.ROLES) do
		if entry.roles[role] then
			roles[#roles + 1] = role
		end
	end
	local domains = {}
	for _, domain in ipairs(Catalogue.DOMAINS) do
		if entry.domains[domain] then
			domains[#domains + 1] = domain
		end
	end
	return string.format(
		"%s (%s) \194\183 T%d %s %s \194\183 %s%s",
		entry.human,
		entry.name,
		entry.tier,
		entry.faction:upper(),
		entry.type,
		table.concat(domains, "+"),
		#roles > 0 and (" \194\183 " .. table.concat(roles, ", ")) or ""
	)
end

--- A tile that is not there. Every tile array keeps a FIXED length, padded with these: a
--- shorter array makes RmlUi evaluate the bindings of the rows it is about to drop, and each
--- one logs "Could not get value from data variable 'tiles[N].name'" (hundreds per keystroke
--- in PtaQ's log). Padded, no binding ever points past the end.
local BLANK_IMG = "/icons/inverted/blank.png"
local function blankTile()
	return {
		name = "",
		human = "",
		img = BLANK_IMG,
		faction = "",
		index = 0,
		count = "",
		blank = true,
		picked = false,
		order = "",
	}
end

local function padded(list, length)
	for index = #list + 1, length do
		list[index] = blankTile()
	end
	return list
end

--- Where a name sits in the pick set (nil if it is not in it).
local function pickOrder(name)
	for index, picked in ipairs(state.picks) do
		if picked == name then
			return index
		end
	end
	return nil
end

local function tileOf(entry, index)
	local order = pickOrder(entry.name)
	return {
		name = entry.name,
		human = entry.human,
		img = entry.img,
		faction = entry.faction,
		index = index,
		count = "",
		blank = false,
		picked = order ~= nil,
		-- The badge only means something with more than one picked.
		order = (order and #state.picks > 1) and tostring(order) or "",
	}
end

local function ensureCatalogue()
	if state.entries then
		return
	end
	local icontypes = VFS.Include("gamedata/icontypes.lua")
	state.iconTypes = icontypes
	state.entries = Catalogue.build(UnitDefs, VFS.FileExists, icontypes, WeaponDefs)
	state.byName = {}
	for _, entry in ipairs(state.entries) do
		state.byName[entry.name] = entry
	end
end

--- The picture a chip wears, or "" for none.
local function chipIcon(row, value)
	if row == "faction" then
		return FACTION_ICONS[value] or ""
	end
	local unitName = ICON_UNITS[row] and ICON_UNITS[row][value]
	local icon = unitName and state.iconTypes and state.iconTypes[unitName]
	if icon and icon.bitmap and UnitDefNames and UnitDefNames[unitName] then
		return "/" .. icon.bitmap
	end
	return ""
end

--- The SORT chips: every key, the active one saying which way round it is.
local function sortChips()
	-- The direction as an ARROW on the active chip (PtaQ: arrows, not HI / LO): down for
	-- biggest-first (and Z to A), up for smallest-first (and A to Z).
	local chips = {}
	for _, sort in ipairs(Catalogue.SORTS) do
		local active = state.sort.key == sort.key
		chips[#chips + 1] = {
			key = sort.key,
			label = sort.label,
			active = active,
			down = active and state.sort.desc == true,
			up = active and state.sort.desc ~= true,
		}
	end
	return chips
end

--- The tiles, the chips with their counts, the recent row. Render pass only.
local function refresh()
	local m = state.model
	if not m then
		return
	end
	ensureCatalogue()
	state.filter.search = m.search or ""
	local matches = Catalogue.sort(Catalogue.filter(state.entries, state.filter), state.sort.key, state.sort.desc)
	m.sortChips = sortChips()
	local tiles, names = {}, {}
	for index = 1, math.min(#matches, PAGE) do
		tiles[index] = tileOf(matches[index], index)
		names[index] = matches[index].name
	end
	m.tiles = padded(tiles, PAGE)
	state.lastTiles = names
	state.focusIndex = math.max(1, math.min(state.focusIndex, #names))
	m.focusIndex = state.focusIndex
	m.countText = (#matches > PAGE) and string.format("%d of %d shown: refine the search", PAGE, #matches)
		or string.format("%d unit type(s)", #matches)
	m.none = #matches == 0

	local counts = Catalogue.counts(state.entries, state.filter)
	local anyActive = (m.search or "") ~= ""
	for _, row in ipairs(Catalogue.ROWS) do
		local chips = {}
		for _, value in ipairs(CHIP_VALUES[row]) do
			local count = counts[row][value] or 0
			local active = state.filter[row][value] == true
			anyActive = anyActive or active
			chips[#chips + 1] = {
				row = row,
				value = tostring(value),
				label = CHIP_LABELS[row][value] or tostring(value),
				icon = chipIcon(row, value) ~= "" and chipIcon(row, value) or BLANK_IMG,
				hasIcon = chipIcon(row, value) ~= "",
				count = count,
				active = active,
				zero = count == 0 and not active,
			}
		end
		m[row .. "Chips"] = chips
	end
	m.anyActive = anyActive

	-- Blueprints, matched by name against the search; offered only to an editor that takes them.
	if not state.blueprints then
		loadBlueprints()
	end
	local words = {}
	for word in tostring(m.search or ""):lower():gmatch("%S+") do
		words[#words + 1] = word
	end
	local blueprintTiles = {}
	for _, blueprint in ipairs(state.blueprints) do
		if #blueprintTiles >= BLUEPRINT_PAGE then
			break
		end
		local hay, ok = blueprint.name:lower(), true
		for _, word in ipairs(words) do
			ok = ok and hay:find(word, 1, true) ~= nil
		end
		if ok then
			local first = state.byName[blueprint.units[1].unitDefName]
			blueprintTiles[#blueprintTiles + 1] = {
				name = blueprint.name,
				human = blueprint.name,
				count = "x" .. #blueprint.units,
				img = first and first.img or BLANK_IMG,
				blank = false,
			}
		end
	end
	local anyBlueprint = #blueprintTiles > 0
	m.blueprints = padded(blueprintTiles, BLUEPRINT_PAGE)
	m.blueprintsShown = anyBlueprint and state.owner ~= nil and state.owner.onPickBlueprint ~= nil

	local recent = {}
	for _, name in ipairs(state.recent) do
		if state.byName[name] then
			recent[#recent + 1] = tileOf(state.byName[name], 0)
		end
	end
	local anyRecent = #recent > 0
	m.recent = padded(recent, RECENT_LIMIT)
	m.recentShown = anyRecent and not anyActive

	m.pickCount = #state.picks
	m.pickSetShown = #state.picks > 1
	m.cycleMode = state.cycleMode
end

--------------------------------------------------------------------------------
-- Picking
--------------------------------------------------------------------------------
--- Tell the owner what is picked now: the first name (what a one-type owner arms with) and
--- the whole set with how to cycle it, `{ names = { ... }, mode = "abc" | "random" }`.
local function notifyOwner()
	local owner = state.owner
	if not (owner and owner.onPick and state.picks[1]) then
		return
	end
	local names = {}
	for index, name in ipairs(state.picks) do
		names[index] = name
	end
	local ok, problem = pcall(owner.onPick, names[1], { names = names, mode = state.cycleMode })
	if not ok then
		Spring.Echo("[unit library] the pick handler failed: " .. tostring(problem))
	end
end

--- A tile clicked. Plain: that one alone. Shift (additive): add it to the pick set, or take it
--- back out.
local function pick(name, additive)
	name = tostring(name or "")
	ensureCatalogue()
	if not state.byName[name] then
		return false
	end
	state.picks = Cycle.toggle(state.picks, name, additive == true)
	state.model.picked = state.picks[1] or ""
	if pickOrder(name) then
		state.recent = Catalogue.remember(state.recent, name, RECENT_LIMIT)
		Spring.SetConfigString(RECENT_KEY, table.concat(state.recent, ","))
	end
	state.dirty = true
	notifyOwner()
	return true
end

--- The CYCLE chips: A B C or RANDOM. Remembered; the owner hears the set again.
local function setCycle(mode)
	state.cycleMode = Cycle.mode(mode)
	Spring.SetConfigString(CYCLE_KEY, state.cycleMode)
	state.dirty = true
	if #state.picks > 1 then
		notifyOwner()
	end
end

--- A SORT chip: pick that key (in the direction it starts in), or flip the one already on.
local function setSort(key)
	key = tostring(key)
	if not Catalogue.sortKnown(key) then
		return false
	end
	if state.sort.key == key then
		state.sort.desc = not state.sort.desc
	else
		state.sort = { key = key, desc = Catalogue.sortDefaultDesc(key) }
	end
	Spring.SetConfigString(SORT_KEY, state.sort.key .. ":" .. (state.sort.desc and "desc" or "asc"))
	state.focusIndex = 1
	state.dirty = true
	return true
end

--- Put the pick down (the owner let go of it: a right click on the map, CANCEL).
local function clearPicks()
	state.picks = {}
	if state.model then
		state.model.picked = ""
	end
	state.dirty = true
end

local function fold(name)
	name = tostring(name)
	state.folded[name] = (not state.folded[name]) or nil
	if state.model then
		state.model.folded[name] = state.folded[name] == true
	end
	saveFolded()
end

--- A chip pressed. Plain: that value alone (again: clear the row). Shift: add or remove it.
local function chip(row, value, additive)
	if not state.filter[row] then
		return
	end
	if row == "tier" then
		value = tonumber(value) or value
	end
	state.filter[row] = Catalogue.toggle(state.filter[row], value, additive)
	state.focusIndex = 1
	state.dirty = true
	saveFilter()
end

local function clearAll()
	for _, row in ipairs(Catalogue.ROWS) do
		state.filter[row] = {}
	end
	state.model.search = ""
	state.filter.search = ""
	state.focusIndex = 1
	state.dirty = true
	saveFilter()
end

--------------------------------------------------------------------------------
-- The keyboard, on the search field (RmlUi eats these keys before widget:KeyPress)
--------------------------------------------------------------------------------
---@return table
local function keyIds()
	if state.keyIds then
		return state.keyIds
	end
	local ok, ids = pcall(function()
		return RmlUi.key_identifier()
	end)
	if not (ok and type(ids) == "table") then
		ok, ids = pcall(function()
			return RmlUi.key_identifier
		end)
	end
	if ok and type(ids) == "table" then
		state.keyIds = ids
	else
		Spring.Echo("[unit library] RmlUi.key_identifier did not resolve; Enter and arrows will not work")
		state.keyIds = {}
	end
	return state.keyIds
end

--- Arrows move the highlight, Enter picks it, Escape closes. Returns whether it was ours.
local function onKey(key)
	local ids = keyIds()
	local count = #state.lastTiles
	if key == ids.RETURN or key == ids.NUMPADENTER then
		local name = state.lastTiles[state.focusIndex]
		if name then
			pick(name)
		end
		return true
	elseif key == ids.ESCAPE then
		state.wantShown = false
		return true
	elseif count > 0 and (key == ids.RIGHT or key == ids.LEFT or key == ids.DOWN or key == ids.UP) then
		local step = (key == ids.RIGHT and 1) or (key == ids.LEFT and -1) or (key == ids.DOWN and COLUMNS) or -COLUMNS
		state.focusIndex = math.max(1, math.min(count, state.focusIndex + step))
		state.model.focusIndex = state.focusIndex
		return true
	end
	return false
end

local function wireKeys()
	if state.keyWired or not state.document then
		return
	end
	local search = state.document:GetElementById("ul-search")
	if not search then
		return
	end
	state.keyWired = true
	search:AddEventListener("keydown", function(event)
		local key = event and event.parameters and event.parameters.key_identifier
		if key and onKey(key) then
			event:StopPropagation()
		end
	end, false)
end

--------------------------------------------------------------------------------
-- The model: fixed callbacks, registered once at OpenDataModel. State only.
--------------------------------------------------------------------------------
local initialModel = {
	title = "UNIT LIBRARY",
	search = "",
	picked = "",
	tiles = {},
	recent = {},
	recentShown = false,
	none = false,
	countText = "",
	hoverText = "",
	focusIndex = 1,
	anyActive = false,
	blueprints = {},
	blueprintsShown = false,
	pickCount = 0,
	pickSetShown = false,
	cycleMode = Cycle.ORDER,
	folded = {},
	setCycle = function(_, mode)
		setCycle(mode)
	end,
	sortChips = {},
	setSort = function(_, key)
		setSort(key)
	end,
	fold = function(_, name)
		fold(name)
	end,
	pickBlueprint = function(_, name)
		pickBlueprint(name)
	end,
	deleteBlueprint = function(event, name)
		pcall(function()
			event:StopPropagation()
		end)
		deleteBlueprint(tostring(name))
	end,
	factionChips = {},
	tierChips = {},
	typeChips = {},
	roleChips = {},
	domainChips = {},
	pick = function(event, name)
		local additive = false
		pcall(function()
			additive = event.parameters.shift_key == 1 or event.parameters.shift_key == true
		end)
		pick(name, additive)
	end,
	chip = function(event, row, value)
		local additive = false
		pcall(function()
			additive = event.parameters.shift_key == 1 or event.parameters.shift_key == true
		end)
		chip(row, value, additive)
	end,
	clearAll = function()
		clearAll()
	end,
	hover = function(_, name)
		local entry = state.byName[tostring(name)]
		state.model.hoverText = entry and describe(entry) or ""
	end,
	searchChanged = function()
		state.focusIndex = 1
		state.dirty = true
	end,
	searchClear = function()
		state.model.search = ""
		state.focusIndex = 1
		state.dirty = true
	end,
	searchFocus = function()
		Spring.SDLStartTextInput()
	end,
	searchBlur = function()
		Spring.SDLStopTextInput()
	end,
	close = function()
		state.wantShown = false
	end,
}

--------------------------------------------------------------------------------
-- The API the editors use
--------------------------------------------------------------------------------
local function open(options)
	options = options or {}
	local previous = state.owner and state.owner.title
	state.owner = { title = options.title, onPick = options.onPick, onPickBlueprint = options.onPickBlueprint }
	if options.title ~= previous then
		-- A pick belongs to the editor that made it.
		clearPicks()
		-- Each editor finds the library as it left it.
		local saved = options.title
			and Spring.GetConfigString(FILTER_KEY .. tostring(options.title):gsub("%W", "_"), "")
		state.filter = parseFilter(saved)
		if state.model then
			state.model.search = ""
		end
	end
	if state.model then
		state.model.title = options.title and ("UNITS \194\183 " .. tostring(options.title)) or "UNIT LIBRARY"
	end
	state.wantShown = true
	state.wantFocus = true
	state.focusIndex = 1
	state.dirty = true
	return state.document ~= nil
end

local function close()
	state.wantShown = false
end

function widget:Initialize()
	state.context = RmlUi.GetContext("shared")
	if not state.context then
		return false
	end
	state.folded = loadFolded()
	state.sort = loadSort()
	state.cycleMode = Cycle.mode(Spring.GetConfigString(CYCLE_KEY, Cycle.ORDER))
	initialModel.folded = foldModel()
	initialModel.cycleMode = state.cycleMode
	state.model = state.context:OpenDataModel(MODEL_NAME, initialModel, self)
	if not state.model then
		return false
	end
	state.document = state.context:LoadDocument(RML_PATH, self)
	if not state.document then
		widget:Shutdown()
		return false
	end
	state.document:ReloadStyleSheet()
	state.document:Hide()
	state.root = state.document:GetElementById("ul-root")
	if WG.TerraformerShared and WG.TerraformerShared.registerDocument then
		WG.TerraformerShared.registerDocument(DOC_KEY, state.document)
	end
	if WG.TerraformerShared and WG.TerraformerShared.attachDraggable and state.root then
		state.drag = WG.TerraformerShared.attachDraggable(state.document, "ul-handle", state.root, {})
	end
	state.recent = loadRecent()
	wireKeys()

	WG.UnitLibrary = {
		open = open,
		close = close,
		isOpen = function()
			return state.wantShown
		end,
		--- Who opened it last, by title.
		owner = function()
			return state.owner and state.owner.title or nil
		end,
		--- Blueprints (U9): save a group under a name, list them, pick one (as a click would),
		--- delete one.
		saveBlueprint = saveBlueprint,
		deleteBlueprint = deleteBlueprint,
		pickBlueprint = pickBlueprint,
		blueprints = function()
			if not state.blueprints then
				loadBlueprints()
			end
			local out = {}
			for index, blueprint in ipairs(state.blueprints) do
				out[index] = blueprint.name
			end
			return out
		end,
		--- Is a screen point (RmlUi coordinates) inside the library window?
		contains = function(x, y)
			local root = state.root
			if not (state.shown and root and root.offset_width > 0) then
				return false
			end
			return x >= root.absolute_left
				and x <= root.absolute_left + root.offset_width
				and y >= root.absolute_top
				and y <= root.absolute_top + root.offset_height
		end,
		--- Pick as a click on the tile would (additive = Shift held). For the harness and for
		--- keyboard shortcuts.
		pick = pick,
		--- The SORT chips: a key as a click would (again flips it), and what is on now.
		setSort = setSort,
		sort = function()
			return { key = state.sort.key, desc = state.sort.desc }
		end,
		--- A chip's icon, for checks.
		chipIcon = function(row, value)
			ensureCatalogue()
			return chipIcon(row, value)
		end,
		--- The pick set, in order.
		picks = function()
			return state.picks
		end,
		--- The CYCLE chips: "abc" or "random".
		setCycle = setCycle,
		cycleMode = function()
			return state.cycleMode
		end,
		--- The owner let go of its pick: the tiles stop showing it.
		clearPicks = clearPicks,
		--- Fold or open a section ("filters", "blueprints", "recent", "units") as its title
		--- row would, and read whether one is folded.
		fold = fold,
		folded = function(name)
			return state.folded[tostring(name)] == true
		end,
		--- Set the search, and whole filter rows (a list of values each), as the controls would.
		--- A row left out is left alone; `clear = true` clears every row first.
		setFilter = function(filter)
			filter = filter or {}
			if filter.clear then
				for _, row in ipairs(Catalogue.ROWS) do
					state.filter[row] = {}
				end
				state.model.search = ""
			end
			if filter.search ~= nil then
				state.model.search = filter.search
			end
			for _, row in ipairs(Catalogue.ROWS) do
				if type(filter[row]) == "table" then
					local set = {}
					for _, value in ipairs(filter[row]) do
						set[value] = true
					end
					state.filter[row] = set
				end
			end
			state.focusIndex = 1
			state.dirty = true
		end,
		--- A chip press, as a click (additive = Shift held).
		chip = chip,
		--- A key on the search field (an RmlUi key identifier), as the keyboard would send it.
		key = function(name)
			return onKey(keyIds()[name])
		end,
		focusIndex = function()
			return state.focusIndex
		end,
		--- The unit names the tiles show now, in order.
		visible = function()
			return state.lastTiles
		end,
		--- How many unit types the library knows.
		size = function()
			ensureCatalogue()
			return #state.entries
		end,
		--- A unit's classification (type, tier, faction, domains, roles, stats), for checks.
		classify = function(name)
			ensureCatalogue()
			return state.byName[tostring(name)]
		end,
		--- Milliseconds one filter + chip-count pass takes over the whole catalogue (the work
		--- a keystroke costs), averaged over `n` runs.
		benchFilter = function(n)
			ensureCatalogue()
			n = n or 20
			local filter =
				{ search = "t2", faction = { cor = true }, tier = {}, type = { bot = true }, role = {}, domain = {} }
			local started = Spring.GetTimer()
			for _ = 1, n do
				Catalogue.filter(state.entries, filter)
				Catalogue.counts(state.entries, filter)
			end
			return Spring.DiffTimers(Spring.GetTimer(), started) * 1000 / n
		end,
		--- Every entry, for checks and for tuning Catalogue.ROLE_RULES against real data.
		entries = function()
			ensureCatalogue()
			return state.entries
		end,
	}
end

function widget:Update()
	if state.drag then
		state.drag.tick()
	end
	if state.wantShown ~= state.shown and state.document then
		state.shown = state.wantShown
		if state.shown then
			state.document:Show()
			if WG.TerraformerShared and WG.TerraformerShared.bringToFront then
				WG.TerraformerShared.bringToFront(DOC_KEY)
			end
		else
			state.document:Hide()
			Spring.SDLStopTextInput()
		end
	end
	if state.shown and state.dirty then
		state.dirty = false
		refresh()
	end
	-- Focus the search on open, so typing starts finding at once. After the refresh, a frame
	-- after Show, so the field is laid out.
	if state.shown and state.wantFocus and not state.dirty then
		state.wantFocus = false
		local search = state.document:GetElementById("ul-search")
		if search then
			search:Focus()
		end
	end
end

function widget:Shutdown()
	Spring.SDLStopTextInput()
	WG.UnitLibrary = nil
	if WG.TerraformerShared and WG.TerraformerShared.unregisterDocument then
		WG.TerraformerShared.unregisterDocument(DOC_KEY)
	end
	if state.context and state.model then
		state.context:RemoveDataModel(MODEL_NAME)
		state.model = nil
	end
	if state.document then
		state.document:Close()
		state.document = nil
	end
end
