local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

local Comms = {
  ResourceCommunicationCase = SharedEnums.ResourceCommunicationCase,
}
Comms.__index = Comms

--- Determine communication case from parameters
---@param senderTeamId number
---@param receiverTeamId number
---@param taxRate number
---@param resourceShareThreshold number
---@return integer
function Comms.DecideCommunicationCaseFromParams(senderTeamId, receiverTeamId, taxRate, resourceShareThreshold)
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
function Comms.DecideCommunicationCase(policyResult)
  return Comms.DecideCommunicationCaseFromParams(
    policyResult.senderTeamId,
    policyResult.receiverTeamId,
    policyResult.taxRate,
    policyResult.resourceShareThreshold
  )
end

---Format a number for UI display by flooring it to whole numbers, this mirrors behavior in ResourceTransfer, which rounds down to the nearest percentage when interpreting commands from the slider
---@param value number
---@return string
function FormatNumberForUI(value)
  if type(value) == "number" then
      return tostring(math.floor(value))
  else
      return tostring(value)
  end
end
Comms.FormatNumberForUI = FormatNumberForUI

---@param policyResult ResourcePolicyResult
function Comms.TooltipText(policyResult)
  local pascalResourceType = policyResult.resourceType:gsub("^%l", string.upper)
  local baseKey = 'ui.playersList'
  local case = Comms.DecideCommunicationCase(policyResult)
  if case == SharedEnums.ResourceCommunicationCase.OnSelf then
      return Spring.I18N(baseKey .. '.request' .. pascalResourceType)
  elseif case == SharedEnums.ResourceCommunicationCase.OnTaxFree then
      return Spring.I18N(baseKey .. '.share' .. pascalResourceType)
  elseif case == SharedEnums.ResourceCommunicationCase.OnTaxed then
    local i18nData = {
        amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
        amountSendable = FormatNumberForUI(policyResult.amountSendable),
        taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
    }
    return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'Taxed', i18nData)
  elseif case == SharedEnums.ResourceCommunicationCase.OnTaxedThreshold then
      local i18nData = {
          amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
          amountSendable = FormatNumberForUI(policyResult.amountSendable),
          taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
          resourceShareThreshold = FormatNumberForUI(policyResult.resourceShareThreshold),
          sentAmountUntaxed = FormatNumberForUI(math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)),
      }
      return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'TaxedThreshold', i18nData)
  end
end

--- Send chat messages for completed resource transfers
---@param transferResult ResourceTransferResult
---@param policyResult ResourcePolicyResult
function Comms.SendTransferChatMessages(transferResult, policyResult)
  if transferResult.sent > 0 then
    local resourceType = policyResult.resourceType
    local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
    local case = Comms.DecideCommunicationCase(policyResult)

    if case == SharedEnums.ResourceCommunicationCase.OnTaxFree then
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType .. ':receivedAmount=' .. math.floor(transferResult.received))
    elseif case == SharedEnums.ResourceCommunicationCase.OnTaxed then
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType ..
        'Taxed:receivedAmount=' ..
        math.floor(transferResult.received) ..
        ':sentAmount=' ..
        math.floor(transferResult.sent) .. ':taxRatePercentage=' .. math.floor(policyResult.taxRate * 100 + 0.5))
    elseif case == SharedEnums.ResourceCommunicationCase.OnTaxedThreshold then
      local cumulativeUntaxed = math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType ..
        'TaxedThreshold:receivedAmount=' ..
        math.floor(transferResult.received) ..
        ':sentAmount=' ..
        math.floor(transferResult.sent) ..
        ':taxRatePercentage=' ..
        math.floor(policyResult.taxRate * 100 + 0.5) ..
        ':sentAmountUntaxed=' ..
        math.floor(cumulativeUntaxed) .. ':resourceShareThreshold=' .. math.floor(policyResult.resourceShareThreshold))
    end
  end
end

return Comms