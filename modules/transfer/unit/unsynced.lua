local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")

local Unsynced = {}

---Share selected units to target team; synced controller re-validates, so just forward the selection.
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
