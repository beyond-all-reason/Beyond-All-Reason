local ModOptions = VFS.Include("common/luaUtilities/team_transfer/modoption_enums.lua")
local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local SharedHelpers = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local Gadgets = {}
Gadgets.__index = Gadgets

--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
---@param ctx ResourceTransferContext
---@return ResourceTransferResult
function Gadgets.ResourceTransfer(ctx)
	local policyResult = ctx.policyResult
	local desiredAmount = ctx.desiredAmount

	local received, sent = SharedHelpers.CalculateSenderTaxedAmount(policyResult, desiredAmount)

	local springRepo = ctx.springRepo
	springRepo.AddTeamResource(ctx.senderTeamId, policyResult.resourceType, -sent)
	springRepo.AddTeamResource(ctx.receiverTeamId, policyResult.resourceType, received)

	---@type ResourceTransferResult
	local result = {
		success = true,
		sent = sent,
		received = received,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		policyResult = policyResult
	}

	return result
end

-- Tax Resource Sharing

---@param transferResult ResourceTransferResult
---@param ctx ResourceTransferContext
function Gadgets.ApplyTransferResultToContext(transferResult, ctx)
	local resourceType = transferResult.policyResult and transferResult.policyResult.resourceType or ctx.resourceType
	local sender, receiver
	if resourceType == SharedEnums.ResourceType.METAL then
		sender = ctx.sender.metal
		receiver = ctx.receiver.metal
	elseif resourceType == SharedEnums.ResourceType.ENERGY then
		sender = ctx.sender.energy
		receiver = ctx.receiver.energy
	end
	sender.current = math.max(0, sender.current - transferResult.sent)
	receiver.current = math.min(receiver.storage, receiver.current + transferResult.received)
end

---@param taxRate number
---@param metalThreshold number
---@param energyThreshold number
---@return fun(ctx: PolicyContext, resourceType: ResourceType) : ResourcePolicyResult
function Gadgets.BuildResultFactory(taxRate, metalThreshold, energyThreshold)
	---@param resourceType ResourceType
	local function getThreshold(resourceType)
		if resourceType == SharedEnums.ResourceType.METAL then
			return metalThreshold
		elseif resourceType == SharedEnums.ResourceType.ENERGY then
			return energyThreshold
		end
	end

	---@param ctx PolicyContext
	---@param resourceType ResourceType
	---@return ResourcePolicyResult
	local function calcResourcePolicyResult(ctx, resourceType)
		local senderData
		local receiverData
		if resourceType == SharedEnums.ResourceType.METAL then
			senderData = ctx.sender.metal
			receiverData = ctx.receiver.metal
		elseif resourceType == SharedEnums.ResourceType.ENERGY then
			senderData = ctx.sender.energy
			receiverData = ctx.receiver.energy
		end

		local receiverCapacity = receiverData.storage - receiverData.current

		local cumulativeSent = SharedHelpers.GetCumulativeSent(ctx.senderTeamId, resourceType)
		local threshold = getThreshold(resourceType)
		local allowanceRemaining = math.max(0, threshold - cumulativeSent)
		local senderBudget = math.max(0, senderData.current)

		local untaxedPortion = math.min(allowanceRemaining, senderBudget)

		local effectiveRate = (taxRate < 1) and taxRate or 1

		-- Cap taxed receivable early by budget and receiver capacity
		local taxedSendable = math.max(0, (senderBudget - untaxedPortion) * (1 - effectiveRate))
		local maxReceivable = math.max(0, receiverCapacity - untaxedPortion)
		local taxedPortion = math.min(taxedSendable, maxReceivable)

		-- Example of sender cost inversion used by ResourceTransfer: untaxed + taxed/(1 - r)
		-- local reversed = untaxedPortion + (taxedPortion > 0 and (taxedPortion / (1 - effectiveRate)) or 0)

		-- note that amountSendable is in receivable units
		local amountSendable = untaxedPortion + taxedPortion

		---@type ResourcePolicyResult
		return {
			senderTeamId = ctx.senderTeamId,
			receiverTeamId = ctx.receiverTeamId,
			-- policy caps, note amounts here are all in receivable units
			canShare = amountSendable > 0,
			amountSendable = amountSendable,
			amountReceivable = receiverCapacity,
			taxedPortion = taxedPortion,
			untaxedPortion = untaxedPortion,
			taxRate = effectiveRate,
			resourceType = resourceType,
			remainingTaxFreeAllowance = allowanceRemaining,
			resourceShareThreshold = threshold,
			cumulativeSent = cumulativeSent,
		}
	end
	return calcResourcePolicyResult
end

---@param transferResult ResourceTransferResult
---@param resourceType ResourceType
---@param springRepo ISpring
function Gadgets.RegisterPostTransfer(transferResult, resourceType, springRepo)
	local cumulativeParam = SharedHelpers.GetCumulativeParam(resourceType)
	local cumulativeSent = tonumber(springRepo.GetTeamRulesParam(transferResult.senderTeamId, cumulativeParam)) or 0
	springRepo.SetTeamRulesParam(transferResult.senderTeamId, cumulativeParam, cumulativeSent + transferResult.sent)
end

---@param springRepo ISpring
---@param senderId number
---@param receiverId number
---@param resourceType ResourceType
---@param policyResult ResourcePolicyResult
function Gadgets.CachePolicyResult(springRepo, senderId, receiverId, resourceType, policyResult)
	local baseKey = SharedHelpers.MakeBaseKey(receiverId, resourceType)
	local serialized = SharedHelpers.SerializePolicyResult(policyResult)
	springRepo.SetTeamRulesParam(senderId, baseKey, serialized)
end

return Gadgets
