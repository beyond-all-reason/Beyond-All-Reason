local ModOptions = VFS.Include("common/luaUtilities/team_transfer/modoption_enums.lua")
local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local Gadgets = {
  SendTransferChatMessages = Comms.SendTransferChatMessages,
}
Gadgets.__index = Gadgets

-- Determine if a team is a non-player team (Gaia or AI-controlled)
local function isNonPlayerTeam(springRepo, teamId)
  if teamId == springRepo.GetGaiaTeamID() then
    return true
  end
  local _name, _active, _spec, isAiTeam = springRepo.GetTeamInfo(teamId, false)
  if isAiTeam then
    return true
  end
  local luaAI = springRepo.GetTeamLuaAI and springRepo.GetTeamLuaAI(teamId)
  return luaAI ~= nil
end

-- Build a rejected policy result with zeroed capabilities
---@param ctx PolicyContext
---@param resourceType ResourceType
---@return ResourcePolicyResult
local function rejectPolicy(ctx, resourceType)
  return Shared.CreateDenyPolicy(
    ctx.senderTeamId,
    ctx.receiverTeamId,
    resourceType,
    Shared.GetCumulativeSent(ctx.senderTeamId, resourceType)
  )
end

-- Encapsulate legacy AllowResourceTransfer gate rules
---@param ctx PolicyContext
---@param resourceType ResourceType
---@return ResourcePolicyResult|nil
local function tryRejectPolicy(ctx, resourceType)
  if ctx.isCheatingEnabled then
    return nil
  end
  if not ctx.areAlliedTeams and not isNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
    return rejectPolicy(ctx, resourceType)
  end
  local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
  local activePlayers = numActivePlayers and
      tonumber(ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")) or 0
  if activePlayers == 0 then
    return rejectPolicy(ctx, resourceType)
  end
  return nil
end

--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
---@param ctx ResourceTransferContext
---@return ResourceTransferResult
function Gadgets.ResourceTransfer(ctx)
  local policyResult = ctx.policyResult
  local desiredAmount = ctx.desiredAmount

  if (not policyResult or not policyResult.canShare) or (not desiredAmount or desiredAmount <= 0) then
    ---@type ResourceTransferResult
    return {
      success = false,
      sent = 0,
      received = 0,
      untaxed = 0,
      senderTeamId = ctx.senderTeamId,
      receiverTeamId = ctx.receiverTeamId,
      policyResult = policyResult,
    }
  end

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
    local rejected = tryRejectPolicy(ctx, resourceType)
    if rejected then return rejected end

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

return Gadgets
