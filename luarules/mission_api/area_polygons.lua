---
--- Areas as polygons, the form the campaign AI takes them in.
---

local CIRCLE_VERTEX_COUNT = 32

-- The AI does not check a vertex against the map.
local function toMapElmo(coordinate, mapSize)
	return math.max(0, math.min(mapSize, math.floor(coordinate + 0.5)))
end

---@param area table an Area parameter: a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }
---@return number[] polygon x1, z1, x2, z2, ... in whole elmos, inside the map
local function fromArea(area)
	local polygon = {}

	if area.x1 then
		polygon = { area.x1, area.z1, area.x2, area.z1, area.x2, area.z2, area.x1, area.z2 }
	else
		for i = 0, CIRCLE_VERTEX_COUNT - 1 do
			local angle = i / CIRCLE_VERTEX_COUNT * 2 * math.pi
			polygon[#polygon + 1] = area.x + area.radius * math.cos(angle)
			polygon[#polygon + 1] = area.z + area.radius * math.sin(angle)
		end
	end

	for i = 1, #polygon, 2 do
		polygon[i] = toMapElmo(polygon[i], Game.mapSizeX)
		polygon[i + 1] = toMapElmo(polygon[i + 1], Game.mapSizeZ)
	end

	return polygon
end

return {
	FromArea = fromArea,
}
