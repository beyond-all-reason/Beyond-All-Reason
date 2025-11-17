--- Resource transfer helpers kept separate to reduce gui_advplayerslist.lua locals
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

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
        Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType .. 'Amount:amount=' .. shareAmount)
      else
        Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
      end
    else
      if shareAmount and shareAmount > 0 then
        Spring.ShareResources(targetPlayer.team, resourceType, shareAmount)
      end
    end
  end

  return ResourceHelpers
end

