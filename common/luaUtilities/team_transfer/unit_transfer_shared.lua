local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_serialization_helpers.lua")
local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")

local Shared = Comms

local FieldTypes = PolicyShared.FieldTypes
Shared.UnitPolicyFields = {
  canShare = FieldTypes.boolean,
  sharingModes = FieldTypes.string,
}

---Validate a list of unitIds under current mode
---Returns a structured result object designed for UI consumption.
---We don't make decisions here on how to display unit names etc, we just collate the data and let the UI decide.
---@param policyResult UnitPolicyResult -- note that policyResult is useless right now but is passed in for future use
---@param unitDefID number
---@param stunCategory string
---@param defs table
---@return boolean
local function wouldBeStunned(unitDefID, stunCategory, defs)
  if not stunCategory then
    return false
  end
  return Shared.IsShareableDef(unitDefID, stunCategory, defs)
end

---@param unitIds number[]
---@param springApi SpringSynced?
---@param unitDefs table?
---@return UnitValidationResult
function Shared.ValidateUnits(policyResult, unitIds, springApi, unitDefs)
  local spring = springApi or Spring
  local defs = unitDefs or UnitDefs or (spring.GetUnitDefs and spring.GetUnitDefs()) or {}
  local out = {
    status = TransferEnums.UnitValidationOutcome.Failure,
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

  local modes = policyResult.sharingModes or {"none"}
  local stunSeconds = tonumber(policyResult.stunSeconds) or 0
  local stunCategory = policyResult.stunCategory
  
  local validUnitNamesSet = {}
  local invalidUnitNamesSet = {}
  for _, unitId in ipairs(unitIds) do
    local unitDefID = spring.GetUnitDefID(unitId)
    if not unitDefID then
      spring.Log("unit_transfer_shared", tostring(LOG.ERROR), string.format("ValidateUnits: unitId %d not found", unitId))
      out.invalidUnitCount = out.invalidUnitCount + 1
      table.insert(out.invalidUnitIds, unitId)
      table.insert(out.invalidUnitNames, "Unknown Unit")
      return out
    else
      local ok = Shared.IsShareableDef(unitDefID, modes, defs)
      local def = defs[unitDefID] or defs[tostring(unitDefID)]
      local unitName = (def and (def.translatedHumanName or def.name)) or tostring(unitDefID)
      
      -- Block nanoframes for units that would be stunned (prevents tax bypass)
      if ok and stunSeconds > 0 and wouldBeStunned(unitDefID, stunCategory, defs) then
        local beingBuilt, buildProgress = spring.GetUnitIsBeingBuilt(unitId)
        if beingBuilt and buildProgress > 0 then
          ok = false -- Nanoframe transfer blocked for stun-category units
        end
      end
      
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
    out.status = TransferEnums.UnitValidationOutcome.Success
  elseif out.validUnitCount > 0 and out.invalidUnitCount > 0 then
    out.status = TransferEnums.UnitValidationOutcome.PartialSuccess
  else
    out.status = TransferEnums.UnitValidationOutcome.Failure
  end

  return out
end

---UI getter for per-pair policy expose from cache
---@param senderTeamId number
---@param receiverTeamId number
---@param springApi SpringSynced?
---@return UnitPolicyResult
function Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId, springApi)
  local spring = springApi or Spring
  local baseKey = PolicyShared.MakeBaseKey(receiverTeamId, TransferEnums.TransferCategory.UnitTransfer)
  local serialized = spring.GetTeamRulesParam(senderTeamId, baseKey)
  
  -- Always get stun config from mod options (not cached)
  local modOptions = spring.GetModOptions()
  local stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0
  local stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource
  
  if serialized == nil then
    local category = modOptions.unit_sharing_mode or ModeEnums.UnitFilterCategory.None
    local modes = { category }
    local areAllied = spring.AreTeamsAllied and spring.AreTeamsAllied(senderTeamId, receiverTeamId)
    local canShare = areAllied and category ~= ModeEnums.UnitFilterCategory.None
    ---@type UnitPolicyResult
    return {
      senderTeamId = senderTeamId,
      receiverTeamId = receiverTeamId,
      canShare = canShare,
      sharingModes = modes,
      stunSeconds = stunSeconds,
      stunCategory = stunCategory,
    }
  end
  
  local policy = Shared.DeserializePolicy(serialized, senderTeamId, receiverTeamId)
  -- Ensure stun fields are always present from mod options
  policy.stunSeconds = stunSeconds
  policy.stunCategory = stunCategory
  return policy
end

---Serialize unit policy expose to compact string
---@param policy table
---@return string
function Shared.SerializePolicy(policy)
  local flat = {
    canShare = policy.canShare,
    sharingModes = table.concat(policy.sharingModes or {"none"}, ","),
  }
  return PolicyShared.Serialize(Shared.UnitPolicyFields, flat)
end

---@param serialized string
---@param senderId number
---@param receiverId number
---@return UnitPolicyResult
function Shared.DeserializePolicy(serialized, senderId, receiverId)
  local result = PolicyShared.Deserialize(Shared.UnitPolicyFields, serialized, {
    senderTeamId = senderId,
    receiverTeamId = receiverId,
  })
  local modesStr = result.sharingModes or "none"
  local modes = {}
  for m in modesStr:gmatch("[^,]+") do
    modes[#modes + 1] = m
  end
  result.sharingModes = modes
  return result
end

local Commander = TransferEnums.UnitType.Commander

local allUnitTypes = {
  TransferEnums.UnitType.Combat,
  TransferEnums.UnitType.Commander,
  TransferEnums.UnitType.Production,
  TransferEnums.UnitType.T2Constructor,
  TransferEnums.UnitType.Resource,
  TransferEnums.UnitType.Utility,
  TransferEnums.UnitType.Transport,
}

function Shared.GetModeUnitTypes(category)
  if category == ModeEnums.UnitFilterCategory.None then
    return {}
  end

  if category == ModeEnums.UnitFilterCategory.All then
    return allUnitTypes
  end

  -- Commanders are always shareable regardless of category
  if category == ModeEnums.UnitFilterCategory.Combat then
    return {TransferEnums.UnitType.Combat, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.CombatT2Cons then
    return {TransferEnums.UnitType.Combat, TransferEnums.UnitType.T2Constructor, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.Production then
    return {TransferEnums.UnitType.Production, TransferEnums.UnitType.T2Constructor, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.ProductionResource then
    return {TransferEnums.UnitType.Production, TransferEnums.UnitType.T2Constructor, TransferEnums.UnitType.Resource, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.ProductionResourceUtility then
    return {TransferEnums.UnitType.Production, TransferEnums.UnitType.T2Constructor, TransferEnums.UnitType.Resource, TransferEnums.UnitType.Utility, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.ProductionUtility then
    return {TransferEnums.UnitType.Production, TransferEnums.UnitType.T2Constructor, TransferEnums.UnitType.Utility, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.Resource then
    return {TransferEnums.UnitType.Resource, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.T2Cons then
    return {TransferEnums.UnitType.T2Constructor, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.Transport then
    return {TransferEnums.UnitType.Transport, Commander}
  end

  if category == ModeEnums.UnitFilterCategory.Utility then
    return {TransferEnums.UnitType.Utility, Commander}
  end

  return {}
end

local function UnitTypeMatchesCategory(unitDef, category)
  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
  local categoryUnitTypes = Shared.GetModeUnitTypes(category)
  return table.contains(categoryUnitTypes, unitType)
end

---@param unitDef table
---@param category string
---@return boolean
local function EvaluateUnitForSharing(unitDef, category)
  if not unitDef then return false end

  if category == ModeEnums.UnitFilterCategory.None then
    return false
  end

  if category == ModeEnums.UnitFilterCategory.All then
    return true
  end

  return UnitTypeMatchesCategory(unitDef, category)
end

local allowedByCategory = setmetatable({}, { __mode = "k" })

local function BuildAllowedCacheForCategory(category, unitDefs)
  local defs = unitDefs or UnitDefs
  if not defs then return nil end
  local cacheByDefs = allowedByCategory[defs]
  if not cacheByDefs then
    cacheByDefs = {}
    allowedByCategory[defs] = cacheByDefs
  end
  if cacheByDefs[category] then
    return cacheByDefs[category]
  end
  local cache = {}
  for unitDefID, unitDef in pairs(defs) do
    if EvaluateUnitForSharing(unitDef, category) then
      cache[unitDefID] = true
    end
  end
  cacheByDefs[category] = cache
  return cache
end

---@param unitDefId number
---@param categories string|string[]
---@param unitDefs table?
---@return boolean
function Shared.IsShareableDef(unitDefId, categories, unitDefs)
  if not unitDefId or not categories then return false end
  if type(categories) == "string" then categories = {categories} end
  for _, category in ipairs(categories) do
    if category == ModeEnums.UnitFilterCategory.All then return true end
    local cache = BuildAllowedCacheForCategory(category, unitDefs)
    if cache and cache[unitDefId] then return true end
  end
  return false
end

return Shared
