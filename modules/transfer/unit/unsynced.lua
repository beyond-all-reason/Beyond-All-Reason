local Spring = Spring

local LuaRulesMsg = require("modules/transfer/lib/lua_rules_msg")
local Shared = require("modules/transfer/unit/shared")

local Unsynced = {}

-- The terms the policy gives the local team for sharing units with another, as the synced side published them: a
-- widget asks before it offers the action.
---@param targetTeamID integer
---@return UnitTransferTerms
function Unsynced.Terms(targetTeamID)
	return Shared.GetCachedTerms(Spring.GetMyTeamID(), targetTeamID, Spring)
end

-- Which of these units the terms let through, and why the others would not go.
---@param terms UnitTransferTerms
---@param unitIDs integer[]
---@return TransferUnitValidation
function Unsynced.Validate(terms, unitIDs)
	return Shared.ValidateUnits(terms, unitIDs, Spring)
end

Unsynced.TooltipText = Shared.TooltipText
Unsynced.DecideCommunicationCase = Shared.DecideCommunicationCase

---@param targetTeamID number
function Unsynced.ShareUnits(targetTeamID)
	local unitIDs = Spring.GetSelectedUnits()
	if #unitIDs == 0 then
		return
	end
	local msg = LuaRulesMsg.SerializeUnitTransfer(targetTeamID, unitIDs)
	Spring.SendLuaRulesMsg(msg)
end

return Unsynced
