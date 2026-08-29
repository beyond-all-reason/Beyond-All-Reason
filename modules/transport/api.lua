---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.Transport
	assert(surface ~= nil, "Transport." .. name .. " called before the transport_rules gadget initialized")
	return surface
end

return {
	---@param unitID integer
	---@return boolean
	IsCarried = function(unitID)
		return gadgetSurface("IsCarried").IsCarried(unitID)
	end,

	---@param unitID integer
	---@return integer|nil transportID
	CarrierOf = function(unitID)
		return gadgetSurface("CarrierOf").CarrierOf(unitID)
	end,

	---@param transportID integer
	---@return integer[]
	Cargo = function(transportID)
		return gadgetSurface("Cargo").Cargo(transportID)
	end,

	---@param transportDefID integer
	---@param unitDefID integer
	---@param carriedMass number|nil
	---@return boolean
	CanCarry = function(transportDefID, unitDefID, carriedMass)
		return gadgetSurface("CanCarry").CanCarry(transportDefID, unitDefID, carriedMass)
	end,
}
