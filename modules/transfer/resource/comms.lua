local BAR = BAR
local SendToUnsynced = SendToUnsynced
local Spring = Spring --[[@as Recoil.Shared]]

local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Notes = require("modules/transfer/lib/notes")
local Published = require("modules/published")
local Shared = require("modules/transfer/resource/shared")
local TransferEnums = require("modules/transfer/enums")
local FieldTypes = Published.FieldTypes

local Comms = {}
Comms.__index = Comms

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

function Comms.TooltipText(terms)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	local r = terms.resourceType == TransferEnums.ResourceType.METAL and "ui.playersList.shareMetal."
		or "ui.playersList.shareEnergy."
	local pascalResourceType = terms.resourceType:gsub("^%l", string.upper)

	local case = Shared.CaseOf(terms)
	if case == TransferEnums.ResourceTermsCase.OnSelf then
		return BAR.I18N("ui.playersList.request" .. pascalResourceType)
	elseif case == TransferEnums.ResourceTermsCase.OnDisabled then
		return BAR.I18N(r .. "disabled")
	end

	local notes = Notes.For(Transfer.ResourceTermsNotes, terms, Spring.GetModOptions(), Spring)
	local opening = notes[Transfer.ResourceTermsNotes.Opening]
	if case == TransferEnums.ResourceTermsCase.OnTaxFree then
		return noted(BAR.I18N(r .. "default"), opening)
	elseif case == TransferEnums.ResourceTermsCase.OnTaxed then
		return noted(
			BAR.I18N(r .. "taxed", {
				amountReceivable = FormatNumberForUI(terms.amountReceivable),
				amountSendable = FormatNumberForUI(terms.amountSendable),
				taxRatePercentage = FormatNumberForUI(terms.taxRate * 100),
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
---@param terms ResourceTransferTerms
function Comms.SendTransferChatMessages(transferResult, terms)
	if transferResult.sent > 0 then
		local resourceType = terms.resourceType
		local pascalResourceType = resourceType == TransferEnums.ResourceType.METAL and "Metal" or "Energy"
		local case = Shared.CaseOf(terms)
		local chatParams = {
			receivedAmount = math.floor(transferResult.received),
			sentAmount = FormatNumberForUI(transferResult.sent),
			taxRatePercentage = FormatNumberForUI(terms.taxRate * 100 + 0.5),
			resourceType = resourceType,
		}

		local key
		if case == TransferEnums.ResourceTermsCase.OnTaxFree then
			key = "ui.playersList.chat.sent" .. pascalResourceType
		elseif case == TransferEnums.ResourceTermsCase.OnTaxed then
			key = "ui.playersList.chat.sent" .. pascalResourceType .. "Taxed"
		end
		if not key then
			return
		end

		-- The chat widget reads the line as key:name=value:name=value (luaui/Widgets/gui_chat.lua)
		local pairs_ = {}
		for name in pairs(Comms.SendTransferChatMessageProtocol) do
			pairs_[#pairs_ + 1] = name .. "=" .. tostring(chatParams[name])
		end
		local serialized = table.concat(pairs_, ":")
		local _, senderPlayerID = Spring.GetTeamInfo(terms.senderTeamId, false)
		if senderPlayerID and senderPlayerID >= 0 then
			SendToUnsynced("sendMsg", senderPlayerID, key .. ":" .. serialized)
		end
	end
end

return Comms
