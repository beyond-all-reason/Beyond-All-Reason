local BAR = BAR
local Spring = Spring

local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Notes = require("modules/transfer/lib/notes")
local TransferEnums = require("modules/transfer/enums")

local Comms = {}
Comms.__index = Comms

---@param modes string[]
---@return string
local function displayModes(modes)
	local names = {}
	for _, m in ipairs(modes) do
		names[#names + 1] = BAR.I18N("ui.unitSharingMode." .. m)
	end
	return table.concat(names, " + ")
end

---@param policy UnitTransferTerms
---@param validationResult TransferUnitValidation?
---@return number TransferEnums.UnitCommunicationCase
function Comms.DecideCommunicationCase(policy, validationResult)
	if policy.senderTeamId == policy.receiverTeamId then
		return TransferEnums.UnitCommunicationCase.OnSelf
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

---@param text string
---@param policy UnitTransferTerms
---@param validationResult TransferUnitValidation?
---@return string
local function withPolicyEffects(text, policy, validationResult)
	if not validationResult then
		return text
	end

	local buildDelay = tonumber(policy.buildDelaySeconds) or 0
	local builderCount = tonumber(validationResult.buildDelayedUnitCount) or 0
	if buildDelay > 0 and builderCount > 0 then
		text = text
			.. " "
			.. BAR.I18N("ui.playersList.shareUnits.buildDelay", {
				count = builderCount,
				buildDelaySeconds = buildDelay,
			})
	end

	local stunSeconds = tonumber(policy.stunSeconds) or 0
	local stunnedCount = tonumber(validationResult.stunnedUnitCount) or 0
	if stunSeconds > 0 and stunnedCount > 0 then
		text = text
			.. " "
			.. BAR.I18N("ui.playersList.shareUnits.stunDelay", {
				count = stunnedCount,
				stunSeconds = stunSeconds,
				stunCategory = policy.stunCategory and BAR.I18N("ui.unitSharingMode." .. policy.stunCategory) or "",
			})
	end

	return text
end

---@param text string
---@param opening string|nil what another module says would open sharing further
---@return string
local function noted(text, opening)
	if opening == nil or opening == "" then
		return text
	end
	return BAR.I18N("ui.playersList.noted", { text = text, note = opening })
end

---@param policy UnitTransferTerms
---@param validationResult TransferUnitValidation?
function Comms.TooltipText(policy, validationResult)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	local case = Comms.DecideCommunicationCase(policy, validationResult)
	if case == TransferEnums.UnitCommunicationCase.OnSelf then
		return BAR.I18N("ui.playersList.requestSupport")
	end

	local notes = Notes.For(Transfer.UnitTermsNotes, policy, Spring.GetModOptions(), Spring)
	local opening = notes[Transfer.UnitTermsNotes.Opening]
	local u = "ui.playersList.shareUnits."

	if case == TransferEnums.UnitCommunicationCase.OnPolicyDisabled then
		return noted(BAR.I18N(u .. "disabled", { unitSharingMode = displayModes(policy.sharingModes) }), opening)
	elseif case == TransferEnums.UnitCommunicationCase.OnSelectionValidationFailed then
		return noted(BAR.I18N(u .. "allInvalid", { unitSharingMode = displayModes(policy.sharingModes) }), opening)
	elseif case == TransferEnums.UnitCommunicationCase.OnPartiallyShareable then
		if not validationResult then
			error("This should not be possible.")
		end
		local invalidNames = validationResult.invalidUnitNames
		local text = BAR.I18N(u .. "invalid", {
			unitSharingMode = displayModes(policy.sharingModes),
			firstInvalidUnitName = invalidNames[1] or "",
			count = #invalidNames,
		})
		return withPolicyEffects(noted(text, opening), policy, validationResult)
	elseif case == TransferEnums.UnitCommunicationCase.OnFullyShareable then
		local i18nData = {}
		if validationResult then
			i18nData.validUnitCount = validationResult.validUnitCount
		end
		return withPolicyEffects(BAR.I18N(u .. "default", i18nData), policy, validationResult)
	else
		error("Invalid unit communication case: " .. case)
	end
end

return Comms
