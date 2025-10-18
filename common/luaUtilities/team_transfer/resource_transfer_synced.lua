local ModOptions = VFS.Include("common/luaUtilities/team_transfer/modoption_enums.lua")
local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local Gadgets = {}
Gadgets.__index = Gadgets

--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
---@param ctx ResourceTransferContext
---@return ResourceTransferResult
function Gadgets.ResourceTransfer(ctx)
  local policyResult = ctx.policyResult
  local desiredAmount = ctx.desiredAmount

  local received, sent, untaxed = Shared.CalculateSenderTaxedAmount(policyResult, desiredAmount)

  local springRepo = ctx.springRepo
  springRepo.AddTeamResource(ctx.senderTeamId, policyResult.resourceType, -sent)
  springRepo.AddTeamResource(ctx.receiverTeamId, policyResult.resourceType, received)

  ---@type ResourceTransferResult
  local result = {
    success = true,
    sent = sent,
    received = received,
    untaxed = untaxed,
    senderTeamId = ctx.senderTeamId,
    receiverTeamId = ctx.receiverTeamId,
    policyResult = policyResult
  }

  return result
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

    local cumulativeSent = Shared.GetCumulativeSent(ctx.senderTeamId, resourceType)
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
      overflowSliderEnabled = true
    }
  end
  return calcResourcePolicyResult
end

---@param ctx ResourceTransferContext
---@param transferResult ResourceTransferResult
function Gadgets.RegisterPostTransfer(ctx, transferResult)
  local cumulativeParam = Shared.GetCumulativeParam(ctx.resourceType)
  local cumulativeSent = tonumber(ctx.springRepo.GetTeamRulesParam(transferResult.senderTeamId, cumulativeParam))
  ctx.springRepo.SetTeamRulesParam(ctx.senderTeamId, cumulativeParam, cumulativeSent + transferResult.sent)
end

---@param springRepo ISpring
---@param senderId number
---@param receiverId number
---@param resourceType ResourceType
---@param policyResult ResourcePolicyResult
function Gadgets.CachePolicyResult(springRepo, senderId, receiverId, resourceType, policyResult)
  local baseKey = Shared.MakeBaseKey(receiverId, resourceType)
  local serialized = Shared.SerializeResourcePolicyResult(policyResult)
  springRepo.SetTeamRulesParam(senderId, baseKey, serialized)
end

--- Send chat messages for completed resource transfers
---@param transferResult ResourceTransferResult
---@param policyResult ResourcePolicyResult
function Gadgets.SendTransferChatMessages(transferResult, policyResult)
  if transferResult.sent > 0 then
    local resourceType = policyResult.resourceType
    local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
    local case = Shared.DecideCommunicationCase(policyResult)

    if case == SharedEnums.ResourceCommunicationCase.OnTaxFree then
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType .. ':receivedAmount=' .. math.floor(transferResult.received))
    elseif case == SharedEnums.ResourceCommunicationCase.OnTaxed then
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType ..
        'Taxed:receivedAmount=' ..
        math.floor(transferResult.received) ..
        ':sentAmount=' ..
        math.floor(transferResult.sent) .. ':taxRatePercentage=' .. math.floor(policyResult.taxRate * 100 + 0.5))
    elseif case == SharedEnums.ResourceCommunicationCase.OnTaxedThreshold then
      local cumulativeUntaxed = math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType ..
        'TaxedThreshold:receivedAmount=' ..
        math.floor(transferResult.received) ..
        ':sentAmount=' ..
        math.floor(transferResult.sent) ..
        ':taxRatePercentage=' ..
        math.floor(policyResult.taxRate * 100 + 0.5) ..
        ':sentAmountUntaxed=' ..
        math.floor(cumulativeUntaxed) .. ':resourceShareThreshold=' .. math.floor(policyResult.resourceShareThreshold))
    end
  end
end

return Gadgets
