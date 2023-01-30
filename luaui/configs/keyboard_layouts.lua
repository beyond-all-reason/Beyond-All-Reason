local scanToCode = { qwerty = {}, azerty = {}, qwertz = {} }

for c in string.gmatch("QWERTYUIOPASDFGHJKLZXCVBNM[];',./`-=\\", ".") do
	scanToCode["qwerty"][c] = c
	scanToCode["qwertz"][c] = c
	scanToCode["azerty"][c] = c
end

scanToCode["qwertz"]["Y"] = "Z"
scanToCode["qwertz"]["Z"] = "Y"
	-- NEEDS CORRECTION BELOW
scanToCode["qwertz"][";"] = ";"
scanToCode["qwertz"]["'"] = "'"
scanToCode["qwertz"][","] = ","
scanToCode["qwertz"]["."] = "."
scanToCode["qwertz"]["/"] = "/"
scanToCode["qwertz"]["`"] = "`"
scanToCode["qwertz"]["-"] = "-"
scanToCode["qwertz"]["="] = "="
scanToCode["qwertz"]["\\"] = "\\"
	-- NEEDS CORRECTION ABOVE

scanToCode["azerty"]["Z"] = "W"
scanToCode["azerty"]["A"] = "Q"
scanToCode["azerty"]["Q"] = "A"
scanToCode["azerty"]["W"] = "Z"
	-- NEEDS CORRECTION BELOW
scanToCode["azerty"][";"] = ";"
scanToCode["azerty"]["'"] = "'"
scanToCode["azerty"][","] = ","
scanToCode["azerty"]["."] = "."
scanToCode["azerty"]["/"] = "/"
scanToCode["azerty"]["`"] = "`"
scanToCode["azerty"]["-"] = "-"
scanToCode["azerty"]["="] = "="
scanToCode["azerty"]["\\"] = "\\"
	-- NEEDS CORRECTION ABOVE

scanToCode["dvorak"] = {
	Q = "'",
	W = ",",
	E = ".",
	R = "P",
	T = "Y",
	Y = "F",
	U = "G",
	I = "C",
	O = "R",
	P = "L",
	A = "A",
	S = "O",
	D = "E",
	F = "U",
	G = "I",
	H = "D",
	J = "H",
	K = "T",
	L = "N",
	Z = ";",
	X = "Q",
	C = "J",
	V = "K",
	B = "X",
	N = "B",
	M = "M",
	-- NEEDS CORRECTION BELOW
	[";"] = ";",
	["'"] = "'",
	[","] = ",",
	["."] = ".",
	["/"] = "/",
	["`"] = "`",
	["-"] = "-",
	["="] = "=",
	["\\"] = "\\",
	-- NEEDS CORRECTION ABOVE
}

local layouts = { 'qwerty', 'qwertz', 'azerty', 'dvorak' }

local function sanitizeKey(key, layout)
	if not (type(key) == "string") then
		return ""
	end

	layout = layout or Spring.GetConfigString("KeyboardLayout", "qwerty")

	key = key:upper():gsub("ANY%+", '')
	key = key:gsub("SC_(.)", function(c)
		return scanToCode[layout][c] or c
	end)

	return key
end

local keybindingLayouts = {
	'Default',
	'Default (Mnemonic)',
	'Default 60% Keyboard',
	'Grid Optimized',
	'Grid Optimized 60% Keyboard',
	'Custom'
}

local keybindingPresets = {
	['Default'] = 'luaui/configs/hotkeys/default_keys.txt',
	['Default (Mnemonic)'] = 'luaui/configs/hotkeys/mnemonic_keys.txt',
	['Default 60% Keyboard'] = 'luaui/configs/hotkeys/default_keys_60pct.txt',
	['Grid Optimized'] = 'luaui/configs/hotkeys/grid_keys.txt',
	['Grid Optimized 60% Keyboard'] = 'luaui/configs/hotkeys/grid_keys_60pct.txt',
	['Custom'] = 'uikeys_bar.txt',
}

local keybindingLayoutFiles = {}
local presetKeybindings = {}

for i, v in ipairs(keybindingLayouts) do
	local file = keybindingPresets[v]
	keybindingLayoutFiles[i] = file
	presetKeybindings[file] = v
end

return {
	layouts = layouts,
	scanToCode = scanToCode,
	sanitizeKey = sanitizeKey,
	keybindingLayouts = keybindingLayouts,
	keybindingLayoutFiles = keybindingLayoutFiles,
	keybindingPresets = keybindingPresets,
	presetKeybindings = presetKeybindings,
}
