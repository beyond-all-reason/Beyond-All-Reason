local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")

local Shared = Comms

local FieldTypes = PolicyShared.FieldTypes
Shared.UnitPolicyFields = {
  canShare = FieldTypes.boolean,
  sharingMode = FieldTypes.string,
}

-- Lua table cache for unit policies (replaces TeamRulesParam serialization)
-- Structure: policyCache[senderTeamId][receiverTeamId] = UnitPolicyResult
local policyCache = {}

-- Shared deny policy singleton for non-allied pairs
local DENY_SINGLETON = {
  canShare = false,
  sharingMode = SharedEnums.UnitSharingMode.Disabled,
}

---Validate a list of unitIds under current mode
---Returns a structured result object designed for UI consumption.
---We don't make decisions here on how to display unit names etc, we just collate the data and let the UI decide.
---@param policyResult UnitPolicyResult -- note that policyResult is useless right now but is passed in for future use
---@param unitIds number[]
---@param springApi ISpring?
---@param unitDefs table?
---@return UnitValidationResult
function Shared.ValidateUnits(policyResult, unitIds, springApi, unitDefs)
  local spring = springApi or Spring
  local defs = unitDefs or UnitDefs or (spring.GetUnitDefs and spring.GetUnitDefs()) or {}
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
---@param springApi ISpring?
---@return UnitPolicyResult
function Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId, springApi)
  local spring = springApi or Spring
  
  -- Fast path: non-allied pairs return shared deny singleton
  if not spring.AreTeamsAllied(senderTeamId, receiverTeamId) then
    DENY_SINGLETON.senderTeamId = senderTeamId
    DENY_SINGLETON.receiverTeamId = receiverTeamId
    return DENY_SINGLETON
  end
  
  -- Allied pairs: check Lua table cache
  local senderCache = policyCache[senderTeamId]
  if senderCache and senderCache[receiverTeamId] then
    return senderCache[receiverTeamId]
  end
  
  -- Cache miss - return deny policy
  ---@type UnitPolicyResult
  return {
    senderTeamId = senderTeamId,
    receiverTeamId = receiverTeamId,
    canShare = false,
    sharingMode = SharedEnums.UnitSharingMode.Disabled,
  }
end

---Cache a unit policy result in the Lua table cache
---@param senderTeamId number
---@param receiverTeamId number
---@param policyResult UnitPolicyResult
---@param springApi ISpring?
function Shared.CachePolicyResult(senderTeamId, receiverTeamId, policyResult, springApi)
  local spring = springApi or Spring
  
  -- Only cache allied pairs (non-allied use singleton)
  if not spring.AreTeamsAllied(senderTeamId, receiverTeamId) then
    return
  end
  
  policyCache[senderTeamId] = policyCache[senderTeamId] or {}
  policyCache[senderTeamId][receiverTeamId] = policyResult
end

---Invalidate unit policy cache entries
---@param senderTeamId number? If nil, invalidates all senders
---@param receiverTeamId number? If nil, invalidates all receivers for sender
function Shared.InvalidatePolicyCache(senderTeamId, receiverTeamId)
  if senderTeamId and receiverTeamId then
    if policyCache[senderTeamId] then
      policyCache[senderTeamId][receiverTeamId] = nil
    end
  elseif senderTeamId then
    policyCache[senderTeamId] = nil
  else
    policyCache = {}
  end
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
  if mode == SharedEnums.UnitSharingMode.Disabled then
    return {}
  end

  if mode == SharedEnums.UnitSharingMode.Enabled then
    return {
      SharedEnums.UnitType.Combat,
      SharedEnums.UnitType.Economic,
      SharedEnums.UnitType.Utility,
      SharedEnums.UnitType.T2Constructor
    }
  end

  if mode == SharedEnums.UnitSharingMode.CombatUnits then
    return {SharedEnums.UnitType.Combat}
  end

  if mode == SharedEnums.UnitSharingMode.Economic then
    return {SharedEnums.UnitType.Economic, SharedEnums.UnitType.T2Constructor}
  end

  if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
    return {SharedEnums.UnitType.Economic, SharedEnums.UnitType.T2Constructor, SharedEnums.UnitType.Utility}
  end

  if mode == SharedEnums.UnitSharingMode.T2Cons then
    return {SharedEnums.UnitType.T2Constructor}
  end

  if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
    return {SharedEnums.UnitType.Combat, SharedEnums.UnitType.T2Constructor}
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
  if mode == SharedEnums.UnitSharingMode.Disabled then
    return false
  end

  if mode == SharedEnums.UnitSharingMode.Enabled then
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
