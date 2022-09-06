function widget:GetInfo()
	return {
		name = "BAR Hotkeys",
		desc = "Enables BAR Hotkeys" ,
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true,
		handler = true,
	}
end

local currentLayout
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

local function makeBindsTable(keyLayout)
	return VFS.Include("luaui/configs/bar_hotkeys.lua", {
		table = table,
		Q = keyLayout[3][1], W = keyLayout[3][2], E = keyLayout[3][3], R = keyLayout[3][4], T = keyLayout[3][5], Y = keyLayout[3][6], U = keyLayout[3][7], I = keyLayout[3][8], O = keyLayout[3][9], P = keyLayout[3][10],
		A = keyLayout[2][1], S = keyLayout[2][2], D = keyLayout[2][3], F = keyLayout[2][4], G = keyLayout[2][5], H = keyLayout[2][6], J = keyLayout[2][7], K = keyLayout[2][8], L = keyLayout[2][9],
		Z = keyLayout[1][1], X = keyLayout[1][2], C = keyLayout[1][3], V = keyLayout[1][4], B = keyLayout[1][5], N = keyLayout[1][6], M = keyLayout[1][7],
	})
end

local function reloadBuildMenuBindings()
	if WG['buildmenu'] and WG['buildmenu'].reloadBindings then
		WG['buildmenu'].reloadBindings()
	end
end

local function loadBindings()
	local keyLayout = keyConfig.keyLayouts[currentLayout]

	reloadBuildMenuBindings()

	for _, v in ipairs(makeBindsTable(keyLayout)) do
		local command = 'bind '..v[1]..' '..v[2]..' '..(v[3] or '')
		Spring.SendCommands(command)
	end
end

local function reloadBindings()
	Spring.SendCommands("unbindall")

	currentLayout = Spring.GetConfigString("KeyboardLayout", 'qwerty')

	loadBindings()
end

function widget:Initialize()
	reloadBindings()

	WG.reloadBindings = reloadBindings
end

function widget:Shutdown()
	Spring.SendCommands("keyreload")
	reloadBuildMenuBindings()
end
