---@class RegionHull
local Hull = {}

---@param points { x: number, z: number }[]
---@return number cx
---@return number cz
local function centroid(points)
	local cx, cz = 0.0, 0.0
	for _, p in ipairs(points) do
		cx, cz = cx + p.x, cz + p.z
	end
	return cx / #points, cz / #points
end

---@param o { x: number, z: number }
---@param a { x: number, z: number }
---@param b { x: number, z: number }
---@return number
local function cross(o, a, b)
	return (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x)
end

---@param ring { x: number, z: number }[]
---@param i integer
---@return { x: number, z: number }
local function around(ring, i)
	return ring[((i - 1) % #ring) + 1] --[[@as { x: number, z: number }]]
end

---@param points { x: number, z: number }[]
---@return { x: number, z: number }[]
local function convexHull(points)
	local sorted = {}
	for i, p in ipairs(points) do
		sorted[i] = p
	end
	table.sort(sorted, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.z < b.z
	end)
	local lower = {} ---@type { x: number, z: number }[]
	for _, p in ipairs(sorted) do
		while #lower >= 2 and cross(around(lower, #lower - 1), around(lower, #lower), p) <= 0 do
			lower[#lower] = nil
		end
		lower[#lower + 1] = p
	end
	local upper = {} ---@type { x: number, z: number }[]
	for i = #sorted, 1, -1 do
		local p = around(sorted, i)
		while #upper >= 2 and cross(around(upper, #upper - 1), around(upper, #upper), p) <= 0 do
			upper[#upper] = nil
		end
		upper[#upper + 1] = p
	end
	lower[#lower] = nil
	upper[#upper] = nil
	local hull = {}
	for _, p in ipairs(lower) do
		hull[#hull + 1] = p
	end
	for _, p in ipairs(upper) do
		hull[#hull + 1] = p
	end
	return hull
end

---@param prev { x: number, z: number }
---@param p { x: number, z: number }
---@param nxt { x: number, z: number }
---@return number
local function bend(prev, p, nxt)
	local ax, az = p.x - prev.x, p.z - prev.z
	local bx, bz = nxt.x - p.x, nxt.z - p.z
	local la, lb = math.sqrt(ax * ax + az * az), math.sqrt(bx * bx + bz * bz)
	if la < 1 or lb < 1 then
		return 0
	end
	return math.abs(ax * bz - az * bx) / (la * lb)
end

---@param hull { x: number, z: number }[]
---@return { x: number, z: number }[]
local function pruned(hull)
	while #hull > 3 do
		local dropped = false
		for i = 1, #hull do
			if bend(around(hull, i - 1), around(hull, i), around(hull, i + 1)) < 0.35 then
				table.remove(hull, i)
				dropped = true
				break
			end
		end
		if not dropped then
			break
		end
	end
	return hull
end

---@param points { x: number, z: number }[]
---@param pad number
---@return { x: number, z: number }[]|nil
function Hull.Around(points, pad)
	local n = #points
	if n == 0 then
		return nil
	end
	local cx, cz = centroid(points)
	local hull = n >= 3 and pruned(convexHull(points)) or {}
	if #hull < 3 then
		local reach = pad
		for _, p in ipairs(points) do
			reach = math.max(reach, math.sqrt((p.x - cx) ^ 2 + (p.z - cz) ^ 2) + pad)
		end
		local square = {}
		for k = 0, 3 do
			local a = k / 4 * 2 * math.pi
			square[#square + 1] = { x = cx + math.cos(a) * reach, z = cz + math.sin(a) * reach }
		end
		return square
	end
	local out = {}
	for i, p in ipairs(hull) do
		local dx, dz = p.x - cx, p.z - cz
		local d = math.sqrt(dx * dx + dz * dz)
		out[i] = d < 1 and { x = p.x, z = p.z } or { x = p.x + dx / d * pad, z = p.z + dz / d * pad }
	end
	return out
end

return Hull
