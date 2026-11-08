-- The in-game keybind editor, apart from how it looks: the catalog resolved into categories and rows, the staged
-- keymap and its undo, the presets, the dialogs and the key capture as data, and what a key does. It draws nothing and
-- knows no place on the screen.
--
-- Edits are staged and touch neither the engine nor disk until Save, which is also where a
-- default forks: it cannot take the edits, so saving makes a new preset of them.
--
-- A window requires this once (each require is a model of its own) and draws what it holds: model.rows,
-- model.categories, model.dialog, model.capturing, model.dirty, and its controls (searchBox, nameBox,
-- presetDropdown, compareDropdown: keybind_editbox and keybind_dropdown; keyboard, selectionBuilder:
-- keybind_keyboard and keybind_select_builder). It passes key input on (model.keyPress, keyRelease, textInput),
-- sends presses to what they do (model.pressButton, pressLabel, handleZone, pressGrid, selectCategory, showKey)
-- and shows the tooltips model.rowTip, presetTip and changedTip make. It answers `model.view`:
--   rowsChanged()   the rows were built again: to be clamped where they scroll
--   scrollToTop()   the list shows something new, from the top
--   layout()        everything is to be placed again
-- and watches model.presetsGen (the pickers' options changed) and model.refit (the column's labels did).

local keyConfig = require("luaui/configs/keyboard_layouts")
local keybindConfig = require("luaui/Include/keybind_config")
local keybindModel = require("luaui/Include/keybind_model")

-- Shape and rules are documented in common/configs/keybinds.README.md; this is the
-- contract Chobby and the lobby read too, so it is data rather than Lua.
local catalog = keybindConfig.load("common/configs/keybind_catalog.json") or {}
local Dropdown = require("luaui/Include/keybind_dropdown")
local Editbox = require("luaui/Include/keybind_editbox")
local KEYSYMS = require("luaui/Include/keybind_keysyms")
local Search = require("luaui/Include/search")
local profiles = require("luaui/Include/keybind_profiles")
local text = require("luaui/Include/keybind_text")

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

---@type table<string, any>
local model = {
	profiles = profiles,
	categories = {},
	-- Selection is held as the catalog's i18n key, never its translated title, so a language
	-- change cannot strand it against titles that have all moved.
	---@type string?
	selectedCategory = nil,
	-- Set while a category asks to be drawn as the grid menu instead of a row list.
	---@type table?
	gridGroup = nil,
	---@type table
	working = nil,
	---@type table
	resolvedCatalog = nil,
	catalogShiftPair = {},
	-- Headers, notes, links and the bindable rows themselves, which share no shape beyond the type
	-- naming which they are.
	---@type table[]
	rows = {},
	-- Bumped by rebuildRows, so what is baked knows the list behind it changed.
	rowsGen = 0,
	dirty = false,
	---@type table?
	capturing = nil,
	---@type table?
	dialog = nil,
	presetOptions = {},
	scanKeys = {},
	clashing = {},
	hidden = {},
	labels = {},
	changedKey = {},
	sources = {},
	widgetActions = require("luaui/Include/keybind_widget_actions"),
	changedCount = -1,
	-- A column entry changed, so its label is to be fitted again.
	refit = false,
	undo = {},
	batching = false,
	batchEdited = false,
	keyboardGen = -1,
	selectCommand = require("luaui/Include/keybind_select"),
	-- Bumped whenever the pickers' options change, which also rewords Save.
	presetsGen = 0,
	keyboard = require("luaui/Include/keybind_keyboard").new(),
	selectionBuilder = require("luaui/Include/keybind_select_builder").new(),
}
-- What the window answers and is told, filled in by it.
---@type table<string, function>
local view = {}
model.view = view

-- The engine loads this one file; a profile is applied by writing it here.
local customKeysFile = profiles.activeFile

-- Stands in for the generated Other bucket when no catalog category is titled the same.
-- A table cannot collide with a catalog key, which is always a string.
local generatedOtherKey = {}
local otherCategoryKey = generatedOtherKey
-- Grouped chips per action. Derived purely from working.byAction, and every path that
-- changes that rebuilds the rows, so rebuildRows is where it gets dropped.
local chipGroups = {}
local catalogAny, catalogAnyPrefixes = {}, {}
local L = {}
model.L = L

local colorText = "\255\235\235\235"
-- The font is shared with every other widget, some of which set an outline and leave it set.
local outline = { 0, 0, 0, 0.4 }
local colorDim = "\255\160\160\160"
local colorHeader = "\255\255\200\130"
local colorDanger = "\255\235\090\090"

-- Shared by every unchanged row that asks: no keys at all, and nothing to copy.
local noRaws = {}
-- In the order the column and the rows list them; the leftovers under Other close the first.
local sections = {
	{ key = "game", inAll = true, withOther = true },
	{ key = "widgets", heading = "widgets", inAll = false },
}
-- File stems in anims/: the engine own pairing (MouseHandler.cpp) and the cursors BAR custom
-- commands declare. An order with no cursor of its own has no entry.
local cursors = {
	move = "move",
	attack = "attack",
	areaattack = "attack",
	manuallaunch = "attack",
	manualfire = "dgun",
	settarget = "settarget",
	settargetnoground = "settarget",
	fight = "fight",
	patrol = "patrol",
	guard = "defend",
	repair = "repair",
	reclaim = "reclamate",
	resurrect = "revive",
	restore = "restore",
	capture = "capture",
	loadunits = "pickup",
	unloadunits = "unload",
	wait = "wait",
	gatherwait = "gather",
	selfd = "selfd",
}
-- The 48 px set is nearest a row height. Most cursors number frames from 0 and a few from 1;
-- false when there is neither.
local cursorTextures = setmetatable({}, {
	__index = function(self, stem)
		local base = "anims/icexuick_100/cursor" .. stem
		local path = (VFS.FileExists(base .. "_0.png") and base .. "_0.png")
			or (VFS.FileExists(base .. "_1.png") and base .. "_1.png")
			or false
		self[stem] = path

		return path
	end,
})

-- Sent as commands because widgetHandler can be a per-widget proxy, which carries no
-- Enable/DisableWidget.
local function toggleMenu(useGrid)
	if useGrid == nil then
		return
	end

	local api = WG.buildmenu
	if api and api.setLayout then -- a build menu with both layouts (Build Menu FlowUI2)
		api.setLayout(useGrid and "grid" or "build")
	elseif useGrid then
		Spring.SendCommands("luaui disablewidget Build menu")
		Spring.SendCommands("luaui enablewidget Grid menu")
	else
		Spring.SendCommands("luaui disablewidget Grid menu")
		Spring.SendCommands("luaui enablewidget Build menu")
	end
end

-- A copy of the staged keymap, for putting back. Binds and keysets are copied rather than
-- shared: the edits rewrite entries in place.
function model.snapshotOf()
	local binds, byAction = {}, {}
	for i, b in ipairs(model.working.binds) do
		binds[i] = { keyset = b.keyset, action = b.action }
	end
	for action, ks in pairs(model.working.byAction) do
		local copy = {}
		for i, k in ipairs(ks) do
			copy[i] = { raw = k.raw, display = k.display }
		end
		byAction[action] = copy
	end

	return { binds = binds, byAction = byAction }
end

----------------------------------------------------------------
-- Profiles and the picker
----------------------------------------------------------------

-- Staged edits mark the active one with a "*", a default included: the edits are real and
-- unsaved either way.
local function buildPresetOptions()
	local active = profiles.activeName()

	model.presetOptions = {}
	for _, b in ipairs(profiles.builtins) do
		local label = (model.dirty and b.name == active) and (b.name .. " *") or b.name
		model.presetOptions[#model.presetOptions + 1] =
			{ label = label, name = b.name, tag = L.defaultTag, group = "default" }
	end
	for _, name in ipairs(profiles.list()) do
		local label = (model.dirty and name == active) and (name .. " *") or name
		model.presetOptions[#model.presetOptions + 1] = { label = label, name = name, group = "own" }
	end

	return model.presetOptions
end

-- Shipped profiles can be copied but not renamed or deleted.
function model.activeIsOwn()
	return profiles.get(profiles.activeName()) ~= nil
end

-- Single source for whether a button is live, so it cannot draw enabled and do nothing.
function model.buttonEnabled(id)
	if id == "save" or id == "reset" then
		return model.dirty
	end
	if id == "edit" then
		return model.activeIsOwn()
	end

	return true
end

local function currentPresetIndex()
	local name = profiles.activeName()
	for i = 1, #model.presetOptions do
		if model.presetOptions[i].name == name then
			return i
		end
	end

	return 1
end

----------------------------------------------------------------
-- Catalog and the row list
----------------------------------------------------------------

-- Probed rather than declared: a label shared with the command card names the thing rather
-- than a numbered variant, so the argument goes on the end instead.
local labelPlacesArg = {}
local function prefixRowLabel(key, arg, row, col)
	local places = labelPlacesArg[key]
	if places == nil then
		places = BAR.I18N(key, { n = "", row = "", col = "" }):find("", 1, true) ~= nil
		labelPlacesArg[key] = places
	end

	if places then
		return BAR.I18N(key, { n = arg, row = row, col = col })
	end

	return BAR.I18N(key) .. " " .. arg
end

-- Resolve i18n labels once (search rebuilds rows per keystroke); redone on refresh.
local function buildResolvedCatalog()
	labelPlacesArg = {}
	model.resolvedCatalog = {}
	catalogAny, catalogAnyPrefixes, model.catalogShiftPair = {}, {}, {}
	model.hidden, model.labels, model.sources = {}, {}, {}
	local widgets, manifestChanges = model.widgetActions.manifests()
	model.manifestsVersion = manifestChanges

	-- Asked for with an empty default, so a missing key is silent and reads as none.
	local function describe(item)
		local command = (item.action or item.prefix or ""):match("^%S+")
		-- Appended one by one: a nil in a table constructor ends what ipairs walks.
		local keys = {}
		if item.description then
			keys[#keys + 1] = item.description
		end
		if item.label and item.label:sub(1, 9) == "commands." then
			keys[#keys + 1] = item.label .. "_tooltip"
		end
		if command then
			keys[#keys + 1] = "cmd." .. command
			keys[#keys + 1] = "cmd." .. command .. "._description"
			keys[#keys + 1] = "cmd.luarules." .. command
		end
		for _, key in ipairs(keys) do
			local found = BAR.I18N(key, { default = "" })
			-- Commands with no engine description got a stand-in reading "<chat command description: X>"
			-- rather than being left out.
			local placeholder = type(found) == "string" and found:match("^%b<>$") ~= nil
			if type(found) == "string" and found ~= "" and found ~= key and not placeholder then
				return found
			end
		end

		return nil
	end

	local allGroups = {}
	for _, group in ipairs(catalog) do
		allGroups[#allGroups + 1] = group
	end
	for _, group in ipairs(model.widgetActions.groups(widgets)) do
		allGroups[#allGroups + 1] = group
	end
	-- A widget that is off would otherwise leave its actions under Other as raw ids.
	local hidden = model.widgetActions.hiddenActions(widgets)
	if #hidden > 0 then
		allGroups[#allGroups + 1] = { hidden = hidden }
	end

	for _, group in ipairs(allGroups) do
		if group.hidden then
			model.resolvedCatalog[#model.resolvedCatalog + 1] =
				{ hidden = group.hidden, title = "", titleLower = "", items = {} }
			for _, h in ipairs(group.hidden) do
				model.hidden[h] = true
			end
		else
			local title = group.title or BAR.I18N(group.category)
			local g = {
				category = group.category,
				layout = group.layout,
				section = group.section,
				title = title,
				titleLower = title:lower(),
				items = {},
			}
			for _, item in ipairs(group.items) do
				if item.prefix then
					if item.alwaysModifier == "any" then
						catalogAnyPrefixes[#catalogAnyPrefixes + 1] = item.prefix
					end
					g.selection = g.selection or item.selection == true
					g.items[#g.items + 1] = {
						prefix = item.prefix,
						label = item.label,
						unit = item.unit,
						selection = item.selection,
						members = item.members,
						membersFrom = item.membersFrom,
						description = describe(item),
						icon = (item.icon and VFS.FileExists(item.icon) and item.icon) or nil,
					}
				else
					if item.action then
						if item.alwaysModifier == "any" then
							catalogAny[item.action] = true
						elseif item.alwaysModifier == "shift" then
							model.catalogShiftPair[item.action] = true
						end
					end
					local label = item.label and BAR.I18N(item.label) or item.action
					local stem = item.action and cursors[item.action:match("^%S+")]
					local cursor = stem and cursorTextures[stem] or nil
					-- The picture a key shows for the action: the catalog's own where it names
					-- one, else the cursor an order is already known by.
					local icon = (item.icon and VFS.FileExists(item.icon) and item.icon) or cursor
					g.items[#g.items + 1] = {
						action = item.action,
						actionLower = item.action and item.action:lower(),
						label = label,
						labelLower = label:lower(),
						icon = icon,
						description = describe(item),
					}
					if item.action then
						model.labels[item.action] = label
						model.sources[item.action] = title
					end
					-- One picture in a group gives every row in it the column, so the names line up.
					g.hasCursors = g.hasCursors or icon ~= nil
				end
			end
			if g.layout == "grid" then
				-- Pulled off the same catalog entries the list would have used, so the grid and
				-- the flat form name things identically.
				g.categoryLabels = {}
				for _, it in ipairs(group.items) do
					local n = it.action and it.action:match("^gridmenu_category%s+(%d+)$")
					if n then
						g.categoryLabels[tonumber(n)] = BAR.I18N(it.label)
					end
					if it.prefix == "gridmenu_key" and it.label then
						local key = it.label
						g.cellLabel = function(row, col)
							return BAR.I18N(key, { n = row .. " " .. col, row = row, col = col })
						end
					end
				end
				g.cellLabel = g.cellLabel or function(row, col)
					return row .. " " .. col
				end
				for _, it in ipairs(group.items) do
					if it.action == "gridmenu_cycle_builder" and it.label then
						g.cycleLabel = BAR.I18N(it.label)
					end
				end
				g.cycleLabel = g.cycleLabel or "gridmenu_cycle_builder"
			end
			model.resolvedCatalog[#model.resolvedCatalog + 1] = g
		end
	end

	L.other = BAR.I18N("categories.other")
	L.widgets = BAR.I18N("ui.keybinds.editor.widgets")
	L.addBind = BAR.I18N("ui.keybinds.editor.addBind")
	L.addBindTitle = BAR.I18N("ui.keybinds.editor.addBindTitle")
	L.editBindTitle = BAR.I18N("ui.keybinds.editor.editBindTitle")
	L.addSelection = BAR.I18N("ui.keybinds.select.addLink")
	L.selectionAdd = BAR.I18N("ui.keybinds.select.titleAdd")
	L.selectionEdit = BAR.I18N("ui.keybinds.select.titleEdit")
	L.selectionChooseKey = BAR.I18N("ui.keybinds.select.chooseKey")
	L.otherLower = L.other:lower()
	L.title = BAR.I18N("ui.keybinds.title")
	L.allCategories = BAR.I18N("ui.keybinds.editor.allCategories")
	L.gridNextPage = BAR.I18N("actions.gridMenu.nextPage")
	-- gui_gridmenu hardcodes both the caption and the key, so it is not bindable and there is no
	-- i18n key to read.
	L.gridBack = BAR.I18N("ui.buildMenu.back")

	model.categories = { { label = L.allCategories } }
	otherCategoryKey = generatedOtherKey
	local seen = {}
	for _, section in ipairs(sections) do
		local first = #model.categories + 1
		for _, g in ipairs(model.resolvedCatalog) do
			-- Keyed like the row filter below, not by title: two categories that translate to
			-- the same words are still separate, and one has to not vanish from the column.
			if not g.hidden and not seen[g.category] and model.sectionOf(g) == section then
				seen[g.category] = true
				model.categories[#model.categories + 1] = { label = g.title, key = g.category }
				-- A catalog category of the same name takes the leftovers, matching the row
				-- order below, rather than a second column entry appearing beside it.
				if section.withOther and g.title == L.other then
					otherCategoryKey = g.category
				end
			end
		end
		if section.withOther and otherCategoryKey == generatedOtherKey then
			model.categories[#model.categories + 1] = { label = L.other, key = otherCategoryKey }
		end
		if section.heading and #model.categories >= first then
			table.insert(model.categories, first, { label = L[section.heading], header = true })
		end
	end
	-- Every keyreload comes through here, so without this the entry went missing until a preset
	-- switch happened to move the count.
	model.changedCount = -1
	L.pressKey = BAR.I18N("ui.keybinds.editor.pressKey")
	L.preset = BAR.I18N("ui.keybinds.editor.preset")
	L.defaultTag = BAR.I18N("ui.keybinds.editor.defaultTag")
	L.newProfile = BAR.I18N("ui.keybinds.editor.newProfile")
	L.duplicate = BAR.I18N("ui.keybinds.editor.duplicate")
	L.duplicateTooltip = BAR.I18N("ui.keybinds.editor.duplicateTooltip")
	L.edit = BAR.I18N("ui.keybinds.editor.edit")
	L.editTooltip = BAR.I18N("ui.keybinds.editor.editTooltip")
	L.editLockedTooltip = BAR.I18N("ui.keybinds.editor.editLockedTooltip")
	L.saveAsNew = BAR.I18N("ui.keybinds.editor.saveAsNew")
	L.noticeDefault = BAR.I18N("ui.keybinds.editor.noticeDefault")
	L.noticeDefaultUnsaved = BAR.I18N("ui.keybinds.editor.noticeDefaultUnsaved")
	L.noticeUnsaved = BAR.I18N("ui.keybinds.editor.noticeUnsaved")
	L.changed = BAR.I18N("ui.keybinds.editor.changed")
	L.boundToAny = BAR.I18N("ui.keybinds.editor.boundToAny")
	L.changedUnknown = BAR.I18N("ui.keybinds.editor.changedUnknown")
	L.changedNoneTooltip = BAR.I18N("ui.keybinds.editor.changedNoneTooltip")
	L.compareWith = BAR.I18N("ui.keybinds.editor.compareWith")
	L.compareNone = BAR.I18N("ui.keybinds.editor.compareNone")
	L.compareNoneHint = BAR.I18N("ui.keybinds.editor.compareNoneHint")
	L.conflictOrder = BAR.I18N("ui.keybinds.editor.conflictOrder")
	L.conflictShipped = BAR.I18N("ui.keybinds.editor.conflictShipped")
	L.revertNone = BAR.I18N("ui.keybinds.editor.revertNone")
	L.presetDefault = BAR.I18N("ui.keybinds.editor.presetDefault")
	L.presetOwn = BAR.I18N("ui.keybinds.editor.presetOwn")
	L.export = BAR.I18N("ui.keybinds.editor.export")
	L.exportTooltip = BAR.I18N("ui.keybinds.editor.exportTooltip")
	L.import = BAR.I18N("ui.keybinds.editor.import")
	L.importTooltip = BAR.I18N("ui.keybinds.editor.importTooltip")
	L.keyboard = BAR.I18N("ui.keybinds.editor.keyboard")
	L.keyboardTooltip = BAR.I18N("ui.keybinds.editor.keyboardTooltip")
	-- The keyboard page's cards are built from this catalog, so they go with it.
	model.keyInfo = nil
	model.keyboard:refreshStrings()
	L.importTitle = BAR.I18N("ui.keybinds.editor.importTitle")
	L.importEmpty = BAR.I18N("ui.keybinds.editor.importEmpty")
	L.importNone = BAR.I18N("ui.keybinds.editor.importNone")
	L.importAsNew = BAR.I18N("ui.keybinds.editor.importAsNew")
	L.importAdd = BAR.I18N("ui.keybinds.editor.importAdd")
	L.ok = BAR.I18N("ui.keybinds.editor.ok")
	L.editTitle = BAR.I18N("ui.keybinds.editor.editTitle")
	L.delete = BAR.I18N("ui.keybinds.editor.delete")
	L.duplicateTitle = BAR.I18N("ui.keybinds.editor.duplicateTitle")
	L.save = BAR.I18N("ui.keybinds.editor.save")
	L.reset = BAR.I18N("ui.keybinds.editor.reset")
	L.resetConfirm = BAR.I18N("ui.keybinds.editor.resetConfirm")
	L.saveTitle = BAR.I18N("ui.keybinds.editor.saveTitle")
	L.discard = BAR.I18N("ui.keybinds.editor.discard")
	L.unsavedTitle = BAR.I18N("ui.keybinds.editor.unsavedTitle")
	L.unsavedMessage = BAR.I18N("ui.keybinds.editor.unsavedMessage")
	L.applyFailedTitle = BAR.I18N("ui.keybinds.editor.applyFailedTitle")
	L.accept = BAR.I18N("ui.keybinds.editor.accept")
	L.cancel = BAR.I18N("ui.keybinds.editor.cancel")
end

-- The modifier names a search can name, off the same list the chips are printed from.
local modifierKey = {}
for _, name in ipairs(keyConfig.modifierOrder) do
	modifierKey[name:lower()] = true
end

-- A keyset's canonical form, kept on the keyset record against the raw it came from: the
-- change and conflict checks below run for every row on every rebuild.
local function canonOf(k)
	if k.canonFor ~= k.raw then
		k.canon, k.canonFor = keybindModel.canonicalKeyset(k.raw), k.raw
	end

	return k.canon
end

-- Compared as sets of canonical keysets, so spelling and order do not count as a change.
local function rowChange(action)
	local base = model.base
	if not base then
		return nil
	end

	local theirs = base.byAction[action]
	local seen, n = {}, 0
	for _, k in ipairs(model.working.byAction[action] or noRaws) do
		local c = canonOf(k)
		if not seen[c] then
			seen[c] = true
			n = n + 1
			if not (theirs and theirs.set[c]) then
				return theirs and theirs.raws or noRaws
			end
		end
	end
	if (theirs and theirs.n or 0) ~= n then
		return theirs and theirs.raws or noRaws
	end

	return nil
end

-- SDL's key for the OS layout, which a press is matched by; KeyboardLayout only relabels keys.
function model.scanToKey(scan)
	local key = model.scanKeys[scan]
	if key == nil then
		key = Spring.GetKeyFromScanSymbol and Spring.GetKeyFromScanSymbol("sc_" .. scan) or ""
		model.scanKeys[scan] = key
	end

	return key
end

-- Flagged when the game ships the two on one key - by design, so no clash of the player
-- making. Hidden actions are left out: sharing a key with a listed one is how the catalog says
-- they belong together.
function model.conflictsOf(action, raws)
	local index = model.working.collisions
	if not index then
		return nil
	end

	local out, seen
	for _, raw in ipairs(raws) do
		-- Any holder at all: for a key being captured this action is not among them yet.
		for _, other in ipairs(keybindModel.collidersOf(index, action, raw)) do
			local name = other.action
			if not model.hidden[name] and not (seen and seen[name]) then
				seen = seen or {}
				seen[name] = true
				out = out or {}
				local pair = (action < name) and (action .. "\n" .. name) or (name .. "\n" .. action)
				out[#out + 1] = {
					action = name,
					shipped = model.shippedPairs ~= nil and model.shippedPairs[pair] == true,
				}
			end
		end
	end

	return out
end

-- A prefix entry's declared members, then bound actions under the prefix that nothing earlier claimed.
function model.prefixActions(item, claimed)
	-- Read here rather than with the rest of the catalog, so a profile made a moment ago gets its
	-- row without waiting for a refresh.
	local members = item.members
	if item.membersFrom == "profiles" then
		-- Switching to the one already on can only do nothing. One already bound is still found from
		-- the keymap below, which is what leaves a stale self-binding somewhere to remove it.
		local active = profiles.activeName()
		members = {}
		for _, builtin in ipairs(profiles.builtins) do
			if builtin.name ~= active then
				members[#members + 1] = builtin.name
			end
		end
		for _, own in ipairs(profiles.list()) do
			if own ~= active then
				members[#members + 1] = own
			end
		end
	end

	-- A declared member is a row whether or not it is bound. Families the catalog cannot
	-- enumerate (buildunit_ is per unit) list none and are discovered from what is bound.
	local matched = {}
	for _, member in ipairs(members or {}) do
		local action = item.prefix .. member
		if not claimed[action] then
			claimed[action] = true
			matched[#matched + 1] = action
		end
	end

	local found = {}
	for action in pairs(model.working.byAction) do
		if not claimed[action] and action:sub(1, #item.prefix) == item.prefix then
			claimed[action] = true
			found[#found + 1] = action
		end
	end
	table.sort(found)
	for i = 1, #found do
		matched[#matched + 1] = found[i]
	end

	return matched
end

function model.sectionOf(group)
	for _, section in ipairs(sections) do
		if section.key == (group.section or "game") then
			return section
		end
	end

	return sections[1]
end

-- Per category, the actions whose chips redden, claimed the way the rows claim them.
function model.countClashes()
	model.clashing = {}
	local function clashes(action)
		local raws = {}
		for i, k in ipairs(model.working.byAction[action] or noRaws) do
			raws[i] = k.raw
		end
		for _, o in ipairs(model.conflictsOf(action, raws) or noRaws) do
			if not o.shipped then
				model.clashing[action] = true

				return true
			end
		end

		return false
	end

	local counts, claimed = {}, {}
	for _, group in ipairs(model.resolvedCatalog) do
		if group.hidden then
			for _, h in ipairs(group.hidden) do
				claimed[h] = true
			end
		end
	end
	for _, group in ipairs(model.resolvedCatalog) do
		if not group.hidden then
			local n = counts[group.category] or 0
			for _, item in ipairs(group.items) do
				if item.prefix and item.prefix ~= "" then
					for _, action in ipairs(model.prefixActions(item, claimed)) do
						if clashes(action) then
							n = n + 1
						end
					end
				elseif item.action and not claimed[item.action] then
					claimed[item.action] = true
					if clashes(item.action) then
						n = n + 1
					end
				end
			end
			counts[group.category] = n
		end
	end
	local other = counts[otherCategoryKey] or 0
	for action in pairs(model.working.byAction) do
		if not claimed[action] and clashes(action) then
			other = other + 1
		end
	end
	counts[otherCategoryKey] = other

	local total, counted = 0, {}
	for _, group in ipairs(model.resolvedCatalog) do
		if not group.hidden and model.sectionOf(group).inAll then
			counted[group.category] = true
			total = total + (counts[group.category] or 0)
		end
	end
	if not counted[otherCategoryKey] then
		total = total + (counts[otherCategoryKey] or 0)
	end
	for _, c in ipairs(model.categories) do
		local n
		if c.header or c.key == model.changedKey then
			n = nil
		elseif c.key == nil then
			n = total
		else
			n = counts[c.key] or 0
		end
		if (c.count or 0) ~= (n or 0) then
			c.count = n
			model.refit = true
		end
	end
end

-- Where each action is first bound. The keymap is written in bind order, so that is the order
-- the player drags rows into.
function model.bindPositions()
	local at = {}
	for i, b in ipairs(model.working.binds) do
		at[b.action] = at[b.action] or i
	end

	return at
end

-- An action left with no binds has no place in the file, so it trails, as it was.
function model.inBindOrder(actions, boundAt)
	local was = {}
	for i, action in ipairs(actions) do
		was[action] = i
	end
	table.sort(actions, function(a, b)
		local pa, pb = boundAt[a], boundAt[b]
		if pa and pb then
			return pa < pb
		elseif pa or pb then
			return pa ~= nil
		end

		return was[a] < was[b]
	end)

	return actions
end

-- Rebuilds the display list from the catalog and the staged binds, honouring both the
-- search box and the category column.
function model.rebuildRows()
	chipGroups = {}
	model.rowsGen = model.rowsGen + 1
	if not model.resolvedCatalog then
		buildResolvedCatalog()
	end
	-- The keyboard page searches by the same text, lighting the keys it finds.
	model.keyboard:setQuery(model.searchBox and model.searchBox:getText())

	model.rows = {}

	-- A grid category replaces the list outright: its keys only make sense laid out the
	-- way the grid menu itself draws them, so there are no rows to build.
	model.gridGroup = nil
	if model.selectedCategory then
		for _, group in ipairs(model.resolvedCatalog) do
			if group.category == model.selectedCategory and group.layout == "grid" then
				model.gridGroup = group
			end
		end
	end
	-- Rebuilt with the rows, which every edit rebuilds; ahead of the grid, whose entries count too.
	model.working.collisions = keybindModel.collisionIndex(model.working.binds, model.scanToKey)
	model.countClashes()

	if model.gridGroup then
		view.rowsChanged()

		return
	end
	local query = Search.query(model.searchBox and model.searchBox:getText())

	-- The column's Changed entry keeps only rows that differ from the base preset. How many
	-- there are is counted whatever is shown, since its label says so.
	local changedOnly = model.selectedCategory == model.changedKey
	local changedCount = 0
	-- A narrowed list hides rows whose binds a drop would move, so only the whole one can be dragged.
	local reorderable = query.empty and not changedOnly
	local boundAt = model.bindPositions()

	-- Whole keys only, as the chips print them: "f1" does not find F11, and a paired action
	-- hidden Shift half does not answer to "shift".
	local wantKeys = {}
	-- An Any+ binding fires whatever is held, so it answers a query naming modifiers even though
	-- its chip prints the bare key.
	local wantPlain, namedMods = {}, false
	for key in query.text:gmatch("[^%s%+]+") do
		wantKeys[#wantKeys + 1] = key
		if modifierKey[key] then
			namedMods = true
		else
			wantPlain[#wantPlain + 1] = key
		end
	end
	-- How the action answers the query: "exact" when a chip holds every key named, "any" when it
	-- only holds the keys and carries Any+ for the modifiers, false when neither.
	local function boundToQuery(action)
		if not (wantKeys[1] and action) then
			return false
		end
		local any = false
		local pair = model.catalogShiftPair[action]
		for _, k in ipairs(model.working.byAction[action] or {}) do
			-- The chip's text, which for a paired action is not the keyset's own. Kept on the keyset
			-- against the raw it came from, since this runs for every row on every keystroke.
			local shown = k.display
			if pair then
				if k.unshiftedFor ~= k.raw then
					k.unshifted, k.unshiftedFor = keybindModel.displayWithoutShift(k.raw, model.working.layout), k.raw
				end
				shown = k.unshifted
			end
			if keybindModel.holdsKeys(shown, wantKeys) then
				return "exact"
			end
			if namedMods and wantPlain[1] then
				local mods = keybindModel.splitElement(canonOf(k))
				if mods.any and keybindModel.holdsKeys(shown, wantPlain) then
					any = true
				end
			end
		end

		return any and "any" or false
	end
	-- Whether an action is listed by key: by the keys the search text names, within the
	-- category shown.
	local function keyHit(action, _, inCategory)
		return inCategory and boundToQuery(action)
	end
	-- Rows found by key are listed ahead of everything found by name, under a heading of their
	-- own, and only there. Gathered as they are met, so they keep the catalog's order.
	local keyRows = {}
	local catalogActions = {}
	local sectionRows = {}
	local otherGroupEnd

	-- Claim hidden actions up front so they never surface, as a row or under Other.
	-- Exact ids only (not prefixes), so a future action can't be hidden by coincidence.
	for _, group in ipairs(model.resolvedCatalog) do
		if group.hidden then
			for _, h in ipairs(group.hidden) do
				catalogActions[h] = true
			end
		end
	end

	for _, group in ipairs(model.resolvedCatalog) do
		-- Non-selected groups are still walked: they have to claim their actions or the
		-- leftovers below would sweep them all into Other.
		-- A search still reaches the sections All leaves out, so a clash with one can be found.
		local inCategory = group.category == model.selectedCategory
			or changedOnly
			or (not model.selectedCategory and (model.sectionOf(group).inAll or not query.empty))
		-- A group whose own title matches keeps every row under it, so searching for a
		-- category's name shows the category rather than emptying it.
		local categoryMatch = Search.claims(query, group.titleLower)
		local groupRows = {}
		local keyLink
		for _, item in ipairs(group.items) do
			-- An empty prefix would claim every bound action, so treat it as no prefix.
			if item.prefix and item.prefix ~= "" then
				local matched = model.prefixActions(item, catalogActions)
				if item.selection then
					model.inBindOrder(matched, boundAt)
				end
				for i = 1, #matched do
					local action = matched[i]
					local arg = action:sub(#item.prefix + 1)
					if item.unit then
						local def = UnitDefNames[arg]
						if def then
							arg = def.translatedHumanName or arg
						else
							-- Factions gated behind modoptions (Legion, scavengers) aren't in
							-- UnitDefNames, but their names live in the units i18n regardless.
							local key = "units.names." .. arg
							local name = BAR.I18N(key)
							if name ~= key then
								arg = name
							end
						end
					end
					local row, col = arg:match("^%s*(%S+)%s+(%S+)")
					local label = item.label and prefixRowLabel(item.label, arg, row, col) or action
					local command = item.selection and model.selectCommand.parse(action)
					if command then
						label = model.selectCommand.describe(command)
					end
					local buildable = command and model.selectCommand.editable(command)
					model.labels[action] = label
					model.sources[action] = group.title
					local change = rowChange(action)
					if change then
						changedCount = changedCount + 1
					end
					local byKey = keyHit(action, label, inCategory)
					if
						(change or not changedOnly)
						and (
							byKey
							or categoryMatch
							or Search.matches(query, action:lower())
							or Search.matches(query, label:lower())
						)
					then
						local entry = {
							type = "editable",
							action = action,
							label = label,
							editSelection = buildable or nil,
							custom = item.selection and not buildable or nil,
							reorder = reorderable and item.selection and boundAt[action] and item or nil,
							description = item.description,
							change = change,
							queryAny = byKey == "any",
						}
						if not byKey then
							groupRows[#groupRows + 1] = entry
						elseif group.layout == "grid" then
							keyLink = group
						else
							keyRows[#keyRows + 1] = entry
						end
					end
				end
			-- Skip an action a hidden entry or an earlier prefix already claimed, so a
			-- hide stays authoritative and entry order can't produce a duplicate row.
			elseif not (item.action and catalogActions[item.action]) then
				if item.action then
					catalogActions[item.action] = true
				end
				local change = rowChange(item.action)
				if change then
					changedCount = changedCount + 1
				end
				local byKey = keyHit(item.action, item.label, inCategory)
				if
					(change or not changedOnly)
					and (
						byKey
						or categoryMatch
						or Search.matches(query, item.labelLower)
						or Search.matches(query, item.actionLower)
					)
				then
					local entry = {
						type = "editable",
						action = item.action,
						label = item.label,
						cursor = item.icon,
						cursorColumn = group.hasCursors,
						description = item.description,
						change = change,
						queryAny = byKey == "any",
					}
					if not byKey then
						groupRows[#groupRows + 1] = entry
					elseif group.layout == "grid" then
						keyLink = group
					else
						keyRows[#keyRows + 1] = entry
					end
				end
			end
		end

		-- A grid category's keys only read laid out, so a key found among them points at that view.
		if keyLink then
			keyRows[#keyRows + 1] = { type = "link", label = group.title, category = group.category }
		end

		if inCategory and #groupRows > 0 then
			local section = model.sectionOf(group)
			local into = model.rows
			if not section.withOther then
				sectionRows[section] = sectionRows[section] or {}
				into = sectionRows[section]
			end
			into[#into + 1] = {
				type = "header",
				text = group.title,
				add = group.selection and not changedOnly and query.empty and L.addSelection or nil,
			}
			if group.layout == "grid" then
				-- Still driven by the rows a search matched, so hunting for one of them surfaces the way in.
				into[#into + 1] = { type = "link", label = L.edit, category = group.category }
			else
				for i = 1, #groupRows do
					into[#into + 1] = groupRows[i]
				end
			end
			if section.withOther and group.title == L.other then
				otherGroupEnd = #model.rows
			end
		end
	end

	local otherMatch = Search.claims(query, L.otherLower)
	local others, otherKeyed = {}, {}
	local inOther = not model.selectedCategory or changedOnly or model.selectedCategory == otherCategoryKey
	for action in pairs(model.working.byAction) do
		if not catalogActions[action] then
			local change = rowChange(action)
			if change then
				changedCount = changedCount + 1
			end
			if changedOnly and not change then
				-- Not what the column entry asked for.
			elseif keyHit(action, action, inOther) then
				otherKeyed[#otherKeyed + 1] = action
			elseif otherMatch or Search.matches(query, action:lower()) then
				others[#others + 1] = action
			end
		end
	end
	-- Leftovers found by key join the other key rows, in a steady order.
	table.sort(otherKeyed)
	for _, action in ipairs(otherKeyed) do
		keyRows[#keyRows + 1] = {
			type = "editable",
			action = action,
			label = action,
			custom = true,
			change = rowChange(action),
			queryAny = boundToQuery(action) == "any",
		}
	end

	if #others > 0 and inOther then
		table.sort(others)
		model.inBindOrder(others, boundAt)

		-- A catalog category can be titled the same as this generated one; when it is,
		-- the leftovers join it after its own items instead of repeating the header.
		local tail = {}
		if otherGroupEnd then
			for i = otherGroupEnd + 1, #model.rows do
				tail[#tail + 1] = model.rows[i]
				model.rows[i] = nil
			end
		else
			model.rows[#model.rows + 1] = { type = "header", text = L.other }
		end

		for _, action in ipairs(others) do
			model.rows[#model.rows + 1] = {
				type = "editable",
				action = action,
				label = action,
				custom = true,
				reorder = reorderable and boundAt[action] and L.other or nil,
				change = rowChange(action),
			}
		end
		for i = 1, #tail do
			model.rows[#model.rows + 1] = tail[i]
		end
	end

	for _, section in ipairs(sections) do
		for _, row in ipairs(sectionRows[section] or noRaws) do
			model.rows[#model.rows + 1] = row
		end
	end

	-- The key rows go on top, under a heading that names the keys the way a chip would. One
	-- cursor among them gives them all the column, as it does within a category.
	if #keyRows > 0 then
		-- Modifiers ahead of the key, as a chip prints them, whatever order they were typed in.
		local modifierAt = { ctrl = 1, alt = 2, meta = 3, shift = 4 }
		local keys, column = {}, false
		for i = 1, #wantKeys do
			keys[i] = { name = wantKeys[i]:upper(), at = (modifierAt[wantKeys[i]] or 5) * 100 + i }
		end
		table.sort(keys, function(a, b)
			return a.at < b.at
		end)
		for i = 1, #keys do
			keys[i] = keys[i].name
		end
		for i = 1, #keyRows do
			column = column or keyRows[i].cursor ~= nil
		end
		local ordered = {
			{
				type = "header",
				text = BAR.I18N("ui.keybinds.editor.boundTo", { keys = table.concat(keys, " + ") }),
			},
		}
		-- It does fire on the keys searched for, but its chip reads as the bare key, and beside the
		-- exact bindings that reads as a mistake.
		local anyRows = {}
		for i = 1, #keyRows do
			keyRows[i].cursorColumn = column
			keyRows[i].hitKeys = wantKeys
			if keyRows[i].queryAny then
				anyRows[#anyRows + 1] = keyRows[i]
			else
				ordered[#ordered + 1] = keyRows[i]
			end
		end
		if #anyRows > 0 then
			ordered[#ordered + 1] = { type = "header", text = L.boundToAny }
			for i = 1, #anyRows do
				ordered[#ordered + 1] = anyRows[i]
			end
		end
		for i = 1, #model.rows do
			ordered[#ordered + 1] = model.rows[i]
		end
		model.rows = ordered
	end

	-- Taking the entry away from under the selection sends the column back to everything, which
	-- is a different list from the one just built.
	if model.changedCount ~= changedCount then
		model.changedCount = changedCount
		model.syncChangedEntry()
		if changedOnly and model.selectedCategory ~= model.changedKey then
			return model.rebuildRows()
		end
	end

	-- The Changed section with nothing to list says why: no preset is being compared with,
	-- or nothing differs from the one that is.
	if changedOnly and #model.rows == 0 then
		if not model.base then
			model.rows[1] = { type = "note", text = L.compareNoneHint }
		else
			model.rows[1] = {
				type = "note",
				text = BAR.I18N("ui.keybinds.editor.changedNothing", { name = model.base.name }),
			}
		end
	end

	view.rowsChanged()
end

-- Selected: whatever the active preset is compared with now.
function model.compareOptions()
	local active = profiles.activeName()
	local options = { { label = L.compareNone or "None", none = true } }
	for _, b in ipairs(profiles.builtins) do
		if b.name ~= active then
			options[#options + 1] = { label = b.name, name = b.name, tag = L.defaultTag, group = "default" }
		end
	end
	-- The store lists its profiles by name.
	for _, name in ipairs(profiles.list()) do
		if name ~= active then
			options[#options + 1] = { label = name, name = name, group = "own" }
		end
	end
	local selected = 1
	local base = model.base and model.base.name
	for i, o in ipairs(options) do
		if o.name and o.name == base then
			selected = i
		end
	end

	return options, selected
end

function model.refreshCompare()
	local dd = model.compareDropdown
	if not dd then
		return
	end
	local options, selected = model.compareOptions()
	dd:setOptions(options)
	dd:setSelected(selected)
end

-- The player picked what to compare the active preset with. Recorded on the preset, so it
-- holds across sessions; "none" is a choice too, and stays one.
function model.pickBase(option)
	if not model.activeIsOwn() then
		return
	end
	profiles.setBase(profiles.activeName(), option and option.name or nil)
	model.refreshBase()
	model.rebuildRows()
end

----------------------------------------------------------------
-- Staging
----------------------------------------------------------------

-- Staged-edits flag, read by the picker marker and the footer buttons alike.
local function setDirty(value)
	model.dirty = value
end

-- Re-reading the engine replaces whatever was staged. Without this a language or layout
-- change leaves the flag armed over bindings it no longer describes.
local function seedWorkingFromEngine()
	local built = keybindModel.build()
	model.working = { byAction = {}, layout = built.layout, binds = built.binds }
	for _, entry in ipairs(built.actions) do
		local copy = {}
		for _, k in ipairs(entry.keysets) do
			copy[#copy + 1] = { raw = k.raw, display = k.display }
		end
		model.working.byAction[entry.action] = copy
	end

	setDirty(false)
	-- A fresh keymap has nothing to take back; what comes after is measured from here.
	model.undo = {}
	model.snapshot = model.snapshotOf()
end

-- Detached copy of the staged binds, for handing to the store.
local function stagedBinds()
	local out = {}
	for i, b in ipairs(model.working.binds) do
		out[i] = { keyset = b.keyset, action = b.action }
	end

	return out
end

-- Nothing in the editor rebinds the meta key, so a profile made from another one keeps
-- whatever that had; dropping it would silently change the new profile's modifiers.
local function activeFakeMeta()
	local name = profiles.activeName()
	local source = profiles.get(name) or profiles.isBuiltin(name)

	return source and source.fakeMeta or nil
end

-- Read from the binds rather than the name: the grid menu is inert without its gridmenu_*
-- keys, and the build menu is what buildunit_* hotkeys drive.
local function wantsGridMenu(name)
	local source = profiles.isBuiltin(name)
	if not source then
		return nil
	end

	local buildunit = false
	for _, b in ipairs(source.binds or {}) do
		local action = b.action:lower()
		if action:find("gridmenu_", 1, true) == 1 then
			return true
		elseif action:find("buildunit_", 1, true) == 1 then
			buildunit = true
		end
	end

	if buildunit then
		return false
	end

	return nil
end

-- Points the engine at a profile and brings the rest of the UI in line with it.
local function applyActiveProfile(name, fromName)
	Spring.SetConfigString("KeybindingFile", customKeysFile)
	if fromName and fromName ~= name then
		Spring.Echo("Keybind profile: " .. fromName .. " -> " .. name)
	end
	toggleMenu(wantsGridMenu(name))

	if WG["bar_hotkeys"] and WG["bar_hotkeys"].reloadBindings then
		WG["bar_hotkeys"].reloadBindings()
	else
		model.refresh()
	end
end

-- A preset with no known origin has nothing to have changed from, so the column entry comes
-- and goes with it.
function model.refreshBase()
	-- Which pairs of actions the game itself puts on one key, in any shipped preset. Built
	-- once, the shipped presets not changing.
	if not model.shippedPairs then
		local shipped = {}
		for _, b in ipairs(profiles.builtins) do
			local binds = b.binds or {}
			local index = keybindModel.collisionIndex(binds, model.scanToKey)
			for _, bind in ipairs(binds) do
				for _, other in ipairs(keybindModel.collidersOf(index, bind.action, bind.keyset)) do
					local a, o = bind.action, other.action
					shipped[(a < o) and (a .. "\n" .. o) or (o .. "\n" .. a)] = true
				end
			end
		end
		model.shippedPairs = shipped
	end

	local base = profiles.baseOf(profiles.activeName())
	local wanted = base and base.name or nil
	local _, manifestChanges = model.widgetActions.manifests()
	if (model.base and model.base.name) ~= wanted or (model.base and model.base.manifests ~= manifestChanges) then
		if base then
			local byAction = {}
			for _, b in ipairs(profiles.effectiveBinds(base)) do
				local entry = byAction[b.action]
				if not entry then
					entry = { set = {}, n = 0, raws = {} }
					byAction[b.action] = entry
				end
				local c = keybindModel.canonicalKeyset(b.keyset)
				if not entry.set[c] then
					entry.set[c] = true
					entry.n = entry.n + 1
					entry.raws[#entry.raws + 1] = b.keyset
				end
			end
			model.base = { name = wanted, byAction = byAction, manifests = manifestChanges }
		else
			model.base = nil
		end
		model.changedCount = -1
	end
	model.syncChangedEntry()
	model.refreshCompare()
end

-- A shipped preset is measured against itself, so it only has the entry while staged edits
-- differ from it: a "Changed (0)" on a default is noise.
function model.syncChangedEntry()
	local listed = model.categories[2] ~= nil and model.categories[2].key == model.changedKey
	if model.activeIsOwn() or (model.base and model.changedCount > 0) then
		local label = L.changedUnknown or "?"
		if model.base then
			label = BAR.I18N("ui.keybinds.editor.changedCount", { n = math.max(0, model.changedCount) })
		end
		if not listed then
			table.insert(model.categories, 2, { label = label, key = model.changedKey })
			model.refit = true
		elseif model.categories[2].label ~= label then
			model.categories[2].label = label
			model.refit = true
		end
	elseif listed then
		table.remove(model.categories, 2)
		if model.selectedCategory == model.changedKey then
			model.selectedCategory = nil
		end
		model.refit = true
	end
end

function model.refreshPicker()
	buildPresetOptions()
	model.presetDropdown:setOptions(model.presetOptions)
	model.presetDropdown:setSelected(currentPresetIndex())
	model.refreshBase()
	-- Settles the Save button wording, and so its width, and what the header tooltips say.
	model.presetsGen = model.presetsGen + 1
end

-- Files the keymap as it stood before the edit just made, then takes the one it stands at
-- now, for the edit after.
function model.pushUndo()
	model.undo[#model.undo + 1] = model.snapshot
	model.snapshot = model.snapshotOf()
end

-- Staging changes the picker too: the active profile picks up the unsaved marker. A gesture
-- that stages several edits files one snapshot for the lot, once it is done.
local function markStaged()
	if model.batching then
		model.batchEdited = true
	else
		model.pushUndo()
	end
	setDirty(true)
	model.refreshPicker()
	model.rebuildRows()
end

-- Ctrl+Z: the last edit taken back. With none left the keymap is what was loaded, so there
-- is nothing unsaved either. Answers whether there was anything to take back.
function model.undoEdit()
	local snap = table.remove(model.undo)
	if not snap then
		return false
	end

	model.working.binds, model.working.byAction = snap.binds, snap.byAction
	-- Copied again: the restored tables are live now, and the next edit rewrites them.
	model.snapshot = model.snapshotOf()
	setDirty(#model.undo > 0)
	model.refreshPicker()
	model.rebuildRows()

	return true
end

-- Staged edits live only in `working`, so throwing them away means re-reading the engine.
-- Clearing the flag on its own would leave the edits on screen and still saveable.
local function discardStaged()
	seedWorkingFromEngine()
	model.refreshPicker()
	model.rebuildRows()
end

-- Order counts: two actions on one keyset are tried in bind order.
function model.isStaged(binds)
	if #binds ~= #model.working.binds then
		return false
	end

	for i, b in ipairs(binds) do
		local w = model.working.binds[i]
		if b.keyset ~= w.keyset or b.action ~= w.action then
			return false
		end
	end

	return true
end

-- The list arrives in engine order already, so it replaces the staged one outright.
function model.stageBinds(binds)
	-- Emptied entries stay: the rows the catalog does not name come from them.
	local byAction = {}
	for action in pairs(model.working.byAction) do
		byAction[action] = {}
	end
	for _, b in ipairs(binds) do
		local ks = byAction[b.action] or {}
		byAction[b.action] = ks
		ks[#ks + 1] = { raw = b.keyset, display = keybindModel.displayKeyset(b.keyset, model.working.layout) }
	end

	model.working.binds, model.working.byAction = binds, byAction
	markStaged()
end

----------------------------------------------------------------
-- Dialogs
----------------------------------------------------------------

-- Raises a modal, taking focus off the search box.
local function openDialog(d)
	-- Replacing a live modal outright drops the rollback its cancel was holding, which is how the
	-- picker ends up naming a profile that was never switched to.
	local previous = model.dialog
	model.dialog = nil
	if previous and previous.cancel then
		previous.cancel()
	end

	-- A modal draws over the capture and takes its keys, so leaving one running behind would
	-- drop the player back into it on cancel, seeded from bindings the modal may have changed.
	model.capturing = nil

	model.dialog = d
	model.searchBox:blur()
	if not d.message then
		model.nameBox:setMaxChars(d.maxChars)
		model.nameBox:setText(d.initial or "")
		model.nameBox:focus()
	end
end

-- Drops the modal, handing it back so the caller can act on it.
local function closeDialog()
	local d = model.dialog
	model.dialog = nil
	model.nameBox:blur()

	return d
end

function model.cancelDialog()
	local d = closeDialog()
	if d and d.cancel then
		d.cancel()
	end
end

-- The optional third button: "Discard" when leaving unsaved edits, "Delete" when
-- editing a profile.
function model.middleDialog()
	local d = closeDialog()
	if d and d.middle then
		d.middle.action()
	end
end

-- A name already in use would be renumbered on the way into the store, handing back a
-- profile nobody asked for.
function model.dialogName()
	if not model.dialog or model.dialog.message then
		return "", false
	end
	if model.dialog.nameless then
		return "", model.dialog.blocked == true
	end

	local name = model.nameBox:getText():gsub("^%s+", ""):gsub("%s+$", "")
	-- Only a profile name has to be one of a kind. A dialog asking for anything else - a bind
	-- command - is free to repeat whatever a profile happens to be called.
	local taken = not model.dialog.freeText
		and name ~= model.dialog.allow
		and (profiles.get(name) ~= nil or profiles.isBuiltin(name) ~= nil)

	-- A dialog can be blocked outright, like an import with nothing to import.
	return name, name == "" or taken or model.dialog.blocked == true
end

-- Confirmation path; only a dialog with a name field has text to read.
function model.acceptDialog()
	local name, blocked = model.dialogName()
	if blocked then
		return
	end

	local d = closeDialog()
	if not d then
		return
	end

	d.accept(name)
end

----------------------------------------------------------------
-- Profile commands
----------------------------------------------------------------

-- A keymap that never reached disk must not clear the staged flag: the reload below would
-- load whatever file is still there and the edits would revert. offPanel marks a caller the
-- player is not looking at, where a modal would surface attributed to something else.
local function selectProfile(name, fromName, offPanel)
	if not profiles.materialize(name) then
		if offPanel then
			Spring.Echo("Keybind profile: could not apply " .. name)
		else
			openDialog({
				title = L.applyFailedTitle,
				message = BAR.I18N("ui.keybinds.editor.applyFailedMessage", { name = name }),
				accept = function() end,
			})
		end

		return false
	end

	profiles.setActive(name)
	setDirty(false)
	-- What was staged is now the preset's own, or gone with the switch: nothing to take back.
	model.undo = {}
	model.snapshot = model.snapshotOf()
	model.refreshPicker()
	applyActiveProfile(name, fromName)

	return true
end

-- Answers whether it landed, so a caller that closes the panel does not do so over a failed
-- save.
local function applyStaged(name, fromName)
	local profile = profiles.get(name)
	if not profile then
		return selectProfile(name, fromName)
	end

	-- The store has to hold the new binds before materialize can write them, so a failed apply is
	-- undone rather than avoided.
	local previous = profile.binds
	profile.binds = stagedBinds()
	profiles.save()

	if selectProfile(name, fromName) then
		return true
	end

	profile.binds = previous
	profiles.save()

	return false
end

-- Saving over a shipped profile is a fork: it asks for a name and writes a new one.
function model.startSave(andThen, onCancel)
	local name = profiles.activeName()
	if profiles.get(name) then
		if applyStaged(name) and andThen then
			andThen()
		end

		return
	end

	openDialog({
		title = L.saveTitle,
		initial = profiles.uniqueName(L.newProfile),
		accept = function(newName)
			-- Forked from the default on screen, which the new preset records as its origin.
			local created = profiles.create(newName, stagedBinds(), activeFakeMeta(), name)
			if applyStaged(created, name) and andThen then
				andThen()
			end
		end,
		cancel = onCancel,
	})
end

-- Staged edits are not in the engine yet, so anything that would replace them asks
-- first. Returns whether it could go ahead immediately.
function model.guardDirty(proceed, onCancel)
	if not model.dirty then
		proceed()

		return true
	end

	openDialog({
		title = L.unsavedTitle,
		message = L.unsavedMessage,
		-- Worded like the footer's Save, which this stands in for.
		acceptLabel = model.activeIsOwn() and L.save or L.saveAsNew,
		save = true,
		accept = function()
			model.startSave(proceed, onCancel)
		end,
		middle = {
			label = L.discard,
			danger = true,
			action = function()
				discardStaged()
				proceed()
			end,
		},
		cancel = onCancel,
	})

	return false
end

model.switchToPreset = function(opt)
	-- Already what is on screen, staged edits and all, so picking it again is not a switch:
	-- it would only ask about edits the player has not tried to leave.
	if opt.name == profiles.activeName() then
		return
	end

	model.guardDirty(function()
		-- The picker committed the new name before the guard ran, so a switch that does not
		-- happen has to put the selection back.
		if not selectProfile(opt.name, profiles.activeName()) then
			model.refreshPicker()
		end
	end, model.refreshPicker)
end

-- Throws staged edits away, back to the active profile as last saved.
function model.startReset()
	openDialog({
		title = L.reset,
		message = L.resetConfirm,
		-- Named for what it does. Without this it falls back to the generic "Accept", which
		-- says nothing about the edits being thrown away, and coloured for it.
		acceptLabel = L.discard,
		danger = true,
		accept = function()
			discardStaged()
		end,
	})
end

function model.startDuplicate()
	local from = profiles.activeName()
	openDialog({
		title = L.duplicateTitle,
		initial = profiles.uniqueName(from),
		accept = function(name)
			-- Copies what is on screen rather than what was last saved, so pending edits come along.
			local base = profiles.baseOf(from)
			applyStaged(profiles.create(name, stagedBinds(), activeFakeMeta(), base and base.name), from)
		end,
	})
end

-- Export copies the preset on screen, staged edits included, to the clipboard as the text the
-- engine loads; Import reads such text back, as a new preset of the player's own or as edits to
-- the one on screen.
function model.startClipboard(exporting)
	if exporting then
		local name = profiles.activeName()
		Spring.SetClipboard(profiles.exportText({ name = name, binds = stagedBinds(), fakeMeta = activeFakeMeta() }))
		openDialog({
			title = L.export,
			message = BAR.I18N("ui.keybinds.editor.exportDone", { name = name }),
			info = true,
			acceptLabel = L.ok,
			accept = function() end,
		})

		return
	end

	local clip = Spring.GetClipboard()
	if type(clip) ~= "string" or clip:match("^%s*$") then
		openDialog({
			title = L.import,
			message = L.importEmpty,
			info = true,
			acceptLabel = L.ok,
			accept = function() end,
		})

		return
	end

	-- With nothing readable the dialog still opens, so the player can see why, but cannot be
	-- accepted. An unbind alone still edits a preset; a new one needs a bind.
	local lines, count, errors, directives = profiles.classifyBindFile(clip)
	local binds, fakeMeta, stamped = profiles.parseBindFile(clip)
	local from = profiles.activeName()
	-- A default takes no edits, so loose lines can only go on a copy of it.
	local whole = profiles.isWholeProfile(clip)
	local own = model.activeIsOwn()
	local d = {
		title = L.importTitle,
		initial = profiles.uniqueName(stamped or L.newProfile),
		preview = { lines = lines, scroll = 0, summary = "" },
		choice = { label = L.importAsNew, on = whole or not own, locked = not own },
		hint = BAR.I18N("ui.keybinds.editor.importAddHint", { name = from }),
		nameless = false,
		blocked = false,
		acceptLabel = L.import,
	}

	local function summarize(readable)
		local summary = readable and (colorText .. BAR.I18N("ui.keybinds.editor.importSummary", { n = count }))
			or (colorDanger .. L.importNone)
		if errors > 0 then
			summary = summary
				.. colorDim
				.. ", "
				.. colorHeader
				.. BAR.I18N("ui.keybinds.editor.importErrors", { n = errors })
		end

		return summary
	end

	function d.choice.set(on)
		local readable = count + directives > 0
		if on and whole then
			readable = binds ~= nil
		end

		d.choice.on = on
		d.nameless = not on
		d.blocked = not readable
		d.acceptLabel = on and L.import or L.importAdd
		d.preview.summary = summarize(readable)
		if on then
			model.nameBox:focus()
		else
			model.nameBox:blur()
		end
	end

	function d.accept(newName)
		if d.choice.on and whole then
			-- Named like a copy is, then made live: importing is switching to it.
			model.guardDirty(function()
				selectProfile(profiles.create(newName, binds, fakeMeta), from)
			end)

			return
		end

		local merged = profiles.applyBindText(stagedBinds(), clip)
		if model.isStaged(merged) then
			openDialog({
				title = L.importTitle,
				message = BAR.I18N("ui.keybinds.editor.importNothing", { name = from }),
				info = true,
				acceptLabel = L.ok,
				accept = function() end,
			})

			return
		end

		if d.choice.on then
			-- Staged edits come along in the copy, so there is nothing to ask about.
			local base = profiles.baseOf(from)
			selectProfile(profiles.create(newName, merged, activeFakeMeta(), base and base.name), from)
		else
			model.stageBinds(merged)
		end
	end

	openDialog(d)
	d.choice.set(d.choice.on)
end

-- Renaming and deleting share one dialog: the name field commits a rename, the
-- middle button deletes. Deleting asks again, since it cannot be undone.
function model.startEdit()
	local name = profiles.activeName()

	-- The staged keymap and everything undo can put back move with the rename too, or a save
	-- writes back a key switching to a profile no longer there.
	local function retargetSwitch(set, from, to)
		local keysets = set and set.byAction[from]
		if not keysets then
			return
		end

		for _, bind in ipairs(set.binds) do
			if bind.action == from then
				bind.action = to
			end
		end
		set.byAction[from] = nil
		set.byAction[to] = keysets
	end

	openDialog({
		title = L.editTitle,
		initial = name,
		allow = name,
		accept = function(newName)
			-- The store renumbers a name already taken, so follow what it settled on.
			local from = profiles.switchAction(name)
			local settled = profiles.rename(name, newName)
			local to = profiles.switchAction(settled)
			retargetSwitch(model.working, from, to)
			retargetSwitch(model.snapshot, from, to)
			for _, snap in ipairs(model.undo) do
				retargetSwitch(snap, from, to)
			end

			-- The rename moved the store copy, so the file has to be written again or the next launch
			-- adopts the keymap as a separate profile. With edits pending only the file is written,
			-- since reloading is the part staged edits cannot take.
			if model.dirty then
				profiles.materialize(settled)
				model.refreshPicker()
				model.rebuildRows()
			else
				selectProfile(settled, nil)
			end
		end,
		middle = {
			label = L.delete,
			danger = true,
			action = function()
				openDialog({
					title = L.delete,
					message = BAR.I18N("ui.keybinds.editor.deleteConfirm", { name = name }),
					acceptLabel = L.delete,
					danger = true,
					accept = function()
						-- Re-seeded rather than just unflagged: clearing the flag alone would
						-- leave the deleted profile's edits on screen with Save greyed out.
						discardStaged()
						profiles.delete(name)

						-- Selected rather than committed: the staged keymap belongs to the profile just deleted.
						selectProfile(profiles.activeName(), name)
					end,
				})
			end,
		},
	})
end

-- Accept wording, needed by the geometry as well as the drawing.
function model.acceptLabelFor(d)
	return d.acceptLabel or (d.message and L.accept or L.save)
end

function model.dropVanishedCategory()
	if model.selectedCategory == nil or model.selectedCategory == model.changedKey then
		return
	end

	for _, c in ipairs(model.categories) do
		if c.key == model.selectedCategory then
			return
		end
	end

	model.selectedCategory = nil
	view.scrollToTop()
end

-- The staged keymap is the player's edits, so only the catalog is rebuilt.
function model.reloadCatalog()
	buildResolvedCatalog()
	model.refit = true
	model.dropVanishedCategory()
	model.rebuildRows()
end

-- Answers whether the profile was there, so a key naming one since deleted falls through to
-- whatever else is on it rather than being swallowed.
function model.applyProfile(name)
	if not name or not (profiles.get(name) or profiles.isBuiltin(name)) then
		return false
	end

	local from = profiles.activeName()
	if name == from then
		return true
	end

	-- Can arrive from the console or another widget while the panel is open, so it declines
	-- rather than discarding edits the player never answered for.
	if model.dirty then
		Spring.Echo("Keybind profile: save or discard your keybind changes before switching to " .. name)

		return false
	end

	return selectProfile(name, from, true)
end

----------------------------------------------------------------
-- Editing keysets
----------------------------------------------------------------

-- Compared canonically rather than by the printed label: the label drops Any+ and resolves
-- scancodes through the layout, so two bindings the engine separates would read as one.
local function actionHasKeyset(action, newKeyset, exceptRaw)
	local ks = model.working.byAction[action]
	if not ks then
		return false
	end
	local c = keybindModel.canonicalKeyset(newKeyset)
	for _, k in ipairs(ks) do
		if k.raw ~= exceptRaw and keybindModel.canonicalKeyset(k.raw) == c then
			return true
		end
	end
	return false
end

-- The bind list is kept in engine order because two actions on one keyset are tried
-- in bind order; edits touch it in place rather than rebuilding it.
local function stageAdd(action, raw)
	model.working.binds[#model.working.binds + 1] = { keyset = raw, action = action }

	local ks = model.working.byAction[action]
	if not ks then
		ks = {}
		model.working.byAction[action] = ks
	end
	ks[#ks + 1] = { raw = raw, display = keybindModel.displayKeyset(raw, model.working.layout) }
end

local function stageRemove(action, raw)
	for i = #model.working.binds, 1, -1 do
		local b = model.working.binds[i]
		if b.action == action and b.keyset == raw then
			table.remove(model.working.binds, i)
			break
		end
	end

	local ks = model.working.byAction[action] or {}
	for i = #ks, 1, -1 do
		if ks[i].raw == raw then
			table.remove(ks, i)
			break
		end
	end
	-- Rows the catalog does not name are derived from this table, so dropping the entry takes the
	-- row with it and leaves nothing to click to bind the action again.
end

-- Rewrite a binding where it sits. Two actions on one keyset are tried in bind order,
-- so re-adding at the end would hand the other one priority.
local function stageReplace(action, oldRaw, newRaw)
	local entry
	for _, b in ipairs(model.working.binds) do
		if b.action == action and b.keyset == oldRaw then
			entry = b
			break
		end
	end

	if not entry then
		return false
	end

	entry.keyset = newRaw

	for _, k in ipairs(model.working.byAction[action] or {}) do
		if k.raw == oldRaw then
			k.raw = newRaw
			k.display = keybindModel.displayKeyset(newRaw, model.working.layout)
			break
		end
	end

	return true
end

-- The grid menu answers its category keys whether or not Shift is held, which the engine can
-- only express as two binds. Built from the captured elements so Shift lands after any other
-- modifiers, and qualifies the first tap only.
function model.shiftPairRaws(elems)
	local bare, shifted = {}, {}
	for i = 1, #elems do
		local e = elems[i]
		bare[i] = e.mods .. e.sym
		shifted[i] = (i == 1) and (e.mods .. "Shift+" .. e.sym) or bare[i]
	end

	return { table.concat(bare, ","), table.concat(shifted, ",") }
end

-- Rewrite every keyset an action carries, reusing the slots it already holds so the
-- rewrite does not disturb bind order. Answers whether anything actually changed.
local function stageSetKeysets(action, raws)
	local ks = model.working.byAction[action] or {}
	local existing = {}
	for i = 1, #ks do
		existing[i] = ks[i].raw
	end

	-- Compared as a set: which keyset sits in which slot carries no meaning, and a positional
	-- check would call a reordered pair a change.
	if #existing == #raws then
		local wanted = {}
		for i = 1, #raws do
			wanted[raws[i]] = (wanted[raws[i]] or 0) + 1
		end
		for i = 1, #existing do
			wanted[existing[i]] = (wanted[existing[i]] or 0) - 1
		end

		local same = true
		for _, count in pairs(wanted) do
			if count ~= 0 then
				same = false
				break
			end
		end

		if same then
			return false
		end
	end

	local shared = (#existing < #raws) and #existing or #raws
	for i = 1, shared do
		stageReplace(action, existing[i], raws[i])
	end
	for i = shared + 1, #existing do
		stageRemove(action, existing[i])
	end
	for i = shared + 1, #raws do
		stageAdd(action, raws[i])
	end

	return true
end

-- Edit entry point: move a binding, and mark the profile staged.
local function rebindKeyset(action, oldRaw, newKeyset)
	-- Accepting the capture unchanged is not an edit. Staging it would arm Save, mark the
	-- preset unsaved, and raise the unsaved-changes guard over nothing.
	if newKeyset == oldRaw then
		return
	end

	if actionHasKeyset(action, newKeyset, oldRaw) then
		stageRemove(action, oldRaw)
	elseif not stageReplace(action, oldRaw, newKeyset) then
		stageRemove(action, oldRaw)
		stageAdd(action, newKeyset)
	end

	markStaged()
end

-- Edit entry point: extra binding for an action, and mark the profile staged.
local function addKeyset(action, newKeyset)
	if actionHasKeyset(action, newKeyset) then
		return
	end

	stageAdd(action, newKeyset)
	markStaged()
end

-- Edit entry point: drop a binding, and mark the profile staged.
local function removeKeyset(action, raw)
	-- A chip hands over every raw it stands for, so a paired action loses its pair and nothing
	-- else; clearing the action outright would take any other key it carries.
	stageRemove(action, raw)
	markStaged()
end

-- Puts the base preset's keys back on an action: what clicking the ghost chip does.
function model.revert(action)
	local change = rowChange(action)
	if not change then
		return
	end

	local raws = {}
	for i = 1, #change do
		raws[i] = change[i]
	end
	if stageSetKeysets(action, raws) then
		markStaged()
	end
end

-- One key can drive several actions (e.g. backspace = mutesound + edit_backspace),
-- so add the binding without disturbing others on the same keyset.
function model.commitCapture(keyset)
	---@type table
	local c = model.capturing

	-- Left open rather than closed on a key the action already carries. Closing with nothing
	-- changed is indistinguishable from the editor having dropped the press.
	if not c.oldRaw and not model.catalogShiftPair[c.action] and actionHasKeyset(c.action, keyset) then
		return
	end

	model.capturing = nil

	-- One gesture, however many edits it comes to below, files one snapshot to take back.
	model.batching, model.batchEdited = true, false
	if model.catalogShiftPair[c.action] then
		if stageSetKeysets(c.action, model.shiftPairRaws(c.elems)) then
			markStaged()
		end
	elseif c.oldRaw then
		rebindKeyset(c.action, c.oldRaw, keyset)
		-- Skip the one the rebind already landed on, or this undoes it and leaves it bound to none.
		if keyset ~= c.oldRaw then
			for i = 2, #(c.oldRaws or {}) do
				if c.oldRaws[i] ~= keyset then
					removeKeyset(c.action, c.oldRaws[i])
				end
			end
		end
	else
		addKeyset(c.action, keyset)
	end
	model.batching = false
	if model.batchEdited then
		model.pushUndo()
	end
end

----------------------------------------------------------------
-- Modifiers and key capture
----------------------------------------------------------------

local function rawHasAny(raw)
	return raw ~= nil and raw:find("[Aa][Nn][Yy]%+") ~= nil
end

-- Inferred: the catalog alwaysModifier flag first, then whatever it is bound with today. The
-- engine stateful commands carry the flag in the catalog so every surface reads one place.
local function actionUsesAny(action, oldRaw)
	if catalogAny[action] then
		return true
	end

	for _, prefix in ipairs(catalogAnyPrefixes) do
		if action:sub(1, #prefix) == prefix then
			return true
		end
	end

	-- Another keyset of the same action carrying Any+ says nothing about this one, and inheriting
	-- it would silently drop the modifiers the player just pressed.
	if oldRaw then
		return rawHasAny(oldRaw)
	end

	-- Actions the catalog does not list still reach the editor under Other, so fall back
	-- to what they are bound with today.
	for _, k in ipairs(model.working.byAction[action] or {}) do
		if rawHasAny(k.raw) then
			return true
		end
	end

	return false
end

-- Derived from the one canonical list so a modifier added there is understood here too.
-- modPrefix below emits in the same order, reading the state Spring returns positionally.
local modNames = {}
for i, name in ipairs(keyConfig.modifierOrder) do
	modNames[i] = name .. "+"
end

-- Strip modifiers by name so a "+"-key (e.g. numpad+) survives; the Any+ qualifier is
-- carried on the capture rather than in the element.
local function parseElem(raw)
	raw = raw:gsub("[Aa][Nn][Yy]%+", "")
	local mods = ""
	local stripped = true
	while stripped do
		stripped = false
		for _, m in ipairs(modNames) do
			if raw:sub(1, #m):lower() == m:lower() then
				mods = mods .. raw:sub(1, #m)
				raw = raw:sub(#m + 1)
				stripped = true
			end
		end
	end

	return { sym = raw, mods = mods }
end

function model.startCapture(action, label, oldRaws)
	-- The grid page rebinds one keyset by name; a row chip hands over every binding it
	-- stands for, the first of which is the one being edited.
	if type(oldRaws) == "string" then
		oldRaws = { oldRaws }
	end
	local oldRaw = oldRaws and oldRaws[1] or nil

	-- Rebinding seeds the modal with the current binding; the first press clears it.
	local pair = model.catalogShiftPair[action]
	local elems = {}
	if oldRaw then
		for _, part in ipairs(keybindModel.splitChain(oldRaw)) do
			local elem = parseElem(part)
			if pair then
				elem.mods = (elem.mods:gsub("[Ss][Hh][Ii][Ff][Tt]%+", ""))
			end
			elems[#elems + 1] = elem
		end
	end

	local fakeMeta = activeFakeMeta()

	model.capturing = {
		action = action,
		label = label,
		oldRaw = oldRaw,
		oldRaws = oldRaws,
		pair = pair,
		elems = elems,
		-- Showing the existing binding rather than anything the player has pressed.
		seeded = #elems > 0,
		pressed = {},
		lastPress = nil,
		-- Matches the engine's KeyChainTimeout default; BAR ships a tighter 333ms.
		timeout = 750,
		any = actionUsesAny(action, oldRaw),
		fakeMetaCode = fakeMeta and Spring.GetKeyCode(fakeMeta) or nil,
	}
end

function model.modPrefix()
	-- An action that ignores modifiers can only ever produce Any+<key>, never a
	-- contradictory Any+Shift+<key>, so held modifiers are dropped outright.
	if model.capturing and model.capturing.any then
		return ""
	end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local prefix = ""
	if alt then
		prefix = prefix .. "Alt+"
	end
	if ctrl then
		prefix = prefix .. "Ctrl+"
	end
	if meta then
		prefix = prefix .. "Meta+"
	end
	-- A paired action answers held or not held, so Shift is not a modifier the player picks
	-- for it: holding it must read as the bare key and get its partner written behind.
	if shift and not (model.capturing and model.capturing.pair) then
		prefix = prefix .. "Shift+"
	end

	return prefix
end

-- A press within the timeout extends the sequence; a slower one starts over.
function model.appendChain(el)
	local c = model.capturing
	if not c then
		return
	end

	-- The first real press replaces what the modal opened showing.
	if c.seeded then
		c.seeded = false
		c.elems = {}
	end

	local now = spGetTimer()
	local last = c.elems[#c.elems]
	if #c.elems == 0 then
		c.elems[1] = el
	elseif c.lastPress and spDiffTimers(now, c.lastPress) * 1000 <= c.timeout then
		-- Mirrors the engine's key chain, which folds a modifier into a key pressed while it is held.
		if last.modifier and last.scan ~= el.scan and c.pressed[last.scan] then
			c.elems[#c.elems] = el
		else
			c.elems[#c.elems + 1] = el
		end
	else
		c.elems = { el }
	end

	c.lastPress = now
end

-- Accept is shown and acts only on this, so a button not on screen cannot be clicked. Seeded
-- means nothing has been pressed yet: accepting would rewrite a keyset to itself.
function model.captureCanAccept()
	local c = model.capturing

	return c ~= nil and #c.elems > 0 and not c.seeded
end

-- The engine binds a lone modifier as Any+, but the stand-in Meta key keeps the Meta+ it adds.
local function pressElem(key, scanCode)
	local sym = scanCode and Spring.GetScanSymbol(scanCode)
	if not sym or sym == "" then
		return nil
	end

	local modifier = keybindModel.isBareModifier(sym)
	-- A modifier alone reads the same with Shift held or not, so it cannot pair.
	if modifier and model.capturing and model.capturing.pair then
		return nil
	end

	return {
		sym = sym,
		mods = modifier and "" or model.modPrefix(),
		modifier = modifier or (model.capturing ~= nil and key == model.capturing.fakeMetaCode),
		scan = scanCode,
	}
end

-- Any+ replaces the held modifiers, so toggling the checkbox re-derives each element.
function model.elemRaw(e)
	return ((model.capturing and model.capturing.any) and "Any+" or e.mods) .. e.sym
end

-- The captured sequence as one engine keyset string.
function model.chainRaw()
	local parts = {}
	for i = 1, #model.capturing.elems do
		parts[i] = model.elemRaw(model.capturing.elems[i])
	end

	return table.concat(parts, ",")
end

-- Any+ is never shown, so an action carrying both a plain and an Any+ binding of one key
-- reads as that key twice; the chip stands for every binding behind it.
function model.rowChipGroups(action)
	local cached = chipGroups[action]
	if cached then
		return cached
	end

	-- Grouping on the Shift-stripped form is what puts the halves together; the chip carries both
	-- raws, so removing it takes the pair and rebinding moves the pair.
	local pair = model.catalogShiftPair[action]
	local groups, byDisplay = {}, {}
	for _, k in ipairs(model.working.byAction[action] or {}) do
		local shown = pair and keybindModel.displayWithoutShift(k.raw, model.working.layout) or k.display

		local group = byDisplay[shown]
		if not group then
			group = { display = shown, raws = {} }
			byDisplay[shown] = group
			groups[#groups + 1] = group
		end
		group.raws[#group.raws + 1] = k.raw
	end

	chipGroups[action] = groups

	return groups
end

-- The grid menu is 3x4 with row 1 along the bottom, matching the keyboard rows it is
-- bound to (ZXCV under ASDF under QWER) and the order gui_gridmenu draws them in.
local gridRows, gridCols = 3, 4

-- The ids never change, so they are built once rather than concatenated per cell per frame.
local gridKeyActions, gridCategoryActions = {}, {}
model.gridRows, model.gridCols = gridRows, gridCols
model.gridKeyActions, model.gridCategoryActions = gridKeyActions, gridCategoryActions
for row = 1, gridRows do
	gridKeyActions[row] = {}
	for col = 1, gridCols do
		gridKeyActions[row][col] = "gridmenu_key " .. row .. " " .. col
	end
end
for c = 1, gridCols do
	gridCategoryActions[c] = "gridmenu_category " .. c
end

-- The raw keyset a grid action carries, for seeding a rebind. nil when it has none.
function model.gridKeyRaw(action)
	local ks = model.working.byAction[action]

	return ks and ks[1] and ks[1].raw or nil
end

-- The key a grid action currently carries, blank when it has none.
function model.gridKeyText(action)
	local ks = model.working.byAction[action]

	return ks and ks[1] and ks[1].display or ""
end

-- An action under a prefix family takes the family card with the label the list gave its row;
-- one the catalog never lists is its own id under Other.
function model.keyInfoFor(action)
	local info = model.keyInfo
	if not info then
		info = { byAction = {}, prefixes = {} }
		model.keyInfo = info
		for gi, g in ipairs(model.resolvedCatalog or {}) do
			if not g.hidden then
				for ii, item in ipairs(g.items) do
					local rank = gi * 1000 + ii
					if item.prefix then
						info.prefixes[#info.prefixes + 1] = {
							prefix = item.prefix,
							description = item.description,
							icon = item.icon,
							category = g.category,
							rank = rank,
						}
					elseif item.action then
						info.byAction[item.action] = {
							label = item.label,
							description = item.description,
							icon = item.icon,
							category = g.category,
							rank = rank,
						}
					end
				end
			end
		end
	end

	local card = info.byAction[action]
	if card then
		return card
	end
	local best
	for _, p in ipairs(info.prefixes) do
		if p.prefix ~= "" and action:sub(1, #p.prefix) == p.prefix and (not best or #p.prefix > #best.prefix) then
			best = p
		end
	end
	card = {
		label = model.labels[action] or action,
		description = best and best.description,
		icon = best and best.icon,
		category = (best and best.category) or "categories.other",
		rank = (best and best.rank) or math.huge,
	}
	info.byAction[action] = card

	return card
end

-- Places the staged keymap on the keyboard, once per change to it.
function model.ensureKeyboard()
	if model.keyboardGen ~= model.rowsGen then
		model.keyboardGen = model.rowsGen
		model.keyboard:place(
			model.working.binds,
			model.hidden,
			model.working.layout,
			model.catalogShiftPair,
			model.keyInfoFor
		)
	end
end

-- Staged once the row is let go. The block's binds trade places among the slots they already
-- hold, so every other bind keeps its place in the file.
function model.stageRowOrder(reorder)
	local rank, n = {}, 0
	for _, row in ipairs(model.rows) do
		if row.reorder == reorder then
			n = n + 1
			rank[row.action] = n
		end
	end

	local slots, moved = {}, {}
	for i, b in ipairs(model.working.binds) do
		if rank[b.action] then
			slots[#slots + 1] = i
			moved[#moved + 1] = { bind = b, at = i }
		end
	end
	table.sort(moved, function(a, b)
		if rank[a.bind.action] ~= rank[b.bind.action] then
			return rank[a.bind.action] < rank[b.bind.action]
		end

		return a.at < b.at
	end)
	local changed = false
	for i, slot in ipairs(slots) do
		changed = changed or model.working.binds[slot] ~= moved[i].bind
		model.working.binds[slot] = moved[i].bind
	end
	if changed then
		markStaged()
	else
		model.rebuildRows()
	end
end

function model.renameAction(from, to)
	model.working.binds = keybindModel.renameAction(model.working.binds, from, to)

	local keys = {}
	for _, b in ipairs(model.working.binds) do
		if b.action == to then
			keys[#keys + 1] = { raw = b.keyset, display = keybindModel.displayKeyset(b.keyset, model.working.layout) }
		end
	end
	model.working.byAction[from] = nil
	model.working.byAction[to] = keys

	markStaged()
end

-- Only the command is asked for; the key comes from the same capture every row uses, and the
-- action lands under Other, where the list puts whatever it does not recognise. Given one of
-- those, it edits that command instead.
function model.addBind(editing)
	openDialog({
		title = editing and L.editBindTitle or L.addBindTitle,
		initial = editing,
		freeText = true,
		wide = true,
		maxChars = 255,
		accept = function(typed)
			if typed:match("^/?bind%s+%S+%s+%S") then
				local merged = profiles.applyBindText(stagedBinds(), typed)
				if not model.isStaged(merged) then
					model.stageBinds(merged)
				end

				return
			end

			-- The engine lower-cases the command as it parses the bind line, so a capitalised one would
			-- read back as something else. Its arguments keep their case.
			local command, rest = typed:match("^(%S+)(.*)$")
			if not command then
				return
			end

			local action = command:lower() .. rest
			if not editing then
				model.startCapture(action, action)
			elseif action ~= editing then
				model.renameAction(editing, action)
			end
		end,
	})
end

function model.openSelectionBuilder(action)
	local Select = model.selectCommand
	model.selectionBuilder:show(action and Select.parse(action), {
		title = action and L.selectionEdit or L.selectionAdd,
		acceptLabel = action and L.save or L.selectionChooseKey,
		cancelLabel = L.cancel,
		onAccept = function(newAction, command)
			if not action then
				model.startCapture(newAction, Select.describe(command))
			elseif not Select.sameSelection(newAction, action) then
				model.renameAction(action, newAction)
			end
		end,
	})
end

-- Routes a click on a keybind row to the edit it implies.
function model.handleZone(kind, action, label, raws)
	if kind == "remove" then
		-- One chip, one snapshot to take back, however many binds it stood for.
		model.batching, model.batchEdited = true, false
		for _, raw in ipairs(raws) do
			removeKeyset(action, raw)
		end
		model.batching = false
		if model.batchEdited then
			model.pushUndo()
		end
	elseif kind == "revert" then
		model.revert(action)
	elseif kind == "add" then
		model.startCapture(action, label)
	elseif kind == "rebind" then
		model.startCapture(action, label, raws)
	end
end

function model.textInput(char)
	if model.dialog then
		return not model.dialog.message and not model.dialog.nameless and model.nameBox:textInput(char)
	end
	if model.selectionBuilder:isOpen() then
		return model.selectionBuilder:textInput(char)
	end
	if model.searchBox and model.searchBox:isFocused() then
		return model.searchBox:textInput(char)
	end

	return false
end

-- Keys, offered to the modal, the capture, the dropdown and the search box in that order.
function model.keyPress(key, scanCode)
	if model.dialog then
		if key == KEYSYMS.ESCAPE then
			model.cancelDialog()
		elseif key == KEYSYMS.RETURN then
			model.acceptDialog()
		elseif not model.dialog.message and not model.dialog.nameless then
			-- Focus is dropped by the editbox on Escape/Return, which are handled above.
			model.nameBox:keyPress(key)
		end

		return true
	end

	if model.selectionBuilder:isOpen() then
		return model.selectionBuilder:keyPress(key)
	end

	if model.capturing then
		if key == 27 then
			model.capturing = nil
		else
			-- Skip auto-repeat; only the initial press adds an element (release clears pressed).
			local elem = pressElem(key, scanCode)
			if elem and not model.capturing.pressed[scanCode] then
				model.capturing.pressed[scanCode] = true
				model.appendChain(elem)
			end
		end
		return true
	end

	if model.presetDropdown and model.presetDropdown:isOpen() then
		if key == 27 then
			model.presetDropdown:close()
		end
		return true
	end
	if model.compareDropdown and model.compareDropdown:isOpen() then
		if key == 27 then
			model.compareDropdown:close()
		end
		return true
	end

	-- Escape has to come before the panel closes: leaving a view is what the key is for.
	if model.gridGroup and key == 27 then
		model.selectCategory(nil)

		return true
	end

	-- Ctrl+Z takes the last edit back. Below the capture and the dropdown, which take every
	-- key while they are up; above the search field, which has no use for it.
	if key == KEYSYMS.Z then
		local _, ctrl = Spring.GetModKeyState()
		if ctrl then
			model.undoEdit()

			return true
		end
	end

	-- The list being read is the one the search made, and the first Escape asks for that back.
	-- With nothing to clear it goes unclaimed and the widget above closes the panel.
	if key == KEYSYMS.ESCAPE then
		if model.searchBox and model.searchBox:getText() ~= "" then
			-- Focus stays, so the next thing typed starts a new search.
			model.searchBox:setText("")

			return true
		end
		if model.searchBox then
			model.searchBox:blur()
		end

		return false
	end

	if model.searchBox and model.searchBox:isFocused() then
		return model.searchBox:keyPress(key)
	end

	return false
end

-- Only a capture cares about releases, to know a held key has gone.
function model.keyRelease(key, scanCode)
	if model.capturing then
		model.capturing.pressed[scanCode] = nil
	end
end

----------------------------------------------------------------
-- What the windows do alike
----------------------------------------------------------------

-- What a header or footer button does, when it can.
function model.pressButton(id)
	if not model.buttonEnabled(id) then
		return
	end
	if id == "save" then
		model.startSave()
	elseif id == "reset" then
		model.startReset()
	elseif id == "duplicate" then
		model.startDuplicate()
	elseif id == "edit" then
		model.startEdit()
	elseif id == "export" then
		model.startClipboard(true)
	elseif id == "import" then
		model.startClipboard(false)
	end
end

-- A press on the name of a row the player made: what it runs, to change.
function model.pressLabel(row)
	if row.editSelection then
		model.openSelectionBuilder(row.action)
	else
		model.addBind(row.action)
	end
end

-- The rows a held one can move among: its block, those sharing its `reorder`.
function model.reorderSpan(at)
	local rows = model.rows
	local reorder = rows[at].reorder
	local first, last = at, at
	while rows[first - 1] and rows[first - 1].reorder == reorder do
		first = first - 1
	end
	while rows[last + 1] and rows[last + 1].reorder == reorder do
		last = last + 1
	end

	return first, last
end

-- A held row moved: shown there now, staged when let go (model.stageRowOrder).
function model.moveRow(from, to)
	table.insert(model.rows, to, table.remove(model.rows, from))
	model.rowsGen = model.rowsGen + 1
end

-- A key pressed on the keyboard page: the list, searched for that key on that layer. Handed to the search box rather
-- than filtered behind the scenes, so the player can see what narrows the list and clear it.
function model.showKey(key, layer)
	model.selectedCategory = nil
	view.scrollToTop()
	model.searchBox:setText(model.keyboard:keysetName(key, layer))
end

----------------------------------------------------------------
-- Tooltips, as the tooltip widgets' content tables
----------------------------------------------------------------

-- The keys the base preset had for a changed row, as its chips would print them.
function model.changeKeys(row)
	local shown, seen = {}, {}
	local pair = model.catalogShiftPair[row.action]
	for _, raw in ipairs(row.change or noRaws) do
		local disp = pair and keybindModel.displayWithoutShift(raw, model.working.layout)
			or keybindModel.displayKeyset(raw, model.working.layout)
		if not seen[disp] then
			seen[disp] = true
			shown[#shown + 1] = disp
		end
	end

	return #shown > 0 and table.concat(shown, ", ") or L.revertNone
end

-- A preset in a picker: its description, or what it was made from.
function model.presetTip(name)
	local builtin = profiles.isBuiltin(name)
	if builtin then
		return { text = builtin.description and BAR.I18N(builtin.description) or nil, note = L.presetDefault }
	end
	local base = profiles.baseOf(name)

	return { note = base and BAR.I18N("ui.keybinds.editor.presetBasedOn", { name = base.name }) or L.presetOwn }
end

-- The column's Changed entry.
function model.changedTip()
	if model.base then
		return { text = BAR.I18N("ui.keybinds.editor.changedTooltip", { name = model.base.name }) }
	end

	return { note = L.changedNoneTooltip }
end

-- An editable row, by the part under the cursor: the hollow chip says what a press puts back; otherwise what the
-- action does, what else its chip's key (group: a rowChipGroups entry) drives, and what the base preset had.
-- Answers the content and the title.
function model.rowTip(row, zone, group)
	if zone == "revert" and row.change then
		return { text = BAR.I18N("ui.keybinds.editor.revertTooltip", { keys = model.changeKeys(row) }) }, nil
	end
	local content = { text = row.description }
	local notes = {}
	local others = group and model.conflictsOf(row.action, group.raws)
	if others then
		-- A warning when the sharing is the player's; a note when the game ships it so.
		local clash = false
		for _, o in ipairs(others) do
			clash = clash or not o.shipped
		end
		local rows = {
			{ (clash and colorDanger or "") .. BAR.I18N("ui.keybinds.editor.conflict", { keys = group.display }), "" },
		}
		for _, o in ipairs(others) do
			rows[#rows + 1] = { model.sources[o.action] or L.other, model.labels[o.action] or o.action }
		end
		content.rows = rows
		notes[#notes + 1] = clash and L.conflictOrder or L.conflictShipped
	end
	if row.change and model.base then
		if #row.change > 0 then
			notes[#notes + 1] =
				BAR.I18N("ui.keybinds.editor.defaultIn", { name = model.base.name, keys = model.changeKeys(row) })
		else
			notes[#notes + 1] = BAR.I18N("ui.keybinds.editor.defaultNone", { name = model.base.name })
		end
	end
	if notes[1] then
		content.note = table.concat(notes, "\n")
	end

	return content, row.label
end

-- What goes to WG.tooltip: its text and note wrapped to `width`, colours carried over the breaks; nil when it says
-- nothing. A copy, as content tables are compared by value.
function model.wrapTip(content, font, width)
	if not (content and (content.text or content.rows or content.note)) then
		return nil
	end
	local wrapped = {}
	for k, v in pairs(content) do
		wrapped[k] = v
	end
	if font and font.WrapText then
		for _, k in ipairs({ "text", "note" }) do
			if wrapped[k] then
				wrapped[k] = text.carryColors(font:WrapText(wrapped[k], width))
			end
		end
	end

	return wrapped
end

-- A category picked, or the column left with nil: the list from the top.
function model.selectCategory(key)
	model.selectedCategory = key
	view.scrollToTop()
	model.rebuildRows()
end

-- A press on the grid page, by what its zone was: the key that cell or button binds is captured.
function model.pressGrid(zone, a, b)
	local gridGroup = model.gridGroup
	if zone == "cell" then
		local action = gridKeyActions[a][b]
		model.startCapture(action, gridGroup.cellLabel(a, b), model.gridKeyRaw(action))
	elseif zone == "category" then
		local action = gridCategoryActions[a]
		model.startCapture(action, gridGroup.categoryLabels[a], model.gridKeyRaw(action))
	elseif zone == "next" then
		model.startCapture("gridmenu_next_page", L.gridNextPage, model.gridKeyRaw("gridmenu_next_page"))
	elseif zone == "cycle" then
		model.startCapture("gridmenu_cycle_builder", gridGroup.cycleLabel, model.gridKeyRaw("gridmenu_cycle_builder"))
	end
end

-- The fields and pickers, made on first use: they read their strings then.
function model.ensureControls()
	if model.searchBox then
		return
	end
	-- Each control prints live, every frame, on the shared font, so each pins the panel's
	-- outline for itself.
	model.searchBox = Editbox.new({
		placeholder = BAR.I18N("ui.keybinds.editor.search"),
		clearable = true,
		onChange = model.rebuildRows,
		outline = outline,
	})
	model.presetDropdown = Dropdown.new({
		options = model.presetOptions,
		onSelect = model.switchToPreset,
		markSelected = true,
		outline = outline,
	})
	model.nameBox = Editbox.new({ maxChars = 40, outline = outline })
	-- The Changed section's picker of what to compare the active preset with.
	model.compareDropdown = Dropdown.new({
		options = {},
		onSelect = model.pickBase,
		markSelected = true,
		outline = outline,
	})
end

-- Re-reads the engine and rebuilds everything shown from it.
function model.refresh()
	model.ensureControls()
	-- The hotkeys widget writes the profile store from a copy of its own.
	profiles.invalidate()
	model.scanKeys, model.shippedPairs = {}, nil
	seedWorkingFromEngine()
	model.resolvedCatalog = nil
	-- Ahead of the picker, which labels its "new profile" entry from L.
	buildResolvedCatalog()
	model.refit = true
	model.dropVanishedCategory()
	model.refreshPicker()
	view.layout()
	model.rebuildRows()
end

-- The window closing: focus, the capture, a search and any open modal go.
function model.blur()
	model.selectionBuilder:close()
	local searchBox, presetDropdown = model.searchBox, model.presetDropdown
	if searchBox then
		searchBox:blur()
	end
	if presetDropdown then
		presetDropdown:close()
	end
	if model.compareDropdown then
		model.compareDropdown:close()
	end
	if model.nameBox then
		model.nameBox:blur()
	end
	model.capturing = nil
	-- Clicking a key on the keyboard page narrows through the same box, so this keeps that from
	-- outliving the visit that asked for it.
	if searchBox and searchBox:getText() ~= "" then
		searchBox:setText("")
		view.scrollToTop()
	end

	-- Through cancel rather than dropped: a live modal is holding a rollback, and the picker
	-- names a profile that was never switched to until that runs.
	model.cancelDialog()
end

----------------------------------------------------------------
-- The keyboard, while a window is open
----------------------------------------------------------------

-- Input ownership is taken once on open and given back on close, rather than every
-- frame, so chat's handling is restored exactly as it was found.
local ownsInput = false
local panelHasInput = false
local textInputStarted = false
-- Keys already down when the panel opened. Their release has to be let through, or
-- whatever they started stays stuck on once the panel starts swallowing releases.
local heldAtOpen = {}

-- Each frame, from the window's Update. ownText and disownText are the window's: what its handler offers for it.
function model.holdInput(open, ownText, disownText)
	-- Text ownership is what puts this panel ahead of actionHandler, which otherwise runs
	-- before every widget and would fire the keybinds being edited.
	if open then
		if not panelHasInput then
			panelHasInput = true
			heldAtOpen = Spring.GetPressedKeys and Spring.GetPressedKeys() or {}
			ownsInput = ownText()

			-- Chat has to be asked to let go, and toggling its input flag is the only public
			-- way to make it cancel. The flag goes straight back because gui_chat persists it,
			-- and a config save while the panel is open would leave chat input dead next
			-- launch. isInputActive is the accessor that means chat is holding input;
			-- getHandleInput is a saved option that reads true whoever the owner is, so poking
			-- on that cancels the settings search box or the widget selector's filter instead.
			if not ownsInput and WG.chat and WG.chat.isInputActive and WG.chat.isInputActive() then
				WG.chat.setHandleInput(false)
				WG.chat.setHandleInput(true)
				ownsInput = ownText()
			end
		elseif not ownsInput then
			ownsInput = ownText()
		end

		-- Only once it is ours. Starting SDL text input for a field we never took, then
		-- stopping it again on close, is what kills that field.
		if ownsInput and not textInputStarted then
			textInputStarted = true
			if Spring.SDLStartTextInput then
				Spring.SDLStartTextInput()
			end
		end
	elseif panelHasInput then
		panelHasInput = false
		if ownsInput then
			ownsInput = false
			disownText()
		end
		if textInputStarted then
			textInputStarted = false
			if Spring.SDLStopTextInput then
				Spring.SDLStopTextInput()
			end
		end
	end
end

-- The engine runs bound actions on release as well as on press, so releases have to be
-- swallowed too. A key already down when the panel opened is let through instead, or
-- whatever it started stays stuck on. Whether this release is to go through.
function model.releaseGoesThrough(key)
	if heldAtOpen[key] then
		heldAtOpen[key] = nil

		return true
	end

	return false
end

-- The window's Shutdown.
function model.releaseInput()
	if ownsInput then
		ownsInput = false
		if Spring.SDLStopTextInput then
			Spring.SDLStopTextInput()
		end
	end
end

return model
