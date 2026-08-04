--- The search ORDER: which points to try, in what sequence, given a centre and
--- how far out we are willing to look. Pure — no Spring, no engine, no map — so
--- the thing that decides "nearest first" is specced directly rather than
--- inferred from where units ended up.
---
--- Integer lattice, not trigonometry. Candidates are offsets on a grid of
--- `step`, visited in rings of increasing Chebyshev distance, and sorted inside
--- each ring by true squared distance. Two reasons for the lattice over a
--- circle of sin/cos samples:
---
---   * every coordinate is exact integer arithmetic, so there is no floating
---     point to disagree about between clients, platforms or replays; and
---   * a ring at radius k has a bounded, knowable number of candidates, so a
---     caller can reason about the cost of the worst case instead of guessing.
---
--- Nearest-first matters because it is the whole contract. A caller asked for a
--- point; if that point is unusable they want the closest usable one, not a
--- random one within tolerance.

local Search = {}

---Candidate offsets at one ring, nearest first.
---
---Ring 0 is the requested point itself. Ring k is every lattice point whose
---Chebyshev distance is exactly k — the square shell — which is what makes the
---rings disjoint and the whole walk exhaustive.
---@param ring integer 0-based ring index
---@param step number lattice spacing in elmos
---@return { dx: number, dz: number }[]
function Search.Ring(ring, step)
	assert(type(ring) == "number" and ring >= 0 and ring % 1 == 0, "Ring expects a non-negative integer ring")
	assert(type(step) == "number" and step > 0, "Ring expects a positive step")

	if ring == 0 then
		return { { dx = 0, dz = 0 } }
	end

	local out = {}
	for i = -ring, ring do
		for j = -ring, ring do
			-- The shell only: interior points belong to an earlier ring and
			-- must not be offered twice.
			if i == -ring or i == ring or j == -ring or j == ring then
				out[#out + 1] = { dx = i * step, dz = j * step }
			end
		end
	end

	-- Nearest first inside the shell. The dx/dz tiebreak is arbitrary but
	-- FIXED, which is the point: two candidates at the same distance must
	-- always be offered in the same order.
	table.sort(out, function(a, b)
		local da = a.dx * a.dx + a.dz * a.dz
		local db = b.dx * b.dx + b.dz * b.dz
		if da ~= db then
			return da < db
		end
		if a.dx ~= b.dx then
			return a.dx < b.dx
		end
		return a.dz < b.dz
	end)
	return out
end

---How many rings a given reach needs at a given step.
---@param radius number how far out the caller will accept a spot
---@param step number lattice spacing
---@return integer
function Search.Rings(radius, step)
	if radius <= 0 then
		return 0
	end
	return math.ceil(radius / step)
end

---Walk outward from a point, offering each candidate to `accept` until one is
---taken. Returns the accepted position, or nil having tried everything.
---
---`accept` is where the engine lives; keeping it a parameter is what leaves
---this file pure and lets a spec drive the whole walk with a plain function.
---@param x number
---@param z number
---@param opts { radius: number, step: number|nil, limit: integer|nil }
---@param accept fun(x: number, z: number, ring: integer): boolean
---@return number|nil x, number|nil z, integer tried
function Search.Outward(x, z, opts, accept)
	assert(type(accept) == "function", "Outward expects an accept function")
	local step = opts.step or 64
	local radius = opts.radius or 0
	-- A ceiling on work, not on distance: a caller that asks to search a whole
	-- map should get a bounded answer rather than a frame-long stall.
	local limit = opts.limit or 512

	local tried = 0
	for ring = 0, Search.Rings(radius, step) do
		for _, offset in ipairs(Search.Ring(ring, step)) do
			-- The shell overshoots the circle at its corners; skip what the
			-- caller did not ask for so "radius" means radius.
			local dist2 = offset.dx * offset.dx + offset.dz * offset.dz
			if dist2 <= radius * radius or ring == 0 then
				tried = tried + 1
				if tried > limit then
					return nil, nil, tried - 1
				end
				local cx, cz = x + offset.dx, z + offset.dz
				if accept(cx, cz, ring) then
					return cx, cz, tried
				end
			end
		end
	end
	return nil, nil, tried
end

return Search
