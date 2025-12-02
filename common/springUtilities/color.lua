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
	-- avoid special char used by i18n
	if r == 37 then r = 38 end	-- 37 = %
	if g == 37 then g = 38 end	-- 37 = %
	if b == 37 then b = 38 end	-- 37 = %
	return colorIndicator .. schar(r) .. schar(g) .. schar(b)
end

local function RgbToLinear(c)
	-- Convert Gamma corrected RGB (0-1) to linear RGB
    if c <= 0.04045 then
        return c / 12.92
    end
    return math_pow((c + 0.055) / 1.055, 2.4)
end

local function RgbToY(r, g, b)
	-- Convert Gamma corrected RGB (0-1) to the Y' relative luminance of XYZ

    -- Normalize and linearize RGB values
    local linearR = RgbToLinear(r)
    local linearG = RgbToLinear(g)
    local linearB = RgbToLinear(b)

	-- Y part of the XYZ
    return linearR * 0.2126729 + linearG * 0.7151522 + linearB * 0.0721750
end

local function ColorIsDark(red, green, blue)
    -- Determines if the (player) color is dark (i.e. if a white outline is needed)
	-- Input color is the gamma corrected RGB (0-1) color

	-- Luminance of less than 0.2 was found to get good results on the BAR color palette
	return RgbToY(red, green, blue) < 0.2
end

local function LegacyColorIsDark(red, green, blue)
    -- (Deprecated) Determines if the (player) color is dark (i.e. if a white outline is needed)
    return red + green * 1.2 + blue * 0.4 < 0.65
end

return {
	ToString = ColorString,
	ToStringEx = ColorStringEx,
	ToIntArray = ColorArray,
	ColorIsDark = ColorIsDark,
	LegacyColorIsDark = LegacyColorIsDark,
}
