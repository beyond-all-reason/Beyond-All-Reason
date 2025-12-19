local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/bar_economy_waterfill_solver.lua")

local ResourceType = SharedEnums.ResourceType

local Gadgets = {
  SendTransferChatMessages = Comms.SendTransferChatMessages,
}
Gadgets.__index = Gadgets

local RESOURCE_NAME_TO_TYPE = {
  [ResourceType.METAL] = ResourceType.METAL,
  [ResourceType.ENERGY] = ResourceType.ENERGY,
  metal = ResourceType.METAL,
  m = ResourceType.METAL,
  e = ResourceType.ENERGY,
  energy = ResourceType.ENERGY,
}

local STORAGE_NAME_TO_TYPE = {
  ms = ResourceType.METAL,
  metalStorage = ResourceType.METAL,
  es = ResourceType.ENERGY,
  energyStorage = ResourceType.ENERGY,
}

local function ResolveResource(resource)
  if resource == nil then
    error("resource identifier is required", 3)
  end

  local storageType = STORAGE_NAME_TO_TYPE[resource]
  if storageType then
    return storageType, true
  end

  local resolved = RESOURCE_NAME_TO_TYPE[resource]
  if resolved then
    return resolved, false
  end

  error(("unsupported resource identifier '%s'"):format(tostring(resource)), 3)
end

local function EnsureResourceType(resource)
  local resolved, isStorage = ResolveResource(resource)
  if isStorage then
    error("resource identifier requires a resource type (metal or energy)", 3)
  end
  return resolved
end

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

-- Encapsulate legacy AllowResourceTransfer gate rules
---@param ctx PolicyContext
---@param resourceType ResourceType
---@return ResourcePolicyResult|nil
local function TryDenyPolicy(ctx, resourceType)
  -- Globally disable any form of resource sharing if the modoption is turned off
  local modOpts = ctx.springRepo.GetModOptions()
  local resourceSharingEnabled = modOpts[SharedEnums.ModOptions.ResourceSharingEnabled]
  if resourceSharingEnabled == false then
    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
  end

  if ctx.isCheatingEnabled then
    return nil
  end

  if not ctx.areAlliedTeams and not isNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
  end

  local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
  if numActivePlayers ~= nil and tonumber(numActivePlayers) == 0 then
    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
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
    local rejected = TryDenyPolicy(ctx, resourceType)
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

    local cumulativeSent = Shared.GetCumulativeSent(ctx.senderTeamId, resourceType, ctx.springRepo)
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
      cumulativeSent = cumulativeSent
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
---@param teamsList TeamResourceData[]
---@param frame number?
function Gadgets.ProcessEconomy(springRepo, teamsList, frame)
  return WaterfillSolver.ProcessEconomy(springRepo, teamsList, frame)
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
