local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local TeamTransferCache = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")

local ResourceComms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local metalPolicyScratch = {}
local energyPolicyScratch = {}

local METAL_POLICY_PREFIX = "metalPolicy_"
local ENERGY_POLICY_PREFIX = "energyPolicy_"

local ResourceWidgets = {
  CalculateSenderTaxedAmount = ResourceShared.CalculateSenderTaxedAmount,
  CommunicationCase = SharedEnums.ResourceCommunicationCase,
  DecideCommunicationCase = ResourceShared.DecideCommunicationCase,
  GetCachedPolicyResult = ResourceShared.GetCachedPolicyResult,
  ResourceTypes = SharedEnums.ResourceTypes,
  TooltipText = ResourceComms.TooltipText,
  SendTransferChatMessages = ResourceComms.SendTransferChatMessages,
}
ResourceWidgets.__index = ResourceWidgets

--------------------------------------------------------
--- Resource Transfer
--------------------------------------------------------

--- Get policy result and pascal resource type for a player
---@param player table
---@param resourceType string
---@param senderTeamId number
---@return ResourcePolicyResult policyResult, string pascalResourceType
function ResourceWidgets.GetPlayerPolicy(player, resourceType, senderTeamId)
  local pascalResourceType = resourceType:gsub("^%l", string.upper)
  local prefix = resourceType == "metal" and METAL_POLICY_PREFIX or ENERGY_POLICY_PREFIX
  local policyResult = ResourceWidgets.UnpackPolicyResult(player, prefix, senderTeamId, player.team)
  return policyResult, pascalResourceType
end

--- Handle resource transfer logic
---@param targetPlayer table
---@param resourceType string
---@param shareAmount number
---@param senderTeamId number
function ResourceWidgets.HandleResourceTransfer(targetPlayer, resourceType, shareAmount, senderTeamId)
  local policyResult, pascalResourceType = ResourceWidgets.GetPlayerPolicy(targetPlayer, resourceType, senderTeamId)

  local case = ResourceWidgets.DecideCommunicationCase(policyResult)

  if case == ResourceWidgets.CommunicationCase.OnSelf then
    if shareAmount > 0 then
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType .. 'Amount:amount=' .. shareAmount)
    else
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
    end
  end

  if shareAmount and shareAmount > 0 then
    Spring.ShareResources(targetPlayer.team, resourceType, shareAmount)
  end
end

--------------------------------------------------------
--- gui_advplayerlist.lua helper functions
--------------------------------------------------------

---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return ResourcePolicyResult? metalPolicy, ResourcePolicyResult? energyPolicy, UnitTransferPolicyResult? unitPolicy
function TeamTransfer.UnpackAllPolicies(playerData, senderTeamId, receiverTeamId)
  local hasPackedData = playerData[METAL_POLICY_PREFIX .. "canShare"] ~= nil
  if not hasPackedData then return nil, nil, nil end

  local metalPolicy = TeamTransfer.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
  local energyPolicy = TeamTransfer.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)

  return metalPolicy, energyPolicy
end


---This and its sibling hydrate existing tables with a policyResult so we don't thrash GC
---@param transferCategory string SharedEnums.TransferCategory
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
function TeamTransfer.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
  local scratch, fields, prefix
  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
    scratch = metalPolicyScratch
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
    scratch = energyPolicyScratch
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
  end
  scratch.senderTeamId = senderTeamId
  scratch.receiverTeamId = receiverTeamId
  for field, _ in pairs(fields) do
    scratch[field] = playerData[prefix .. field]
  end
  return scratch
end

---Unpack metal policy result from player data
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return ResourcePolicyResult
function ResourceWidgets.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---Unpack energy policy result from player data
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return ResourcePolicyResult
function ResourceWidgets.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---Unpack unit policy result from player data
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return UnitTransferPolicyResult
function UnitWidgets.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---Pack policy result for a given transfer category
---@param transferCategory string SharedEnums.TransferCategory
---@param policy table
---@param playerData table
function TeamTransfer.PackPolicyResult(transferCategory, policy, playerData)
  local fields, prefix
  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
  end
  for field, _ in pairs(fields) do
    playerData[prefix .. field] = policy[field]
  end
end

---Pack metal policy result into player data
---@param senderTeamId number
---@param receiverTeamId number
---@param playerData table
function TeamTransfer.PackMetalPolicyResult(senderTeamId, receiverTeamId, playerData)
  local policy = ResourceWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId, "metal")
  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, policy, playerData)
end

---Pack energy policy result into player data
---@param senderTeamId number
---@param receiverTeamId number
---@param playerData table
function TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playerData)
  local policy = ResourceWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId, "energy")
  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, policy, playerData)
end

--- Pack all policies for a given player
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
function TeamTransfer.PackAllPoliciesForPlayer(playerData, senderTeamId, receiverTeamId)
  TeamTransfer.PackMetalPolicyResult(senderTeamId, receiverTeamId, playerData)
  TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playerData)
end

return TeamTransfer
