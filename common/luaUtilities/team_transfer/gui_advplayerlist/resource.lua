--- Resource transfer helpers kept separate to reduce gui_advplayerslist.lua locals
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")

---@param policyHelpers table
---@return table
return function(policyHelpers)
  local ResourceHelpers = {}

  ---Handle resource transfer logic for a players list entry
  ---@param targetPlayer table
  ---@param resourceType string
  ---@param shareAmount number
  ---@param senderTeamId number
  function ResourceHelpers.HandleResourceTransfer(targetPlayer, resourceType, shareAmount, senderTeamId)
    local policyResult, pascalResourceType = policyHelpers.GetPlayerPolicy(targetPlayer, resourceType, senderTeamId)

    local case = ResourceShared.DecideCommunicationCase(policyResult)

    if case == SharedEnums.ResourceCommunicationCase.OnSelf then
      if shareAmount > 0 then
        Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType .. 'Amount:amount:' .. shareAmount)
      else
        Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
      end
    elseif shareAmount and shareAmount > 0 then
      local msg = LuaRulesMsg.SerializeResourceShare(senderTeamId, targetPlayer.team, resourceType, shareAmount)
      Spring.SendLuaRulesMsg(msg)
    end
  end

  return ResourceHelpers
end
