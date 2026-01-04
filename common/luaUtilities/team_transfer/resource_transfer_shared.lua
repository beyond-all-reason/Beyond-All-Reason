local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")

local Shared = Comms

local FieldTypes = PolicyShared.FieldTypes

-- Field type definitions for serialization/deserialization
Shared.ResourcePolicyFields = {
  resourceType = FieldTypes.string,
  canShare = FieldTypes.boolean,
  amountSendable = FieldTypes.number,
  amountReceivable = FieldTypes.number,
  taxedPortion = FieldTypes.number,
  untaxedPortion = FieldTypes.number,
  taxRate = FieldTypes.number,
  remainingTaxFreeAllowance = FieldTypes.number,
  resourceShareThreshold = FieldTypes.number,
  cumulativeSent = FieldTypes.number,
  taxExcess = FieldTypes.boolean,
}

-- Lua table cache for policies (replaces TeamRulesParam serialization)
-- Structure: policyCache[senderTeamId][receiverTeamId][resourceType] = PolicyResult
local policyCache = {}

-- Shared deny policy singletons for non-allied pairs (no table creation per lookup)
local DENY_SINGLETON = {
  [SharedEnums.ResourceType.METAL] = {
    canShare = false,
    amountSendable = 0,
    amountReceivable = 0,
    taxedPortion = 0,
    untaxedPortion = 0,
    taxRate = 0,
    resourceType = SharedEnums.ResourceType.METAL,
    remainingTaxFreeAllowance = 0,
    resourceShareThreshold = 0,
    cumulativeSent = 0,
    taxExcess = false,
  },
  [SharedEnums.ResourceType.ENERGY] = {
    canShare = false,
    amountSendable = 0,
    amountReceivable = 0,
    taxedPortion = 0,
    untaxedPortion = 0,
    taxRate = 0,
    resourceType = SharedEnums.ResourceType.ENERGY,
    remainingTaxFreeAllowance = 0,
    resourceShareThreshold = 0,
    cumulativeSent = 0,
    taxExcess = false,
  },
}

---Generate base key for policy caching
---@param receiverId number
---@param resourceType ResourceType
---@return string
function Shared.MakeBaseKey(receiverId, resourceType)
  local transferCategory = resourceType == SharedEnums.ResourceType.METAL and SharedEnums.PolicyType.MetalTransfer or
  SharedEnums.PolicyType.EnergyTransfer
  return PolicyShared.MakeBaseKey(receiverId, transferCategory)
end

---Serialize ResourcePolicyResult to string for efficient storage
---@param policyResult table
---@return string
function Shared.SerializeResourcePolicyResult(policyResult)
  return PolicyShared.Serialize(Shared.ResourcePolicyFields, policyResult)
end

---Deserialize ResourcePolicyResult from string
---@param serialized string
---@param senderTeamId number
---@param receiverTeamId number
---@return ResourcePolicyResult
function Shared.DeserializePolicyResult(serialized, senderTeamId, receiverTeamId)
  return PolicyShared.Deserialize(Shared.ResourcePolicyFields, serialized, {
    senderTeamId = senderTeamId,
    receiverTeamId = receiverTeamId,
  })
end

---@param senderTeamId number
---@param receiverTeamId number
---@param resourceType ResourceType
---@param springApi ISpring?
---@return ResourcePolicyResult
function Shared.CreateDenyPolicy(senderTeamId, receiverTeamId, resourceType, springApi)
  ---@type ResourcePolicyResult
  local result = {
    senderTeamId = senderTeamId,
    receiverTeamId = receiverTeamId,
    canShare = false,
    amountSendable = 0,
    amountReceivable = 0,
    taxedPortion = 0,
    untaxedPortion = 0,
    taxRate = 0,
    resourceType = resourceType,
    remainingTaxFreeAllowance = 0,
    resourceShareThreshold = 0,
    cumulativeSent = Shared.GetCumulativeSent(senderTeamId, resourceType, springApi),
    taxExcess = false,
  }
  return result
end

---@param policyResult ResourcePolicyResult
---@param desired number
---@return number received, number sent, number untaxed
function Shared.CalculateSenderTaxedAmount(policyResult, desired)
  local untaxed = math.min(desired, policyResult.untaxedPortion)
  local taxed = desired - untaxed
  local r = policyResult.taxRate

  local received
  local sent
  if taxed > 0 then
    if r >= 1.0 then
      -- 100% tax means taxed portion cannot be sent (infinite cost)
      sent = untaxed
      received = untaxed -- only untaxed portion reaches receiver
    else
      sent = untaxed + (taxed / (1 - r))
      received = desired -- all desired amount reaches receiver
    end
  else
    sent = untaxed
    received = untaxed
  end

  return received, sent, untaxed
end

---@param senderId number
---@param receiverId number
---@param resourceType ResourceType
---@param springApi ISpring?
---@return ResourcePolicyResult
function Shared.GetCachedPolicyResult(senderId, receiverId, resourceType, springApi)
  local spring = springApi or Spring
  
  -- Fast path: non-allied pairs return shared deny singleton
  if not spring.AreTeamsAllied(senderId, receiverId) then
    local singleton = DENY_SINGLETON[resourceType]
    singleton.senderTeamId = senderId
    singleton.receiverTeamId = receiverId
    return singleton
  end
  
  -- Allied pairs: check Lua table cache
  local senderCache = policyCache[senderId]
  if senderCache then
    local receiverCache = senderCache[receiverId]
    if receiverCache and receiverCache[resourceType] then
      return receiverCache[resourceType]
    end
  end
  
  -- Cache miss - return deny policy (caller should populate cache)
  return Shared.CreateDenyPolicy(senderId, receiverId, resourceType, springApi)
end

---Cache a policy result in the Lua table cache
---@param senderId number
---@param receiverId number
---@param resourceType ResourceType
---@param policyResult ResourcePolicyResult
---@param springApi ISpring?
function Shared.CachePolicyResult(senderId, receiverId, resourceType, policyResult, springApi)
  local spring = springApi or Spring
  
  -- Only cache allied pairs (non-allied use singleton)
  if not spring.AreTeamsAllied(senderId, receiverId) then
    return
  end
  
  policyCache[senderId] = policyCache[senderId] or {}
  policyCache[senderId][receiverId] = policyCache[senderId][receiverId] or {}
  policyCache[senderId][receiverId][resourceType] = policyResult
end

---Invalidate policy cache entries
---@param senderId number? If nil, invalidates all senders
---@param receiverId number? If nil, invalidates all receivers for sender
function Shared.InvalidatePolicyCache(senderId, receiverId)
  if senderId and receiverId then
    if policyCache[senderId] then
      policyCache[senderId][receiverId] = nil
    end
  elseif senderId then
    policyCache[senderId] = nil
  else
    policyCache = {}
  end
end

---@param resourceType ResourceType
---@return string
function Shared.GetCumulativeParam(resourceType)
  if resourceType == SharedEnums.ResourceType.METAL then
    return "metal_share_cumulative_sent"
  else
    return "energy_share_cumulative_sent"
  end
end

---Get param key for passive (waterfill) cumulative tracking - separate from manual transfers
---@param resourceType ResourceType
---@return string
function Shared.GetPassiveCumulativeParam(resourceType)
  if resourceType == SharedEnums.ResourceType.METAL then
    return "passive_cumulative_sent_metal"
  else
    return "passive_cumulative_sent_energy"
  end
end

---@param teamId number
---@param resourceType ResourceType
---@param springRepo ISpring?
---@return number
function Shared.GetCumulativeSent(teamId, resourceType, springRepo)
  local param = Shared.GetCumulativeParam(resourceType)
  local spring = springRepo or Spring
  local value = spring.GetTeamRulesParam(teamId, param)
  if value == nil then
    return 0
  end
  return tonumber(value) or 0
end

return Shared
