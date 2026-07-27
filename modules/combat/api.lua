---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.Combat
	assert(surface ~= nil, "Combat." .. name .. " called before the combat_rules gadget initialized")
	return surface
end

return {
	---An ordered attack still targets a protected unit; the damage floor is what makes that harmless.
	---Refcounted: one Unprotect per Protect.
	---@param unitID integer
	Protect = function(unitID)
		gadgetSurface("Protect").Protect(unitID)
	end,

	---@param unitID integer
	Unprotect = function(unitID)
		gadgetSurface("Unprotect").Unprotect(unitID)
	end,

	---@param unitID integer
	---@return boolean
	IsProtected = function(unitID)
		return gadgetSurface("IsProtected").IsProtected(unitID)
	end,

	---@param unitID integer
	---@param seconds number
	Stun = function(unitID, seconds)
		gadgetSurface("Stun").Stun(unitID, seconds)
	end,
}
