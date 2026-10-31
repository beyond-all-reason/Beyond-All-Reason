local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Metal Brush",
		desc = "Paint and stamp metal deposits on the map. Requires /cheat.",
		author = "PtaQ",
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

-- $c$ exists for map-editor sessions, where other widgets can toggle /cheat off
-- mid-stream. The mapeditor modoption comes from the start script, so a client
-- cannot forge it. (Spring.IsReplay is unsynced and nil here; demos replay the
-- /cheat command anyway.)
local MAP_EDITOR_SESSION = false
do
	local mapEditorOpt = (Spring.GetModOptions() or {}).mapeditor
	MAP_EDITOR_SESSION = mapEditorOpt == true or mapEditorOpt == 1 or mapEditorOpt == "1"
end

local function isAllowed(certified)
	-- $c$ is self-asserted by the sender: trust it only in a map-editor session.
	-- Elsewhere require live cheat, else any modified client could forge the
	-- prefix to place metal in a no-cheat game.
	return Spring.IsCheatingEnabled() or (certified and MAP_EDITOR_SESSION)
end

local METAL_SQ = Game.metalMapSquareSize or 16
local MAP_X = Game.mapSizeX
local MAP_Z = Game.mapSizeZ
local METAL_MAP_X = math.floor(MAP_X / METAL_SQ)
local METAL_MAP_Z = math.floor(MAP_Z / METAL_SQ)

local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs
local cos = math.cos
local sin = math.sin
local pi = math.pi
local sqrt = math.sqrt

-- Same falloff curve as the brush widgets, so the applied metal matches the preview ring.
local BrushShapes = require("common/brush_shapes")
local computeFalloff = BrushShapes.computeFalloff

local spGetMetalAmount = Spring.GetMetalAmount
local spSetMetalAmount = Spring.SetMetalAmount
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitMetalExtraction = Spring.SetUnitMetalExtraction

local EXTRACTOR_RADIUS = Game.extractorRadius

-- unitDefID -> extractsMetal, built on first editor use so normal matches never walk UnitDefs.
local extractorDefs = nil
local function getExtractorDefs()
	if not extractorDefs then
		extractorDefs = {}
		for udid, ud in pairs(UnitDefs) do
			if ud.extractsMetal and ud.extractsMetal > 0 then
				extractorDefs[udid] = ud.extractsMetal
			end
		end
	end
	return extractorDefs
end

-- Metal per byte step of a metal square (maxMetal / 255; Lua cannot read maxMetal).
-- Measured once by overfilling square 0,0, which clamps to 255 steps, then restored.
---@type number?
local metalStepCache = nil
local function metalMapStep()
	if not metalStepCache then
		local old = spGetMetalAmount(0, 0)
		spSetMetalAmount(0, 0, 1e9)
		local top = spGetMetalAmount(0, 0)
		spSetMetalAmount(0, 0, old)
		metalStepCache = (top and top > 0) and (top / 255) or 1
	end
	return metalStepCache
end

local scratchParts = {}

-- ============================================================
-- Undo / Redo stacks
-- ============================================================
local undoStack = {}
local redoStack = {}
local MAX_UNDO = 50

---@type fun(dx: number, dz: number, radius: number, shape: string, angleDeg: number?): boolean, number?
local isInsideShape -- forward declaration

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
	if #snap == 0 then
		return
	end
	undoStack[#undoStack + 1] = snap
	if #undoStack > MAX_UNDO then
		table.remove(undoStack, 1)
	end
	for i = #redoStack, 1, -1 do
		redoStack[i] = nil
	end
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

---@return integer
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

-- Inverse-rotate an offset into the shape's own frame.
local function rotateInv(dx, dz, angleDeg)
	if angleDeg == 0 then
		return dx, dz
	end
	local rad = -angleDeg * pi / 180
	local c, s = cos(rad), sin(rad)
	return dx * c - dz * s, dx * s + dz * c
end

-- Returns (isInside, normalizedDistance) for a world-space offset from the brush centre.
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
	elseif shape == "triangle" then
		return BrushShapes.isInside(dx, dz, radius, shape, angleDeg)
	end
	return false, 1
end

-- ============================================================
-- Paint: raise or lower metal under the brush with falloff
-- ============================================================
local function applyPaint(centerX, centerZ, radius, shape, angleDeg, curve, direction, intensity, metalTarget)
	local halfSq = METAL_SQ * 0.5
	local mxMin = max(0, floor((centerX - radius) / METAL_SQ))
	local mxMax = min(METAL_MAP_X - 1, floor((centerX + radius) / METAL_SQ))
	local mzMin = max(0, floor((centerZ - radius) / METAL_SQ))
	local mzMax = min(METAL_MAP_Z - 1, floor((centerZ + radius) / METAL_SQ))

	local step = intensity * metalTarget * 2.0

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
			end
		end
	end
end

-- ============================================================
-- Stamp: place a complete metal spot with uniform distribution
-- ============================================================
local function applyStamp(centerX, centerZ, radius, metalTarget, shape, angleDeg, direction)
	local halfSq = METAL_SQ * 0.5
	local mxMin = max(0, floor((centerX - radius) / METAL_SQ))
	local mxMax = min(METAL_MAP_X - 1, floor((centerX + radius) / METAL_SQ))
	local mzMin = max(0, floor((centerZ - radius) / METAL_SQ))
	local mzMax = min(METAL_MAP_Z - 1, floor((centerZ + radius) / METAL_SQ))

	-- Erase clears every square in the shape.
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

	-- A stamp is a mex spot: its metal stays within one metal square short of the
	-- extractor radius (room for the build grid snap), or no mex could cover it whole
	-- and the spot finder would offer no build position. The spot readout is the
	-- summed metal / 1000, so the squares share metalTarget * 1000 at any brush size.
	local spotRad = math.max(EXTRACTOR_RADIUS - METAL_SQ, METAL_SQ)
	local spotRadSq = spotRad * spotRad
	local function inSpot(wx, wz)
		local dx, dz = wx - centerX, wz - centerZ
		return dx * dx + dz * dz <= spotRadSq and isInsideShape(dx, dz, radius, shape, angleDeg)
	end
	local squareCount = 0
	for mz = mzMin, mzMax do
		local wz = mz * METAL_SQ + halfSq
		for mx = mxMin, mxMax do
			local wx = mx * METAL_SQ + halfSq
			if inSpot(wx, wz) then
				squareCount = squareCount + 1
			end
		end
	end

	if squareCount == 0 then
		return
	end

	local want = metalTarget * 1000
	local perSquare = want / squareCount

	---@type [integer, integer, number][]
	local written = {}
	---@type number
	local got = 0
	for mz = mzMin, mzMax do
		local wz = mz * METAL_SQ + halfSq
		for mx = mxMin, mxMax do
			local wx = mx * METAL_SQ + halfSq
			if inSpot(wx, wz) then
				spSetMetalAmount(mx, mz, perSquare)
				got = got + spGetMetalAmount(mx, mz)
				written[#written + 1] = { mx, mz, (wx - centerX) ^ 2 + (wz - centerZ) ^ 2 }
			end
		end
	end

	-- Each square is stored in byte steps of maxMetal, so the spot rounds short of the
	-- target. Settle the rest one step at a time on the squares nearest the centre.
	local step = metalMapStep()
	local steps = floor((want - got) / step + 0.5)
	if steps ~= 0 and #written > 0 then
		table.sort(written, function(a, b)
			return a[3] < b[3]
		end)
		local dir = steps > 0 and 1 or -1
		local left, tries = math.abs(steps), #written * 4
		local i = 1
		while left > 0 and tries > 0 do
			local sq = written[i]
			---@cast sq -nil
			local before = spGetMetalAmount(sq[1], sq[2])
			spSetMetalAmount(sq[1], sq[2], before + dir * step)
			if spGetMetalAmount(sq[1], sq[2]) ~= before then
				left = left - 1
			end
			tries = tries - 1
			i = i % #written + 1
		end
	end
end

-- ============================================================
-- Extractor recalculation: update mex income after a metal map edit
-- ============================================================
local function recalcNearbyExtractors(centerX, centerZ, brushRadius)
	local searchRadius = brushRadius + EXTRACTOR_RADIUS + METAL_SQ
	local units = spGetUnitsInRectangle(
		centerX - searchRadius,
		centerZ - searchRadius,
		centerX + searchRadius,
		centerZ + searchRadius
	)
	if not units then
		return
	end

	local exDefs = getExtractorDefs()

	for i = 1, #units do
		local uid = units[i]
		local udid = spGetUnitDefID(uid)
		local mult = exDefs[udid]
		if mult then
			-- SetUnitMetalExtraction takes the extraction DEPTH (the def's extractsMetal), not
			-- a rate; re-setting the def's own depth makes the engine rescan the metal map.
			spSetUnitMetalExtraction(uid, mult)
		end
	end
end

-- ============================================================
-- Resource spots: the mex denier, extractor snapping, area mex and the spot markers
-- read the resource spot finder, which scans the metal map only at game start.
-- Rescan once the metal stops changing and tell LuaUI to do the same.
-- GameFrame is registered only while a rescan is pending.
-- ============================================================
local SPOT_REFRESH_DELAY = 15 -- frames after the last metal write
---@type integer?
local spotRefreshFrame = nil

local function metalChanged()
	Spring.SendLuaUIMsg("mb_metal_updated")
	spotRefreshFrame = Spring.GetGameFrame() + SPOT_REFRESH_DELAY
	gadgetHandler:UpdateCallIn("GameFrame")
end

-- Other synced gadgets that write the metal map (the clone tool's paste) call this so
-- the extractors and the resource spots catch up exactly as after a brush stroke.
GG.MetalBrush = {
	metalWritten = function(centerX, centerZ, radius)
		recalcNearbyExtractors(centerX, centerZ, radius)
		metalChanged()
	end,
}

function gadget:Shutdown()
	GG.MetalBrush = nil
end

function gadget:GameFrame(frame)
	if spotRefreshFrame and frame < spotRefreshFrame then
		return
	end
	gadgetHandler:RemoveCallIn("GameFrame")
	if not spotRefreshFrame then
		return
	end
	spotRefreshFrame = nil
	local finder = GG.resource_spot_finder
	if finder and finder.Refresh then
		finder.Refresh()
		Spring.SendLuaUIMsg("mb_spots_refreshed")
	end
end

-- ============================================================
-- Message Handler
-- ============================================================
function gadget:RecvLuaMsg(msg, playerID)
	-- The header comes before $c$ so cmd_sendcommand (which claims $c$-prefixed
	-- messages) does not intercept: $metal_paint$$c$payload or $metal_paint$payload.

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

		local direction = tonumber(scratchParts[1]) or 0
		local centerX = tonumber(scratchParts[2]) or 0
		local centerZ = tonumber(scratchParts[3]) or 0
		local radius = tonumber(scratchParts[4]) or 32
		local shape = scratchParts[5] or "circle"
		local angleDeg = tonumber(scratchParts[6]) or 0
		local curve = tonumber(scratchParts[7]) or 1.0
		local intensity = tonumber(scratchParts[8]) or 1.0
		local metalTarget = tonumber(scratchParts[9]) or 2.0

		radius = max(8, min(2000, radius))
		intensity = max(0.1, min(100.0, intensity))
		curve = max(0.1, min(5.0, curve))
		metalTarget = max(0.01, min(50.0, metalTarget))

		pushUndo(snapshotShape(centerX, centerZ, radius, shape, angleDeg))
		applyPaint(centerX, centerZ, radius, shape, angleDeg, curve, direction, intensity, metalTarget)
		recalcNearbyExtractors(centerX, centerZ, radius)
		metalChanged()
		return
	end

	-- STAMP: $metal_stamp$[$c$]x z radius metalValue shape angleDeg direction
	if msg:sub(1, STAMP_HEADER_LEN) == STAMP_HEADER then
		local rest = msg:sub(STAMP_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if certified then
			rest = rest:sub(CHEAT_SIG_LEN + 1)
		end
		if not isAllowed(certified) then
			return
		end
		local count = parseParts(rest)
		if count < 4 then
			return
		end

		local centerX = tonumber(scratchParts[1]) or 0
		local centerZ = tonumber(scratchParts[2]) or 0
		local radius = tonumber(scratchParts[3]) or 32
		local metalTarget = tonumber(scratchParts[4]) or 2.0
		local shape = scratchParts[5] or "circle"
		local angleDeg = tonumber(scratchParts[6]) or 0
		local direction = tonumber(scratchParts[7]) or 1

		radius = max(8, min(2000, radius))
		metalTarget = max(0.01, min(255.0, metalTarget))

		pushUndo(snapshotShape(centerX, centerZ, radius, shape, angleDeg))
		applyStamp(centerX, centerZ, radius, metalTarget, shape, angleDeg, direction)
		recalcNearbyExtractors(centerX, centerZ, radius)
		metalChanged()
		return
	end

	-- CLEAR: $metal_clear$[$c$]
	if msg:sub(1, CLEAR_HEADER_LEN) == CLEAR_HEADER then
		local rest = msg:sub(CLEAR_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if certified then
			rest = rest:sub(CHEAT_SIG_LEN + 1)
		end
		if not isAllowed(certified) then
			return
		end

		for mz = 0, METAL_MAP_Z - 1 do
			for mx = 0, METAL_MAP_X - 1 do
				if spGetMetalAmount(mx, mz) > 0 then
					spSetMetalAmount(mx, mz, 0)
				end
			end
		end
		local allUnits = Spring.GetAllUnits()
		if allUnits then
			local exDefs = getExtractorDefs()
			for i = 1, #allUnits do
				local uid = allUnits[i]
				local mult = exDefs[spGetUnitDefID(uid)]
				if mult then
					-- The def's own depth, as everywhere else: with no metal left the mex
					-- extracts nothing, and a depth of 0 would outlive later metal edits.
					spSetUnitMetalExtraction(uid, mult)
				end
			end
		end
		metalChanged()
		return
	end

	-- LOAD: $metal_load$[$c$]mx mz amount mx mz amount ...
	if msg:sub(1, LOAD_HEADER_LEN) == LOAD_HEADER then
		local rest = msg:sub(LOAD_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if certified then
			rest = rest:sub(CHEAT_SIG_LEN + 1)
		end
		if not isAllowed(certified) then
			return
		end
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
			local allUnits = Spring.GetAllUnits()
			if allUnits then
				local exDefs = getExtractorDefs()
				for i = 1, #allUnits do
					local uid = allUnits[i]
					local mult = exDefs[spGetUnitDefID(uid)]
					if mult then
						-- The def's own depth makes the engine rescan (see recalcNearbyExtractors).
						spSetUnitMetalExtraction(uid, mult)
					end
				end
			end
		end
		if loaded > 0 then
			metalChanged()
		end
		return
	end

	-- UNDO: $metal_undo$[$c$]
	if msg:sub(1, UNDO_HEADER_LEN) == UNDO_HEADER then
		local rest = msg:sub(UNDO_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if not isAllowed(certified) then
			return
		end
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
		metalChanged()
		Spring.Echo("[Metal Brush] Undo (" .. (#snap / 3) .. " squares, " .. #undoStack .. " left)")
		return
	end

	-- REDO: $metal_redo$[$c$]
	if msg:sub(1, REDO_HEADER_LEN) == REDO_HEADER then
		local rest = msg:sub(REDO_HEADER_LEN + 1)
		local certified = rest:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
		if not isAllowed(certified) then
			return
		end
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
		metalChanged()
		Spring.Echo("[Metal Brush] Redo (" .. (#snap / 3) .. " squares, " .. #redoStack .. " left)")
		return
	end
end
