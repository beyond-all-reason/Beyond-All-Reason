
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

local LOAD_RADIUS = 64 -- elmos XZ; transporter must be within this range
-- TODO: use UnitDefs[unitDefID].loadingRadius or a custom param instead

local isAirTransport = {}
for udefID, def in ipairs(UnitDefs) do
	if def.canFly and def.isTransport then
		isAirTransport[udefID] = true
	end
end

local TransportAPI = GG.TransportAPI
if not TransportAPI then
	Spring.Echo("TransportAPI must be loaded before this gadget")
	return false
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

-- ── Helpers ───────────────────────────────────────────────────────────────────

local mathSqrt          = math.sqrt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitHeight   = Spring.GetUnitHeight
local spAreTeamsAllied  = Spring.AreTeamsAllied
local spGetUnitTeam     = Spring.GetUnitTeam
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetGroundHeight   = Spring.GetGroundHeight

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
	return dist2D(tx, tz, goalX, goalZ) <= LOAD_RADIUS and dY >= 0 -- cylinder of radius LOAD_RADIUS with open top above the goal position
end

-- ── Pre-queue bookkeeping ─────────────────────────────────────────────────────
-- claimedBy[transporteeID]        = transporterID  (unit is queued for this transporter)
-- queuedSeats[transporterID]      = number of seat-units already claimed but not yet loaded
-- transporterClaims[transporterID] = { transporteeID, ... }  (reverse map for cleanup and processing)

local claimedBy        = {}
local queuedSeats      = {}
local transporterClaims = {}

local function claimTransportee(transporterID, transporteeID, teeSize)

	if claimedBy[transporteeID] then return true end -- already claimed (double-call guard)
	
	queuedSeats[transporterID] = queuedSeats[transporterID] or 0 -- TODO: initialize in UnitCreated instead
	
	-- guard: queuedSeats + teeSize must not exceed total seats (TODO: also account for usedSeats / current cargo)
	if queuedSeats[transporterID] + teeSize > (Spring.GetUnitRulesParam(transporterID, "nSeats") or 0) then
		return false
	end

	-- claim it
	claimedBy[transporteeID] = transporterID
	queuedSeats[transporterID] = (queuedSeats[transporterID] or 0) + teeSize
	local claims = transporterClaims[transporterID]
	if not claims then claims = {} transporterClaims[transporterID] = claims end
	claims[#claims + 1] = transporteeID
	Spring.SetUnitLoadingTransport(transporteeID, transporteeID)
	return true
end

local function releaseTransportee(transporteeID)
	local transporterID = claimedBy[transporteeID]
	if not transporterID then return end
	claimedBy[transporteeID] = nil
	Spring.SetUnitLoadingTransport(transporteeID, nil)
	local teeSize = TransportAPI.GetTransporteeSize(transporteeID)
	queuedSeats[transporterID] = math.max(0, (queuedSeats[transporterID] or 0) - teeSize)
	local claims = transporterClaims[transporterID]
	if claims then
		for i = #claims, 1, -1 do
			if claims[i] == transporteeID then table.remove(claims, i) break end
		end
	end
end

local function releaseAllClaims(transporterID)
	local claims = transporterClaims[transporterID]
	if not claims then return end
	for _, teeID in ipairs(claims) do
		claimedBy[teeID] = nil
		Spring.SetUnitLoadingTransport(teeID, nil)
	end
	transporterClaims[transporterID] = nil
	queuedSeats[transporterID] = nil
end

local function processAllClaims(transporterID)
	local claims = transporterClaims[transporterID]
	if not claims then return end
	for _, teeID in ipairs(claims) do
		Spring.GiveOrderToUnit(teeID, CMD.LOAD_ONTO, { transporterID }, {})
	end
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

-- Blocks underwater pickups and capacity-exceeded pickups.
function gadget:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam)
	local _, y, _ = spGetUnitPosition(transporteeID)
	if isUnderwater(transporteeID, y) then return false end
	if Spring.GetUnitRulesParam(transporteeID, "inTransportAnim") == 1 then return false end
	if customTransportLoad[transporterUnitDefID] then
		local nSeats    = Spring.GetUnitRulesParam(transporterID, "nSeats")    or 0
		local usedSeats = Spring.GetUnitRulesParam(transporterID, "usedSeats") or 0
		local teeSize   = TransportAPI.GetTransporteeSize(transporteeID)
		if nSeats - usedSeats < teeSize then
			return false
		end
		local slotSizesStr = Spring.GetUnitRulesParam(transporterID, "slotSizes") or ""
		for sizeStr in slotSizesStr:gmatch("[^,]+") do
			if tonumber(sizeStr) == teeSize then
				return true
			end
		end
		return false
	end
	return true
end

-- Transport loading in 4 phases:
-- 1: Engine coarse move (pre-AllowUnitTransportLoad): the transporter moves toward the load target until dist < uDef.loadingRadius.
-- 2: Optional pre-queue phase for area commands: the transporter moves coarsely toward the area center and accumulates claims.
--    Each transporter gets its own AllowUnitTransportLoad call per SlowUpdate() (per Update() in the enhance_transports branch),
--    and they all claim in processing order. Overlap is prevented by calling SetUnitLoadingTransport(teeID, teeID),
--    which makes the target invisible to engine scans. The area command is consumed (UnitFinishCommand) when all seats are
--    pre-filled or when the engine finds no more valid targets; claims are then dispatched via processAllClaims().
-- 3: Single-target phase: move closer until inRange() is true; velocity-gate enemy units.
-- 4: Load the unit and finish the command.

function gadget:AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)

	if isUnderwater(transporteeID, goalY) then return false end -- AllowUnitTransport will drop that command anyway
	if not isAirTransport[transporterUnitDefID] then return true end -- we're not handling this

	local Q = Spring.GetUnitCommands(transporterID, 2)
	local duringAreaCmd = (Q[2] and Q[2].id == CMD.LOAD_UNITS and #Q[2].params == 4)

	if duringAreaCmd then -- pre-queue phase: accumulate claims
		-- move coarsely toward the area command center
		Spring.SetUnitMoveGoal(transporterID, Q[2].params[1], Q[2].params[2], Q[2].params[3])

		-- finish the current sub-command to re-trigger the scan on the next SlowUpdate (CMD.REMOVE might also work)
		Spring.UnitFinishCommand(transporterID)

		-- attempt to claim the offered transportee
		local teeSize = TransportAPI.GetTransporteeSize(transporteeID)
		local canSeat = claimTransportee(transporterID, transporteeID, teeSize)

		if not canSeat then -- transport is full; force the area command to finish
			Spring.UnitFinishCommand(transporterID)
		end

		-- the other exit is handled by the engine, which drops the area command when no more valid targets are found
		return false
	end

	-- post-queue phase: distance gate for individual load commands
	-- the transportee moves to the transporter on its own via the CMD.LOAD_ONTO command issued in processAllClaims()
	Spring.SetUnitMoveGoal(transporterID, goalX, goalY, goalZ)
	if not inRange(transporterID, goalX, goalY, goalZ) then -- not in range yet
		return false
	end

	-- make it harder to pull enemy units: velocity gate
	if not spAreTeamsAllied(spGetUnitTeam(transporterID), spGetUnitTeam(transporteeID))
	and select(4, spGetUnitVelocity(transporteeID)) >= 0.5 then
		return false
	end

	-- all checks passed; proceed to loading
	-- for custom transports, dispatch to LUS after a final canLoad gate (equivalent to isBusy);
	-- for standard transports, return true (they manage their own busy state)

	if customTransportLoad[transporterUnitDefID] then
		if Spring.GetUnitRulesParam(transporterID, "canLoad") == 0 then return false end -- canLoad gate
		releaseTransportee(transporteeID) -- release the pre-queue claim; also done in UnitLoaded as a safety net
		customTransportLoad[transporterUnitDefID](transporterID, 'PerformLoad', transporteeID)
		Spring.UnitFinishCommand(transporterID) -- consume the command so the transporter proceeds to the next
		return false
	end
	return true -- default for standard transports
end

-- Distance gate; for custom transports hand off to LUS (return false = engine skips detach).
function gadget:AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
	if isUnderwater(transporteeID, goalY) then return false end
	if isAirTransport[transporterUnitDefID] then
		Spring.SetUnitMoveGoal(transporterID, goalX, goalY + LOAD_RADIUS/2, goalZ)
		if not inRange(transporterID, goalX, goalY, goalZ) then return false end
		if customTransportUnload[transporterUnitDefID] then
			if Spring.GetUnitRulesParam(transporterID, "canUnload") == 0 then return false end
			local targets = TransportAPI.GetUnloadTargets(transporterID, transporteeID)
			for _, teeID in ipairs(targets) do
				customTransportUnload[transporterUnitDefID](transporterID, 'PerformUnload', teeID, goalX, goalY, goalZ)
			end
			Spring.UnitFinishCommand(transporterID)
			return false -- LUS handles the detachment
		end
	end
	return true
end


-- Transportee loaded: release its queued-seat reservation (LUS now owns the slot via usedSeats).
function gadget:UnitLoaded(unitID, unitDefID, transporterID, transporterDefID)
	releaseTransportee(unitID)
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	if cmdID == CMD.LOAD_UNITS and #cmdParams == 4 then -- area load cmd finished/canceled
		processAllClaims(unitID)
	elseif cmdID == CMD.LOAD_UNITS and #cmdParams == 1 and claimedBy[cmdParams[1]] then -- note: UnitFinishCommand on sub-commands in AllowUnitTransportLoad also fires this; the claimedBy guard prevents false releases
		releaseTransportee(cmdParams[1])
	end
end

-- Transportee died while loaded or while claimed: clean up bookkeeping and slot.
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	releaseTransportee(unitID)  -- no-op if not claimed
	releaseAllClaims(unitID)    -- no-op if not a transporter with claims

	-- TODO: handle the case of a transportee dying while queued for a claim,
	-- freeing up seats for other units. Since the area command is likely already consumed,
	-- the transporter will not automatically seek a replacement.
	-- Option: if a queued transportee dies, CMD.INSERT a new area load command using the stored
	-- area data. If the transporter is still in the area-command phase, do nothing; if it is in
	-- the single-load phase, reinsert the area command at the front and let the claiming cycle
	-- refill the queue, then resume the single-load phase once done.

	local transporterID = Spring.GetUnitTransporter(unitID)
	if not transporterID then return end

	local transporterDefID = Spring.GetUnitDefID(transporterID)

	if customTransportUnload[transporterDefID] then
		local gx, gy, gz = spGetUnitPosition(transporterID)
		customTransportUnload[transporterDefID](transporterID, 'PerformUnload', unitID, gx, gy, gz)
	end
end
