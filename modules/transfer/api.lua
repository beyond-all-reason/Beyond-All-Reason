local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")

local mayUnitScratch = {}
local mayValidationScratch = {}
local unitsValidationScratch = {}

---@param name string action file name under actions/
---@param request table
---@return any result
local function perform(name, request)
	local action = ModuleHandler.LoadActions(Modules.Transfer).byName[name]
	if action == nil then
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
		if Spring.GetGameRulesParam("isTakeInProgress") == 1 then
			return true
		end
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
