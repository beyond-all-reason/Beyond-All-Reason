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
-- A self-contained LCG rather than math.random: the layout has to be
-- reproducible from a seed so the preview is stable across frames, and widgets
-- must not perturb the shared math.random stream to get it. Constants are the
-- Numerical Recipes LCG; the products stay under 2^53 so doubles hold them
-- exactly in Lua 5.1.
local LCG_MUL = 1664525
local LCG_ADD = 1013904223
local LCG_MOD = 4294967296

local RngMT = {}
RngMT.__index = RngMT

---Next float in [0, 1).
function RngMT:next()
	self.state = (LCG_MUL * self.state + LCG_ADD) % LCG_MOD
	return self.state / LCG_MOD
end

---Next integer in [lo, hi] inclusive.
function RngMT:int(lo, hi)
	if hi <= lo then
		return lo
	end
	return lo + floor(self:next() * (hi - lo + 1))
end

local function newRng(seed)
	return setmetatable({ state = (floor(seed or 0) % LCG_MOD + LCG_MOD) % LCG_MOD }, RngMT)
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function rotatePoint(px, pz, angleDeg)
	if angleDeg == 0 then
		return px, pz
	end
	local rad = angleDeg * pi / 180
	local ca, sa = cos(rad), sin(rad)
	return px * ca - pz * sa, px * sa + pz * ca
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
