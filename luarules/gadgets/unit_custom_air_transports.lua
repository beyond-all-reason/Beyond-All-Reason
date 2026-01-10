
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Transport Handler",
		desc    = "Underwater gating for all transports; distance gating, slot/seat gating and LUS load/unload dispatch for custom air transports",
		author  = "Doo, GitHub Copilot",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1, -- must be > 0 (unit_script.lua is layer 0) so LUS environments are ready when UnitCreated fires
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- ── Air transport detection ───────────────────────────────────────────────────
-- All flying transports get distance gating. Custom ones (with PerformLoad/Unload
-- in their LUS) additionally get slot/seat gating and script dispatch.

local LOAD_RADIUS = 128 -- elmos XZ; transporter must be within this range
-- in the future we use UnitDefs[unitdefID].loadingRadius or a custom param for this

local isAirTransport = {}
for udefID, def in ipairs(UnitDefs) do
	if def.canFly and def.isTransport then
		isAirTransport[udefID] = true
	end
end

-- ── Script function cache ─────────────────────────────────────────────────────
-- [unitDefID] = function  → custom transport, call to dispatch to LUS
-- [unitDefID] = false     → checked, not a custom transport
-- [unitDefID] = nil       → not yet checked

local customTransportLoad   = {}
local customTransportUnload = {}

local function GetScriptFunc(unitID, functionName) 
	if Spring.GetCOBScriptID(unitID, functionName) then
		return Spring.CallCOBScript
	end
	local env = Spring.UnitScript.GetScriptEnv(unitID)
	if env and env[functionName] then
		return function(uid, fname, a, b, c, d, e, f, g, h, i, j, k, l)
			local scriptEnv = Spring.UnitScript.GetScriptEnv(uid)
			Spring.UnitScript.CallAsUnit(uid, scriptEnv[fname], a, b, c, d, e, f, g, h, i, j, k, l)
		end
	end
	return false
end

local function getTransporteeSize(udefID)
	local def = UnitDefs[udefID]
	if def.customParams and def.customParams.nseats then
		return tonumber(def.customParams.nseats)
	end
	local footprint = math.max(def.xsize, def.zsize) / 2
	if     footprint <= 2  then return 1
	elseif footprint <= 4  then return 4
	elseif footprint <= 8  then return 8
	elseif footprint <= 16 then return 16
	else                        return 1000
	end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local mathSqrt          = math.sqrt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitHeight   = Spring.GetUnitHeight
local spAreTeamsAllied  = Spring.AreTeamsAllied
local spGetUnitTeam     = Spring.GetUnitTeam
local spGetUnitVelocity = Spring.GetUnitVelocity

local function isUnderwater(unitID, y)
	local height = spGetUnitHeight(unitID)
	return not height or y + height < 0
end

local function dist2D(x1, z1, x2, z2)
	local dx, dz = x1 - x2, z1 - z2
	return mathSqrt(dx * dx + dz * dz)
end

local function inRange(transporterID, goalX, goalY, goalZ)
	local tx, ty, tz = spGetUnitPosition(transporterID)
	local dY = ty - goalY
	return dist2D(tx, tz, goalX, goalZ) <= LOAD_RADIUS and dY >= 0 and dY < LOAD_RADIUS -- equivalent to a cylinder of radius load_radius and height load_radius over transporteePosition
end

-- ── Gadget callbacks ──────────────────────────────────────────────────────────

function gadget:Initialize()
	for _, unitID in pairs(Spring.GetAllUnits()) do -- save/load compat
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam) -- cache custom load/unload functions for custom transports
	if customTransportLoad[unitDefID] == nil or customTransportUnload[unitDefID] == nil then
		customTransportLoad[unitDefID]   = GetScriptFunc(unitID, 'PerformLoad')
		customTransportUnload[unitDefID] = GetScriptFunc(unitID, 'PerformUnload')
	end
end

-- Blocks underwater pickups and capacity-exceeded pickups before the transporter even starts moving.
-- WARNING: also called by unsynced engine code (cursor hover / CanTransport check) — keep this purely read-only.
function gadget:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam)
	local _, y, _ = spGetUnitPosition(transporteeID)
	if isUnderwater(transporteeID, y) then return false end
	if customTransportLoad[transporterUnitDefID] then
		local nSeats       = Spring.GetUnitRulesParam(transporterID, "nSeats")    or 0
		local usedSeats    = Spring.GetUnitRulesParam(transporterID, "usedSeats") or 0
		local teeSize      = getTransporteeSize(transporteeUnitDefID)
		if nSeats - usedSeats < teeSize then return false end
		local slotSizesStr = Spring.GetUnitRulesParam(transporterID, "slotSizes") or ""
		for sizeStr in slotSizesStr:gmatch("[^,]+") do
			if tonumber(sizeStr) == teeSize then return true end
		end
		return false
	end
	return true
end

-- Distance gate; for custom transports hand off to LUS (return false = engine skips attach).
function gadget:AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
	if isUnderwater(transporteeID, goalY) then return false end
	if isAirTransport[transporterUnitDefID] then
		if not inRange(transporterID, goalX, goalY, goalZ) then return false end
		if not spAreTeamsAllied(spGetUnitTeam(transporterID), spGetUnitTeam(transporteeID))
		and select(4, spGetUnitVelocity(transporteeID)) >= 0.5 then
			return false
		end
		if customTransportLoad[transporterUnitDefID] then
			if Spring.GetUnitRulesParam(transporterID, "canLoad") == 0 then return false end
			customTransportLoad[transporterUnitDefID](transporterID, 'PerformLoad', transporteeID)
			return false -- LUS handles the attachment
		end
	end
	return true
end

-- Distance gate; for custom transports hand off to LUS (return false = engine skips detach).
function gadget:AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
	if isUnderwater(transporteeID, goalY) then return false end
	if isAirTransport[transporterUnitDefID] then
		if not inRange(transporterID, goalX, goalY, goalZ) then return false end
		if customTransportUnload[transporterUnitDefID] then
			if Spring.GetUnitRulesParam(transporterID, "canUnload") == 0 then return false end
			customTransportUnload[transporterUnitDefID](transporterID, 'PerformUnload', transporteeID, goalX, goalY, goalZ)
			return false -- LUS handles the detachment
		end
	end
	return true
end

-- Transportee died while loaded: clean up its slot without animating.
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local transporterID = Spring.GetUnitTransporter(unitID)
	if not transporterID then return end
	local transporterDefID = Spring.GetUnitDefID(transporterID)
	if customTransportUnload[transporterDefID] then
		local gx, gy, gz = spGetUnitPosition(transporterID)
		customTransportUnload[transporterDefID](transporterID, 'PerformUnload', unitID, gx, gy, gz)
	end
end
