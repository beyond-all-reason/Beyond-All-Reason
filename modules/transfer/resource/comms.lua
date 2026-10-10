local BAR = BAR
local SendToUnsynced = SendToUnsynced
local Spring = Spring

local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Notes = require("modules/transfer/lib/notes")
local Published = require("modules/published")
local TransferEnums = require("modules/transfer/enums")
local FieldTypes = Published.FieldTypes

local Comms = {
	ResourceCommunicationCase = TransferEnums.ResourceCommunicationCase,
}
Comms.__index = Comms

---@param policyResult ResourceTransferTerms
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
	return TransferEnums.ResourceCommunicationCase.OnTaxed
end

---@param value number
---@return string
local function FormatNumberForUI(value)
	if type(value) == "number" then
		return tostring(math.floor(value))
	else
		return tostring(value)
	end
end

Comms.FormatNumberForUI = FormatNumberForUI

---@param text string
---@param opening string|nil what another module says would change the terms for the better
---@return string
local function noted(text, opening)
	if opening == nil or opening == "" then
		return text
	end
	return BAR.I18N("ui.playersList.noted", { text = text, note = opening })
end

function Comms.TooltipText(policyResult)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	local r = policyResult.resourceType == TransferEnums.ResourceType.METAL and "ui.playersList.shareMetal."
		or "ui.playersList.shareEnergy."
	local pascalResourceType = policyResult.resourceType:gsub("^%l", string.upper)

	local case = Comms.DecideCommunicationCase(policyResult)
	if case == TransferEnums.ResourceCommunicationCase.OnSelf then
		return BAR.I18N("ui.playersList.request" .. pascalResourceType)
	elseif case == TransferEnums.ResourceCommunicationCase.OnDisabled then
		return BAR.I18N(r .. "disabled")
	end

	local notes = Notes.For(Transfer.ResourceTermsNotes, policyResult, Spring.GetModOptions(), Spring)
	local opening = notes[Transfer.ResourceTermsNotes.Opening]
	if case == TransferEnums.ResourceCommunicationCase.OnTaxFree then
		return noted(BAR.I18N(r .. "default"), opening)
	elseif case == TransferEnums.ResourceCommunicationCase.OnTaxed then
		return noted(
			BAR.I18N(r .. "taxed", {
				amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
				amountSendable = FormatNumberForUI(policyResult.amountSendable),
				taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
			}),
			opening
		)
	end
end

Comms.SendTransferChatMessageProtocol = {
	receivedAmount = FieldTypes.string,
	sentAmount = FieldTypes.string,
	taxRatePercentage = FieldTypes.string,
}

Comms.SendTransferChatMessageProtocolHighlights = {
	receivedAmount = true,
	sentAmount = true,
	taxRatePercentage = false,
}

---@param transferResult TransferResourceResult
---@param policyResult ResourceTransferTerms
function Comms.SendTransferChatMessages(transferResult, policyResult)
	if transferResult.sent > 0 then
		local resourceType = policyResult.resourceType
		local pascalResourceType = resourceType == TransferEnums.ResourceType.METAL and "Metal" or "Energy"
		local case = Comms.DecideCommunicationCase(policyResult)
		local chatParams = {
			receivedAmount = math.floor(transferResult.received),
			sentAmount = FormatNumberForUI(transferResult.sent),
			taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100 + 0.5),
			resourceType = resourceType,
		}

		local key
		if case == TransferEnums.ResourceCommunicationCase.OnTaxFree then
			key = "ui.playersList.chat.sent" .. pascalResourceType
		elseif case == TransferEnums.ResourceCommunicationCase.OnTaxed then
			key = "ui.playersList.chat.sent" .. pascalResourceType .. "Taxed"
		end
		if not key then
			return
		end

		local serialized = Published.Encode(Comms.SendTransferChatMessageProtocol, chatParams)
		local _, senderPlayerID = Spring.GetTeamInfo(policyResult.senderTeamId, false)
		if senderPlayerID and senderPlayerID >= 0 then
			SendToUnsynced("sendMsg", senderPlayerID, key .. ":" .. serialized)
		end
	end
end

return Comms
