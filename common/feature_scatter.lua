-- common/feature_scatter.lua
--
-- Brush-layout generation for the feature placer. The widget builds the layout,
-- draws it as ghosts and sends the same list of placements to the gadget, so the
-- preview and the result agree by construction.
--
-- Two stages:
--   * generateLocal(): brush-relative layout, deterministic for (seed, params),
--     so it can be cached while the cursor moves without reshuffling.
--   * resolve(): moves the layout to a world position and applies the terrain
--     filters, which need the brush centre. Cheap enough to run per frame.
--
-- Containment uses common/brush_shapes.lua, the module the brush outline is drawn
-- from, so features land inside the shape the user sees. The terrain filters are
-- common/smart_filter.lua, the test every brush tool's overlay draws.

local BrushShapes = require("common/brush_shapes")
local SmartFilter = require("common/smart_filter")
local isInside = BrushShapes.isInside
local passesSmartFilter = SmartFilter.passes

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
-- Own generator rather than math.random: the layout must be reproducible from a
-- seed, and reseeding the shared math.random stream would disturb other code.
--
-- Recoil builds Lua with LUA_NUMBER = float, so integers are exact only up to
-- 2^24. A 32-bit LCG overflows that and collapses to a handful of outputs.
-- Wichmann-Hill's multiplies peak at 172 * 30306 = 5212632 (exact), and its
-- period is still around 7e12.
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
-- Orbits a brush-local offset as the brush rotates. The sign matches the engine
-- heading convention (heading h faces (sin h, 0, cos h)), so offsets turn the
-- same way as the models. The textbook (x*c - z*s, x*s + z*c) is the mirror and
-- makes the group counter-rotate.
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
-- Scale variation
----------------------------------------------------------------
-- Bottom-heavy roll (t^1.5): most features near scaleMin, a thin tail toward
-- scaleMax, like a natural stand with many small trees and few large ones.
local function rollScale(rng, smin, smax)
	smin = smin or 1
	smax = smax or smin
	if smax <= smin then
		return smin
	end
	local t = rng:next()
	t = t * sqrt(t)
	return smin + (smax - smin) * t
end

----------------------------------------------------------------
-- Tilt variation
----------------------------------------------------------------
-- A lean of up to maxDeg in a random direction, as pitch and roll in radians for
-- SetFeatureRotation. The squared draw keeps most features near upright. The
-- direction splits over pitch and roll like the placer gadget's wobble.
-- Returns 0, 0 without touching the rng when maxDeg is 0, so untilted layouts
-- keep the same random sequence.
local function rollTilt(rng, maxDeg)
	if not maxDeg or maxDeg <= 0 then
		return 0, 0
	end
	local t = rng:next()
	local lean = maxDeg * t * t * pi / 180
	local dir = rng:next() * 2 * pi
	return lean * cos(dir), lean * sin(dir)
end

----------------------------------------------------------------
-- Distribution: random
----------------------------------------------------------------
local function generateRandom(radius, shape, lengthScale, count, rng)
	---@type table<integer, table>
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
	---@type table<integer, table>
	local positions = {}
	for i = 0, count - 1 do
		local r = radius * sqrt(i / max(1, count - 1))
		local theta = i * GOLDEN_ANGLE
		positions[#positions + 1] = { r * cos(theta), r * sin(theta) }
	end
	return positions
end

local function generateSquareGrid(radius, count, lengthScale)
	---@type table<integer, table>
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
	---@type table<integer, table>
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
-- Most features spawn at a Gaussian offset from random clump centres, the rest
-- (clump.loose, default 25%) scatter freely. A minimum separation from the
-- selected defs' radii stops overlaps. With a scale range, features near a clump
-- centre roll larger, and pair spacing follows both features' scales.
--
-- `spacingOverride` replaces the def-derived separation for callers whose names
-- are not features (the unit placer scatters units, sized by footprint).
--
-- `clump` (optional) shapes the stand; omitted fields give the plain layout:
--   count    number of clumps, 0 = auto (about 0.7 * sqrt of the count, 2..6)
--   size     clump spread multiplier (1 = radius / clumps * 1.2)
--   loose    fraction of features scattered between the clumps (0.25)
--   variety  0..1, how unlike each other the clumps are: per clump a share of
--            the features (dense vs sparse), a spread, and an age that shifts
--            its size range (a young clump of saplings next to an old grove)
local function generateClustered(
	radius,
	shape,
	lengthScale,
	count,
	defNames,
	rng,
	scaleMin,
	scaleMax,
	spacingOverride,
	clump
)
	scaleMin = scaleMin or 1
	scaleMax = scaleMax or 1
	clump = clump or {}
	local clumpCount = floor(tonumber(clump.count) or 0)
	local clumpSize = max(0.05, tonumber(clump.size) or 1)
	local looseFrac = max(0, min(1, tonumber(clump.loose) or 0.25))
	local variety = max(0, min(1, tonumber(clump.variety) or 0))
	---@type number
	local minSpacing = 4
	if spacingOverride then
		minSpacing = spacingOverride
	else
		for i = 1, #defNames do
			local def = FeatureDefNames[defNames[i]]
			if def and def.radius and def.radius > minSpacing then
				minSpacing = def.radius
			end
		end
		minSpacing = minSpacing * 1.4
	end

	-- Guarantee the Poisson-disk capacity can actually fit `count`, or the
	-- rejection loop burns its whole budget and returns short.
	local capacity = 0.5 * (radius / max(1, minSpacing)) ^ 2
	if capacity < count then
		minSpacing = radius / sqrt(count * 2)
	end
	minSpacing = max(4, minSpacing)

	local numClusters = clumpCount
	if numClusters <= 0 then
		numClusters = max(2, min(6, floor(sqrt(count) * 0.7 + 0.5)))
	end
	---@class ScatterClump
	---@field [1] number centre x
	---@field [2] number centre z
	---@field weight number? share of the features (variety on only)
	---@field spread number? sigma multiplier (variety on only)
	---@field age number? 0 young (small) .. 1 old (large) (variety on only)

	---@type ScatterClump[]
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

	local sigma = radius / max(1, #clusterCenters) * 1.2 * clumpSize

	-- Per-clump character. Rolled only when variety is on, so a zero-variety
	-- layout keeps the same random sequence for a given seed.
	---@type number
	local totalWeight = #clusterCenters
	if variety > 0 then
		totalWeight = 0
		for _, cc in ipairs(clusterCenters) do
			-- Squared roll: most clumps sparse, a few dense, like real stands.
			local w = rng:next()
			local weight = 1 + variety * (0.1 + 3 * w * w - 1)
			cc.weight = weight
			cc.spread = 1 + variety * (0.4 + rng:next() * 1.4 - 1)
			cc.age = rng:next()
			totalWeight = totalWeight + weight
		end
	end

	local hasScale = scaleMax > scaleMin
	local scaleRange = scaleMax - scaleMin

	---@type table<integer, table>
	local positions = {}
	local maxAttempts = count * 15
	local tries = 0

	while #positions < count and tries < maxAttempts do
		tries = tries + 1
		local px, pz, ps
		local valid = false

		if rng:next() < looseFrac then
			local rx = (rng:next() * 2 - 1) * radius
			local rz = (rng:next() * 2 - 1) * radius * lengthScale
			if insideLocal(rx, rz, radius, shape, lengthScale) then
				px, pz = rx, rz
				ps = hasScale and rollScale(rng, scaleMin, scaleMax) or scaleMin
				valid = true
			end
		else
			-- Box-Muller for a normally-distributed offset from a nucleus.
			-- (never empty: a single centre is added above when none fit)
			local cc = clusterCenters[#clusterCenters] --[[@as ScatterClump]]
			if variety > 0 then
				local pick = rng:next() * totalWeight
				for _, c in ipairs(clusterCenters) do
					cc = c
					pick = pick - (c.weight or 1)
					if pick <= 0 then
						break
					end
				end
			else
				cc = clusterCenters[rng:int(1, #clusterCenters)] --[[@as ScatterClump]]
			end
			local ccSigma = sigma * (cc.spread or 1)
			local u1 = max(1e-7, rng:next())
			local mag = ccSigma * sqrt(-2 * log(u1))
			local ang = rng:next() * TAU
			px, pz = cc[1] + mag * cos(ang), cc[2] + mag * sin(ang)
			valid = insideLocal(px, pz, radius, shape, lengthScale)
			if valid then
				if hasScale then
					-- Core of the clump = big, fringe = small, plus jitter so the
					-- gradient does not read as concentric rings.
					local closeness = 1.0 - min(1.0, mag / (ccSigma * 1.5))
					local t = closeness + (rng:next() - 0.5) * 0.4
					if cc.age then
						-- An old clump leans large, a young one small.
						t = t + (cc.age - 0.5) * variety * 1.2
					end
					t = max(0, min(1, t))
					ps = scaleMin + scaleRange * t
				else
					-- fixed scale (min == max): every feature the same size
					ps = scaleMin
				end
			end
		end

		if valid then
			local tooClose = false
			for i = 1, #positions do
				local ddx, ddz = px - positions[i][1], pz - positions[i][2]
				-- Pair spacing follows the two features' scales, fixed or rolled; unscaled
				-- layouts have ps = 1 and keep the def-derived spacing.
				local need = minSpacing * 0.5 * (ps + positions[i][3])
				if ddx * ddx + ddz * ddz < need * need then
					tooClose = true
					break
				end
			end
			if not tooClose then
				positions[#positions + 1] = { px, pz, ps }
			end
		end
	end

	return positions
end

----------------------------------------------------------------
-- Public: layout generation
----------------------------------------------------------------
---Build a brush-relative layout. Deterministic for a given (seed, params).
---@param params table shape, radius, rotation, count, distribution, rotRandom, tiltRandom (max lean, degrees), defNames, lengthScale, scaleMin, scaleMax, minSpacing (clustered: replaces the FeatureDefNames radius), clumps, clumpSize, clumpLoose, clumpVariety (clustered, see generateClustered)
---@param seed number
---@return table layout array of { dx, dz, defName, heading, scale, pitch, roll }
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
	local scaleMin = params.scaleMin or 1
	local scaleMax = params.scaleMax or 1
	if scaleMax < scaleMin then
		scaleMin, scaleMax = scaleMax, scaleMin
	end
	-- Entries carry a scale only when the brush scale is not 1, so an unscaled
	-- map's wire traffic and save files stay byte-identical.
	local hasScale = scaleMin ~= 1 or scaleMax ~= 1

	local positions
	if distribution == "regular" then
		positions = generateRegular(radius, shape, lengthScale, count, rng)
	elseif distribution == "clustered" then
		positions = generateClustered(
			radius,
			shape,
			lengthScale,
			count,
			defNames,
			rng,
			scaleMin,
			scaleMax,
			tonumber(params.minSpacing),
			{
				count = params.clumps,
				size = params.clumpSize,
				loose = params.clumpLoose,
				variety = params.clumpVariety,
			}
		)
	else
		positions = generateRandom(radius, shape, lengthScale, count, rng)
	end

	-- Rotate the layout into the brush's orientation and assign per-feature
	-- def and heading. Headings are rolled here, not at resolve time, so a
	-- feature keeps its orientation while the cursor moves.
	local angleDeg = params.rotation or 0
	local baseHeading = floor((angleDeg / 360) * 65536) % 65536
	local spread = floor((params.rotRandom or 100) / 100 * 32768)
	local tiltMax = params.tiltRandom or 0
	local numDefs = #defNames

	local layout = {}
	for i = 1, #positions do
		local wx, wz = rotatePoint(positions[i][1], positions[i][2], angleDeg)
		-- Clustered rolled its scales during generation (clump-correlated); the
		-- other distributions roll here.
		local s = nil
		if hasScale then
			s = positions[i][3] or rollScale(rng, scaleMin, scaleMax)
		end
		local entry = {
			dx = wx,
			dz = wz,
			defName = defNames[rng:int(1, numDefs)],
			heading = (baseHeading + rng:int(-spread, spread)) % 65536,
			scale = s,
		}
		entry.pitch, entry.roll = rollTilt(rng, tiltMax)
		layout[#layout + 1] = entry
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
---@return table placements array of { defName, x, y, z, heading, pitch, roll, scale }
--
-- `extraRotDeg` is for symmetry copies: each copy's rotation differs from the
-- brush's own (radial 360/N, mirrored twice the mirror angle), and the layout was
-- only rotated by the base rotation, so the difference is applied here to keep
-- each copy inside its drawn outline.
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

	local smart = params.smartEnabled and params.smartFilters or nil

	for i = 1, #layout do
		local entry = layout[i]
		local dx, dz = entry.dx, entry.dz
		if rotateCopy then
			dx, dz = rotatePoint(dx, dz, extraRotDeg)
		end
		local x = max(0, min(mapX, centerX + dx))
		local z = max(0, min(mapZ, centerZ + dz))
		local y = GetGroundHeight(x, z)

		if not smart or passesSmartFilter(x, z, smart, y) then
			placements[#placements + 1] = {
				defName = entry.defName,
				x = x,
				y = y,
				z = z,
				heading = (entry.heading + headingOffset) % 65536,
				pitch = entry.pitch or 0,
				roll = entry.roll or 0,
				scale = entry.scale,
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
	rollScale = rollScale,
	rollTilt = rollTilt,
}
