local state = VFS.Include("modules/transport/state.lua") ---@type TransportState

---@class TransportLoadedRequest a passenger just came aboard
---@field unitID integer the passenger
---@field transportID integer the carrier
---@field carrier TransportDefTraits
---@field passenger TransportDefTraits
---@field loadedSpeed number|nil elmos per frame the carrier may fly now; nil for a carrier that does not fly

---@param request table unvalidated; validate is what makes it a TransportLoadedRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" then
		return false, "transport.loaded expects a request table"
	end
	if type(request.unitID) ~= "number" or type(request.transportID) ~= "number" then
		return false, "transport.loaded needs the passenger and the carrier"
	end
	if type(request.carrier) ~= "table" or type(request.passenger) ~= "table" then
		return false, "transport.loaded needs both units' traits"
	end
	return true
end)

---@param request TransportLoadedRequest
---@return boolean
Actions.RegisterExecute(function(request)
	if request.loadedSpeed ~= nil then
		state.loadedSpeed[request.transportID] = request.loadedSpeed
	end
	if request.carrier.stealthsPassengers and not request.passenger.isStealthy then
		Spring.SetUnitStealth(request.unitID, true)
	end
	if request.passenger.leavesGhost then
		Spring.SetUnitLeavesGhost(request.unitID, false, true)
	end
	return true
end)
