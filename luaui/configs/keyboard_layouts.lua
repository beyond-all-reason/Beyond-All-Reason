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
scanToCode["azerty"] = {
	Q = "A",
	W = "Z",
	Z = "W",
	A = "Q",
	M = ",",
	[";"] = "M",
	[","] = ";",
	["."] = ":",
	["/"] = "!",
	["["] = "^",
	["]"] = "$",
	["-"] = ")",
	["="] = "=",
	["'"] = "ù",
	["`"] = "²",
	["\\"] = "*",
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
	Z = "Z",
	X = "X",
	C = "C",
	V = "V",
	B = "B",
	N = "K",
	M = "M",
	[";"] = "O",
	["'"] = "'",
	[","] = ",",
	["."] = ".",
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


scanToCode["canary"] = {
	Q = "W",
	W = "L",
	E = "Y",
	R = "P",
	T = "K",
	Y = "Z",
	U = "X",
	I = "O",
	O = "U",
	P = ";",
	A = "C",
	S = "R",
	D = "S",
	F = "T",
	G = "B",
	H = "F",
	J = "N",
	K = "E",
	L = "I",
	[";"] = "A",
	Z = "J",
	X = "V",
	C = "D",
	V = "G",
	B = "Q",
	N = "M",
	M = "H",
	["'"] = "'",
	[","] = "/",
	["."] = ",",
	["/"] = ".",
	["`"] = "`",
	["-"] = "-",
	["="] = "=",
	["\\"] = "\\",
}


scanToCode["canary-ortho"] = {
	Q = "W",
	W = "L",
	E = "Y",
	R = "P",
	T = "B",
	Y = "Z",
	U = "F",
	I = "O",
	O = "U",
	P = ";",
	A = "C",
	S = "R",
	D = "S",
	F = "T",
	G = "G",
	H = "M",
	J = "N",
	K = "E",
	L = "I",
	[";"] = "A",
	Z = "Q",
	X = "J",
	C = "V",
	V = "D",
	B = "K",
	N = "X",
	M = "H",
	["'"] = "'",
	[","] = "/",
	["."] = ",",
	["/"] = ".",
	["`"] = "`",
	["-"] = "-",
	["="] = "=",
	["\\"] = "\\",
}


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

scanToCode["de-neo"] = {
	Q = "X",
	W = "V",
	E = "L",
	R = "C",
	T = "W",
	Y = "K",
	U = "H",
	I = "G",
	O = "F",
	P = "Q",
	A = "U",
	S = "I",
	D = "A",
	F = "E",
	G = "O",
	H = "S",
	J = "N",
	K = "R",
	L = "T",
	Z = "Ü",
	X = "Ö",
	C = "Ä",
	V = "P",
	B = "Z",
	N = "B",
	M = "M",
	[";"] = "d",
	["'"] = "y",
	[","] = ",",
	["."] = ".",
	["/"] = "j",
	["`"] = "^",
	["-"] = "-",
	["="] = "`",
	-- NEEDS CORRECTION BELOW
	-- The key used in qwerty for \ is used as Mod3 -- ISO_Level3_Shift
	-- which activates the third layer on the keyboard.
	-- Since it's just a modifier, no real key is pressed and as such,
	-- mapping it to a key is kind of difficult.
	["\\"] = "\\",
	-- NEEDS CORRECTION ABOVE
}

scanToCode["workman"] = {
	Q = "Q",
	W = "D",
	E = "R",
	R = "W",
	T = "B",
	Y = "J",
	U = "F",
	I = "U",
	O = "P",
	P = ";",
	A = "A",
	S = "S",
	D = "H",
	F = "T",
	G = "G",
	H = "Y",
	J = "N",
	K = "E",
	L = "O",
	Z = "Z",
	X = "X",
	C = "M",
	V = "C",
	B = "V",
	N = "K",
	M = "L",
	[";"] = "I",
	["'"] = "'",
	[","] = ",",
	["."] = ".",
	["/"] = "/",
	["`"] = "`",
	["-"] = "-",
	["="] = "=",
	["\\"] = "\\",
}


local layouts = {
	'qwerty',
	'qwertz',
	'azerty',
	'colemak',
	'colemak-dh',
	'canary',
	'canary-ortho',
	'dvorak',
	'de-neo',
	'workman',
}

-- Single-letter modifier abbreviations (uikeys.txt: A/C/M/S, * for Any).
local modAbbrev = { A = "ALT+", C = "CTRL+", M = "META+", S = "SHIFT+" }

local function sanitizeKey(key, layout)
	if not (type(key) == "string") then
		return ""
	end

	layout = layout or Spring.GetConfigString("KeyboardLayout", "qwerty")

	key = key:upper():gsub("ANY%+", ""):gsub("%*%+", "")
	key = key:gsub("SC_(.)", function(c)
		return scanToCode[layout][c] or c
	end)
	-- The backslash key comes through as the keysym word, missing the SC_ mapping above.
	key = key:gsub("BACKSLASH", "\\")
	-- Expand a single-letter modifier token (frontier so it doesn't eat the A in META+).
	key = key:gsub("%f[%u]([ACMS])%+", function(m) return modAbbrev[m] end)

	return key
end

-- Preset registry from the shared cross-surface contract (also consumed by Chobby
-- / the lobby); the first entry is the default fallback.
-- Source of truth: common/configs/keybind_presets.json
local Json = Json or VFS.Include('common/luaUtilities/json.lua')
local ok, decoded = pcall(Json.decode, VFS.LoadFile('common/configs/keybind_presets.json'))
local presetList = ok and type(decoded) == 'table' and decoded.presets or nil
if type(presetList) ~= 'table' or #presetList == 0 then
	-- Boot even if the shared registry is missing/corrupt: presets gate the editor,
	-- the settings menu, and the hotkeys widget, so fall back to the built-in list.
	Spring.Echo('[keyboard_layouts] could not load common/configs/keybind_presets.json; using built-in preset fallback')
	presetList = {
		{ name = 'Grid', file = 'luaui/configs/hotkeys/grid_keys.txt' },
		{ name = 'Grid (60% Keyboard)', file = 'luaui/configs/hotkeys/grid_keys_60pct.txt' },
		{ name = 'Legacy', file = 'luaui/configs/hotkeys/legacy_keys.txt' },
		{ name = 'Legacy (60% Keyboard)', file = 'luaui/configs/hotkeys/legacy_keys_60pct.txt' },
		{ name = 'Custom', file = 'uikeys.txt' },
	}
end

local keybindingLayouts = {}
local keybindingPresets = {}
local keybindingLayoutFiles = {}
local presetKeybindings = {}

for i, preset in ipairs(presetList) do
	keybindingLayouts[i] = preset.name
	keybindingPresets[preset.name] = preset.file
	keybindingLayoutFiles[i] = preset.file
	presetKeybindings[preset.file] = preset.name
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
