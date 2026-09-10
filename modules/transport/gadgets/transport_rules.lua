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

local Transport = VFS.Include("modules/transport/api.lua") ---@type TransportApi
local Unstack = VFS.Include("modules/transport/lib/unstack.lua") ---@type TransportUnstack
local state = VFS.Include("modules/transport/state.lua") ---@type TransportState

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
	return Transport.MayLoad(transporterID, transporterDefID, transporteeID, transporteeDefID, goalX, goalY, goalZ)
end

function gadget:AllowUnitTransportUnload(transporterID, transporterDefID, _, transporteeID, _, _, goalX, goalY, goalZ)
	return Transport.MayUnload(transporterID, transporterDefID, transporteeID, goalX, goalY, goalZ)
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
	Transport.Loaded(unitID, unitDefID, transportID)
end

function gadget:UnitUnloaded(unitID, unitDefID, _, transportID)
	if unitID == nil or unitDefID == nil or transportID == nil then
		return
	end
	Transport.Unloaded(unitID, unitDefID, transportID)
end

function gadget:GameFrame(frame)
	for transportID, allowed in pairs(state.loadedSpeed) do
		local vx, vy, vz, vw = Spring.GetUnitVelocity(transportID)
		if vw and vw > allowed then
			local factor = allowed / vw
			Spring.SetUnitVelocity(transportID, vx * factor, vy * factor, vz * factor)
		end
	end
	for unitID, unitDefID in pairs(state.unstacking) do
		if not Spring.ValidUnitID(unitID) or Unstack.Step(unitID, unitDefID) then
			state.unstacking[unitID] = nil
		end
	end
	for unitID, landing in pairs(state.settling) do
		if landing.frame <= frame then
			state.settling[unitID] = nil
			if Spring.ValidUnitID(unitID) then
				Spring.SetUnitPhysics(unitID, landing.px, landing.py, landing.pz, 0, 0, 0, 0, 0, 0, 0, 0, 0)
				Spring.SetUnitDirection(unitID, landing.dx, landing.dy, landing.dz, landing.rx, landing.ry, landing.rz)
			end
		end
	end
end

function gadget:GameFramePost()
	if next(state.maybeDead) == nil then
		return
	end
	for unitID, transportID in pairs(state.maybeDead) do
		if deadOrCrashing(transportID) and not deadOrCrashing(unitID) then
			Spring.UnitDetach(unitID)
			Spring.AddUnitDamage(unitID, 1e6, nil, nil, Game.envDamageTypes.TransportKilled)
		end
	end
	state.maybeDead = {}
end

function gadget:UnitCreated(unitID, unitDefID)
	if not Transport.DefTraits(unitDefID).canMove then
		Unstack.Wake(state.unstacking, unitID)
	end
end

function gadget:UnitDestroyed(unitID)
	state.loadedSpeed[unitID] = nil
	state.settling[unitID] = nil
	state.unstacking[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD.UNLOAD_UNITS)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if Transport.DefTraits(unitDefID).isNano then
			state.unstacking[unitID] = unitDefID
		end
	end
end
