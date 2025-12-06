local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")

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

  EconomyLog.Transfer(
    ctx.senderTeamId,
    ctx.receiverTeamId,
    policyResult.resourceType,
    received,
    untaxed,
    received - untaxed
  )

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

-- Pooled result table for BuildResultFactory (reused to avoid GC pressure)
local policyResultPool = {}

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

    local taxedSendable = math.max(0, (senderBudget - untaxedPortion) * (1 - effectiveRate))
    local maxReceivable = math.max(0, receiverCapacity - untaxedPortion)
    local taxedPortion = math.min(taxedSendable, maxReceivable)

    local amountSendable = untaxedPortion + taxedPortion

    -- Reuse pooled table for result (keyed by resourceType to avoid conflicts within same pair)
    local result = policyResultPool[resourceType]
    if not result then
      result = {}
      policyResultPool[resourceType] = result
    end
    
    result.senderTeamId = ctx.senderTeamId
    result.receiverTeamId = ctx.receiverTeamId
    result.canShare = true
    result.amountSendable = amountSendable
    result.amountReceivable = receiverCapacity
    result.taxedPortion = taxedPortion
    result.untaxedPortion = untaxedPortion
    result.taxRate = effectiveRate
    result.resourceType = resourceType
    result.remainingTaxFreeAllowance = allowanceRemaining
    result.resourceShareThreshold = threshold
    result.cumulativeSent = cumulativeSent
    
    return result
  end
  return calcResourcePolicyResult
end

---@param ctx ResourceTransferContext
---@param transferResult ResourceTransferResult
function Gadgets.RegisterPostTransfer(ctx, transferResult)
  Gadgets.UpdateCumulativeSent(ctx.springRepo, transferResult.senderTeamId, ctx.resourceType, transferResult.sent)
end

---@param springApi ISpring
---@param teamId number
---@param resourceType ResourceType
---@param amountSent number
function Gadgets.UpdateCumulativeSent(springApi, teamId, resourceType, amountSent)
  local param = Shared.GetCumulativeParam(resourceType)
  local current = tonumber(springApi.GetTeamRulesParam(teamId, param)) or 0
  springApi.SetTeamRulesParam(teamId, param, current + amountSent)
end

---@param springRepo ISpring
---@param frame number
---@param lastUpdate number
---@param updateRate number
---@param contextFactory table
---@return number lastUpdate New last update frame
function Gadgets.UpdatePolicyCache(springRepo, frame, lastUpdate, updateRate, contextFactory)
  if frame < lastUpdate + updateRate then
    return lastUpdate
  end

  local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
  local resultFactory = Gadgets.BuildResultFactory(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY])
  
  local allTeams = springRepo.GetTeamList()
  for _, senderID in ipairs(allTeams) do
    for _, receiverID in ipairs(allTeams) do
      local ctx = contextFactory.policy(senderID, receiverID)
      
      local metalPolicy = resultFactory(ctx, ResourceType.METAL)
      Gadgets.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.METAL, metalPolicy)
      
      local energyPolicy = resultFactory(ctx, ResourceType.ENERGY)
      Gadgets.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.ENERGY, energyPolicy)
    end
  end
  return frame
end

---@param springRepo ISpring
---@param teamsList TeamResourceData[]
function Gadgets.WaterfillSolve(springRepo, teamsList)
  return WaterfillSolver.Solve(springRepo, teamsList)
end

---@param springRepo ISpring
---@param senderId number
---@param receiverId number
---@param resourceType ResourceType
---@param policyResult ResourcePolicyResult
function Gadgets.CachePolicyResult(springRepo, senderId, receiverId, resourceType, policyResult)
  local baseKey = Shared.MakeBaseKey(receiverId, resourceType)
  local serialized = Shared.SerializeResourcePolicyResult(policyResult)
  
  -- Optimization: Only write to engine if value changed
  -- GetTeamRulesParam is generally cheaper than SetTeamRulesParam (which triggers events)
  local current = springRepo.GetTeamRulesParam(senderId, baseKey)
  if current ~= serialized then
    springRepo.SetTeamRulesParam(senderId, baseKey, serialized)
  end
end

return Gadgets
