local ModuleHandler = VFS.Include("modules/module_handler.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")

-- Refilled per call: the engine asks this once per unit per transfer attempt.
local mayUnitScratch = {}
local mayValidationScratch = {}
-- Units' own scratch: MayTransfer fires inside the transfer loop, while the
-- request built here is still being read.
local unitsValidationScratch = {}

---@param name string action file name under actions/
---@param request table
---@return any result
local function perform(name, request)
	local action = ModuleHandler.LoadActions("transfer").byName[name]
	if action == nil then
		-- Refuse, do not raise: this runs inside engine callins. The usual cause is a file added
		-- while running; the registry is memoised and the VFS listing not re-scanned.
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
	---@param unitIDs integer[]
	---@param toTeamID integer
	---@param fromTeamID integer the team being asked to give them up
	---@return UnitTransferResult
	Units = function(unitIDs, toTeamID, fromTeamID)
		-- The api gathers; the action only reads its request. The grant is the pair's cached
		-- policy result, the validation is that grant applied to each unit as it is now.
		local grant = UnitShared.GetCachedPolicyResult(fromTeamID, toTeamID, Spring)
		return perform("units", {
			from = fromTeamID,
			to = toTeamID,
			unitIDs = unitIDs,
			grant = grant,
			validation = UnitShared.ValidateUnits(grant, unitIDs, Spring, nil, unitsValidationScratch),
		})
	end,

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
			grant = ResourceShared.GetCachedPolicyResult(fromTeamID, toTeamID, resource, Spring),
		})
	end,

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
		-- A fiat Give asks no policy question, but the engine asks this callin anyway on the way
		-- through Spring.TransferUnit; without this a mission handing a Gaia outpost to the player
		-- is refused because Gaia is nobody's ally.
		-- A rulesparam rather than an upvalue because VFS.Include is uncached: the controller
		-- and the caller hold DIFFERENT copies of this file.
		if Spring.GetGameRulesParam("isGiveInProgress") == 1 then
			return true
		end
		local policyResult = UnitShared.GetCachedPolicyResult(fromTeamID, toTeamID, Spring)
		mayUnitScratch[1] = unitID
		local validation = UnitShared.ValidateUnits(policyResult, mayUnitScratch, Spring, nil, mayValidationScratch)
		return validation.status ~= TransferEnums.UnitValidationOutcome.Failure
	end,

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
		})
	end,

	---@param unitIDs integer[]
	---@param toTeamID integer
	---@return integer transferred
	Give = function(unitIDs, toTeamID)
		return perform("give", { to = toTeamID, unitIDs = unitIDs })
	end,
}
