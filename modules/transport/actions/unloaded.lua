local Rules = VFS.Include("modules/transport/lib/rules.lua") ---@type TransportRules
local Unstack = VFS.Include("modules/transport/lib/unstack.lua") ---@type TransportUnstack
local state = VFS.Include("modules/transport/state.lua") ---@type TransportState

---@class TransportUnloadedRequest a passenger was just set down
---@field unitID integer the passenger
---@field unitDefID integer
---@field transportID integer the carrier
---@field carrier TransportDefTraits
---@field passenger TransportDefTraits
---@field loadedSpeed number|false|nil the carrier's speed with what it still carries; false when it carries nothing; nil for a carrier that does not fly
---@field frame integer the game frame the set-down happened on

---@param request table unvalidated; validate is what makes it a TransportUnloadedRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" then
		return false, "transport.unloaded expects a request table"
	end
	if
		type(request.unitID) ~= "number"
		or type(request.unitDefID) ~= "number"
		or type(request.transportID) ~= "number"
	then
		return false, "transport.unloaded needs the passenger, its def and the carrier"
	end
	if type(request.carrier) ~= "table" or type(request.passenger) ~= "table" then
		return false, "transport.unloaded needs both units' traits"
	end
	if type(request.frame) ~= "number" then
		return false, "transport.unloaded needs the frame"
	end
	return true
end)

---@param request TransportUnloadedRequest
---@return boolean
Actions.RegisterExecute(function(request)
	local unitID, transportID = request.unitID, request.transportID
	local carrier, passenger = request.carrier, request.passenger
	if carrier.canFly then
		state.loadedSpeed[transportID] = request.loadedSpeed or nil
	end
	if carrier.stealthsPassengers and not passenger.isStealthy then
		Spring.SetUnitStealth(unitID, false)
	end
	if passenger.leavesGhost then
		Spring.SetUnitLeavesGhost(unitID, true)
	end
	if not passenger.canMove then
		Unstack.Wake(state.unstacking, unitID)
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
		return true
	end

	local px, py, pz = Spring.GetUnitPosition(unitID)
	local dx, dy, dz, rx, ry, rz = Spring.GetUnitDirection(unitID)
	state.settling[unitID] = {
		px = px,
		py = py,
		pz = pz,
		dx = dx,
		dy = dy,
		dz = dz,
		rx = rx,
		ry = ry,
		rz = rz,
		frame = request.frame + Rules.UNLOAD_SETTLE_FRAMES,
	}
	Spring.SetUnitVelocity(unitID, 0, 0, 0)

	if not Spring.GetUnitRulesParam(unitID, "unit_effigy") then
		state.maybeDead[unitID] = transportID
	end
	return true
end)
