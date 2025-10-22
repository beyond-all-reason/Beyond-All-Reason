local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

local Comms = {
  UnitCommunicationCase = SharedEnums.UnitCommunicationCase,
}
Comms.__index = Comms

---Decide communication case for unit sharing based on policy and optional validation results
---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
---@return number SharedEnums.UnitCommunicationCase
function Comms.DecideCommunicationCase(policy, validationResult)
  if policy.senderTeamId == policy.receiverTeamId then
    return SharedEnums.UnitCommunicationCase.OnSelf
  elseif not policy.canShare then
    return SharedEnums.UnitCommunicationCase.OnPolicyDisabled
  elseif validationResult then
    if validationResult.status == SharedEnums.UnitValidationOutcome.PartialSuccess then
      return SharedEnums.UnitCommunicationCase.OnPartiallyShareable
    elseif validationResult.status == SharedEnums.UnitValidationOutcome.Success then
      return SharedEnums.UnitCommunicationCase.OnFullyShareable
    else
      return SharedEnums.UnitCommunicationCase.OnSelectionValidationFailed
    end
  else
    return SharedEnums.UnitCommunicationCase.OnFullyShareable
  end
end

---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
function Comms.TooltipText(policy, validationResult)
  local baseKey = 'ui.playersList'
  local case = Comms.DecideCommunicationCase(policy, validationResult)
  if case == SharedEnums.UnitCommunicationCase.OnSelf then
    return Spring.I18N(baseKey .. '.requestSupport')
  elseif case == SharedEnums.UnitCommunicationCase.OnPolicyDisabled then
    local i18nData = {
      unitSharingMode = policy.sharingMode,
    }
    return Spring.I18N(baseKey .. '.shareUnitsDisabled', i18nData)
  elseif case == SharedEnums.UnitCommunicationCase.OnSelectionValidationFailed then
    return Spring.I18N(baseKey .. '.shareUnitsInvalid.all')
  elseif case == SharedEnums.UnitCommunicationCase.OnPartiallyShareable then
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
  elseif case == SharedEnums.UnitCommunicationCase.OnFullyShareable then
    if validationResult then
      return Spring.I18N(baseKey .. '.shareUnits')
    else
      return Spring.I18N(baseKey .. '.shareUnits')
    end
  else
    error('Invalid unit communication case: ' .. case)
  end
end

return Comms
