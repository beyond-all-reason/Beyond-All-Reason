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

local function makeBindsTable(file)
	local env = keyConfig.scanToCode[currentLayout]
	env['table'] = table
	return VFS.Include(file, env)
end

local function loadBindingsLegacy(file)
	for _, v in ipairs(makeBindsTable(file)) do
		local command = 'bind '..v[1]..' '..v[2]..' '..(v[3] or '')
		Spring.SendCommands(command)
	end
end

-- Map old, deleted lua format presets onto uikeys presets
local legacyToTxt = {
	['luaui/configs/bar_hotkeys.lua']          = 'luaui/configs/hotkeys/default_keys.txt',
	['luaui/configs/bar_hotkeys_mnemonic.lua'] = 'luaui/configs/hotkeys/mnemonic_keys.txt',
	['luaui/configs/bar_hotkeys_60.lua']       = 'luaui/configs/hotkeys/default_keys_60pct.txt',
	['luaui/configs/bar_hotkeys_grid.lua']     = 'luaui/configs/hotkeys/grid_keys.txt',
	['luaui/configs/bar_hotkeys_grid_60.lua']  = 'luaui/configs/hotkeys/grid_keys_60pct.txt',
	['bar_hotkeys_custom.lua']                 = 'uikeys.txt',
}


-- TODO: This code is exclusively to convert from the placeholder lua format to the more stable uikeys format
-- TODO: After a period of ~6 months it should be deleted (around January 2024 or later)
local function replaceLegacyPreset()
	local keyFile = Spring.GetConfigString("KeybindingFile")
	-- sometimes this file can be in other directories, we do a string match
	local isCustom = keyFile and keyFile:match("bar_hotkeys_custom.lua") ~= nil or false
	if not keyFile or not isCustom then
		return false
	end


	local newFormat = legacyToTxt[keyFile]
	if isCustom then -- in case the dir is not root, just pass the filename not the whole path
		newFormat = legacyToTxt["bar_hotkeys_custom.lua"]
	end
	if not newFormat then return false end

	-- in case the user has a uikeys file already, we need to back it up because it could potentially get overwritten by the following steps
	if VFS.FileExists("uikeys.txt") then
		Spring.Echo("BAR Hotkeys: Found existing unused uikeys file, creating a backup called uikeys_auto_backup.txt")
		Spring.SendCommands("keyreload")
		os.rename("uikeys.txt", "uikeys_auto_backup.txt")
	end

	-- output the current custom .lua bindings into a uikeys.txt file
	if isCustom then
		Spring.Echo("BAR Hotkeys: bar_hotkeys_custom.lua found. This format is deprecated, a " .. newFormat .. " file was written to your bar folder")
		if VFS.FileExists(keyFile) then
			Spring.SendCommands("unbindall")
			loadBindingsLegacy(keyFile)
		end

		Spring.SendCommands("keysave " .. newFormat)
	else
		Spring.SendCommands("keyreload " .. newFormat)
	end

	Spring.SetConfigString("KeybindingFile", newFormat)

	return true
end

local function reloadBindings()
	-- Second parameter here is just a fallback if this config is undefined
	currentLayout = Spring.GetConfigString("KeyboardLayout", 'qwerty')

	local hasLegacy = replaceLegacyPreset()

	currentKeybindingsFile = Spring.GetConfigString("KeybindingFile", keyConfig.keybindingPresets["Default"])

	if not hasLegacy then
		if VFS.FileExists(currentKeybindingsFile) then
			Spring.SendCommands("keyreload " .. currentKeybindingsFile)
			Spring.Echo("BAR Hotkeys: Loaded preset " .. keyConfig.presetKeybindings[currentKeybindingsFile] .. " from path: " .. currentKeybindingsFile)
		else
			Spring.Echo("BAR Hotkeys: Did not find keybindings file " .. currentKeybindingsFile ..". Loading defaults")
			Spring.SendCommands("keyreload " .. keyConfig.keybindingPresets["Default"])
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
