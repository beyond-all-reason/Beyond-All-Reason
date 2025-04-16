local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

local Shared = {}

local FieldTypes = {
  string = "string",
  boolean = "boolean",
  number = "number",
}

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
  return string.format("policy_cache_%d_%s_", receiverId, resourceType)
end

---Serialize ResourcePolicyResult to string for efficient storage
---@param policyResult table
---@return string
function Shared.SerializePolicyResult(policyResult)
  -- Simple serialization: field1:value1:field2:value2:...
  -- Exclude senderTeamId and receiverTeamId as they're set by the cache key
  local parts = {}
  for field, fieldType in pairs(Shared.ResourcePolicyFields) do
    local v = policyResult[field]
    if v ~= nil then
      if fieldType == FieldTypes.boolean then
        v = v and "1" or "0"
      elseif fieldType == FieldTypes.string then
        v = v         -- strings are fine
      else
        v = tostring(v)
      end
      table.insert(parts, field)
      table.insert(parts, v)
    end
  end
  return table.concat(parts, ":")
end

---Deserialize ResourcePolicyResult from string
---@param serialized string
---@param resourceType ResourceType
---@return ResourcePolicyResult
function Shared.DeserializeResourcePolicyResult(serialized, resourceType)
  local result = {}
  local parts = {}
  for part in string.gmatch(serialized, "([^:]+)") do
    table.insert(parts, part)
  end
  for i = 1, #parts, 2 do
    local key = parts[i]
    local value = parts[i + 1]
    if key and value then
      local fieldType = Shared.ResourcePolicyFields[key]
      if key == "resourceType" then
        result[key] = resourceType
      elseif fieldType == FieldTypes.boolean then
        result[key] = value == "1"
      elseif fieldType == FieldTypes.string then
        result[key] = value
      elseif fieldType == FieldTypes.number then
        result[key] = tonumber(value) or 0
      else
        error("Unknown field type: " .. tostring(fieldType))
      end
    end
  end
  return result
end

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
    ---@type ResourcePolicyResult
    local result = {
      senderTeamId = senderId,
      receiverTeamId = receiverId,
      canShare = false,
      amountSendable = 0,
      amountReceivable = 0,
      taxedPortion = 0,
      untaxedPortion = 0,
      taxRate = 0,
      resourceType = resourceType,
      remainingTaxFreeAllowance = 0,
      resourceShareThreshold = 0,
      cumulativeSent = 0,
    }
    return result
  end

  if type(serialized) ~= "string" then
    serialized = tostring(serialized)
  end

  local result = Shared.DeserializeResourcePolicyResult(serialized, resourceType)
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

--- Determine communication case from parameters
---@param senderTeamId number
---@param receiverTeamId number
---@param taxRate number
---@param resourceShareThreshold number
---@return integer
function Shared.DecideCommunicationCaseFromParams(senderTeamId, receiverTeamId, taxRate, resourceShareThreshold)
  if senderTeamId == receiverTeamId then
    return SharedEnums.ResourceCommunicationCase.OnSelf
  end
  if taxRate <= 0 then
    return SharedEnums.ResourceCommunicationCase.OnTaxFree
  end
  if resourceShareThreshold > 0 then
    return SharedEnums.ResourceCommunicationCase.OnTaxedThreshold
  end
  return SharedEnums.ResourceCommunicationCase.OnTaxed
end

--- Determine communication case from policy result
---@param policyResult ResourcePolicyResult
---@return integer
function Shared.DecideCommunicationCase(policyResult)
  return Shared.DecideCommunicationCaseFromParams(
    policyResult.senderTeamId,
    policyResult.receiverTeamId,
    policyResult.taxRate,
    policyResult.resourceShareThreshold
  )
end

return Shared
