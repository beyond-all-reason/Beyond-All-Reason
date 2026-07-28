local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local TransferEnums = VFS.Include("modules/context/enums.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Shared = VFS.Include("modules/transfer/unit/shared.lua")
local PolicyEvents = VFS.Include("modules/context/policy_events.lua")

local Synced = {
	ValidateUnits = Shared.ValidateUnits,
	GetModeUnitTypes = Shared.GetModeUnitTypes,
}

---@param ctx TransferPolicyContext
---@return UnitPolicyResult
function Synced.GetPolicy(ctx)
	local pipelines = ModuleHandler.LoadPolicies("transfer") ---@type TransferPipelines
	return ModuleHandler.Evaluate(pipelines.unit_transfer, ctx)
end

---@param ctx UnitTransferContext
---@return UnitTransferResult
function Synced.UnitTransfer(ctx)
	local policyResult = ctx.policyResult

	if not policyResult.canShare then
		---@type UnitTransferResult
		return {
			success = false,
			outcome = TransferEnums.UnitValidationOutcome.Failure,
			senderTeamId = ctx.senderTeamId,
			receiverTeamId = ctx.receiverTeamId,
			validationResult = ctx.validationResult,
			policyResult = ctx.policyResult,
		}
	end

	for _, unitId in ipairs(ctx.validationResult.validUnitIds) do
		ctx.springRepo.TransferUnit(unitId, ctx.receiverTeamId, ctx.given)
	end

	---@type UnitTransferResult
	return {
		success = true,
		outcome = ctx.validationResult.status,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		validationResult = ctx.validationResult,
		policyResult = ctx.policyResult,
	}
end

---@param springRepo Spring
---@param teamId integer
---@return boolean
local function teamActive(springRepo, teamId)
	local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
	if n == nil then
		return true
	end
	return tonumber(n) ~= 0
end

---@param springRepo Spring
---@param teamId integer
---@param ctx TransferPolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's modes
function Synced.CacheTeamFactor(springRepo, teamId, ctx)
	local modes = ctx.unitSharingModes
		or { springRepo.GetModOptions().unit_sharing_mode or ModeEnums.UnitFilterCategory.None }
	local serialized = Shared.SerializeUnitFactor({
		sharingModes = modes,
		active = teamActive(springRepo, teamId),
	})
	springRepo.SetTeamRulesParam(teamId, Shared.MakeFactorKey(), serialized)
	PolicyEvents.NotifyIfChanged(teamId, TransferEnums.PolicyType.UnitTransfer, serialized)
end

return Synced
