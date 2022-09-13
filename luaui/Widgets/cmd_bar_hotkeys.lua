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

local function makeBindsTable()
	local bindingsFile = VFS.FileExists(currentKeybindingsFile) and currentKeybindingsFile or "luaui/configs/bar_hotkeys.lua"
	local env = keyConfig.scanToCode[currentLayout]
	env['table'] = table
	return VFS.Include(bindingsFile, env)
end

local function reloadWidgetsBindings()
	local reloadableWidgets = {'buildmenu', 'ordermenu', 'keybinds'}

	for _, w in pairs(reloadableWidgets) do
		if WG[w] and WG[w].reloadBindings then
			WG[w].reloadBindings()
		end
	end
end

local function loadBindings()
	for _, v in ipairs(makeBindsTable()) do
		local command = 'bind '..v[1]..' '..v[2]..' '..(v[3] or '')
		Spring.SendCommands(command)
	end
end

local function reloadBindings()
	Spring.SendCommands("unbindall")

	currentLayout = Spring.GetConfigString("KeyboardLayout", 'qwerty')
	currentKeybindingsFile = Spring.GetConfigString("KeybindingFile", "luaui/configs/bar_hotkeys.lua")

	loadBindings()

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
