
---@class RegionGeometry
local Geometry = {}

---@param vertices { x: number, z: number }[]
---@return RegionGeometryKey|nil what the ring is: one vertex a point, three or more a polygon; nil for anything else
function Geometry.Of(vertices)
	local n = #vertices
	if n == 1 then
		return "point"
	end
	if n >= 3 then
		return "polygon"
	end
	return nil
end

---@param vertices { x: number, z: number }[]
---@return number
function Geometry.Area(vertices)
	local n = #vertices
	if n < 3 then
		return 0
	end
	local twice = 0.0
	for i, a in ipairs(vertices) do
		local b = vertices[(i % n) + 1] or a
		twice = twice + (a.x * b.z - b.x * a.z)
	end
	return math.abs(twice) * 0.5
end

---@param vertices { x: number, z: number }[]
---@return number x
---@return number z
function Geometry.Centroid(vertices)
	local n = #vertices
	if n == 0 then
		return 0, 0
	end
	local sx, sz = 0.0, 0.0
	for _, v in ipairs(vertices) do
		sx, sz = sx + v.x, sz + v.z
	end
	return sx / n, sz / n
end

---@param x number
---@param z number
---@param vertices { x: number, z: number }[]
---@return boolean
function Geometry.Contains(x, z, vertices)
	local n = #vertices
	if n < 3 then
		return false
	end
	local inside = false
	local j = n
	for i, vi in ipairs(vertices) do
		local vj = vertices[j] or vi
		if (vi.z > z) ~= (vj.z > z) then
			local crossX = vj.x + (z - vj.z) * (vi.x - vj.x) / (vi.z - vj.z)
			if x < crossX then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end

local EPS = 1e-3 -- elmos: a point closer than this to an edge lies on it

---@param p { x: number, z: number }
---@param q { x: number, z: number }
---@param r { x: number, z: number }
---@return integer 1 or -1 for the side of the line pq the point r lies on; 0 when it lies on the line
local function side(p, q, r)
	local dx, dz = q.x - p.x, q.z - p.z
	local len = math.sqrt(dx * dx + dz * dz)
	local cross = dx * (r.z - p.z) - dz * (r.x - p.x)
	if len == 0 or math.abs(cross) / len <= EPS then
		return 0
	end
	return cross > 0 and 1 or -1
end

---@return boolean the segments cross properly; ones that touch or run along each other do not
local function segmentsCross(a1, a2, b1, b2)
	return side(b1, b2, a1) * side(b1, b2, a2) < 0 and side(a1, a2, b1) * side(a1, a2, b2) < 0
end

---@param x number
---@param z number
---@param vertices { x: number, z: number }[]
---@return boolean the point lies on the ring
function Geometry.OnBoundary(x, z, vertices)
	local n = #vertices
	local p = { x = x, z = z }
	for i, a in ipairs(vertices) do
		local b = vertices[(i % n) + 1] or a
		if
			side(a, b, p) == 0
			and x >= math.min(a.x, b.x) - EPS
			and x <= math.max(a.x, b.x) + EPS
			and z >= math.min(a.z, b.z) - EPS
			and z <= math.max(a.z, b.z) + EPS
		then
			return true
		end
	end
	return false
end

---@param x number
---@param z number
---@param vertices { x: number, z: number }[]
---@return boolean the point lies inside the ring and not on it
local function strictlyInside(x, z, vertices)
	return Geometry.Contains(x, z, vertices) and not Geometry.OnBoundary(x, z, vertices)
end

---@param a { x: number, z: number }[]
---@param b { x: number, z: number }[]
---@return boolean the two rings share ground; neighbours that only touch along an edge or at a corner do not
function Geometry.Overlaps(a, b)
	if #a < 3 or #b < 3 then
		return false
	end
	for _, v in ipairs(a) do
		if strictlyInside(v.x, v.z, b) then
			return true
		end
	end
	for _, v in ipairs(b) do
		if strictlyInside(v.x, v.z, a) then
			return true
		end
	end
	local na, nb = #a, #b
	for i = 1, na do
		local a1, a2 = a[i], a[(i % na) + 1]
		for j = 1, nb do
			if segmentsCross(a1, a2, b[j], b[(j % nb) + 1]) then
				return true
			end
		end
	end
	-- one ring lying along the other, or the same ring twice: no corner is strictly inside, no edge crosses
	local ax, az = Geometry.Centroid(a)
	local bx, bz = Geometry.Centroid(b)
	return strictlyInside(ax, az, b) or strictlyInside(bx, bz, a)
end

---@param ax number
---@param az number
---@param bx number
---@param bz number
---@return number
function Geometry.Distance(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

return Geometry
