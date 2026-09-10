local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transport Rules",
		desc = "One owner for what a carrier may load, where it may set down, how fast it flies loaded, and what becomes of cargo",
		author = "Doo, Bluestone, raaar, Hornet, knorke, icexuick, beherith, Niobium, Chronographer, Beyond All Reason",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local Rules = VFS.Include("modules/transport/lib/rules.lua") ---@type TransportRules
local Transport = VFS.Include("modules/transport/api.lua") ---@type TransportApi
local Unstack = VFS.Include("modules/transport/lib/unstack.lua") ---@type TransportUnstack

local loadedSpeed = {} ---@type table<integer, number> air transport -> allowed elmos per frame
local settling = {} ---@type table<integer, table> unloaded unit -> where it landed, and when to pin it
local maybeDead = {} ---@type table<integer, integer> cargo -> the carrier that just let go
local unstacking = {} ---@type table<integer, integer> a nano turret -> its def, nudged until clear of any immobile ally

---@param transportID integer
local function updateLoadedSpeed(transportID)
	local allowed = Transport.LoadedSpeed(transportID)
	if allowed ~= nil then
		loadedSpeed[transportID] = allowed
	end
end

---@param unitID integer
---@return boolean
local function deadOrCrashing(unitID)
	return Spring.GetUnitIsDead(unitID) ~= false or Spring.GetUnitMoveTypeData(unitID).aircraftState == "crashing"
end

function gadget:AllowUnitTransport(_, transporterDefID, _, transporteeID, transporteeDefID)
	return Transport.MayCarry(transporterDefID, transporteeID, transporteeDefID)
end

function gadget:AllowUnitTransportLoad(
	transporterID,
	transporterDefID,
	_,
	transporteeID,
	transporteeDefID,
	_,
	goalX,
	goalY,
	goalZ
)
	local allowed =
		Transport.MayLoad(transporterID, transporterDefID, transporteeID, transporteeDefID, goalX, goalY, goalZ)
	if allowed and Transport.DefTraits(transporterDefID).reach then
		Spring.SetUnitVelocity(transporterID, 0, 0, 0)
	end
	return allowed
end

function gadget:AllowUnitTransportUnload(transporterID, transporterDefID, _, transporteeID, _, _, goalX, goalY, goalZ)
	local allowed = Transport.MayUnload(transporterID, transporterDefID, transporteeID, goalX, goalY, goalZ)
	if allowed and Transport.DefTraits(transporterDefID).reach then
		Spring.SetUnitVelocity(transporterID, 0, 0, 0)
	end
	return allowed
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	if not Transport.DefTraits(unitDefID).isTransport then
		return false
	end
	if cmdID == CMD.LOAD_UNITS then
		if #cmdParams == 1 then
			local targetID = cmdParams[1]
			if Spring.ValidUnitID(targetID) then
				return Transport.MayOrderLoad(unitID, unitDefID, teamID, targetID)
			end
		end
	elseif cmdParams[1] and cmdParams[3] then
		local cargo = Spring.GetUnitIsTransporting(unitID)
		if cargo and cargo[1] and Transport.DefTraits(Spring.GetUnitDefID(cargo[1])).isNano then
			return Transport.MayOrderUnload(cmdParams[1], cmdParams[2], cmdParams[3])
		end
	end
	return true
end

function gadget:UnitLoaded(unitID, unitDefID, _, transportID)
	local carrier = Transport.DefTraits(Spring.GetUnitDefID(transportID))
	local passenger = Transport.DefTraits(unitDefID)
	if carrier.canFly then
		updateLoadedSpeed(transportID)
	end
	if carrier.stealthsPassengers and not passenger.isStealthy then
		Spring.SetUnitStealth(unitID, true)
	end
	if passenger.leavesGhost then
		Spring.SetUnitLeavesGhost(unitID, false, true)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, _, transportID)
	if unitID == nil or unitDefID == nil or transportID == nil then
		return
	end
	local carrier = Transport.DefTraits(Spring.GetUnitDefID(transportID))
	local passenger = Transport.DefTraits(unitDefID)
	if carrier.canFly then
		local cargo = Spring.GetUnitIsTransporting(transportID)
		if cargo == nil or cargo[1] == nil then
			loadedSpeed[transportID] = nil
		else
			updateLoadedSpeed(transportID)
		end
	end
	if carrier.stealthsPassengers and not passenger.isStealthy then
		Spring.SetUnitStealth(unitID, false)
	end
	if passenger.leavesGhost then
		Spring.SetUnitLeavesGhost(unitID, true)
	end
	if not passenger.canMove then
		for turretID, turretDefID in pairs(Unstack.TurretsUnder(unitID)) do
			unstacking[turretID] = turretDefID
		end
	end

	if passenger.isParatrooper then
		local vx, vy, vz = Spring.GetUnitVelocity(transportID)
		vx, vz = Rules.ClampParatrooperVelocity(vx), Rules.ClampParatrooperVelocity(vz)
		local x, y, z = Spring.GetUnitPosition(unitID)
		if y - Spring.GetGroundHeight(x, z) < Rules.PARATROOPER_GROUND_MARGIN then
			vx, vy, vz = 0, 0, 0
		end
		Spring.SetUnitVelocity(unitID, vx, vy, vz)
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		return
	end

	local px, py, pz = Spring.GetUnitPosition(unitID)
	local dx, dy, dz, rx, ry, rz = Spring.GetUnitDirection(unitID)
	settling[unitID] = {
		px = px,
		py = py,
		pz = pz,
		dx = dx,
		dy = dy,
		dz = dz,
		rx = rx,
		ry = ry,
		rz = rz,
		frame = Spring.GetGameFrame() + Rules.UNLOAD_SETTLE_FRAMES,
	}
	Spring.SetUnitVelocity(unitID, 0, 0, 0)

	if not Spring.GetUnitRulesParam(unitID, "unit_effigy") then
		maybeDead[unitID] = transportID
	end
end

function gadget:GameFrame(frame)
	for transportID, allowed in pairs(loadedSpeed) do
		local vx, vy, vz, vw = Spring.GetUnitVelocity(transportID)
		if vw and vw > allowed then
			local factor = allowed / vw
			Spring.SetUnitVelocity(transportID, vx * factor, vy * factor, vz * factor)
		end
	end
	for unitID, unitDefID in pairs(unstacking) do
		if not Spring.ValidUnitID(unitID) or Unstack.Step(unitID, unitDefID) then
			unstacking[unitID] = nil
		end
	end
	for unitID, landing in pairs(settling) do
		if landing.frame <= frame then
			settling[unitID] = nil
			if Spring.ValidUnitID(unitID) then
				Spring.SetUnitPhysics(unitID, landing.px, landing.py, landing.pz, 0, 0, 0, 0, 0, 0, 0, 0, 0)
				Spring.SetUnitDirection(unitID, landing.dx, landing.dy, landing.dz, landing.rx, landing.ry, landing.rz)
			end
		end
	end
end

function gadget:GameFramePost()
	if next(maybeDead) == nil then
		return
	end
	for unitID, transportID in pairs(maybeDead) do
		if deadOrCrashing(transportID) and not deadOrCrashing(unitID) then
			Spring.UnitDetach(unitID)
			Spring.AddUnitDamage(unitID, 1e6, nil, nil, Game.envDamageTypes.TransportKilled)
		end
	end
	maybeDead = {}
end

function gadget:UnitCreated(unitID, unitDefID)
	if not Transport.DefTraits(unitDefID).canMove then
		for turretID, turretDefID in pairs(Unstack.TurretsUnder(unitID)) do
			unstacking[turretID] = turretDefID
		end
	end
end

function gadget:UnitDestroyed(unitID)
	loadedSpeed[unitID] = nil
	settling[unitID] = nil
	unstacking[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD.UNLOAD_UNITS)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if Transport.DefTraits(unitDefID).isNano then
			unstacking[unitID] = unitDefID
		end
	end
	GG.Transport = {
		---@param unitID integer
		---@return boolean
		IsCarried = function(unitID)
			return Spring.GetUnitTransporter(unitID) ~= nil
		end,
		---@param unitID integer
		---@return integer|nil
		CarrierOf = function(unitID)
			return Spring.GetUnitTransporter(unitID)
		end,
		---@param transportID integer
		---@return integer[]
		Cargo = function(transportID)
			return Spring.GetUnitIsTransporting(transportID) or {}
		end,
		---@param transportDefID integer
		---@param unitDefID integer
		---@param carriedMass number|nil
		---@param carriedCount integer|nil
		---@return boolean
		CanCarry = function(transportDefID, unitDefID, carriedMass, carriedCount)
			local transportDef, unitDef = UnitDefs[transportDefID], UnitDefs[unitDefID]
			return transportDef ~= nil
				and unitDef ~= nil
				and Rules.CanCarry(transportDef, unitDef, carriedMass, carriedCount)
		end,
	}
end

function gadget:Shutdown()
	GG.Transport = nil
end
