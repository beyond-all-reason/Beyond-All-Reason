local Enums = VFS.Include("modules/sharing/enums.lua")

--- The only place units change teams at runtime. Executes a transfer of
--- pre-validated units within the bounds of the pair's UnitPolicyResult
--- (policies stay pure; actions do the mutation).

---@param ctx UnitTransferContext
---@return UnitTransferResult
local function executeUnitTransfer(ctx)
	local policyResult = ctx.policyResult

	if not policyResult.canShare then
		---@type UnitTransferResult
		return {
			success = false,
			outcome = Enums.UnitValidationOutcome.Failure,
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

---@type ActionDescriptor
return {
	name = "UnitTransfer",
	parameters = {
		{ name = "ctx", required = true, type = "table" },
	},
	execute = executeUnitTransfer,
}
