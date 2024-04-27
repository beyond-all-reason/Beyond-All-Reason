function widget:GetInfo()
	return {
		name = "BAR Hotkeys",
		desc = "Enables BAR Hotkeys" ,
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
		handler = true,
	}
end

local currentLayout
local currentKeybindingsFile
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

local function reloadWidgetsBindings()
	local reloadableWidgets = {'buildmenu', 'ordermenu', 'keybinds'}

	for _, w in pairs(reloadableWidgets) do
		if WG[w] and WG[w].reloadBindings then
			WG[w].reloadBindings()
		end
	end
end

local function hasOldDefaultKeys(file)
	if string.find(file, "default") then
		return true
	end
	return false
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
	Spring.Echo("BAR Hotkeys: Did not find keybindings file " .. currentKeys ..". Loading grid keys")
	Spring.SendCommands("keyreload " .. keyConfig.keybindingLayoutFiles[1])
end

local function reloadBindings()
	-- Second parameter here is just a fallback if this config is undefined
	currentLayout = Spring.GetConfigString("KeyboardLayout", 'qwerty')

	currentKeybindingsFile = Spring.GetConfigString("KeybindingFile", keyConfig.keybindingLayoutFiles[1])
	local usingOldPreset = hasOldDefaultKeys(currentKeybindingsFile)
	if usingOldPreset then
		currentKeybindingsFile = replaceDefaultWithLegacy(currentKeybindingsFile)
		Spring.Echo("BAR Hotkeys: Found old default key config, replacing with legacy", currentKeybindingsFile)
	end

	-- resolve upgrading from old "default" to "legacy"
	if usingOldPreset then
		if VFS.FileExists(currentKeybindingsFile) then
			Spring.SendCommands("keyreload " .. currentKeybindingsFile)
			Spring.Echo("BAR Hotkeys: Loaded preset " .. keyConfig.presetKeybindings[currentKeybindingsFile] .. " from path: " .. currentKeybindingsFile)
			Spring.SetConfigString("KeybindingFile", currentKeybindingsFile)
		else
			fallbackToDefault(currentKeybindingsFile)
		end
	else
		-- normal path of loading saved keybinds, no upgrading or anything going on here
		if VFS.FileExists(currentKeybindingsFile) then
			Spring.SendCommands("keyreload " .. currentKeybindingsFile)
			Spring.Echo("BAR Hotkeys: Loaded hotkeys from" .. currentKeybindingsFile)
		else
			fallbackToDefault(currentKeybindingsFile)
		end
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
