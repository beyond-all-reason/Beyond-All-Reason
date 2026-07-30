-- common/feature_scatter.lua
--
-- Brush-layout generation for the feature placer. This used to live in
-- luarules/gadgets/cmd_feature_placer.lua, which meant the widget had no way of
-- knowing what the gadget was about to spawn -- it sent brush parameters and the
-- gadget rolled the dice. That made a truthful placement preview impossible.
--
-- Now the widget owns generation: it builds the layout, draws it as ghosts, and
-- on click ships the resulting list of concrete placements to the gadget. The
-- preview and the result are the same array, so they agree by construction
-- rather than by two copies of the same algorithm staying in sync.
--
-- Two-stage on purpose:
--   * generateLocal() produces a brush-relative layout. It is deterministic for
--     a given (seed, params) pair, so it can be cached and reused while the
--     cursor moves -- otherwise the preview would reshuffle every frame.
--   * resolve() translates that layout to a world position and applies the
--     terrain-dependent smart filters, which can only be evaluated once the
--     brush centre is known. Cheap enough to run per frame.
--
-- Containment uses common/brush_shapes.lua, the same module the brush outlines
-- are drawn from, so features land inside the shape the user actually sees. The
-- old gadget-local isInsideShape used an apothem-based polygon convention that
-- did not match the drawn outline.

local BrushShapes = VFS.Include("common/brush_shapes.lua")
local isInside = BrushShapes.isInside

local max = math.max
local min = math.min
local floor = math.floor
local sqrt = math.sqrt
local log = math.log
local cos = math.cos
local sin = math.sin
local pi = math.pi

local GOLDEN_ANGLE = pi * (3 - sqrt(5))
local TAU = 2 * pi

----------------------------------------------------------------
-- Deterministic RNG
----------------------------------------------------------------
-- Self-contained rather than math.random: the layout has to be reproducible
-- from a seed so the preview stays put while the cursor moves, and getting that
-- by reseeding the shared math.random stream would disturb every other widget.
--
-- Wichmann-Hill specifically, because **Recoil builds Lua with
-- LUA_NUMBER = float** (rts/lib/lua/include/luaconf.h -- the `double` line is
-- commented out). Integers are therefore only exact to 2^24 = 16777216, and any
-- generator whose intermediates exceed that silently disintegrates: the textbook
-- 32-bit LCG this replaced computed 1664525 * state, up to 7.1e15, and collapsed
-- to FIVE distinct outputs in 500 draws -- every scattered feature landing on one
-- of a couple of spots.
--
-- Wichmann-Hill's three multiplies peak at 172 * 30306 = 5212632, comfortably
-- exact, and it still has a period around 7e12.
local WH_M1, WH_A1 = 30269, 171
local WH_M2, WH_A2 = 30307, 172
local WH_M3, WH_A3 = 30323, 170
local SEED_MAX = 16777216 -- 2^24; anything above this is not exact as a float

local RngMT = {}
RngMT.__index = RngMT

---Next float in [0, 1).
function RngMT:next()
	self.s1 = (WH_A1 * self.s1) % WH_M1
	self.s2 = (WH_A2 * self.s2) % WH_M2
	self.s3 = (WH_A3 * self.s3) % WH_M3
	local v = (self.s1 / WH_M1 + self.s2 / WH_M2 + self.s3 / WH_M3) % 1
	-- Guard the boundary: at float precision the fractional sum can round up to
	-- exactly 1.0, which would push :int() one past its upper bound.
	if v >= 1 then
		return 0
	end
	return v
end

---Next integer in [lo, hi] inclusive.
function RngMT:int(lo, hi)
	if hi <= lo then
		return lo
	end
	local v = lo + floor(self:next() * (hi - lo + 1))
	if v > hi then
		return hi
	end
	return v
end

local function newRng(seed)
	seed = floor(seed or 0)
	if seed < 0 then
		seed = -seed
	end
	seed = seed % SEED_MAX

	local rng = setmetatable({
		s1 = (seed % (WH_M1 - 1)) + 1,
		s2 = (floor(seed / 3) % (WH_M2 - 1)) + 1,
		s3 = (floor(seed / 7) % (WH_M3 - 1)) + 1,
	}, RngMT)

	-- Adjacent seeds start from adjacent states, which correlates the first few
	-- draws. Cheap to spin past.
	for _ = 1, 12 do
		rng:next()
	end
	return rng
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
-- Orbits a brush-local offset as the brush rotates.
--
-- The sign has to match the heading convention or the layout counter-rotates:
-- brush rotation feeds both this and baseHeading, and a feature with heading h
-- faces (sin h, 0, cos h). Rotating the brush by t must therefore move an offset
-- exactly the way it turns that facing -- i.e. this is Ry_engine(-t), the same
-- rotation the model itself receives. The textbook (x*c - z*s, x*s + z*c) is the
-- mirror of that: a feature due +Z of the centre would swing to -X while turning
-- to face +X, so the group appeared to spin the wrong way about its own axes
-- instead of orbiting the brush centre.
local function rotatePoint(px, pz, angleDeg)
	if angleDeg == 0 then
		return px, pz
	end
	local rad = angleDeg * pi / 180
	local ca, sa = cos(rad), sin(rad)
	return px * ca + pz * sa, -px * sa + pz * ca
end

-- Local-space containment: the layout is generated unrotated and rotated into
-- place afterwards, so the shape test always runs at angle 0.
local function insideLocal(dx, dz, radius, shape, lengthScale)
	local ok = isInside(dx, dz, radius, shape, 0, lengthScale)
	return ok
end

----------------------------------------------------------------
-- Distribution: random
----------------------------------------------------------------
local function generateRandom(radius, shape, lengthScale, count, rng)
	local positions = {}
	local attempts = 0
	local maxAttempts = count * 8
	while #positions < count and attempts < maxAttempts do
		attempts = attempts + 1
		local rx = (rng:next() * 2 - 1) * radius
		local rz = (rng:next() * 2 - 1) * radius * lengthScale
		if insideLocal(rx, rz, radius, shape, lengthScale) then
			positions[#positions + 1] = { rx, rz }
		end
	end
	return positions
end

----------------------------------------------------------------
-- Distribution: regular grids
----------------------------------------------------------------
local function generateFibonacci(radius, count)
	local positions = {}
	for i = 0, count - 1 do
		local r = radius * sqrt(i / max(1, count - 1))
		local theta = i * GOLDEN_ANGLE
		positions[#positions + 1] = { r * cos(theta), r * sin(theta) }
	end
	return positions
end

local function generateSquareGrid(radius, count, lengthScale)
	local positions = {}
	local radZ = radius * lengthScale
	local spacing = sqrt((2 * radius) * (2 * radZ) / max(1, count))
	local cols = max(1, floor(2 * radius / spacing + 0.5))
	local rows = max(1, floor(2 * radZ / spacing + 0.5))
	local sx = 2 * radius / cols
	local sz = 2 * radZ / rows
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			positions[#positions + 1] = { -radius + sx * (col + 0.5), -radZ + sz * (row + 0.5) }
		end
	end
	return positions
end

-- Grid clipped to the shape mask. Used for hexagon and octagon, which have no
-- natural lattice of their own but tile a square grid acceptably.
local function generateClippedGrid(radius, shape, count, lengthScale)
	local positions = {}
	local radZ = radius * lengthScale
	-- Overshoot the spacing estimate: clipping throws points away, so a spacing
	-- derived from the bounding box alone would under-fill the shape.
	local spacing = sqrt((2 * radius) * (2 * radZ) / max(1, count)) * 0.85
	local numCols = floor(2 * radius / spacing) + 1
	local numRows = floor(2 * radZ / spacing) + 1
	for row = 0, numRows do
		for col = 0, numCols do
			local lx = -radius + col * spacing
			local lz = -radZ + row * spacing
			if insideLocal(lx, lz, radius, shape, lengthScale) then
				positions[#positions + 1] = { lx, lz }
			end
		end
	end
	return positions
end

local function generateRegular(radius, shape, lengthScale, count, rng)
	if shape == "circle" then
		return generateFibonacci(radius, count)
	elseif shape == "square" then
		return generateSquareGrid(radius, count, lengthScale)
	elseif shape == "hexagon" or shape == "octagon" then
		return generateClippedGrid(radius, shape, count, lengthScale)
	end
	-- Triangle has no pleasant lattice; fall back to scatter.
	return generateRandom(radius, shape, lengthScale, count, rng)
end

----------------------------------------------------------------
-- Distribution: clustered (organic)
----------------------------------------------------------------
-- Two tiers: ~75% of features spawn near randomly-chosen cluster nuclei with a
-- Gaussian offset, ~25% scatter freely. A minimum separation derived from the
-- selected defs' own collision radii prevents exact overlaps, so large features
-- naturally space out while small ones pack tightly.
local function generateClustered(radius, shape, lengthScale, count, defNames, rng)
	local minSpacing = 4
	for i = 1, #defNames do
		local def = FeatureDefNames[defNames[i]]
		if def and def.radius and def.radius > minSpacing then
			minSpacing = def.radius
		end
	end
	minSpacing = minSpacing * 1.4

	-- Guarantee the Poisson-disk capacity can actually fit `count`, or the
	-- rejection loop burns its whole budget and returns short.
	local capacity = 0.5 * (radius / max(1, minSpacing)) ^ 2
	if capacity < count then
		minSpacing = radius / sqrt(count * 2)
	end
	minSpacing = max(4, minSpacing)
	local minSq = minSpacing * minSpacing

	local numClusters = max(2, min(6, floor(sqrt(count) * 0.7 + 0.5)))
	local clusterCenters = {}
	local nattempts = 0
	while #clusterCenters < numClusters and nattempts < numClusters * 20 do
		nattempts = nattempts + 1
		local rx = (rng:next() * 2 - 1) * radius
		local rz = (rng:next() * 2 - 1) * radius * lengthScale
		if insideLocal(rx, rz, radius, shape, lengthScale) then
			clusterCenters[#clusterCenters + 1] = { rx, rz }
		end
	end
	if #clusterCenters == 0 then
		clusterCenters[1] = { 0, 0 }
	end

	local sigma = radius / max(1, #clusterCenters) * 1.2
	local RANDOM_FRAC = 0.25

	local positions = {}
	local maxAttempts = count * 15
	local tries = 0

	while #positions < count and tries < maxAttempts do
		tries = tries + 1
		local px, pz
		local valid = false

		if rng:next() < RANDOM_FRAC then
			local rx = (rng:next() * 2 - 1) * radius
			local rz = (rng:next() * 2 - 1) * radius * lengthScale
			if insideLocal(rx, rz, radius, shape, lengthScale) then
				px, pz = rx, rz
				valid = true
			end
		else
			-- Box-Muller for a normally-distributed offset from a nucleus.
			local cc = clusterCenters[rng:int(1, #clusterCenters)]
			local u1 = max(1e-7, rng:next())
			local mag = sigma * sqrt(-2 * log(u1))
			local ang = rng:next() * TAU
			px, pz = cc[1] + mag * cos(ang), cc[2] + mag * sin(ang)
			valid = insideLocal(px, pz, radius, shape, lengthScale)
		end

		if valid then
			local tooClose = false
			for i = 1, #positions do
				local ddx, ddz = px - positions[i][1], pz - positions[i][2]
				if ddx * ddx + ddz * ddz < minSq then
					tooClose = true
					break
				end
			end
			if not tooClose then
				positions[#positions + 1] = { px, pz }
			end
		end
	end

	return positions
end

----------------------------------------------------------------
-- Public: layout generation
----------------------------------------------------------------
---Build a brush-relative layout. Deterministic for a given (seed, params).
---@param params table shape, radius, rotation, count, distribution, rotRandom, defNames, lengthScale
---@param seed number
---@return table layout array of { dx, dz, defName, heading }
local function generateLocal(params, seed)
	local defNames = params.defNames or {}
	if #defNames == 0 then
		return {}
	end

	local rng = newRng(seed)
	local shape = params.shape or "circle"
	local radius = params.radius or 200
	local lengthScale = params.lengthScale or 1.0
	local count = max(1, floor(params.count or 1))
	local distribution = params.distribution or "random"

	local positions
	if distribution == "regular" then
		positions = generateRegular(radius, shape, lengthScale, count, rng)
	elseif distribution == "clustered" then
		positions = generateClustered(radius, shape, lengthScale, count, defNames, rng)
	else
		positions = generateRandom(radius, shape, lengthScale, count, rng)
	end

	-- Rotate the layout into the brush's orientation and assign per-feature
	-- def and heading. Headings are rolled here, not at resolve time, so a
	-- feature keeps its orientation while the cursor moves.
	local angleDeg = params.rotation or 0
	local baseHeading = floor((angleDeg / 360) * 65536) % 65536
	local spread = floor((params.rotRandom or 100) / 100 * 32768)
	local numDefs = #defNames

	local layout = {}
	for i = 1, #positions do
		local wx, wz = rotatePoint(positions[i][1], positions[i][2], angleDeg)
		layout[#layout + 1] = {
			dx = wx,
			dz = wz,
			defName = defNames[rng:int(1, numDefs)],
			heading = (baseHeading + rng:int(-spread, spread)) % 65536,
		}
	end

	return layout
end

----------------------------------------------------------------
-- Public: resolve to world placements
----------------------------------------------------------------
---Translate a layout to a world position and apply terrain-dependent filters.
---@param layout table from generateLocal
---@param centerX number brush centre
---@param centerZ number brush centre
---@param params table smartEnabled and smartFilters
---@param extraRotDeg number|nil additional rotation for this copy of the brush
---@return table placements array of { defName, x, y, z, heading, pitch, roll }
--
-- `extraRotDeg` exists for symmetry. getSymmetricPositions hands back a per-copy
-- `rot` that differs from the brush's own rotation (radial copies are turned by
-- 360/N, mirrored copies by twice the mirror angle), and the drawn outline and
-- the erase brush both honour it. The layout was rotated once by the base
-- rotation in generateLocal, so each copy needs the difference applied here --
-- otherwise mirrored copies keep the unrotated pattern and land outside the
-- outline the user is aiming with.
local function resolve(layout, centerX, centerZ, params, extraRotDeg)
	local placements = {}
	if not layout or #layout == 0 then
		return placements
	end

	extraRotDeg = extraRotDeg or 0
	local rotateCopy = extraRotDeg ~= 0
	local headingOffset = floor(extraRotDeg / 360 * 65536)

	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	local GetGroundHeight = Spring.GetGroundHeight
	local GetGroundNormal = Spring.GetGroundNormal

	local smart = params.smartEnabled and params.smartFilters or nil
	local nyCliffMin, nySlopeMax, altMin, altMax
	if smart then
		nyCliffMin = smart.avoidCliffs and cos((smart.slopeMax or 45) * pi / 180) or nil
		nySlopeMax = smart.preferSlopes and cos((smart.slopeMin or 10) * pi / 180) or nil
		altMin = smart.altMinEnable and smart.altMin or nil
		altMax = smart.altMaxEnable and smart.altMax or nil
	end

	for i = 1, #layout do
		local entry = layout[i]
		local dx, dz = entry.dx, entry.dz
		if rotateCopy then
			dx, dz = rotatePoint(dx, dz, extraRotDeg)
		end
		local x = max(0, min(mapX, centerX + dx))
		local z = max(0, min(mapZ, centerZ + dz))
		local y = GetGroundHeight(x, z)

		local valid = true
		if smart then
			if smart.avoidWater and y < 0 then
				valid = false
			end
			if valid and (nyCliffMin or nySlopeMax) then
				local _, ny = GetGroundNormal(x, z)
				ny = ny or 1.0
				if nyCliffMin and ny < nyCliffMin then
					valid = false
				end
				if valid and nySlopeMax and ny > nySlopeMax then
					valid = false
				end
			end
			if valid and altMin and y < altMin then
				valid = false
			end
			if valid and altMax and y > altMax then
				valid = false
			end
		end

		if valid then
			placements[#placements + 1] = {
				defName = entry.defName,
				x = x,
				y = y,
				z = z,
				heading = (entry.heading + headingOffset) % 65536,
				pitch = 0,
				roll = 0,
			}
		end
	end

	return placements
end

return {
	newRng = newRng,
	generateLocal = generateLocal,
	resolve = resolve,
	rotatePoint = rotatePoint,
}
