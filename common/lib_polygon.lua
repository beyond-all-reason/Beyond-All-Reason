-- Polygon math utilities for startbox containment checks.
-- Used by both synced gadgets and unsynced widgets.

local PolygonLib = {}

--- Point-in-polygon test using the ray-casting (crossing number) algorithm.
--- Handles convex and concave polygons correctly.
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param vertices table array of {x, y} vertex pairs defining the polygon
--- @return boolean true if the point is inside the polygon
function PolygonLib.PointInPolygon(x, y, vertices)
	local n = #vertices
	if n < 3 then
		return false
	end

	local inside = false
	local j = n
	for i = 1, n do
		local xi, yi = vertices[i][1], vertices[i][2]
		local xj, yj = vertices[j][1], vertices[j][2]

		if (yi > y) ~= (yj > y) then
			local intersectX = xj + (y - yj) * (xi - xj) / (yi - yj)
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
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param entry table startbox config entry with entry.boxes = {polygon1, polygon2, ...}
--- @return boolean true if the point is inside any sub-polygon
function PolygonLib.PointInStartbox(x, y, entry)
	if not entry or not entry.boxes then
		return false
	end

	for i = 1, #entry.boxes do
		if PolygonLib.PointInPolygon(x, y, entry.boxes[i]) then
			return true
		end
	end

	return false
end

--- Compute the axis-aligned bounding box of all sub-polygons in a startbox entry.
--- @param entry table startbox config entry with entry.boxes = {polygon1, polygon2, ...}
--- @return number, number, number, number xmin, ymin, xmax, ymax
function PolygonLib.GetStartboxBounds(entry)
	if not entry or not entry.boxes then
		return 0, 0, 0, 0
	end

	local xmin, ymin = math.huge, math.huge
	local xmax, ymax = -math.huge, -math.huge

	for i = 1, #entry.boxes do
		local polygon = entry.boxes[i]
		for j = 1, #polygon do
			local vx, vy = polygon[j][1], polygon[j][2]
			if vx < xmin then xmin = vx end
			if vx > xmax then xmax = vx end
			if vy < ymin then ymin = vy end
			if vy > ymax then ymax = vy end
		end
	end

	return xmin, ymin, xmax, ymax
end

return PolygonLib
