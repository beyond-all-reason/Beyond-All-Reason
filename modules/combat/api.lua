--- Synced contract of the combat module. Forwards through the combat_rules
--- gadget's GG surface, the ledger's one owner; this file holds no state.

---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.Combat
	assert(surface ~= nil, "Combat." .. name .. " called before the combat_rules gadget initialized")
	return surface
end

return {
	---Protect a unit: neutral, so enemy weapons stop auto-acquiring it, and
	---immune to damage. An ordered attack still targets it; the damage floor
	---is what makes that harmless. Refcounted — one Unprotect per Protect.
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

	---Paralyze a unit for a duration. Module capability only — there is
	---deliberately no mission DSL over this; modules re-reference it.
	---@param unitID integer
	---@param seconds number
	Stun = function(unitID, seconds)
		gadgetSurface("Stun").Stun(unitID, seconds)
	end,
}
