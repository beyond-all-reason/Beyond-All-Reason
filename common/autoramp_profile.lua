-- autoramp_profile.lua
-- Pure autoramp terrain computation, shared by the synced gadget (which applies
-- it to the heightmap at full resolution) and the unsynced widget (which runs
-- it on a coarser grid to draw the WYSIWYG hover preview). No Spring height
-- writes, no GL, no math.random — all randomness comes from the seeded
-- permutation table, so both consumers and every client agree bit-for-bit.
--
-- Pipeline (one call, footprint = brush circle):
--   1. read original heights into a window grid via opts.getHeight
--   2. steepest ascent/descent march from the click → hTop / hBot, plus the
--      march path length → the original cliff's representative slope
--   3. signed chamfer distance d from the (h == hMid) iso-contour
--   4. anchor shift dOff from opts.startMode:
--        "average"  — face pivots on the mid contour (bites half / spills half)
--        "extend"   — top lip preserved: the face spills outward over the low
--                     side, never biting into the mesa top
--        "subtract" — bottom lip preserved: the face carves into the mesa,
--                     never burying the low side
--   5. per cell: face = hMid + softCap((dPerturbed - dOff) * tan(angle)),
--      blended by contour-band and brush-ring weights, minus ridged gullies,
--      plus the talus wedge
--
-- compute(opts) -> result table, or nil + reason ("no_cliff" | "no_span" |
-- "no_contour"). Result:
--   { n, ox, oz, cellSize, orig = {..}, newH = {..}, hTop, hBot, hMid }
-- Arrays are dense [iz*n+ix+1]; nil = off-map. newH == orig where unchanged.

local M = {}

local floor = math.floor
local abs = math.abs
local min = math.min
local max = math.max
local sqrt = math.sqrt
local tan = math.tan
local pi = math.pi

-- ── Seeded noise (self-contained copy of the brush's perlin/fbm/ridged) ──────
local cachedPerm = nil
local cachedPermSeed = nil

local function buildPermTable(seed)
	seed = seed or 0
	if cachedPerm and cachedPermSeed == seed then
		return cachedPerm
	end
	local perm = cachedPerm or {}
	for i = 0, 255 do
		perm[i] = i
	end
	local s = seed
	for i = 255, 1, -1 do
		s = (s * 1103515245 + 12345) % 2147483648
		local j = s % (i + 1)
		perm[i], perm[j] = perm[j], perm[i]
	end
	for i = 0, 255 do
		perm[i + 256] = perm[i]
	end
	cachedPerm = perm
	cachedPermSeed = seed
	return perm
end

local function fade(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(t, a, b)
	return a + t * (b - a)
end

local function grad2d(hash, x, y)
	local h = hash % 4
	if h == 0 then
		return x + y
	elseif h == 1 then
		return -x + y
	elseif h == 2 then
		return x - y
	else
		return -x - y
	end
end

local function perlinNoise2D(x, y, perm)
	local xi = floor(x) % 256
	local yi = floor(y) % 256
	local xf = x - floor(x)
	local yf = y - floor(y)
	local u = fade(xf)
	local v = fade(yf)
	local aa = perm[perm[xi] + yi]
	local ab = perm[perm[xi] + yi + 1]
	local ba = perm[perm[xi + 1] + yi]
	local bb = perm[perm[xi + 1] + yi + 1]
	return lerp(
		v,
		lerp(u, grad2d(aa, xf, yf), grad2d(ba, xf - 1, yf)),
		lerp(u, grad2d(ab, xf, yf - 1), grad2d(bb, xf - 1, yf - 1))
	)
end

local function fbmNoise(x, y, perm, octaves, persistence, lacunarity)
	local total = 0
	local amplitude = 1
	local frequency = 1
	local maxVal = 0
	for _ = 1, octaves do
		total = total + perlinNoise2D(x * frequency, y * frequency, perm) * amplitude
		maxVal = maxVal + amplitude
		amplitude = amplitude * persistence
		frequency = frequency * lacunarity
	end
	return total / maxVal
end

local function ridgedNoise(x, y, perm, octaves, persistence, lacunarity)
	local total = 0
	local amplitude = 1
	local frequency = 1
	local maxVal = 0
	for _ = 1, octaves do
		local val = perlinNoise2D(x * frequency, y * frequency, perm)
		val = 1 - abs(val)
		val = val * val
		total = total + val * amplitude
		maxVal = maxVal + amplitude
		amplitude = amplitude * persistence
		frequency = frequency * lacunarity
	end
	return total / maxVal
end

-- softCap(v, cap, k): identity far below cap, flattens onto cap over the last
-- k units with C1 continuity (quadratic smooth-min).
local function softCap(v, cap, k)
	local d = cap - v
	if d >= k then
		return v
	end
	if d <= -k then
		return cap
	end
	local t = (d + k) / (2 * k)
	return cap - k * t * t
end

-- Minimum cliff height (elmos) worth restyling; fixed in world units so the
-- coarse preview grid and the full-resolution apply agree on rejection.
local MIN_SPAN = 12

function M.compute(opts)
	local cellSize = opts.cellSize
	local mapSizeX = opts.mapSizeX
	local mapSizeZ = opts.mapSizeZ
	local getHeight = opts.getHeight
	local centerX = opts.centerX
	local centerZ = opts.centerZ
	local radius = opts.radius
	local angleDeg = opts.angleDeg
	local falloffK = opts.falloffK
	local edgeNoiseK = opts.edgeNoiseK
	local erosionK = opts.erosionK
	local talusK = opts.talusK
	local seed = opts.seed
	local startMode = opts.startMode or "average"

	local tanA = tan(angleDeg * pi / 180)

	local half = floor(radius / cellSize + 0.5)
	if half < 4 then
		half = 4
	end
	local n = half * 2 + 1
	local ccx = floor(centerX / cellSize + 0.5)
	local ccz = floor(centerZ / cellSize + 0.5)
	local ox = ccx - half -- world cell of window column 0
	local oz = ccz - half

	-- 1) Original heights. nil = off-map; barriers for the distance transform.
	local h = {}
	for iz = 0, n - 1 do
		local z = (oz + iz) * cellSize
		if z >= 0 and z <= mapSizeZ then
			local rowBase = iz * n
			for ix = 0, n - 1 do
				local x = (ox + ix) * cellSize
				if x >= 0 and x <= mapSizeX then
					h[rowBase + ix + 1] = getHeight(x, z)
				end
			end
		end
	end

	-- 2) Probe: the march starts at the steep cell NEAREST the click anywhere
	-- inside the brush circle — the click itself does not need to land on the
	-- face (top-down camera over a mesa, face on the far side, etc.). If no
	-- cell within the radius is steep enough, there is no cliff to restyle.
	local function cellSlopeAt(ix, iz)
		local i = iz * n + ix + 1
		local hc = h[i]
		if not hc then
			return 0
		end
		local s = 0
		if ix > 0 and h[i - 1] then
			local dv = abs(hc - h[i - 1])
			if dv > s then
				s = dv
			end
		end
		if ix < n - 1 and h[i + 1] then
			local dv = abs(hc - h[i + 1])
			if dv > s then
				s = dv
			end
		end
		if iz > 0 and h[i - n] then
			local dv = abs(hc - h[i - n])
			if dv > s then
				s = dv
			end
		end
		if iz < n - 1 and h[i + n] then
			local dv = abs(hc - h[i + n])
			if dv > s then
				s = dv
			end
		end
		return s / cellSize
	end

	local MIN_PROBE_SLOPE = 0.25 -- ~14°: below this a cell doesn't count as cliff
	local radiusSq = radius * radius
	local bestIx, bestIz, bestDistSq
	for iz = 0, n - 1 do
		local dz = (iz - half) * cellSize
		for ix = 0, n - 1 do
			local dx = (ix - half) * cellSize
			local dSq = dx * dx + dz * dz
			if dSq < radiusSq and (not bestDistSq or dSq < bestDistSq) then
				if cellSlopeAt(ix, iz) >= MIN_PROBE_SLOPE then
					bestIx, bestIz, bestDistSq = ix, iz, dSq
				end
			end
		end
	end
	if not bestIx then
		return nil, "no_cliff"
	end

	-- Steepest ascent/descent march to the plateau heights. Returns the plateau
	-- height and the EUCLIDEAN start→stop distance: the walk itself zigzags on
	-- noisy faces, and using its accumulated path length made real cliffs read
	-- 2–3x gentler than they are, flipping the extend/subtract anchor direction.
	local function march(dirUp)
		local ix, iz = bestIx, bestIz
		local cur = h[iz * n + ix + 1]
		local flatGain = cellSize * 0.176 -- tan(10°) per axial step
		for _ = 1, n do
			local bx, bz, bh
			for dz = -1, 1 do
				for dx = -1, 1 do
					if dx ~= 0 or dz ~= 0 then
						local jx, jz = ix + dx, iz + dz
						if jx >= 0 and jx < n and jz >= 0 and jz < n then
							local hn = h[jz * n + jx + 1]
							if hn and ((dirUp and hn > (bh or cur)) or (not dirUp and hn < (bh or cur))) then
								bx, bz, bh = jx, jz, hn
							end
						end
					end
				end
			end
			if not bx then
				break
			end
			local gain = abs(bh - cur)
			local stepCells = (bx ~= ix and bz ~= iz) and 1.41421 or 1
			ix, iz, cur = bx, bz, bh
			if gain < flatGain * stepCells then
				break -- slope fell below ~10°: plateau reached
			end
		end
		local ddx = (ix - bestIx) * cellSize
		local ddz = (iz - bestIz) * cellSize
		return cur, sqrt(ddx * ddx + ddz * ddz)
	end

	local hTop, lenUp = march(true)
	local hBot, lenDown = march(false)
	local span = hTop - hBot
	if span < MIN_SPAN then
		return nil, "no_span"
	end
	local hMid = (hTop + hBot) * 0.5

	-- 3) Signed chamfer distance from the hMid iso-contour of the ORIGINAL
	-- heights. Positive above the mid line, negative below.
	local INF = 1e9
	local dist = {}
	local dSign = {}
	for iz = 0, n - 1 do
		local rowBase = iz * n
		for ix = 0, n - 1 do
			local i = rowBase + ix + 1
			local hv = h[i]
			if hv then
				dSign[i] = (hv >= hMid) and 1 or -1
				dist[i] = INF
			end
		end
	end
	local contourFound = false
	for iz = 0, n - 1 do
		local rowBase = iz * n
		for ix = 0, n - 1 do
			local i = rowBase + ix + 1
			local s = dSign[i]
			if s then
				if
					(ix > 0 and dSign[i - 1] and dSign[i - 1] ~= s)
					or (ix < n - 1 and dSign[i + 1] and dSign[i + 1] ~= s)
					or (iz > 0 and dSign[i - n] and dSign[i - n] ~= s)
					or (iz < n - 1 and dSign[i + n] and dSign[i + n] ~= s)
				then
					dist[i] = cellSize * 0.5
					contourFound = true
				end
			end
		end
	end
	if not contourFound then
		return nil, "no_contour"
	end
	local D1 = cellSize
	local D2 = cellSize * 1.41421
	for iz = 0, n - 1 do
		local rowBase = iz * n
		for ix = 0, n - 1 do
			local i = rowBase + ix + 1
			local dv = dist[i]
			if dv then
				if ix > 0 and dist[i - 1] and dist[i - 1] + D1 < dv then
					dv = dist[i - 1] + D1
				end
				if iz > 0 then
					local j = i - n
					if dist[j] and dist[j] + D1 < dv then
						dv = dist[j] + D1
					end
					if ix > 0 and dist[j - 1] and dist[j - 1] + D2 < dv then
						dv = dist[j - 1] + D2
					end
					if ix < n - 1 and dist[j + 1] and dist[j + 1] + D2 < dv then
						dv = dist[j + 1] + D2
					end
				end
				dist[i] = dv
			end
		end
	end
	for iz = n - 1, 0, -1 do
		local rowBase = iz * n
		for ix = n - 1, 0, -1 do
			local i = rowBase + ix + 1
			local dv = dist[i]
			if dv then
				if ix < n - 1 and dist[i + 1] and dist[i + 1] + D1 < dv then
					dv = dist[i + 1] + D1
				end
				if iz < n - 1 then
					local j = i + n
					if dist[j] and dist[j] + D1 < dv then
						dv = dist[j] + D1
					end
					if ix < n - 1 and dist[j + 1] and dist[j + 1] + D2 < dv then
						dv = dist[j + 1] + D2
					end
					if ix > 0 and dist[j - 1] and dist[j - 1] + D2 < dv then
						dv = dist[j - 1] + D2
					end
				end
				dist[i] = dv
			end
		end
	end

	-- 4) Anchor + tunables. All derive from the brush radius and cliff span so
	-- the look scales with the feature being edited.
	local perm = buildPermTable(seed)
	local capT = hTop - hMid -- > 0
	local capB = hMid - hBot -- > 0
	local dTop = capT / tanA -- new face half-width above the mid line
	local dBot = capB / tanA

	-- Original cliff slope from the march: anchors extend/subtract so the
	-- preserved lip sits where the ORIGINAL face met its plateau.
	local tanOrig = span / max(cellSize, lenUp + lenDown)
	if tanOrig < 0.15 then
		tanOrig = 0.15
	elseif tanOrig > 20 then
		tanOrig = 20
	end
	local dOff = 0
	if startMode == "extend" then
		dOff = capT / tanOrig - dTop -- new top lip lands on the original top lip
	elseif startMode == "subtract" then
		dOff = dBot - capB / tanOrig -- new bottom lip lands on the original bottom lip
	end

	local shoulderT = max(cellSize, capT * (0.15 + 0.85 * falloffK)) -- soft-clamp knee (height units)
	local shoulderB = max(cellSize, capB * (0.15 + 0.85 * falloffK))
	local dFaceT = dTop + shoulderT / tanA
	local dFaceB = dBot + shoulderB / tanA
	local blendLen = max(cellSize * 2, falloffK * radius * 0.35)
	local edgeAmp = edgeNoiseK * radius * 0.22
	local edgeScale = max(48, radius * 0.45)
	local grooveScale = max(24, radius * 0.12)
	local grooveDepth = erosionK * span * 0.16
	-- Talus is a DEPOSITION SURFACE, not an additive wedge: a concave scree
	-- cone leaning on the face base at the natural angle of repose, composited
	-- with max() so repeated clicks converge onto it instead of stacking.
	local talusHeight = talusK * span * 0.45 -- pile height where it leans on the face
	local TAN_REPOSE = 0.62 -- ~32°, natural scree repose slope
	local talusLen = max(cellSize * 3, talusHeight / TAN_REPOSE) -- fan run-out length
	local talusNScale = max(24, radius * 0.18) -- lobe wavelength along the fan
	local rimIn = radius * 0.72 -- brush-ring blend start
	local rimSpan = radius - rimIn
	local rejHi = dOff + dFaceT + blendLen + edgeAmp
	local rejLo = dOff - (max(dFaceB + blendLen, dBot + talusLen) + edgeAmp)

	local newH = {}

	for iz = 0, n - 1 do
		local rowBase = iz * n
		local z = (oz + iz) * cellSize
		for ix = 0, n - 1 do
			local i = rowBase + ix + 1
			local orig = h[i]
			local dRaw = orig and dist[i]
			if orig then
				newH[i] = orig
			end
			if dRaw and dRaw < INF then
				local x = (ox + ix) * cellSize
				local dx = x - centerX
				local dz = z - centerZ
				local r = sqrt(dx * dx + dz * dz)
				local d = dRaw * dSign[i]
				if r < radius and d < rejHi and d > rejLo then
					local wRing = 1
					if r > rimIn then
						local t = (r - rimIn) / rimSpan
						wRing = 1 - t * t * (3 - 2 * t)
					end
					-- Wavy lips: perturb the across-face coordinate, which shifts
					-- the face, the shoulders and the talus line together.
					local dn = d
					if edgeAmp > 0 then
						dn = d + fbmNoise(x / edgeScale, z / edgeScale, perm, 3, 0.5, 2.0) * edgeAmp
					end
					local ds = dn - dOff -- face-relative across coordinate
					local v = ds * tanA
					if v >= 0 then
						v = softCap(v, capT, shoulderT)
					else
						v = -softCap(-v, capB, shoulderB)
					end
					local target = hMid + v
					-- Hard mode guarantee, independent of how well the anchor was
					-- estimated: extend only ever raises terrain, subtract only
					-- ever lowers it. (Gullies and talus still texture on top.)
					if startMode == "extend" then
						if target < orig then
							target = orig
						end
					elseif startMode == "subtract" then
						if target > orig then
							target = orig
						end
					end
					-- Band weight: full on the face, fades into untouched plateau.
					local aw = (ds >= 0) and (ds - dFaceT) or (-ds - dFaceB)
					local wBand = 1
					if aw > 0 then
						if aw >= blendLen then
							wBand = 0
						else
							local t = aw / blendLen
							wBand = 1 - t * t * (3 - 2 * t)
						end
					end
					-- Gullies: ridged noise stretched along the original downslope
					-- direction reads as erosion channels cut into the face.
					if grooveDepth > 0 and wBand > 0 then
						local gx, gz = 0, 0
						if ix > 0 and ix < n - 1 and h[i - 1] and h[i + 1] then
							gx = h[i + 1] - h[i - 1]
						end
						if iz > 0 and iz < n - 1 and h[i - n] and h[i + n] then
							gz = h[i + n] - h[i - n]
						end
						local gm = sqrt(gx * gx + gz * gz)
						if gm > 0.5 then
							gx, gz = gx / gm, gz / gm
							local u = (-gz * x + gx * z) / grooveScale
							local w = (gx * x + gz * z) / (grooveScale * 3.5)
							local rg = ridgedNoise(u, w, perm, 3, 0.5, 2.0)
							local capSide = (v >= 0) and capT or capB
							local faceMask = 0
							if capSide > 1 then
								faceMask = 1 - min(1, abs(v) / capSide)
							end
							target = target - grooveDepth * rg * faceMask * wBand
						end
					end
					local out = orig + (target - orig) * wBand
					-- Talus: raise the ground onto the scree deposition surface where
					-- that surface is higher. u runs 0 at the fan's outer edge → 1
					-- at the face base; u^1.6 gives the concave profile of settled
					-- debris (steep against the cliff, feathering to zero slope at
					-- the run-out), fbm lobes break the fan into natural tongues,
					-- and the cap keeps it below the mid line. max() compositing
					-- makes repeated clicks converge instead of stacking material.
					if talusHeight > 0 then
						local u = (ds + dBot + talusLen) / talusLen
						if u > 0 then
							if u > 1.35 then
								u = 1.35 -- scree may lean partway up the face
							end
							local tn = fbmNoise(x / talusNScale + 313.7, z / talusNScale - 157.3, perm, 2, 0.5, 2.0)
							local surf = hBot + talusHeight * (u ^ 1.6) * (0.75 + 0.45 * tn)
							local capH = hMid - span * 0.05
							if surf > capH then
								surf = capH
							end
							if surf > out then
								out = surf
							end
						end
					end
					newH[i] = orig + (out - orig) * wRing
				end
			end
		end
	end

	return {
		n = n,
		ox = ox,
		oz = oz,
		cellSize = cellSize,
		orig = h,
		newH = newH,
		hTop = hTop,
		hBot = hBot,
		hMid = hMid,
	}
end

return M
