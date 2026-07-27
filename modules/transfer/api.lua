--- Synced contract of the transfer module: the one way things change hands.
---
--- Every verb here runs a declared action from actions/ — validate, then
--- execute — so the module has exactly one effectful path per capability and
--- the framework can see it. This file holds no state and makes no decisions;
--- it is the calling convention, not the behaviour.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

---Run a declared action: refuse on its own precondition, never halfway.
---@param name string action file name under actions/
---@param request table
---@return any result
local function perform(name, request)
	local action = ModuleHandler.LoadActions("transfer").byName[name]
	assert(action, "transfer has no action named " .. tostring(name))
	if action.validate then
		local allowed, reason = action.validate(request)
		if not allowed then
			Spring.Log("transfer", LOG.WARNING, "transfer." .. name .. " refused: " .. tostring(reason))
			return nil
		end
	end
	return action.execute(request)
end

return {
	---Hand units to another team through the sharing pipeline: the active
	---mode's policy decides whether it happens at all, and what it costs.
	---A caller that wants the transfer regardless of policy wants Give.
	---@param unitIDs integer[]
	---@param toTeamID integer
	---@param fromTeamID integer the team being asked to give them up
	---@return UnitTransferResult
	Units = function(unitIDs, toTeamID, fromTeamID)
		return perform("units", { from = fromTeamID, to = toTeamID, unitIDs = unitIDs })
	end,

	---Send metal or energy, priced by the active mode.
	---@param resource ResourceName
	---@param amount number
	---@param toTeamID integer
	---@param fromTeamID integer
	---@return ResourceTransferResult
	Resources = function(resource, amount, toTeamID, fromTeamID)
		return perform("resources", { from = fromTeamID, to = toTeamID, resource = resource, amount = amount })
	end,

	---Move units with no policy question asked: the giver is the game itself,
	---not a team choosing to share. Scripted handovers use this when the mode
	---is not meant to have a say — and a mode that IS meant to have a say
	---should see a Units call instead.
	---@param unitIDs integer[]
	---@param toTeamID integer
	---@return integer transferred
	Give = function(unitIDs, toTeamID)
		assert(GG ~= nil and GG.TransferUnits ~= nil,
			"Transfer.Give called before the unit transfer controller initialized")
		return GG.TransferUnits(unitIDs, toTeamID, true)
	end,
}
