--- Policy helpers that keep gui_advplayerslist.lua under the Lua local closure cap
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
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
  local transferCategory = resourceType == "metal" and TransferEnums.TransferCategory.MetalTransfer or
      TransferEnums.TransferCategory.EnergyTransfer
  local policyResult = PolicyHelpers.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
  local pascalResourceType = resourceType == TransferEnums.ResourceType.METAL and "Metal" or "Energy"
  return policyResult, pascalResourceType
end

---@param playerData table
---@param myTeamID number
---@param playerTeamID number
function PolicyHelpers.PackAllPoliciesForPlayer(playerData, myTeamID, playerTeamID)
  PolicyHelpers.PackMetalPolicyResult(playerTeamID, myTeamID, playerData)
  PolicyHelpers.PackEnergyPolicyResult(playerTeamID, myTeamID, playerData)

  local unitPolicy = UnitShared.GetCachedPolicyResult(myTeamID, playerTeamID, Spring)
  PolicyHelpers.PackPolicyResult(TransferEnums.TransferCategory.UnitTransfer, unitPolicy, playerData)
end

---@param playerData table
---@param myTeamID number
---@param team number
---@return table, table, table
function PolicyHelpers.UnpackAllPolicies(playerData, myTeamID, team)
  local metalPolicy = PolicyHelpers.UnpackPolicyResult(TransferEnums.TransferCategory.MetalTransfer, playerData, myTeamID,
      team)
  local energyPolicy = PolicyHelpers.UnpackPolicyResult(TransferEnums.TransferCategory.EnergyTransfer, playerData, myTeamID,
      team)
  local unitPolicy = PolicyHelpers.UnpackUnitPolicyResult(playerData, myTeamID, team)
  return metalPolicy, energyPolicy, unitPolicy
end

---@param transferCategory string TransferEnums.TransferCategory
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return table
function PolicyHelpers.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
  local fields, prefix, scratch
  if transferCategory == TransferEnums.TransferCategory.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
    scratch = metalPlayerScratch
  elseif transferCategory == TransferEnums.TransferCategory.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
    scratch = energyPlayerScratch
  elseif transferCategory == TransferEnums.TransferCategory.UnitTransfer then
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
  return PolicyHelpers.UnpackPolicyResult(TransferEnums.TransferCategory.UnitTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---@param transferCategory string TransferEnums.TransferCategory
---@param policy table
---@param playerData table
function PolicyHelpers.PackPolicyResult(transferCategory, policy, playerData)
  local fields, prefix
  if transferCategory == TransferEnums.TransferCategory.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
  elseif transferCategory == TransferEnums.TransferCategory.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
  elseif transferCategory == TransferEnums.TransferCategory.UnitTransfer then
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
  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, TransferEnums.ResourceType.METAL)
  PolicyHelpers.PackPolicyResult(TransferEnums.TransferCategory.MetalTransfer, policyResult, player)
end

---@param team number
---@param myTeamID number
---@param player table
function PolicyHelpers.PackEnergyPolicyResult(team, myTeamID, player)
  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, TransferEnums.ResourceType.ENERGY)
  PolicyHelpers.PackPolicyResult(TransferEnums.TransferCategory.EnergyTransfer, policyResult, player)
end

return PolicyHelpers

