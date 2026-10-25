local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Terraform Brush",
		desc = "Raises, lowers, or levels terrain with configurable shape, radius, and rotation. Requires /cheat.",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	-- Registered as a sync action (table lookup by message name) instead of a
	-- RecvFromSynced callin, which would be invoked for every SendToUnsynced
	-- message from every synced gadget. Returning true stops the broadcast.
	local function onStacks(_, undoCount, redoCount)
		if Script.LuaUI("TerraformBrushStackUpdate") then
			Script.LuaUI.TerraformBrushStackUpdate(undoCount, redoCount)
		end
		return true
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("TerraformBrushStacks", onStacks)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("TerraformBrushStacks")
	end
	return
end

-- Prefix embedded in messages sent by an authorised editor session.
local CHEAT_SIG = "$c$"

-- Map-editor sessions accept certified messages without live cheat: /cheat is a
-- toggle several widgets nudge independently, and two of them seeing "off" at
-- once flip it back off mid-import. The mapeditor modoption comes from the start
-- script, is synced, and cannot be forged by a client. Replays need no special
-- case: demos replay the /cheat command. (Spring.IsReplay is nil in synced code.)
local MAP_EDITOR_SESSION = false
do
	local mapEditorOpt = (Spring.GetModOptions() or {}).mapeditor
	MAP_EDITOR_SESSION = mapEditorOpt == true or mapEditorOpt == 1 or mapEditorOpt == "1"
end

local mapDamageEnabled = Game.mapDamage ~= false

-- Refusal echoes are throttled to one per ~2 s: a drag sends dozens of packets
-- a second. Game frames keep the throttle deterministic (RecvLuaMsg is synced).
local lastGateEchoFrame = -1000
local function echoGate(text)
	local frame = Spring.GetGameFrame()
	if frame - lastGateEchoFrame >= 60 then
		lastGateEchoFrame = frame
		Spring.Echo(text)
	end
end

-- Engine trap: synced height changes reach the rendered heightmap only where
-- the viewer's allyteam has LOS, so edits outside vision change the sim but not
-- the picture (and pregame ground rays hit stale heights). Grant the editing
-- allyteam global LOS on its first accepted terraform message.
local function ensureEditorLos(playerID)
	if not playerID then
		return
	end
	local _, _, spec, _, allyTeamID = Spring.GetPlayerInfo(playerID, false)
	if spec or not allyTeamID then
		return
	end
	if not Spring.GetGlobalLos(allyTeamID) then
		Spring.SetGlobalLos(allyTeamID, true)
	end
end

local function isTerraformAllowed(certified, playerID)
	if not mapDamageEnabled then
		echoGate(
			"[Terraform Brush] Map deformation is disabled (disablemapdamage modoption or notDeformable map). Terraform cannot work."
		)
		return false
	end
	-- $c$ is self-asserted by the sender, so honour it only inside a map-editor
	-- session; elsewhere a modified client could prefix it in a no-cheat game.
	local allowed = Spring.IsCheatingEnabled() or (certified and MAP_EDITOR_SESSION)
	if allowed then
		ensureEditorLos(playerID)
	end
	return allowed
end

local PACKET_HEADER = "$terraform_brush$"
local RAMP_HEADER = "$terraform_ramp$"
local SPLINE_RAMP_HEADER = "$terraform_ramp_spline$"
local RESTORE_HEADER = "$terraform_restore$"
local FULL_RESTORE_HEADER = "$terraform_full_restore$"
local IMPORT_HEADER = "$terraform_import$"
local IMPORT_END_HEADER = "$terraform_import_end$"
local UNDO_HEADER = "$terraform_undo$"
local UNDO_STROKE_HEADER = "$terraform_undo_stroke$"
local REDO_HEADER = "$terraform_redo$"
local MERGE_END_HEADER = "$terraform_merge_end$"
local STROKE_END_HEADER = "$terraform_stroke_end$"
local NOISE_HEADER = "$terraform_noise$"
local ERODE_HEADER = "$terraform_erode$"
local WARM_HEADER = "$terraform_warm$"
local REMAP_HEADER = "$terraform_remap$"
local REMAP_HEADER_LENGTH = #REMAP_HEADER
local AUTORAMP_HEADER = "$terraform_autoramp$"
local HEIGHT_STEP = 8
local MAX_UNDO = 10000
-- Vertex budget across all undo and redo entries: about 24 bytes per vertex,
-- so 8 M is about 192 MB, well under the 1.5 GB synced LuaRules VM cap. Keep
-- one undo entry per tick (merging across ticks leaves striped terrain on
-- undo), so eviction is the only knob.
local MAX_SNAPSHOT_VERTICES = 8000000

local undoStack = {}
local redoStack = {}
local totalVertexCount = 0 -- track approximate memory usage

-- Import-completion counter, published as game rules param tfb_import_done. The
-- map project loader waits on it because only the sim knows when the streamed
-- columns have landed; a rules param, unlike SendToUnsynced, survives /luaui reload.
local importDoneCounter = 0

local currentStrokeId = 0 -- incremented on each STROKE_END; tags all entries in a stroke
local MAX_RADIUS = 2000
local MIN_RADIUS = 8
local MAX_BLUR_STEP = 6 -- smooth mode: widest box half-width (grid cells) at max intensity
local MAX_SMUDGE_BUFFERS = 16 -- smudge mode: carried height grabs alive at once (one per stroke chain)

local ringInnerRatio = 0.6

-- Reusable scratch tables to reduce GC pressure in hot paths
local scratchHeightData = {}
local scratchHeightDataMax = 0 -- high-water mark for reliable trimming (avoids # on reused table)
local scratchSnapFlat = {} -- flat buffer: x,z,h,x,z,h,... (no sub-table allocation)
local scratchBlurHeights = {} -- padded (sw+2)x(sh+2) height grid for smooth-mode local blur
local scratchBlurSAT = {} -- summed-area table over scratchBlurHeights (dense box mean)
local smudgeBuffers = {} -- smudge mode: carried brush-space height grabs, one per active stroke chain
local smudgeClock = 0 -- smudge dab counter, used to retire chains whose stroke has ended
local scratchParts = {}

-- Parse a space-separated payload into scratchParts, reusing the table
local function parseParts(payload)
	local idx = 0
	for word in payload:gmatch("[%-%.%w]+") do
		idx = idx + 1
		scratchParts[idx] = word
	end
	for i = idx + 1, #scratchParts do
		scratchParts[i] = nil
	end
	return scratchParts
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

-- Apply a batch of {x, z, newHeight} entries to the heightmap. SetHeightMapFunc
-- takes a function, so the workers are module-level closures fed via upvalues.
local nanHeightSkipped = false
local ahcData, ahcCount = nil, 0

local function applyHeightChangesWorker()
	local SetHeightMap = Spring.SetHeightMap
	for i = 1, ahcCount do
		local entry = ahcData[i]
		local h = entry[3]
		if h == h then -- NaN check: NaN ~= NaN
			SetHeightMap(entry[1], entry[2], h)
		else
			nanHeightSkipped = true
		end
	end
end

local function applyHeightChanges(heightData, count)
	count = count or #heightData
	if count == 0 then
		return
	end

	ahcData, ahcCount = heightData, count
	Spring.SetHeightMapFunc(applyHeightChangesWorker)
	ahcData = nil
	if nanHeightSkipped then
		Spring.Echo("[Terraform Brush] Warning: NaN height skipped — possible div0 in brush math")
		nanHeightSkipped = false
	end
end

-- Flat-buffer variant: reads {x1,z1,h1, x2,z2,h2,...} without sub-tables.
-- Used by the heightmap import, which streams columns as flat triplets.
local ahcFlat, ahcFlatCount = nil, 0

local function applyHeightChangesFlatWorker()
	local SetHeightMap = Spring.SetHeightMap
	for i = 0, ahcFlatCount - 1 do
		local base = i * 3
		local h = ahcFlat[base + 3]
		if h == h then -- NaN check
			SetHeightMap(ahcFlat[base + 1], ahcFlat[base + 2], h)
		else
			nanHeightSkipped = true
		end
	end
end

local function applyHeightChangesFlat(flatData, vertexCount)
	if vertexCount == 0 then
		return
	end
	ahcFlat, ahcFlatCount = flatData, vertexCount
	Spring.SetHeightMapFunc(applyHeightChangesFlatWorker)
	ahcFlat = nil
	if nanHeightSkipped then
		Spring.Echo("[Terraform Brush] Warning: NaN height skipped in heightmap import")
		nanHeightSkipped = false
	end
end

-- BBOX-GRID SNAPSHOT FORMAT
-- Snapshots store touched cells as a 2D grid over their world bbox. Mask values:
--   nil : cell not in this snapshot
--   1   : cell touched, original height stored in hgrid[i]
--   2   : cell touched, original height equals Spring.GetGroundOrigHeight
--         (hgrid[i] not stored, which saves a float on untouched terrain)
-- Index: i = iz*w + ix + 1 with ix=(x-minX)/ss, iz=(z-minZ)/ss, where ss is
-- Game.squareSize stored in snap.ss so cells always map back to the same coords.
local GetGroundOrigHeight = Spring.GetGroundOrigHeight
local GetGroundHeight = Spring.GetGroundHeight
local SetHeightMap = Spring.SetHeightMap
local SetHeightMapFunc = Spring.SetHeightMapFunc

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
		if x < minX then
			minX = x
		end
		if x > maxX then
			maxX = x
		end
		if z < minZ then
			minZ = z
		end
		if z > maxZ then
			maxZ = z
		end
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
		minX = minX,
		minZ = minZ,
		w = w,
		h = h,
		ss = ss,
		mask = mask,
		hgrid = hgrid,
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
					if val == val then -- NaN check
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
		minX = minX,
		minZ = minZ,
		w = w,
		h = h,
		ss = ss,
		mask = mask,
		hgrid = hgrid,
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

-- Push a ready bbox-grid snapshot as a new undo entry. Bookkeeping shared by
-- the flat converter below and the per-tick batch commit (flushBatch).
local function pushBboxSnapshot(snapshot)
	local vertexCount = snapshot.vertexCount or 0

	for i = 1, #redoStack do
		totalVertexCount = totalVertexCount - (redoStack[i].vertexCount or 0)
	end
	redoStack = {}

	snapshot.strokeId = currentStrokeId
	undoStack[#undoStack + 1] = snapshot
	totalVertexCount = totalVertexCount + vertexCount
	if #undoStack > MAX_UNDO then
		local old = undoStack[1]
		totalVertexCount = totalVertexCount - (old.vertexCount or 0)
		table.remove(undoStack, 1)
	end

	evictOldSnapshots()
	SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
end

-- Convert a flat {x,z,h,...} buffer to a bbox-grid snapshot and push it. One
-- undo entry per tick is mandatory (merging ticks stripes the terrain on undo):
-- brush dabs commit through flushBatch, the ramp, noise, erode and fill ops here.
local function pushSnapshotFromFlat(flatBuf, vertexCount)
	if vertexCount == 0 then
		return
	end
	if vertexCount > MAX_SNAPSHOT_VERTICES then
		return
	end
	pushBboxSnapshot(flatToBboxSnapshot(flatBuf, vertexCount))
end

-- Snapshot every heightmap vertex into one undo entry. Skips the per-call
-- MAX_SNAPSHOT_VERTICES gate on purpose: whole-map edits are explicit user
-- actions, and cells still at their original height cost only a mask entry.
local function snapshotWholeMap()
	local squareSize = Game.squareSize
	local snapFlat = scratchSnapFlat
	local vCount = 0
	for iz = 0, Game.mapSizeZ, squareSize do
		for ix = 0, Game.mapSizeX, squareSize do
			local base = vCount * 3
			snapFlat[base + 1] = ix
			snapFlat[base + 2] = iz
			snapFlat[base + 3] = GetGroundHeight(ix, iz)
			vCount = vCount + 1
		end
	end
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
end

-- Re-snap every feature to the ground after a whole-map height change, so
-- trees and rocks do not end up floating or buried.
local function resnapAllFeatures()
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		local fx, fy, fz = Spring.GetFeaturePosition(features[i])
		if fx then
			Spring.SetFeaturePosition(features[i], fx, fy, fz, true)
		end
	end
end

-- Whole-map height range edit, behind the Dimensions window. "scale" remaps
-- every vertex linearly from the live extremes onto [newMin, newMax]; "clamp"
-- only cuts vertices outside the range (useful for shaving a runaway peak).
-- Only the live heightmap changes, never the original, so the edit is undoable
-- and the restore brush stays anchored to the map as loaded.
local function remapMapHeights(newMin, newMax, clampOnly)
	local squareSize = Game.squareSize
	local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

	-- Scan for the true extremes rather than trusting Spring.GetGroundExtremes,
	-- so the terrain lands on [newMin, newMax] exactly.
	local curMin, curMax = math.huge, -math.huge
	for iz = 0, mapSizeZ, squareSize do
		for ix = 0, mapSizeX, squareSize do
			local h = GetGroundHeight(ix, iz)
			if h < curMin then
				curMin = h
			end
			if h > curMax then
				curMax = h
			end
		end
	end

	local scale
	if not clampOnly then
		-- A flat map has no relief to stretch and would divide by zero.
		if curMax - curMin < 0.01 then
			echoGate("[Terraform Brush] Map is flat - nothing to rescale. Raise some terrain first.")
			return
		end
		scale = (newMax - newMin) / (curMax - curMin)
	elseif curMin >= newMin and curMax <= newMax then
		echoGate("[Terraform Brush] Terrain already inside that range - nothing to clamp.")
		return
	end

	snapshotWholeMap()

	Spring.SetHeightMapFunc(function()
		for iz = 0, mapSizeZ, squareSize do
			for ix = 0, mapSizeX, squareSize do
				local h = GetGroundHeight(ix, iz)
				local nh
				if clampOnly then
					nh = (h < newMin and newMin) or (h > newMax and newMax) or h
				else
					nh = newMin + (h - curMin) * scale
				end
				if nh ~= h then
					SetHeightMap(ix, iz, nh)
				end
			end
		end
	end)

	-- SetHeightMapFunc does not regenerate the smooth mesh aircraft fly over.
	Spring.RebuildSmoothMesh(0, 0, mapSizeX, mapSizeZ)
	resnapAllFeatures()

	SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
	Spring.Echo(
		string.format(
			"[Terraform Brush] Height range %s: %.1f..%.1f -> %.1f..%.1f",
			clampOnly and "clamped" or "rescaled",
			curMin,
			curMax,
			clampOnly and max(curMin, newMin) or newMin,
			clampOnly and min(curMax, newMax) or newMax
		)
	)
end

local DUST_CEGS = { "dust_cloud", "dust_cloud_dirt_light", "dust_cloud_fast", "dust_cloud_dirt", "dirtpoof" }
local DUST_COUNT_PER_100 = 12 -- puffs per 100 radius
local RUMBLE_SOUNDS =
	{ "sounds/atmos/lavarumbleshort1.wav", "sounds/atmos/lavarumbleshort2.wav", "sounds/atmos/lavarumbleshort3.wav" }

local SPLASH_CEGS_BIG = { "splash-large", "splash-huge", "splash-medium" }
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
	Spring.PlaySoundFile(WATER_SOUNDS[random(1, #WATER_SOUNDS)], vol, centerX, 0, centerZ, "sfx")
end

local function spawnDust(centerX, centerZ, radius, intensity)
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
		-- Skip underwater puffs: dust over submerged terrain spawns oversized
		-- clouds and tanks the framerate. Water FX needs a submerged centre.
		if y >= 0 then
			local ceg = DUST_CEGS[random(1, #DUST_CEGS)]
			local scale = radius * (0.0125 + random() * 0.05) * intensityScale
			SpawnCEG(ceg, x, y, z, 0, (0.5 + random() * 1.5) * intensityScale, 0, scale, 0)
		end
	end
	local vol = math.min(4.0, radius / 100 * intensityScale)
	local y = Spring.GetGroundHeight(centerX, centerZ)
	Spring.PlaySoundFile(RUMBLE_SOUNDS[random(1, #RUMBLE_SOUNDS)], vol, centerX, y, centerZ, "sfx")
end

-- Memoised rotation: angleDeg is constant within one footprint, so sin/cos run once.
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

local function regularPolygonFalloff(dx, dz, radius, angleDeg, numSides)
	local lx, lz = rotatePoint(dx, dz, -angleDeg)
	local dist = (lx * lx + lz * lz) ^ 0.5
	if dist < 0.001 then
		return 1
	end
	local angle = atan2(lz, lx)
	if angle < 0 then
		angle = angle + 2 * pi
	end
	local sectorAngle = 2 * pi / numSides
	local angleInSector = (angle % sectorAngle) - sectorAngle / 2
	local apothem = radius * cos(pi / numSides)
	local edgeDist = apothem / cos(angleInSector)
	if dist > edgeDist then
		return nil
	end
	return 1 - dist / edgeDist
end

local function computeFalloff(dx, dz, radius, shape, angleDeg, curve, lengthScale)
	lengthScale = lengthScale or 1.0
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
		if not f then
			return nil
		end
		rawFalloff = f
	elseif shape == "hexagon" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local f = regularPolygonFalloff(lx, lz, radius, 0, 6)
		if not f then
			return nil
		end
		rawFalloff = f
	elseif shape == "octagon" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local f = regularPolygonFalloff(lx, lz, radius, 0, 8)
		if not f then
			return nil
		end
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

-- FALLOFF STAMP CACHE
-- computeFalloff is the hot spot of applyTerraform (about 395 k calls per tick
-- at radius 2000, each a sin/cos rotation and a power), so the per-cell falloff
-- field is cached, keyed by quantised params:
--   radius      -> integer
--   angleDeg    -> 2 deg steps, coarser for huge footprints (quantiseStampParams)
--   curve       -> 0.05 step
--   lengthScale -> 0.05 step
--   ringRatio   -> 0.02 step (only matters for "ring" shape)
-- LRU eviction by cell budget: a radius-2000 stamp is about 500 k slots, and the
-- budget keeps every angle of a small or mid FOLLOW STROKE drag resident.
local FALLOFF_STAMP_CELL_BUDGET = 3000000
local FALLOFF_EPSILON = 1 / 255 -- below this, treat as zero (sub-quantisation)
local falloffStampCache = {}
local falloffStampGen = {} -- key -> last-use generation (monotonic clock)
local falloffStampSize = {} -- key -> w*h, for the budget accounting
---@type number
local falloffStampCells = 0 -- data slots held by every cached stamp together
local falloffStampClock = 0

-- Cells one stamp of this radius / length scale occupies at grid step ss
-- (its bounding window; mirrors buildFalloffStamp's extent maths).
local function stampCellCount(radius, lengthScale, ss)
	local halfCells = floor(radius * max(1, lengthScale) * 1.42 / ss)
	local size = halfCells * 2 + 1
	return size * size
end

local function quantiseStampParams(radius, shape, angleDeg, curve, lengthScale, ringRatio, ss)
	local rQ = floor(radius)
	local cQ = floor(curve / 0.05 + 0.5) * 0.05
	local lQ = floor(lengthScale / 0.05 + 0.5) * 0.05
	local rrQ = floor(ringRatio / 0.02 + 0.5) * 0.02
	local aQ
	if (shape == "circle" or shape == "ring") and lQ == 1 then
		-- Rotation-invariant footprint: one stamp serves every angle.
		aQ = 0
	else
		-- 2 deg steps while a full rotation fits the cache; coarser (up to 30
		-- deg) for huge footprints so a FOLLOW drag cannot rebuild a 100 k-cell
		-- stamp per dab. The widget quantises its tangent to 2 deg as well.
		local aStep = 2
		local cells = stampCellCount(rQ, lQ, ss)
		if cells > 40000 then
			aStep = min(30, 2 * math.ceil(cells / 40000))
		end
		-- Wrap to [0,360) first so 359 and -1 share a stamp.
		local aN = angleDeg % 360
		aQ = floor(aN / aStep + 0.5) * aStep
		if aQ >= 360 then
			aQ = aQ - 360
		end
	end
	return rQ, aQ, cQ, lQ, rrQ
end

local function buildFalloffStamp(radius, shape, angleDeg, curve, lengthScale, ringRatio, ss)
	-- computeFalloff reads the module-level ringInnerRatio: override it with the
	-- quantised key value for the build, then restore.
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
		end
	end
	ringInnerRatio = prevRing
	return { w = size, h = size, cx = halfCells, cz = halfCells, data = data }
end

local function getFalloffStamp(radius, shape, angleDeg, curve, lengthScale, ringRatio, ss)
	local rQ, aQ, cQ, lQ, rrQ = quantiseStampParams(radius, shape, angleDeg, curve, lengthScale, ringRatio, ss)
	local key = string.format("%s|%d|%d|%.2f|%.2f|%.2f|%d", shape, rQ, aQ, cQ, lQ, rrQ, ss)
	falloffStampClock = falloffStampClock + 1
	local stamp = falloffStampCache[key]
	if stamp then
		falloffStampGen[key] = falloffStampClock
		return stamp
	end
	local built = buildFalloffStamp(rQ, shape, aQ, cQ, lQ, rrQ, ss)
	falloffStampCache[key] = built
	falloffStampGen[key] = falloffStampClock
	local builtCells = built.w * built.h
	falloffStampSize[key] = builtCells
	falloffStampCells = falloffStampCells + builtCells
	-- Evict least-recently-used stamps until the budget holds; the one just
	-- built stays whatever its size.
	while falloffStampCells > FALLOFF_STAMP_CELL_BUDGET do
		local oldKey, oldGen
		for k, g in pairs(falloffStampGen) do
			if k ~= key and (oldGen == nil or g < oldGen) then
				oldKey, oldGen = k, g
			end
		end
		if not oldKey then
			break
		end
		falloffStampCells = falloffStampCells - (falloffStampSize[oldKey] or 0)
		falloffStampCache[oldKey] = nil
		falloffStampGen[oldKey] = nil
		falloffStampSize[oldKey] = nil
	end
	return built
end

-- PER-TICK BATCH
-- A STROKE message carries every dab of a widget tick (up to 48). Each
-- SetHeightMapFunc triggers an engine RecalcArea (normals, slopes, pathing, LOS,
-- textures), so the dabs apply in order against a working copy of the cells they
-- touch and the tick commits once: one SetHeightMapFunc and one undo entry.
-- Dab k still sees dab k-1's writes, so the result matches sequential commits.
-- Cells are keyed by a map-global index (zCell * batchCols + xCell + 1); the
-- tables are sparse and reused, cleared by walking the touch lists.
local SQUARE_SIZE = Game.squareSize
local batchCols = floor(Game.mapSizeX / SQUARE_SIZE) + 1
---@type table<number, number>
local batchNew = {} -- cellIdx -> height written this tick (working copy)
---@type table<number, number>
local batchPre = {} -- cellIdx -> height read from the engine at first touch
---@type number[]
local batchWriteList = {} -- cellIdx per written cell, first-write order
local batchWriteN = 0
---@type number[]
local batchReadList = {} -- cellIdx per cell fetched from the engine
local batchReadN = 0
local batchOpen = false
-- Undo bbox of the tick, in cells; reset to +-huge by beginBatch.
local batchMinXc, batchMinZc, batchMaxXc, batchMaxZc = math.huge, math.huge, -math.huge, -math.huge

-- Pre-stroke heights: each cell's height before the current stroke first wrote
-- it, kept until STROKE_END. Clay planes are measured on these so a stroke lays
-- ONE layer; measuring the live ground stacks a disc per tick (concentric rings).
---@type table<number, number>
local strokeOrig = {}
---@type number[]
local strokeOrigList = {}
local strokeOrigN = 0
local STROKE_ORIG_LIMIT = 4000000

local function clearStrokeOrigin()
	for i = 1, strokeOrigN do
		strokeOrig[strokeOrigList[i]] = nil
	end
	strokeOrigN = 0
end

local function beginBatch()
	batchOpen = true
	batchWriteN = 0
	batchReadN = 0
	batchMinXc, batchMinZc = math.huge, math.huge
	batchMaxXc, batchMaxZc = -math.huge, -math.huge
	-- A stroke that never got its STROKE_END (widget reload mid-drag) must not
	-- pin the whole map's pre-stroke heights forever.
	if strokeOrigN > STROKE_ORIG_LIMIT then
		clearStrokeOrigin()
	end
end

-- Height of a cell as this tick currently sees it: this tick's write if any,
-- else the engine value, cached in batchPre on first read. Callers clamp the
-- cell into the map.
local function batchRead(xCell, zCell)
	local idx = zCell * batchCols + xCell + 1
	local v = batchNew[idx]
	if v ~= nil then
		return v
	end
	v = batchPre[idx]
	if v == nil then
		v = GetGroundHeight(xCell * SQUARE_SIZE, zCell * SQUARE_SIZE)
		batchPre[idx] = v
		batchReadN = batchReadN + 1
		batchReadList[batchReadN] = idx
	end
	return v
end

-- SetHeightMapFunc wants a function argument; this one walks the write list.
local function batchCommitWorker()
	for i = 1, batchWriteN do
		local idx = batchWriteList[i] or 0
		local h = batchNew[idx]
		if h == h then -- NaN check: NaN ~= NaN
			local zc = floor((idx - 1) / batchCols)
			SetHeightMap(((idx - 1) - zc * batchCols) * SQUARE_SIZE, zc * SQUARE_SIZE, h)
		else
			nanHeightSkipped = true
		end
	end
end

-- Commit the tick: one heightmap write, one undo entry, then reset.
local function flushBatch()
	batchOpen = false
	if batchWriteN > 0 then
		SetHeightMapFunc(batchCommitWorker)
		if nanHeightSkipped then
			Spring.Echo("[Terraform Brush] Warning: NaN height skipped — possible div0 in brush math")
			nanHeightSkipped = false
		end
		-- Undo entry built straight from the pre-tick heights in bbox-grid
		-- format (see flatToBboxSnapshot), with no flat intermediate.
		if batchWriteN <= MAX_SNAPSHOT_VERTICES then
			local w = batchMaxXc - batchMinXc + 1
			local h = batchMaxZc - batchMinZc + 1
			local mask, hgrid = {}, {}
			for i = 1, batchWriteN do
				local idx = batchWriteList[i] or 0
				local zc = floor((idx - 1) / batchCols)
				local xc = (idx - 1) - zc * batchCols
				local sIdx = (zc - batchMinZc) * w + (xc - batchMinXc) + 1
				local pre = batchPre[idx]
				if pre == GetGroundOrigHeight(xc * SQUARE_SIZE, zc * SQUARE_SIZE) then
					mask[sIdx] = 2
				else
					mask[sIdx] = 1
					hgrid[sIdx] = pre
				end
			end
			pushBboxSnapshot({
				format = "bbox",
				minX = batchMinXc * SQUARE_SIZE,
				minZ = batchMinZc * SQUARE_SIZE,
				w = w,
				h = h,
				ss = SQUARE_SIZE,
				mask = mask,
				hgrid = hgrid,
				vertexCount = batchWriteN,
			})
		end
		for i = 1, batchWriteN do
			batchNew[batchWriteList[i]] = nil
		end
	end
	for i = 1, batchReadN do
		batchPre[batchReadList[i]] = nil
	end
	batchWriteN = 0
	batchReadN = 0
end

-- Clay target plane for a dab. Measured on the pre-stroke surface (strokeOrig
-- where this stroke already wrote, the live ground elsewhere) as the mean of
-- the centre and four taps half a radius out, so the dabs of one stroke agree
-- on a plane instead of each re-measuring the disc the previous one left.
-- stack=true is the per-tick build-up option: the plane sits on the live centre
-- height, so a held or slow drag keeps piling layers (and rings).
local function clayPlaneFor(centerX, centerZ, radius, rise, stack)
	if stack then
		return GetGroundHeight(centerX, centerZ) + rise
	end
	local maxXc = floor(Game.mapSizeX / SQUARE_SIZE)
	local maxZc = floor(Game.mapSizeZ / SQUARE_SIZE)
	local cxc = floor(centerX / SQUARE_SIZE + 0.5)
	local czc = floor(centerZ / SQUARE_SIZE + 0.5)
	local r = max(1, floor(radius * 0.5 / SQUARE_SIZE))
	local sum = 0.0
	for t = 1, 5 do
		local xc, zc = cxc, czc
		if t == 2 then
			xc = cxc - r
		elseif t == 3 then
			xc = cxc + r
		elseif t == 4 then
			zc = czc - r
		elseif t == 5 then
			zc = czc + r
		end
		xc = max(0, min(maxXc, xc))
		zc = max(0, min(maxZc, zc))
		local h = strokeOrig[zc * batchCols + xc + 1]
		if h == nil then
			h = GetGroundHeight(xc * SQUARE_SIZE, zc * SQUARE_SIZE)
		end
		sum = sum + h
	end
	return sum / 5 + rise
end

-- clayMode: false/nil off, 1 = clay (one layer per stroke), 2 = clay with
-- per-tick build-up. Dabs inside a STROKE batch get clayPlaneIn from
-- handleStroke; a dab on its own (per-dab BRUSH message, sticky replay) opens
-- and commits a batch of one.
local function applyTerraform(
	centerX,
	centerZ,
	radius,
	direction,
	shape,
	angleDeg,
	curve,
	heightMin,
	heightMax,
	intensity,
	lengthScale,
	clayMode,
	opacity,
	flattenHeight,
	instant,
	localBlur,
	localSmudge,
	smudgeStart,
	clayPlaneIn
)
	local squareSize = SQUARE_SIZE
	local maxXc = floor(Game.mapSizeX / squareSize)
	local maxZc = floor(Game.mapSizeZ / squareSize)
	lengthScale = lengthScale or 1.0

	local standalone = not batchOpen
	if standalone then
		beginBatch()
	end

	-- Clay mode: target plane at the reference height + full brush displacement.
	local clayPlane = clayPlaneIn
	if not clayPlane and clayMode and direction ~= 0 and direction ~= 2 then
		clayPlane = clayPlaneFor(centerX, centerZ, radius, direction * HEIGHT_STEP * intensity, clayMode == 2)
	end

	opacity = opacity or 0.3
	local dirStep = direction * HEIGHT_STEP

	local stamp = getFalloffStamp(radius, shape, angleDeg, curve, lengthScale, ringInnerRatio, squareSize)
	local sw = stamp.w
	local sh = stamp.h
	local sCx = stamp.cx
	local sCz = stamp.cz
	local sdata = stamp.data
	-- Snap the centre to the grid (at most squareSize/2 off) so the cached stamp aligns.
	local centerCellX = floor(centerX / squareSize + 0.5)
	local centerCellZ = floor(centerZ / squareSize + 0.5)
	local cols = batchCols
	local bNew, bPre = batchNew, batchPre

	local levelTarget
	if direction == 0 and not localBlur and not localSmudge then
		-- Heights are only written after the loop, so one centre read serves every cell.
		levelTarget = flattenHeight or batchRead(max(0, min(maxXc, centerCellX)), max(0, min(maxZc, centerCellZ)))
	end

	-- Smooth mode (localBlur): each cell blends toward the mean of its OWN
	-- neighbourhood, so the falloff edge leaves no seam against untouched ground.
	-- The box half-width (blurStep) grows with intensity so strong passes flatten
	-- broad bumps, capped at half the radius. The mean must be dense over the
	-- whole box (sparse taps miss ripples at the tap spacing and leave grid
	-- stripes); a summed-area table gives it in 4 lookups per cell.
	local blurBuf, blurStride, blurStep, blurSAT, satStride, blurInvArea
	if localBlur then
		local intensityT = max(0, min(1, math.log(intensity / 0.1) / math.log(100.0 / 0.1)))
		blurStep = floor(1 + intensityT * (MAX_BLUR_STEP - 1) + 0.5)
		blurStep = max(1, min(blurStep, floor(radius / squareSize / 2)))
		blurStride = sw + 2 * blurStep
		blurBuf = scratchBlurHeights
		local padRows = sh + 2 * blurStep
		for pz = 0, padRows - 1 do
			local zCell = centerCellZ + (pz - blurStep - sCz)
			if zCell < 0 then
				zCell = 0
			elseif zCell > maxZc then
				zCell = maxZc
			end
			local rowBase = pz * blurStride
			for px = 0, blurStride - 1 do
				local xCell = centerCellX + (px - blurStep - sCx)
				if xCell < 0 then
					xCell = 0
				elseif xCell > maxXc then
					xCell = maxXc
				end
				blurBuf[rowBase + px + 1] = batchRead(xCell, zCell)
			end
		end
		-- SAT[r][c] = sum of blurBuf rows < r, cols < c (zero first row/col).
		blurSAT = scratchBlurSAT
		satStride = blurStride + 1
		for c = 1, satStride do
			blurSAT[c] = 0
		end
		for r = 1, padRows do
			local rowBase = r * satStride
			local prevBase = rowBase - satStride
			local bufBase = (r - 1) * blurStride
			blurSAT[rowBase + 1] = 0
			local rowSum = 0
			for c = 1, blurStride do
				rowSum = rowSum + blurBuf[bufBase + c]
				blurSAT[rowBase + c + 1] = blurSAT[prevBase + c + 1] + rowSum
			end
		end
		local boxSide = 2 * blurStep + 1
		blurInvArea = 1 / (boxSide * boxSide)
	end

	-- Smudge mode (localSmudge), like GIMP's smudge: the first dab of a stroke
	-- grabs a brush-space height buffer, every later dab folds the ground under
	-- the moved brush into it and the main loop paints it back, so relief drags
	-- along the stroke and tapers off. Chains are matched by proximity so each
	-- symmetry copy keeps its own buffer; a widget-flagged stroke-start dab
	-- always grabs fresh.
	local smudgeHeights
	if localSmudge then
		smudgeClock = smudgeClock + 1
		local buf
		if not smudgeStart then
			local bestD
			for i = 1, #smudgeBuffers do
				local b = smudgeBuffers[i]
				if b.w == sw and b.h == sh then
					local dx = centerCellX - b.cx
					local dz = centerCellZ - b.cz
					local d = dx * dx + dz * dz
					if bestD == nil or d < bestD then
						bestD, buf = d, b
					end
				end
			end
			-- A chain more than a brush diameter away belongs to another copy (or
			-- is stale): grab fresh rather than teleport terrain across the map.
			local maxCells = 2 * radius / squareSize
			if buf and bestD > maxCells * maxCells then
				buf = nil
			end
		end
		local grab = false
		if not buf then
			-- Retire chains whose stroke ended long ago, and cap the pool.
			for i = #smudgeBuffers, 1, -1 do
				if smudgeClock - smudgeBuffers[i].clock > 512 then
					table.remove(smudgeBuffers, i)
				end
			end
			if #smudgeBuffers >= MAX_SMUDGE_BUFFERS then
				local oldI = 1
				for i = 2, #smudgeBuffers do
					if smudgeBuffers[i].clock < smudgeBuffers[oldI].clock then
						oldI = i
					end
				end
				table.remove(smudgeBuffers, oldI)
			end
			buf = { w = sw, h = sh, heights = {} }
			smudgeBuffers[#smudgeBuffers + 1] = buf
			grab = true
		end
		buf.cx = centerCellX
		buf.cz = centerCellZ
		buf.clock = smudgeClock
		smudgeHeights = buf.heights
		-- Rate: share of the carried relief surviving each dab, from intensity on
		-- the same log scale as smooth's blur width (higher = longer tails).
		local intensityT = max(0, min(1, math.log(intensity / 0.1) / math.log(100.0 / 0.1)))
		local rate = 0.5 + 0.47 * intensityT
		for iz = 0, sh - 1 do
			local rowBase = iz * sw
			local zCell = centerCellZ + (iz - sCz)
			if zCell < 0 then
				zCell = 0
			elseif zCell > maxZc then
				zCell = maxZc
			end
			for ix = 0, sw - 1 do
				local xCell = centerCellX + (ix - sCx)
				if xCell < 0 then
					xCell = 0
				elseif xCell > maxXc then
					xCell = maxXc
				end
				local cur = batchRead(xCell, zCell)
				local idx = rowBase + ix + 1
				if grab then
					smudgeHeights[idx] = cur
				else
					smudgeHeights[idx] = cur + (smudgeHeights[idx] - cur) * rate
				end
			end
		end
		if grab then
			-- the first dab of a stroke only grabs; nothing to paint yet
			if standalone then
				flushBatch()
			end
			return
		end
	end

	for iz = 0, sh - 1 do
		local sBase = iz * sw
		local zCell = centerCellZ + (iz - sCz)
		if zCell >= 0 and zCell <= maxZc then
			local rowIdx = zCell * cols + 1
			for ix = 0, sw - 1 do
				local falloff = sdata[sBase + ix + 1]
				if falloff then
					local xCell = centerCellX + (ix - sCx)
					if xCell >= 0 and xCell <= maxXc then
						local idx = rowIdx + xCell
						local current
						local blurTarget
						if localBlur then
							current = blurBuf[(iz + blurStep) * blurStride + ix + blurStep + 1]
							-- Box mean over padded rows [iz, iz+2*blurStep] and
							-- cols [ix, ix+2*blurStep] from 4 SAT corners.
							local r0Base = iz * satStride
							local r1Base = (iz + 2 * blurStep + 1) * satStride
							local c0 = ix + 1
							local c1 = ix + 2 * blurStep + 2
							blurTarget = (
								blurSAT[r1Base + c1]
								- blurSAT[r0Base + c1]
								- blurSAT[r1Base + c0]
								+ blurSAT[r0Base + c0]
							) * blurInvArea
						else
							-- batchRead inlined: hot path.
							current = bNew[idx]
							if current == nil then
								current = bPre[idx]
								if current == nil then
									current = GetGroundHeight(xCell * squareSize, zCell * squareSize)
									bPre[idx] = current
									batchReadN = batchReadN + 1
									batchReadList[batchReadN] = idx
								end
							end
						end

						local newHeight

						if instant then
							-- Stamp mode: lerp toward the cap height in one step
							if direction > 0 and heightMax then
								newHeight = current + (heightMax - current) * falloff
							elseif direction < 0 and heightMin then
								newHeight = current + (heightMin - current) * falloff
							elseif direction == 0 then
								local target = localBlur and blurTarget
									or (localSmudge and smudgeHeights[sBase + ix + 1])
									or levelTarget
								newHeight = current + (target - current) * falloff
								if heightMin then
									newHeight = max(heightMin, newHeight)
								end
								if heightMax then
									newHeight = min(heightMax, newHeight)
								end
							else
								-- random (direction 2) or no cap set
								local delta = dirStep * falloff * intensity * opacity
								newHeight = current + delta
								if heightMin then
									newHeight = max(heightMin, newHeight)
								end
								if heightMax then
									newHeight = min(heightMax, newHeight)
								end
							end
						elseif direction == 2 then
							local delta = (random() * 2 - 1) * HEIGHT_STEP * falloff * intensity * opacity
							newHeight = current + delta
						elseif direction == 0 then
							local target = localBlur and blurTarget
								or (localSmudge and smudgeHeights[sBase + ix + 1])
								or levelTarget
							local diff = target - current
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
								local delta = dirStep * falloff * intensity * opacity
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

						-- First write of this cell in the tick: list it, grow the
						-- undo bbox, and pin its pre-stroke height for the clay plane.
						if bNew[idx] == nil then
							batchWriteN = batchWriteN + 1
							batchWriteList[batchWriteN] = idx
							if xCell < batchMinXc then
								batchMinXc = xCell
							end
							if xCell > batchMaxXc then
								batchMaxXc = xCell
							end
							if zCell < batchMinZc then
								batchMinZc = zCell
							end
							if zCell > batchMaxZc then
								batchMaxZc = zCell
							end
							-- The blur path reads through blurBuf, so the cell may lack
							-- a pre entry: pin it for the snapshot and the clear loop.
							local pre = bPre[idx] or current
							if bPre[idx] == nil then
								bPre[idx] = current
								batchReadN = batchReadN + 1
								batchReadList[batchReadN] = idx
							end
							if strokeOrig[idx] == nil then
								strokeOrig[idx] = pre
								strokeOrigN = strokeOrigN + 1
								strokeOrigList[strokeOrigN] = idx
							end
						end
						bNew[idx] = newHeight
					end
				end
			end
		end
	end

	if standalone then
		flushBatch()
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
						-- Clay: move toward the target, never past it
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
						if he then
							he[1] = x
							he[2] = z
							he[3] = newHeight
						else
							heightData[hIdx] = { x, z, newHeight }
						end
					end
				end
			end
		end
	end

	for i = hIdx + 1, scratchHeightDataMax do
		heightData[i] = nil
	end
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

	if numPts < 2 then
		return
	end

	local arcLengths = { 0 }
	for i = 2, numPts do
		local dx = waypoints[i][1] - waypoints[i - 1][1]
		local dz = waypoints[i][2] - waypoints[i - 1][2]
		arcLengths[i] = arcLengths[i - 1] + (dx * dx + dz * dz) ^ 0.5
	end
	local totalLength = arcLengths[numPts]
	if totalLength < 1 then
		return
	end

	local startY = Spring.GetGroundHeight(waypoints[1][1], waypoints[1][2])
	local endY = Spring.GetGroundHeight(waypoints[numPts][1], waypoints[numPts][2])

	local bbMinX, bbMaxX = waypoints[1][1], waypoints[1][1]
	local bbMinZ, bbMaxZ = waypoints[1][2], waypoints[1][2]
	for i = 2, numPts do
		if waypoints[i][1] < bbMinX then
			bbMinX = waypoints[i][1]
		end
		if waypoints[i][1] > bbMaxX then
			bbMaxX = waypoints[i][1]
		end
		if waypoints[i][2] < bbMinZ then
			bbMinZ = waypoints[i][2]
		end
		if waypoints[i][2] > bbMaxZ then
			bbMaxZ = waypoints[i][2]
		end
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
					if he then
						he[1] = x
						he[2] = z
						he[3] = newHeight
					else
						heightData[hIdx] = { x, z, newHeight }
					end
				end
			end
		end
	end

	for i = hIdx + 1, scratchHeightDataMax do
		heightData[i] = nil
	end
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
				if he then
					he[1] = x
					he[2] = z
					he[3] = newHeight
				else
					heightData[hIdx] = { x, z, newHeight }
				end
			end
		end
	end

	for i = hIdx + 1, scratchHeightDataMax do
		heightData[i] = nil
	end
	scratchHeightDataMax = hIdx
	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

-- NOISE FUNCTIONS

-- Seeded Perlin permutation table, cached per seed.
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
	-- seeded Fisher-Yates shuffle
	local s = seed % 65536 + 1
	for i = 255, 1, -1 do
		s = (s * 75) % 65537 -- Lehmer LCG, exact in the engine's float32 numbers
		local j = s % (i + 1)
		perm[i], perm[j] = perm[j], perm[i]
	end
	-- duplicated so lookups past 255 need no wrap
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
		val = 1 - abs(val) -- ridge: invert absolute value
		val = val * val -- sharpen ridges
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

local function applyNoise(
	centerX,
	centerZ,
	radius,
	shape,
	angleDeg,
	curve,
	intensity,
	lengthScale,
	noiseType,
	noiseScale,
	octaves,
	persistence,
	lacunarity,
	seed
)
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

				local nx = x / noiseScale
				local nz = z / noiseScale
				local noiseVal = sampleNoise(noiseType, nx, nz, perm, octaves, persistence, lacunarity)

				-- noise is 0..1: centre it on 0
				local offset = (noiseVal - 0.5) * 2 * HEIGHT_STEP * intensity * falloff
				hIdx = hIdx + 1
				local he = heightData[hIdx]
				if he then
					he[1] = x
					he[2] = z
					he[3] = current + offset
				else
					heightData[hIdx] = { x, z, current + offset }
				end
			end
		end
	end

	-- Trim scratch heightData using tracked max (avoids # on reused table)
	for i = hIdx + 1, scratchHeightDataMax do
		heightData[i] = nil
	end
	scratchHeightDataMax = hIdx
	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

-- ERODE BRUSH: thermal (talus) erosion
-- Any cell whose drop to a 4-neighbour exceeds the talus step (one grid step
-- steeper than the repose angle) sheds material downhill:
--   transfer = rate * 0.5 * (dh - talus)   per too-steep neighbour pair
-- Transfers collect in a delta buffer and apply in one batch, so the pass is
-- order-independent, and scale with the brush falloff so edges erode gently.
-- At most ERODE_CELL_BUDGET source cells relax per message: larger footprints
-- take a strided subset, and the widget advances `phase` each tick to cover the rest.
local ERODE_CELL_BUDGET = 8000

local function applyErode(centerX, centerZ, radius, shape, angleDeg, curve, intensity, lengthScale, reposeDeg, phase)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	lengthScale = lengthScale or 1.0

	local talus = math.tan(reposeDeg * pi / 180) * squareSize
	-- A sender sheds to up to 4 neighbours, so a pair's difference drops by
	-- 5*amt per pass. Capping rate at 0.4 (0.5*rate <= 1/5) lands even a pinnacle
	-- exactly on the talus slope instead of inverting it.
	local rate = min(0.4, intensity * 0.125)

	local stamp = getFalloffStamp(radius, shape, angleDeg, curve, lengthScale, ringInnerRatio, squareSize)
	local sw = stamp.w
	local sh = stamp.h
	local sCx = stamp.cx
	local sCz = stamp.cz
	local sdata = stamp.data
	-- Count active stamp cells once, cache on the stamp (stamps are cached/reused)
	local nCells = stamp.cellCount
	if not nCells then
		nCells = 0
		for _ in pairs(sdata) do
			nCells = nCells + 1
		end
		stamp.cellCount = nCells
	end
	local stride = floor((nCells + ERODE_CELL_BUDGET - 1) / ERODE_CELL_BUDGET)
	if stride < 1 then
		stride = 1
	end
	local strideOffset = phase % stride

	-- Snap brush center to nearest grid cell so the cached stamp aligns
	local centerCellX = floor(centerX / squareSize + 0.5)
	local centerCellZ = floor(centerZ / squareSize + 0.5)

	-- Working window = stamp + 1-cell border so footprint-edge cells can shed
	-- material outward (the border only receives, it is never a source).
	local ww = sw + 2
	local originCellX = centerCellX - sCx - 1 -- world cell of window column 0
	local originCellZ = centerCellZ - sCz - 1 -- world cell of window row 0

	local heights = {} -- [windowIdx] = lazily cached GetGroundHeight
	local delta = {} -- [windowIdx] = accumulated height change this pass
	local touched = {} -- windowIdx list in first-touch order (deterministic apply)
	local nTouched = 0

	-- Move material from source cell (cIdx, height h) to neighbor (nIdx at nx,nz)
	local function shed(cIdx, h, cellRate, nIdx, nx, nz)
		if nx < 0 or nx > mapSizeX or nz < 0 or nz > mapSizeZ then
			return
		end
		local hn = heights[nIdx]
		if not hn then
			hn = GetGroundHeight(nx, nz)
			heights[nIdx] = hn
		end
		local dh = h - hn
		if dh > talus then
			local amt = (dh - talus) * 0.5 * cellRate
			local dc = delta[cIdx]
			if dc == nil then
				nTouched = nTouched + 1
				touched[nTouched] = cIdx
				dc = 0
			end
			delta[cIdx] = dc - amt
			local dn = delta[nIdx]
			if dn == nil then
				nTouched = nTouched + 1
				touched[nTouched] = nIdx
				dn = 0
			end
			delta[nIdx] = dn + amt
		end
	end

	local seq = 0 -- running index over active stamp cells (drives the stride subset)
	for iz = 0, sh - 1 do
		local sBase = iz * sw
		local wz = iz + 1 -- window row of this stamp row
		local z = (originCellZ + wz) * squareSize
		for ix = 0, sw - 1 do
			local falloff = sdata[sBase + ix + 1]
			if falloff then
				seq = seq + 1
				if (seq % stride) == strideOffset then
					local wx = ix + 1
					local x = (originCellX + wx) * squareSize
					if x >= 0 and x <= mapSizeX and z >= 0 and z <= mapSizeZ then
						local cIdx = wz * ww + wx + 1
						local h = heights[cIdx]
						if not h then
							h = GetGroundHeight(x, z)
							heights[cIdx] = h
						end
						local cellRate = rate * falloff
						shed(cIdx, h, cellRate, cIdx - 1, x - squareSize, z)
						shed(cIdx, h, cellRate, cIdx + 1, x + squareSize, z)
						shed(cIdx, h, cellRate, cIdx - ww, x, z - squareSize)
						shed(cIdx, h, cellRate, cIdx + ww, x, z + squareSize)
					end
				end
			end
		end
	end

	-- Apply all accumulated deltas in one batch (order-independent pass)
	local heightData = scratchHeightData
	local snapFlat = scratchSnapFlat
	local hIdx = 0
	local sCount = 0
	for i = 1, nTouched do
		local idx = touched[i]
		local d = delta[idx]
		if d > 0.001 or d < -0.001 then
			local wi = idx - 1
			local wzc = floor(wi / ww)
			local wxc = wi - wzc * ww
			local x = (originCellX + wxc) * squareSize
			local z = (originCellZ + wzc) * squareSize
			local h = heights[idx]
			local base = sCount * 3
			snapFlat[base + 1] = x
			snapFlat[base + 2] = z
			snapFlat[base + 3] = h
			sCount = sCount + 1
			hIdx = hIdx + 1
			local he = heightData[hIdx]
			if he then
				he[1] = x
				he[2] = z
				he[3] = h + d
			else
				heightData[hIdx] = { x, z, h + d }
			end
		end
	end

	-- Trim scratch heightData using tracked max (avoids # on reused table)
	for i = hIdx + 1, scratchHeightDataMax do
		heightData[i] = nil
	end
	scratchHeightDataMax = hIdx
	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

-- AUTORAMP: one-click cliff restyler
-- The terrain math lives in common/autoramp_profile.lua, shared with the
-- widget's hover preview so the preview matches this apply exactly (pure seeded
-- math). This side feeds it the real heightmap and pushes the usual undo entry.
local AutorampProfile = require("common/autoramp_profile")

local function applyAutoramp(
	centerX,
	centerZ,
	radius,
	angleDeg,
	falloffK,
	edgeNoiseK,
	erosionK,
	talusK,
	seed,
	startMode
)
	local res, err = AutorampProfile.compute({
		centerX = centerX,
		centerZ = centerZ,
		radius = radius,
		angleDeg = angleDeg,
		falloffK = falloffK,
		edgeNoiseK = edgeNoiseK,
		erosionK = erosionK,
		talusK = talusK,
		seed = seed,
		startMode = startMode,
		cellSize = Game.squareSize,
		mapSizeX = Game.mapSizeX,
		mapSizeZ = Game.mapSizeZ,
		getHeight = GetGroundHeight,
	})
	if not res then
		if err == "no_cliff" then
			echoGate("[Terraform Brush] Autoramp: no cliff inside the brush circle (all ground is too gentle)")
		elseif err == "no_span" then
			echoGate("[Terraform Brush] Autoramp: no usable cliff height at the click point")
		elseif err == "no_contour" then
			echoGate(
				"[Terraform Brush] Autoramp: cliff mid-line is outside the brush — enlarge the brush or click the face"
			)
		end
		return
	end

	local n = res.n
	local ox = res.ox
	local oz = res.oz
	local cs = res.cellSize
	local orig = res.orig
	local out = res.newH
	local heightData = scratchHeightData
	local snapFlat = scratchSnapFlat
	local hIdx = 0
	local sCount = 0
	for iz = 0, n - 1 do
		local rowBase = iz * n
		local z = (oz + iz) * cs
		for ix = 0, n - 1 do
			local i = rowBase + ix + 1
			local o = orig[i]
			if o then
				local delta = out[i] - o
				if delta > 0.05 or delta < -0.05 then
					local x = (ox + ix) * cs
					local base = sCount * 3
					snapFlat[base + 1] = x
					snapFlat[base + 2] = z
					snapFlat[base + 3] = o
					sCount = sCount + 1
					hIdx = hIdx + 1
					local he = heightData[hIdx]
					if he then
						he[1] = x
						he[2] = z
						he[3] = o + delta
					else
						heightData[hIdx] = { x, z, o + delta }
					end
				end
			end
		end
	end

	-- Trim scratch heightData using tracked max (avoids # on reused table)
	for i = hIdx + 1, scratchHeightDataMax do
		heightData[i] = nil
	end
	scratchHeightDataMax = hIdx
	if hIdx > 0 then
		applyHeightChanges(heightData, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
	end
end

-- One message carries a whole tick of brush dabs (built by the widget's
-- extraState.sendStrokeDabs). Clay planes for every dab come from the pre-tick
-- heightmap before the first dab lands, so a stroke deposits per distance
-- travelled and cannot rise more than HEIGHT_STEP * intensity in one tick.
local strokeDabX, strokeDabZ, strokeDabA, strokeClayPlane = {}, {}, {}, {}
local function handleStroke(payload)
	local parts = parseParts(payload)
	local direction = tonumber(parts[1])
	local radius = tonumber(parts[2])
	local shape = parts[3] or "circle"
	local curve = tonumber(parts[4]) or 1.0
	local heightMin = tonumber(parts[5])
	local heightMax = tonumber(parts[6])
	local intensity = tonumber(parts[7]) or 1.0
	local lengthScale = tonumber(parts[8]) or 1.0
	-- Clay flag: "1" = clay (one layer per stroke), "2" = clay with per-tick
	-- build-up (Settings > Stroke > Clay build-up), anything else = off.
	local clayMode = (parts[9] == "1" and 1) or (parts[9] == "2" and 2) or false
	local dustMode = parts[10] == "1"
	local opacity = tonumber(parts[11]) or 0.3
	local instant = parts[12] == "1"
	-- Same sentinels as the per-dab message: "smooth" and "smudge<startDigit>"
	-- ride the flatten slot as non-numeric values.
	local localBlur = parts[13] == "smooth"
	local localSmudge = parts[13] ~= nil and parts[13]:sub(1, 6) == "smudge"
	local smudgeStart = localSmudge and parts[13]:sub(7, 7) == "1"
	local flattenHeight = tonumber(parts[13])
	if parts[14] then
		ringInnerRatio = max(0.05, min(0.95, tonumber(parts[14]) or 0.6))
	end
	local nDabs = tonumber(parts[15]) or 0
	if not direction or not radius or nDabs < 1 then
		return
	end

	radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
	curve = max(0.1, min(5.0, curve))
	intensity = max(0.1, min(100.0, intensity))
	lengthScale = max(0.2, min(5.0, lengthScale))
	opacity = max(0.01, min(1.0, opacity))

	-- Copy the dabs out of the shared parse scratch before applying any of them.
	local count = 0
	for i = 1, nDabs do
		local b = 15 + (i - 1) * 3
		local x = tonumber(parts[b + 1])
		local z = tonumber(parts[b + 2])
		if not x or not z then
			break
		end
		count = count + 1
		strokeDabX[count] = x
		strokeDabZ[count] = z
		strokeDabA[count] = tonumber(parts[b + 3]) or 0
	end
	if count < 1 then
		return
	end

	-- Derive every plane before any dab lands so dabs cannot compound (see clayPlaneFor).
	local doClay = clayMode and direction ~= 0 and direction ~= 2
	if doClay then
		local rise = direction * HEIGHT_STEP * intensity
		local stack = clayMode == 2
		for i = 1, count do
			strokeClayPlane[i] = clayPlaneFor(strokeDabX[i], strokeDabZ[i], radius, rise, stack)
		end
	end
	-- One batch for the tick: a single heightmap commit and a single undo entry
	-- however many dabs the message carries.
	beginBatch()
	for i = 1, count do
		applyTerraform(
			strokeDabX[i],
			strokeDabZ[i],
			radius,
			direction,
			shape,
			strokeDabA[i],
			curve,
			heightMin,
			heightMax,
			intensity,
			lengthScale,
			clayMode,
			opacity,
			flattenHeight,
			instant,
			localBlur,
			localSmudge,
			smudgeStart,
			doClay and strokeClayPlane[i] or nil
		)
	end
	flushBatch()
	-- One dust burst per tick, not per dab: 48 CEG bursts cost frames for no visible gain.
	if dustMode then
		spawnDust(strokeDabX[count], strokeDabZ[count], radius, intensity)
	end
end

-- Hoisted handler: the RecvLuaMsg dispatcher sits near the 60-upvalue cap, so
-- the parse/clamp body lives here and the dispatcher only gains two upvalues.
local function handleAutoramp(payload)
	local parts = parseParts(payload)
	local centerX = tonumber(parts[1])
	local centerZ = tonumber(parts[2])
	local radius = tonumber(parts[3])
	local angleDeg = tonumber(parts[4]) or 60
	local falloffK = tonumber(parts[5]) or 0.5
	local edgeNoiseK = tonumber(parts[6]) or 0.35
	local erosionK = tonumber(parts[7]) or 0.35
	local talusK = tonumber(parts[8]) or 0.4
	local seed = tonumber(parts[9]) or 0
	local startMode = parts[10]
	if not centerX or not centerZ or not radius then
		return
	end
	radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
	angleDeg = max(10, min(85, angleDeg))
	falloffK = max(0, min(1, falloffK))
	edgeNoiseK = max(0, min(1, edgeNoiseK))
	erosionK = max(0, min(1, erosionK))
	talusK = max(0, min(1, talusK))
	seed = floor(max(0, min(9999, seed)))
	if startMode ~= "extend" and startMode ~= "subtract" then
		startMode = "average"
	end
	applyAutoramp(centerX, centerZ, radius, angleDeg, falloffK, edgeNoiseK, erosionK, talusK, seed, startMode)
end

-- FILL BRUSH: radial-ray rim detection, polar basin, IDW curved fill
-- Phase 1: cast FILL_NUM_RAYS rays from the click. A ray finds the rim when it
--    has climbed WALL_MIN_RISE above the click and dropped back down past it;
--    rays that never do are open, and too many open rays abort the fill.
-- Phase 2: the basin is every cell closer to the click than the rim distance
--    at its angle (median-filtered across rays so one leak cannot spread).
-- Phase 3: each basin cell's target is an IDW blend of the rim peak heights,
--    so even rims fill flat and uneven ones fill as a smooth curve.
-- Phase 4: raise (never lower) each basin cell to its target.
local FILL_HEADER = "$terraform_fill$"

local FILL_NUM_RAYS = 128 -- radial rays for rim detection
-- Ray walk length and basin cell cap are derived per-call from map size so
-- the fill can span almost the entire map (slow but correct on huge bowls).

local function applyFill(cx, cz)
	local ss = Game.squareSize
	local mapX = Game.mapSizeX
	local mapZ = Game.mapSizeZ
	local sin, cos, pi = math.sin, math.cos, math.pi

	-- Map dimensions in cells; ray walks the full diagonal so it can reach
	-- the opposite map edge when needed.
	local mapXCells = mapX / ss
	local mapZCells = mapZ / ss
	local fillRayMaxSteps = floor(math.sqrt(mapXCells * mapXCells + mapZCells * mapZCells)) + 4
	-- Basin cap is the whole map: fill is meant to be permissive, and the
	-- watchdog risk on enormous bowls is accepted.
	local fillMaxCells = floor(mapXCells * mapZCells) + 1

	cx = max(0, min(mapX, floor(cx / ss + 0.5) * ss))
	cz = max(0, min(mapZ, floor(cz / ss + 0.5) * ss))

	local startH = Spring.GetGroundHeight(cx, cz)

	-- Phase 1: the highest point along each ray is the rim in that direction.
	-- Its distance (in cells) bounds the basin in Phase 2.
	local rimPX, rimPZ, rimPH = {}, {}, {}
	local rimPeakStep = {} -- per-ray peak distance in cells (nil if rejected)
	local rimN = 0
	local WALL_MIN_RISE = 16 -- ray peak must be at least this above startH
	-- after the peak, terrain must drop this far below it (and below
	-- startH + WALL_MIN_RISE / 2) to count as leaving the bowl
	local EXIT_DROP = 12

	local openRays = 0 -- rays that never left the bowl: open directions

	for ri = 0, FILL_NUM_RAYS - 1 do
		local angle = ri * 2 * pi / FILL_NUM_RAYS
		local ddx = cos(angle)
		local ddz = sin(angle)
		local peakX, peakZ, peakH, peakStep = cx, cz, startH, 0
		local exited = false
		local exitCeiling = startH + WALL_MIN_RISE * 0.5

		for step = 1, fillRayMaxSteps do
			local rx = floor(cx / ss + ddx * step + 0.5) * ss
			local rz = floor(cz / ss + ddz * step + 0.5) * ss
			rx = max(0, min(mapX, rx))
			rz = max(0, min(mapZ, rz))
			local h = Spring.GetGroundHeight(rx, rz)

			if h > peakH then
				peakX, peakZ, peakH, peakStep = rx, rz, h, step
			end

			-- Left the bowl: a real rim peak, then back down near the click's
			-- level. Interior bumps that never return to low ground do not count.
			if peakH >= startH + WALL_MIN_RISE and h <= exitCeiling and h < peakH - EXIT_DROP then
				exited = true
				break
			end

			-- map edge before leaving the bowl: open direction
			if rx <= 0 or rx >= mapX or rz <= 0 or rz >= mapZ then
				break
			end
		end

		-- Only rays that left the bowl contribute a rim; the rest are open.
		if exited then
			rimN = rimN + 1
			rimPX[rimN] = peakX
			rimPZ[rimN] = peakZ
			rimPH[rimN] = peakH
			rimPeakStep[ri] = peakStep -- indexed by ray id, not by rimN
		else
			openRays = openRays + 1
		end
	end

	-- Small gaps (a narrow canyon entrance) are fine, an open side is not.
	local OPEN_RAY_MAX = floor(FILL_NUM_RAYS * 0.10) -- at most 10% of rays may be open
	if openRays > OPEN_RAY_MAX then
		Spring.Echo(
			string.format(
				"[Terraform Fill] Area is not enclosed (%d/%d rays open, max %d) — aborting",
				openRays,
				FILL_NUM_RAYS,
				OPEN_RAY_MAX
			)
		)
		return
	end

	if rimN < 3 then
		Spring.Echo("[Terraform Fill] Could not detect enclosing rim (found " .. rimN .. " peaks)")
		return
	end

	-- Phase 2: a cell is in the basin when its distance from the click is less
	-- than the rim distance at its angle. Rejected rays borrow the nearest
	-- accepted neighbour's distance, and each ray is capped against the median of
	-- its window so one ray that saw a far rim through a gap cannot leak.
	local basinX, basinZ = {}, {}
	local bN = 0

	-- Gap-fill rimPeakStep across rejected rays (nearest accepted neighbour)
	local rimStepRaw = {}
	do
		local last = nil
		for ri = 0, FILL_NUM_RAYS * 2 - 1 do
			local r = ri % FILL_NUM_RAYS
			if rimPeakStep[r] then
				last = rimPeakStep[r]
			end
			if ri >= FILL_NUM_RAYS and rimStepRaw[r] == nil and last then
				rimStepRaw[r] = last
			end
			if rimPeakStep[r] then
				rimStepRaw[r] = rimPeakStep[r]
			end
		end
		last = nil
		for ri = FILL_NUM_RAYS * 2 - 1, 0, -1 do
			local r = ri % FILL_NUM_RAYS
			if rimPeakStep[r] then
				last = rimPeakStep[r]
			end
			if rimStepRaw[r] == nil and last then
				rimStepRaw[r] = last
			end
		end
	end

	-- Anti-leak filter: cap each ray at 2x the median of its window, which keeps
	-- the typical rim distance but cuts outliers that shot through a gap.
	local ANTI_LEAK_HALF = 2 -- window = 5 rays
	local rimStep = {}
	local wbuf = {}
	for ri = 0, FILL_NUM_RAYS - 1 do
		if rimStepRaw[ri] then
			local n = 0
			for d = -ANTI_LEAK_HALF, ANTI_LEAK_HALF do
				local r2 = (ri + d + FILL_NUM_RAYS) % FILL_NUM_RAYS
				local v = rimStepRaw[r2]
				if v then
					n = n + 1
					wbuf[n] = v
				end
			end
			table.sort(wbuf, function(a, b)
				return a < b
			end)
			local med = wbuf[floor(n / 2) + 1]
			local own = rimStepRaw[ri]
			local cap = med * 2.0
			rimStep[ri] = own < cap and own or cap
			for i = 1, n do
				wbuf[i] = nil
			end
		end
	end

	local maxStep = 0
	for ri = 0, FILL_NUM_RAYS - 1 do
		if rimStep[ri] and rimStep[ri] > maxStep then
			maxStep = rimStep[ri]
		end
	end

	local atan2 = math.atan2
	local sqrt = math.sqrt
	local twoPi = 2 * pi
	local raysPerRad = FILL_NUM_RAYS / twoPi

	-- Per-cell IDW target from rim peaks (also used in Phase 3).
	local basinT = {}
	local function idwTarget(x, z)
		local sumW, sumWH = 0, 0
		for j = 1, rimN do
			local ddx = rimPX[j] - x
			local ddz = rimPZ[j] - z
			local w = 1 / (ddx * ddx + ddz * ddz + 1)
			sumW = sumW + w
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
						if ang < 0 then
							ang = ang + twoPi
						end
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

	-- Phase 3+4: raise each basin cell to its IDW target
	local snapFlat = scratchSnapFlat
	local sCount = 0
	local hBuf = scratchHeightData
	local hIdx = 0

	for i = 1, bN do
		local x, z = basinX[i], basinZ[i]
		local target = basinT[i]
		local curH = Spring.GetGroundHeight(x, z)
		if curH < target - 0.1 then
			local base = sCount * 3
			snapFlat[base + 1] = x
			snapFlat[base + 2] = z
			snapFlat[base + 3] = curH
			sCount = sCount + 1
			hIdx = hIdx + 1
			local he = hBuf[hIdx]
			if he then
				he[1] = x
				he[2] = z
				he[3] = target
			else
				hBuf[hIdx] = { x, z, target }
			end
		end
	end
	for i = hIdx + 1, scratchHeightDataMax do
		hBuf[i] = nil
	end
	scratchHeightDataMax = hIdx

	if hIdx > 0 then
		applyHeightChanges(hBuf, hIdx)
		pushSnapshotFromFlat(snapFlat, sCount)
		spawnDust(cx, cz, min(400, hIdx * ss * 0.5))
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	-- Lua 5.1 caps a function at 60 upvalues and this dispatcher sits near it, so
	-- header lengths are spelled #X_HEADER rather than cached in locals. New
	-- message branches should hoist their body into a local handler function.
	if type(msg) ~= "string" or #msg == 0 then
		return false
	end
	-- Strip the certification prefix; it only counts inside a map-editor session
	-- (see isTerraformAllowed).
	local certified = msg:sub(1, #CHEAT_SIG) == CHEAT_SIG
	if certified then
		msg = msg:sub(#CHEAT_SIG + 1)
	end
	if msg == UNDO_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end

		if #undoStack == 0 then
			return true
		end

		local snapshot = undoStack[#undoStack]
		undoStack[#undoStack] = nil
		local vertexCount = snapshot.vertexCount or 0
		totalVertexCount = totalVertexCount - vertexCount

		local redoSnapshot = captureCurrentForSnapshot(snapshot)
		redoSnapshot.strokeId = snapshot.strokeId

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
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end
		if #undoStack == 0 then
			return true
		end

		local targetStrokeId = undoStack[#undoStack].strokeId

		local collected = {}
		while #undoStack > 0 do
			local top = undoStack[#undoStack]
			if top.strokeId ~= targetStrokeId then
				break
			end
			undoStack[#undoStack] = nil
			local vertexCount = top.vertexCount or 0
			totalVertexCount = totalVertexCount - vertexCount
			collected[#collected + 1] = top
		end

		-- Apply the whole stroke at once: this gadget has no GameFrame to spread it over.
		for i = 1, #collected do
			local entry = collected[i]
			local vertexCount = entry.vertexCount or 0
			local redoSnapshot = captureCurrentForSnapshot(entry)
			redoSnapshot.strokeId = targetStrokeId
			applySnapshotHeights(entry)
			redoStack[#redoStack + 1] = redoSnapshot
			totalVertexCount = totalVertexCount + vertexCount
		end

		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
		return true
	end

	if msg == REDO_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end

		if #redoStack == 0 then
			return true
		end

		local snapshot = redoStack[#redoStack]
		redoStack[#redoStack] = nil
		local vertexCount = snapshot.vertexCount or 0
		totalVertexCount = totalVertexCount - vertexCount

		local undoSnapshot = captureCurrentForSnapshot(snapshot)
		undoSnapshot.strokeId = snapshot.strokeId

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

	-- MERGE_END is retired (the gadget never merged across ticks), but replays
	-- and older widgets still send it every tick: swallow it quietly.
	if msg == MERGE_END_HEADER then
		return true
	end

	if msg == STROKE_END_HEADER then
		currentStrokeId = currentStrokeId + 1
		clearStrokeOrigin()
		return true
	end

	if msg:sub(1, #WARM_HEADER) == WARM_HEADER then
		-- Warm-up hint on tool or param change: build the falloff stamp before the
		-- stroke's first apply. Touches neither the heightmap nor ringInnerRatio,
		-- and refuses quietly.
		if mapDamageEnabled and isTerraformAllowed(certified, playerID) then
			local parts = parseParts(msg:sub(#WARM_HEADER + 1))
			local radius = tonumber(parts[1])
			if radius then
				local shape = parts[2] or "circle"
				local angleDeg = tonumber(parts[3]) or 0
				local curve = tonumber(parts[4]) or 1.0
				local lengthScale = tonumber(parts[5]) or 1.0
				local ringRatio = tonumber(parts[6]) or ringInnerRatio
				radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
				curve = max(0.1, min(5.0, curve))
				lengthScale = max(0.2, min(5.0, lengthScale))
				ringRatio = max(0.05, min(0.95, ringRatio))
				getFalloffStamp(radius, shape, angleDeg, curve, lengthScale, ringRatio, Game.squareSize)
			end
		end
		return true
	end

	if msg:sub(1, #IMPORT_HEADER) == IMPORT_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end

		local parts = parseParts(msg:sub(#IMPORT_HEADER + 1))
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
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end
		-- Adding 0 everywhere marks every heightmap chunk dirty, so the mesh,
		-- normals, shadows and minimap refresh.
		Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 0)
		importDoneCounter = importDoneCounter + 1
		Spring.SetGameRulesParam("tfb_import_done", importDoneCounter)
		return true
	end

	if msg:sub(1, #RESTORE_HEADER) == RESTORE_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end

		local payload = msg:sub(#RESTORE_HEADER + 1)
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

	if msg:sub(1, REMAP_HEADER_LENGTH) == REMAP_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end
		local parts = parseParts(msg:sub(REMAP_HEADER_LENGTH + 1))
		local newMin = tonumber(parts[1])
		local newMax = tonumber(parts[2])
		if not (newMin and newMax) or newMax - newMin < 1 then
			echoGate("[Terraform Brush] Height range needs a max at least 1 above the min.")
			return true
		end
		remapMapHeights(newMin, newMax, parts[3] == "clamp")
		return true
	end

	if msg == FULL_RESTORE_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end
		local squareSize = Game.squareSize
		local mapSizeX = Game.mapSizeX
		local mapSizeZ = Game.mapSizeZ
		snapshotWholeMap()
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

	if msg:sub(1, #SPLINE_RAMP_HEADER) == SPLINE_RAMP_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end

		local parts = parseParts(msg:sub(#SPLINE_RAMP_HEADER + 1))

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

	if msg:sub(1, #RAMP_HEADER) == RAMP_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end

		local parts = parseParts(msg:sub(#RAMP_HEADER + 1))

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

	if msg:sub(1, #NOISE_HEADER) == NOISE_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end

		local payload = msg:sub(#NOISE_HEADER + 1)
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

		applyNoise(
			centerX,
			centerZ,
			radius,
			shape,
			angleDeg,
			curve,
			intensity,
			lengthScale,
			noiseType,
			nScale,
			octaves,
			persistence,
			lacunarity,
			seed
		)
		if noiseDustMode then
			spawnDust(centerX, centerZ, radius, intensity)
		end
		return true
	end

	if msg:sub(1, #ERODE_HEADER) == ERODE_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end

		local payload = msg:sub(#ERODE_HEADER + 1)
		local parts = parseParts(payload)

		local centerX = tonumber(parts[1])
		local centerZ = tonumber(parts[2])
		local radius = tonumber(parts[3])
		local shape = parts[4] or "circle"
		local angleDeg = tonumber(parts[5]) or 0
		local curve = tonumber(parts[6]) or 1.0
		local intensity = tonumber(parts[7]) or 1.0
		local lengthScale = tonumber(parts[8]) or 1.0
		local reposeDeg = tonumber(parts[9]) or 33
		local phase = tonumber(parts[10]) or 0

		if not centerX or not centerZ or not radius then
			return true
		end

		radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
		curve = max(0.1, min(5.0, curve))
		intensity = max(0.1, min(100.0, intensity))
		lengthScale = max(0.2, min(5.0, lengthScale))
		reposeDeg = max(10, min(60, reposeDeg))
		phase = floor(max(0, phase))

		applyErode(centerX, centerZ, radius, shape, angleDeg, curve, intensity, lengthScale, reposeDeg, phase)
		return true
	end

	if msg:sub(1, #FILL_HEADER) == FILL_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end
		local parts = parseParts(msg:sub(#FILL_HEADER + 1))
		local fillX = tonumber(parts[1])
		local fillZ = tonumber(parts[2])
		if fillX and fillZ then
			applyFill(fillX, fillZ)
		end
		return true
	end

	if msg:sub(1, #AUTORAMP_HEADER) == AUTORAMP_HEADER then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end
		handleAutoramp(msg:sub(#AUTORAMP_HEADER + 1))
		return true
	end

	-- Header spelled inline: this dispatcher is one upvalue under the Lua 5.1
	-- cap of 60, and a string constant costs none.
	if msg:sub(1, 18) == "$terraform_stroke$" then
		if not isTerraformAllowed(certified, playerID) then
			echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
			return true
		end
		handleStroke(msg:sub(19))
		return true
	end

	if msg:sub(1, #PACKET_HEADER) ~= PACKET_HEADER then
		return
	end

	if not isTerraformAllowed(certified, playerID) then
		echoGate("[Terraform Brush] Requires /cheat to be enabled (type /cheat or reactivate the tool)")
		return true
	end

	local payload = msg:sub(#PACKET_HEADER + 1)
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
	local clayMode = (parts[12] == "1" and 1) or (parts[12] == "2" and 2) or false
	local dustMode = parts[13] == "1"
	local opacity = tonumber(parts[14]) or 0.3
	local instant = parts[15] == "1"
	-- The flatten slot also carries sentinels: "smooth" (per-cell target) and
	-- "smudge0"/"smudge1", whose digit marks a stroke-start dab that re-grabs.
	local localBlur = parts[16] == "smooth"
	local localSmudge = parts[16] ~= nil and parts[16]:sub(1, 6) == "smudge"
	local smudgeStart = localSmudge and parts[16]:sub(7, 7) == "1"
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

	applyTerraform(
		centerX,
		centerZ,
		radius,
		direction,
		shape,
		angleDeg,
		curve,
		heightMin,
		heightMax,
		intensity,
		lengthScale,
		clayMode,
		opacity,
		flattenHeight,
		instant,
		localBlur,
		localSmudge,
		smudgeStart
	)
	if dustMode then
		spawnDust(centerX, centerZ, radius, intensity)
	end
	return true
end
