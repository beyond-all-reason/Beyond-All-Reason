if not Game then
	return -- some parser environments such as modrules don't have it, but they don't need colored text either
end

local floor = math.floor
local math_pow = math.pow
local schar = string.char

local colorIndicator = Game.textColorCodes.Color
local colorAndOutlineIndicator = Game.textColorCodes.ColorAndOutline

local function ColorStringEx(r, g, b, a, oR, oG, oB, oA)
	-- Formats alpha and also outline color.
	return colorAndOutlineIndicator .. schar(floor(r * 255)) .. schar(floor(g * 255)) .. schar(floor(b * 255)) .. schar(floor(a * 255)) .. schar(floor(oR * 255)) .. schar(floor(oG * 255)) .. schar(floor(oB * 255)) .. schar(floor(oA * 255))
end

local function ColorArray(r, g, b)
	return floor(r * 255), floor(g * 255), floor(b * 255)
end

local function ColorString(r, g, b)
	-- Standard R, G, B color code.
	r = floor(r * 255)
	g = floor(g * 255)
	b = floor(b * 255)
	-- avoid special char used by i18n
	if r == 37 then
		r = 38
	end -- 37 = %
	if g == 37 then
		g = 38
	end -- 37 = %
	if b == 37 then
		b = 38
	end -- 37 = %
	return colorIndicator .. schar(r) .. schar(g) .. schar(b)
end

local function RgbToLinear(c)
	-- Convert Gamma corrected RGB (0-1) to linear RGB

	-- See https://en.wikipedia.org/wiki/SRGB#From_sRGB_to_CIE_XYZ for an explanation of this transfert function
	if c <= 0.04045 then
		return c / 12.92
	end
	return math_pow((c + 0.055) / 1.055, 2.4)
end

local function RgbToY(r, g, b)
	-- Convert Gamma corrected RGB (0-1) to the Y' relative luminance of XYZ

	-- Linearize the RGB values
	local linearR = RgbToLinear(r)
	local linearG = RgbToLinear(g)
	local linearB = RgbToLinear(b)

	-- Compute the Y' component of XYZ
	return linearR * 0.2126729 + linearG * 0.7151522 + linearB * 0.0721750
end

local function ColorIsDark(red, green, blue)
	-- Determines if the (player) color is dark (i.e. if a white outline is needed)
	-- Input color is a gamma corrected RGB (0-1) color

	-- 0.07 was selected because its the lower than all 16 colors in the BAR 8v8 color palette. So if the colors
	-- is from this palette the color is never considered dark and thus never gets a white outline.
	local threshold = 0.07
	return RgbToY(red, green, blue) < threshold
end

local function ConvertColor(r, g, b)
	-- Converts 0-1 float RGB to a color escape string safe for font rendering.
	-- Guards against char(0) (null), char(10) (newline), char(37) (% used by i18n).
	r = floor(r * 255)
	g = floor(g * 255)
	b = floor(b * 255)
	if r < 11 then
		r = 11
	end
	if g < 11 then
		g = 11
	end
	if b < 11 then
		b = 11
	end
	if r == 37 then
		r = 38
	end
	if g == 37 then
		g = 38
	end
	if b == 37 then
		b = 38
	end
	return colorIndicator .. schar(r) .. schar(g) .. schar(b)
end

return {
	ToString = ColorString,
	ToStringEx = ColorStringEx,
	ToIntArray = ColorArray,
	ColorIsDark = ColorIsDark,
	ConvertColor = ConvertColor,
}
