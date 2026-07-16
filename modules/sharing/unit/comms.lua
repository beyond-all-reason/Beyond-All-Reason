local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local TransferEnums = VFS.Include("modules/sharing/enums.lua")
local TechBlockingComms = VFS.Include("modules/sharing/tech/blocking_comms.lua")

local NONE_MODE = ModeEnums.UnitFilterCategory.None

local Comms = {}
Comms.__index = Comms

--- True when a higher tech level introduces a real unit-sharing change ("none"/empty unlocks nothing).
---@param policy UnitPolicyResult
---@return boolean
local function hasFutureUnlock(policy)
	local tb = TechBlockingComms.fromPolicy(policy)
	if not tb then
		return false
	end
	local opts = Spring.GetModOptions()
	for scanLevel = tb.level + 1, 3 do
		local mode = opts["unit_sharing_mode_at_t" .. scanLevel] ---@type string? sparse modoption
		if mode and mode ~= "" and mode ~= NONE_MODE then
			return true
		end
	end
	return false
end

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
---@return table
local function techI18nData(policy)
	local tb = TechBlockingComms.fromPolicy(policy)
	if not tb then
		return {}
	end
	local opts = Spring.GetModOptions()
	local nextMode = nil
	local nextLevel = nil
	local nextThreshold = nil
	for scanLevel = tb.level + 1, 3 do
		local mode = opts["unit_sharing_mode_at_t" .. scanLevel] ---@type string? sparse modoption
		if mode and mode ~= "" and mode ~= NONE_MODE then
			nextMode = mode
			nextLevel = scanLevel
			nextThreshold = scanLevel == 2 and tb.t2Threshold or tb.t3Threshold
			break
		end
	end
	return {
		currentKeystones = tb.points,
		nextTechLevel = nextLevel or tb.nextLevel,
		requiredKeystones = nextThreshold or tb.nextThreshold,
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

---Append share-time effect notes (build delay, stun) for the selection, gated on the validation's affected count.
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
		text = text .. " " .. BAR.I18N("ui.playersList.shareUnits.base.buildDelay", {
			count = builderCount,
			buildDelaySeconds = buildDelay,
		})
	end

	local stunSeconds = tonumber(policy.stunSeconds) or 0
	local stunnedCount = tonumber(validationResult.stunnedUnitCount) or 0
	if stunSeconds > 0 and stunnedCount > 0 then
		text = text .. " " .. BAR.I18N("ui.playersList.shareUnits.base.stunDelay", {
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
	local tb = TechBlockingComms.fromPolicy(policy)
	local hasTechUnlock = tb ~= nil
	-- config that never unlocks anything new reads as a plain restriction, so use base messaging
	local futureUnlock = hasTechUnlock and hasFutureUnlock(policy)
	local tree = (hasTechUnlock and futureUnlock) and "tech" or "base"
	local u = "ui.playersList.shareUnits." .. tree
	local case = Comms.DecideCommunicationCase(policy, validationResult)

	if case == TransferEnums.UnitCommunicationCase.OnSelf then
		return BAR.I18N("ui.playersList.requestSupport")
	elseif case == TransferEnums.UnitCommunicationCase.OnTechBlocked then
		if not futureUnlock then
			return BAR.I18N("ui.playersList.shareUnits.tech.noUnlock")
		end
		return BAR.I18N(u .. ".disabled", techI18nData(policy))
	elseif case == TransferEnums.UnitCommunicationCase.OnPolicyDisabled then
		return BAR.I18N(u .. ".disabled", { unitSharingMode = displayModes(policy.sharingModes) })
	elseif case == TransferEnums.UnitCommunicationCase.OnSelectionValidationFailed then
		if hasTechUnlock and not futureUnlock then
			return BAR.I18N("ui.playersList.shareUnits.tech.noUnlock")
		end
		local i18nData = { unitSharingMode = displayModes(policy.sharingModes) }
		if tree == "tech" then
			local td = techI18nData(policy)
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
			local td = techI18nData(policy)
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
