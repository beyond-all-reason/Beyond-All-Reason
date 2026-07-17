local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local TransferEnums = VFS.Include("common/luaUtilities/sharing/transfer_enums.lua")
local Shared = VFS.Include("common/luaUtilities/sharing/unit_transfer_shared.lua")
local PolicyEvents = VFS.Include("common/luaUtilities/sharing/policy_events.lua")

local Synced = {
	ValidateUnits = Shared.ValidateUnits,
	GetModeUnitTypes = Shared.GetModeUnitTypes,
}

---Build per-pair policy (expose) from context
---@param ctx PolicyContext
---@return UnitPolicyResult
function Synced.GetPolicy(ctx)
	local modOptions = ctx.springRepo.GetModOptions()
	local modes = ctx.unitSharingModes or { modOptions.unit_sharing_mode or ModeEnums.UnitFilterCategory.None }
	local canShare = ctx.areAlliedTeams and not (#modes == 1 and modes[1] == ModeEnums.UnitFilterCategory.None)
	if canShare and not ctx.isCheatingEnabled then
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		if numActivePlayers ~= nil and tonumber(numActivePlayers) == 0 then
			canShare = false
		end
	end
	local stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0
	local stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource
	local buildDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.ConstructorBuildDelay]) or 0
	return {
		canShare = canShare,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		sharingModes = modes,
		stunSeconds = stunSeconds,
		stunCategory = stunCategory,
		buildDelaySeconds = buildDelaySeconds,
		techBlocking = ctx.ext and ctx.ext.techBlocking or nil,
	}
end

---Execute unit transfer with pre-validated units
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
		-- ctx.given should always be false here because we short-circuit inside AllowResourceTransfer
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

---@param springRepo EngineSynced
---@param teamId integer
---@return boolean
local function teamActive(springRepo, teamId)
	local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
	if n == nil then
		return true
	end
	return tonumber(n) ~= 0
end

---Compute and cache one team's unit factor: its tech-resolved sharing modes + active flag.
---@param springRepo EngineSynced
---@param teamId integer
---@param ctx PolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's modes
function Synced.CacheTeamFactor(springRepo, teamId, ctx)
	local modes = ctx.unitSharingModes or { springRepo.GetModOptions().unit_sharing_mode or ModeEnums.UnitFilterCategory.None }
	local serialized = Shared.SerializeUnitFactor({
		sharingModes = modes,
		active = teamActive(springRepo, teamId),
	})
	springRepo.SetTeamRulesParam(teamId, Shared.MakeFactorKey(), serialized)
	PolicyEvents.NotifyIfChanged(teamId, TransferEnums.PolicyType.UnitTransfer, serialized)
end

return Synced
