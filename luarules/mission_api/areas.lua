---
--- Named areas.
---
--- Anything that reads an area by its name sees its current shape, and finds no area
--- while the name has none.
---

local areaNames = GG["MissionAPI"].areaNames

--- An area table is its own shape. An area name gives that area's current shape, or nil when the name has no area.
---@param area table|string a rectangle { x1, z1, x2, z2 } or circle { x, z, radius }, or an area name
---@return table?
local function resolveArea(area)
	if type(area) == "string" then
		return areaNames[area]
	end
	return area
end

return {
	ResolveArea = resolveArea,
}
