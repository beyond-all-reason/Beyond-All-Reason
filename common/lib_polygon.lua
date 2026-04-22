-- Polygon math utilities for startbox containment checks.
-- Used by both synced gadgets and unsynced widgets.

local PolygonLib = {}

--- Point-in-polygon test using the ray-casting (crossing number) algorithm.
--- Handles convex and concave polygons correctly.
--- @param x number world X coordinate
--- @param z number world Z coordinate
--- @param vertices table array of {x, z} vertex pairs defining the polygon
--- @return boolean true if the point is inside the polygon
function PolygonLib.PointInPolygon(x, z, vertices)
	local n = #vertices
	if n < 3 then
		return false
	end

	local inside = false
	local j = n
	for i = 1, n do
		local xi, zi = vertices[i][1], vertices[i][2]
		local xj, zj = vertices[j][1], vertices[j][2]

		if (zi > z) ~= (zj > z) then
			local intersectX = xj + (z - zj) * (xi - xj) / (zi - zj)
			if x < intersectX then
				inside = not inside
			end
		end

		j = i
	end

	return inside
end

--- Check if a point is inside any polygon of a startbox entry.
--- A startbox entry may contain multiple disjoint polygons (entry.boxes).
--- @param x number world X coordinate
--- @param z number world Z coordinate
--- @param entry table startbox config entry with entry.boxes = {polygon1, polygon2, ...}
--- @return boolean true if the point is inside any sub-polygon
function PolygonLib.PointInStartbox(x, z, entry)
	if not entry or not entry.boxes then
		return false
	end

	for i = 1, #entry.boxes do
		if PolygonLib.PointInPolygon(x, z, entry.boxes[i]) then
			return true
		end
	end

	return false
end

--- Compute the axis-aligned bounding box of all sub-polygons in a startbox entry.
--- @param entry table startbox config entry with entry.boxes = {polygon1, polygon2, ...}
--- @return number, number, number, number xmin, zmin, xmax, zmax
function PolygonLib.GetStartboxBounds(entry)
	if not entry or not entry.boxes then
		return 0, 0, 0, 0
	end

	local xmin, zmin = math.huge, math.huge
	local xmax, zmax = -math.huge, -math.huge

	for i = 1, #entry.boxes do
		local polygon = entry.boxes[i]
		for j = 1, #polygon do
			local vx, vz = polygon[j][1], polygon[j][2]
			if vx < xmin then xmin = vx end
			if vx > xmax then xmax = vx end
			if vz < zmin then zmin = vz end
			if vz > zmax then zmax = vz end
		end
	end

	return xmin, zmin, xmax, zmax
end

return PolygonLib
