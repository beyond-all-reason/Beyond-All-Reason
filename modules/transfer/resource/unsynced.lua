-- Transfer's resource api in the unsynced handle: what a widget may ask about sharing a resource, and the share.
local Spring = Spring --[[@as Recoil.Unsynced]]
local Comms = require("modules/transfer/resource/comms")
local LuaRulesMsg = require("modules/transfer/lib/lua_rules_msg")
local Shared = require("modules/transfer/resource/shared")
local TransferEnums = require("modules/transfer/enums")

local Unsynced = {}

-- The terms the policy gives the local team for sharing a resource with another, evaluated here and now: whether it
-- may, and at what tax, so a widget can say so before anything is sent.
---@param targetTeamID integer
---@param resourceType ResourceName
---@return ResourceTransferTerms the policy's answer for the local team and that one, evaluated now
function Unsynced.Terms(targetTeamID, resourceType)
	return Shared.Terms(Spring.GetMyTeamID(), targetTeamID, resourceType, Spring)
end

-- A share of the local team's resource, asked of the synced side, which does it under the terms and tells the
-- sender what moved.
---@param targetTeamID integer
---@param resourceType ResourceName
---@param amount number
function Unsynced.Share(targetTeamID, resourceType, amount)
	if amount == nil or amount <= 0 then
		return
	end
	Spring.SendLuaRulesMsg(LuaRulesMsg.SerializeResourceShare(Spring.GetMyTeamID(), targetTeamID, resourceType, amount))
end

Unsynced.TooltipText = Comms.TooltipText
Unsynced.CaseOf = Shared.CaseOf
Unsynced.FormatNumberForUI = Comms.FormatNumberForUI
Unsynced.CalculateSenderTaxedAmount = Shared.CalculateSenderTaxedAmount
Unsynced.TermsCase = TransferEnums.ResourceTermsCase
-- Which fields of the module's share chat lines carry an amount worth colouring (false: a rate, plain).
Unsynced.ChatHighlights = Comms.SendTransferChatMessageProtocolHighlights

return Unsynced
