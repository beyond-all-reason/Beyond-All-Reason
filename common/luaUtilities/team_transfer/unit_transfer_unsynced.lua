local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")

local Unsynced = {}

---Share currently selected units to target team (mirrors Spring.ShareResources behavior)
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

