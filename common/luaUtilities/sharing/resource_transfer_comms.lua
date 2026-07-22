local TransferEnums = VFS.Include("common/luaUtilities/sharing/transfer_enums.lua")
local Cache = VFS.Include("common/luaUtilities/sharing/serialization.lua")
local FieldTypes = Cache.FieldTypes
local TechBlockingComms = VFS.Include("common/luaUtilities/sharing/tech_blocking_comms.lua")

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
	return TransferEnums.ResourceCommunicationCase.OnTaxed
end

---Format a number for UI display by flooring to whole numbers, mirroring ResourceTransfer's slider rounding.
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

---@param policyResult ResourcePolicyResult
---@return TechUnlockInfo?
---@return TechBlockingContext?
local function getTaxUnlock(policyResult)
	local tb = TechBlockingComms.fromPolicy(policyResult)
	if not tb then
		return nil, nil
	end

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
	local resBase = policyResult.resourceType == TransferEnums.ResourceType.METAL and "ui.playersList.shareMetal" or "ui.playersList.shareEnergy"
	local pascalResourceType = policyResult.resourceType:gsub("^%l", string.upper)
	local taxUnlock, tb = getTaxUnlock(policyResult)
	local tree = taxUnlock and "tech" or "base"
	local r = resBase .. "." .. tree

	local case = Comms.DecideCommunicationCase(policyResult)
	if case == TransferEnums.ResourceCommunicationCase.OnSelf then
		return BAR.I18N("ui.playersList.request" .. pascalResourceType)
	elseif case == TransferEnums.ResourceCommunicationCase.OnTaxFree then
		local i18nData = {}
		if taxUnlock and tb then
			i18nData.nextRate = FormatNumberForUI((tonumber(taxUnlock.unlockValue) or 0) * 100)
			i18nData.nextTechLevel = taxUnlock.unlockLevel
			i18nData.currentKeystones = tb.points
			i18nData.requiredKeystones = taxUnlock.unlockThreshold
		end
		return BAR.I18N(r .. ".default", i18nData)
	elseif case == TransferEnums.ResourceCommunicationCase.OnDisabled then
		-- Force base tree for disabled (tech doesn't hard-block resources, so it's a game state reason)
		return BAR.I18N(resBase .. ".base.disabled")
	elseif case == TransferEnums.ResourceCommunicationCase.OnTaxed then
		local i18nData = {
			amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
			amountSendable = FormatNumberForUI(policyResult.amountSendable),
			taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
		}
		if taxUnlock and tb then
			i18nData.nextRate = FormatNumberForUI((tonumber(taxUnlock.unlockValue) or 0) * 100)
			i18nData.nextTechLevel = taxUnlock.unlockLevel
			i18nData.currentKeystones = tb.points
			i18nData.requiredKeystones = taxUnlock.unlockThreshold
		end
		return BAR.I18N(r .. ".taxed", i18nData)
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

--- Send chat messages for completed resource transfers
---@param transferResult ResourceTransferResult
---@param policyResult ResourcePolicyResult
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

		local serialized = Cache.Serialize(Comms.SendTransferChatMessageProtocol, chatParams)
		-- Runs in synced (game_resource_transfer_controller). Spring.SendLuaRulesMsg only carries a
		-- real playerID when sent from a player's client, so from synced game_message would resolve an
		-- empty/wrong sender name and recipients' gui_chat would fail to classify it as an ally chat
		-- line, leaking the raw i18n key. Instead route straight to game_message's unsynced "sendMsg"
		-- action (dispatched by action name across gadgets), attributed to the sender team's player.
		local _, senderPlayerID = Spring.GetTeamInfo(policyResult.senderTeamId, false)
		if senderPlayerID and senderPlayerID >= 0 then
			SendToUnsynced("sendMsg", senderPlayerID, key .. ":" .. serialized)
		end
	end
end

return Comms
