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

scanToCode["colemak"] = {
	Q = "Q",
	W = "W",
	E = "F",
	R = "P",
	T = "G",
	Y = "J",
	U = "L",
	I = "U",
	O = "Y",
	P = ";",
	A = "A",
	S = "R",
	D = "S",
	F = "T",
	G = "D",
	H = "H",
	J = "N",
	K = "E",
	L = "I",
	[";"] = "O",
	Z = "Z",
	X = "X",
	C = "C",
	V = "V",
	B = "B",
	N = "K",
	M = "M",
	["'"] = "'",
	[","] = ".",
	["."] = ",",
	["/"] = "/",
	["`"] = "`",
	["-"] = "-",
	["="] = "=",
	["\\"] = "\\",
}

scanToCode["colemak-dh"] = {
	Q = "Q",
	W = "W",
	E = "F",
	R = "P",
	T = "B",
	Y = "J",
	U = "L",
	I = "U",
	O = "Y",
	P = ";",
	A = "A",
	S = "R",
	D = "S",
	F = "T",
	G = "G",
	H = "M",
	J = "N",
	K = "E",
	L = "I",
	[";"] = "O",
	Z = "Z",
	X = "X",
	C = "C",
	V = "D",
	B = "V",
	N = "K",
	M = "M",
	["'"] = "'",
	[","] = ",",
	["."] = ".",
	["/"] = "/",
	["`"] = "`",
	["-"] = "-",
	["="] = "=",
	["\\"] = "\\",
}

local layouts = { 'qwerty', 'qwertz', 'azerty', 'dvorak', 'colemak', 'colemak-dh' }

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

return {
	layouts = layouts,
	scanToCode = scanToCode,
	sanitizeKey = sanitizeKey,
	keybindingLayouts = {
		'Default',
		'Default (Mnemonic)',
		'Default 60% Keyboard',
		'Grid Optimized',
		'Grid Optimized 60% Keyboard',
		'Custom'
	},
	keybindingLayoutFiles = {
		'luaui/configs/bar_hotkeys.lua',
		'luaui/configs/bar_hotkeys_mnemonic.lua',
		'luaui/configs/bar_hotkeys_60.lua',
		'luaui/configs/bar_hotkeys_grid.lua',
		'luaui/configs/bar_hotkeys_grid_60.lua',
		'bar_hotkeys_custom.lua'
	}
}
