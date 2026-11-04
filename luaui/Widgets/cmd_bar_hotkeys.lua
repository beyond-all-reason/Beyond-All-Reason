local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "BAR Hotkeys",
		desc = "Enables BAR Hotkeys",
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU GPL, v2 or later",
		layer = -99999, -- run before gui_options, so that we can appropriately transform stuff here when keybind changes happen
		enabled = true,
	}
end

-- Localized Spring API for performance
local spEcho = Spring.Echo

local WidgetActions = require("luaui/Include/keybind_widget_actions")
local profiles = require("luaui/Include/keybind_profiles")

local manifestsVersion, defaultsSignature

local function reloadWidgetsBindings()
	local reloadableWidgets = { "buildmenu", "ordermenu", "keybinds", "cmd_blueprint" }

	for _, w in pairs(reloadableWidgets) do
		if WG[w] and WG[w].reloadBindings then
			WG[w].reloadBindings()
		end
	end
end

-- Also the upgrade path once the shipped preset files stop being installed.
local function fallbackToProfile(missing)
	spEcho("BAR Hotkeys: Did not find keybindings file " .. missing .. ". Writing the active profile")

	local file = profiles.materialize(profiles.activeName())
	if file then
		Spring.SetConfigString("KeybindingFile", file)
	end

	return file
end

local function reloadBindings()
	-- The editor holds a store of its own, so the selection this one last read may be stale.
	profiles.invalidate()

	-- Still read from config rather than the store: on the launch a player is migrated this is
	-- what they were on.
	local file = Spring.GetConfigString("KeybindingFile", profiles.activeFile)

	if not VFS.FileExists(file) then
		file = fallbackToProfile(file)
	end

	if file then
		Spring.SendCommands("keyreload " .. file)
		-- A KeybindingFile the player pointed elsewhere is named on its own rather than credited to
		-- whatever the store has selected.
		local name = file == profiles.activeFile and profiles.activeName()
		if name then
			spEcho("BAR Hotkeys: Loaded profile '" .. name .. "' from " .. file)
		else
			spEcho("BAR Hotkeys: Loaded hotkeys from " .. file)
		end
	else
		spEcho("BAR Hotkeys: No hotkey file found")
	end

	reloadWidgetsBindings()
end

-- A hand-edited uikeys.txt becomes a profile of theirs before the editor writes over it.
local function adoptEditedKeymap()
	local name = profiles.adoptEditedKeymap()
	if not name then
		return
	end

	spEcho("BAR Hotkeys: " .. profiles.activeFile .. " was edited outside the keybind editor; kept as profile " .. name)

	local file = profiles.materialize(name)
	if file then
		Spring.SetConfigString("KeybindingFile", file)
	end
end

local function widgetDefaultsSignature()
	local parts = {}
	for i, default in ipairs(WidgetActions.defaults((WidgetActions.manifests()))) do
		parts[i] = default.action .. "=" .. table.concat(default.keysets, ",")
	end

	return table.concat(parts, ";")
end

-- Held while the editor has edits staged: a reload would reseed it over them, and saving applies the defaults.
function widget:Update()
	local _, version = WidgetActions.manifests()
	if version == manifestsVersion then
		return
	end
	if WG.keybinds and WG.keybinds.hasStagedEdits and WG.keybinds.hasStagedEdits() then
		return
	end
	manifestsVersion = version

	local signature = widgetDefaultsSignature()
	if signature == defaultsSignature then
		return
	end
	defaultsSignature = signature

	if Spring.GetConfigString("KeybindingFile", profiles.activeFile) ~= profiles.activeFile then
		return
	end
	-- The editor writes the store from a copy of its own.
	profiles.invalidate()
	if profiles.materialize(profiles.activeName()) then
		reloadBindings()
	end
end

function widget:Initialize()
	adoptEditedKeymap()
	reloadBindings()
	manifestsVersion = select(2, WidgetActions.manifests())
	defaultsSignature = widgetDefaultsSignature()

	WG.bar_hotkeys = {}
	WG.bar_hotkeys.reloadBindings = reloadBindings
end

function widget:Shutdown()
	Spring.SendCommands("keyreload")
	reloadWidgetsBindings()
end
