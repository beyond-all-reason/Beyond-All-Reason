local floor = math.floor
local schar = string.char
local colorIndicator = Game.textColorCodes.Color
local colorAndOutlineIndicator = Game.textColorCodes.ColorAndOutline

local function ColorStringEx(R, G, B, A, oR, oG, oB, oA)
	-- Formats alpha and also outline color.
	return colorAndOutlineIndicator .. schar(floor(R * 255)) .. schar(floor(G * 255)) ..
		schar(floor(B * 255)) .. schar(floor(A * 255)) ..
		schar(floor(oR * 255)) .. schar(floor(oG * 255)) ..
		schar(floor(oB * 255)) .. schar(floor(oA * 255))
end

local function ColorArray(R, G, B)
	local R255 = floor(R * 255)
	local G255 = floor(G * 255)
	local B255 = floor(B * 255)
	return R255, G255, B255
end

local function ColorString(R, G, B)
	-- Standard R, G, B color code.
	local R255, G255, B255 = ColorArray(R, G, B)

	return colorIndicator .. schar(R255) .. schar(G255) .. schar(B255)
end

return {
	ToString = ColorString,
	ToStringEx = ColorStringEx,
	ToIntArray = ColorArray,
}
