local GlobalEnums = VFS.Include("modes/global_enums.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_serialization_helpers.lua")
local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")

local Shared = Comms

local FieldTypes = PolicyShared.FieldTypes
Shared.UnitPolicyFields = {
  canShare = FieldTypes.boolean,
  sharingMode = FieldTypes.string,
}

---Validate a list of unitIds under current mode
---Returns a structured result object designed for UI consumption.
---We don't make decisions here on how to display unit names etc, we just collate the data and let the UI decide.
---@param policyResult UnitPolicyResult -- note that policyResult is useless right now but is passed in for future use
---Map stun category to equivalent sharing mode for unit type lookup
---@param stunCategory string
---@return string|nil Equivalent UnitSharingMode
local function stunCategoryToMode(stunCategory)
  if stunCategory == GlobalEnums.UnitStunCategory.Combat then
    return GlobalEnums.UnitSharingMode.CombatUnits
  elseif stunCategory == GlobalEnums.UnitStunCategory.CombatT2Cons then
    return GlobalEnums.UnitSharingMode.CombatT2Cons
  elseif stunCategory == GlobalEnums.UnitStunCategory.Economic then
    return GlobalEnums.UnitSharingMode.Economic
  elseif stunCategory == GlobalEnums.UnitStunCategory.EconomicPlusBuildings then
    return GlobalEnums.UnitSharingMode.EconomicPlusBuildings
  elseif stunCategory == GlobalEnums.UnitStunCategory.T2Cons then
    return GlobalEnums.UnitSharingMode.T2Cons
  elseif stunCategory == GlobalEnums.UnitStunCategory.All then
    return GlobalEnums.UnitSharingMode.Enabled
  end
  return nil
end

---Check if a unit should be stunned based on the stun category
---@param unitDefID number
---@param stunCategory string
---@param defs table
---@return boolean
local function wouldBeStunned(unitDefID, stunCategory, defs)
  if not stunCategory then
    return false
  end
  
  local equivalentMode = stunCategoryToMode(stunCategory)
  if not equivalentMode then
    return false
  end
  
  return Shared.IsShareableDef(unitDefID, equivalentMode, defs)
end

---@param unitIds number[]
---@param springApi ISpring?
---@param unitDefs table?
---@return UnitValidationResult
function Shared.ValidateUnits(policyResult, unitIds, springApi, unitDefs)
  local spring = springApi or Spring
  local defs = unitDefs or UnitDefs or (spring.GetUnitDefs and spring.GetUnitDefs()) or {}
  local out = {
    status = GlobalEnums.UnitValidationOutcome.Failure,
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
      local ok = Shared.IsShareableDef(unitDefID, mode, defs)
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
    out.status = GlobalEnums.UnitValidationOutcome.Success
  elseif out.validUnitCount > 0 and out.invalidUnitCount > 0 then
    out.status = GlobalEnums.UnitValidationOutcome.PartialSuccess
  else
    out.status = GlobalEnums.UnitValidationOutcome.Failure
  end

  return out
end

---UI getter for per-pair policy expose from cache
---@param senderTeamId number
---@param receiverTeamId number
---@param springApi ISpring?
---@return UnitPolicyResult
function Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId, springApi)
  local spring = springApi or Spring
  local baseKey = PolicyShared.MakeBaseKey(receiverTeamId, GlobalEnums.TransferCategory.UnitTransfer)
  local serialized = spring.GetTeamRulesParam(senderTeamId, baseKey)
  
  -- Always get stun config from mod options (not cached)
  local modOptions = spring.GetModOptions()
  local stunSeconds = tonumber(modOptions[GlobalEnums.ModOptions.UnitShareStunSeconds]) or 0
  local stunCategory = modOptions[GlobalEnums.ModOptions.UnitStunCategory] or GlobalEnums.UnitStunCategory.EconomicPlusBuildings
  
  if serialized == nil then
    -- No cache - build default policy from mod options
    local mode = modOptions.unit_sharing_mode or GlobalEnums.UnitSharingMode.Disabled
    local areAllied = spring.AreTeamsAllied and spring.AreTeamsAllied(senderTeamId, receiverTeamId)
    local canShare = areAllied and mode ~= GlobalEnums.UnitSharingMode.Disabled
    ---@type UnitPolicyResult
    return {
      senderTeamId = senderTeamId,
      receiverTeamId = receiverTeamId,
      canShare = canShare,
      sharingMode = mode,
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

function Shared.GetModeUnitTypes(mode)
  if mode == GlobalEnums.UnitSharingMode.Disabled then
    return {}
  end

  if mode == GlobalEnums.UnitSharingMode.Enabled then
    return {
      GlobalEnums.UnitType.Combat,
      GlobalEnums.UnitType.Economic,
      GlobalEnums.UnitType.Utility,
      GlobalEnums.UnitType.T2Constructor
    }
  end

  if mode == GlobalEnums.UnitSharingMode.CombatUnits then
    return {GlobalEnums.UnitType.Combat}
  end

  if mode == GlobalEnums.UnitSharingMode.Economic then
    return {GlobalEnums.UnitType.Economic, GlobalEnums.UnitType.T2Constructor}
  end

  if mode == GlobalEnums.UnitSharingMode.EconomicPlusBuildings then
    return {GlobalEnums.UnitType.Economic, GlobalEnums.UnitType.T2Constructor, GlobalEnums.UnitType.Utility}
  end

  if mode == GlobalEnums.UnitSharingMode.T2Cons then
    return {GlobalEnums.UnitType.T2Constructor}
  end

  if mode == GlobalEnums.UnitSharingMode.CombatT2Cons then
    return {GlobalEnums.UnitType.Combat, GlobalEnums.UnitType.T2Constructor}
  end

  error("Unknown mode: " .. mode)
end

local function UnitTypeMatchesMode(unitDef, mode)
  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
  local modeUnitTypes = Shared.GetModeUnitTypes(mode)
  return table.contains(modeUnitTypes, unitType)
end


---Get globals published by the module
---@param unitDef table
---@param mode string
---@return boolean
local function EvaluateUnitForSharing(unitDef, mode)
  if not unitDef then return false end

  -- Simple cases
  if mode == GlobalEnums.UnitSharingMode.Disabled then
    return false
  end

  if mode == GlobalEnums.UnitSharingMode.Enabled then
    return true
  end

  return UnitTypeMatchesMode(unitDef, mode)
end

-- Allowed UnitDefID cache per mode for fast validation
local allowedByMode = setmetatable({}, { __mode = "k" })

local function BuildAllowedCacheForMode(mode, unitDefs)
  local defs = unitDefs or UnitDefs
  if not defs then return nil end
  local cacheByDefs = allowedByMode[defs]
  if not cacheByDefs then
    cacheByDefs = {}
    allowedByMode[defs] = cacheByDefs
  end
  if cacheByDefs[mode] then
    return cacheByDefs[mode]
  end
  local cache = {}
  for unitDefID, unitDef in pairs(defs) do
    local ok = EvaluateUnitForSharing(unitDef, mode)
    if ok then
      cache[unitDefID] = true
    end
  end
  cacheByDefs[mode] = cache
  return cache
end

function Shared.IsShareableDef(unitDefId, mode, unitDefs)
  if not unitDefId or not mode then return false end
  local cache = BuildAllowedCacheForMode(mode, unitDefs)
  if not cache then return false end
  return cache[unitDefId] == true
end

return Shared
