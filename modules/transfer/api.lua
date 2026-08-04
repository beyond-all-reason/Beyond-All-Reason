--- Synced contract of the transfer module: the one way things change hands.
---
--- Every verb here runs a declared action from actions/ — validate, then
--- execute — so the module has exactly one effectful path per capability and
--- the framework can see it. This file holds no state and makes no decisions;
--- it is the calling convention, not the behaviour.

local ModuleHandler = VFS.Include("modules/module_handler.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local TransferEnums = VFS.Include("modules/context/enums.lua")

-- Refilled per call: the engine asks this once per unit per transfer attempt.
local mayUnitScratch = {}
local mayValidationScratch = {}

---Run a declared action: refuse on its own precondition, never halfway.
---@param name string action file name under actions/
---@param request table
---@return any result
local function perform(name, request)
	local action = ModuleHandler.LoadActions("transfer").byName[name]
	if action == nil then
		-- Refuse, do not raise: this runs inside engine callins, and a missing
		-- action must not take the callin down with it. The usual cause is a
		-- file added while the game was running — the registry is memoised and
		-- the VFS listing is not re-scanned, so a restart is what picks it up.
		Spring.Log(
			"transfer",
			LOG.ERROR,
			"transfer has no action named "
				.. tostring(name)
				.. " (added since the game started? restart to pick it up)"
		)
		return nil
	end
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
		-- The pipeline entry point travels in the request: an action file runs
		-- in the registrar's environment, where GG is not the gadget's GG.
		return perform("units", {
			from = fromTeamID,
			to = toTeamID,
			unitIDs = unitIDs,
			share = GG and GG.ShareUnits,
		})
	end,

	---Send metal or energy, priced by the active mode.
	---@param resource ResourceName
	---@param amount number
	---@param toTeamID integer
	---@param fromTeamID integer
	---@return ResourceTransferResult
	Resources = function(resource, amount, toTeamID, fromTeamID)
		return perform("resources", {
			from = fromTeamID,
			to = toTeamID,
			resource = resource,
			amount = amount,
			send = GG and GG.ShareTeamResource,
		})
	end,

	---May this one unit move between these teams? The engine asks through
	---AllowUnitTransfer; the gadget there is an adapter, and this is the
	---answer — so an engine hook and a deliberate share cannot disagree.
	---@param unitID integer
	---@param fromTeamID integer
	---@param toTeamID integer
	---@param capture boolean|nil engine-driven capture, never a policy question
	---@return boolean
	MayTransfer = function(unitID, fromTeamID, toTeamID, capture)
		if capture then
			return true
		end
		-- /take moves a whole seat under its own policy; per-unit rules do not
		-- apply to the sweep it performs.
		if Spring.GetGameRulesParam("isTakeInProgress") == 1 then
			return true
		end
		-- Nor to a fiat Give. Its whole contract is "no policy question
		-- asked", but the engine asks this callin anyway on the way through
		-- Spring.TransferUnit — so without this the bypass bypasses nothing,
		-- and a mission handing a Gaia outpost to the player is refused for
		-- the entirely correct reason that Gaia is nobody's ally.
		--
		-- A rulesparam rather than an upvalue because VFS.Include is uncached:
		-- the controller and the caller hold DIFFERENT copies of this file.
		if Spring.GetGameRulesParam("isGiveInProgress") == 1 then
			return true
		end
		local policyResult = UnitShared.GetCachedPolicyResult(fromTeamID, toTeamID, Spring)
		mayUnitScratch[1] = unitID
		local validation = UnitShared.ValidateUnits(policyResult, mayUnitScratch, Spring, nil, mayValidationScratch)
		return validation.status ~= TransferEnums.UnitValidationOutcome.Failure
	end,

	---Hand a team's resources over with no policy question asked: a seat
	---changing hands, not a team choosing to share. Untaxed by definition.
	---@param resource ResourceName
	---@param amount number
	---@param toTeamID integer
	---@param fromTeamID integer
	---@return number moved
	GiveResources = function(resource, amount, toTeamID, fromTeamID)
		return perform("give_resources", {
			from = fromTeamID,
			to = toTeamID,
			resource = resource,
			amount = amount,
			add = GG and GG.AddTeamResource,
			take = GG and GG.AddTeamResource,
		})
	end,

	---Move units with no policy question asked: the giver is the game itself,
	---not a team choosing to share. Scripted handovers use this when the mode
	---is not meant to have a say — and a mode that IS meant to have a say
	---should see a Units call instead.
	---@param unitIDs integer[]
	---@param toTeamID integer
	---@return integer transferred
	Give = function(unitIDs, toTeamID)
		return perform("give", { to = toTeamID, unitIDs = unitIDs, move = GG and GG.TransferUnits })
	end,
}
