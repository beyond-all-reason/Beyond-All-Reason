---@class TransportHaltRequest an air transport stops dead to load or set down
---@field carrierID integer

---@param request table unvalidated; validate is what makes it a TransportHaltRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" or type(request.carrierID) ~= "number" then
		return false, "transport.halt needs the carrier"
	end
	return true
end)

---@param request TransportHaltRequest
---@return boolean
Actions.RegisterExecute(function(request)
	Spring.SetUnitVelocity(request.carrierID, 0, 0, 0)
	return true
end)
