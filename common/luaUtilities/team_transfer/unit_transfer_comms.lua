local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local TechBlockingComms = VFS.Include("common/luaUtilities/team_transfer/tech_blocking_comms.lua")

local Comms = {}
Comms.__index = Comms

---@param modes string[]
---@return string
local function displayModes(modes)
  local names = {}
  for _, m in ipairs(modes) do
    names[#names + 1] = Spring.I18N('ui.unitSharingMode.' .. m)
  end
  return table.concat(names, " + ")
end

---@param policy UnitPolicyResult
---@return table
local function techI18nData(policy)
  local tb = TechBlockingComms.fromPolicy(policy)
  if not tb then return {} end
  local opts = Spring.GetModOptions()
  local nextMode = nil
  local nextLevel = nil
  local nextThreshold = nil
  for scanLevel = tb.level + 1, 3 do
    local mode = opts["unit_sharing_mode_at_t" .. scanLevel]
    if mode and mode ~= "" then
      nextMode = mode
      nextLevel = scanLevel
      nextThreshold = scanLevel == 2 and tb.t2Threshold or tb.t3Threshold
      break
    end
  end
  return {
    currentCatalysts = tb.points,
    nextTechLevel = nextLevel or tb.nextLevel,
    requiredCatalysts = nextThreshold or tb.nextThreshold,
    nextUnitSharingMode = nextMode or "",
  }
end

---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
---@return number TransferEnums.UnitCommunicationCase
function Comms.DecideCommunicationCase(policy, validationResult)
  if policy.senderTeamId == policy.receiverTeamId then
    return TransferEnums.UnitCommunicationCase.OnSelf
  elseif not policy.canShare and TechBlockingComms.fromPolicy(policy) then
    return TransferEnums.UnitCommunicationCase.OnTechBlocked
  elseif not policy.canShare then
    return TransferEnums.UnitCommunicationCase.OnPolicyDisabled
  elseif validationResult then
    if validationResult.status == TransferEnums.UnitValidationOutcome.PartialSuccess then
      return TransferEnums.UnitCommunicationCase.OnPartiallyShareable
    elseif validationResult.status == TransferEnums.UnitValidationOutcome.Success then
      return TransferEnums.UnitCommunicationCase.OnFullyShareable
    else
      return TransferEnums.UnitCommunicationCase.OnSelectionValidationFailed
    end
  else
    return TransferEnums.UnitCommunicationCase.OnFullyShareable
  end
end

---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
function Comms.TooltipText(policy, validationResult)
  local tb = TechBlockingComms.fromPolicy(policy)
  local hasTechUnlock = tb ~= nil
  local tree = hasTechUnlock and 'tech' or 'base'
  local u = 'ui.playersList.shareUnits.' .. tree
  local case = Comms.DecideCommunicationCase(policy, validationResult)

  if case == TransferEnums.UnitCommunicationCase.OnSelf then
    return Spring.I18N('ui.playersList.requestSupport')

  elseif case == TransferEnums.UnitCommunicationCase.OnTechBlocked then
    return Spring.I18N(u .. '.disabled', techI18nData(policy))

  elseif case == TransferEnums.UnitCommunicationCase.OnPolicyDisabled then
    return Spring.I18N(u .. '.disabled', { unitSharingMode = displayModes(policy.sharingModes) })

  elseif case == TransferEnums.UnitCommunicationCase.OnSelectionValidationFailed then
    local i18nData = { unitSharingMode = displayModes(policy.sharingModes) }
    if tree == 'tech' then
      local td = techI18nData(policy)
      for k, v in pairs(td) do i18nData[k] = v end
    end
    return Spring.I18N(u .. '.invalid.all', i18nData)

  elseif case == TransferEnums.UnitCommunicationCase.OnPartiallyShareable then
    if not validationResult then error("This should not be possible.") end
    local invalidNames = validationResult.invalidUnitNames
    local i18nData = {
      unitSharingMode = displayModes(policy.sharingModes),
      firstInvalidUnitName = invalidNames[1] or "",
      secondInvalidUnitName = invalidNames[2] or "",
      count = #invalidNames - 2,
    }
    if tree == 'tech' then
      local td = techI18nData(policy)
      for k, v in pairs(td) do i18nData[k] = v end
    end
    if #invalidNames == 1 then
      return Spring.I18N(u .. '.invalid.one', i18nData)
    elseif #invalidNames == 2 then
      return Spring.I18N(u .. '.invalid.two', i18nData)
    else
      return Spring.I18N(u .. '.invalid.other', i18nData)
    end

  elseif case == TransferEnums.UnitCommunicationCase.OnFullyShareable then
    local i18nData = {}
    if validationResult then
      i18nData.validUnitCount = validationResult.validUnitCount
    end
    return Spring.I18N('ui.playersList.shareUnits.base.default', i18nData)
  else
    error('Invalid unit communication case: ' .. case)
  end
end

return Comms
