--- Policy helpers that keep gui_advplayerslist.lua under the Lua local closure cap
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local METAL_POLICY_PREFIX = "metal_"
local ENERGY_POLICY_PREFIX = "energy_"
local UNIT_POLICY_PREFIX = "unit_"

local metalPlayerScratch = {}
local energyPlayerScratch = {}
local unitPlayerScratch = {}

local PolicyHelpers = {}

---@param player table
---@param resourceType string
---@param senderTeamId number
---@return ResourcePolicyResult policyResult, string pascalResourceType
function PolicyHelpers.GetPlayerResourcePolicy(player, resourceType, senderTeamId)
  local transferCategory = resourceType == SharedEnums.ResourceType.METAL and SharedEnums.PolicyType.MetalTransfer or
      SharedEnums.PolicyType.EnergyTransfer
  local policyResult = PolicyHelpers.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
  local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
  return policyResult, pascalResourceType
end

---@param playerData table
---@param myTeamID number
---@param playerTeamID number
function PolicyHelpers.PackAllPoliciesForPlayer(playerData, myTeamID, playerTeamID)
  PolicyHelpers.PackMetalPolicyResult(playerTeamID, myTeamID, playerData)
  PolicyHelpers.PackEnergyPolicyResult(playerTeamID, myTeamID, playerData)

  local unitPolicy = UnitShared.GetCachedPolicyResult(myTeamID, playerTeamID, Spring)
  PolicyHelpers.PackPolicyResult(SharedEnums.PolicyType.UnitTransfer, unitPolicy, playerData)
end

---@param playerData table
---@param myTeamID number
---@param team number
---@return table, table, table
function PolicyHelpers.UnpackAllPolicies(playerData, myTeamID, team)
  local metalPolicy = PolicyHelpers.UnpackPolicyResult(SharedEnums.PolicyType.MetalTransfer, playerData, myTeamID,
      team)
  local energyPolicy = PolicyHelpers.UnpackPolicyResult(SharedEnums.PolicyType.EnergyTransfer, playerData, myTeamID,
      team)
  local unitPolicy = PolicyHelpers.UnpackUnitPolicyResult(playerData, myTeamID, team)
  return metalPolicy, energyPolicy, unitPolicy
end

---@param transferCategory string SharedEnums.PolicyType
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return table
function PolicyHelpers.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
  local fields, prefix, scratch
  if transferCategory == SharedEnums.PolicyType.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
    scratch = metalPlayerScratch
  elseif transferCategory == SharedEnums.PolicyType.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
    scratch = energyPlayerScratch
  elseif transferCategory == SharedEnums.PolicyType.UnitTransfer then
    fields = UnitShared.UnitPolicyFields
    prefix = UNIT_POLICY_PREFIX
    scratch = unitPlayerScratch
  else
    error("Invalid transfer category: " .. transferCategory)
  end

  scratch.senderTeamId = senderTeamId
  scratch.receiverTeamId = receiverTeamId

  for field, _ in pairs(fields) do
    scratch[field] = playerData[prefix .. field]
  end
  return scratch
end

---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return UnitPolicyResult
function PolicyHelpers.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
  return PolicyHelpers.UnpackPolicyResult(SharedEnums.PolicyType.UnitTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---@param transferCategory string SharedEnums.PolicyType
---@param policy table
---@param playerData table
function PolicyHelpers.PackPolicyResult(transferCategory, policy, playerData)
  local fields, prefix
  if transferCategory == SharedEnums.PolicyType.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
  elseif transferCategory == SharedEnums.PolicyType.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
  elseif transferCategory == SharedEnums.PolicyType.UnitTransfer then
    fields = UnitShared.UnitPolicyFields
    prefix = UNIT_POLICY_PREFIX
  else
    error("Invalid transfer category: " .. transferCategory)
  end
  for field, _ in pairs(fields) do
    playerData[prefix .. field] = policy[field]
  end
end

---@param team number
---@param myTeamID number
---@param player table
function PolicyHelpers.PackMetalPolicyResult(team, myTeamID, player)
  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.METAL)
  PolicyHelpers.PackPolicyResult(SharedEnums.PolicyType.MetalTransfer, policyResult, player)
end

---@param team number
---@param myTeamID number
---@param player table
function PolicyHelpers.PackEnergyPolicyResult(team, myTeamID, player)
  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.ENERGY)
  PolicyHelpers.PackPolicyResult(SharedEnums.PolicyType.EnergyTransfer, policyResult, player)
end

return PolicyHelpers

