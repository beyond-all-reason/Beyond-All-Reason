local floor = math.floor
local schar = string.char

local function ColorArray(R, G, B)
	local R255 = floor(R * 255)
	local G255 = floor(G * 255)
	local B255 = floor(B * 255)
	if R255 < 1 then
		R255 = 1
	end
	if G255 < 1 then
		G255 = 1
	end
	if B255 < 1 then
		B255 = 1
	end

	return R255, G255, B255
end

local function ColorString(R, G, B)
	local R255, G255, B255 = ColorArray(R, G, B)

	return "\255" .. schar(R255) .. schar(G255) .. schar(B255)
end


return {
	ToString = ColorString,
	ToArray = ColorArray,
}
