local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")

local Shared = {}

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

--- Core helper: compute sender cost for a desired received amount under policyResult
---@param policyResult ResourcePolicyResult
---@param desiredReceived number
---@return number receivedAmount, number sentAmount, number untaxedPortion
function Shared.CalculateSenderTaxedAmount(policyResult, desiredReceived)
  local maxReceivable = policyResult.amountReceivable
  local desired = math.min(desiredReceived, policyResult.amountSendable, maxReceivable)
  if desired <= 0 then
    return 0, 0, 0
  end

  local untaxed = math.min(desired, policyResult.untaxedPortion)
  local taxed = desired - untaxed
  local r = policyResult.taxRate

  local received
  local sent
  if taxed > 0 then
    if r >= 1.0 then
      -- 100% tax means taxed portion cannot be sent (infinite cost)
      sent = untaxed
      received = untaxed       -- only untaxed portion reaches receiver
    else
      sent = untaxed + (taxed / (1 - r))
      received = desired       -- all desired amount reaches receiver
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
    return Shared.CreateDenyPolicy(senderId, receiverId, resourceType, 0)
  end

  if type(serialized) ~= "string" then
    serialized = tostring(serialized)
  end

  local result = Shared.DeserializePolicyResult(serialized, senderId, receiverId)
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

---Generate base key for policy caching
---@param receiverId number
---@param resourceType ResourceType
---@return string
function Shared.MakeBaseKey(receiverId, resourceType)
  local transferCategory = resourceType == SharedEnums.ResourceType.METAL and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
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

---Create a default deny ResourcePolicyResult
---@param senderTeamId number
---@param receiverTeamId number
---@param resourceType ResourceType
---@param cumulativeSent number?
---@return ResourcePolicyResult
function Shared.CreateDenyPolicy(senderTeamId, receiverTeamId, resourceType, cumulativeSent)
  return {
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
    cumulativeSent = cumulativeSent or 0,
  }
end

return Shared
