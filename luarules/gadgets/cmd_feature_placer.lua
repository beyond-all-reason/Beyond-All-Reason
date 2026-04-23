function gadget:GetInfo()
	return {
		name    = "Feature Placer",
		desc    = "Synced gadget for placing, removing, and managing map features via brush tool",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:RecvFromSynced(name, a, b)
		if name == "FeaturePlacerHistory" then
			if Script.LuaUI("feature_placer_history") then
				Script.LuaUI.feature_placer_history(a, b)
			end
		elseif name == "feature_save_begin" then
			if Script.LuaUI("feature_save_begin") then
				Script.LuaUI.feature_save_begin(a)
			end
		elseif name == "feature_save_data" then
			if Script.LuaUI("feature_save_data") then
				Script.LuaUI.feature_save_data(a)
			end
		elseif name == "feature_save_end" then
			if Script.LuaUI("feature_save_end") then
				Script.LuaUI.feature_save_end(a)
			end
		end
	end
	return
end

----------------------------------------------------------------
-- Constants & Headers
----------------------------------------------------------------
local SCATTER_HEADER  = "$feature_scatter$"
local POINT_HEADER    = "$feature_point$"
local REMOVE_HEADER   = "$feature_remove$"
local UNDO_HEADER     = "$feature_undo$"
local REDO_HEADER     = "$feature_redo$"
local SAVE_HEADER     = "$feature_save$"
local LOAD_HEADER     = "$feature_load$"
local CLEARALL_HEADER = "$feature_clearall$"

local MAX_UNDO = 100

----------------------------------------------------------------
-- Localize
----------------------------------------------------------------
local max    = math.max
local min    = math.min
local floor  = math.floor
local ceil   = math.ceil
local sqrt   = math.sqrt
local log    = math.log
local cos    = math.cos
local sin    = math.sin
local abs    = math.abs
local atan2  = math.atan2
local random = math.random
local pi     = math.pi

local SendToUnsynced       = SendToUnsynced
local CreateFeature        = Spring.CreateFeature
local DestroyFeature       = Spring.DestroyFeature
local GetGroundHeight      = Spring.GetGroundHeight
local GetGroundNormal      = Spring.GetGroundNormal
local GetAllFeatures       = Spring.GetAllFeatures
local GetFeaturesInRectangle = Spring.GetFeaturesInRectangle
local GetFeaturePosition   = Spring.GetFeaturePosition
local GetFeatureDefID      = Spring.GetFeatureDefID
local GetFeatureHeading    = Spring.GetFeatureHeading
local ValidFeatureID       = Spring.ValidFeatureID
local GetGaiaTeamID        = Spring.GetGaiaTeamID
local SetFeatureRotation   = Spring.SetFeatureRotation
local GetFeatureRotation   = Spring.GetFeatureRotation
local GetGameFrame         = Spring.GetGameFrame

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local undoStack = {}
local redoStack = {}
local gaiaTeamID

----------------------------------------------------------------
-- Wobble animation
----------------------------------------------------------------
local wobbleQueue = {}
local WOBBLE_DURATION  = 22   -- frames (~0.73s at 30fps)
local WOBBLE_AMPLITUDE = 8    -- degrees peak tilt
local WOBBLE_FREQ      = 0.6  -- radians per frame
local WOBBLE_RAMP      = 3    -- frames to ramp in

local function addWobble(featureID)
	if featureID then
		local _, yaw, _ = GetFeatureRotation(featureID)
		wobbleQueue[featureID] = {
			start = GetGameFrame(),
			axis  = random() * 2 * pi,
			yaw   = yaw or 0,
		}
	end
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function sendHistoryUpdate()
	SendToUnsynced("FeaturePlacerHistory", #undoStack, #redoStack)
end

local function pushUndo(entry)
	redoStack = {}
	undoStack[#undoStack + 1] = entry
	while #undoStack > MAX_UNDO do
		table.remove(undoStack, 1)
	end
	sendHistoryUpdate()
end

----------------------------------------------------------------
-- Shape containment
----------------------------------------------------------------
local function rotatePoint(px, pz, angleDeg)
	local rad = angleDeg * pi / 180
	local ca = cos(rad)
	local sa = sin(rad)
	return px * ca - pz * sa, px * sa + pz * ca
end

local function isInsideShape(dx, dz, radius, shape, angleDeg)
	local lx, lz = rotatePoint(dx, dz, -angleDeg)
	local ax, az = abs(lx), abs(lz)

	if shape == "circle" then
		return lx * lx + lz * lz <= radius * radius
	elseif shape == "square" then
		return ax <= radius and az <= radius
	elseif shape == "hexagon" or shape == "octagon" or shape == "triangle" then
		local numSides = shape == "hexagon" and 6 or (shape == "octagon" and 8 or 3)
		local dist = sqrt(lx * lx + lz * lz)
		if dist < 0.001 then return true end
		local angle = atan2(lz, lx)
		if angle < 0 then angle = angle + 2 * pi end
		local sectorAngle = 2 * pi / numSides
		local angleInSector = (angle % sectorAngle) - sectorAngle / 2
		local apothem = radius * cos(pi / numSides)
		local edgeDist = apothem / cos(angleInSector)
		return dist <= edgeDist
	end
	return false
end

----------------------------------------------------------------
-- Position generation: random within shape
----------------------------------------------------------------
local function generateRandomPositions(centerX, centerZ, radius, shape, angleDeg, count)
	local positions = {}
	local attempts = 0
	local maxAttempts = count * 5
	while #positions < count and attempts < maxAttempts do
		attempts = attempts + 1
		local rx = (random() * 2 - 1) * radius
		local rz = (random() * 2 - 1) * radius
		if isInsideShape(rx, rz, radius, shape, 0) then
			-- Rotate back to world space
			local wx, wz = rotatePoint(rx, rz, angleDeg)
			positions[#positions + 1] = { centerX + wx, centerZ + wz }
		end
	end
	return positions
end

----------------------------------------------------------------
-- Position generation: regular grids
----------------------------------------------------------------
local GOLDEN_ANGLE = pi * (3 - sqrt(5))

local function generateFibonacciPositions(centerX, centerZ, radius, count, angleDeg)
	local positions = {}
	for i = 0, count - 1 do
		local r = radius * sqrt(i / max(1, count - 1))
		local theta = i * GOLDEN_ANGLE
		local lx = r * cos(theta)
		local lz = r * sin(theta)
		local wx, wz = rotatePoint(lx, lz, angleDeg)
		positions[#positions + 1] = { centerX + wx, centerZ + wz }
	end
	return positions
end

local function generateSquareGrid(centerX, centerZ, radius, count, angleDeg)
	local positions = {}
	local area = (2 * radius) * (2 * radius)
	local spacing = sqrt(area / max(1, count))
	local cols = max(1, floor(2 * radius / spacing + 0.5))
	local rows = max(1, floor(2 * radius / spacing + 0.5))
	local sx = 2 * radius / cols
	local sz = 2 * radius / rows
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local lx = -radius + sx * (col + 0.5)
			local lz = -radius + sz * (row + 0.5)
			local wx, wz = rotatePoint(lx, lz, angleDeg)
			positions[#positions + 1] = { centerX + wx, centerZ + wz }
		end
	end
	return positions
end

local function generateHexGrid(centerX, centerZ, radius, count, angleDeg)
	local positions = {}
	-- Hex area of inscribed hexagon ≈ 2.598 * R^2
	local hexArea = 2.598 * radius * radius
	local spacing = sqrt(hexArea / max(1, count) * 2 / sqrt(3))
	local rowSpacing = spacing * sqrt(3) / 2

	local numRows = floor(2 * radius / rowSpacing) + 1
	for row = 0, numRows do
		local lz = -radius + row * rowSpacing
		local offset = (row % 2 == 1) and spacing / 2 or 0
		local numCols = floor(2 * radius / spacing) + 1
		for col = 0, numCols do
			local lx = -radius + col * spacing + offset
			if isInsideShape(lx, lz, radius, "hexagon", 0) then
				local wx, wz = rotatePoint(lx, lz, angleDeg)
				positions[#positions + 1] = { centerX + wx, centerZ + wz }
			end
		end
	end
	return positions
end

local function generateOctGrid(centerX, centerZ, radius, count, angleDeg)
	-- Use square grid clipped to octagon
	local positions = {}
	local area = 2 * (1 + sqrt(2)) * (radius * cos(pi / 8)) ^ 2
	local spacing = sqrt(area / max(1, count))
	local numCols = floor(2 * radius / spacing) + 1
	local numRows = numCols
	for row = 0, numRows do
		for col = 0, numCols do
			local lx = -radius + col * spacing
			local lz = -radius + row * spacing
			if isInsideShape(lx, lz, radius, "octagon", 0) then
				local wx, wz = rotatePoint(lx, lz, angleDeg)
				positions[#positions + 1] = { centerX + wx, centerZ + wz }
			end
		end
	end
	return positions
end

local function generateRegularPositions(centerX, centerZ, radius, shape, angleDeg, count)
	if shape == "circle" then
		return generateFibonacciPositions(centerX, centerZ, radius, count, angleDeg)
	elseif shape == "square" then
		return generateSquareGrid(centerX, centerZ, radius, count, angleDeg)
	elseif shape == "hexagon" then
		return generateHexGrid(centerX, centerZ, radius, count, angleDeg)
	elseif shape == "octagon" then
		return generateOctGrid(centerX, centerZ, radius, count, angleDeg)
	elseif shape == "triangle" then
		return generateRandomPositions(centerX, centerZ, radius, shape, angleDeg, count)
	end
	return generateRandomPositions(centerX, centerZ, radius, shape, angleDeg, count)
end

----------------------------------------------------------------
-- Position generation: clustered (organic)
----------------------------------------------------------------
-- Generates a natural distribution with two tiers:
--   ~75% of features spawn near randomly-chosen cluster nuclei
--       (Gaussian offset from the nucleus)
--   ~25% scatter freely inside the brush shape
-- A per-feature minimum separation derived from the feature's own
-- collision radius prevents exact overlaps.  Larger features (trees)
-- naturally space out; smaller ones (bushes) cluster tightly.
local function generateClusteredPositions(centerX, centerZ, radius, shape, angleDeg, count, defNames)
	-- Derive minimum spacing from the selected feature defs.
	-- Use the largest collision radius so mixed selections stay coherent.
	local minSpacing = 4
	for _, name in ipairs(defNames) do
		local def = FeatureDefNames[name]
		if def and def.radius and def.radius > minSpacing then
			minSpacing = def.radius
		end
	end
	minSpacing = minSpacing * 1.4   -- slightly larger than the model radius

	-- Safety clamp: guarantee Poisson-disk capacity >= count.
	-- Rough capacity estimate: 0.5 * (R/r)^2
	local capacity = 0.5 * (radius / max(1, minSpacing)) ^ 2
	if capacity < count then
		minSpacing = radius / sqrt(count * 2)
	end
	minSpacing = max(4, minSpacing)
	local minSq = minSpacing * minSpacing

	-- Choose cluster nuclei randomly inside the shape.
	local numClusters = max(2, min(6, floor(sqrt(count) * 0.7 + 0.5)))
	local clusterCenters = {}
	local nattempts = 0
	while #clusterCenters < numClusters and nattempts < numClusters * 20 do
		nattempts = nattempts + 1
		local rx = (random() * 2 - 1) * radius
		local rz = (random() * 2 - 1) * radius
		if isInsideShape(rx, rz, radius, shape, 0) then
			local wx, wz = rotatePoint(rx, rz, angleDeg)
			clusterCenters[#clusterCenters + 1] = { centerX + wx, centerZ + wz }
		end
	end
	if #clusterCenters == 0 then
		clusterCenters[1] = { centerX, centerZ }
	end

	-- Gaussian sigma: spread features over roughly 1/numClusters of the brush.
	local sigma = radius / max(1, #clusterCenters) * 1.2
	local RANDOM_FRAC = 0.25   -- fraction placed with pure random scatter

	local positions = {}
	local maxAttempts = count * 15
	local tries = 0

	while #positions < count and tries < maxAttempts do
		tries = tries + 1
		local px, pz
		local valid = false

		if random() < RANDOM_FRAC then
			-- Pure random inside shape
			local rx = (random() * 2 - 1) * radius
			local rz = (random() * 2 - 1) * radius
			if isInsideShape(rx, rz, radius, shape, 0) then
				local wx, wz = rotatePoint(rx, rz, angleDeg)
				px, pz = centerX + wx, centerZ + wz
				valid = true
			end
		else
			-- Gaussian offset around a random cluster nucleus.
			-- Box-Muller transform for normally-distributed offset.
			local cc = clusterCenters[random(1, #clusterCenters)]
			local u1 = max(1e-7, random())
			local mag = sigma * sqrt(-2 * log(u1))
			local ang = random() * 2 * pi
			local ox = mag * cos(ang)
			local oz = mag * sin(ang)
			px, pz = cc[1] + ox, cc[2] + oz
			local dx, dz = px - centerX, pz - centerZ
			if isInsideShape(dx, dz, radius, shape, angleDeg) then
				valid = true
			end
		end

		if valid then
			-- Reject if too close to an already-accepted position.
			local tooClose = false
			for i = 1, #positions do
				local ex, ez = positions[i][1], positions[i][2]
				local ddx, ddz = px - ex, pz - ez
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
-- Smart post-filter: terrain-aware rejection applied to an existing position list.
-- Used when smartEnabled is true regardless of distribution mode.
----------------------------------------------------------------
local function filterSmartPositions(positions, opts)
	local nyCliffMin = opts.avoidCliffs  and cos(opts.slopeMax * pi / 180) or 0
	local nySlopeMax = opts.preferSlopes and cos(opts.slopeMin * pi / 180) or 1

	local filtered = {}
	for _, pos in ipairs(positions) do
		local px, pz = pos[1], pos[2]
		local h = GetGroundHeight(px, pz)
		local _, ny = GetGroundNormal(px, pz)
		ny = ny or 1.0

		local valid = true
		if opts.avoidWater and h < 0 then valid = false end
		if valid and opts.avoidCliffs  and ny < nyCliffMin then valid = false end
		if valid and opts.preferSlopes and ny > nySlopeMax  then valid = false end
		if valid and opts.altMin and h < opts.altMin then valid = false end
		if valid and opts.altMax and h > opts.altMax then valid = false end

		if valid then
			filtered[#filtered + 1] = pos
		end
	end
	return filtered
end

----------------------------------------------------------------
-- Position generation: smart (terrain-aware rejection sampling)
-- Legacy standalone mode kept for backward compatibility.
----------------------------------------------------------------
local function generateSmartPositions(centerX, centerZ, radius, shape, angleDeg, count, opts)
	-- GetGroundNormal returns (nx, ny, nz).
	-- ny = 1.0 for flat ground, ny -> 0 for vertical cliffs.
	-- degrees -> ny threshold: ny = cos(angle_in_radians)
	local nyCliffMin = opts.avoidCliffs  and cos(opts.slopeMax * pi / 180) or 0
	local nySlopeMax = opts.preferSlopes and cos(opts.slopeMin * pi / 180) or 1

	local positions = {}
	local maxAttempts = count * 30  -- extra budget since we're filtering
	local attempts = 0

	while #positions < count and attempts < maxAttempts do
		attempts = attempts + 1
		local rx = (random() * 2 - 1) * radius
		local rz = (random() * 2 - 1) * radius
		if isInsideShape(rx, rz, radius, shape, 0) then
			local wx, wz = rotatePoint(rx, rz, angleDeg)
			local px = max(0, min(Game.mapSizeX, centerX + wx))
			local pz = max(0, min(Game.mapSizeZ, centerZ + wz))

			local h = GetGroundHeight(px, pz)
			local _, ny = GetGroundNormal(px, pz)
			ny = ny or 1.0

			local valid = true

			if opts.avoidWater and h < 0 then
				valid = false
			end

			if valid and opts.avoidCliffs and ny < nyCliffMin then
				valid = false
			end

			if valid and opts.preferSlopes and ny > nySlopeMax then
				valid = false
			end

			if valid and opts.altMin and h < opts.altMin then
				valid = false
			end

			if valid and opts.altMax and h > opts.altMax then
				valid = false
			end

			if valid then
				positions[#positions + 1] = { px, pz }
			end
		end
	end

	return positions
end

----------------------------------------------------------------
-- Feature placement
----------------------------------------------------------------
local function placeFeatures(defNames, positions, baseHeading, rotRandom)
	if #defNames == 0 or #positions == 0 then return end
	local placed = {}
	local numDefs = #defNames
	local spread = floor((rotRandom or 100) / 100 * 32768)
	for i, pos in ipairs(positions) do
		local defName = defNames[random(1, numDefs)]
		local x, z = pos[1], pos[2]
		-- Clamp to map bounds
		x = max(0, min(Game.mapSizeX, x))
		z = max(0, min(Game.mapSizeZ, z))
		local y = GetGroundHeight(x, z)
		local heading = (baseHeading + random(-spread, spread)) % 65536
		local id = CreateFeature(defName, x, y, z, heading, gaiaTeamID)
		if id then
			placed[#placed + 1] = { id = id, defName = defName, x = x, y = y, z = z, heading = heading }
			addWobble(id)
		end
	end
	if #placed > 0 then
		pushUndo({ action = "place", features = placed })
	end
end

local function placeSingleFeature(defNames, x, z, heading)
	if #defNames == 0 then return end
	x = max(0, min(Game.mapSizeX, x))
	z = max(0, min(Game.mapSizeZ, z))
	local defName = defNames[random(1, #defNames)]
	local y = GetGroundHeight(x, z)
	local id = CreateFeature(defName, x, y, z, heading, gaiaTeamID)
	if id then
		addWobble(id)
		pushUndo({ action = "place", features = { { id = id, defName = defName, x = x, y = y, z = z, heading = heading } } })
	end
end

----------------------------------------------------------------
-- Feature removal
----------------------------------------------------------------
local function removeFeatures(centerX, centerZ, radius, shape, angleDeg)
	local extent = radius * 1.42
	local x1 = max(0, centerX - extent)
	local z1 = max(0, centerZ - extent)
	local x2 = min(Game.mapSizeX, centerX + extent)
	local z2 = min(Game.mapSizeZ, centerZ + extent)

	local features = GetFeaturesInRectangle(x1, z1, x2, z2)
	if not features or #features == 0 then return end

	local removed = {}
	for i = 1, #features do
		local fid = features[i]
		local fx, fy, fz = GetFeaturePosition(fid)
		local dx = fx - centerX
		local dz = fz - centerZ
		if isInsideShape(dx, dz, radius, shape, angleDeg) then
			local defID = GetFeatureDefID(fid)
			local def = FeatureDefs[defID]
			if def then
				local heading = GetFeatureHeading(fid) or 0
				removed[#removed + 1] = { defName = def.name, x = fx, y = fy, z = fz, heading = heading }
				DestroyFeature(fid)
			end
		end
	end
	if #removed > 0 then
		pushUndo({ action = "remove", features = removed })
	end
end

----------------------------------------------------------------
-- Undo / Redo
----------------------------------------------------------------
local function featureUndo()
	if #undoStack == 0 then return end
	local entry = undoStack[#undoStack]
	undoStack[#undoStack] = nil

	if entry.action == "place" then
		for _, f in ipairs(entry.features) do
			if ValidFeatureID(f.id) then
				DestroyFeature(f.id)
			end
		end
	elseif entry.action == "remove" then
		for i, f in ipairs(entry.features) do
			local id = CreateFeature(f.defName, f.x, f.y, f.z, f.heading, gaiaTeamID)
			f.id = id
		end
	end

	redoStack[#redoStack + 1] = entry
	sendHistoryUpdate()
end

local function featureRedo()
	if #redoStack == 0 then return end
	local entry = redoStack[#redoStack]
	redoStack[#redoStack] = nil

	if entry.action == "place" then
		for i, f in ipairs(entry.features) do
			local id = CreateFeature(f.defName, f.x, f.y, f.z, f.heading, gaiaTeamID)
			f.id = id
		end
	elseif entry.action == "remove" then
		for _, f in ipairs(entry.features) do
			if ValidFeatureID(f.id) then
				DestroyFeature(f.id)
			end
		end
	end

	undoStack[#undoStack + 1] = entry
	sendHistoryUpdate()
end

----------------------------------------------------------------
-- Save: collect all features and send to unsynced
----------------------------------------------------------------
local function exportAllFeatures()
	local allFeatures = GetAllFeatures()
	local data = {}
	for i = 1, #allFeatures do
		local fid = allFeatures[i]
		local defID = GetFeatureDefID(fid)
		local def = FeatureDefs[defID]
		if def then
			local fx, fy, fz = GetFeaturePosition(fid)
			local heading = GetFeatureHeading(fid) or 0
			data[#data + 1] = def.name .. " " .. floor(fx) .. " " .. floor(fz) .. " " .. heading
		end
	end
	-- Send count first, then batches of features
	local count = #data
	SendToUnsynced("feature_save_begin", count)
	local BATCH = 50
	for i = 1, count, BATCH do
		local batch = {}
		for j = i, min(i + BATCH - 1, count) do
			batch[#batch + 1] = data[j]
		end
		SendToUnsynced("feature_save_data", table.concat(batch, "|"))
	end
	SendToUnsynced("feature_save_end", count)
end

----------------------------------------------------------------
-- Load: create features from batch messages
----------------------------------------------------------------
local function loadFeatureBatch(payload)
	local placed = {}
	for entry in payload:gmatch("[^|]+") do
		local parts = {}
		for word in entry:gmatch("%S+") do
			parts[#parts + 1] = word
		end
		local defName = parts[1]
		local x       = tonumber(parts[2])
		local z       = tonumber(parts[3])
		local heading = tonumber(parts[4]) or 0
		if defName and x and z and FeatureDefNames[defName] then
			x = max(0, min(Game.mapSizeX, x))
			z = max(0, min(Game.mapSizeZ, z))
			local y = GetGroundHeight(x, z)
			local id = CreateFeature(defName, x, y, z, heading, gaiaTeamID)
			if id then
				placed[#placed + 1] = { id = id, defName = defName, x = x, y = y, z = z, heading = heading }
			end
		end
	end
	if #placed > 0 then
		pushUndo({ action = "place", features = placed })
	end
end

----------------------------------------------------------------
-- Clear all: destroy every feature on map
----------------------------------------------------------------
local function clearAllFeatures()
	local allFeatures = GetAllFeatures()
	local removed = {}
	for i = 1, #allFeatures do
		local fid = allFeatures[i]
		local defID = GetFeatureDefID(fid)
		local def = FeatureDefs[defID]
		if def then
			local fx, fy, fz = GetFeaturePosition(fid)
			local heading = GetFeatureHeading(fid) or 0
			removed[#removed + 1] = { defName = def.name, x = fx, y = fy, z = fz, heading = heading }
			DestroyFeature(fid)
		end
	end
	if #removed > 0 then
		pushUndo({ action = "remove", features = removed })
	end
	Spring.Echo("[Feature Placer] Cleared " .. #removed .. " features")
end

----------------------------------------------------------------
-- Message parsing
----------------------------------------------------------------
local function parseDefList(str)
	local defs = {}
	for name in str:gmatch("[^|]+") do
		if FeatureDefNames[name] then
			defs[#defs + 1] = name
		end
	end
	return defs
end

function gadget:RecvLuaMsg(msg, playerID)
	-- Undo
	if msg == UNDO_HEADER then
		if not Spring.IsCheatingEnabled() then return true end
		featureUndo()
		return true
	end

	-- Redo
	if msg == REDO_HEADER then
		if not Spring.IsCheatingEnabled() then return true end
		featureRedo()
		return true
	end

	-- Scatter placement
	if msg:sub(1, #SCATTER_HEADER) == SCATTER_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		local payload = msg:sub(#SCATTER_HEADER + 1)
		local parts = {}
		for word in payload:gmatch("%S+") do
			parts[#parts + 1] = word
		end
		local defNames = parseDefList(parts[1] or "")
		local centerX  = tonumber(parts[2])
		local centerZ  = tonumber(parts[3])
		local radius   = tonumber(parts[4])
		local shape    = parts[5] or "circle"
		local angleDeg = tonumber(parts[6]) or 0
		local count    = tonumber(parts[7]) or 5
		local mode     = parts[8] or "random"
		local rotRandom = tonumber(parts[9]) or 100
		-- Smart filter enabled flag (parts[10]), filter params in parts[11..17]
		local smartEnabled = parts[10] == "1"
		local smartOpts = {
			avoidWater   = parts[11] == "1",
			avoidCliffs  = parts[12] == "1",
			slopeMax     = tonumber(parts[13]) or 45,
			preferSlopes = parts[14] == "1",
			slopeMin     = tonumber(parts[15]) or 10,
			altMin       = (parts[16] and parts[16] ~= "_") and tonumber(parts[16]) or nil,
			altMax       = (parts[17] and parts[17] ~= "_") and tonumber(parts[17]) or nil,
		}

		if #defNames == 0 or not centerX or not centerZ or not radius then
			return true
		end

		radius = max(8, min(2000, radius))
		count = max(1, min(500, count))
		local baseHeading = floor(angleDeg / 360 * 65536) % 65536

		local positions
		if mode == "regular" then
			positions = generateRegularPositions(centerX, centerZ, radius, shape, angleDeg, count)
		elseif mode == "clustered" then
			positions = generateClusteredPositions(centerX, centerZ, radius, shape, angleDeg, count, defNames)
		elseif mode == "smart" then
			-- legacy: standalone smart mode (no smartEnabled flag in old messages)
			positions = generateSmartPositions(centerX, centerZ, radius, shape, angleDeg, count, smartOpts)
		else
			positions = generateRandomPositions(centerX, centerZ, radius, shape, angleDeg, count)
		end

		-- Apply smart filter as a post-pass when smartEnabled is set
		if smartEnabled and mode ~= "smart" then
			positions = filterSmartPositions(positions, smartOpts)
		end

		placeFeatures(defNames, positions, baseHeading, rotRandom)
		return true
	end

	-- Point placement
	if msg:sub(1, #POINT_HEADER) == POINT_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		local payload = msg:sub(#POINT_HEADER + 1)
		local parts = {}
		for word in payload:gmatch("%S+") do
			parts[#parts + 1] = word
		end
		local defNames = parseDefList(parts[1] or "")
		local x       = tonumber(parts[2])
		local z       = tonumber(parts[3])
		local heading = tonumber(parts[4]) or random(0, 65535)

		if #defNames == 0 or not x or not z then
			return true
		end
		placeSingleFeature(defNames, x, z, heading)
		return true
	end

	-- Save
	if msg == SAVE_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Save requires /cheat to be enabled")
			return true
		end
		exportAllFeatures()
		return true
	end

	-- Load batch
	if msg:sub(1, #LOAD_HEADER) == LOAD_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		local payload = msg:sub(#LOAD_HEADER + 1)
		loadFeatureBatch(payload)
		return true
	end

	-- Clear all
	if msg == CLEARALL_HEADER then
		if not Spring.IsCheatingEnabled() then return true end
		clearAllFeatures()
		return true
	end

	-- Remove
	if msg:sub(1, #REMOVE_HEADER) == REMOVE_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		local payload = msg:sub(#REMOVE_HEADER + 1)
		local parts = {}
		for word in payload:gmatch("%S+") do
			parts[#parts + 1] = word
		end
		local centerX  = tonumber(parts[1])
		local centerZ  = tonumber(parts[2])
		local radius   = tonumber(parts[3])
		local shape    = parts[4] or "circle"
		local angleDeg = tonumber(parts[5]) or 0

		if not centerX or not centerZ or not radius then
			return true
		end
		radius = max(8, min(2000, radius))
		removeFeatures(centerX, centerZ, radius, shape, angleDeg)
		return true
	end
end

function gadget:Initialize()
	gaiaTeamID = GetGaiaTeamID()
end

function gadget:GameFrame(frame)
	for fid, info in pairs(wobbleQueue) do
		local elapsed = frame - info.start
		if elapsed > WOBBLE_DURATION or not ValidFeatureID(fid) then
			if ValidFeatureID(fid) then
				SetFeatureRotation(fid, 0, info.yaw, 0)
			end
			wobbleQueue[fid] = nil
		else
			local t = elapsed / WOBBLE_DURATION
			local ramp = min(1, elapsed / WOBBLE_RAMP)
			local decay = (1 - t) * (1 - t)
			local angleDeg = WOBBLE_AMPLITUDE * sin(elapsed * WOBBLE_FREQ) * decay * ramp
			local angle = angleDeg * pi / 180
			local pitch = angle * cos(info.axis)
			local roll  = angle * sin(info.axis)
			SetFeatureRotation(fid, pitch, info.yaw, roll)
		end
	end
end
