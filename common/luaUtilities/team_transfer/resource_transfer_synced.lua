local GlobalEnums = VFS.Include("modes/global_enums.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")

local ResourceType = GlobalEnums.ResourceType

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
---@param resourceType ResourceName
---@return ResourcePolicyResult|nil
local function TryDenyPolicy(ctx, resourceType)
  -- Globally disable any form of resource sharing if the modoption is turned off
  local modOpts = ctx.springRepo.GetModOptions()
  local resourceSharingEnabled = modOpts[GlobalEnums.ModOptions.ResourceSharingEnabled]
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
---@return fun(ctx: PolicyContext, resourceType: ResourceName) : ResourcePolicyResult
function Gadgets.BuildResultFactory(taxRate, metalThreshold, energyThreshold)
  ---@param resourceType ResourceName
  local function getThreshold(resourceType)
    if resourceType == GlobalEnums.ResourceType.METAL then
      return metalThreshold
    elseif resourceType == GlobalEnums.ResourceType.ENERGY then
      return energyThreshold
    end
  end

  ---@param ctx PolicyContext
  ---@param resourceType ResourceName
  ---@return ResourcePolicyResult
  local function calcResourcePolicyResult(ctx, resourceType)
    local rejected = TryDenyPolicy(ctx, resourceType)
    if rejected then return rejected end

    local senderData
    local receiverData
    if resourceType == GlobalEnums.ResourceType.METAL then
      senderData = ctx.sender.metal
      receiverData = ctx.receiver.metal
    elseif resourceType == GlobalEnums.ResourceType.ENERGY then
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
    result.canShare = receiverCapacity > 0 and amountSendable > 0
    result.amountSendable = amountSendable
    result.amountReceivable = receiverCapacity
    result.taxedPortion = taxedPortion
    result.untaxedPortion = untaxedPortion
    result.taxRate = effectiveRate
    result.resourceType = resourceType
    result.remainingTaxFreeAllowance = allowanceRemaining
    result.resourceShareThreshold = threshold
    result.cumulativeSent = cumulativeSent
    result.taxExcess = false
    
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
---@param resourceType ResourceName
---@param amountSent number
function Gadgets.UpdateCumulativeSent(springApi, teamId, resourceType, amountSent)
  local param = Shared.GetCumulativeParam(resourceType)
  local current = tonumber(springApi.GetTeamRulesParam(teamId, param)) or 0
  springApi.SetTeamRulesParam(teamId, param, current + amountSent)
end

-- Persistent state for staggered ally group updates
local allyGroupUpdateState = {
  allyGroups = {},       -- allyTeamId -> {teamId, teamId, ...}
  allyTeamIds = {},      -- ordered list of allyTeamIds
  nextGroupIndex = 1,    -- which group to update next (1-indexed)
  initialized = false,
}

local function rebuildAllyGroups(springRepo)
  local state = allyGroupUpdateState
  state.allyGroups = {}
  state.allyTeamIds = {}
  
  local allTeams = springRepo.GetTeamList()
  for _, teamId in ipairs(allTeams) do
    local allyTeamId = springRepo.GetTeamAllyTeamID(teamId)
    if not state.allyGroups[allyTeamId] then
      state.allyGroups[allyTeamId] = {}
      state.allyTeamIds[#state.allyTeamIds + 1] = allyTeamId
    end
    local group = state.allyGroups[allyTeamId]
    group[#group + 1] = teamId
  end
  
  state.initialized = true
  state.nextGroupIndex = 1
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

  local state = allyGroupUpdateState
  if not state.initialized then
    rebuildAllyGroups(springRepo)
  end
  
  local numGroups = #state.allyTeamIds
  if numGroups == 0 then
    return frame
  end
  
  local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
  local resultFactory = Gadgets.BuildResultFactory(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY])
  
  -- Process half the ally groups per frame (minimum 1)
  local groupsPerFrame = math.max(1, math.floor(numGroups / 2))
  local groupsProcessed = 0
  
  while groupsProcessed < groupsPerFrame do
    local allyTeamId = state.allyTeamIds[state.nextGroupIndex]
    local allyGroup = state.allyGroups[allyTeamId]
    
    -- Within this ally group: compute full policies (allies can share)
    for _, senderID in ipairs(allyGroup) do
      for _, receiverID in ipairs(allyGroup) do
        local ctx = contextFactory.policy(senderID, receiverID)
        
        local metalPolicy = resultFactory(ctx, ResourceType.METAL)
        Gadgets.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.METAL, metalPolicy)
        
        local energyPolicy = resultFactory(ctx, ResourceType.ENERGY)
        Gadgets.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.ENERGY, energyPolicy)
      end
      
      -- Cross-alliance: cache deny policies (cheap, no context building needed)
      for _, otherAllyTeamId in ipairs(state.allyTeamIds) do
        if otherAllyTeamId ~= allyTeamId then
          local enemyGroup = state.allyGroups[otherAllyTeamId]
          for _, receiverID in ipairs(enemyGroup) do
            local metalDeny = Shared.CreateDenyPolicy(senderID, receiverID, ResourceType.METAL, springRepo)
            Gadgets.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.METAL, metalDeny)
            
            local energyDeny = Shared.CreateDenyPolicy(senderID, receiverID, ResourceType.ENERGY, springRepo)
            Gadgets.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.ENERGY, energyDeny)
          end
        end
      end
    end
    
    state.nextGroupIndex = (state.nextGroupIndex % numGroups) + 1
    groupsProcessed = groupsProcessed + 1
  end
  
  return frame
end

function Gadgets.InvalidateAllyGroupCache()
  allyGroupUpdateState.initialized = false
end

---@param springRepo ISpring
---@param teamsList TeamResourceData[]
function Gadgets.WaterfillSolve(springRepo, teamsList)
  return WaterfillSolver.Solve(springRepo, teamsList)
end

---@param springRepo ISpring
---@param senderId number
---@param receiverId number
---@param resourceType ResourceName
---@param policyResult ResourcePolicyResult
function Gadgets.CachePolicyResult(springRepo, senderId, receiverId, resourceType, policyResult)
  local baseKey = Shared.MakeBaseKey(receiverId, resourceType)
  local serialized = Shared.SerializeResourcePolicyResult(policyResult)
  springRepo.SetTeamRulesParam(senderId, baseKey, serialized)
end

return Gadgets
