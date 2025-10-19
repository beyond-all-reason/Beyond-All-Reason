local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")

local Shared = {}

local FieldTypes = PolicyShared.FieldTypes
Shared.UnitPolicyFields = {
  canShare = FieldTypes.boolean,
  sharingMode = FieldTypes.string,
  allowTakeBypass = FieldTypes.boolean,
}


---Validate a list of unitIds under current mode
---Returns a structured result object designed for UI consumption.
---We don't make decisions here on how to display unit names etc, we just collate the data and let the UI decide.
---@param policyResult UnitPolicyResult -- note that policyResult is useless right now but is passed in for future use
---@param unitIds number[]
---@return UnitValidationResult
function Shared.ValidateUnits(policyResult, unitIds)
  local out = {
    status = SharedEnums.UnitValidationOutcome.Failure,
    validUnitCount = 0,
    validUnitNames = {},
    validUnitIds = {},
    invalidUnitCount = 0,
    invalidUnitNames = {},
    invalidUnitIds = {},
  }

  if (not policyResult.canShare) or (not unitIds or #unitIds == 0) then
    return out
  end

  local mode = policyResult.sharingMode
  local validUnitNamesSet = {}
  local invalidUnitNamesSet = {}
  for _, unitId in ipairs(unitIds) do
    local unitDefID = Spring.GetUnitDefID(unitId)
    if not unitDefID then
      Spring.Log("unit_transfer_shared", LOG.ERROR, "ValidateUnits: unitId", unitId, "not found")
      out.invalidUnitCount = out.invalidUnitCount + 1
      table.insert(out.invalidUnitIds, unitId)
      table.insert(out.invalidUnitNames, "Unknown Unit")
      return out
    else
      local ok = Shared.IsShareableDef(unitDefID, mode)
      local unitName = UnitDefs[unitDefID] and (UnitDefs[unitDefID].translatedHumanName or UnitDefs[unitDefID].name)

      if ok then
        out.validUnitCount = out.validUnitCount + 1
        table.insert(out.validUnitIds, unitId)
        if not validUnitNamesSet[unitName] then
          validUnitNamesSet[unitName] = true
          table.insert(out.validUnitNames, unitName)
        end
      else
        out.invalidUnitCount = out.invalidUnitCount + 1
        table.insert(out.invalidUnitIds, unitId)
        if not invalidUnitNamesSet[unitName] then
          invalidUnitNamesSet[unitName] = true
          table.insert(out.invalidUnitNames, unitName)
        end
      end
    end
  end

  if out.validUnitCount > 0 and out.invalidUnitCount == 0 then
    out.status = SharedEnums.UnitValidationOutcome.Success
  elseif out.validUnitCount > 0 and out.invalidUnitCount > 0 then
    out.status = SharedEnums.UnitValidationOutcome.PartialSuccess
  else
    out.status = SharedEnums.UnitValidationOutcome.Failure
  end

  return out
end

---UI getter for per-pair policy expose from cache
---@param senderTeamId number
---@param receiverTeamId number
---@return UnitPolicyResult
function Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId)
  local baseKey = PolicyShared.MakeBaseKey(receiverTeamId, SharedEnums.TransferCategory.UnitTransfer)
  local serialized = Spring.GetTeamRulesParam(senderTeamId, baseKey)
  if serialized == nil then
    -- default to deny
    ---@type UnitPolicyResult
    return {
      senderTeamId = senderTeamId,
      receiverTeamId = receiverTeamId,
      canShare = false,
      sharingMode = SharedEnums.UnitSharingMode.Disabled,
      allowTakeBypass = false
    }
  end

  if type(serialized) ~= "string" then
    serialized = tostring(serialized)
  end

  return Shared.DeserializePolicy(serialized, senderTeamId, receiverTeamId)
end

---Serialize unit policy expose to compact string
---@param policy table
---@return string
function Shared.SerializePolicy(policy)
  return PolicyShared.Serialize(Shared.UnitPolicyFields, policy)
end

---Deserialize unit policy expose from string
---@param serialized string
---@param senderId number
---@param receiverId number
---@return UnitPolicyResult
function Shared.DeserializePolicy(serialized, senderId, receiverId)
  return PolicyShared.Deserialize(Shared.UnitPolicyFields, serialized, {
    senderTeamId = senderId,
    receiverTeamId = receiverId,
  })
end

---Get globals published by the module
---@param unitDef table
---@param mode string
---@return boolean
local function EvaluateUnitForSharing(unitDef, mode)
  if not unitDef then return false end

  -- Simple cases
  if mode == SharedEnums.UnitSharingMode.Disabled then
    return false
  end

  if mode == SharedEnums.UnitSharingMode.Enabled then
    return true
  end

  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)

  if mode == SharedEnums.UnitSharingMode.CombatUnits then
    return unitType == SharedEnums.UnitType.Combat
  end

  if mode == SharedEnums.UnitSharingMode.Economic then
    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor
  end

  if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor or
    unitType == SharedEnums.UnitType.Utility
  end

  if mode == SharedEnums.UnitSharingMode.T2Cons then
    return unitType == SharedEnums.UnitType.T2Constructor
  end

  if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
    return unitType == SharedEnums.UnitType.Combat or unitType == SharedEnums.UnitType.T2Constructor
  end

  Spring.Log("unit_transfer_shared", LOG.ERROR, "EvaluateUnitForSharing: unknown mode =", mode)
  return false
end

-- Allowed UnitDefID cache per mode for fast validation
local allowedByMode = {}

local function BuildAllowedCacheForMode(mode)
  if allowedByMode[mode] then return end
  local cache = {}
  for unitDefID, unitDef in pairs(UnitDefs) do
    if EvaluateUnitForSharing(unitDef, mode) then
      cache[unitDefID] = true
    end
  end
  allowedByMode[mode] = cache
end

function Shared.IsShareableDef(unitDefId, mode)
  if not unitDefId or not mode then return false end
  BuildAllowedCacheForMode(mode)
  return allowedByMode[mode][unitDefId] == true
end

return Shared
