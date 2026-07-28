local TransferEnums = VFS.Include("modules/context/enums.lua")
local Notes = VFS.Include("modules/transfer/lib/notes.lua")

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

---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
---@return number TransferEnums.UnitCommunicationCase
function Comms.DecideCommunicationCase(policy, validationResult)
	if policy.senderTeamId == policy.receiverTeamId then
		return TransferEnums.UnitCommunicationCase.OnSelf
	elseif not policy.canShare and policy.techBlocking then
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

---@param text string
---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
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
			.. BAR.I18N("ui.playersList.shareUnits.base.buildDelay", {
				count = builderCount,
				buildDelaySeconds = buildDelay,
			})
	end

	local stunSeconds = tonumber(policy.stunSeconds) or 0
	local stunnedCount = tonumber(validationResult.stunnedUnitCount) or 0
	if stunSeconds > 0 and stunnedCount > 0 then
		text = text
			.. " "
			.. BAR.I18N("ui.playersList.shareUnits.base.stunDelay", {
				count = stunnedCount,
				stunSeconds = stunSeconds,
				stunCategory = policy.stunCategory and BAR.I18N("ui.unitSharingMode." .. policy.stunCategory) or "",
			})
	end

	return text
end

---@param policy UnitPolicyResult
---@param validationResult UnitValidationResult?
function Comms.TooltipText(policy, validationResult)
	local notes = Notes.For("unit_terms_notes", policy)
	local hasTechUnlock = policy.techBlocking ~= nil
	-- config that never unlocks anything new reads as a plain restriction, so use base messaging
	local futureUnlock = hasTechUnlock and notes.futureUnlock == true
	local tree = (hasTechUnlock and futureUnlock) and "tech" or "base"
	local u = "ui.playersList.shareUnits." .. tree
	local case = Comms.DecideCommunicationCase(policy, validationResult)

	if case == TransferEnums.UnitCommunicationCase.OnSelf then
		return BAR.I18N("ui.playersList.requestSupport")
	elseif case == TransferEnums.UnitCommunicationCase.OnTechBlocked then
		if not futureUnlock then
			return BAR.I18N("ui.playersList.shareUnits.tech.noUnlock")
		end
		return BAR.I18N(u .. ".disabled", notes.techData or {})
	elseif case == TransferEnums.UnitCommunicationCase.OnPolicyDisabled then
		return BAR.I18N(u .. ".disabled", { unitSharingMode = displayModes(policy.sharingModes) })
	elseif case == TransferEnums.UnitCommunicationCase.OnSelectionValidationFailed then
		if hasTechUnlock and not futureUnlock then
			return BAR.I18N("ui.playersList.shareUnits.tech.noUnlock")
		end
		local i18nData = { unitSharingMode = displayModes(policy.sharingModes) }
		if tree == "tech" then
			local td = notes.techData or {}
			for k, v in pairs(td) do
				i18nData[k] = v
			end
		end
		return BAR.I18N(u .. ".allInvalid", i18nData)
	elseif case == TransferEnums.UnitCommunicationCase.OnPartiallyShareable then
		if not validationResult then
			error("This should not be possible.")
		end
		local invalidNames = validationResult.invalidUnitNames
		local i18nData = {
			unitSharingMode = displayModes(policy.sharingModes),
			firstInvalidUnitName = invalidNames[1] or "",
			count = #invalidNames,
		}
		if tree == "tech" then
			local td = notes.techData or {}
			for k, v in pairs(td) do
				i18nData[k] = v
			end
		end
		return withPolicyEffects(BAR.I18N(u .. ".invalid", i18nData), policy, validationResult)
	elseif case == TransferEnums.UnitCommunicationCase.OnFullyShareable then
		local i18nData = {}
		if validationResult then
			i18nData.validUnitCount = validationResult.validUnitCount
		end
		return withPolicyEffects(BAR.I18N("ui.playersList.shareUnits.base.default", i18nData), policy, validationResult)
	else
		error("Invalid unit communication case: " .. case)
	end
end

return Comms
