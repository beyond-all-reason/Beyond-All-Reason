function gadget:GetInfo()
	return {
		name = "Clone Tool",
		desc = "Handles synced operations for clone tool: terrain height, metal, features",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:RecvFromSynced(name, undoCount, redoCount)
		if name == "CloneToolStacks" then
			if Script.LuaUI("CloneToolStackUpdate") then
				Script.LuaUI.CloneToolStackUpdate(undoCount, redoCount)
			end
		end
	end
	return
end

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local CHEAT_SIG = "$c$"
local CHEAT_SIG_LEN = #CHEAT_SIG
local CLONE_TERRAIN_HEADER = "$clone_terrain$"
local CLONE_TERRAIN_HEADER_LEN = #CLONE_TERRAIN_HEADER
local CLONE_METAL_HEADER = "$clone_metal$"
local CLONE_METAL_HEADER_LEN = #CLONE_METAL_HEADER
local CLONE_FEATURES_HEADER = "$clone_features$"
local CLONE_FEATURES_HEADER_LEN = #CLONE_FEATURES_HEADER
local CLONE_FEATURES_CLEAR_HEADER = "$clone_features_clear$"
local CLONE_FEATURES_CLEAR_HEADER_LEN = #CLONE_FEATURES_CLEAR_HEADER
local CLONE_UNDO_HEADER = "$clone_undo$"
local CLONE_REDO_HEADER = "$clone_redo$"
local CLONE_TBEGIN_HEADER = "$clone_tbegin$"
local CLONE_TBEGIN_HEADER_LEN = #CLONE_TBEGIN_HEADER
local CLONE_TGRID_HEADER = "$clone_tgrid$"
local CLONE_TGRID_HEADER_LEN = #CLONE_TGRID_HEADER
local CLONE_TEND_HEADER = "$clone_tend$"

local HEIGHTMAP_BATCH_SIZE = 999999

local spSetHeightMap = Spring.SetHeightMap
local spGetGroundHeight = Spring.GetGroundHeight
local spSetHeightMapFunc = Spring.SetHeightMapFunc
local spLevelHeightMap = Spring.LevelHeightMap
local spSetMetalAmount = Spring.SetMetalAmount
local spGetMetalAmount = Spring.GetMetalAmount
local spCreateFeature = Spring.CreateFeature
local spDestroyFeature = Spring.DestroyFeature
local spGetFeaturesInRectangle = Spring.GetFeaturesInRectangle
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureHeading = Spring.GetFeatureHeading
local spEcho = Spring.Echo
local SendToUnsynced = SendToUnsynced

local min = math.min
local max = math.max
local floor = math.floor
local tonumber = tonumber

-- ---------------------------------------------------------------------------
-- Undo / Redo
-- ---------------------------------------------------------------------------
local undoStack = {}
local redoStack = {}
local totalVertexCount = 0
local MAX_UNDO = 100
local MAX_SNAPSHOT_VERTICES = 4000000

-- ---------------------------------------------------------------------------
-- Height map application (same pattern as terraform brush)
-- ---------------------------------------------------------------------------
local pendingFlatData
local pendingFlatStart
local pendingFlatEnd

local function heightMapApplyFn()
	local fd = pendingFlatData
	for i = pendingFlatStart, pendingFlatEnd - 1 do
		local base = i * 3
		local h = fd[base + 3]
		if h == h then -- NaN guard
			spSetHeightMap(fd[base + 1], fd[base + 2], h)
		end
	end
end

local function applyHeightChangesFlat(flatData, vertexCount)
	if vertexCount == 0 then return end
	pendingFlatData = flatData
	local offset = 0
	while offset < vertexCount do
		local batchEnd = min(offset + HEIGHTMAP_BATCH_SIZE, vertexCount)
		pendingFlatStart = offset
		pendingFlatEnd = batchEnd
		local ok = spSetHeightMapFunc(heightMapApplyFn)
		if not ok or ok == 0 then
			for i = offset, batchEnd - 1 do
				local base = i * 3
				local x, z, h = flatData[base + 1], flatData[base + 2], flatData[base + 3]
				if h == h then
					spLevelHeightMap(x, z, x, z, h)
				end
			end
		end
		offset = batchEnd
	end
end

-- ---------------------------------------------------------------------------
-- Snapshot for undo
-- ---------------------------------------------------------------------------
local function captureCurrentHeights(flatData, vertexCount)
	local snapshot = {}
	for i = 0, vertexCount - 1 do
		local base = i * 3
		local x, z = flatData[base + 1], flatData[base + 2]
		snapshot[base + 1] = x
		snapshot[base + 2] = z
		snapshot[base + 3] = spGetGroundHeight(x, z)
	end
	snapshot.vertexCount = vertexCount
	return snapshot
end

local function pushUndo(beforeSnapshot)
	for i = 1, #redoStack do
		local rs = redoStack[i]
		totalVertexCount = totalVertexCount - (rs.vertexCount or 0)
	end
	redoStack = {}

	undoStack[#undoStack + 1] = beforeSnapshot
	totalVertexCount = totalVertexCount + (beforeSnapshot.vertexCount or 0)

	if #undoStack > MAX_UNDO then
		local old = undoStack[1]
		totalVertexCount = totalVertexCount - (old.vertexCount or 0)
		table.remove(undoStack, 1)
	end

	SendToUnsynced("CloneToolStacks", #undoStack, #redoStack)
end

-- ---------------------------------------------------------------------------
-- Auth check
-- ---------------------------------------------------------------------------
local function isAllowed(certified)
	return Spring.IsCheatingEnabled() or certified
end

-- ---------------------------------------------------------------------------
-- Parse helpers
-- ---------------------------------------------------------------------------
local scratchParts = {}

local function parseParts(payload)
	local idx = 0
	for word in payload:gmatch("[%-%.%w_]+") do
		idx = idx + 1
		scratchParts[idx] = word
	end
	for i = idx + 1, #scratchParts do scratchParts[i] = nil end
	return scratchParts, idx
end

-- ---------------------------------------------------------------------------
-- Handle terrain clone: "$clone_terrain$count x z h x z h ..."
-- ---------------------------------------------------------------------------
local function handleCloneTerrain(payload)
	local parts, count = parseParts(payload)
	local vertexCount = tonumber(parts[1]) or 0
	if vertexCount == 0 then return end

	-- Build flat buffer
	local flatData = {}
	for i = 1, vertexCount do
		local base = (i - 1) * 3
		local pi = 1 + (i - 1) * 3 + 1 -- skip first element (count)
		flatData[base + 1] = tonumber(parts[pi]) or 0
		flatData[base + 2] = tonumber(parts[pi + 1]) or 0
		flatData[base + 3] = tonumber(parts[pi + 2]) or 0
	end

	-- Capture before for undo
	local beforeSnapshot = captureCurrentHeights(flatData, vertexCount)

	-- Apply
	applyHeightChangesFlat(flatData, vertexCount)

	-- Push undo
	pushUndo(beforeSnapshot)
end

-- ---------------------------------------------------------------------------
-- Handle metal clone: "$clone_metal$count mx mz val mx mz val ..."
-- ---------------------------------------------------------------------------
local function handleCloneMetal(payload)
	local parts, count = parseParts(payload)
	local entryCount = tonumber(parts[1]) or 0
	if entryCount == 0 then return end

	for i = 1, entryCount do
		local pi = 1 + (i - 1) * 3 + 1
		local mx = tonumber(parts[pi]) or 0
		local mz = tonumber(parts[pi + 1]) or 0
		local val = tonumber(parts[pi + 2]) or 0
		spSetMetalAmount(mx, mz, val)
	end
end

-- ---------------------------------------------------------------------------
-- Handle feature clear: "$clone_features_clear$x1 z1 x2 z2"
-- ---------------------------------------------------------------------------
local function handleFeaturesClear(payload)
	local parts = parseParts(payload)
	local x1 = tonumber(parts[1]) or 0
	local z1 = tonumber(parts[2]) or 0
	local x2 = tonumber(parts[3]) or 0
	local z2 = tonumber(parts[4]) or 0

	local feats = spGetFeaturesInRectangle(x1, z1, x2, z2)
	if feats then
		for _, fid in ipairs(feats) do
			spDestroyFeature(fid)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Handle feature clone: "$clone_features$count defName x y z heading ..."
-- ---------------------------------------------------------------------------
local gaiaTeamID = Spring.GetGaiaTeamID()

local function handleCloneFeatures(payload)
	local parts, count = parseParts(payload)
	local entryCount = tonumber(parts[1]) or 0
	spEcho("[Clone Gadget] Features recv: " .. entryCount)
	if entryCount == 0 then return end

	local created = 0
	for i = 1, entryCount do
		local pi = 1 + (i - 1) * 5 + 1
		local defName = parts[pi]
		local x = tonumber(parts[pi + 1]) or 0
		local y = tonumber(parts[pi + 2]) or 0
		local z = tonumber(parts[pi + 3]) or 0
		local heading = tonumber(parts[pi + 4]) or 0
		if defName and FeatureDefNames[defName] then
			spCreateFeature(defName, x, y, z, heading, gaiaTeamID)
			created = created + 1
		else
			spEcho("[Clone Gadget] Feature defName not found: '" .. tostring(defName) .. "'")
		end
	end
	spEcho("[Clone Gadget] Features created: " .. created .. "/" .. entryCount)
end

-- ---------------------------------------------------------------------------
-- Grid-based terrain paste (transaction: begin → grid chunks → end)
-- ---------------------------------------------------------------------------
local pendingPaste = nil -- { gx0, gz0, srcStep, dstStep, srcCols, srcRows, grid, beforeSnapshot }

local function handleTerrainBegin(payload)
	-- Safety: clear any stale pending paste from a previous incomplete transaction
	pendingPaste = nil

	local parts = parseParts(payload)
	local gx0     = tonumber(parts[1]) or 0
	local gz0     = tonumber(parts[2]) or 0
	local srcStep = tonumber(parts[3]) or 8
	local dstStep = tonumber(parts[4]) or 8
	local srcCols = tonumber(parts[5]) or 0
	local srcRows = tonumber(parts[6]) or 0
	if srcCols == 0 or srcRows == 0 then return end

	-- Compute full output area at dstStep resolution
	local ratio = srcStep / dstStep
	local outCols = (srcCols - 1) * ratio + 1
	local outRows = (srcRows - 1) * ratio + 1

	-- Capture before-heights for the entire output area (for undo)
	local snapshot = {}
	local vc = 0
	for r = 0, outRows - 1 do
		for c = 0, outCols - 1 do
			local wx = gx0 + c * dstStep
			local wz = gz0 + r * dstStep
			local base = vc * 3
			snapshot[base + 1] = wx
			snapshot[base + 2] = wz
			snapshot[base + 3] = spGetGroundHeight(wx, wz)
			vc = vc + 1
		end
	end
	snapshot.vertexCount = vc

	pendingPaste = {
		gx0 = gx0, gz0 = gz0,
		srcStep = srcStep, dstStep = dstStep,
		srcCols = srcCols, srcRows = srcRows,
		grid = {},
		beforeSnapshot = snapshot,
	}
end

local function handleTerrainGrid(payload)
	if not pendingPaste then return end
	local parts, cnt = parseParts(payload)
	local rowStart = tonumber(parts[1]) or 0
	local rowCount = tonumber(parts[2]) or 0
	local cols = pendingPaste.srcCols

	-- Parse heights, store in grid, build flat buffer for immediate application
	local flatData = {}
	local vc = 0
	local pi = 3 -- skip rowStart and rowCount
	for r = 0, rowCount - 1 do
		local row = {}
		for c = 0, cols - 1 do
			local h = tonumber(parts[pi]) or 0
			pi = pi + 1
			row[c + 1] = h
			local base = vc * 3
			flatData[base + 1] = pendingPaste.gx0 + c * pendingPaste.srcStep
			flatData[base + 2] = pendingPaste.gz0 + (rowStart + r) * pendingPaste.srcStep
			flatData[base + 3] = h
			vc = vc + 1
		end
		pendingPaste.grid[rowStart + r + 1] = row
	end

	-- Apply source grid points immediately
	applyHeightChangesFlat(flatData, vc)
end

local function handleTerrainEnd()
	if not pendingPaste then return end
	local p = pendingPaste

	-- If srcStep > dstStep, fill intermediate vertices via bilinear interpolation
	if p.srcStep > p.dstStep then
		local ratio = p.srcStep / p.dstStep
		local outCols = (p.srcCols - 1) * ratio + 1
		local outRows = (p.srcRows - 1) * ratio + 1
		local grid = p.grid
		local srcCols = p.srcCols
		local srcRows = p.srcRows

		local fillData = {}
		local fillCount = 0
		for or_ = 0, outRows - 1 do
			for oc = 0, outCols - 1 do
				-- Skip vertices already set (source grid points)
				if or_ % ratio ~= 0 or oc % ratio ~= 0 then
					local sc = oc / ratio
					local sr = or_ / ratio
					local c0 = floor(sc)
					if c0 < 0 then c0 = 0 end
					if c0 > srcCols - 1 then c0 = srcCols - 1 end
					local r0 = floor(sr)
					if r0 < 0 then r0 = 0 end
					if r0 > srcRows - 1 then r0 = srcRows - 1 end
					local c1 = c0 + 1
					if c1 > srcCols - 1 then c1 = srcCols - 1 end
					local r1 = r0 + 1
					if r1 > srcRows - 1 then r1 = srcRows - 1 end
					local fc = sc - c0
					local fr = sr - r0

					local row0 = grid[r0 + 1]
					local row1 = grid[r1 + 1]
					if row0 and row1 then
						local h00 = row0[c0 + 1] or 0
						local h10 = row0[c1 + 1] or 0
						local h01 = row1[c0 + 1] or 0
						local h11 = row1[c1 + 1] or 0
						local h = h00 * (1 - fc) * (1 - fr)
							+ h10 * fc * (1 - fr)
							+ h01 * (1 - fc) * fr
							+ h11 * fc * fr

						local base = fillCount * 3
						fillData[base + 1] = p.gx0 + oc * p.dstStep
						fillData[base + 2] = p.gz0 + or_ * p.dstStep
						fillData[base + 3] = h
						fillCount = fillCount + 1
					end
				end
			end
		end

		if fillCount > 0 then
			applyHeightChangesFlat(fillData, fillCount)
		end
	end

	-- Push single undo for the entire paste
	pushUndo(p.beforeSnapshot)
	pendingPaste = nil
end

-- ---------------------------------------------------------------------------
-- Undo / Redo handlers (height-only for now)
-- ---------------------------------------------------------------------------
local function handleUndo()
	if #undoStack == 0 then return end

	local snapshot = undoStack[#undoStack]
	undoStack[#undoStack] = nil
	local vc = snapshot.vertexCount or 0
	totalVertexCount = totalVertexCount - vc

	-- Capture current for redo
	local redoSnapshot = captureCurrentHeights(snapshot, vc)

	-- Apply old heights
	applyHeightChangesFlat(snapshot, vc)

	redoStack[#redoStack + 1] = redoSnapshot
	totalVertexCount = totalVertexCount + vc
	SendToUnsynced("CloneToolStacks", #undoStack, #redoStack)
end

local function handleRedo()
	if #redoStack == 0 then return end

	local snapshot = redoStack[#redoStack]
	redoStack[#redoStack] = nil
	local vc = snapshot.vertexCount or 0
	totalVertexCount = totalVertexCount - vc

	local undoSnapshot = captureCurrentHeights(snapshot, vc)
	applyHeightChangesFlat(snapshot, vc)

	undoStack[#undoStack + 1] = undoSnapshot
	totalVertexCount = totalVertexCount + vc
	SendToUnsynced("CloneToolStacks", #undoStack, #redoStack)
end

-- ---------------------------------------------------------------------------
-- RecvLuaMsg dispatch
-- ---------------------------------------------------------------------------
function gadget:RecvLuaMsg(msg, playerID)
	local certified = msg:sub(1, CHEAT_SIG_LEN) == CHEAT_SIG
	if certified then
		msg = msg:sub(CHEAT_SIG_LEN + 1)
	end

	-- Terrain
	if msg:sub(1, CLONE_TERRAIN_HEADER_LEN) == CLONE_TERRAIN_HEADER then
		if not isAllowed(certified) then return true end
		handleCloneTerrain(msg:sub(CLONE_TERRAIN_HEADER_LEN + 1))
		return true
	end

	-- Metal
	if msg:sub(1, CLONE_METAL_HEADER_LEN) == CLONE_METAL_HEADER then
		if not isAllowed(certified) then return true end
		handleCloneMetal(msg:sub(CLONE_METAL_HEADER_LEN + 1))
		return true
	end

	-- Features clear
	if msg:sub(1, CLONE_FEATURES_CLEAR_HEADER_LEN) == CLONE_FEATURES_CLEAR_HEADER then
		if not isAllowed(certified) then return true end
		handleFeaturesClear(msg:sub(CLONE_FEATURES_CLEAR_HEADER_LEN + 1))
		return true
	end

	-- Features
	if msg:sub(1, CLONE_FEATURES_HEADER_LEN) == CLONE_FEATURES_HEADER then
		if not isAllowed(certified) then return true end
		handleCloneFeatures(msg:sub(CLONE_FEATURES_HEADER_LEN + 1))
		return true
	end

	-- Undo
	if msg == CLONE_UNDO_HEADER then
		if not isAllowed(certified) then return true end
		handleUndo()
		return true
	end

	-- Redo
	if msg == CLONE_REDO_HEADER then
		if not isAllowed(certified) then return true end
		handleRedo()
		return true
	end

	-- Terrain grid begin
	if msg:sub(1, CLONE_TBEGIN_HEADER_LEN) == CLONE_TBEGIN_HEADER then
		if not isAllowed(certified) then return true end
		handleTerrainBegin(msg:sub(CLONE_TBEGIN_HEADER_LEN + 1))
		return true
	end

	-- Terrain grid chunk
	if msg:sub(1, CLONE_TGRID_HEADER_LEN) == CLONE_TGRID_HEADER then
		if not isAllowed(certified) then return true end
		handleTerrainGrid(msg:sub(CLONE_TGRID_HEADER_LEN + 1))
		return true
	end

	-- Terrain grid end
	if msg == CLONE_TEND_HEADER then
		if not isAllowed(certified) then return true end
		handleTerrainEnd()
		return true
	end
end
