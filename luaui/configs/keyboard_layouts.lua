local scanToCode = { qwerty = {}, azerty = {}, qwertz = {} }

for c in string.gmatch("QWERTYUIOPASDFGHJKLZXCVBNM[];',./`-=\\", ".") do
	scanToCode.qwerty[c] = c
	scanToCode.qwertz[c] = c
	scanToCode.azerty[c] = c
end

scanToCode.qwertz.Y = "Z"
scanToCode.qwertz.Z = "Y"
-- NEEDS CORRECTION BELOW
scanToCode.qwertz[";"] = ";"
scanToCode.qwertz["'"] = "'"
scanToCode.qwertz[","] = ","
scanToCode.qwertz["."] = "."
scanToCode.qwertz["/"] = "/"
scanToCode.qwertz["`"] = "`"
scanToCode.qwertz["-"] = "-"
scanToCode.qwertz["="] = "="
scanToCode.qwertz["\\"] = "\\"
-- NEEDS CORRECTION ABOVE
scanToCode.azerty = {
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

scanToCode.colemak = {
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

scanToCode.canary = {
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

scanToCode.dvorak = {
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

scanToCode.workman = {
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
	"qwerty",
	"qwertz",
	"azerty",
	"colemak",
	"colemak-dh",
	"canary",
	"canary-ortho",
	"dvorak",
	"de-neo",
	"workman",
}

-- The order the engine writes modifiers in, and the one every surface should read and emit.
local modifierOrder = { "Alt", "Ctrl", "Meta", "Shift" }

-- Single-letter abbreviations, as uikeys.txt may spell them (A/C/M/S; * for Any). Derived so
-- the vocabulary is stated once.
local modAbbrev = {}
for _, name in ipairs(modifierOrder) do
	modAbbrev[name:sub(1, 1):upper()] = name:upper() .. "+"
end

-- Printable keys the engine reports by name. The scancode names are positional, so
-- they map to the qwerty character and pick up the layout translation afterwards;
-- the keycode names are the character outright.
local scanKeyWords = {
	minus = "-",
	equals = "=",
	comma = ",",
	apostrophe = "'",
	period = ".",
	semicolon = ";",
	leftbracket = "[",
	rightbracket = "]",
	slash = "/",
	backquote = "`",
	backslash = "\\",
}
local keyCodeWords = {
	backquote = "`",
	tilde = "`",
	caret = "^",
	backslash = "\\",
}

local function sanitizeKey(key, layout)
	if type(key) ~= "string" then
		return ""
	end

	layout = layout or Spring.GetConfigString("KeyboardLayout", "qwerty")

	-- The engine names the punctuation keys with words rather than the character they
	-- produce ("sc_backquote", "backslash"). Fold those back first so they render as
	-- the key itself, and so the scancode form still picks up the layout mapping below.
	key = key:gsub("[Ss][Cc]_(%a%a+)", function(word)
		return "sc_" .. (scanKeyWords[word:lower()] or word)
	end)
	-- Whole words wherever they sit, not just the last one: a chain's first tap is a key
	-- name too. Anything not a key name falls through unchanged, modifiers included.
	key = key:gsub("%f[%a](%a%a+)%f[%A]", function(word)
		return keyCodeWords[word:lower()] or word
	end)

	key = key:upper():gsub("ANY%+", ""):gsub("%*%+", "")

	-- Callers pass whole keysets, chains included, so a key name runs to the next comma
	-- rather than to the end of the string. The leading "." takes one character before the
	-- comma test so a bound comma key reads as itself instead of a separator.
	-- Only a single character is positional: matching one character of a named key would
	-- remap its first letter instead, which renders sc_space as "OPACE" on dvorak.
	local positional = scanToCode[layout] or scanToCode.qwerty
	key = key:gsub("SC_(.[^,]*)", function(token)
		if #token == 1 then
			return positional[token] or token
		end

		-- Named keys sit in the same place on every layout, so the name is the label.
		return token
	end)
	-- Expand a single-letter modifier token (frontier so it doesn't eat the A in META+).
	key = key:gsub("%f[%u]([ACMS])%+", function(m)
		return modAbbrev[m]
	end)

	return key
end

return {
	layouts = layouts,
	scanToCode = scanToCode,
	sanitizeKey = sanitizeKey,
	modifierOrder = modifierOrder,
}
