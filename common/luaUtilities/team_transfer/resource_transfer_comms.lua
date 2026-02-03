local GlobalEnums = VFS.Include("modes/global_enums.lua")
local Cache = VFS.Include("common/luaUtilities/team_transfer/team_transfer_serialization_helpers.lua")
local FieldTypes = Cache.FieldTypes

local Comms = {
  ResourceCommunicationCase = GlobalEnums.ResourceCommunicationCase,
}
Comms.__index = Comms

--- Determine communication case from policy result
---@param policyResult ResourcePolicyResult
---@return integer
function Comms.DecideCommunicationCase(policyResult)
  if policyResult.senderTeamId == policyResult.receiverTeamId then
    return GlobalEnums.ResourceCommunicationCase.OnSelf
  end
  if not policyResult.canShare then
    return GlobalEnums.ResourceCommunicationCase.OnDisabled
  end
  if policyResult.taxRate <= 0 then
    return GlobalEnums.ResourceCommunicationCase.OnTaxFree
  end
  if policyResult.resourceShareThreshold > 0 then
    return GlobalEnums.ResourceCommunicationCase.OnTaxedThreshold
  end
  return GlobalEnums.ResourceCommunicationCase.OnTaxed
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
  if case == GlobalEnums.ResourceCommunicationCase.OnSelf then
    return Spring.I18N(baseKey .. '.request' .. pascalResourceType)
  elseif case == GlobalEnums.ResourceCommunicationCase.OnTaxFree then
    return Spring.I18N(baseKey .. '.share' .. pascalResourceType)
  elseif case == GlobalEnums.ResourceCommunicationCase.OnDisabled then
    return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'Disabled')
  elseif case == GlobalEnums.ResourceCommunicationCase.OnTaxed then
    local i18nData = {
      amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
      amountSendable = FormatNumberForUI(policyResult.amountSendable),
      taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
    }
    return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'Taxed', i18nData)
  elseif case == GlobalEnums.ResourceCommunicationCase.OnTaxedThreshold then
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

Comms.SendTransferChatMessageProtocol = {
  receivedAmount = FieldTypes.string,
  sentAmount = FieldTypes.string,
  taxRatePercentage = FieldTypes.string,
  sentAmountUntaxed = FieldTypes.string,
  resourceShareThreshold = FieldTypes.string,
}

Comms.SendTransferChatMessageProtocolHighlights = {
  receivedAmount = true,
  sentAmount = true,
  taxRatePercentage = false,
  sentAmountUntaxed = true,
  resourceShareThreshold = true,
}

--- Send chat messages for completed resource transfers
---@param transferResult ResourceTransferResult
---@param policyResult ResourcePolicyResult
function Comms.SendTransferChatMessages(transferResult, policyResult)
  if transferResult.sent > 0 then
    local resourceType = policyResult.resourceType
    local pascalResourceType = resourceType == GlobalEnums.ResourceType.METAL and "Metal" or "Energy"
    local case = Comms.DecideCommunicationCase(policyResult)
    local cumulativeUntaxed = math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)
    local chatParams = {
      receivedAmount = math.floor(transferResult.received),
      sentAmount = FormatNumberForUI(transferResult.sent),
      taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100 + 0.5),
      sentAmountUntaxed = FormatNumberForUI(cumulativeUntaxed + transferResult.untaxed),
      resourceShareThreshold = FormatNumberForUI(policyResult.resourceShareThreshold),
      resourceType = resourceType,
    }

    local key
    if case == GlobalEnums.ResourceCommunicationCase.OnTaxFree then
      key = 'ui.playersList.chat.sent' .. pascalResourceType
    elseif case == GlobalEnums.ResourceCommunicationCase.OnTaxed then
      key = 'ui.playersList.chat.sent' .. pascalResourceType .. 'Taxed'
    elseif case == GlobalEnums.ResourceCommunicationCase.OnTaxedThreshold then
      key = 'ui.playersList.chat.sent' .. pascalResourceType .. 'TaxedThreshold'
    end

    local serialized = Cache.Serialize(Comms.SendTransferChatMessageProtocol, chatParams)
    Spring.SendLuaRulesMsg('msg:' .. key .. ':' .. serialized)
  end
end

return Comms
