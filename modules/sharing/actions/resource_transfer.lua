local Actions = Actions ---@type ActionRegistrar injected by the loader (widget idiom)
local Shared = VFS.Include("modules/sharing/resource/shared.lua")

--- The only place resource amounts move between teams at runtime. Executes a
--- transfer within the bounds already established by the pair's
--- ResourcePolicyResult (policies stay pure; actions do the mutation).

---@param ctx ResourceTransferContext
---@return ResourceTransferResult
Actions.RegisterExecute(function(ctx)
	local policyResult = ctx.policyResult
	local desiredAmount = ctx.desiredAmount
	if (not policyResult or not policyResult.canShare) or (not desiredAmount or desiredAmount <= 0) then
		---@type ResourceTransferResult
		return {
			success = false,
			sent = 0,
			received = 0,
			senderTeamId = ctx.senderTeamId,
			receiverTeamId = ctx.receiverTeamId,
			policyResult = policyResult,
		}
	end

	local received, sent = Shared.CalculateSenderTaxedAmount(policyResult, desiredAmount)

	local springRepo = ctx.springRepo
	local resourceType = policyResult.resourceType
	-- deduct via SetTeamResource; AddTeamResource clamps its amount to >= 0
	local senderCurrent = springRepo.GetTeamResources(ctx.senderTeamId, resourceType) or 0
	springRepo.SetTeamResource(ctx.senderTeamId, resourceType, math.max(0, senderCurrent - sent))
	springRepo.AddTeamResource(ctx.receiverTeamId, resourceType, received)

	---@type ResourceTransferResult
	local result = {
		success = true,
		sent = sent,
		received = received,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		policyResult = policyResult,
	}

	return result
end)
