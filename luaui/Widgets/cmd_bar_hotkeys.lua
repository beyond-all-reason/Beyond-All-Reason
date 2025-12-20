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

local currentLayout
local currentKeybindingsFile
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")


local function reloadWidgetsBindings()
	local reloadableWidgets = {'buildmenu', 'ordermenu', 'keybinds', 'cmd_blueprint'}

	for _, w in pairs(reloadableWidgets) do
		if WG[w] and WG[w].reloadBindings then
			WG[w].reloadBindings()
		end
	end
end


local function replaceDefaultWithLegacy(file)
	if file == 'luaui/configs/hotkeys/default_keys.txt' then
		return 'luaui/configs/hotkeys/legacy_keys.txt'
	end
	if file == 'luaui/configs/hotkeys/default_keys_60pct.txt' then
		return 'luaui/configs/hotkeys/legacy_keys_60pct.txt'
	end
end


-- if keybinds are missing, load default hotkeys
local function fallbackToDefault(currentKeys)
	local default = keyConfig.keybindingLayoutFiles[1]
	spEcho("BAR Hotkeys: Did not find keybindings file " .. currentKeys ..". Loading grid keys")
	Spring.SendCommands("keyreload " .. default)
	return default
end


local function reloadBindings()
	-- Second parameter here is just a fallback if this config is undefined
	currentLayout = Spring.GetConfigString("KeyboardLayout", 'qwerty')

	currentKeybindingsFile = Spring.GetConfigString("KeybindingFile", keyConfig.keybindingLayoutFiles[1])

	-- detect if old "default" settings are present, replace with "legacy"
	local usingOldPreset = string.find(currentKeybindingsFile, "default") and true or false
	if usingOldPreset then
		currentKeybindingsFile = replaceDefaultWithLegacy(currentKeybindingsFile)
		spEcho("BAR Hotkeys: Found old default key config, replacing with legacy", currentKeybindingsFile)
	end

	if not VFS.FileExists(currentKeybindingsFile) then
		currentKeybindingsFile = fallbackToDefault(currentKeybindingsFile)
	end

	if VFS.FileExists(currentKeybindingsFile) then
		Spring.SendCommands("keyreload " .. currentKeybindingsFile)
		spEcho("BAR Hotkeys: Loaded hotkeys from " .. currentKeybindingsFile)
		if usingOldPreset then
			-- resolve upgrading from old "default" to "legacy"
			Spring.SetConfigString("KeybindingFile", currentKeybindingsFile)
		end
	else
		spEcho("BAR Hotkeys: No hotkey file found")
	end

	reloadWidgetsBindings()
end


function widget:Initialize()
	reloadBindings()

	WG['bar_hotkeys'] = {}
	WG['bar_hotkeys'].reloadBindings = reloadBindings
end

function widget:Shutdown()
	Spring.SendCommands("keyreload")
	reloadWidgetsBindings()
end
