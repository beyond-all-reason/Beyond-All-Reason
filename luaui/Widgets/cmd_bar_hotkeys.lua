local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "BAR Hotkeys",
		desc = "Enables BAR Hotkeys" ,
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU GPL, v2 or later",
		layer = -99999, -- run before gui_options, so that we can appropriately transform stuff here when keybind changes happen
		enabled = true,
	}
end


-- Localized Spring API for performance
local spEcho = Spring.Echo

local profiles = VFS.Include("luaui/Include/keybind_profiles.lua")


local function reloadWidgetsBindings()
	local reloadableWidgets = {'buildmenu', 'ordermenu', 'keybinds', 'cmd_blueprint'}

	for _, w in pairs(reloadableWidgets) do
		if WG[w] and WG[w].reloadBindings then
			WG[w].reloadBindings()
		end
	end
end


-- Nothing to load, so write the active profile out and point the config at it. This
-- is also the upgrade path once the shipped preset files stop being installed.
local function fallbackToProfile(missing)
	spEcho("BAR Hotkeys: Did not find keybindings file " .. missing .. ". Writing the active profile")

	local file = profiles.materialize(profiles.activeName())
	if file then
		Spring.SetConfigString("KeybindingFile", file)
	end

	return file
end


local function reloadBindings()
	-- Still read from config rather than the store: on the launch a player is
	-- migrated this is what they were on, and the store snapshots the live keymap.
	local file = Spring.GetConfigString("KeybindingFile", profiles.activeFile)

	if not VFS.FileExists(file) then
		file = fallbackToProfile(file)
	end

	if file then
		Spring.SendCommands("keyreload " .. file)
		spEcho("BAR Hotkeys: Loaded hotkeys from " .. file)
	else
		spEcho("BAR Hotkeys: No hotkey file found")
	end

	reloadWidgetsBindings()
end


-- Anyone who was editing uikeys.txt by hand keeps what they wrote: it becomes a profile of
-- theirs before the editor gets a chance to write over it. Materializing hands the file back
-- to us, so the next launch finds one that matches and leaves it alone.
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


function widget:Initialize()
	adoptEditedKeymap()
	reloadBindings()

	WG['bar_hotkeys'] = {}
	WG['bar_hotkeys'].reloadBindings = reloadBindings
end

function widget:Shutdown()
	Spring.SendCommands("keyreload")
	reloadWidgetsBindings()
end
