-- cmd_terraform_brush_mapgen.lua
-- Procedural starting-map generator for the Terraform Brush "New Map" feature.
--
-- The Recoil engine's blank-map generator can only emit a dead-flat plane
-- (verified: BlankMapGenerator.cpp sets minHeight==maxHeight). So all terrain is
-- produced HERE in Lua and stamped onto the freshly-reloaded flat map through the
-- existing synced import path (cmd_terraform_brush.lua streams columns to the
-- gadget, which calls Spring.SetHeightMap). Water is not a separate system: the
-- engine renders the water plane at world height 0, so seas/lakes are simply
-- heightmap regions carved below 0.
--
-- This module is PURE (no widget globals, no GL, no Spring height writes). It
-- returns the `columns` array shaped exactly like the importer's importHeightRows:
--   columns[i][j] = ground height (elmos) at world (x=(i-1)*sq, z=(j-1)*sq)
-- plus an `info` table (spawns, metal spots, stats) for the apply step.
--
-- Fairness: every symmetry mode folds the heightmap, the spawn pads, and the
-- metal spots through the SAME transform, so symmetric maps are pixel-exact
-- symmetric (symmetryScore == 0), not merely approximately so.

local M = {}

local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt
local sin = math.sin
local min = math.min
local max = math.max
local abs = math.abs

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function clamp(v, lo, hi)
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	else
		return v
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Smoothstep in [0,1] over [e0,e1].
local function smoothstep(e0, e1, x)
	if e1 <= e0 then
		return x >= e1 and 1 or 0
	end
	local t = clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Deterministic 2D hash in [0,1). Classic fract(sin(dot)) hash: cheap, seedable,
-- good enough for terrain value-noise. Seed perturbs the lattice.
local function hash2(ix, iy, seed)
	local n = ix * 127.1 + iy * 311.7 + seed * 0.017
	local s = sin(n) * 43758.5453123
	return s - floor(s)
end

-- Value noise with smoothstep interpolation; returns [0,1].
local function valueNoise(x, y, seed)
	local x0 = floor(x)
	local y0 = floor(y)
	local fx = x - x0
	local fy = y - y0
	local v00 = hash2(x0, y0, seed)
	local v10 = hash2(x0 + 1, y0, seed)
	local v01 = hash2(x0, y0 + 1, seed)
	local v11 = hash2(x0 + 1, y0 + 1, seed)
	local sx = fx * fx * (3 - 2 * fx)
	local sy = fy * fy * (3 - 2 * fy)
	local a = v00 + (v10 - v00) * sx
	local b = v01 + (v11 - v01) * sx
	return a + (b - a) * sy
end

-- Fractal Brownian motion (sum of octaves), normalized to [0,1].
local function fbm(x, y, seed, octaves, persistence, lacunarity)
	local amp = 1.0
	local freq = 1.0
	local sum = 0.0
	local norm = 0.0
	for o = 1, octaves do
		sum = sum + amp * valueNoise(x * freq, y * freq, seed + o * 101.0)
		norm = norm + amp
		amp = amp * persistence
		freq = freq * lacunarity
	end
	return sum / norm
end

-- ---------------------------------------------------------------------------
-- Symmetry: canonical-cell mapping
--
-- canonical(i,j) returns the representative cell of (i,j)'s symmetry orbit,
-- chosen as the row-major-smallest member. Folding `field[i][j] = field[canon]`
-- in row-major order guarantees the representative is already computed, so one
-- in-place pass produces exact symmetry. Supported: rot180 (default), mirrorx
-- (left/right), mirrorz (top/bottom), rot90 (4-fold; requires a square map).
-- ---------------------------------------------------------------------------

local function makeCanonical(numX, numZ, sym)
	if sym == "none" then
		return function(i, j)
			return i, j
		end -- every cell its own rep -> no folding
	elseif sym == "mirrorx" then
		return function(i, j)
			local pi = numX + 1 - i
			if pi < i then
				return pi, j
			end
			return i, j
		end
	elseif sym == "mirrorz" then
		return function(i, j)
			local pj = numZ + 1 - j
			if pj < j then
				return i, pj
			end
			return i, j
		end
	elseif sym == "rot90" then
		-- 4-fold rotation about the centre; only valid when numX == numZ.
		local n = numX
		return function(i, j)
			local bi, bj = i, j
			-- orbit: (i,j) -> (j, n+1-i) -> (n+1-i, n+1-j) -> (n+1-j, i)
			local ci, cj = j, n + 1 - i
			if ci < bi or (ci == bi and cj < bj) then
				bi, bj = ci, cj
			end
			ci, cj = n + 1 - i, n + 1 - j
			if ci < bi or (ci == bi and cj < bj) then
				bi, bj = ci, cj
			end
			ci, cj = n + 1 - j, i
			if ci < bi or (ci == bi and cj < bj) then
				bi, bj = ci, cj
			end
			return bi, bj
		end
	end
	-- rot180 (point symmetry about centre) — the competitive 1v1 default.
	return function(i, j)
		local pi = numX + 1 - i
		local pj = numZ + 1 - j
		if pi < i or (pi == i and pj < j) then
			return pi, pj
		end
		return i, j
	end
end

-- Forward symmetry transform of a world point (used to fold spawns/metal so they
-- match the heightmap fold). Returns the partner cell of (i,j).
local function symPartners(i, j, numX, numZ, sym)
	if sym == "none" then
		return {} -- asymmetric: no folded partners
	elseif sym == "mirrorx" then
		return { { numX + 1 - i, j } }
	elseif sym == "mirrorz" then
		return { { i, numZ + 1 - j } }
	elseif sym == "rot90" then
		local n = numX
		return {
			{ j, n + 1 - i },
			{ n + 1 - i, n + 1 - j },
			{ n + 1 - j, i },
		}
	end
	return { { numX + 1 - i, numZ + 1 - j } } -- rot180
end

-- ---------------------------------------------------------------------------
-- Parameter mapping (recipe 0..1 sliders -> generator internals)
-- ---------------------------------------------------------------------------

local function mapParams(o)
	local hilliness = clamp(o.hilliness or 0.5, 0, 1)
	local roughness = clamp(o.roughness or 0.5, 0, 1)
	local featureSize = clamp(o.featureScale or 0.5, 0, 1) -- 0 = small features, 1 = big
	local jaggedness = clamp(o.jaggedness or 0.5, 0, 1)
	local waterLevel = clamp(o.waterLevel or 0.0, 0, 0.85)
	local islandness = clamp(o.islandness or 0.0, 0, 1)

	return {
		landAmp = lerp(0, 720, hilliness * hilliness), -- max land height (elmos); 0 at hilliness 0 = dead flat
		waterDepth = lerp(50, 230, clamp(hilliness * 0.7 + 0.25, 0, 1)),
		octaves = floor(lerp(2, 6, roughness) + 0.5),
		persistence = lerp(0.40, 0.62, roughness),
		lacunarity = 2.0,
		-- featureFreq = noise cycles across the LONGER axis (low = big landforms).
		featureFreq = lerp(7.5, 1.6, featureSize),
		exponent = lerp(0.85, 2.7, jaggedness), -- redistribution power
		waterLevel = waterLevel,
		islandness = islandness,
	}
end

-- ---------------------------------------------------------------------------
-- Main generation
--
-- opts (all optional, sensible defaults):
--   numX, numZ      heightmap sample counts (= mapx+1, mapy+1). Derived by the
--                   caller from Game.mapSizeX/Z; required here.
--   squareSize      world elmos per sample (Game.squareSize, default 8)
--   seed            integer
--   hilliness, roughness, featureScale, jaggedness, waterLevel, islandness  [0..1]
--   symmetry        "rot180" | "mirrorx" | "mirrorz" | "rot90"
--   players         desired symmetric spawn count (2 or 4)
--
-- returns columns, info
-- ---------------------------------------------------------------------------

function M.generate(opts)
	opts = opts or {}
	local numX = opts.numX
	local numZ = opts.numZ
	if not numX or not numZ then
		return nil, "mapgen: numX/numZ required"
	end
	local sq = opts.squareSize or 8
	local seed = (opts.seed or 1) % 1000000

	local sym = opts.symmetry or "rot180"
	-- rot90 needs a square sample grid; fall back to rot180 otherwise.
	if sym == "rot90" and numX ~= numZ then
		sym = "rot180"
	end

	local P = mapParams(opts)

	-- --- 1. Noise setup ----------------------------------------------------
	-- cyclesX/Z = fBm cycles across each axis (keeps features isotropic in world
	-- space). We sample fBm DIRECTLY per heightmap cell — value noise already
	-- smoothstep-interpolates so the result is smooth, and every octave is
	-- represented. (A coarse grid + bilinear upsample faceted the terrain into a
	-- visible quad grid and aliased the high-frequency octaves.)
	local maxN = max(numX, numZ)
	local cyclesX = P.featureFreq * (numX / maxN)
	local cyclesZ = P.featureFreq * (numZ / maxN)
	local octaves = P.octaves
	local persistence = P.persistence
	local lacunarity = P.lacunarity

	-- --- 2. Build the shaped+symmetric field at full resolution -------------
	-- field[i][j] = shaped fBm (computed for canonical cells, copied to partners
	-- for exact symmetry). Range is normalized later from fmin/fmax.
	local canonical = makeCanonical(numX, numZ, sym)
	local cxCenter = (numX + 1) * 0.5
	local czCenter = (numZ + 1) * 0.5
	local maxRad = sqrt((numX - cxCenter) ^ 2 + (numZ - czCenter) ^ 2)
	local islandness = P.islandness
	local exponent = P.exponent
	local invX = 1 / (numX - 1)
	local invZ = 1 / (numZ - 1)

	-- Shaped value for a canonical cell: fBm + redistribution + radial island bias.
	local function shapedAt(i, j)
		local s = fbm((i - 1) * invX * cyclesX, (j - 1) * invZ * cyclesZ, seed, octaves, persistence, lacunarity)
		s = s ^ exponent -- redistribution (fBm is [0,1])
		if islandness > 0 then
			local r = sqrt((i - cxCenter) ^ 2 + (j - czCenter) ^ 2) / maxRad
			s = s - islandness * smoothstep(0.55, 1.0, r) -- push edges down -> coastline
		end
		return s
	end

	local field = {}
	local fmin, fmax = math.huge, -math.huge
	for i = 1, numX do
		local col = {}
		field[i] = col
		for j = 1, numZ do
			local ci, cj = canonical(i, j)
			local s
			if ci == i and cj == j then
				s = shapedAt(i, j)
			else
				s = field[ci][cj] -- representative already computed (row-major)
			end
			col[j] = s
			if s < fmin then
				fmin = s
			end
			if s > fmax then
				fmax = s
			end
		end
	end
	local frange = fmax - fmin
	if frange < 1e-6 then
		frange = 1
	end

	-- --- 3. Sea level from the water-coverage percentile -------------------
	-- Histogram the field; sea level q = the waterLevel-quantile. Land sits in
	-- [q, fmax], water in [fmin, q). q maps to world height 0.
	local q
	if P.waterLevel <= 0 then
		q = fmin - 1e-6
	else
		local BINS = 1024
		local hist = {}
		for b = 1, BINS do
			hist[b] = 0
		end
		local total = numX * numZ
		for i = 1, numX do
			local col = field[i]
			for j = 1, numZ do
				local b = floor((col[j] - fmin) / frange * (BINS - 1)) + 1
				if b < 1 then
					b = 1
				elseif b > BINS then
					b = BINS
				end
				hist[b] = hist[b] + 1
			end
		end
		local target = P.waterLevel * total
		local acc = 0
		local qb = 1
		for b = 1, BINS do
			acc = acc + hist[b]
			if acc >= target then
				qb = b
				break
			end
		end
		-- Reconstruct with the SAME (BINS-1) scale the binning used (the lower edge
		-- of bin qb), so the realized water coverage matches the requested fraction.
		q = fmin + ((qb - 1) / (BINS - 1)) * frange
	end

	local landSpan = max(1e-6, fmax - q)
	local waterSpan = max(1e-6, q - fmin)
	local landAmp = P.landAmp
	local waterDepth = P.waterDepth

	-- --- 4. Convert the field to world heights (columns array) --------------
	local columns = {}
	local waterCells = 0
	local hMin, hMax = math.huge, -math.huge
	for i = 1, numX do
		local fcol = field[i]
		local hcol = {}
		columns[i] = hcol
		for j = 1, numZ do
			local s = fcol[j]
			local h
			if s >= q then
				h = ((s - q) / landSpan) * landAmp
			else
				h = -((q - s) / waterSpan) * waterDepth
				waterCells = waterCells + 1
			end
			hcol[j] = h
			if h < hMin then
				hMin = h
			end
			if h > hMax then
				hMax = h
			end
		end
	end

	-- --- 5. Symmetric spawn pads -------------------------------------------
	-- Anchor spawns in normalized coords, fold through the symmetry transform,
	-- nudge inward off deep water, then flatten an identical disc at each so the
	-- spawn ground is buildable and fair.
	local players = opts.players or ((sym == "rot90") and 4 or 2)
	if sym == "rot90" then
		players = 4
	end

	local function cellAt(un, vn)
		return clamp(floor(un * (numX - 1)) + 1, 1, numX), clamp(floor(vn * (numZ - 1)) + 1, 1, numZ)
	end

	-- primary anchor (canonical-region spawn) by symmetry
	local ax, az
	if sym == "mirrorz" then
		ax, az = cellAt(0.5, 0.16)
	elseif sym == "rot90" then
		ax, az = cellAt(0.20, 0.20)
	else -- rot180 / mirrorx -> horizontal duel
		ax, az = cellAt(0.16, 0.5)
	end

	-- Nudge the anchor toward centre until it is above water (keeps it on land).
	do
		local steps = 0
		while columns[ax][az] < 8 and steps < numX do
			ax = clamp(ax + (ax < cxCenter and 1 or -1), 1, numX)
			az = clamp(az + (az < czCenter and 1 or -1), 1, numZ)
			steps = steps + 1
		end
	end

	-- Build the full spawn set. Symmetric modes fold the anchor through the
	-- transform; "none" places a second independent spawn at the opposite side.
	local spawnCells = { { ax, az } }
	if sym == "none" then
		local bx, bz = numX + 1 - ax, numZ + 1 - az
		local steps = 0
		while columns[bx][bz] < 8 and steps < numX do
			bx = clamp(bx + (bx < cxCenter and 1 or -1), 1, numX)
			bz = clamp(bz + (bz < czCenter and 1 or -1), 1, numZ)
			steps = steps + 1
		end
		spawnCells[#spawnCells + 1] = { bx, bz }
	else
		for _, p in ipairs(symPartners(ax, az, numX, numZ, sym)) do
			spawnCells[#spawnCells + 1] = p
		end
	end

	-- Flatten a buildable pad at each spawn. Pad height = MEAN terrain height over
	-- that spawn's own disc, so it blends into local surroundings (minimal cut/fill)
	-- instead of cratering. For symmetric modes the per-spawn means are equal
	-- (mirror-image discs, non-overlapping) so fairness is preserved; for "none"
	-- each spawn levels to its own ground. A flat core eases out over a wide blend.
	local padRadiusCells = clamp(floor(min(numX, numZ) * 0.045), 6, 34)
	local blend = max(6, floor(padRadiusCells * 1.2))
	local r2 = padRadiusCells * padRadiusCells
	-- Pads level to local mean ground. The floor only lifts a spawn clear of the
	-- waterline when the map actually HAS sea; a flat/no-water map keeps floor 0 so
	-- spawns don't sprout 20-elmo bumps on what should be a dead-flat canvas.
	local padFloor = (waterCells > 0) and 20 or 0
	local padHeight = padFloor
	for _, sc in ipairs(spawnCells) do
		local sx, szc = sc[1], sc[2]
		local sum, cnt = 0, 0
		for di = -padRadiusCells, padRadiusCells do
			local i = sx + di
			if i >= 1 and i <= numX then
				for dj = -padRadiusCells, padRadiusCells do
					local j = szc + dj
					if j >= 1 and j <= numZ and (di * di + dj * dj) <= r2 then
						sum = sum + columns[i][j]
						cnt = cnt + 1
					end
				end
			end
		end
		padHeight = max(cnt > 0 and (sum / cnt) or columns[sx][szc], padFloor)
		for di = -padRadiusCells - blend, padRadiusCells + blend do
			local i = sx + di
			if i >= 1 and i <= numX then
				local hcol = columns[i]
				for dj = -padRadiusCells - blend, padRadiusCells + blend do
					local j = szc + dj
					if j >= 1 and j <= numZ then
						local d = sqrt(di * di + dj * dj)
						local t = 1 - smoothstep(padRadiusCells, padRadiusCells + blend, d)
						if t > 0 then
							hcol[j] = hcol[j] + (padHeight - hcol[j]) * t
						end
					end
				end
			end
		end
	end

	-- --- 6. Metal spots ----------------------------------------------------
	-- (a) a flanking spot beside each spawn pad, (b) an expansion field on a
	-- seed-jittered grid, and (c) a contested centre. Each representative is folded
	-- through the SAME symmetry transform as the heightmap (symPartners) so the
	-- layout is exactly fair; "none" places each spot independently. Spots over
	-- water are skipped. Count scales with map size and the metalDensity recipe.
	local metal = {}
	local function addMetalCell(i, j, amount)
		i = floor(i + 0.5)
		j = floor(j + 0.5)
		if i < 1 or i > numX or j < 1 or j > numZ then
			return
		end
		if columns[i][j] < 4 then
			return
		end -- not under water
		metal[#metal + 1] = { x = (i - 1) * sq, z = (j - 1) * sq, amount = amount }
	end
	-- place a representative cell plus its symmetric partners as one fair set
	local function addMetalFair(i, j, amount)
		addMetalCell(i, j, amount)
		for _, p in ipairs(symPartners(floor(i + 0.5), floor(j + 0.5), numX, numZ, sym)) do
			addMetalCell(p[1], p[2], amount)
		end
	end

	-- (a) flanking spot just outside each spawn pad, toward map centre.
	local flankOff = padRadiusCells + blend + 6
	do
		local toCx, toCz = (cxCenter - ax), (czCenter - az)
		local len = max(1e-6, sqrt(toCx * toCx + toCz * toCz))
		addMetalFair(ax + toCx / len * flankOff, az + toCz / len * flankOff, 2.0)
		if sym == "none" and spawnCells[2] then -- second spawn's own flank
			local b = spawnCells[2]
			local tx, tz = (cxCenter - b[1]), (czCenter - b[2])
			local l2 = max(1e-6, sqrt(tx * tx + tz * tz))
			addMetalCell(b[1] + tx / l2 * flankOff, b[2] + tz / l2 * flankOff, 2.0)
		end
	end

	-- (b) expansion field: a jittered grid, one placement per symmetry orbit.
	local density = clamp(opts.metalDensity or 0.5, 0, 1)
	local units = numX / 64
	local gN = clamp(floor(lerp(2.5, 6.0, density) * sqrt(units / 12) + 0.5), 2, 11)
	for gx = 0, gN do
		for gz = 0, gN do
			local jx = (hash2(gx, gz, seed) * 2 - 1) * 0.5
			local jz = (hash2(gx, gz, seed + 31) * 2 - 1) * 0.5
			local u = (gx + 0.5 + jx) / (gN + 1)
			local v = (gz + 0.5 + jz) / (gN + 1)
			local mi = clamp(floor(u * (numX - 1)) + 1, 1, numX)
			local mj = clamp(floor(v * (numZ - 1)) + 1, 1, numZ)
			local ci, cj = canonical(mi, mj)
			if ci == mi and cj == mj then -- one placement per orbit
				addMetalFair(mi, mj, 1.5)
			end
		end
	end

	-- (c) contested centre spot.
	addMetalCell(cxCenter, czCenter, 3.0)

	local info = {
		numX = numX,
		numZ = numZ,
		squareSize = sq,
		seed = seed,
		symmetry = sym,
		players = players,
		minHeight = hMin,
		maxHeight = hMax,
		seaLevel = 0,
		waterPct = (waterCells / (numX * numZ)) * 100,
		padHeight = padHeight,
		spawns = {}, -- world coords {x,z}
		metal = metal,
	}
	for _, sc in ipairs(spawnCells) do
		info.spawns[#info.spawns + 1] = { x = (sc[1] - 1) * sq, z = (sc[2] - 1) * sq }
	end

	return columns, info
end

-- Default recipe (all 0..1 sliders) used by the UI and the randomizer.
function M.defaults()
	return {
		hilliness = 0.5,
		roughness = 0.5,
		featureScale = 0.5,
		jaggedness = 0.45,
		waterLevel = 0.0,
		islandness = 0.0,
		metalDensity = 0.5,
		symmetry = "rot180",
		players = 2,
	}
end

return M
