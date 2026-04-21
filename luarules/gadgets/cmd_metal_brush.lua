local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Metal Brush",
		desc = "Paint and stamp metal deposits on the map. Requires /cheat.",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local PAINT_HEADER = "$metal_paint$"
local PAINT_HEADER_LEN = #PAINT_HEADER
local STAMP_HEADER = "$metal_stamp$"
local STAMP_HEADER_LEN = #STAMP_HEADER
local CLEAR_HEADER = "$metal_clear$"
local CLEAR_HEADER_LEN = #CLEAR_HEADER
local LOAD_HEADER = "$metal_load$"
local LOAD_HEADER_LEN = #LOAD_HEADER
local UNDO_HEADER = "$metal_undo$"
local UNDO_HEADER_LEN = #UNDO_HEADER
local REDO_HEADER = "$metal_redo$"
local REDO_HEADER_LEN = #REDO_HEADER

local CHEAT_SIG = "$c$"
local CHEAT_SIG_LEN = #CHEAT_SIG

local function isAllowed(certified)
	return Spring.IsCheatingEnabled() or certified
end

local METAL_SQ = Game.metalMapSquareSize or 16
local MAP_X = Game.mapSizeX
local MAP_Z = Game.mapSizeZ
local METAL_MAP_X = math.floor(MAP_X / METAL_SQ)
local METAL_MAP_Z = math.floor(MAP_Z / METAL_SQ)

-- Reference values from map_metal_spot_placer.lua for standard metal spots
local REF_METAL_BUDGET_PER_UNIT = 0.43 * 9 * 255  -- total raw metal budget per 1.0 extraction rate

local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs
local cos = math.cos
local sin = math.sin
local pi = math.pi
local sqrt = math.sqrt

local spGetMetalAmount = Spring.GetMetalAmount
local spSetMetalAmount = Spring.SetMetalAmount
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spSetUnitMetalExtraction = Spring.SetUnitMetalExtraction

local EXTRACTOR_RADIUS = Game.extractorRadius

-- Build lookup: unitDefID -> extractsMetal for all extractor units
local extractorDefs = {}
for udid, ud in pairs(UnitDefs) do
	if ud.extractsMetal and ud.extractsMetal > 0 then
		extractorDefs[udid] = ud.extractsMetal
	end
end

local scratchParts = {}

-- ============================================================
-- Undo / Redo stacks
-- ============================================================
local undoStack = {}
local redoStack = {}
local MAX_UNDO = 50

local isInsideShape  -- forward declaration

local function snapshotShape(centerX, centerZ, radius, shape, angleDeg)
	local halfSq = METAL_SQ * 0.5
	local mxMin = max(0, floor((centerX - radius) / METAL_SQ))
	local mxMax = min(METAL_MAP_X - 1, floor((centerX + radius) / METAL_SQ))
	local mzMin = max(0, floor((centerZ - radius) / METAL_SQ))
	local mzMax = min(METAL_MAP_Z - 1, floor((centerZ + radius) / METAL_SQ))
	local snap = { cx = centerX, cz = centerZ, r = radius }
	for mz = mzMin, mzMax do
		local wz = mz * METAL_SQ + halfSq
		for mx = mxMin, mxMax do
			local wx = mx * METAL_SQ + halfSq
			local inside = isInsideShape(wx - centerX, wz - centerZ, radius, shape, angleDeg)
			if inside then
				snap[#snap + 1] = mx
				snap[#snap + 1] = mz
				snap[#snap + 1] = spGetMetalAmount(mx, mz)
			end
		end
	end
	return snap
end

local function pushUndo(snap)
	if #snap == 0 then return end
	undoStack[#undoStack + 1] = snap
	if #undoStack > MAX_UNDO then
		table.remove(undoStack, 1)
	end
	-- New operation invalidates redo stack
	for i = #redoStack, 1, -1 do redoStack[i] = nil end
end

local function applySnapshot(snap)
	local redo = { cx = snap.cx, cz = snap.cz, r = snap.r }
	for i = 1, #snap, 3 do
		local mx = snap[i]
		local mz = snap[i + 1]
		local oldVal = snap[i + 2]
		redo[#redo + 1] = mx
		redo[#redo + 1] = mz
		redo[#redo + 1] = spGetMetalAmount(mx, mz)
		spSetMetalAmount(mx, mz, oldVal)
	end
	return redo
end

local function parseParts(payload)
	local idx = 0
	for word in payload:gmatch("[%-%.%w]+") do
		idx = idx + 1
		scratchParts[idx] = word
	end
	for i = idx + 1, #scratchParts do
		scratchParts[i] = nil
	end
	return idx
end

-- Rotate a point by -angleDeg (inverse rotation for shape testing)
local function rotateInv(dx, dz, angleDeg)
	if angleDeg == 0 then return dx, dz end
	local rad = -angleDeg * pi / 180
	local c, s = cos(rad), sin(rad)
	return dx * c - dz * s, dx * s + dz * c
end

-- Test if world-space offset (dx, dz) from brush center is inside the shape,
-- returns (isInside, normalizedDistance)
isInsideShape = function(dx, dz, radius, shape, angleDeg)
	local rx, rz = rotateInv(dx, dz, angleDeg)
	if shape == "circle" then
		local d = sqrt(rx * rx + rz * rz)
		return d <= radius, d / radius
	elseif shape == "square" then
		local d = max(abs(rx), abs(rz))
		return d <= radius, d / radius
	elseif shape == "hexagon" then
		local ax, az = abs(rx), abs(rz)
		local d = max(ax * 0.866025 + az * 0.5, az)
		return d <= radius, d / radius
	elseif shape == "octagon" then
		local ax, az = abs(rx), abs(rz)
		local d = max(ax, az, (ax + az) * 0.7071068)
		return d <= radius, d / radius
	end
	return false, 1
end

local function computeFalloff(normDist, curve)
	if normDist >= 1 then return 0 end
	if normDist <= 0 then return 1 end
	local t = 1 - normDist
	if curve == 1.0 then return t end
	return t ^ curve
end

-- ============================================================
-- Paint: Raise/Lower metal under brush with falloff
-- ============================================================
local function applyPaint(centerX, centerZ, radius, shape, angleDeg, curve, direction, intensity, metalTarget)
	local halfSq = METAL_SQ * 0.5
	local mxMin = max(0, floor((centerX - radius) / METAL_SQ))
	local mxMax = min(METAL_MAP_X - 1, floor((centerX + radius) / METAL_SQ))
	local mzMin = max(0, floor((centerZ - radius) / METAL_SQ))
	local mzMax = min(METAL_MAP_Z - 1, floor((centerZ + radius) / METAL_SQ))

	local step = intensity * metalTarget * 2.0
	local modified = 0

	for mz = mzMin, mzMax do
		local wz = mz * METAL_SQ + halfSq
		for mx = mxMin, mxMax do
			local wx = mx * METAL_SQ + halfSq
			local inside, normDist = isInsideShape(wx - centerX, wz - centerZ, radius, shape, angleDeg)
			if inside then
				local falloff = computeFalloff(normDist, curve)
				local current = spGetMetalAmount(mx, mz)
				local delta = direction * step * falloff
				local newVal = max(0, current + delta)
				spSetMetalAmount(mx, mz, newVal)
				modified = modified + 1
			end
		end
	end
	if modified > 0 then
		Spring.Echo("[Metal Brush] applyPaint: modified " .. modified .. " squares, step=" .. step)
	end
end

-- ============================================================
-- Stamp: Place a complete metal spot with uniform distribution
-- ============================================================
local function applyStamp(centerX, centerZ, radius, metalTarget, shape, angleDeg, direction)
	local halfSq = METAL_SQ * 0.5
	local mxMin = max(0, floor((centerX - radius) / METAL_SQ))
	local mxMax = min(METAL_MAP_X - 1, floor((centerX + radius) / METAL_SQ))
	local mzMin = max(0, floor((centerZ - radius) / METAL_SQ))
	local mzMax = min(METAL_MAP_Z - 1, floor((centerZ + radius) / METAL_SQ))

	-- Erase mode: clear all metal in shape
	if direction < 0 then
		for mz = mzMin, mzMax do
			local wz = mz * METAL_SQ + halfSq
			for mx = mxMin, mxMax do
				local wx = mx * METAL_SQ + halfSq
				local inside = isInsideShape(wx - centerX, wz - centerZ, radius, shape, angleDeg)
				if inside then
					spSetMetalAmount(mx, mz, 0)
				end
			end
		end
		return
	end

	-- Count squares inside shape for budget calculation
	local squareCount = 0
	for mz = mzMin, mzMax do
		local wz = mz * METAL_SQ + halfSq
		for mx = mxMin, mxMax do
			local wx = mx * METAL_SQ + halfSq
			local inside = isInsideShape(wx - centerX, wz - centerZ, radius, shape, angleDeg)
			if inside then
				squareCount = squareCount + 1
			end
		end
	end

	if squareCount == 0 then return end

	-- Per-pixel metal amount: spread the total budget evenly across all squares
	-- Reference: standard 5x5 spot (21 squares) at metal=2.0 yields ~94 per square
	local totalBudget = metalTarget * REF_METAL_BUDGET_PER_UNIT
	local perSquare = totalBudget / squareCount

	for mz = mzMin, mzMax do
		local wz = mz * METAL_SQ + halfSq
		for mx = mxMin, mxMax do
			local wx = mx * METAL_SQ + halfSq
			local inside = isInsideShape(wx - centerX, wz - centerZ, radius, shape, angleDeg)
			if inside then
				spSetMetalAmount(mx, mz, perSquare)
			end
		end
	end
end

-- ============================================================
-- Extractor recalculation: update mex income after metal map edit
-- ============================================================
local function recalcNearbyExtractors(centerX, centerZ, brushRadius)
	local searchRadius = brushRadius + EXTRACTOR_RADIUS + METAL_SQ
	local units = spGetUnitsInRectangle(
		centerX - searchRadius, centerZ - searchRadius,
		centerX + searchRadius, centerZ + searchRadius
	)
	if not units then return end

	local halfSq = METAL_SQ * 0.5
	local recalcCount = 0

	for i = 1, #units do
		local uid = units[i]
		local udid = spGetUnitDefID(uid)
		local mult = extractorDefs[udid]
		if mult then
			local ux, _, uz = spGetUnitPosition(uid)
			-- Sample metal map under this extractor's radius
			local mxMin = max(0, floor((ux - EXTRACTOR_RADIUS) / METAL_SQ))
			local mxMax = min(METAL_MAP_X - 1, floor((ux + EXTRACTOR_RADIUS) / METAL_SQ))
			local mzMin = max(0, floor((uz - EXTRACTOR_RADIUS) / METAL_SQ))
			local mzMax = min(METAL_MAP_Z - 1, floor((uz + EXTRACTOR_RADIUS) / METAL_SQ))

			local totalMetal = 0
			for mz = mzMin, mzMax do
				local wz = mz * METAL_SQ + halfSq
				for mx = mxMin, mxMax do
					local wx = mx * METAL_SQ + halfSq
					local dx, dz = wx - ux, wz - uz
					if sqrt(dx * dx + dz * dz) < EXTRACTOR_RADIUS then
						totalMetal = totalMetal + spGetMetalAmount(mx, mz)
					end
				end
			end

			local newRate = totalMetal * mult
			spSetUnitMetalExtraction(uid, newRate)
			recalcCount = recalcCount + 1
		end
	end

	if recalcCount > 0 then
		Spring.Echo("[Metal Brush] Recalculated extraction for " .. recalcCount .. " extractor(s)")
	end
end

-- ============================================================
-- Message Handler
-- ============================================================
function gadget:RecvLuaMsg(msg, playerID)
	-- Check header first (before $c$) so cmd_sendcommand doesn't intercept
	-- Format: $metal_paint$$c$payload  or  $metal_paint$payload

	-- PAINT: $metal_paint$[$c$]direction x z radius shape angleDeg curve intensity metalValue
	if msg:sub(1, PAINT_HEADER_LEN) == PAINT_HEADER then
		local rest = msg:sub(PAINT_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if certified then
			rest = rest:sub(CHEAT_SIG_LEN + 1)
		end
		if not isAllowed(certified) then
			Spring.Echo("[Metal Brush] Paint blocked: cheat not enabled")
			return
		end
		local count = parseParts(rest)
		if count < 9 then
			Spring.Echo("[Metal Brush] Paint parse failed: got " .. count .. " parts from: " .. rest)
			return
		end

		local direction  = tonumber(scratchParts[1]) or 0
		local centerX    = tonumber(scratchParts[2]) or 0
		local centerZ    = tonumber(scratchParts[3]) or 0
		local radius     = tonumber(scratchParts[4]) or 32
		local shape      = scratchParts[5] or "circle"
		local angleDeg   = tonumber(scratchParts[6]) or 0
		local curve      = tonumber(scratchParts[7]) or 1.0
		local intensity  = tonumber(scratchParts[8]) or 1.0
		local metalTarget = tonumber(scratchParts[9]) or 2.0

		radius    = max(8, min(2000, radius))
		intensity = max(0.1, min(100.0, intensity))
		curve     = max(0.1, min(5.0, curve))
		metalTarget = max(0.01, min(50.0, metalTarget))

		pushUndo(snapshotShape(centerX, centerZ, radius, shape, angleDeg))
		applyPaint(centerX, centerZ, radius, shape, angleDeg, curve, direction, intensity, metalTarget)
		recalcNearbyExtractors(centerX, centerZ, radius)
		Spring.Echo("[Metal Brush] Paint applied at " .. centerX .. "," .. centerZ .. " r=" .. radius .. " shape=" .. shape .. " dir=" .. direction .. " int=" .. intensity .. " mv=" .. metalTarget)
		return
	end

	-- STAMP: $metal_stamp$[$c$]x z radius metalValue shape angleDeg direction
	if msg:sub(1, STAMP_HEADER_LEN) == STAMP_HEADER then
		local rest = msg:sub(STAMP_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if certified then
			rest = rest:sub(CHEAT_SIG_LEN + 1)
		end
		if not isAllowed(certified) then return end
		local count = parseParts(rest)
		if count < 4 then return end

		local centerX    = tonumber(scratchParts[1]) or 0
		local centerZ    = tonumber(scratchParts[2]) or 0
		local radius     = tonumber(scratchParts[3]) or 32
		local metalTarget = tonumber(scratchParts[4]) or 2.0
		local shape      = scratchParts[5] or "circle"
		local angleDeg   = tonumber(scratchParts[6]) or 0
		local direction  = tonumber(scratchParts[7]) or 1

		radius = max(8, min(2000, radius))
		metalTarget = max(0.01, min(255.0, metalTarget))

		pushUndo(snapshotShape(centerX, centerZ, radius, shape, angleDeg))
		applyStamp(centerX, centerZ, radius, metalTarget, shape, angleDeg, direction)
		recalcNearbyExtractors(centerX, centerZ, radius)
		Spring.Echo("[Metal Brush] Stamp applied at " .. centerX .. "," .. centerZ .. " r=" .. radius .. " mv=" .. metalTarget .. " dir=" .. direction)
		return
	end

	-- CLEAR: $metal_clear$[$c$]
	if msg:sub(1, CLEAR_HEADER_LEN) == CLEAR_HEADER then
		local rest = msg:sub(CLEAR_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if certified then
			rest = rest:sub(CHEAT_SIG_LEN + 1)
		end
		if not isAllowed(certified) then return end

		local cleared = 0
		for mz = 0, METAL_MAP_Z - 1 do
			for mx = 0, METAL_MAP_X - 1 do
				if spGetMetalAmount(mx, mz) > 0 then
					spSetMetalAmount(mx, mz, 0)
					cleared = cleared + 1
				end
			end
		end
		-- Recalc all extractors on the map
		local allUnits = Spring.GetAllUnits()
		if allUnits then
			for i = 1, #allUnits do
				local uid = allUnits[i]
				local udid = spGetUnitDefID(uid)
				if extractorDefs[udid] then
					spSetUnitMetalExtraction(uid, 0)
				end
			end
		end
		Spring.Echo("[Metal Brush] Cleared all metal (" .. cleared .. " squares)")
		return
	end

	-- LOAD: $metal_load$[$c$]mx mz amount mx mz amount ...
	if msg:sub(1, LOAD_HEADER_LEN) == LOAD_HEADER then
		local rest = msg:sub(LOAD_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if certified then
			rest = rest:sub(CHEAT_SIG_LEN + 1)
		end
		if not isAllowed(certified) then return end
		local count = parseParts(rest)
		local loaded = 0
		for i = 1, count - 2, 3 do
			local mx = tonumber(scratchParts[i]) or 0
			local mz = tonumber(scratchParts[i + 1]) or 0
			local amount = tonumber(scratchParts[i + 2]) or 0
			if mx >= 0 and mx < METAL_MAP_X and mz >= 0 and mz < METAL_MAP_Z then
				spSetMetalAmount(mx, mz, amount)
				loaded = loaded + 1
			end
		end
		if loaded > 0 then
			-- Recalc all extractors
			local allUnits = Spring.GetAllUnits()
			if allUnits then
				local halfSq = METAL_SQ * 0.5
				for i = 1, #allUnits do
					local uid = allUnits[i]
					local udid = spGetUnitDefID(uid)
					local mult = extractorDefs[udid]
					if mult then
						local ux, _, uz = spGetUnitPosition(uid)
						local mxMin = max(0, floor((ux - EXTRACTOR_RADIUS) / METAL_SQ))
						local mxMax = min(METAL_MAP_X - 1, floor((ux + EXTRACTOR_RADIUS) / METAL_SQ))
						local mzMin = max(0, floor((uz - EXTRACTOR_RADIUS) / METAL_SQ))
						local mzMax = min(METAL_MAP_Z - 1, floor((uz + EXTRACTOR_RADIUS) / METAL_SQ))
						local totalMetal = 0
						for mmz = mzMin, mzMax do
							local wz = mmz * METAL_SQ + halfSq
							for mmx = mxMin, mxMax do
								local wx = mmx * METAL_SQ + halfSq
								local dx, dz = wx - ux, wz - uz
								if sqrt(dx * dx + dz * dz) < EXTRACTOR_RADIUS then
									totalMetal = totalMetal + spGetMetalAmount(mmx, mmz)
								end
							end
						end
						spSetUnitMetalExtraction(uid, totalMetal * mult)
					end
				end
			end
		end
		Spring.Echo("[Metal Brush] Loaded " .. loaded .. " metal squares")
		return
	end

	-- UNDO: $metal_undo$[$c$]
	if msg:sub(1, UNDO_HEADER_LEN) == UNDO_HEADER then
		local rest = msg:sub(UNDO_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if not isAllowed(certified) then return end
		local snap = undoStack[#undoStack]
		if not snap then
			Spring.Echo("[Metal Brush] Undo: nothing to undo")
			return
		end
		undoStack[#undoStack] = nil
		local redo = applySnapshot(snap)
		redoStack[#redoStack + 1] = redo
		if snap.cx and snap.r then
			recalcNearbyExtractors(snap.cx, snap.cz, snap.r)
		end
		Spring.Echo("[Metal Brush] Undo (" .. (#snap/3) .. " squares, " .. #undoStack .. " left)")
		return
	end

	-- REDO: $metal_redo$[$c$]
	if msg:sub(1, REDO_HEADER_LEN) == REDO_HEADER then
		local rest = msg:sub(REDO_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if not isAllowed(certified) then return end
		local snap = redoStack[#redoStack]
		if not snap then
			Spring.Echo("[Metal Brush] Redo: nothing to redo")
			return
		end
		redoStack[#redoStack] = nil
		local undo = applySnapshot(snap)
		undoStack[#undoStack + 1] = undo
		if snap.cx and snap.r then
			recalcNearbyExtractors(snap.cx, snap.cz, snap.r)
		end
		Spring.Echo("[Metal Brush] Redo (" .. (#snap/3) .. " squares, " .. #redoStack .. " left)")
		return
	end
end
