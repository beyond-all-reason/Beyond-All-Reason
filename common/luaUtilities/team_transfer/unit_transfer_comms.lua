local GlobalEnums = VFS.Include("modes/global_enums.lua")

local Comms = {}
Comms.__index = Comms

---Decide communication case for unit sharing based on policy and optional validation results
---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
---@return number GlobalEnums.UnitCommunicationCase
function Comms.DecideCommunicationCase(policy, validationResult)
  if policy.senderTeamId == policy.receiverTeamId then
    return GlobalEnums.UnitCommunicationCase.OnSelf
  elseif not policy.canShare then
    return GlobalEnums.UnitCommunicationCase.OnPolicyDisabled
  elseif validationResult then
    if validationResult.status == GlobalEnums.UnitValidationOutcome.PartialSuccess then
      return GlobalEnums.UnitCommunicationCase.OnPartiallyShareable
    elseif validationResult.status == GlobalEnums.UnitValidationOutcome.Success then
      return GlobalEnums.UnitCommunicationCase.OnFullyShareable
    else
      return GlobalEnums.UnitCommunicationCase.OnSelectionValidationFailed
    end
  else
    return GlobalEnums.UnitCommunicationCase.OnFullyShareable
  end
end

---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
function Comms.TooltipText(policy, validationResult)
  local baseKey = 'ui.playersList'
  local case = Comms.DecideCommunicationCase(policy, validationResult)
  local i18nData = {
    unitSharingMode = policy.sharingMode,
  }
  if validationResult then
    i18nData.firstInvalidUnitName = validationResult.invalidUnitNames[1] or ""
    i18nData.secondInvalidUnitName = validationResult.invalidUnitNames[2] or ""
    i18nData.count = #validationResult.invalidUnitNames - 2
  end
  if case == GlobalEnums.UnitCommunicationCase.OnSelf then
    return Spring.I18N(baseKey .. '.requestSupport')
  elseif case == GlobalEnums.UnitCommunicationCase.OnPolicyDisabled then
    return Spring.I18N(baseKey .. '.shareUnitsDisabled', i18nData)
  elseif case == GlobalEnums.UnitCommunicationCase.OnSelectionValidationFailed then
    return Spring.I18N(baseKey .. '.shareUnitsInvalid.all')
  elseif case == GlobalEnums.UnitCommunicationCase.OnPartiallyShareable then
    if not validationResult then error("This should not be possible.") end

    local invalidNames = validationResult.invalidUnitNames
    local i18nData = {
      unitSharingMode = policy.sharingMode,
      firstInvalidUnitName = invalidNames[1] or "",
      secondInvalidUnitName = invalidNames[2] or "",
      count = #invalidNames - 2,
    }
    if #invalidNames == 1 then
      return Spring.I18N(baseKey .. '.shareUnitsInvalid.one', i18nData)
    elseif #invalidNames == 2 then
      return Spring.I18N(baseKey .. '.shareUnitsInvalid.two', i18nData)
    else
      return Spring.I18N(baseKey .. '.shareUnitsInvalid.other', i18nData)
    end
  elseif case == GlobalEnums.UnitCommunicationCase.OnFullyShareable then
    if validationResult then
      local i18nData = {
        validUnitCount = validationResult.validUnitCount,
      }
      return Spring.I18N(baseKey .. '.shareUnits', i18nData)
    else
      return Spring.I18N(baseKey .. '.shareUnits')
    end
  else
    error('Invalid unit communication case: ' .. case)
  end
end

return Comms
