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
}

---Generate base key for policy caching
---@param receiverId number
---@param resourceType ResourceType
---@return string
function Shared.MakeBaseKey(receiverId, resourceType)
  local transferCategory = resourceType == SharedEnums.ResourceType.METAL and SharedEnums.TransferCategory.MetalTransfer or
  SharedEnums.TransferCategory.EnergyTransfer
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
---@return ResourcePolicyResult
function Shared.CreateDenyPolicy(senderTeamId, receiverTeamId, resourceType)
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
    cumulativeSent = Shared.GetCumulativeSent(senderTeamId, resourceType)
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
---@return ResourcePolicyResult
function Shared.GetCachedPolicyResult(senderId, receiverId, resourceType)
  local baseKey = Shared.MakeBaseKey(receiverId, resourceType)
  local serialized = Spring.GetTeamRulesParam(senderId, baseKey)

  if serialized == nil then
    return Shared.CreateDenyPolicy(senderId, receiverId, resourceType)
  end

  if type(serialized) ~= "string" then
    serialized = tostring(serialized)
  end

  local result = Shared.DeserializePolicyResult(serialized, senderId, receiverId)
  result.senderTeamId = senderId
  result.receiverTeamId = receiverId
  return result
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

---@param teamId number
---@param resourceType ResourceType
---@return number
function Shared.GetCumulativeSent(teamId, resourceType)
  local param = Shared.GetCumulativeParam(resourceType)
  return tonumber(Spring.GetTeamRulesParam(teamId, param)) or 0
end

return Shared
