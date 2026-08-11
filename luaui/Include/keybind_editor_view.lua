-- Interactive view for the in-game keybind editor, hosted as the first tab of
-- the Keybind/Mouse Info panel. Immediate-mode, drawn live every frame.
--
-- The picker lists the shipped profiles and the player's own. Edits are staged in the
-- working model and touch neither the engine nor disk until Save, which is also where
-- a shipped profile forks: saving over a read-only one creates a copy instead. Unsaved
-- work is marked with a "*" on the profile name and guarded on the way out.

local keybindModel = VFS.Include("luaui/Include/keybind_model.lua")
local keybindConfig = VFS.Include("luaui/Include/keybind_config.lua")
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

-- Shape and rules are documented in common/configs/keybinds.README.md; this is the
-- contract Chobby and the lobby read too, so it is data rather than Lua.
local catalog = keybindConfig.load('common/configs/keybind_catalog.json') or {}
local Editbox = VFS.Include("luaui/Include/keybind_editbox.lua")
local Dropdown = VFS.Include("luaui/Include/keybind_dropdown.lua")
local profiles = VFS.Include("luaui/Include/keybind_profiles.lua")

local KEYSYMS = VFS.Include("luaui/Include/keybind_keysyms.lua")
local text = VFS.Include("luaui/Include/keybind_text.lua")


local view = {}

local floor = math.floor
local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local isInRect = math.isInRect
local spGetScanSymbol = Spring.GetScanSymbol
local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glBlending = gl.Blending

-- The engine loads this one file; a profile is applied by writing it here.
local customKeysFile = profiles.activeFile

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
local scale = 1
local rowHeight = 22
local listTop = 0
local barX1 = 0
local listX1 = 0
local sidebarW = 0
local categories = {}
-- Selection is held as the catalog's i18n key, never its translated title, so a language
-- change cannot strand it against titles that have all moved.
local selectedCategory
-- Stands in for the generated Other bucket when no catalog category is titled the same.
-- A table cannot collide with a catalog key, which is always a string.
local generatedOtherKey = {}
local otherCategoryKey = generatedOtherKey
-- Set while a category asks to be drawn as the grid menu instead of a row list.
local gridGroup
local listRight = 0
local keyAreaX1 = 0

local working
local resolvedCatalog
-- Grouped chips per action. Derived purely from working.byAction, and every path that
-- changes that rebuilds the rows, so rebuildRows is where it gets dropped.
local chipGroups = {}
local catalogAny, catalogAnyPrefixes, catalogShiftPair = {}, {}, {}
local L = {}
local rows = {}
local scroll = 0
local dragging = false
local dirty = false
local capturing

local font
local RectRound, Scroller, UiElement, Highlight

local colorAction = "\255\210\210\205"
local colorKey = "\255\235\185\070"
local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"
local colorHeader = "\255\255\200\130"
local colorDanger = "\255\235\090\090"
-- SelectHighlight defaults to 0.35 and the rest of the UI stays near it. At 1 the
-- overlay is opaque and swallows the label under it.
local hoverOpacity = 0.25
local buttonFill = { 0.18, 0.18, 0.18, 1 }
-- Matching stops because Draw.Button gradients color1 -> color2, and the white hover
-- overlay washes a tinted button out to grey, so these brighten instead.
local dangerFill = { 0.46, 0.10, 0.10, 1 }
local dangerFillHover = { 0.66, 0.14, 0.14, 1 }
local confirmFill = { 0.17, 0.38, 0.21, 1 }
local confirmFillHover = { 0.24, 0.52, 0.29, 1 }
local confirmFillMuted = { 0.11, 0.20, 0.13, 1 }
local pillFill = { 0.22, 0.22, 0.22, 1 }
local sheenTop = { 1, 1, 1, 0.05 }
local sheenNone = { 1, 1, 1, 0 }
local hoverWash = { 1, 1, 1, 0.08 }
local rowWash = { 1, 1, 1, 0.06 }

local searchBox, presetDropdown, nameBox, menuToggle
local switchToPreset, scrollFromY

local dialog

local headerButtons = {
	{ id = "duplicate", icon = "LuaUI/Images/keybinds/duplicate.png" },
	{ id = "edit", icon = "LuaUI/Images/keybinds/edit.png" },
}

local footerButtons = {
	{ id = "reset" },
	{ id = "save", fill = confirmFill, fillHover = confirmFillHover, fillMuted = confirmFillMuted },
}

local buttonSets = { headerButtons, footerButtons }

-- Header and footer bands, shared by the layout and by every geometry derived from it.
local headerH = 0
local footerH = 0
local layoutPending = false

----------------------------------------------------------------
-- Profiles and the picker
----------------------------------------------------------------

local presetOptions = {}

-- Picker contents: the shipped profiles, the player's own, and any unsaved fork.
local function buildPresetOptions()
	local active = profiles.activeName()
	-- Editing a shipped profile does not change it: what is on screen is an unsaved new
	-- profile, so the picker says that instead of marking the read-only one as modified.
	local pending = dirty and profiles.isBuiltin(active) ~= nil

	presetOptions = {}
	for _, b in ipairs(profiles.builtins) do
		presetOptions[#presetOptions + 1] = { label = b.name, name = b.name, builtin = true }
	end
	for _, name in ipairs(profiles.list()) do
		local marked = (dirty and name == active) and (name .. " *") or name
		presetOptions[#presetOptions + 1] = { label = marked, name = name }
	end
	if pending then
		presetOptions[#presetOptions + 1] = { label = L.newProfile .. " *", pending = true }
	end

	return presetOptions
end

-- Shipped profiles can be copied but not renamed or deleted.
local function activeIsOwn()
	return profiles.get(profiles.activeName()) ~= nil
end

-- Single source for whether a button is live, so it cannot draw enabled and do nothing.
local function buttonEnabled(id)
	if id == "save" or id == "reset" then
		return dirty
	end
	if id == "duplicate" then
		return true
	end

	return activeIsOwn()
end

local function currentPresetIndex()
	local last = presetOptions[#presetOptions]
	if last and last.pending then
		return #presetOptions
	end

	local name = profiles.activeName()
	for i = 1, #presetOptions do
		if presetOptions[i].name == name then
			return i
		end
	end

	return 1
end

----------------------------------------------------------------
-- Scrolling
----------------------------------------------------------------

local function listBottom()
	return area.y1 + footerH
end

-- Whole rows the band can paint.
local function visibleRows()
	return math.max(1, floor((listTop - listBottom()) / rowHeight))
end

-- Furthest offset that still fills the band.
local function maxScroll()
	return math.max(0, #rows - visibleRows())
end

local function clampScroll()
	if scroll < 0 then scroll = 0 end
	if scroll > maxScroll() then scroll = maxScroll() end
end

----------------------------------------------------------------
-- Catalog and the row list
----------------------------------------------------------------

-- Resolve i18n labels once (search rebuilds rows per keystroke); redone on refresh.
local function buildResolvedCatalog()
	resolvedCatalog = {}
	catalogAny, catalogAnyPrefixes, catalogShiftPair = {}, {}, {}
	for _, group in ipairs(catalog) do
		if group.hidden then
			resolvedCatalog[#resolvedCatalog + 1] = { hidden = group.hidden, title = "", titleLower = "", items = {} }
		else
			local title = Spring.I18N(group.category)
			local g = { category = group.category, layout = group.layout, title = title,
				titleLower = title:lower(), items = {} }
			for _, item in ipairs(group.items) do
				if item.prefix then
					if item.alwaysModifier == "any" then
						catalogAnyPrefixes[#catalogAnyPrefixes + 1] = item.prefix
					end
					g.items[#g.items + 1] = { prefix = item.prefix, label = item.label,
						unit = item.unit, members = item.members }
				else
					if item.action then
						if item.alwaysModifier == "any" then
							catalogAny[item.action] = true
						elseif item.alwaysModifier == "shift" then
							catalogShiftPair[item.action] = true
						end
					end
					local label = Spring.I18N(item.label)
					g.items[#g.items + 1] = {
						action = item.action,
						actionLower = item.action and item.action:lower(),
						label = label,
						labelLower = label:lower(),
						keyText = item.keyLabel and Spring.I18N(item.keyLabel) or "",
						modifierOnly = item.modifierOnly,
					}
				end
			end
			if g.layout == "grid" then
				-- Pulled off the same catalog entries the list would have used, so the grid and
				-- the flat form name things identically.
				g.categoryLabels = {}
				for _, it in ipairs(group.items) do
					local n = it.action and it.action:match("^gridmenu_category%s+(%d+)$")
					if n then
						g.categoryLabels[tonumber(n)] = Spring.I18N(it.label)
					end
					if it.prefix == "gridmenu_key" and it.label then
						local key = it.label
						g.cellLabel = function(row, col)
							return Spring.I18N(key, { n = row .. " " .. col, row = row, col = col })
						end
					end
				end
				g.cellLabel = g.cellLabel or function(row, col)
					return row .. " " .. col
				end
				for _, it in ipairs(group.items) do
					if it.action == "gridmenu_cycle_builder" and it.label then
						g.cycleLabel = Spring.I18N(it.label)
					end
				end
				g.cycleLabel = g.cycleLabel or "gridmenu_cycle_builder"
			end
			resolvedCatalog[#resolvedCatalog + 1] = g
		end
	end

	L.other = Spring.I18N('ui.keybinds.editor.other')
	L.otherLower = L.other:lower()
	L.title = Spring.I18N('ui.keybinds.title')
	L.allCategories = Spring.I18N('ui.keybinds.editor.allCategories')
	L.gridNextPage = Spring.I18N('ui.keybinds.gridMenu.nextPage')
	-- gui_gridmenu hardcodes both the caption and the key on this button, so it is not
	-- bindable and there is no i18n key to read.
	-- Shared with gui_gridmenu, which draws the button this mirrors.
	L.gridBack = Spring.I18N('ui.buildMenu.back')

	categories = { { label = L.allCategories } }
	otherCategoryKey = generatedOtherKey
	local seen = {}
	for _, g in ipairs(resolvedCatalog) do
		-- Keyed like the row filter below, not by title: two categories that translate to
		-- the same words are still separate, and one has to not vanish from the column.
		if not g.hidden and not seen[g.category] then
			seen[g.category] = true
			categories[#categories + 1] = { label = g.title, key = g.category }
			-- A catalog category of the same name takes the leftovers, matching the row
			-- order below, rather than a second column entry appearing beside it.
			if g.title == L.other then
				otherCategoryKey = g.category
			end
		end
	end
	if otherCategoryKey == generatedOtherKey then
		categories[#categories + 1] = { label = L.other, key = otherCategoryKey }
	end
	L.pressKey = Spring.I18N('ui.keybinds.editor.pressKey')
	L.newProfile = Spring.I18N('ui.keybinds.editor.newProfile')
	L.duplicate = Spring.I18N('ui.keybinds.editor.duplicate')
	L.edit = Spring.I18N('ui.keybinds.editor.edit')
	L.editTitle = Spring.I18N('ui.keybinds.editor.editTitle')
	L.delete = Spring.I18N('ui.keybinds.editor.delete')
	L.duplicateTitle = Spring.I18N('ui.keybinds.editor.duplicateTitle')
	L.save = Spring.I18N('ui.keybinds.editor.save')
	L.reset = Spring.I18N('ui.keybinds.editor.reset')
	L.resetConfirm = Spring.I18N('ui.keybinds.editor.resetConfirm')
	L.saveTitle = Spring.I18N('ui.keybinds.editor.saveTitle')
	L.discard = Spring.I18N('ui.keybinds.editor.discard')
	L.unsavedTitle = Spring.I18N('ui.keybinds.editor.unsavedTitle')
	L.unsavedMessage = Spring.I18N('ui.keybinds.editor.unsavedMessage')
	L.applyFailedTitle = Spring.I18N('ui.keybinds.editor.applyFailedTitle')
	L.accept = Spring.I18N('ui.keybinds.editor.accept')
	L.cancel = Spring.I18N('ui.keybinds.editor.cancel')
end

-- Rebuilds the display list from the catalog and the staged binds, honouring both the
-- search box and the category column.
local function rebuildRows()
	chipGroups = {}
	if not resolvedCatalog then
		buildResolvedCatalog()
	end

	rows = {}

	-- A grid category replaces the list outright: its keys only make sense laid out the
	-- way the grid menu itself draws them, so there are no rows to build.
	gridGroup = nil
	if selectedCategory then
		for _, group in ipairs(resolvedCatalog) do
			if group.category == selectedCategory and group.layout == "grid" then
				gridGroup = group
			end
		end
	end
	if gridGroup then
		clampScroll()

		return
	end
	local query = searchBox and searchBox:getText():lower() or ""
	local catalogActions = {}
	local otherGroupEnd

	-- Claim hidden actions up front so they never surface, as a row or under Other.
	-- Exact ids only (not prefixes), so a future action can't be hidden by coincidence.
	for _, group in ipairs(resolvedCatalog) do
		if group.hidden then
			for _, h in ipairs(group.hidden) do
				catalogActions[h] = true
			end
		end
	end

	for _, group in ipairs(resolvedCatalog) do
		-- Non-selected groups are still walked: they have to claim their actions or the
		-- leftovers below would sweep them all into Other.
		local inCategory = not selectedCategory or group.category == selectedCategory
		local categoryMatch = query ~= "" and group.titleLower:find(query, 1, true)
		local groupRows = {}
		for _, item in ipairs(group.items) do
			-- An empty prefix would claim every bound action, so treat it as no prefix.
			if item.prefix and item.prefix ~= "" then
				-- A declared member is a row whether or not it is bound, so unbinding the last
				-- key of "group select 3" leaves the row there to bind again. Families the
				-- catalog cannot enumerate (buildunit_ is per unit) list no members and are
				-- still discovered from what is bound.
				local matched = {}
				for _, member in ipairs(item.members or {}) do
					local action = item.prefix .. member
					catalogActions[action] = true
					matched[#matched + 1] = action
				end

				local found = {}
				for action in pairs(working.byAction) do
					if not catalogActions[action] and action:sub(1, #item.prefix) == item.prefix then
						catalogActions[action] = true
						found[#found + 1] = action
					end
				end
				table.sort(found)
				for i = 1, #found do
					matched[#matched + 1] = found[i]
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
							local name = Spring.I18N(key)
							if name ~= key then arg = name end
						end
					end
					local row, col = arg:match("^%s*(%S+)%s+(%S+)")
					local label = item.label and Spring.I18N(item.label, { n = arg, row = row, col = col }) or action
					if query == "" or categoryMatch or action:lower():find(query, 1, true) or label:lower():find(query, 1, true) then
						groupRows[#groupRows + 1] = { type = "editable", action = action, label = label }
					end
				end
			-- Skip an action a hidden entry or an earlier prefix already claimed, so a
			-- hide stays authoritative and entry order can't produce a duplicate row.
			elseif not (item.action and catalogActions[item.action]) then
				if item.action then
					catalogActions[item.action] = true
				end
				if query == "" or categoryMatch or item.labelLower:find(query, 1, true)
					or (item.actionLower and item.actionLower:find(query, 1, true)) then
					if item.modifierOnly then
						-- Read-only, but the keys still come from the profile rather than a fixed
						-- string: capture cannot produce a bare modifier, so offering the chips
						-- would let a player remove a binding they could never put back.
						local shown, seen = {}, {}
						for _, ks in ipairs(working.byAction[item.action] or {}) do
							if not seen[ks.display] then
								seen[ks.display] = true
								shown[#shown + 1] = ks.display
							end
						end
						groupRows[#groupRows + 1] = { type = "info", label = item.label,
							keyText = table.concat(shown, ", ") }
					elseif item.action then
						groupRows[#groupRows + 1] = { type = "editable", action = item.action, label = item.label }
					else
						groupRows[#groupRows + 1] = { type = "info", label = item.label, keyText = item.keyText }
					end
				end
			end
		end

		if inCategory and #groupRows > 0 then
			rows[#rows + 1] = { type = "header", text = group.title }
			if group.layout == "grid" then
				-- Its keys only read laid out, so the list points at that view rather than
				-- repeating them flat. Still driven by the rows a search matched, so hunting
				-- for one of them surfaces the way in.
				rows[#rows + 1] = { type = "link", label = L.edit, category = group.category }
			else
				for i = 1, #groupRows do
					rows[#rows + 1] = groupRows[i]
				end
			end
			if group.title == L.other then
				otherGroupEnd = #rows
			end
		end
	end

	local otherMatch = query ~= "" and L.otherLower:find(query, 1, true)
	local others = {}
	for action in pairs(working.byAction) do
		if not catalogActions[action] and (query == "" or otherMatch or action:lower():find(query, 1, true)) then
			others[#others + 1] = action
		end
	end

	if #others > 0 and (not selectedCategory or selectedCategory == otherCategoryKey) then
		table.sort(others)

		-- A catalog category can be titled the same as this generated one; when it is,
		-- the leftovers join it after its own items instead of repeating the header.
		local tail = {}
		if otherGroupEnd then
			for i = otherGroupEnd + 1, #rows do
				tail[#tail + 1] = rows[i]
				rows[i] = nil
			end
		else
			rows[#rows + 1] = { type = "header", text = L.other }
		end

		for _, action in ipairs(others) do
			rows[#rows + 1] = { type = "editable", action = action, label = action }
		end
		for i = 1, #tail do
			rows[#rows + 1] = tail[i]
		end
	end

	clampScroll()
end

----------------------------------------------------------------
-- Staging
----------------------------------------------------------------

-- Staged-edits flag, read by the picker marker and the footer buttons alike.
local function setDirty(value)
	dirty = value
end

-- Re-reading the engine replaces whatever was staged, so the flag describing those edits
-- goes with them. Without that a language or layout change leaves the flag armed over
-- bindings it no longer describes, and Save writes the engine's keymap back as an edit.
local function seedWorkingFromEngine()
	local model = keybindModel.build()
	working = { byAction = {}, layout = model.layout, binds = model.binds }
	for _, entry in ipairs(model.actions) do
		local copy = {}
		for _, k in ipairs(entry.keysets) do
			copy[#copy + 1] = { raw = k.raw, display = k.display }
		end
		working.byAction[entry.action] = copy
	end

	setDirty(false)
end

-- Detached copy of the staged binds, for handing to the store.
local function stagedBinds()
	local out = {}
	for i, b in ipairs(working.binds) do
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

-- Which build menu a profile implies. Only the shipped ones imply anything: a profile of
-- the player's own leaves the menu alone, so the settings toggle stays theirs to set.
-- Read from the binds rather than the name, since the grid menu is inert without its
-- gridmenu_* keys and the build menu is what buildunit_* hotkeys drive.
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
	if menuToggle then
		menuToggle(wantsGridMenu(name))
	end

	if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
		WG['bar_hotkeys'].reloadBindings()
	else
		view.refresh()
	end
end

local function refreshPicker()
	buildPresetOptions()
	presetDropdown:setOptions(presetOptions)
	presetDropdown:setSelected(currentPresetIndex())
end

-- Staging changes the picker too: the active profile picks up the unsaved marker.
local function markStaged()
	setDirty(true)
	refreshPicker()
	rebuildRows()
end

-- Staged edits live only in `working`, so throwing them away means re-reading the engine.
-- Clearing the flag on its own would leave the edits on screen and still saveable.
local function discardStaged()
	seedWorkingFromEngine()
	refreshPicker()
	rebuildRows()
end

----------------------------------------------------------------
-- Dialogs
----------------------------------------------------------------

-- Raises a modal, taking focus off the search box.
local function openDialog(d)
	-- Replacing a live modal outright would drop the rollback its cancel was holding, which
	-- is how the picker ends up naming a profile that was never switched to. Run it first,
	-- with the slot already empty so the cancel cannot clobber the incoming dialog.
	local previous = dialog
	dialog = nil
	if previous and previous.cancel then
		previous.cancel()
	end

	-- A modal draws over the capture and takes its keys, so leaving one running behind would
	-- drop the player back into it on cancel, seeded from bindings the modal may have changed.
	capturing = nil

	dialog = d
	searchBox:blur()
	if not d.message then
		nameBox:setText(d.initial or "")
		nameBox:focus()
	end
end

-- Drops the modal, handing it back so the caller can act on it.
local function closeDialog()
	local d = dialog
	dialog = nil
	nameBox:blur()

	return d
end

local function cancelDialog()
	local d = closeDialog()
	if d and d.cancel then
		d.cancel()
	end
end

-- The optional third button: "Discard" when leaving unsaved edits, "Delete" when
-- editing a profile.
local function middleDialog()
	local d = closeDialog()
	if d and d.middle then
		d.middle.action()
	end
end

-- Confirmation path; only a dialog with a name field has text to read.
local function acceptDialog()
	local name = dialog and not dialog.message
		and nameBox:getText():gsub("^%s+", ""):gsub("%s+$", "") or ""
	local d = closeDialog()
	if not d then
		return
	end

	-- An empty name would make the profile unselectable, so treat it as a cancel.
	if not d.message and name == "" then
		if d.cancel then d.cancel() end
		return
	end

	d.accept(name)
end

----------------------------------------------------------------
-- Profile commands
----------------------------------------------------------------

-- Makes a profile the live one, leaving its stored binds alone. Answers whether it took.
-- A keymap that never reached disk must not clear the staged flag: the reload below would
-- load whatever file is still there and the player would watch their edits revert.
local function selectProfile(name, fromName)
	if not profiles.materialize(name) then
		openDialog({
			title = L.applyFailedTitle,
			message = Spring.I18N("ui.keybinds.editor.applyFailedMessage", { name = name }),
			accept = function() end,
		})

		return false
	end

	profiles.setActive(name)
	setDirty(false)
	refreshPicker()
	applyActiveProfile(name, fromName)

	return true
end

-- Commit point: the staged keymap reaches the engine and the store together. Answers
-- whether it landed, so a caller that closes the panel on the way out does not do so over
-- a save that failed.
local function applyStaged(name, fromName)
	local profile = profiles.get(name)
	if profile then
		profile.binds = stagedBinds()
		profiles.save()
	end

	return selectProfile(name, fromName)
end

-- Saving over a shipped profile is a fork: it asks for a name and writes a new one.
local function startSave(andThen, onCancel)
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
			local created = profiles.create(newName, stagedBinds(), activeFakeMeta())
			if applyStaged(created, name) and andThen then
				andThen()
			end
		end,
		cancel = onCancel,
	})
end

-- Staged edits are not in the engine yet, so anything that would replace them asks
-- first. Returns whether it could go ahead immediately.
local function guardDirty(proceed, onCancel)
	if not dirty then
		proceed()

		return true
	end

	openDialog({
		title = L.unsavedTitle,
		message = L.unsavedMessage,
		acceptLabel = L.save,
		save = true,
		accept = function() startSave(proceed, onCancel) end,
		middle = { label = L.discard, action = function()
			discardStaged()
			proceed()
		end },
		cancel = onCancel,
	})

	return false
end

switchToPreset = function(opt)
	-- The pending entry is already what is on screen; picking it is not a switch.
	if opt.pending then
		return
	end

	guardDirty(function()
		-- The picker committed the new name before the guard ran, so a switch that does not
		-- happen has to put the selection back.
		if not selectProfile(opt.name, profiles.activeName()) then
			refreshPicker()
		end
	end, refreshPicker)
end

-- Throws staged edits away, back to the active profile as last saved.
local function startReset()
	openDialog({
		title = L.reset,
		message = L.resetConfirm,
		accept = function()
			discardStaged()
		end,
	})
end

local function startDuplicate()
	local from = profiles.activeName()
	openDialog({
		title = L.duplicateTitle,
		initial = profiles.uniqueName(from),
		accept = function(name)
			-- Copies what is on screen rather than what was last saved, so pending
			-- edits come along instead of being silently dropped.
			applyStaged(profiles.create(name, stagedBinds(), activeFakeMeta()), from)
		end,
	})
end

-- Renaming and deleting share one dialog: the name field commits a rename, the
-- middle button deletes. Deleting asks again, since it cannot be undone.
local function startEdit()
	local name = profiles.activeName()
	openDialog({
		title = L.editTitle,
		initial = name,
		accept = function(newName)
			profiles.rename(name, newName)
			refreshPicker()
		end,
		middle = { label = L.delete, danger = true, action = function()
			openDialog({
				title = L.delete,
				message = Spring.I18N("ui.keybinds.editor.deleteConfirm", { name = name }),
				acceptLabel = L.delete,
				danger = true,
				accept = function()
					-- Re-seeded rather than just unflagged: clearing the flag alone would
					-- leave the deleted profile's edits on screen with Save greyed out.
					discardStaged()
					profiles.delete(name)

					-- Whatever the store fell back to has to be made live; the deleted profile
					-- is still what the engine has loaded. Selected rather than committed: the
					-- staged keymap belongs to the profile just deleted.
					selectProfile(profiles.activeName(), name)
				end,
			})
		end },
	})
end

----------------------------------------------------------------
-- Layout and geometry
----------------------------------------------------------------

-- Builds the controls on first use, the font not existing at include time.
local function ensureControls()
	if searchBox and presetDropdown then
		return
	end

	searchBox = Editbox.new({ placeholder = Spring.I18N('ui.keybinds.editor.search'), onChange = rebuildRows })
	presetDropdown = Dropdown.new({ options = presetOptions, onSelect = switchToPreset })
	nameBox = Editbox.new({ maxChars = 40 })
end

-- Buttons size to their own label so a longer translation is not clipped and a short
-- one is not padded out. Layout can run before view.init has a font, so that case
-- falls back to a width and asks draw to lay out again once the font is there.
local function labelWidth(label, size, pad)
	if not font then
		layoutPending = true

		return floor(110 * scale)
	end

	return floor(font:GetTextWidth(label) * size) + pad * 2
end

-- Accept wording, needed by the geometry as well as the drawing.
local function acceptLabelFor(d)
	return d.acceptLabel or (d.message and L.accept or L.save)
end

-- Header and footer rects, placed right to left from the panel edge.
local function layoutHeader()
	headerH = floor(34 * scale)
	footerH = floor(34 * scale)

	if not (searchBox and presetDropdown) then
		return
	end

	layoutPending = false

	local gap = floor(8 * scale)
	local rowTop = area.y2 - floor(4 * scale)
	local rowBottom = area.y2 - headerH + floor(4 * scale)
	local presetW = floor(240 * scale)
	local btnFs = (rowTop - rowBottom) * 0.5

	-- Right to left: the edit dialog opener, duplicate, then the picker they act on.
	local iconW = rowTop - rowBottom
	local editW, dupW = iconW, iconW
	local editX1 = area.x2 - editW
	local dupX1 = editX1 - gap - dupW
	local pickerX1 = dupX1 - gap - presetW

	headerButtons[1].rect = { dupX1, rowBottom, dupX1 + dupW, rowTop }
	headerButtons[2].rect = { editX1, rowBottom, area.x2, rowTop }
	presetDropdown:setRect(pickerX1, rowBottom, pickerX1 + presetW, rowTop, btnFs)
	searchBox:setRect(listX1, rowBottom, pickerX1 - gap, rowTop, btnFs)

	local fTop = area.y1 + footerH - floor(4 * scale)
	local fBottom = area.y1 + floor(4 * scale)
	local fFs = (fTop - fBottom) * 0.5
	local fPad = floor(14 * scale)
	local x2 = area.x2
	for i = #footerButtons, 1, -1 do
		local b = footerButtons[i]
		local w = labelWidth(L[b.id] or b.id, fFs, fPad)
		b.rect = { x2 - w, fBottom, x2, fTop }
		x2 = x2 - w - gap
	end
end

-- Profile-modal geometry, derived in one place so draw and mousePress agree.
local function dialogGeometry()
	local w = floor(315 * scale)
	local h = floor(150 * scale)
	local messageLines, messageStep
	if dialog and dialog.message and font then
		messageStep = floor(rowHeight * 0.75)
		messageLines = text.wrap(font, dialog.message, w - floor(32 * scale), floor(rowHeight * 0.5))
		h = h + math.max(0, #messageLines - 1) * messageStep
	end
	local cx = (area.x1 + area.x2) * 0.5
	local cy = (area.y1 + area.y2) * 0.5
	local bx1, bx2 = floor(cx - w * 0.5), floor(cx + w * 0.5)
	local by1, by2 = floor(cy - h * 0.5), floor(cy + h * 0.5)
	local bh = floor(28 * scale)
	local pad = floor(16 * scale)
	local btnY1 = by1 + pad
	local bfs = bh * 0.5
	local bpad = floor(14 * scale)

	local cancelW = labelWidth(L.cancel, bfs, bpad)
	local cancel = { bx1 + pad, btnY1, bx1 + pad + cancelW, btnY1 + bh }

	local okW = labelWidth(dialog and acceptLabelFor(dialog) or L.save, bfs, bpad)
	local ok = { bx2 - pad - okW, btnY1, bx2 - pad, btnY1 + bh }

	local midW = labelWidth(dialog and dialog.middle and dialog.middle.label or L.discard, bfs, bpad)
	local midX = (bx1 + bx2) * 0.5
	local discard = { floor(midX - midW * 0.5), btnY1, floor(midX + midW * 0.5), btnY1 + bh }
	local fieldY1 = btnY1 + bh + floor(20 * scale)
	local field = { bx1 + pad, fieldY1, bx2 - pad, fieldY1 + floor(26 * scale) }

	return bx1, by1, bx2, by2, ok, cancel, field, discard, messageLines, messageStep
end

-- Capture-modal geometry, derived in one place so draw and mousePress agree.
local function captureGeometry()
	local w = floor(420 * scale)
	local h = floor(200 * scale)
	local cx = (area.x1 + area.x2) * 0.5
	local cy = (area.y1 + area.y2) * 0.5
	local bx1, bx2 = floor(cx - w * 0.5), floor(cx + w * 0.5)
	local by1, by2 = floor(cy - h * 0.5), floor(cy + h * 0.5)
	local bw = floor(120 * scale)
	local bh = floor(28 * scale)
	local pad = floor(16 * scale)
	local btnY1 = by1 + pad
	local cancel = { bx1 + pad, btnY1, bx1 + pad + bw, btnY1 + bh }
	local ok = { bx2 - pad - bw, btnY1, bx2 - pad, btnY1 + bh }
	return bx1, by1, bx2, by2, ok, cancel
end

----------------------------------------------------------------
-- Panel lifecycle
----------------------------------------------------------------

-- Picks up the font and the FlowUI entry points, which do not exist at include time.
function view.init()
	font = WG['fonts'].getFont()
	RectRound = WG.FlowUI.Draw.RectRound
	Scroller = WG.FlowUI.Draw.Scroller
	UiElement = WG.FlowUI.Draw.Element
	Highlight = WG.FlowUI.Draw.SelectHighlight
	ensureControls()
end

-- Re-reads the engine and rebuilds everything shown from it.
function view.refresh()
	ensureControls()
	seedWorkingFromEngine()
	resolvedCatalog = nil
	-- Ahead of the picker, which labels its "new profile" entry from L.
	buildResolvedCatalog()
	refreshPicker()
	layoutHeader()
	rebuildRows()
end

-- Takes the panel rect from the host; every band and column is derived from it.
function view.setArea(x1, y1, x2, y2, s)
	ensureControls()
	area.x1, area.y1, area.x2, area.y2 = x1, y1, x2, y2
	scale = s or 1
	rowHeight = floor(22 * scale)

	local pad = floor(6 * scale)

	sidebarW = floor(200 * scale)
	listX1 = area.x1 + sidebarW + floor(12 * scale)

	layoutHeader()

	listTop = area.y2 - headerH - floor(4 * scale)
	listRight = area.x2 - floor(12 * scale) - pad
	barX1 = listRight + floor(4 * scale)
	keyAreaX1 = listX1 + floor((listRight - listX1) * 0.45)

	-- Shortened here rather than in the draw loop: the column width and the font size are
	-- both settled by now, and this runs on a resize where the loop runs every frame.
	local labelW = sidebarW - pad * 2
	for _, c in ipairs(categories) do
		c.fitted = text.fit(font, c.label, labelW, rowHeight * 0.55)
	end

	clampScroll()
end

-- Panel closing: drop focus, tooltips and any open modal.
function view.blur()
	if WG['tooltip'] then
		for _, b in ipairs(headerButtons) do
			WG['tooltip'].RemoveTooltip('keybind_' .. b.id)
		end
	end
	if searchBox then
		searchBox:blur()
	end
	if presetDropdown then presetDropdown:close() end
	if nameBox then nameBox:blur() end
	capturing = nil

	-- Through cancel rather than dropped: a live modal is holding a rollback, and the picker
	-- names a profile that was never switched to until that runs.
	cancelDialog()
end

-- The host calls this before closing; false means a dialog is now asking what to do
-- with staged edits and the close should not happen yet.
function view.confirmClose(proceed)
	return guardDirty(proceed)
end

-- Host hook for swapping the build menu when a profile implies one.
function view.setMenuToggle(fn)
	menuToggle = fn
end

-- Switching profiles applies the build menu the new one implies, but a profile can become
-- live without passing through here: the hotkey loader writes one out on the launch where
-- the shipped preset files stop being installed. Applied at startup as well, so the menu
-- matches whatever ended up loaded rather than whichever was running before.
function view.applyMenuForActive()
	if menuToggle then
		menuToggle(wantsGridMenu(profiles.activeName()))
	end
end

----------------------------------------------------------------
-- Editing keysets
----------------------------------------------------------------

-- Whether the action already carries this binding. Compared canonically rather than by
-- the printed label: the label drops Any+ and resolves scancodes through the layout, so it
-- reports two bindings the engine resolves differently as the same one. exceptRaw skips
-- the keyset being rebound.
local function actionHasKeyset(action, newKeyset, exceptRaw)
	local ks = working.byAction[action]
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
	working.binds[#working.binds + 1] = { keyset = raw, action = action }

	local ks = working.byAction[action]
	if not ks then
		ks = {}
		working.byAction[action] = ks
	end
	ks[#ks + 1] = { raw = raw, display = keybindModel.displayKeyset(raw, working.layout) }
end

local function stageRemove(action, raw)
	for i = #working.binds, 1, -1 do
		local b = working.binds[i]
		if b.action == action and b.keyset == raw then
			table.remove(working.binds, i)
			break
		end
	end

	local ks = working.byAction[action] or {}
	for i = #ks, 1, -1 do
		if ks[i].raw == raw then
			table.remove(ks, i)
			break
		end
	end
	-- The entry stays when its last keyset goes. Rows the catalog does not name are derived
	-- from this table, so dropping it takes the row with it and there is nothing left to
	-- click to bind the action again.
end

-- Rewrite a binding where it sits. Two actions on one keyset are tried in bind order,
-- so re-adding at the end would hand the other one priority.
local function stageReplace(action, oldRaw, newRaw)
	local entry
	for _, b in ipairs(working.binds) do
		if b.action == action and b.keyset == oldRaw then
			entry = b
			break
		end
	end

	if not entry then
		return false
	end

	entry.keyset = newRaw

	for _, k in ipairs(working.byAction[action] or {}) do
		if k.raw == oldRaw then
			k.raw = newRaw
			k.display = keybindModel.displayKeyset(newRaw, working.layout)
			break
		end
	end

	return true
end

-- The grid menu answers its category keys whether or not Shift is held, which the engine
-- can only express as two binds. Deriving both from one capture keeps a rebind from
-- leaving the halves on different keys.
-- Built from the captured elements rather than the joined keyset, so Shift lands after any
-- other modifiers the way the engine writes them: Ctrl+K pairs as Ctrl+K and Ctrl+Shift+K.
-- Shift qualifies the first tap only; later taps in a chain are the same in both halves.
local function shiftPairRaws(elems)
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
	local ks = working.byAction[action] or {}
	local existing = {}
	for i = 1, #ks do
		existing[i] = ks[i].raw
	end

	-- Compared as a set: these are all the same action, so which keyset sits in which slot
	-- carries no meaning, and a positional check would call a reordered pair a change and
	-- then rewrite the slots into the order they already had.
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
	-- Accepting the capture unchanged is not an edit. Staging it would arm Save, grow a
	-- pending entry in the picker, and raise the unsaved-changes guard over nothing.
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
	if catalogShiftPair[action] then
		if not stageSetKeysets(action, {}) then
			return
		end
	else
		stageRemove(action, raw)
	end

	markStaged()
end

-- One key can drive several actions (e.g. backspace = mutesound + edit_backspace),
-- so add the binding without disturbing others on the same keyset.
local function commitCapture(keyset)
	local c = capturing

	-- Left open rather than closed on a key the action already carries. Closing with nothing
	-- changed is indistinguishable from the editor having dropped the press.
	if not c.oldRaw and not catalogShiftPair[c.action] and actionHasKeyset(c.action, keyset) then
		return
	end

	capturing = nil

	if catalogShiftPair[c.action] then
		if stageSetKeysets(c.action, shiftPairRaws(c.elems)) then
			markStaged()
		end
	elseif c.oldRaw then
		rebindKeyset(c.action, c.oldRaw, keyset)
		-- One chip stood for every binding that read as the same key, so they all move to
		-- the new one. Collapsing them costs nothing: they were interchangeable already.
		-- Skip the one the rebind already landed on, or this undoes it and leaves the
		-- action bound to nothing.
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
end

----------------------------------------------------------------
-- Modifiers and key capture
----------------------------------------------------------------

local function rawHasAny(raw)
	return raw ~= nil and raw:find("[Aa][Nn][Yy]%+") ~= nil
end

-- Nothing lets a player choose this, so a rebind infers it: the catalog's alwaysModifier
-- flag first, then whatever the action is bound with today. The engine's own stateful
-- commands (CKeyBindings::statefulCommands - drawinmap, the move* family) carry the flag in
-- the catalog rather than a list here, so one place states it and every surface can read it.
local function actionUsesAny(action, oldRaw)
	if catalogAny[action] then
		return true
	end

	for _, prefix in ipairs(catalogAnyPrefixes) do
		if action:sub(1, #prefix) == prefix then
			return true
		end
	end

	-- Rebinding one keyset keeps that keyset's own qualifier: another keyset of the same
	-- action carrying Any+ says nothing about this one, and inheriting it would silently
	-- drop the modifiers the player just pressed.
	if oldRaw then
		return rawHasAny(oldRaw)
	end

	-- Actions the catalog does not list still reach the editor under Other, so fall back
	-- to what they are bound with today.
	for _, k in ipairs(working.byAction[action] or {}) do
		if rawHasAny(k.raw) then
			return true
		end
	end

	return false
end

-- A press within the timeout extends the sequence; a slower one starts over.
local function appendChain(el)
	local c = capturing
	if not c then
		return
	end

	local now = spGetTimer()
	if #c.elems == 0 then
		c.elems[1] = el
	elseif c.lastPress and spDiffTimers(now, c.lastPress) * 1000 <= c.timeout then
		c.elems[#c.elems + 1] = el
	else
		c.elems = { el }
	end

	c.lastPress = now
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

local function startCapture(action, label, oldRaws)
	-- The grid page rebinds one keyset by name; a row chip hands over every binding it
	-- stands for, the first of which is the one being edited.
	if type(oldRaws) == "string" then
		oldRaws = { oldRaws }
	end
	local oldRaw = oldRaws and oldRaws[1] or nil

	-- Rebinding seeds the modal with the current binding; the first press clears it.
	local pair = catalogShiftPair[action]
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

	capturing = {
		action = action,
		label = label,
		oldRaw = oldRaw,
		oldRaws = oldRaws,
		pair = pair,
		elems = elems,
		pressed = {},
		lastPress = nil,
		-- Matches the engine's KeyChainTimeout default; BAR ships a tighter 333ms.
		timeout = 750,
		any = actionUsesAny(action, oldRaw),
	}
end

local function modPrefix()
	-- An action that ignores modifiers can only ever produce Any+<key>, never a
	-- contradictory Any+Shift+<key>, so held modifiers are dropped outright.
	if capturing and capturing.any then
		return ""
	end

	local alt, ctrl, meta, shift = spGetModKeyState()
	local prefix = ""
	if alt then prefix = prefix .. "Alt+" end
	if ctrl then prefix = prefix .. "Ctrl+" end
	if meta then prefix = prefix .. "Meta+" end
	-- A paired action answers held or not held, so Shift is not a modifier the player picks
	-- for it: holding it must read as the bare key and get its partner written behind.
	if shift and not (capturing and capturing.pair) then
		prefix = prefix .. "Shift+"
	end

	return prefix
end

-- Scancode to keyset symbol, refusing modifier keys so they cannot bind alone.
local function pressSym(scanCode)
	local sym = scanCode and spGetScanSymbol(scanCode)
	if not sym or sym == "" then
		return nil
	end
	if sym:find("ctrl") or sym:find("alt") or sym:find("shift") or sym:find("meta") or sym:find("gui") then
		return nil
	end

	return sym
end

-- Any+ replaces the held modifiers, so toggling the checkbox re-derives each element.
local function elemRaw(e)
	return ((capturing and capturing.any) and "Any+" or e.mods) .. e.sym
end

-- The captured sequence as one engine keyset string.
local function chainRaw()
	local parts = {}
	for i = 1, #capturing.elems do
		parts[i] = elemRaw(capturing.elems[i])
	end

	return table.concat(parts, ",")
end


----------------------------------------------------------------
-- Chip layout and text batching
----------------------------------------------------------------

-- Fits a chip to its box, shrinking to a readable floor before it truncates.
local function chipMetrics(display, fs, pad, rightGap, chipArea)
	local tw = font:GetTextWidth(display) * fs
	if pad + tw + rightGap <= chipArea then
		return display, fs, pad + tw + rightGap
	end

	-- Keep inner positive, since a tiny share can drive it negative and the fit would then
	-- return the string whole instead of truncating.
	local inner = math.max(floor(fs), chipArea - pad - rightGap)
	local chipFs = math.max(floor(fs * 0.75), floor(fs * inner / math.max(1, tw)))
	local disp = text.fit(font, display, inner, chipFs)

	return disp, chipFs, pad + font:GetTextWidth(disp) * chipFs + rightGap
end

-- Chain tokens over two lines at most; the second truncates rather than a third appearing.
local function wrapChainTwoLines(tokens, sep, maxW, fs)
	local line1, i = "", 1
	while i <= #tokens do
		local cand = (line1 == "") and tokens[i] or (line1 .. sep .. tokens[i])
		if line1 ~= "" and font:GetTextWidth(cand) * fs > maxW then
			break
		end
		line1, i = cand, i + 1
	end

	if i > #tokens then
		return { line1 }
	end

	local rest = {}
	for j = i, #tokens do
		rest[#rest + 1] = tokens[j]
	end
	local line2 = table.concat(rest, sep)
	if font:GetTextWidth(line2) * fs > maxW then
		line2 = text.fit(font, line2, maxW, fs)
	end

	return { line1 .. sep, line2 }
end

-- One chip per distinct label rather than per binding. The Any+ qualifier is deliberately
-- never shown, so an action carrying both a plain and an Any+ binding of the same key
-- reads as that key twice; the chip stands for every binding behind it.
local function rowChipGroups(action)
	local cached = chipGroups[action]
	if cached then
		return cached
	end

	local groups, byDisplay = {}, {}
	for _, k in ipairs(working.byAction[action] or {}) do
		local group = byDisplay[k.display]
		if not group then
			group = { display = k.display, raws = {} }
			byDisplay[k.display] = group
			groups[#groups + 1] = group
		end
		group.raws[#group.raws + 1] = k.raw
	end

	chipGroups[action] = groups

	return groups
end

-- Shares a row's width across its chips so every one stays clickable when they overflow.
local function layoutRowChips(action, fs, pad, rightGap, chipArea, gap)
	local groups = rowChipGroups(action)
	local n = #groups
	local mets = {}
	if n == 0 then
		return mets, keyAreaX1
	end

	local total = 0
	for i = 1, n do
		local disp, cfs, w = chipMetrics(groups[i].display, fs, pad, rightGap, chipArea)
		mets[i] = { group = groups[i], disp = disp, fs = cfs, w = w }
		total = total + w + (i > 1 and gap or 0)
	end

	if total > chipArea then
		local share = floor((chipArea - (n - 1) * gap) / n)
		for i = 1, n do
			local disp, cfs, w = chipMetrics(groups[i].display, fs, pad, rightGap, share)
			mets[i] = { group = groups[i], disp = disp, fs = cfs, w = w }
		end
	end

	local cx = keyAreaX1
	for i = 1, n do
		mets[i].x = cx
		mets[i].removeX1 = cx + mets[i].w - rightGap
		cx = cx + mets[i].w + gap
	end

	return mets, cx
end

-- The chip band for a row: where each chip sits, where "+" starts after them, and the widths
-- both callers need. Drawing and hit testing take it from here rather than each deriving the
-- same eight constants, so the click zones cannot drift from what was painted.
local function rowChipBand(action, fs, pad)
	local gap = floor(6 * scale)
	local rightGap = pad + floor(fs * 0.9)
	local addW = floor(fs + pad * 2)
	-- Room reserved on the right so "+" always fits.
	local chipArea = listRight - addW - floor(8 * scale) - keyAreaX1
	local mets, cx = layoutRowChips(action, fs, pad, rightGap, chipArea, gap)

	return mets, cx, addW, rightGap
end

-- Geometry drawn between font:Begin and font:End interleaves with the font's batched
-- glyphs and makes both flicker. The list alternates shapes and text row by row, so it
-- queues here and flushes once all the shapes are down; the modals draw every shape
-- before any text and so print directly. Held flat and refilled in place, since a table
-- per string per frame is hundreds of allocations a second.
local pendingText = {}
local pendingCount = 0

local function queueText(str, x, y, size, opts)
	local at = pendingCount * 5
	pendingText[at + 1] = str
	pendingText[at + 2] = x
	pendingText[at + 3] = y
	pendingText[at + 4] = size
	pendingText[at + 5] = opts
	pendingCount = pendingCount + 1
end

local function flushText()
	if pendingCount == 0 then
		return
	end

	font:Begin()
	for i = 0, pendingCount - 1 do
		local at = i * 5
		font:Print(pendingText[at + 1], pendingText[at + 2], pendingText[at + 3],
			pendingText[at + 4], pendingText[at + 5])
	end
	font:End()

	pendingCount = 0
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

-- Rows are laid out from the top of the list band down, so the column lines up with the
-- keybind rows beside it.
local function categoryRect(i)
	local top = listTop - (i - 1) * rowHeight

	return area.x1, top - rowHeight, area.x1 + sidebarW, top
end

-- The grid menu is 3x4 with row 1 along the bottom, matching the keyboard rows it is
-- bound to (ZXCV under ASDF under QWER) and the order gui_gridmenu draws them in.
local gridRows, gridCols = 3, 4

-- The ids never change, so they are built once rather than concatenated per cell per frame.
local gridKeyActions, gridCategoryActions = {}, {}
for row = 1, gridRows do
	gridKeyActions[row] = {}
	for col = 1, gridCols do
		gridKeyActions[row][col] = "gridmenu_key " .. row .. " " .. col
	end
end
for c = 1, gridCols do
	gridCategoryActions[c] = "gridmenu_category " .. c
end

-- Two grids side by side: the build grid as it opens, and the same grid once a category
-- is picked, which is where Back and Next page live. Sized to roughly what the menu
-- occupies in game - 0.2125 of screen width over four columns - rather than stretched.
local function gridGeometry()
	local headH = rowHeight
	local top = listTop - headH - floor(8 * scale)
	local bottom = listBottom() + floor(8 * scale)
	local strip = floor(rowHeight * 1.2)
	local gap = floor(4 * scale)
	local blockGap = floor(28 * scale)

	local availH = (top - bottom) - (strip + gap) * 2
	local availW = (listRight - listX1) - blockGap
	local cell = math.min(floor(availH / gridRows), floor(availW / (gridCols * 2)), floor(100 * scale))
	if cell < 1 then
		cell = 1
	end

	local blockW = cell * gridCols
	local blockH = cell * gridRows + (strip + gap) * 2
	-- Pinned to the top left of the list band, like the rows it replaces, rather than
	-- floating in the middle of it.
	local x1 = listX1
	local stripY = top - blockH
	local gridBottom = stripY + strip + gap

	return x1, x1 + blockW + blockGap, gridBottom, cell, strip, gap, stripY,
		gridBottom + cell * gridRows + gap, headH
end

-- Cell rect for a grid position. Row 1 is the bottom row, so it is laid out upward.
local function gridCellRect(row, col, x1, gridBottom, cell)
	local cx = x1 + (col - 1) * cell
	local cy = gridBottom + (row - 1) * cell

	return cx, cy, cx + cell, cy + cell
end

local function drawButtonFace(r, base)
	local cs = floor(4 * scale)
	RectRound(r[1], r[2], r[3], r[4], cs, 1, 1, 1, 1, base, base)
	RectRound(r[1], r[2], r[3], (r[2] + r[4]) * 0.5, cs, 0, 0, 1, 1,
		sheenTop, sheenNone)
end

local function drawSidebar(mx, my, fs, pad)
	queueText(colorText .. L.title, area.x1 + pad, area.y2 - floor(17 * scale),
		floor(rowHeight * 0.85), "ov")

	for i, c in ipairs(categories) do
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 >= listBottom() then
			local selected = selectedCategory == c.key
			if selected then
				RectRound(x1, y1, x2, y2, floor(3 * scale), 1, 1, 1, 1, { 1, 1, 1, 0.13 }, { 1, 1, 1, 0.13 })
			elseif mx >= x1 and mx <= x2 and my > y1 and my <= y2 then
				RectRound(x1, y1, x2, y2, floor(3 * scale), 1, 1, 1, 1, rowWash, rowWash)
			end
			-- Falls back when the catalog was rebuilt since the last layout pass.
			queueText((selected and colorAction or colorDim) .. (c.fitted or c.label),
				x1 + pad, (y1 + y2) * 0.5, fs, "ov")
		end
	end
end

-- Label left, key right, sized like a category button. Used for every pill in this view.
local function drawGridPill(x1, y1, x2, y2, label, key, fs, pad, cs, mx, my, dim)
	local fill = pillFill
	RectRound(x1, y1, x2, y2, cs, 1, 1, 1, 1, fill, fill)
	if not dim and isInRect(mx, my, x1, y1, x2, y2) then
		RectRound(x1, y1, x2, y2, cs, 1, 1, 1, 1, hoverWash, hoverWash)
	end
	-- Key is right aligned and gets only the width it needs, so the label keeps the rest
	-- and stays readable.
	local keyW = floor(font:GetTextWidth(key) * fs)
	queueText((dim and colorDim or colorAction) .. text.fit(font, label, (x2 - x1) - keyW - pad * 5, fs),
		x1 + pad * 2, (y1 + y2) * 0.5, fs, "ov")
	queueText((dim and colorDim or colorKey) .. key, x2 - pad * 2, (y1 + y2) * 0.5, fs, "rov")
end

-- The raw keyset a grid action carries, for seeding a rebind. nil when it has none.
local function gridKeyRaw(action)
	local ks = working.byAction[action]

	return ks and ks[1] and ks[1].raw or nil
end

-- The key a grid action currently carries, blank when it has none.
local function gridKeyText(action)
	local ks = working.byAction[action]

	return ks and ks[1] and ks[1].display or ""
end

-- Sized to its own label and key, so a longer translation widens it rather than being
-- clipped.
local function gridCycleRect(x1, bsize)
	local fs = floor(bsize * 0.45)
	local pad = floor(3 * scale)
	-- Inset to match the cells below, which sit a pad in from the block edge.
	local cx1 = x1 + pad
	local need = floor((font:GetTextWidth(gridGroup.cycleLabel)
		+ font:GetTextWidth(gridKeyText("gridmenu_cycle_builder"))) * fs) + pad * 10

	return cx1, cx1 + math.max(need, floor(bsize * 2))
end

-- Draws the grid menu as it sits on screen. Cells stay empty: what fills them in game
-- comes from the selected builder, which the editor has no notion of.
local function drawGridMenu(mx, my)
	local x1, x2, gridBottom, cell, strip, gap, stripY, builderY, headH = gridGeometry()
	local pad = floor(3 * scale)
	local cs = floor(3 * scale)
	local keyFs = floor(cell * 0.2)
	local stripFs = floor(strip * 0.45)
	-- Solid enough to read against the panel on its own, so the cells need no container
	-- or outline behind them.
	local fill = pillFill

	-- Same header the list puts above a category, so the two views read alike.
	RectRound(listX1, listTop - headH, listRight, listTop, 0, 0, 0, 0, 0,
		sheenTop, sheenTop)
	queueText(colorHeader .. gridGroup.title, listX1 + floor(6 * scale), listTop - headH * 0.5,
		floor(rowHeight * 0.55) * 0.95, "ov")

	for pass = 1, 2 do
		local gx = (pass == 1) and x1 or x2
		for row = 1, gridRows do
			for col = 1, gridCols do
				local cx1, cy1, cx2, cy2 = gridCellRect(row, col, gx, gridBottom, cell)
				RectRound(cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad, cs, 1, 1, 1, 1, fill, fill)
				-- Only the first grid carries the build keys; the second is the category view,
				-- whose cells hold the same bindings and would just repeat them.
				if gx == x1 then
					if isInRect(mx, my, cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad) then
						RectRound(cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad, cs, 1, 1, 1, 1,
							hoverWash, hoverWash)
					end
					queueText(colorKey .. gridKeyText(gridKeyActions[row][col]),
						cx2 - pad * 3, cy2 - pad * 2 - keyFs, keyFs, "ro")
				end
			end
		end
	end

	for c = 1, gridCols do
		local cx1 = x1 + (c - 1) * cell
		drawGridPill(cx1 + pad, stripY, cx1 + cell - pad, stripY + strip,
			gridGroup.categoryLabels[c] or "", gridKeyText(gridCategoryActions[c]),
			stripFs, pad, cs, mx, my)
	end

	-- Second grid is the view after a category is picked: Back on the left, Next page on
	-- the right, matching how gui_gridmenu splits that strip into thirds.
	local third = floor(cell * gridCols / 3)
	drawGridPill(x2 + pad, stripY, x2 + third, stripY + strip,
		L.gridBack, keybindModel.displayKeyset("shift", working.layout), stripFs, pad, cs, mx, my, true)
	drawGridPill(x2 + gridCols * cell - third, stripY, x2 + gridCols * cell - pad, stripY + strip,
		L.gridNextPage, gridKeyText("gridmenu_next_page"), stripFs, pad, cs, mx, my)

	local ccx1, ccx2 = gridCycleRect(x1, strip)
	drawGridPill(ccx1, builderY, ccx2, builderY + strip, gridGroup.cycleLabel,
		gridKeyText("gridmenu_cycle_builder"), stripFs, pad, cs, mx, my)
end

-- Routes a click in the grid view to the action that cell or button binds. Back is left
-- out on purpose: gui_gridmenu hardcodes its key, so there is nothing to rebind.
local function gridPress(x, y)
	local x1, x2, gridBottom, cell, strip, gap, stripY, builderY = gridGeometry()

	for row = 1, gridRows do
		for col = 1, gridCols do
			local cx1, cy1, cx2, cy2 = gridCellRect(row, col, x1, gridBottom, cell)
			if isInRect(x, y, cx1, cy1, cx2, cy2) then
				local action = gridKeyActions[row][col]
				startCapture(action, gridGroup.cellLabel(row, col), gridKeyRaw(action))

				return true
			end
		end
	end

	if y >= stripY and y <= stripY + strip then
		for c = 1, gridCols do
			local cx1 = x1 + (c - 1) * cell
			if x >= cx1 and x <= cx1 + cell then
				local action = gridCategoryActions[c]
				startCapture(action, gridGroup.categoryLabels[c], gridKeyRaw(action))

				return true
			end
		end

		local third = floor(cell * gridCols / 3)
		if x >= x2 + gridCols * cell - third and x <= x2 + gridCols * cell - floor(3 * scale) then
			startCapture("gridmenu_next_page", L.gridNextPage, gridKeyRaw("gridmenu_next_page"))

			return true
		end
	end

	local ccx1, ccx2 = gridCycleRect(x1, strip)
	if isInRect(x, y, ccx1, builderY, ccx2, builderY + strip) then
		startCapture("gridmenu_cycle_builder", gridGroup.cycleLabel,
			gridKeyRaw("gridmenu_cycle_builder"))

		return true
	end

	return true
end

local function drawRow(row, top, bottom, mx, my, fs, pad)
	local cyc = (top + bottom) * 0.5

	if row.type == "header" then
		RectRound(listX1, bottom, listRight, top, 0, 0, 0, 0, 0, sheenTop, sheenTop)
		queueText(colorHeader .. row.text, listX1 + pad, cyc, fs * 0.95, "ov")
		return
	end

	-- Half-open on the shared edge rather than isInRect's closed test: rows stack, so one
	-- row's top is the next one's bottom and a closed test highlights both.
	local hovered = mx >= listX1 and mx <= listRight and my <= top and my > bottom
	if hovered then
		RectRound(listX1, bottom, listRight, top, 0, 0, 0, 0, 0, rowWash, rowWash)
	end

	-- Indented and followed by an arrow, to read as a way through rather than a binding.
	if row.type == "link" then
		local lx = listX1 + pad * 5
		queueText(colorAction .. row.label, lx, cyc, fs, "ov")
		queueText(colorKey .. string.char(226, 128, 186),
			lx + floor(font:GetTextWidth(row.label) * fs) + pad * 2, cyc, fs, "ov")
		return
	end

	queueText(colorAction .. text.fit(font, row.label, keyAreaX1 - (listX1 + pad) - pad, fs), listX1 + pad, cyc, fs, "ov")

	if row.type == "info" then
		queueText(colorDim .. row.keyText, keyAreaX1, cyc, fs, "ov")
		return
	end


	local c1, c2 = bottom + floor(3 * scale), top - floor(3 * scale)
	local mets, cx, addW, rightGap = rowChipBand(row.action, fs, pad)
	for _, m in ipairs(mets) do
		local overRemove = isInRect(mx, my, m.removeX1, c1, m.x + m.w, c2)
		local overBody = mx >= m.x and mx < m.removeX1 and my >= c1 and my <= c2
		RectRound(m.x, c1, m.x + m.w, c2, floor(3 * scale), 1, 1, 1, 1, { 0, 0, 0, overBody and 0.45 or 0.35 })
		queueText((overBody and colorText or colorKey) .. m.disp, m.x + pad, cyc, m.fs, "ov")
		queueText((overRemove and colorDanger or colorDim) .. "x", m.removeX1 + rightGap * 0.5, cyc, fs, "cov")
	end

	local overAdd = isInRect(mx, my, cx, c1, cx + addW, c2)
	RectRound(cx, c1, cx + addW, c2, floor(3 * scale), 1, 1, 1, 1, { 0.2, 0.45, 0.25, overAdd and 0.55 or 0.4 })
	queueText(colorText .. "+", (cx + cx + addW) * 0.5, cyc, fs, "cov")
end

-- Split out of view.draw: each modal is self-contained, and one function holding every
-- draw path ran past the 60-upvalue ceiling.
local function drawCaptureModal(mx, my)
	local bx1, by1, bx2, by2, ok, cancel = captureGeometry()
	local cs = floor(6 * scale)
	local cx = (bx1 + bx2) * 0.5

	RectRound(area.x1, area.y1, area.x2, area.y2, 0, 0, 0, 0, 0, { 0, 0, 0, 0.55 })
	UiElement(bx1, by1, bx2, by2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	drawButtonFace(cancel, buttonFill)
	drawButtonFace(ok, buttonFill)
	if isInRect(mx, my, cancel[1], cancel[2], cancel[3], cancel[4]) then
		Highlight(cancel[1], cancel[2], cancel[3], cancel[4], cs, hoverOpacity, { 1, 1, 1 })
	end
	if isInRect(mx, my, ok[1], ok[2], ok[3], ok[4]) then
		Highlight(ok[1], ok[2], ok[3], ok[4], cs, hoverOpacity, { 1, 1, 1 })
	end

	local tfs = floor(rowHeight * 0.6)
	local sfs = floor(rowHeight * 0.5)
	local bigfs = floor(rowHeight * 0.95)
	local hasChain = #capturing.elems > 0
	-- Preview held modifiers only while forming the first element, through the same
	-- formatter a finished keyset uses so the two do not render differently.
	local heldRaw = modPrefix()
	local held = heldRaw ~= "" and keybindModel.displayKeyset(heldRaw, working.layout) or ""
	local chainStr
	if hasChain then
		chainStr = keybindModel.displayKeyset(chainRaw(), working.layout)
	elseif held ~= "" then
		chainStr = held .. "_"
	else
		chainStr = L.pressKey
	end
	local hasContent = hasChain or held ~= ""

	-- Shrink toward a readable floor, then wrap to a second line, then ellipsize.
	local chainMaxW = (bx2 - bx1) - floor(32 * scale)
	local minFs = floor(rowHeight * 0.5)
	local chainLines, chainFs = { chainStr }, bigfs
	if hasChain then
		local naturalW = font:GetTextWidth(chainStr) * bigfs
		if naturalW <= chainMaxW then
			chainLines, chainFs = { chainStr }, bigfs
		elseif floor(bigfs * chainMaxW / naturalW) >= minFs then
			chainLines, chainFs = { chainStr }, floor(bigfs * chainMaxW / naturalW)
		else
			local tokens = {}
			for _, e in ipairs(capturing.elems) do
				tokens[#tokens + 1] = keybindModel.displayKeyset(elemRaw(e), working.layout)
			end
			chainLines, chainFs = wrapChainTwoLines(tokens, keybindModel.chainSep, chainMaxW, minFs), minFs
		end
	else
		local w = font:GetTextWidth(chainStr) * bigfs
		if w > chainMaxW then
			chainFs = math.max(minFs, floor(bigfs * chainMaxW / w))
		end
	end

	-- Bar draining over the chain window: time left to extend before it resets. The
	-- track is always drawn so the modal does not gain a row the moment a key lands.
	local barW = floor((bx2 - bx1) * 0.5)
	local barX = cx - barW * 0.5
	local barY = by1 + floor(88 * scale)
	local barH = floor(4 * scale)
	RectRound(barX, barY, barX + barW, barY + barH, floor(2 * scale), 1, 1, 1, 1, { 1, 1, 1, 0.1 })
	if hasChain and capturing.lastPress then
		local frac = 1 - (spDiffTimers(spGetTimer(), capturing.lastPress) * 1000) / capturing.timeout
		if frac < 0 then frac = 0 end
		if frac > 0 then
			RectRound(barX, barY, barX + floor(barW * frac), barY + barH, floor(2 * scale), 1, 1, 1, 1, { 0.9, 0.7, 0.2, 0.9 })
		end
	end

	local chainCy = by1 + floor(122 * scale)
	local lineStep = floor(chainFs * 1.15)

	font:Begin()
	font:Print(colorText .. text.fit(font, capturing.label or capturing.action, chainMaxW, tfs), cx, by2 - floor(26 * scale), tfs, "cov")
	for li = 1, #chainLines do
		local ly = chainCy + (#chainLines - 1) * lineStep * 0.5 - (li - 1) * lineStep
		font:Print((hasContent and colorKey or colorDim) .. chainLines[li], cx, ly, chainFs, "cov")
	end
	font:Print(colorText .. L.cancel, (cancel[1] + cancel[3]) * 0.5, (cancel[2] + cancel[4]) * 0.5, sfs, "cov")
	font:Print((hasChain and colorText or colorDim) .. L.accept, (ok[1] + ok[3]) * 0.5, (ok[2] + ok[4]) * 0.5, sfs, "cov")
	font:End()
end

local function drawProfileDialog(mx, my)
	local bx1, by1, bx2, by2, ok, cancel, field, discard, messageLines, messageStep = dialogGeometry()
	local cs = floor(6 * scale)
	local cx = (bx1 + bx2) * 0.5
	local tfs = floor(rowHeight * 0.6)
	local sfs = floor(rowHeight * 0.5)

	RectRound(area.x1, area.y1, area.x2, area.y2, 0, 0, 0, 0, 0, { 0, 0, 0, 0.55 })
	UiElement(bx1, by1, bx2, by2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	-- Anything whose accept saves is green, anything destructive is red, wherever it
	-- appears; a tinted button brightens on hover instead of taking the white overlay.
	local acceptSaves = dialog.save or (not dialog.message and not dialog.danger)
	local buttons = {
		{ r = cancel },
		{ r = ok, danger = dialog.danger, confirm = acceptSaves },
	}
	if dialog.middle then
		buttons[#buttons + 1] = { r = discard, danger = dialog.middle.danger }
	end
	for _, b in ipairs(buttons) do
		local r = b.r
		local hovered = isInRect(mx, my, r[1], r[2], r[3], r[4])
		local base = (b.danger and dangerFill) or (b.confirm and confirmFill)
		local lift = (b.danger and dangerFillHover) or (b.confirm and confirmFillHover)
		local fill = base and (hovered and lift or base)
		drawButtonFace(r, fill or buttonFill)
		if not fill and hovered then
			Highlight(r[1], r[2], r[3], r[4], cs, hoverOpacity, { 1, 1, 1 })
		end
	end

	font:Begin()
	font:Print(colorText .. text.fit(font, dialog.title, bx2 - bx1 - floor(32 * scale), tfs), cx, by2 - floor(26 * scale), tfs, "cov")
	if dialog.middle then
		font:Print(colorText .. dialog.middle.label,
			(discard[1] + discard[3]) * 0.5, (discard[2] + discard[4]) * 0.5, sfs, "cov")
	end
	if messageLines then
		local top = (field[2] + field[4]) * 0.5 + (#messageLines - 1) * messageStep * 0.5
		for i = 1, #messageLines do
			font:Print(colorDim .. text.fit(font, messageLines[i], bx2 - bx1 - floor(32 * scale), sfs),
				cx, top - (i - 1) * messageStep, sfs, "cov")
		end
	end
	font:Print(colorText .. L.cancel, (cancel[1] + cancel[3]) * 0.5, (cancel[2] + cancel[4]) * 0.5, sfs, "cov")
	font:Print(colorText .. acceptLabelFor(dialog),
		(ok[1] + ok[3]) * 0.5, (ok[2] + ok[4]) * 0.5, sfs, "cov")
	font:End()

	if not dialog.message then
		nameBox:setRect(field[1], field[2], field[3], field[4], sfs)
		nameBox:draw()
	end
end

-- Paints the whole panel. Immediate mode, so this runs every frame.
function view.draw()
	if not font then view.init() end
	if not working then view.refresh() end
	if layoutPending then layoutHeader() end

	-- Pinned rather than assumed: widgets on lower layers draw first and leave blending,
	-- colour and depth wherever they finished, which changes how everything below
	-- composites from one frame to the next.
	glTexture(false)
	glColor(1, 1, 1, 1)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(false)

	local rawMx, rawMy, lmb = spGetMouseState()
	if dragging then
		if lmb then scrollFromY(rawMy) else dragging = false end
	end

	-- Prevent the hover over preset options and modals from also being detected by the
	-- regular rows, sidebar and buttons sitting underneath them.
	local mx, my = rawMx, rawMy
	if dialog or capturing or presetDropdown:isOpen() then
		mx, my = -1, -1
	end

	local rowCount = visibleRows()
	local fs = rowHeight * 0.55
	local pad = floor(6 * scale)
	local lb = listBottom()

	drawSidebar(mx, my, fs, pad)

	if gridGroup then
		drawGridMenu(mx, my)
		flushText()
	else
		for r = 1, rowCount do
			local row = rows[scroll + r]
			if not row then break end
			local top = listTop - (r - 1) * rowHeight
			drawRow(row, top, top - rowHeight, mx, my, fs, pad)
		end
		flushText()

		Scroller(barX1, lb, area.x2, listTop, #rows * rowHeight, scroll * rowHeight)
	end

	searchBox:draw()

	local bfs = floor(rowHeight * 0.55)
	for _, set in ipairs(buttonSets) do
		for _, b in ipairs(set) do
			local r = b.rect
			if r then
				local enabled = buttonEnabled(b.id)
				local hovered = enabled and isInRect(mx, my, r[1], r[2], r[3], r[4])
				-- A tinted button loses its colour under the usual white hover overlay, so it
				-- brightens its own fill instead.
				local fill = b.fill and ((not enabled and b.fillMuted) or (hovered and b.fillHover) or b.fill)
				-- Drawn here rather than through Draw.Button: that caches each distinct button
				-- into a display list compiled mid-frame on a budget, and the immediate and
				-- replayed forms do not match, so a button sized to its own label visibly
				-- alternates between them.
				drawButtonFace(r, fill or buttonFill)

				if b.icon then
					-- Square inset so the 64x64 art keeps its aspect inside a wider button.
					-- Hover only lifts the tint, matching the search box and picker, which
					-- carry no hover treatment of their own.
					local inset = floor((r[4] - r[2]) * 0.22)
					local side = (r[4] - r[2]) - inset * 2
					local ix = floor((r[1] + r[3] - side) * 0.5)
					local iy = r[2] + inset
					local shade = (not enabled and 0.4) or (hovered and 1 or 0.82)
					-- Set explicitly: the icons are white-on-transparent, and whatever drew
					-- before could leave a blend mode that renders them as solid squares.
					glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
					glColor(shade, shade, shade, 1)
					glTexture(b.icon)
					glTexRect(ix, iy, ix + side, iy + side)
					glTexture(false)
					glColor(1, 1, 1, 1)
				else
					if hovered and not fill then
						Highlight(r[1], r[2], r[3], r[4], floor(6 * scale), hoverOpacity, { 1, 1, 1 })
					end
					queueText((enabled and colorText or colorDim) .. text.fit(font, L[b.id], r[3] - r[1] - pad * 2, bfs),
						(r[1] + r[3]) * 0.5, (r[2] + r[4]) * 0.5, bfs, "cov")
				end
			end
		end
	end
	flushText()

	-- Registered every frame because the rects move with the panel; the tooltip widget
	-- owns the hover delay and only draws once the cursor settles.
	if WG['tooltip'] then
		for _, b in ipairs(headerButtons) do
			if b.rect then
				WG['tooltip'].AddTooltip('keybind_' .. b.id, b.rect, L[b.id])
			end
		end
	end

	presetDropdown:draw()

	-- Real cursor: these are the overlay, so the hover is theirs to detect.
	if capturing then
		drawCaptureModal(rawMx, rawMy)
	end

	if dialog then
		drawProfileDialog(rawMx, rawMy)
	end
end

scrollFromY = function(y)
	local lb = listBottom()
	local f = (listTop - y) / math.max(1, listTop - lb)
	if f < 0 then f = 0 elseif f > 1 then f = 1 end
	scroll = floor(f * maxScroll() + 0.5)
	clampScroll()
end

----------------------------------------------------------------
-- Input
----------------------------------------------------------------

-- Scrolls the list; a modal swallows the wheel instead.
function view.mouseWheel(up, value)
	if dialog or capturing or gridGroup then
		return
	end

	local _, my = spGetMouseState()
	if my >= listBottom() and my <= listTop then
		scroll = scroll + (up and -3 or 3)
		clampScroll()
	end
end

-- Which zone of an editable row a click hit; mirrors drawRow's chip layout exactly.
local function hitTestRow(rowAction, x)
	local mets, cx, addW = rowChipBand(rowAction, rowHeight * 0.55, floor(6 * scale))
	for _, m in ipairs(mets) do
		if x >= m.x and x < m.removeX1 then
			return "rebind", m.group.raws
		elseif x >= m.removeX1 and x <= m.x + m.w then
			return "remove", m.group.raws
		end
	end

	if x >= cx and x <= cx + addW then
		return "add"
	end
end

-- Returns true when the click landed in the column, selected or not, so it never falls
-- through to the list behind it.
local function sidebarPress(x, y)
	if x < area.x1 or x > area.x1 + sidebarW or y < listBottom() or y > listTop then
		return false
	end

	for i, c in ipairs(categories) do
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 >= listBottom() and x >= x1 and x <= x2 and y > y1 and y <= y2 then
			if selectedCategory ~= c.key then
				selectedCategory = c.key
				scroll = 0
				rebuildRows()
			end

			return true
		end
	end

	return true
end

-- Routes a click on a keybind row to the edit it implies.
local function handleZone(kind, action, label, raws)
	if kind == "remove" then
		for _, raw in ipairs(raws) do
			removeKeyset(action, raw)
		end
	elseif kind == "add" then
		startCapture(action, label)
	elseif kind == "rebind" then
		startCapture(action, label, raws)
	end
end

-- Routes a click to whichever layer is on top: modal, dropdown, sidebar, then the list.
function view.mousePress(x, y, button)
	if not isInRect(x, y, area.x1, area.y1, area.x2, area.y2) then
		return false
	end

	if dialog then
		if button == 1 then
			local bx1, by1, bx2, by2, ok, cancel, field, discard = dialogGeometry()
			if isInRect(x, y, ok[1], ok[2], ok[3], ok[4]) then
				acceptDialog()
			elseif dialog.middle and isInRect(x, y, discard[1], discard[2], discard[3], discard[4]) then
				middleDialog()
			elseif (isInRect(x, y, cancel[1], cancel[2], cancel[3], cancel[4]))
				or x < bx1 or x > bx2 or y < by1 or y > by2 then
				cancelDialog()
			elseif not dialog.message then
				nameBox:mousePress(x, y)
			end
		end

		return true
	end

	-- In the modal, mouse1 drives its controls; only side buttons (mouse4+) bind.
	if capturing then
		local bx1, by1, bx2, by2, ok, cancel = captureGeometry()
		if button == 1 then
			if isInRect(x, y, ok[1], ok[2], ok[3], ok[4]) then
				if #capturing.elems > 0 then
					commitCapture(chainRaw())
				else
					capturing = nil
				end
			elseif (isInRect(x, y, cancel[1], cancel[2], cancel[3], cancel[4]))
				or x < bx1 or x > bx2 or y < by1 or y > by2 then
				capturing = nil
			end
		elseif button >= 4 then
			appendChain({ sym = "mouse" .. button, mods = modPrefix() })
		end
		return true
	end

	if button ~= 1 then
		return true
	end

	-- The open list draws over the header and footer, so it gets the click before they do.
	-- Closed, this only claims its own toggle and everything below still sees the press.
	local ddWasOpen = presetDropdown:isOpen()
	if presetDropdown:mousePress(x, y) then
		searchBox:blur()
		capturing = nil

		return true
	end
	if ddWasOpen then
		return true
	end

	for _, set in ipairs(buttonSets) do
		for _, b in ipairs(set) do
			local r = b.rect
			if r and isInRect(x, y, r[1], r[2], r[3], r[4]) then
				searchBox:blur()
				presetDropdown:close()
				if buttonEnabled(b.id) then
					if b.id == "save" then
						startSave()
					elseif b.id == "reset" then
						startReset()
					elseif b.id == "duplicate" then
						startDuplicate()
					elseif b.id == "edit" then
						startEdit()
					end
				end

				return true
			end
		end
	end

	if searchBox:mousePress(x, y) then
		capturing = nil
		return true
	end
	searchBox:blur()

	if sidebarPress(x, y) then
		return true
	end

	if not gridGroup and isInRect(x, y, barX1, listBottom(), area.x2, listTop) then
		dragging = true
		scrollFromY(y)
		return true
	end

	if gridGroup and isInRect(x, y, listX1, listBottom(), area.x2, listTop) then
		return gridPress(x, y)
	end

	if isInRect(x, y, listX1, listBottom(), listRight, listTop) then
		-- The band can end in a partial row that draw never paints, so clamp to the
		-- painted count or a click in that strip would edit an unseen row.
		local r = floor((listTop - y) / rowHeight) + 1
		local row = r <= visibleRows() and rows[scroll + r] or nil
		if row and row.type == "editable" then
			local kind, raw = hitTestRow(row.action, x)
			if kind then
				handleZone(kind, row.action, row.label, raw)
			end
		elseif row and row.type == "link" then
			selectedCategory = row.category
			scroll = 0
			rebuildRows()
		end
		return true
	end

	return true
end

function view.textInput(char)
	if dialog then
		return not dialog.message and nameBox:textInput(char)
	end
	if searchBox and searchBox:isFocused() then
		return searchBox:textInput(char)
	end

	return false
end

-- Keys, offered to the modal, the capture, the dropdown and the search box in that order.
function view.keyPress(key, scanCode)
	if dialog then
		if key == KEYSYMS.ESCAPE then
			cancelDialog()
		elseif key == KEYSYMS.RETURN then
			acceptDialog()
		elseif not dialog.message then
			-- Focus is dropped by the editbox on Escape/Return, which are handled above.
			nameBox:keyPress(key)
		end

		return true
	end

	if capturing then
		if key == 27 then
			capturing = nil
		else
			-- Skip auto-repeat; only the initial press adds an element (release clears pressed).
			local sym = pressSym(scanCode)
			if sym and not capturing.pressed[scanCode] then
				capturing.pressed[scanCode] = true
				appendChain({ sym = sym, mods = modPrefix() })
			end
		end
		return true
	end

	if presetDropdown and presetDropdown:isOpen() then
		if key == 27 then presetDropdown:close() end
		return true
	end

	if searchBox and searchBox:isFocused() then
		return searchBox:keyPress(key)
	end

	return false
end

-- Only a capture cares about releases, to know a held key has gone.
function view.keyRelease(key, scanCode)
	if capturing then
		capturing.pressed[scanCode] = nil
	end
end

return view
