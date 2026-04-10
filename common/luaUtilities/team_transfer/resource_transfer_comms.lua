local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local Cache = VFS.Include("common/luaUtilities/team_transfer/team_transfer_serialization_helpers.lua")
local FieldTypes = Cache.FieldTypes
local TechBlockingComms = VFS.Include("common/luaUtilities/team_transfer/tech_blocking_comms.lua")

local Comms = {
  ResourceCommunicationCase = TransferEnums.ResourceCommunicationCase,
}
Comms.__index = Comms

--- Determine communication case from policy result
---@param policyResult ResourcePolicyResult
---@return integer
function Comms.DecideCommunicationCase(policyResult)
  if policyResult.senderTeamId == policyResult.receiverTeamId then
    return TransferEnums.ResourceCommunicationCase.OnSelf
  end
  if not policyResult.canShare then
    return TransferEnums.ResourceCommunicationCase.OnDisabled
  end
  if policyResult.taxRate <= 0 then
    return TransferEnums.ResourceCommunicationCase.OnTaxFree
  end
  if policyResult.resourceShareThreshold > 0 then
    return TransferEnums.ResourceCommunicationCase.OnTaxedThreshold
  end
  return TransferEnums.ResourceCommunicationCase.OnTaxed
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
---@return TechUnlockInfo?
---@return TechBlockingContext?
local function getTaxUnlock(policyResult)
  local tb = TechBlockingComms.fromPolicy(policyResult)
  if not tb then return nil, nil end

  local opts = Spring.GetModOptions()
  for scanLevel = tb.level + 1, 3 do
    local raw = opts["tax_resource_sharing_amount_at_t" .. scanLevel]
    local rate = tonumber(raw)
    if rate and rate >= 0 then
      local thresh = scanLevel == 2 and tb.t2Threshold or tb.t3Threshold
      return { unlockLevel = scanLevel, unlockThreshold = thresh, unlockValue = raw }, tb
    end
  end
  return nil, tb
end

function Comms.TooltipText(policyResult)
  local resBase = policyResult.resourceType == TransferEnums.ResourceType.METAL and 'ui.playersList.shareMetal' or 'ui.playersList.shareEnergy'
  local pascalResourceType = policyResult.resourceType:gsub("^%l", string.upper)
  local taxUnlock, tb = getTaxUnlock(policyResult)
  local tree = taxUnlock and 'tech' or 'base'
  local r = resBase .. '.' .. tree

  local case = Comms.DecideCommunicationCase(policyResult)
  if case == TransferEnums.ResourceCommunicationCase.OnSelf then
    return Spring.I18N('ui.playersList.request' .. pascalResourceType)

  elseif case == TransferEnums.ResourceCommunicationCase.OnTaxFree then
    local i18nData = {}
    if taxUnlock and tb then
      i18nData.nextRate = FormatNumberForUI(tonumber(taxUnlock.unlockValue) * 100)
      i18nData.nextTechLevel = taxUnlock.unlockLevel
      i18nData.currentCatalysts = tb.points
      i18nData.requiredCatalysts = taxUnlock.unlockThreshold
    end
    return Spring.I18N(r .. '.default', i18nData)

  elseif case == TransferEnums.ResourceCommunicationCase.OnDisabled then
    -- Force base tree for disabled (tech doesn't hard-block resources, so it's a game state reason)
    return Spring.I18N(resBase .. '.base.disabled')

  elseif case == TransferEnums.ResourceCommunicationCase.OnTaxed then
    local i18nData = {
      amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
      amountSendable = FormatNumberForUI(policyResult.amountSendable),
      taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
    }
    if taxUnlock and tb then
      i18nData.nextRate = FormatNumberForUI(tonumber(taxUnlock.unlockValue) * 100)
      i18nData.nextTechLevel = taxUnlock.unlockLevel
      i18nData.currentCatalysts = tb.points
      i18nData.requiredCatalysts = taxUnlock.unlockThreshold
    end
    return Spring.I18N(r .. '.taxed', i18nData)

  elseif case == TransferEnums.ResourceCommunicationCase.OnTaxedThreshold then
    local i18nData = {
      amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
      amountSendable = FormatNumberForUI(policyResult.amountSendable),
      taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
      resourceShareThreshold = FormatNumberForUI(policyResult.resourceShareThreshold),
      sentAmountUntaxed = FormatNumberForUI(math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)),
    }
    if taxUnlock and tb then
      i18nData.nextRate = FormatNumberForUI(tonumber(taxUnlock.unlockValue) * 100)
      i18nData.nextTechLevel = taxUnlock.unlockLevel
      i18nData.currentCatalysts = tb.points
      i18nData.requiredCatalysts = taxUnlock.unlockThreshold
    end
    return Spring.I18N(r .. '.taxedThreshold', i18nData)
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
    local pascalResourceType = resourceType == TransferEnums.ResourceType.METAL and "Metal" or "Energy"
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
    if case == TransferEnums.ResourceCommunicationCase.OnTaxFree then
      key = 'ui.playersList.chat.sent' .. pascalResourceType
    elseif case == TransferEnums.ResourceCommunicationCase.OnTaxed then
      key = 'ui.playersList.chat.sent' .. pascalResourceType .. 'Taxed'
    elseif case == TransferEnums.ResourceCommunicationCase.OnTaxedThreshold then
      key = 'ui.playersList.chat.sent' .. pascalResourceType .. 'TaxedThreshold'
    end

    local serialized = Cache.Serialize(Comms.SendTransferChatMessageProtocol, chatParams)
    Spring.SendLuaRulesMsg('msg:' .. key .. ':' .. serialized)
  end
end

return Comms
