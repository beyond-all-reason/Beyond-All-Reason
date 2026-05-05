local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Terraform Brush",
		desc = "Raises, lowers, or levels terrain with configurable shape, radius, and rotation. Requires /cheat.",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:RecvFromSynced(name, undoCount, redoCount)
		if name == "TerraformBrushStacks" then
			if Script.LuaUI("TerraformBrushStackUpdate") then
				Script.LuaUI.TerraformBrushStackUpdate(undoCount, redoCount)
			end
		end
	end
	return
end

-- Prefix embedded in messages when cheat was active at send time.
-- During replay, recorded messages retain this prefix, bypassing the
-- live cheat check (which is always false in replay mode).
local CHEAT_SIG = "$c$"
local CHEAT_SIG_LEN = #CHEAT_SIG

local mapDamageEnabled = Game.mapDamage ~= false

local function isTerraformAllowed(certified)
	if not mapDamageEnabled then
		Spring.Echo("[Terraform Brush] Map deformation is disabled (disablemapdamage modoption or notDeformable map). Terraform cannot work.")
		return false
	end
	return Spring.IsCheatingEnabled() or certified
end

local PACKET_HEADER = "$terraform_brush$"
local PACKET_HEADER_LENGTH = #PACKET_HEADER
local RAMP_HEADER = "$terraform_ramp$"
local RAMP_HEADER_LENGTH = #RAMP_HEADER
local SPLINE_RAMP_HEADER = "$terraform_ramp_spline$"
local SPLINE_RAMP_HEADER_LENGTH = #SPLINE_RAMP_HEADER
local RESTORE_HEADER = "$terraform_restore$"
local RESTORE_HEADER_LENGTH = #RESTORE_HEADER
local FULL_RESTORE_HEADER = "$terraform_full_restore$"
local IMPORT_HEADER = "$terraform_import$"
local IMPORT_HEADER_LENGTH = #IMPORT_HEADER
local IMPORT_END_HEADER = "$terraform_import_end$"
local UNDO_HEADER = "$terraform_undo$"
local UNDO_STROKE_HEADER = "$terraform_undo_stroke$"
local REDO_HEADER = "$terraform_redo$"
local MERGE_END_HEADER = "$terraform_merge_end$"
local STROKE_END_HEADER = "$terraform_stroke_end$"
local NOISE_HEADER = "$terraform_noise$"
local NOISE_HEADER_LENGTH = #NOISE_HEADER
local HEIGHT_STEP = 8
local MAX_UNDO = 10000
-- Total vertex budget across all undo+redo entries. Each vertex = 3 array
-- slots (x,z,h) ≈ 24 B in Lua. 8 M vertices ≈ 192 MB, well under the 1.5 GB
-- synced LuaRules VM cap. The previous 32 M cap permitted ~768 MB of pure
-- height data plus heap fragmentation overhead, blowing the VM ceiling on
-- sustained large-radius drags. One-entry-per-tick MUST be preserved (see
-- bar_stripy_terrain_bug.md): any cross-tick merging produces striped
-- leftover terrain on undo, so eviction is the only knob.
local MAX_SNAPSHOT_VERTICES = 8000000

local undoStack = {}
local redoStack = {}
local totalVertexCount = 0  -- track approximate memory usage

-- Active drag session: all pushSnapshot/pushSnapshotFromFlat calls merge into mergeSnapshot until
-- MERGE_END is received (sent by widget on mouse release).  No time window — MERGE_END is authoritative.
local mergeSnapshot = nil      -- the active snapshot being merged into; nil = no drag in progress
local mergeVertexSet = nil     -- set of numeric keys already in mergeSnapshot
local mergeSnapshotLen = 0     -- explicit length of mergeSnapshot (avoids # on growing tables)
local currentStrokeId = 0      -- incremented on each STROKE_END; tags all entries in a stroke
local lastUndoFrame = -1       -- throttle: only one undo per game frame
local MAX_RADIUS = 2000
local MIN_RADIUS = 8

-- ── Diagnostics ──────────────────────────────────────────────────────────────
local DIAG = false  -- set false to silence
local diagPushCount = 0   -- number of pushSnapshotFromFlat calls in current merge
local diagMergeVerts = 0  -- vertices added during merge phase
local ringInnerRatio = 0.6

-- Reusable scratch tables to reduce GC pressure in hot paths
local scratchHeightData = {}
local scratchHeightDataMax = 0  -- high-water mark for reliable trimming (avoids # on reused table)
local scratchSnapFlat = {}  -- flat buffer: x,z,h,x,z,h,... (no sub-table allocation)
local scratchParts = {}

-- Parse a space-separated payload into scratchParts, reusing the table
local function parseParts(payload)
	local idx = 0
	for word in payload:gmatch("[%-%.%w]+") do
		idx = idx + 1
		scratchParts[idx] = word
	end
	-- Clear stale entries from previous parse
	for i = idx + 1, #scratchParts do scratchParts[i] = nil end
	return scratchParts
end

-- Numeric key for merge vertex set: avoids per-vertex string allocation
local function vertexKey(x, z)
	return x * 65536 + z
end

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local abs = math.abs
local pi = math.pi
local atan2 = math.atan2
local random = math.random

local SpawnCEG = Spring.SpawnCEG

-- Apply a batch of {x, z, newHeight} entries to the heightmap.
-- Uses inline anonymous functions for SetHeightMapFunc (engine requirement).
local nanHeightSkipped = false

local function applyHeightChanges(heightData, count)
	count = count or #heightData
	if count == 0 then return end

	Spring.SetHeightMapFunc(function()
		for i = 1, count do
			local h = heightData[i][3]
			if h == h then  -- NaN check: NaN ~= NaN
				Spring.SetHeightMap(heightData[i][1], heightData[i][2], h)
			else
				nanHeightSkipped = true
			end
		end
	end)
	if nanHeightSkipped then
		Spring.Echo("[Terraform Brush] Warning: NaN height skipped — possible div0 in brush math")
		nanHeightSkipped = false
	end
end

-- Flat-buffer variant: reads {x1,z1,h1, x2,z2,h2,...} without sub-tables.
-- Used by undo/redo where snapshots are stored flat to minimise allocations.
local function applyHeightChangesFlat(flatData, vertexCount)
	if vertexCount == 0 then return end
	Spring.SetHeightMapFunc(function()
		for i = 0, vertexCount - 1 do
			local base = i * 3
			local h = flatData[base + 3]
			if h == h then  -- NaN check
				Spring.SetHeightMap(flatData[base + 1], flatData[base + 2], h)
			else
				nanHeightSkipped = true
			end
		end
	end)
	if nanHeightSkipped then
		Spring.Echo("[Terraform Brush] Warning: NaN height skipped in undo/redo")
		nanHeightSkipped = false
	end
end

-- ─── BBOX-GRID SNAPSHOT FORMAT ───────────────────────────────────────────────
-- Snapshots store touched cells as a 2D grid keyed by world bbox rather than
-- a flat triplet array. Mask values:
--   nil : cell not in this snapshot
--   1   : cell touched, original height stored in hgrid[i]
--   2   : cell touched, original height equals Spring.GetGroundOrigHeight
--         (hgrid[i] not stored — saves a float on virgin terrain edits)
-- Index: i = iz*w + ix + 1 with ix=(x-minX)/ss, iz=(z-minZ)/ss.
-- ss = Game.squareSize captured at conversion time and stored in snap.ss
-- so undo years later still maps cells back to the same world coords.
local GetGroundOrigHeight = Spring.GetGroundOrigHeight
local GetGroundHeight     = Spring.GetGroundHeight
local SetHeightMap        = Spring.SetHeightMap
local SetHeightMapFunc    = Spring.SetHeightMapFunc

-- Convert a flat {x,z,h, x,z,h, ...} buffer to a bbox-grid snapshot.
-- Two passes: bbox scan, then grid fill with orig-delta optimisation.
local function flatToBboxSnapshot(flatBuf, vertexCount)
	local ss = Game.squareSize
	local minX, minZ = math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge
	for i = 0, vertexCount - 1 do
		local base = i * 3
		local x = flatBuf[base + 1]
		local z = flatBuf[base + 2]
		if x < minX then minX = x end
		if x > maxX then maxX = x end
		if z < minZ then minZ = z end
		if z > maxZ then maxZ = z end
	end
	local w = floor((maxX - minX) / ss) + 1
	local h = floor((maxZ - minZ) / ss) + 1
	local mask, hgrid = {}, {}
	for i = 0, vertexCount - 1 do
		local base = i * 3
		local x = flatBuf[base + 1]
		local z = flatBuf[base + 2]
		local origH = flatBuf[base + 3]
		local ix = floor((x - minX) / ss)
		local iz = floor((z - minZ) / ss)
		local idx = iz * w + ix + 1
		if origH == GetGroundOrigHeight(x, z) then
			mask[idx] = 2
		else
			mask[idx] = 1
			hgrid[idx] = origH
		end
	end
	return {
		format = "bbox",
		minX = minX, minZ = minZ, w = w, h = h, ss = ss,
		mask = mask, hgrid = hgrid,
		vertexCount = vertexCount,
	}
end

-- Apply (restore) heights from a bbox snapshot. NaN guard preserved.
local function applySnapshotHeights(snap)
	local minX, minZ = snap.minX, snap.minZ
	local w, h = snap.w, snap.h
	local ss = snap.ss or Game.squareSize
	local mask, hgrid = snap.mask, snap.hgrid
	SetHeightMapFunc(function()
		for iz = 0, h - 1 do
			local rowBase = iz * w
			local z = minZ + iz * ss
			for ix = 0, w - 1 do
				local idx = rowBase + ix + 1
				local m = mask[idx]
				if m then
					local x = minX + ix * ss
					local val
					if m == 2 then
						val = GetGroundOrigHeight(x, z)
					else
						val = hgrid[idx]
					end
					if val == val then  -- NaN check
						SetHeightMap(x, z, val)
					else
						nanHeightSkipped = true
					end
				end
			end
		end
	end)
	if nanHeightSkipped then
		Spring.Echo("[Terraform Brush] Warning: NaN height skipped in undo/redo")
		nanHeightSkipped = false
	end
end

-- Capture a parallel snapshot containing CURRENT heights at every touched
-- cell of `srcSnap`. Used by undo/redo handlers to record reverse state.
local function captureCurrentForSnapshot(srcSnap)
	local minX, minZ = srcSnap.minX, srcSnap.minZ
	local w, h = srcSnap.w, srcSnap.h
	local ss = srcSnap.ss or Game.squareSize
	local srcMask = srcSnap.mask
	local mask, hgrid = {}, {}
	for iz = 0, h - 1 do
		local rowBase = iz * w
		local z = minZ + iz * ss
		for ix = 0, w - 1 do
			local idx = rowBase + ix + 1
			if srcMask[idx] then
				local x = minX + ix * ss
				local cur = GetGroundHeight(x, z)
				if cur == GetGroundOrigHeight(x, z) then
					mask[idx] = 2
				else
					mask[idx] = 1
					hgrid[idx] = cur
				end
			end
		end
	end
	return {
		format = "bbox",
		minX = minX, minZ = minZ, w = w, h = h, ss = ss,
		mask = mask, hgrid = hgrid,
		vertexCount = srcSnap.vertexCount,
	}
end

local function evictOldSnapshots()
	while totalVertexCount > MAX_SNAPSHOT_VERTICES and #undoStack > 0 do
		local old = undoStack[1]
		totalVertexCount = totalVertexCount - (old.vertexCount or 0)
		table.remove(undoStack, 1)
	end
	-- If still over budget, trim redo stack too
	while totalVertexCount > MAX_SNAPSHOT_VERTICES and #redoStack > 0 do
		local old = redoStack[1]
		totalVertexCount = totalVertexCount - (old.vertexCount or 0)
		table.remove(redoStack, 1)
	end
end

local function finalizeMerge()
	if mergeSnapshot then
		if DIAG then
			local vc = mergeSnapshotLen / 3
			Spring.Echo(string.format("[TFBrush DIAG] finalizeMerge: verts=%d pushCalls=%d mergeAdded=%d undoDepth=%d",
				vc, diagPushCount, diagMergeVerts, #undoStack))
			diagPushCount = 0
			diagMergeVerts = 0
		end
		mergeSnapshot.vertexCount = mergeSnapshotLen / 3
	end
	mergeSnapshot = nil
	mergeVertexSet = nil
	mergeSnapshotLen = 0
end

-- Hot-path: convert a flat {x,z,h,...} buffer to a bbox-grid snapshot and push.
-- ONE ENTRY PER TICK is mandatory (see bar_stripy_terrain_bug.md). All snapshot
-- callers route through this; pushSnapshot below flattens sub-tables first.
local function pushSnapshotFromFlat(flatBuf, vertexCount)
	if vertexCount == 0 then return end
	if vertexCount > MAX_SNAPSHOT_VERTICES then return end
	finalizeMerge()

	for i = 1, #redoStack do
		totalVertexCount = totalVertexCount - (redoStack[i].vertexCount or 0)
	end
	redoStack = {}

	local snapshot = flatToBboxSnapshot(flatBuf, vertexCount)
	snapshot.strokeId = currentStrokeId
	undoStack[#undoStack + 1] = snapshot
	totalVertexCount = totalVertexCount + vertexCount
	if DIAG then
		Spring.Echo(string.format("[TFBrush DIAG] NEW entry: verts=%d undoDepth=%d", vertexCount, #undoStack))
	end
	if #undoStack > MAX_UNDO then
		local old = undoStack[1]
		totalVertexCount = totalVertexCount - (old.vertexCount or 0)
		table.remove(undoStack, 1)
	end

	evictOldSnapshots()
	SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
end

-- Sub-table format {{x,z,h},...} cold path: flatten via scratchSnapFlat then
-- route through pushSnapshotFromFlat. Currently unused but kept for API stability.
local function pushSnapshot(snapshot)
	local vertexCount = #snapshot
	if vertexCount == 0 then return end
	if vertexCount > MAX_SNAPSHOT_VERTICES then return end
	local buf = scratchSnapFlat
	for i = 1, vertexCount do
		local base = (i - 1) * 3
		local v = snapshot[i]
		buf[base + 1] = v[1]
		buf[base + 2] = v[2]
		buf[base + 3] = v[3]
	end
	pushSnapshotFromFlat(buf, vertexCount)
end

local DUST_CEGS = { "dust_cloud", "dust_cloud_dirt_light", "dust_cloud_fast", "dust_cloud_dirt", "dirtpoof" }
local DUST_COUNT_PER_100 = 12  -- puffs per 100 radius
local RUMBLE_SOUNDS = { "sounds/atmos/lavarumbleshort1.wav", "sounds/atmos/lavarumbleshort2.wav", "sounds/atmos/lavarumbleshort3.wav" }

local SPLASH_CEGS_BIG   = { "splash-large", "splash-huge", "splash-medium" }
local SPLASH_CEGS_SMALL = { "splash-tiny", "splash-small", "watersplash_small", "watersplash_extrasmall" }
local STEAM_CEGS = { "mistycloud" }
local SPLASH_COUNT_PER_100 = 10
local WATER_SOUNDS = { "sounds/replies/waterex1.wav", "sounds/replies/waterex2.wav" }

local function spawnWaterFX(centerX, centerZ, radius, intensity)
	intensity = intensity or 1.0
	local intensityScale = max(0.3, min(3.0, intensity / 5.0))
	local count = max(3, floor(radius / 100 * SPLASH_COUNT_PER_100 * intensityScale))

	for _ = 1, count do
		local angle = random() * 2 * pi
		local dist = random() * radius * 0.85
		local x = centerX + cos(angle) * dist
		local z = centerZ + sin(angle) * dist
		local y = max(0, Spring.GetGroundHeight(x, z))

		-- Mix of big and small splashes
		if random() < 0.3 then
			local ceg = SPLASH_CEGS_BIG[random(1, #SPLASH_CEGS_BIG)]
			local scale = radius * (0.0008 + random() * 0.002) * intensityScale
			SpawnCEG(ceg, x, y, z, 0, (0.3 + random() * 0.5) * intensityScale, 0, scale, 0)
		else
			local ceg = SPLASH_CEGS_SMALL[random(1, #SPLASH_CEGS_SMALL)]
			local scale = radius * (0.0004 + random() * 0.001) * intensityScale
			SpawnCEG(ceg, x, y, z, 0, (0.2 + random() * 0.4) * intensityScale, 0, scale, 0)
		end
	end

	-- Faint steam/mist on top
	local steamCount = max(1, floor(count * 0.25))
	for _ = 1, steamCount do
		local angle = random() * 2 * pi
		local dist = random() * radius * 0.7
		local x = centerX + cos(angle) * dist
		local z = centerZ + sin(angle) * dist
		local y = max(0, Spring.GetGroundHeight(x, z))
		local ceg = STEAM_CEGS[random(1, #STEAM_CEGS)]
		local scale = radius * (0.00005 + random() * 0.00015) * intensityScale
		SpawnCEG(ceg, x, y + 5, z, 0, 0.05 + random() * 0.1, 0, scale, 0)
	end

	local vol = min(3.0, radius / 120 * intensityScale)
	Spring.PlaySoundFile(WATER_SOUNDS[random(1, #WATER_SOUNDS)], vol, centerX, 0, centerZ, 'sfx')
end

local function spawnDust(centerX, centerZ, radius, intensity)
	-- Check if center is underwater — spawn water FX instead
	local groundY = Spring.GetGroundHeight(centerX, centerZ)
	if groundY < 0 then
		spawnWaterFX(centerX, centerZ, radius, intensity)
		return
	end

	intensity = intensity or 1.0
	local intensityScale = max(0.3, min(3.0, intensity / 5.0))
	local count = max(4, floor(radius / 100 * DUST_COUNT_PER_100 * intensityScale))
	for _ = 1, count do
		local angle = random() * 2 * pi
		local dist = random() * radius * 0.9
		local x = centerX + cos(angle) * dist
		local z = centerZ + sin(angle) * dist
		local y = Spring.GetGroundHeight(x, z)
		local ceg = DUST_CEGS[random(1, #DUST_CEGS)]
		local scale = radius * (0.0125 + random() * 0.05) * intensityScale
		SpawnCEG(ceg, x, y, z, 0, (0.5 + random() * 1.5) * intensityScale, 0, scale, 0)
	end
	local vol = math.min(4.0, radius / 100 * intensityScale)
	local y = Spring.GetGroundHeight(centerX, centerZ)
	Spring.PlaySoundFile(RUMBLE_SOUNDS[random(1, #RUMBLE_SOUNDS)], vol, centerX, y, centerZ, 'sfx')
end

-- Memoised rotation: within one applyTerraform call angleDeg is constant, so
-- sin/cos are computed once and reused for every vertex in the brush footprint.
local _rpAngle, _rpCos, _rpSin
local function rotatePoint(px, pz, angleDeg)
	if angleDeg ~= _rpAngle then
		_rpAngle = angleDeg
		local rad = angleDeg * pi / 180
		_rpCos = cos(rad)
		_rpSin = sin(rad)
	end
	return px * _rpCos - pz * _rpSin, px * _rpSin + pz * _rpCos
end

local function isInsideCircle(dx, dz, radius)
	return dx * dx + dz * dz <= radius * radius
end

local function isInsideSquare(dx, dz, radius, angleDeg)
	local lx, lz = rotatePoint(dx, dz, -angleDeg)
	return abs(lx) <= radius and abs(lz) <= radius
end

local function isInsideRing(dx, dz, radius)
	local distSquared = dx * dx + dz * dz
	local innerRadius = radius * ringInnerRatio
	return distSquared <= radius * radius and distSquared >= innerRadius * innerRadius
end

local function regularPolygonFalloff(dx, dz, radius, angleDeg, numSides)
	local lx, lz = rotatePoint(dx, dz, -angleDeg)
	local dist = (lx * lx + lz * lz) ^ 0.5
	if dist < 0.001 then return 1 end
	local angle = atan2(lz, lx)
	if angle < 0 then angle = angle + 2 * pi end
	local sectorAngle = 2 * pi / numSides
	local angleInSector = (angle % sectorAngle) - sectorAngle / 2
	local apothem = radius * cos(pi / numSides)
	local edgeDist = apothem / cos(angleInSector)
	if dist > edgeDist then return nil end
	return 1 - dist / edgeDist
end

local function computeFalloff(dx, dz, radius, shape, angleDeg, curve, lengthScale)
	lengthScale = lengthScale or 1.0
	local distSquared = dx * dx + dz * dz
	local radiusSquared = radius * radius
	local rawFalloff = nil

	if shape == "circle" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local d2 = lx * lx + lz * lz
		if d2 > radiusSquared then
			return nil
		end

		rawFalloff = 1 - (d2 / radiusSquared)
	elseif shape == "square" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		if abs(lx) > radius or abs(lz) > radius then
			return nil
		end

		rawFalloff = 1 - max(abs(lx), abs(lz)) / radius
	elseif shape == "triangle" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local f = regularPolygonFalloff(lx, lz, radius, 0, 3)
		if not f then return nil end
		rawFalloff = f
	elseif shape == "hexagon" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local f = regularPolygonFalloff(lx, lz, radius, 0, 6)
		if not f then return nil end
		rawFalloff = f
	elseif shape == "octagon" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local f = regularPolygonFalloff(lx, lz, radius, 0, 8)
		if not f then return nil end
		rawFalloff = f
	elseif shape == "ring" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local d2 = lx * lx + lz * lz
		local innerRadius = radius * ringInnerRatio
		if d2 > radiusSquared or d2 < innerRadius * innerRadius then
			return nil
		end

		local dist = d2 ^ 0.5
		local ringWidth = radius - innerRadius
		local midRadius = (radius + innerRadius) * 0.5
		local distFromMid = abs(dist - midRadius)
		rawFalloff = 1 - (distFromMid / (ringWidth * 0.5))
	end

	if not rawFalloff then
		return nil
	end

	return rawFalloff ^ curve
end

-- ─── FALLOFF STAMP CACHE ─────────────────────────────────────────────────────
-- computeFalloff is the inner-loop hot spot for applyTerraform: at radius=2000
-- with squareSize=8 it gets called ~395 k times per tick, each doing a sin/cos
-- rotation and a power. We cache the per-cell falloff field keyed by quantised
-- params so successive ticks of the same brush reuse it.
--
-- Quantisation (chosen to stay within sub-quantisation visual error):
--   radius      → integer
--   angleDeg    → nearest 2°
--   curve       → 0.05 step
--   lengthScale → 0.05 step
--   ringRatio   → 0.02 step (only matters for "ring" shape)
--
-- LRU eviction: keep at most FALLOFF_STAMP_LIMIT stamps. A radius-2000 stamp
-- is ~400 k floats ≈ 16 MB; 4 such = 64 MB max worst-case.
local FALLOFF_STAMP_LIMIT = 4
local FALLOFF_EPSILON     = 1 / 255   -- below this, treat as zero (sub-quantisation)
local falloffStampCache   = {}
local falloffStampOrder   = {}  -- LRU queue of keys (oldest first)

local function quantiseStampParams(radius, angleDeg, curve, lengthScale, ringRatio)
	local rQ  = floor(radius)
	-- Wrap angle to [0,360) before quantising so 359° and -1° share a stamp.
	local aN  = angleDeg % 360
	local aQ  = floor(aN / 2 + 0.5) * 2
	if aQ >= 360 then aQ = aQ - 360 end
	local cQ  = floor(curve / 0.05 + 0.5) * 0.05
	local lQ  = floor(lengthScale / 0.05 + 0.5) * 0.05
	local rrQ = floor(ringRatio / 0.02 + 0.5) * 0.02
	return rQ, aQ, cQ, lQ, rrQ
end

local function buildFalloffStamp(radius, shape, angleDeg, curve, lengthScale, ringRatio, ss)
	-- computeFalloff captures module-level ringInnerRatio. Save & override so
	-- the stamp matches the quantised ringRatio key, then restore.
	local prevRing = ringInnerRatio
	ringInnerRatio = ringRatio
	local extent = radius * max(1, lengthScale) * 1.42
	local halfCells = floor(extent / ss)
	local size = halfCells * 2 + 1
	local data = {}
	for iz = 0, size - 1 do
		local dz = (iz - halfCells) * ss
		local rowBase = iz * size
		for ix = 0, size - 1 do
			local dx = (ix - halfCells) * ss
			local f = computeFalloff(dx, dz, radius, shape, angleDeg, curve, lengthScale)
			if f and f >= FALLOFF_EPSILON then
				data[rowBase + ix + 1] = f
			end
			-- else leave nil (skip cell at apply time)
		end
	end
	ringInnerRatio = prevRing
	return { w = size, h = size, cx = halfCells, cz = halfCells, data = data }
end

local function getFalloffStamp(radius, shape, angleDeg, curve, lengthScale, ringRatio, ss)
	local rQ, aQ, cQ, lQ, rrQ = quantiseStampParams(radius, angleDeg, curve, lengthScale, ringRatio)
	local key = string.format("%s|%d|%d|%.2f|%.2f|%.2f|%d", shape, rQ, aQ, cQ, lQ, rrQ, ss)
	local stamp = falloffStampCache[key]
	if stamp then
		-- Bump LRU recency
		local n = #falloffStampOrder
		for i = 1, n do
			if falloffStampOrder[i] == key then
				if i ~= n then
					table.remove(falloffStampOrder, i)
					falloffStampOrder[n] = key
				end
				break
			end
		end
		return stamp
	end
	stamp = buildFalloffStamp(rQ, shape, aQ, cQ, lQ, rrQ, ss)
	falloffStampCache[key] = stamp
	falloffStampOrder[#falloffStampOrder + 1] = key
	while #falloffStampOrder > FALLOFF_STAMP_LIMIT do
		local oldKey = falloffStampOrder[1]
		table.remove(falloffStampOrder, 1)
		falloffStampCache[oldKey] = nil
	end
	return stamp
end

local function applyTerraform(centerX, centerZ, radius, direction, shape, angleDeg, curve, heightMin, heightMax, intensity, lengthScale, clayMode, opacity, flattenHeight, instant)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	lengthScale = lengthScale or 1.0

	-- Clay mode: compute a target plane at center height + full brush displacement
	local clayPlane
	if clayMode and direction ~= 0 and direction ~= 2 then
		local centerHeight = Spring.GetGroundHeight(centerX, centerZ)
		clayPlane = centerHeight + direction * HEIGHT_STEP * intensity
	end

	opacity = opacity or 0.3

	-- Falloff stamp: precomputed per-cell falloff field keyed by quantised
	-- (radius, shape, angle, curve, length, ringRatio). Skips per-cell sin/cos
	-- and pow when reused across ticks of the same brush.
	local stamp = getFalloffStamp(radius, shape, angleDeg, curve, lengthScale, ringInnerRatio, squareSize)
	local sw    = stamp.w
	local sh    = stamp.h
	local sCx   = stamp.cx
	local sCz   = stamp.cz
	local sdata = stamp.data
	-- Snap brush center to nearest grid cell (sub-quantisation visual change up
	-- to squareSize/2 ≈ 4 world units; required so the cached stamp aligns).
	local centerCellX = floor(centerX / squareSize + 0.5)
	local centerCellZ = floor(centerZ / squareSize + 0.5)

	-- Reuse scratch tables to reduce per-frame allocation
	local heightData = scratchHeightData
	local snapFlat = scratchSnapFlat
	local hIdx = 0
	local sCount = 0

	for iz = 0, sh - 1 do
		local sBase = iz * sw
		local zCell = centerCellZ + (iz - sCz)
		local z = zCell * squareSize
		if z >= 0 and z <= mapSizeZ then
			for ix = 0, sw - 1 do
				local falloff = sdata[sBase + ix + 1]
				if falloff then
					local xCell = centerCellX + (ix - sCx)
					local x = xCell * squareSize
					if x >= 0 and x <= mapSizeX then
						local current = Spring.GetGroundHeight(x, z)
						-- Write to flat scratch buffer (no sub-table allocation)
						local base = sCount * 3
						snapFlat[base + 1] = x
						snapFlat[base + 2] = z
						snapFlat[base + 3] = current
						sCount = sCount + 1

						local newHeight

						if instant then
							-- Stamp mode: directly lerp toward the target cap height in one step
							if direction > 0 and heightMax then
								newHeight = current + (heightMax - current) * falloff
							elseif direction < 0 and heightMin then
								newHeight = current + (heightMin - current) * falloff
							elseif direction == 0 then
								local targetHeight = flattenHeight or Spring.GetGroundHeight(centerX, centerZ)
								newHeight = current + (targetHeight - current) * falloff
								if heightMin then newHeight = max(heightMin, newHeight) end
								if heightMax then newHeight = min(heightMax, newHeight) end
							else
								-- Fallback for direction==2 (random) or missing cap
								local delta = direction * HEIGHT_STEP * falloff * intensity * opacity
								newHeight = current + delta
								if heightMin then newHeight = max(heightMin, newHeight) end
								if heightMax then newHeight = min(heightMax, newHeight) end
							end
						elseif direction == 2 then
							local delta = (math.random() * 2 - 1) * HEIGHT_STEP * falloff * intensity * opacity
							newHeight = current + delta
						elseif direction == 0 then
							local targetHeight = flattenHeight or Spring.GetGroundHeight(centerX, centerZ)
							local diff = targetHeight - current
							local blend = min(1.0, falloff * opacity * intensity)
							newHeight = current + diff * blend
						else
							if clayMode then
								if direction > 0 and current < clayPlane then
									local gap = clayPlane - current
									newHeight = current + gap * falloff * opacity * intensity
									newHeight = min(newHeight, clayPlane)
								elseif direction < 0 and current > clayPlane then
									local gap = current - clayPlane
									newHeight = current - gap * falloff * opacity * intensity
									newHeight = max(newHeight, clayPlane)
								else
									newHeight = current
								end
							else
								local delta = direction * HEIGHT_STEP * falloff * intensity * opacity
								newHeight = current + delta
							end
						end

						if not instant then
							if heightMin then
								newHeight = max(heightMin, newHeight)
							end
							if heightMax then
								newHeight = min(heightMax, newHeight)
							end
						end

						hIdx = hIdx + 1
						local he = heightData[hIdx]
						if he then he[1] = x; he[2] = z; he[3] = newHeight
						else heightData[hIdx] = {x, z, newHeight} end
					end
				end
			end
		end
	end

	-- Trim scratch heightData using tracked max (avoids # on reused table)
	for i = hIdx + 1, scratchHeightDataMax do heightData[i] = nil end
	scratchHeightDataMax = hIdx

	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

local function applyRamp(startX, startZ, startY, endX, endZ, endY, width, clayMode)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ

	local dx = endX - startX
	local dz = endZ - startZ
	local length = (dx * dx + dz * dz) ^ 0.5
	if length < 1 then
		return
	end

	local dirX = dx / length
	local dirZ = dz / length

	local minX = max(0, floor((min(startX, endX) - width) / squareSize) * squareSize)
	local maxX = min(mapSizeX, floor((max(startX, endX) + width) / squareSize) * squareSize)
	local minZ = max(0, floor((min(startZ, endZ) - width) / squareSize) * squareSize)
	local maxZ = min(mapSizeZ, floor((max(startZ, endZ) + width) / squareSize) * squareSize)

	local heightData = scratchHeightData
	local snapFlat = scratchSnapFlat
	local hIdx = 0
	local sCount = 0

	for z = minZ, maxZ, squareSize do
		for x = minX, maxX, squareSize do
			local px = x - startX
			local pz = z - startZ

			local along = px * dirX + pz * dirZ
			if along >= 0 and along <= length then
				local perpX = px - along * dirX
				local perpZ = pz - along * dirZ
				local perpDist = (perpX * perpX + perpZ * perpZ) ^ 0.5

				if perpDist <= width then
					local ratio = perpDist / width
					local falloff = 1 - ratio * ratio
					local t = along / length
					local targetHeight = startY + (endY - startY) * t
					local current = Spring.GetGroundHeight(x, z)
					local newHeight
					if clayMode then
						-- Clay: only move toward target, never past it
						if targetHeight > current then
							newHeight = min(current + (targetHeight - current) * 0.3 * falloff, targetHeight)
						elseif targetHeight < current then
							newHeight = max(current + (targetHeight - current) * 0.3 * falloff, targetHeight)
						end
					else
						newHeight = current + (targetHeight - current) * 0.3 * falloff
					end
					if newHeight then
						local sBase = sCount * 3
						snapFlat[sBase + 1] = x
						snapFlat[sBase + 2] = z
						snapFlat[sBase + 3] = current
						sCount = sCount + 1
						hIdx = hIdx + 1
						local he = heightData[hIdx]
						if he then he[1] = x; he[2] = z; he[3] = newHeight
						else heightData[hIdx] = {x, z, newHeight} end
					end
				end
			end
		end
	end

	for i = hIdx + 1, scratchHeightDataMax do heightData[i] = nil end
	scratchHeightDataMax = hIdx
	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

local function applySplineRamp(waypoints, width, clayMode, snapFull)
	local blendFactor = snapFull and 1.0 or 0.3
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	local numPts = #waypoints

	if numPts < 2 then return end

	-- Compute cumulative arc lengths
	local arcLengths = { 0 }
	for i = 2, numPts do
		local dx = waypoints[i][1] - waypoints[i - 1][1]
		local dz = waypoints[i][2] - waypoints[i - 1][2]
		arcLengths[i] = arcLengths[i - 1] + (dx * dx + dz * dz) ^ 0.5
	end
	local totalLength = arcLengths[numPts]
	if totalLength < 1 then return end

	-- Get start and end ground heights
	local startY = Spring.GetGroundHeight(waypoints[1][1], waypoints[1][2])
	local endY = Spring.GetGroundHeight(waypoints[numPts][1], waypoints[numPts][2])

	-- Compute bounding box
	local bbMinX, bbMaxX = waypoints[1][1], waypoints[1][1]
	local bbMinZ, bbMaxZ = waypoints[1][2], waypoints[1][2]
	for i = 2, numPts do
		if waypoints[i][1] < bbMinX then bbMinX = waypoints[i][1] end
		if waypoints[i][1] > bbMaxX then bbMaxX = waypoints[i][1] end
		if waypoints[i][2] < bbMinZ then bbMinZ = waypoints[i][2] end
		if waypoints[i][2] > bbMaxZ then bbMaxZ = waypoints[i][2] end
	end

	local minX = max(0, floor((bbMinX - width) / squareSize) * squareSize)
	local maxX = min(mapSizeX, floor((bbMaxX + width) / squareSize) * squareSize)
	local minZ = max(0, floor((bbMinZ - width) / squareSize) * squareSize)
	local maxZ = min(mapSizeZ, floor((bbMaxZ + width) / squareSize) * squareSize)

	local heightData = scratchHeightData
	local snapFlat = scratchSnapFlat
	local hIdx = 0
	local sCount = 0

	for z = minZ, maxZ, squareSize do
		for x = minX, maxX, squareSize do
			-- Find closest point on the polyline
			local bestDist = math.huge
			local bestArc = 0

			for i = 1, numPts - 1 do
				local ax, az = waypoints[i][1], waypoints[i][2]
				local bx, bz = waypoints[i + 1][1], waypoints[i + 1][2]
				local segDx = bx - ax
				local segDz = bz - az
				local segLen = (segDx * segDx + segDz * segDz) ^ 0.5
				if segLen > 0 then
					local px = x - ax
					local pz = z - az
					local t = (px * segDx + pz * segDz) / (segLen * segLen)
					t = max(0, min(1, t))
					local projX = ax + t * segDx
					local projZ = az + t * segDz
					local dist = ((x - projX) * (x - projX) + (z - projZ) * (z - projZ)) ^ 0.5
					if dist < bestDist then
						bestDist = dist
						bestArc = arcLengths[i] + t * segLen
					end
				end
			end

			if bestDist <= width then
				local ratio = bestDist / width
				local falloff = 1 - ratio * ratio
				local t = bestArc / totalLength
				local targetHeight = startY + (endY - startY) * t
				local current = Spring.GetGroundHeight(x, z)
				local newHeight
				if clayMode then
					if targetHeight > current then
						newHeight = min(current + (targetHeight - current) * blendFactor * falloff, targetHeight)
					elseif targetHeight < current then
						newHeight = max(current + (targetHeight - current) * blendFactor * falloff, targetHeight)
					end
				else
					newHeight = current + (targetHeight - current) * blendFactor * falloff
				end
				if newHeight then
					local sBase = sCount * 3
					snapFlat[sBase + 1] = x
					snapFlat[sBase + 2] = z
					snapFlat[sBase + 3] = current
					sCount = sCount + 1
					hIdx = hIdx + 1
					local he = heightData[hIdx]
					if he then he[1] = x; he[2] = z; he[3] = newHeight
					else heightData[hIdx] = {x, z, newHeight} end
				end
			end
		end
	end

	for i = hIdx + 1, scratchHeightDataMax do heightData[i] = nil end
	scratchHeightDataMax = hIdx
	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

local function applyRestore(centerX, centerZ, radius, shape, angleDeg, curve, intensity, lengthScale, restoreStrength)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	lengthScale = lengthScale or 1.0
	restoreStrength = restoreStrength or 1.0

	local extent = radius * max(1, lengthScale) * 1.42

	local minX = max(0, floor((centerX - extent) / squareSize) * squareSize)
	local maxX = min(mapSizeX, floor((centerX + extent) / squareSize) * squareSize)
	local minZ = max(0, floor((centerZ - extent) / squareSize) * squareSize)
	local maxZ = min(mapSizeZ, floor((centerZ + extent) / squareSize) * squareSize)

	local heightData = scratchHeightData
	local snapFlat = scratchSnapFlat
	local hIdx = 0
	local sCount = 0

	for z = minZ, maxZ, squareSize do
		for x = minX, maxX, squareSize do
			local dx = x - centerX
			local dz = z - centerZ
			local falloff = computeFalloff(dx, dz, radius, shape, angleDeg, curve, lengthScale)

			if falloff then
				local current = Spring.GetGroundHeight(x, z)
				local base = sCount * 3
				snapFlat[base + 1] = x
				snapFlat[base + 2] = z
				snapFlat[base + 3] = current
				sCount = sCount + 1

				local original = Spring.GetGroundOrigHeight(x, z)
				local target = current + (original - current) * restoreStrength
				local blend = min(1.0, falloff * 0.3 * intensity)
				local newHeight = current + (target - current) * blend
				hIdx = hIdx + 1
				local he = heightData[hIdx]
				if he then he[1] = x; he[2] = z; he[3] = newHeight
				else heightData[hIdx] = {x, z, newHeight} end
			end
		end
	end

	for i = hIdx + 1, scratchHeightDataMax do heightData[i] = nil end
	scratchHeightDataMax = hIdx
	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

-- ============ Noise Functions ============

-- Permutation table for Perlin noise (deterministic, seeded)
-- Cached to avoid rebuilding 512-entry table every frame
local cachedPerm = nil
local cachedPermSeed = nil

local function buildPermTable(seed)
	seed = seed or 0
	if cachedPerm and cachedPermSeed == seed then
		return cachedPerm
	end
	local perm = cachedPerm or {}
	for i = 0, 255 do perm[i] = i end
	-- Fisher-Yates shuffle seeded
	local s = seed
	for i = 255, 1, -1 do
		s = (s * 1103515245 + 12345) % 2147483648
		local j = s % (i + 1)
		perm[i], perm[j] = perm[j], perm[i]
	end
	-- Duplicate for overflow
	for i = 0, 255 do perm[i + 256] = perm[i] end
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
	if h == 0 then return x + y
	elseif h == 1 then return -x + y
	elseif h == 2 then return x - y
	else return -x - y
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

	return lerp(v,
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
		val = 1 - abs(val)  -- ridge: invert absolute value
		val = val * val      -- sharpen ridges
		total = total + val * amplitude
		maxVal = maxVal + amplitude
		amplitude = amplitude * persistence
		frequency = frequency * lacunarity
	end
	return total / maxVal
end

local function billowNoise(x, y, perm, octaves, persistence, lacunarity)
	local total = 0
	local amplitude = 1
	local frequency = 1
	local maxVal = 0
	for _ = 1, octaves do
		local val = abs(perlinNoise2D(x * frequency, y * frequency, perm))
		total = total + val * amplitude
		maxVal = maxVal + amplitude
		amplitude = amplitude * persistence
		frequency = frequency * lacunarity
	end
	return total / maxVal
end

local function voronoiNoise2D(x, y, perm)
	local xi = floor(x)
	local yi = floor(y)
	local minDist = 999

	for dx = -1, 1 do
		for dz = -1, 1 do
			local cx = xi + dx
			local cz = yi + dz
			-- Hash cell to get point position
			local h1 = perm[(cx % 256 + 256) % 256]
			local h2 = perm[(h1 + ((cz % 256 + 256) % 256)) % 256]
			local h3 = perm[(h2 + 1) % 256]
			local px = cx + h2 / 256
			local pz = cz + h3 / 256
			local ddx = px - x
			local ddz = pz - y
			local dist = (ddx * ddx + ddz * ddz) ^ 0.5
			if dist < minDist then
				minDist = dist
			end
		end
	end

	return min(1, minDist)
end

local function voronoiFBM(x, y, perm, octaves, persistence, lacunarity)
	local total = 0
	local amplitude = 1
	local frequency = 1
	local maxVal = 0
	for _ = 1, octaves do
		total = total + voronoiNoise2D(x * frequency, y * frequency, perm) * amplitude
		maxVal = maxVal + amplitude
		amplitude = amplitude * persistence
		frequency = frequency * lacunarity
	end
	return total / maxVal
end

local function sampleNoise(noiseType, nx, nz, perm, octaves, persistence, lacunarity)
	if noiseType == "perlin" then
		-- Single-octave Perlin for classic noise
		return (perlinNoise2D(nx, nz, perm) + 1) * 0.5
	elseif noiseType == "fbm" then
		return (fbmNoise(nx, nz, perm, octaves, persistence, lacunarity) + 1) * 0.5
	elseif noiseType == "ridged" then
		return ridgedNoise(nx, nz, perm, octaves, persistence, lacunarity)
	elseif noiseType == "billow" then
		return billowNoise(nx, nz, perm, octaves, persistence, lacunarity)
	elseif noiseType == "voronoi" then
		return voronoiFBM(nx, nz, perm, octaves, persistence, lacunarity)
	end
	return 0.5
end

local function applyNoise(centerX, centerZ, radius, shape, angleDeg, curve, intensity, lengthScale, noiseType, noiseScale, octaves, persistence, lacunarity, seed)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	lengthScale = lengthScale or 1.0
	noiseScale = noiseScale or 64
	octaves = octaves or 4
	persistence = persistence or 0.5
	lacunarity = lacunarity or 2.0
	seed = seed or 0
	noiseType = noiseType or "perlin"

	local perm = buildPermTable(seed)

	local extent = radius * max(1, lengthScale) * 1.42
	local minX = max(0, floor((centerX - extent) / squareSize) * squareSize)
	local maxX = min(mapSizeX, floor((centerX + extent) / squareSize) * squareSize)
	local minZ = max(0, floor((centerZ - extent) / squareSize) * squareSize)
	local maxZ = min(mapSizeZ, floor((centerZ + extent) / squareSize) * squareSize)

	-- Reuse scratch tables to reduce per-frame allocation
	local heightData = scratchHeightData
	local snapFlat = scratchSnapFlat
	local hIdx = 0
	local sCount = 0

	for z = minZ, maxZ, squareSize do
		for x = minX, maxX, squareSize do
			local dx = x - centerX
			local dz = z - centerZ
			local falloff = computeFalloff(dx, dz, radius, shape, angleDeg, curve, lengthScale)

			if falloff then
				local current = Spring.GetGroundHeight(x, z)
				local base = sCount * 3
				snapFlat[base + 1] = x
				snapFlat[base + 2] = z
				snapFlat[base + 3] = current
				sCount = sCount + 1

				-- Sample noise at world position (divided by scale for frequency)
				local nx = x / noiseScale
				local nz = z / noiseScale
				local noiseVal = sampleNoise(noiseType, nx, nz, perm, octaves, persistence, lacunarity)

				-- Map noise to height offset: centered around 0 (-0.5 to +0.5 range)
				local offset = (noiseVal - 0.5) * 2 * HEIGHT_STEP * intensity * falloff
				hIdx = hIdx + 1
				local he = heightData[hIdx]
				if he then he[1] = x; he[2] = z; he[3] = current + offset
				else heightData[hIdx] = {x, z, current + offset} end
			end
		end
	end

	-- Trim scratch heightData using tracked max (avoids # on reused table)
	for i = hIdx + 1, scratchHeightDataMax do heightData[i] = nil end
	scratchHeightDataMax = hIdx
	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- FILL BRUSH — Radial-ray rim detection + BFS basin + IDW curved fill
--
-- Phase 1: Cast 48 radial rays from click outward. Each ray tracks the
--    running maximum height. When terrain drops > DROP_THRESHOLD below the
--    running max, the ray has crossed the rim. Record the peak (x,z,h).
-- Phase 2: spillover = min(rimPeaks). BFS from click, expand through ALL
--    cells with h < spillover. This naturally captures the entire bowl
--    interior AND inner wall slopes up to the spillover level.
-- Phase 3: For each basin cell, compute target via IDW from rim peaks.
--    Even rims → flat. Uneven → smooth curved surface.
-- Phase 4: Raise (never lower) each basin cell to its IDW target.
-- ─────────────────────────────────────────────────────────────────────────────
local FILL_HEADER = "$terraform_fill$"
local FILL_HEADER_LENGTH = #FILL_HEADER

local FILL_NUM_RAYS       = 128     -- radial rays for rim detection
-- Ray walk length and basin cell cap are derived per-call from map size so
-- the fill can span almost the entire map (slow but correct on huge bowls).

local function applyFill(cx, cz)
	finalizeMerge()

	local ss   = Game.squareSize
	local mapX = Game.mapSizeX
	local mapZ = Game.mapSizeZ
	local sin, cos, pi = math.sin, math.cos, math.pi

	-- Map dimensions in cells; ray walks the full diagonal so it can reach
	-- the opposite map edge when needed.
	local mapXCells = mapX / ss
	local mapZCells = mapZ / ss
	local fillRayMaxSteps = floor(math.sqrt(mapXCells * mapXCells + mapZCells * mapZCells)) + 4
	-- Past-peak cutoff: long enough to skip interior noise on huge maps
	-- but still terminate rays once they're clearly outside a wall.
	local pastPeakLimit = max(80, floor(fillRayMaxSteps * 0.15))
	-- Hard upper bound on basin size = whole map (rare; fill is meant to
	-- be permissive). Watchdog risk on enormous bowls is acceptable per request.
	local fillMaxCells = floor(mapXCells * mapZCells) + 1

	cx = max(0, min(mapX, floor(cx / ss + 0.5) * ss))
	cz = max(0, min(mapZ, floor(cz / ss + 0.5) * ss))

	local startH = Spring.GetGroundHeight(cx, cz)

	-- ── Phase 1: Radial rays → find rim peaks ───────────────────────────────
	-- Walk each ray outward, tracking the highest point. The peak along each
	-- ray IS the rim for that angular direction. We also record the peak
	-- DISTANCE (in cells) per ray — used in Phase 2 to bound the basin by a
	-- polar "inside the rim ring" check rather than a height threshold.
	local rimPX, rimPZ, rimPH = {}, {}, {}
	local rimPeakStep = {}   -- per-ray peak distance in cells (nil if rejected)
	local rimN = 0
	local WALL_MIN_RISE = 16   -- ray peak must be at least this above startH
	local EXIT_DROP     = 12   -- after peak, terrain must drop this much below
	                           -- peak (and stay near/below startH+rise/2) to
	                           -- count as "exited the bowl"

	-- Diagnostic: track all ray results
	local diagPeaks = {}
	local diagSteps = {}
	local openRays  = 0    -- rays that never exited → direction is open

	for ri = 0, FILL_NUM_RAYS - 1 do
		local angle = ri * 2 * pi / FILL_NUM_RAYS
		local ddx = cos(angle)
		local ddz = sin(angle)
		local peakX, peakZ, peakH, peakStep = cx, cz, startH, 0
		local exited = false
		local totalSteps = 0
		local stopReason = "maxsteps"
		local exitCeiling = startH + WALL_MIN_RISE * 0.5

		for step = 1, fillRayMaxSteps do
			local rx = floor(cx / ss + ddx * step + 0.5) * ss
			local rz = floor(cz / ss + ddz * step + 0.5) * ss
			rx = max(0, min(mapX, rx))
			rz = max(0, min(mapZ, rz))
			local h = Spring.GetGroundHeight(rx, rz)
			totalSteps = step

			if h > peakH then
				peakX, peakZ, peakH, peakStep = rx, rz, h, step
			end

			-- Closed-shape check: we consider the bowl "exited" only if we
			-- (a) found a real rim peak above the rise threshold AND
			-- (b) descended back to near the click's low terrain.
			-- Interior bumps that don't return to low ground don't count.
			if peakH >= startH + WALL_MIN_RISE and h <= exitCeiling and h < peakH - EXIT_DROP then
				exited = true
				stopReason = "exited"
				break
			end

			-- Stop at map edge (direction is open if we didn't exit first)
			if rx <= 0 or rx >= mapX or rz <= 0 or rz >= mapZ then stopReason = "edge"; break end
		end

		diagPeaks[ri] = peakH
		diagSteps[ri] = totalSteps

		-- A ray only contributes a rim if it successfully exited the bowl.
		-- Rays that hit the map edge or step limit without descending back
		-- to low ground = open direction (bowl not closed on that side).
		if exited then
			rimN = rimN + 1
			rimPX[rimN] = peakX; rimPZ[rimN] = peakZ; rimPH[rimN] = peakH
			rimPeakStep[ri] = peakStep  -- indexed by ray id, not by rimN
		else
			openRays = openRays + 1
		end

		-- Log first 12 rays in detail
		if ri < 12 then
			Spring.Echo(string.format("[Terraform Fill] ray%02d angle=%.0f° peak=%.1f at(%d,%d) steps=%d stop=%s %s",
				ri, angle * 180 / pi, peakH, peakX, peakZ, totalSteps, stopReason,
				exited and "ACCEPT" or "REJECT"))
		end
	end

	-- Summary: show peak distribution
	local peakMin, peakMax = 99999, -99999
	for ri = 0, FILL_NUM_RAYS - 1 do
		if diagPeaks[ri] < peakMin then peakMin = diagPeaks[ri] end
		if diagPeaks[ri] > peakMax then peakMax = diagPeaks[ri] end
	end
	Spring.Echo(string.format("[Terraform Fill] peakRange=[%.1f .. %.1f] openRays=%d/%d startH=%.1f",
		peakMin, peakMax, openRays, FILL_NUM_RAYS, startH))

	-- Closed-shape verification: too many open directions → abort.
	-- Allow small gaps (e.g. narrow canyon entrance) but not an open side.
	local OPEN_RAY_MAX = floor(FILL_NUM_RAYS * 0.10)  -- ≤10% of rays may be open
	if openRays > OPEN_RAY_MAX then
		Spring.Echo(string.format("[Terraform Fill] Area is not enclosed (%d/%d rays open, max %d) — aborting",
			openRays, FILL_NUM_RAYS, OPEN_RAY_MAX))
		return
	end

	if rimN < 3 then
		Spring.Echo("[Terraform Fill] Could not detect enclosing rim (found "..rimN.." peaks)")
		return
	end

	-- ── Phase 2: Basin = polar disk inside the rim ring ─────────────────────
	-- For each cell in the click's bbox, compute (angle, distance) relative
	-- to the click. The cell is "inside the rim" iff its distance is less
	-- than the rim distance at that angle.
	--
	-- To prevent leaks through gaps: each ray's peak distance is clamped to
	-- the MEDIAN of its K-ray angular window. A single rogue ray that
	-- detected a far rim through a gap cannot extend the basin anymore.
	-- Missing rays fall back to the nearest accepted neighbour via forward
	-- + backward circular sweep.
	local basinX, basinZ = {}, {}
	local bN = 0

	-- Gap-fill rimPeakStep across rejected rays (nearest accepted neighbour)
	local rimStepRaw = {}
	do
		local last = nil
		for ri = 0, FILL_NUM_RAYS * 2 - 1 do
			local r = ri % FILL_NUM_RAYS
			if rimPeakStep[r] then last = rimPeakStep[r] end
			if ri >= FILL_NUM_RAYS and rimStepRaw[r] == nil and last then rimStepRaw[r] = last end
			if rimPeakStep[r] then rimStepRaw[r] = rimPeakStep[r] end
		end
		last = nil
		for ri = FILL_NUM_RAYS * 2 - 1, 0, -1 do
			local r = ri % FILL_NUM_RAYS
			if rimPeakStep[r] then last = rimPeakStep[r] end
			if rimStepRaw[r] == nil and last then rimStepRaw[r] = last end
		end
	end

	-- Anti-leak filter: for each ray, take the MEDIAN of a small window.
	-- Median preserves the typical rim distance (so fill reaches the wall)
	-- while killing single outlier rays that shot through gaps. Additionally,
	-- cap each ray at 2.0× the window median to truncate any persistent leak.
	local ANTI_LEAK_HALF = 2  -- window = 5 rays
	local rimStep = {}
	local wbuf = {}
	for ri = 0, FILL_NUM_RAYS - 1 do
		if rimStepRaw[ri] then
			local n = 0
			for d = -ANTI_LEAK_HALF, ANTI_LEAK_HALF do
				local r2 = (ri + d + FILL_NUM_RAYS) % FILL_NUM_RAYS
				local v = rimStepRaw[r2]
				if v then n = n + 1; wbuf[n] = v end
			end
			table.sort(wbuf, function(a,b) return a < b end)
			local med = wbuf[floor(n/2) + 1]
			local own = rimStepRaw[ri]
			local cap = med * 2.0
			rimStep[ri] = own < cap and own or cap
			for i = 1, n do wbuf[i] = nil end
		end
	end

	local maxStep = 0
	for ri = 0, FILL_NUM_RAYS - 1 do
		if rimStep[ri] and rimStep[ri] > maxStep then maxStep = rimStep[ri] end
	end

	local atan2 = math.atan2
	local sqrt  = math.sqrt
	local twoPi = 2 * pi
	local raysPerRad = FILL_NUM_RAYS / twoPi

	-- Per-cell IDW target from rim peaks (also used in Phase 3).
	local basinT = {}
	local function idwTarget(x, z)
		local sumW, sumWH = 0, 0
		for j = 1, rimN do
			local ddx = rimPX[j] - x
			local ddz = rimPZ[j] - z
			local w = 1 / (ddx*ddx + ddz*ddz + 1)
			sumW  = sumW  + w
			sumWH = sumWH + w * rimPH[j]
		end
		return sumWH / sumW
	end

	for dz = -maxStep, maxStep do
		local z = cz + dz * ss
		if z >= 0 and z <= mapZ then
			for dx = -maxStep, maxStep do
				local x = cx + dx * ss
				if x >= 0 and x <= mapX then
					local dist = sqrt(dx * dx + dz * dz)
					if dist <= maxStep then
						local ang = atan2(dz, dx)
						if ang < 0 then ang = ang + twoPi end
						-- Interpolate rimStep linearly between the two
						-- surrounding rays so edges stay smooth.
						local raw = ang * raysPerRad
						local riF = floor(raw) % FILL_NUM_RAYS
						local riC = (riF + 1) % FILL_NUM_RAYS
						local rsF = rimStep[riF]
						local rsC = rimStep[riC]
						if rsF and rsC then
							local t = raw - floor(raw)
							local rsLerp = rsF * (1 - t) + rsC * t
							if dist <= rsLerp + 1 then
								if bN < fillMaxCells then
									bN = bN + 1
									basinX[bN] = x
									basinZ[bN] = z
									basinT[bN] = idwTarget(x, z)
								end
							end
						end
					end
				end
			end
		end
	end

	if bN >= fillMaxCells then
		Spring.Echo("[Terraform Fill] Basin hit cell cap — bowl too large")
	end

	-- spillover (informational only)
	local spillover = rimPH[1]
	for i = 2, rimN do
		if rimPH[i] < spillover then spillover = rimPH[i] end
	end

	Spring.Echo(string.format("[Terraform Fill] click=%.1f  rimPeaks=%d  spillover=%.1f  maxStep=%d",
		startH, rimN, spillover, maxStep))

	-- Show all rim peak heights for diagnosis
	local rimStr = ""
	for i = 1, rimN do
		rimStr = rimStr .. string.format("%.0f ", rimPH[i])
	end
	Spring.Echo("[Terraform Fill] rimHeights: " .. rimStr)

	-- ── Phase 3+4: Raise each basin cell to its (already computed) IDW target
	local snapFlat = scratchSnapFlat
	local sCount   = 0
	local hBuf     = scratchHeightData
	local hIdx     = 0

	for i = 1, bN do
		local x, z = basinX[i], basinZ[i]
		local target = basinT[i]
		local curH = Spring.GetGroundHeight(x, z)
		if curH < target - 0.1 then
			local base = sCount * 3
			snapFlat[base + 1] = x; snapFlat[base + 2] = z; snapFlat[base + 3] = curH
			sCount = sCount + 1; hIdx = hIdx + 1
			local he = hBuf[hIdx]
			if he then he[1] = x; he[2] = z; he[3] = target
			else hBuf[hIdx] = {x, z, target} end
		end
	end
	for i = hIdx + 1, scratchHeightDataMax do hBuf[i] = nil end
	scratchHeightDataMax = hIdx

	Spring.Echo(string.format("[Terraform Fill] basin=%d  raised=%d", bN, hIdx))

	-- Diagnostic: show target height range for raised cells
	if hIdx > 0 then
		local tMin, tMax = hBuf[1][3], hBuf[1][3]
		local cMin, cMax = 99999, -99999
		for i = 1, hIdx do
			if hBuf[i][3] < tMin then tMin = hBuf[i][3] end
			if hBuf[i][3] > tMax then tMax = hBuf[i][3] end
		end
		for i = 1, bN do
			local ch = Spring.GetGroundHeight(basinX[i], basinZ[i])
			if ch < cMin then cMin = ch end
			if ch > cMax then cMax = ch end
		end
		Spring.Echo(string.format("[Terraform Fill] targetRange=[%.1f..%.1f] basinCurH=[%.1f..%.1f]",
			tMin, tMax, cMin, cMax))
	end

	if hIdx > 0 then
		applyHeightChanges(hBuf, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
		spawnDust(cx, cz, min(400, hIdx * ss * 0.5))
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	-- Defensive: engine always passes a string, but a malformed caller or
	-- future API change could pass nil/non-string — avoid a traceback.
	if type(msg) ~= "string" or #msg == 0 then return false end
	-- Strip cheat-certification prefix embedded by the widget when cheat was on.
	-- Certified messages are trusted even when live cheat mode is false (e.g. in replays).
	local certified = msg:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
	if certified then
		msg = msg:sub(CHEAT_SIG_LEN + 1)
	end
	if msg == UNDO_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		if #undoStack == 0 then
			return true
		end

		finalizeMerge()

		local snapshot = undoStack[#undoStack]
		undoStack[#undoStack] = nil
		local vertexCount = snapshot.vertexCount or 0
		totalVertexCount = totalVertexCount - vertexCount

		-- Capture current heights into a parallel bbox snapshot for redo
		local redoSnapshot = captureCurrentForSnapshot(snapshot)
		redoSnapshot.strokeId = snapshot.strokeId

		if DIAG then
			Spring.Echo(string.format("[TFBrush DIAG] UNDO: verts=%d remaining=%d",
				vertexCount, #undoStack))
		end

		-- Restore the before-heights via SetHeightMapFunc (batched, single RecalcArea)
		applySnapshotHeights(snapshot)

		if vertexCount > 0 then
			redoStack[#redoStack + 1] = redoSnapshot
			totalVertexCount = totalVertexCount + vertexCount
			if #redoStack > MAX_UNDO then
				local old = redoStack[1]
				totalVertexCount = totalVertexCount - (old.vertexCount or 0)
				table.remove(redoStack, 1)
			end
		end
		evictOldSnapshots()
		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
		return true
	end

	if msg == UNDO_STROKE_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end
		if #undoStack == 0 then return true end

		finalizeMerge()

		-- If a previous stroke undo is still in progress, flush it immediately
		if pendingUndoEntries and #pendingUndoEntries > 0 then
			for i = 1, #pendingUndoEntries do
				local entry = pendingUndoEntries[i]
				local vertexCount = entry.vertexCount or 0
				local redoSnapshot = captureCurrentForSnapshot(entry)
				redoSnapshot.strokeId = pendingUndoStrokeId
				applySnapshotHeights(entry)
				redoStack[#redoStack + 1] = redoSnapshot
				totalVertexCount = totalVertexCount + vertexCount
			end
			pendingUndoEntries = {}
			pendingUndoStrokeId = nil
		end

		-- Identify the stroke ID of the top entry
		local targetStrokeId = undoStack[#undoStack].strokeId

		-- Pop all entries belonging to this stroke into the pending queue
		local collected = {}
		while #undoStack > 0 do
			local top = undoStack[#undoStack]
			if top.strokeId ~= targetStrokeId then break end
			undoStack[#undoStack] = nil
			local vertexCount = top.vertexCount or 0
			totalVertexCount = totalVertexCount - vertexCount
			collected[#collected + 1] = top
		end

		-- Store for gradual application in GameFrame (one entry per frame)
		pendingUndoEntries = collected
		pendingUndoStrokeId = targetStrokeId

		if DIAG then
			Spring.Echo(string.format("[TFBrush DIAG] UNDO_STROKE: strokeId=%d queued=%d remaining=%d",
				targetStrokeId or -1, #collected, #undoStack))
		end

		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
		return true
	end

    if msg == REDO_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		if #redoStack == 0 then
			return true
		end

		finalizeMerge()

		local snapshot = redoStack[#redoStack]
		redoStack[#redoStack] = nil
		local vertexCount = snapshot.vertexCount or 0
		totalVertexCount = totalVertexCount - vertexCount

		-- Capture current heights into a parallel bbox snapshot for undo
		local undoSnapshot = captureCurrentForSnapshot(snapshot)
		undoSnapshot.strokeId = snapshot.strokeId

		-- Re-apply the terraform heights via SetHeightMapFunc (batched, single RecalcArea)
		applySnapshotHeights(snapshot)

		if vertexCount > 0 then
			undoStack[#undoStack + 1] = undoSnapshot
			totalVertexCount = totalVertexCount + vertexCount
			if #undoStack > MAX_UNDO then
				local old = undoStack[1]
				totalVertexCount = totalVertexCount - (old.vertexCount or 0)
				table.remove(undoStack, 1)
			end
		end
		evictOldSnapshots()
		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
		return true
    end

	if msg == MERGE_END_HEADER then
		finalizeMerge()
		return true
	end

	if msg == STROKE_END_HEADER then
		finalizeMerge()
		currentStrokeId = currentStrokeId + 1
		return true
	end

	if msg:sub(1, IMPORT_HEADER_LENGTH) == IMPORT_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local parts = parseParts(msg:sub(IMPORT_HEADER_LENGTH + 1))
		local x = tonumber(parts[1])
		if not x then
			return true
		end

		local squareSize = Game.squareSize
		local mapSizeZ = Game.mapSizeZ

		local snapFlat = scratchSnapFlat
		local sCount = 0
		for j = 2, #parts do
			local h = tonumber(parts[j])
			if h then
				local z = (j - 2) * squareSize
				if z <= mapSizeZ then
					local base = sCount * 3
					snapFlat[base + 1] = x
					snapFlat[base + 2] = z
					snapFlat[base + 3] = h
					sCount = sCount + 1
				end
			end
		end

		if sCount > 0 then
			applyHeightChangesFlat(snapFlat, sCount)
		end
		return true
	end

	if msg == IMPORT_END_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end
		-- Adding 0 across the whole map is a no-op for heights but forces the
		-- engine to mark every heightmap chunk dirty, so the GPU mesh, normals,
		-- shadow pass and minimap all refresh without needing a local edit.
		Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 0)
		return true
	end

	if msg:sub(1, RESTORE_HEADER_LENGTH) == RESTORE_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local payload = msg:sub(RESTORE_HEADER_LENGTH + 1)
		local parts = parseParts(payload)

		local centerX = tonumber(parts[1])
		local centerZ = tonumber(parts[2])
		local radius = tonumber(parts[3])
		local shape = parts[4] or "circle"
		local angleDeg = tonumber(parts[5]) or 0
		local curve = tonumber(parts[6]) or 1.0
		local intensity = tonumber(parts[7]) or 1.0
		local lengthScale = tonumber(parts[8]) or 1.0
		local restoreStrength = tonumber(parts[9]) or 1.0

		if not centerX or not centerZ or not radius then
			return true
		end

		radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
		curve = max(0.1, min(5.0, curve))
		intensity = max(0.1, min(100.0, intensity))
		lengthScale = max(0.2, min(5.0, lengthScale))
		restoreStrength = max(0.0, min(1.0, restoreStrength))

		applyRestore(centerX, centerZ, radius, shape, angleDeg, curve, intensity, lengthScale, restoreStrength)
		return true
	end

	if msg == FULL_RESTORE_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end
		finalizeMerge()
		local squareSize = Game.squareSize
		local mapSizeX = Game.mapSizeX
		local mapSizeZ = Game.mapSizeZ
		-- Snapshot current heights into the scratch flat buffer for undo, then
		-- convert to bbox-grid format. Full-map snapshots are the ideal case for
		-- the orig-delta encoding: every cell that already matches its map
		-- original gets mask=2 with no hgrid entry stored.
		local snapFlat = scratchSnapFlat
		local vCount = 0
		for iz = 0, mapSizeZ, squareSize do
			for ix = 0, mapSizeX, squareSize do
				local base = vCount * 3
				snapFlat[base + 1] = ix
				snapFlat[base + 2] = iz
				snapFlat[base + 3] = Spring.GetGroundHeight(ix, iz)
				vCount = vCount + 1
			end
		end
		-- Clear redo, build bbox snapshot and push to undo (bypassing the per-call
		-- vertex-cap check in pushSnapshotFromFlat — full-restore is intentional).
		for i = 1, #redoStack do
			totalVertexCount = totalVertexCount - (redoStack[i].vertexCount or 0)
		end
		redoStack = {}
		local snapshot = flatToBboxSnapshot(snapFlat, vCount)
		snapshot.strokeId = currentStrokeId
		undoStack[#undoStack + 1] = snapshot
		totalVertexCount = totalVertexCount + vCount
		if #undoStack > MAX_UNDO then
			local old = undoStack[1]
			totalVertexCount = totalVertexCount - (old.vertexCount or 0)
			table.remove(undoStack, 1)
		end
		evictOldSnapshots()
		-- Apply original heights to all map points
		Spring.SetHeightMapFunc(function()
			for iz = 0, mapSizeZ, squareSize do
				for ix = 0, mapSizeX, squareSize do
					Spring.SetHeightMap(ix, iz, Spring.GetGroundOrigHeight(ix, iz))
				end
			end
		end)
		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
		return true
	end

	if msg:sub(1, SPLINE_RAMP_HEADER_LENGTH) == SPLINE_RAMP_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local parts = parseParts(msg:sub(SPLINE_RAMP_HEADER_LENGTH + 1))

		local width = tonumber(parts[1])
		local numPts = tonumber(parts[2])
		if not width or not numPts or numPts < 2 then
			return true
		end

		width = max(MIN_RADIUS, min(MAX_RADIUS, width))
		local waypoints = {}
		for i = 1, numPts do
			local px = tonumber(parts[2 + (i - 1) * 2 + 1])
			local pz = tonumber(parts[2 + (i - 1) * 2 + 2])
			if not px or not pz then
				return true
			end
			waypoints[i] = { px, pz }
		end

		local clayFlag = parts[2 + numPts * 2 + 1]
		local splineClayMode = (clayFlag == "1")
		local splineDustMode = (parts[2 + numPts * 2 + 2] == "1")
		local splineSnapFull = (parts[2 + numPts * 2 + 3] == "1")
		applySplineRamp(waypoints, width, splineClayMode, splineSnapFull)
		if splineDustMode and numPts >= 2 then
			local midIdx = floor(numPts / 2)
			spawnDust(waypoints[midIdx][1], waypoints[midIdx][2], width)
		end
		return true
	end

	if msg:sub(1, RAMP_HEADER_LENGTH) == RAMP_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local parts = parseParts(msg:sub(RAMP_HEADER_LENGTH + 1))

		local sX = tonumber(parts[1])
		local sZ = tonumber(parts[2])
		local sY = tonumber(parts[3])
		local eX = tonumber(parts[4])
		local eZ = tonumber(parts[5])
		local eY = tonumber(parts[6])
		local width = tonumber(parts[7])

		if not sX or not sZ or not sY or not eX or not eZ or not eY or not width then
			return true
		end

		local rampClayFlag = parts[8]
		local rampClayMode = (rampClayFlag == "1")
		local rampDustMode = (parts[9] == "1")
		width = max(MIN_RADIUS, min(MAX_RADIUS, width))
		applyRamp(sX, sZ, sY, eX, eZ, eY, width, rampClayMode)
		if rampDustMode then
			local midX = (sX + eX) * 0.5
			local midZ = (sZ + eZ) * 0.5
			spawnDust(midX, midZ, width)
		end
		return true
	end

	if msg:sub(1, NOISE_HEADER_LENGTH) == NOISE_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local payload = msg:sub(NOISE_HEADER_LENGTH + 1)
		local parts = parseParts(payload)

		local centerX = tonumber(parts[1])
		local centerZ = tonumber(parts[2])
		local radius = tonumber(parts[3])
		local shape = parts[4] or "circle"
		local angleDeg = tonumber(parts[5]) or 0
		local curve = tonumber(parts[6]) or 1.0
		local intensity = tonumber(parts[7]) or 1.0
		local lengthScale = tonumber(parts[8]) or 1.0
		local noiseType = parts[9] or "perlin"
		local nScale = tonumber(parts[10]) or 64
		local octaves = tonumber(parts[11]) or 4
		local persistence = tonumber(parts[12]) or 0.5
		local lacunarity = tonumber(parts[13]) or 2.0
		local seed = tonumber(parts[14]) or 0
		local noiseDustMode = (parts[15] == "1")

		if not centerX or not centerZ or not radius then
			return true
		end

		radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
		curve = max(0.1, min(5.0, curve))
		intensity = max(0.1, min(100.0, intensity))
		lengthScale = max(0.2, min(5.0, lengthScale))
		nScale = max(8, min(512, nScale))
		octaves = max(1, min(8, octaves))
		persistence = max(0.1, min(0.9, persistence))
		lacunarity = max(1.0, min(4.0, lacunarity))
		seed = max(0, min(9999, seed))

		applyNoise(centerX, centerZ, radius, shape, angleDeg, curve, intensity, lengthScale, noiseType, nScale, octaves, persistence, lacunarity, seed)
		if noiseDustMode then
			spawnDust(centerX, centerZ, radius, intensity)
		end
		return true
	end

	if msg:sub(1, FILL_HEADER_LENGTH) == FILL_HEADER then
		if not isTerraformAllowed(certified) then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end
		local parts = parseParts(msg:sub(FILL_HEADER_LENGTH + 1))
		local fillX = tonumber(parts[1])
		local fillZ = tonumber(parts[2])
		if fillX and fillZ then
			applyFill(fillX, fillZ)
		end
		return true
	end

	if msg:sub(1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
		return
	end

	if not isTerraformAllowed(certified) then
		Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
		return true
	end

	local payload = msg:sub(PACKET_HEADER_LENGTH + 1)
	local parts = parseParts(payload)

	local direction = tonumber(parts[1])
	local centerX = tonumber(parts[2])
	local centerZ = tonumber(parts[3])
	local radius = tonumber(parts[4])
	local shape = parts[5] or "circle"
	local angleDeg = tonumber(parts[6]) or 0
	local curve = tonumber(parts[7]) or 1.0
	local heightMin = tonumber(parts[8])
	local heightMax = tonumber(parts[9])
	local intensity = tonumber(parts[10]) or 1.0
	local lengthScale = tonumber(parts[11]) or 1.0
	local clayMode = parts[12] == "1"
	local dustMode = parts[13] == "1"
	local opacity = tonumber(parts[14]) or 0.3
	local instant = parts[15] == "1"
	local flattenHeight = tonumber(parts[16])
	if parts[17] then
		ringInnerRatio = max(0.05, min(0.95, tonumber(parts[17]) or 0.6))
	end

	if not direction or not centerX or not centerZ or not radius then
		return true
	end

	radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
	curve = max(0.1, min(5.0, curve))
	intensity = max(0.1, min(100.0, intensity))
	lengthScale = max(0.2, min(5.0, lengthScale))
	opacity = max(0.01, min(1.0, opacity))

	applyTerraform(centerX, centerZ, radius, direction, shape, angleDeg, curve, heightMin, heightMax, intensity, lengthScale, clayMode, opacity, flattenHeight, instant)
	if dustMode then
		spawnDust(centerX, centerZ, radius, intensity)
	end
	return true
end


