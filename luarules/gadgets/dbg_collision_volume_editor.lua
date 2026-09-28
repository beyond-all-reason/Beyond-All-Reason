local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Collision Volume Editor Backend",
		desc = "Cheat-gated synced backend for the RmlUi collision-volume editor",
		author = "BAR contributors",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local PACKET_PREFIX = "cve|"
local MAX_ABS_VALUE = 65536

-- Snapshots are intentionally kept in synced state. This makes Reset stable if
-- the UI is reloaded or the unit is selected more than once during an edit.
local initialVolumes = {} -- [unitID] = { unit = volume, pieces = { [pieceIndex] = volume } }

local function splitPacket(message)
	local fields = {}
	for field in message:gmatch("([^|]+)") do
		fields[#fields + 1] = field
	end
	return fields
end

local function isFinite(value)
	return value ~= nil and value == value and value > -math.huge and value < math.huge
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function parseNumber(value, low, high)
	value = tonumber(value)
	if not isFinite(value) then
		return nil
	end
	return clamp(value, low, high)
end

local function readUnitVolume(unitID)
	local sx, sy, sz, ox, oy, oz, volumeType, testType, axis, disabled =
		Spring.GetUnitCollisionVolumeData(unitID)
	if not sx then
		return nil
	end
	return {
		sx = sx, sy = sy, sz = sz,
		ox = ox, oy = oy, oz = oz,
		volumeType = volumeType, testType = testType, axis = axis,
		enabled = not disabled,
	}
end

local function readPieceVolume(unitID, pieceIndex)
	local sx, sy, sz, ox, oy, oz, volumeType, testType, axis, disabled =
		Spring.GetUnitPieceCollisionVolumeData(unitID, pieceIndex)
	if not sx then
		return nil
	end
	return {
		sx = sx, sy = sy, sz = sz,
		ox = ox, oy = oy, oz = oz,
		volumeType = volumeType, testType = testType, axis = axis,
		enabled = not disabled,
	}
end

local function validUnit(unitID)
	return unitID and Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function validPiece(unitID, pieceIndex)
	if not pieceIndex or pieceIndex < 1 or pieceIndex % 1 ~= 0 then
		return false
	end
	local pieces = Spring.GetUnitPieceList(unitID)
	return pieces and pieceIndex <= #pieces
end

local function ensureSnapshot(unitID)
	local snapshot = initialVolumes[unitID]
	if snapshot then
		return snapshot
	end

	snapshot = { unit = readUnitVolume(unitID), pieces = {} }
	local pieces = Spring.GetUnitPieceList(unitID) or {}
	for pieceIndex = 1, #pieces do
		snapshot.pieces[pieceIndex] = readPieceVolume(unitID, pieceIndex)
	end
	initialVolumes[unitID] = snapshot
	return snapshot
end

local function applyUnitVolume(unitID, volume)
	Spring.SetUnitCollisionVolumeData(
		unitID,
		volume.sx, volume.sy, volume.sz,
		volume.ox, volume.oy, volume.oz,
		volume.volumeType, volume.testType, volume.axis
	)
	Spring.ForceUnitCollisionUpdate(unitID)
end

local function applyPieceVolume(unitID, pieceIndex, volume)
	Spring.SetUnitPieceCollisionVolumeData(
		unitID, pieceIndex, volume.enabled,
		volume.sx, volume.sy, volume.sz,
		volume.ox, volume.oy, volume.oz,
		volume.volumeType, volume.axis
	)
	Spring.ForceUnitCollisionUpdate(unitID)
end

local function parseVolume(fields)
	local sx = parseNumber(fields[7], 1, MAX_ABS_VALUE)
	local sy = parseNumber(fields[8], 1, MAX_ABS_VALUE)
	local sz = parseNumber(fields[9], 1, MAX_ABS_VALUE)
	local ox = parseNumber(fields[10], -MAX_ABS_VALUE, MAX_ABS_VALUE)
	local oy = parseNumber(fields[11], -MAX_ABS_VALUE, MAX_ABS_VALUE)
	local oz = parseNumber(fields[12], -MAX_ABS_VALUE, MAX_ABS_VALUE)
	local volumeType = parseNumber(fields[13], 0, 3)
	local testType = parseNumber(fields[14], 0, 1)
	local axis = parseNumber(fields[15], 0, 2)

	if not (sx and sy and sz and ox and oy and oz and volumeType and testType and axis) then
		return nil
	end

	return {
		sx = sx, sy = sy, sz = sz,
		ox = ox, oy = oy, oz = oz,
		volumeType = math.floor(volumeType),
		testType = math.floor(testType),
		axis = math.floor(axis),
		enabled = fields[6] == "1",
	}
end

local function handleSet(fields)
	local unitID = tonumber(fields[3])
	if not validUnit(unitID) then
		return
	end

	local scope = fields[4]
	local pieceIndex = tonumber(fields[5])
	local volume = parseVolume(fields)
	if not volume then
		return
	end

	ensureSnapshot(unitID)
	if scope == "unit" then
		applyUnitVolume(unitID, volume)
	elseif scope == "piece" and validPiece(unitID, pieceIndex) then
		applyPieceVolume(unitID, pieceIndex, volume)
	end
end

local function handleReset(fields)
	local unitID = tonumber(fields[3])
	if not validUnit(unitID) then
		return
	end

	local snapshot = ensureSnapshot(unitID)
	if fields[4] == "unit" and snapshot.unit then
		applyUnitVolume(unitID, snapshot.unit)
	elseif fields[4] == "piece" then
		local pieceIndex = tonumber(fields[5])
		local volume = pieceIndex and snapshot.pieces[pieceIndex]
		if volume and validPiece(unitID, pieceIndex) then
			applyPieceVolume(unitID, pieceIndex, volume)
		end
	end
end

function gadget:RecvLuaMsg(message, playerID)
	if message:sub(1, #PACKET_PREFIX) ~= PACKET_PREFIX then
		return
	end

	-- Collision volumes affect synced gameplay. The editor is therefore a
	-- developer tool and never accepts mutation packets unless /cheat is on.
	if not Spring.IsCheatingEnabled() then
		return
	end

	local fields = splitPacket(message)
	local action = fields[2]
	if action == "snapshot" then
		local unitID = tonumber(fields[3])
		if validUnit(unitID) then
			ensureSnapshot(unitID)
		end
	elseif action == "set" then
		handleSet(fields)
	elseif action == "reset" then
		handleReset(fields)
	end
end

function gadget:UnitDestroyed(unitID)
	initialVolumes[unitID] = nil
end
