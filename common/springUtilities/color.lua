if not Game then
	return -- some parser environments such as modrules don't have it, but they don't need colored text either
end

local floor = math.floor
local schar = string.char

local colorIndicator = Game.textColorCodes.Color
local colorAndOutlineIndicator = Game.textColorCodes.ColorAndOutline

local function ColorStringEx(r, g, b, a, oR, oG, oB, oA)
	-- Formats alpha and also outline color.
	return colorAndOutlineIndicator .. schar(floor(r * 255)) .. schar(floor(g * 255)) ..
		schar(floor(b * 255)) .. schar(floor(a * 255)) ..
		schar(floor(oR * 255)) .. schar(floor(oG * 255)) ..
		schar(floor(oB * 255)) .. schar(floor(oA * 255))
end

local function ColorArray(r, g, b)
	return floor(r * 255), floor(g * 255), floor(b * 255)
end


local function ColorString(r, g, b)
	-- Standard R, G, B color code.
	r = floor(r * 255)
	g = floor(g * 255)
	b = floor(b * 255)
	-- avoid special chars used by i18n
	-- 37 = %
	if r == 37 then r = 38 end
	if g == 37 then g = 38 end
	if b == 37 then b = 38 end
	-- 123 = {
	if r == 123 then r = 122 end
	if g == 123 then g = 122 end
	if b == 123 then b = 122 end
	-- 125 = }
	if r == 125 then r = 126 end
	if g == 125 then g = 126 end
	if b == 125 then b = 126 end
	return colorIndicator .. schar(r) .. schar(g) .. schar(b)
end

return {
	ToString = ColorString,
	ToStringEx = ColorStringEx,
	ToIntArray = ColorArray,
}
