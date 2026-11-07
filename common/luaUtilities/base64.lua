-- Author: Alex Kloss
-- Contact: http://www.it-rfc.de
-- Date: 2006-2008
-- License: LGPL2

-- The bit fields packed into a byte never overlap, so they combine with plain arithmetic.
local floor = math.floor
local strbyte = string.byte
local strchar = string.char

-- encoding table
local base64chars = {
	[0] = 'A', [1] = 'B', [2] = 'C', [3] = 'D', [4] = 'E', [5] = 'F', [6] = 'G', [7] = 'H', [8] = 'I', [9] = 'J',
	[10] = 'K', [11] = 'L', [12] = 'M', [13] = 'N', [14] = 'O', [15] = 'P', [16] = 'Q', [17] = 'R', [18] = 'S',
	[19] = 'T', [20] = 'U', [21] = 'V', [22] = 'W', [23] = 'X', [24] = 'Y', [25] = 'Z', [26] = 'a', [27] = 'b',
	[28] = 'c', [29] = 'd', [30] = 'e', [31] = 'f', [32] = 'g', [33] = 'h', [34] = 'i', [35] = 'j', [36] = 'k',
	[37] = 'l', [38] = 'm', [39] = 'n', [40] = 'o', [41] = 'p', [42] = 'q', [43] = 'r', [44] = 's', [45] = 't',
	[46] = 'u', [47] = 'v', [48] = 'w', [49] = 'x', [50] = 'y', [51] = 'z', [52] = '0', [53] = '1', [54] = '2',
	[55] = '3', [56] = '4', [57] = '5', [58] = '6', [59] = '7', [60] = '8', [61] = '9', [62] = '-', [63] = '_'
}

-- encodes input string to base64url with = padding.
local function base64Encode(data)
	local result = {}
	local resultCount = 0
	local dataLen = #data
	for spos = 0, dataLen - 1, 3 do
		local b1, b2, b3 = strbyte(data, spos + 1, spos + 3)
		b2 = b2 or 0
		b3 = b3 or 0
		resultCount = resultCount + 1
		result[resultCount] = base64chars[floor(b1 / 4)] ..
			base64chars[(b1 % 4) * 16 + floor(b2 / 16)] ..
			(((dataLen - spos) > 1) and base64chars[(b2 % 16) * 4 + floor(b3 / 64)] or "=") ..
			(((dataLen - spos) > 2) and base64chars[b3 % 64] or "=")
	end
	result = table.concat(result)
	return result
end

-- decoding table
-- The url alphabet ('-' and '_') is what base64Encode above emits and what the modoptions transport specifies.
-- '+' and '/' are accepted as aliases, making this decode both base64 and base64url.
local base64bytes = {
	['A'] = 0, ['B'] = 1, ['C'] = 2, ['D'] = 3, ['E'] = 4, ['F'] = 5, ['G'] = 6, ['H'] = 7, ['I'] = 8, ['J'] = 9,
	['K'] = 10, ['L'] = 11, ['M'] = 12, ['N'] = 13, ['O'] = 14, ['P'] = 15, ['Q'] = 16, ['R'] = 17, ['S'] = 18,
	['T'] = 19, ['U'] = 20, ['V'] = 21, ['W'] = 22, ['X'] = 23, ['Y'] = 24, ['Z'] = 25, ['a'] = 26, ['b'] = 27,
	['c'] = 28, ['d'] = 29, ['e'] = 30, ['f'] = 31, ['g'] = 32, ['h'] = 33, ['i'] = 34, ['j'] = 35, ['k'] = 36,
	['l'] = 37, ['m'] = 38, ['n'] = 39, ['o'] = 40, ['p'] = 41, ['q'] = 42, ['r'] = 43, ['s'] = 44, ['t'] = 45,
	['u'] = 46, ['v'] = 47, ['w'] = 48, ['x'] = 49, ['y'] = 50, ['z'] = 51, ['0'] = 52, ['1'] = 53, ['2'] = 54,
	['3'] = 55, ['4'] = 56, ['5'] = 57, ['6'] = 58, ['7'] = 59, ['8'] = 60, ['9'] = 61, ['-'] = 62, ['_'] = 63,
	['+'] = 62, ['/'] = 63,
	['='] = nil,
}

-- the same table, keyed by byte value
local base64values = {} ---@type table<integer, integer>
for character, value in pairs(base64bytes) do
	base64values[strbyte(character)] = value
end

-- Anything outside the alphabet, padding aside.
local UNEXPECTED_CHARACTER_PATTERN = "[^%w=_+/-]"

-- Decoding is best-effort for compatibility, but warns about invalid chars
local function warnUnexpectedCharacters(data)
	local seen = {}
	local characters = {}

	for character in data:gmatch(UNEXPECTED_CHARACTER_PATTERN) do
		if not seen[character] then
			seen[character] = true
			characters[#characters + 1] = string.format("%q", character)
		end
	end

	Spring.Log("base64", LOG.WARNING, string.format(
		"Decoding input with %d unexpected character(s) (%s); they are dropped, so the result is truncated.",
		#characters,
		table.concat(characters, ", ")
	))
end

-- decode base64 or base64url input to string
local function base64Decode(data)

	if data:find(UNEXPECTED_CHARACTER_PATTERN) then
		warnUnexpectedCharacters(data)
	end

	local result = {}
	local resultCount = 0
	local dataLen = #data
	for dpos = 0, dataLen - 1, 4 do
		local c1, c2, c3, c4 = strbyte(data, dpos + 1, dpos + 4)
		c1, c2, c3, c4 = base64values[c1], base64values[c2], base64values[c3], base64values[c4]
		local byte1 = c1 * 4 + floor(c2 / 16)
		resultCount = resultCount + 1
		if c4 ~= nil then
			result[resultCount] = strchar(byte1, (c2 % 16) * 16 + floor(c3 / 4), (c3 % 4) * 64 + c4)
		elseif c3 ~= nil then
			result[resultCount] = strchar(byte1, (c2 % 16) * 16 + floor(c3 / 4))
		else
			result[resultCount] = strchar(byte1)
		end
	end
	result = table.concat(result)
	return result
end

return {
	Encode = base64Encode,
	Decode = base64Decode,
}
