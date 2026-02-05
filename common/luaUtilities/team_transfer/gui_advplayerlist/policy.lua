--- Policy helpers that keep gui_advplayerslist.lua under the Lua local closure cap
local GlobalEnums = VFS.Include("modes/global_enums.lua")
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
  local transferCategory = resourceType == "metal" and GlobalEnums.TransferCategory.MetalTransfer or
      GlobalEnums.TransferCategory.EnergyTransfer
  local policyResult = PolicyHelpers.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
  local pascalResourceType = resourceType == GlobalEnums.ResourceType.METAL and "Metal" or "Energy"
  return policyResult, pascalResourceType
end

---@param playerData table
---@param myTeamID number
---@param playerTeamID number
function PolicyHelpers.PackAllPoliciesForPlayer(playerData, myTeamID, playerTeamID)
  PolicyHelpers.PackMetalPolicyResult(playerTeamID, myTeamID, playerData)
  PolicyHelpers.PackEnergyPolicyResult(playerTeamID, myTeamID, playerData)

  local unitPolicy = UnitShared.GetCachedPolicyResult(myTeamID, playerTeamID, Spring)
  PolicyHelpers.PackPolicyResult(GlobalEnums.TransferCategory.UnitTransfer, unitPolicy, playerData)
end

---@param playerData table
---@param myTeamID number
---@param team number
---@return table, table, table
function PolicyHelpers.UnpackAllPolicies(playerData, myTeamID, team)
  local metalPolicy = PolicyHelpers.UnpackPolicyResult(GlobalEnums.TransferCategory.MetalTransfer, playerData, myTeamID,
      team)
  local energyPolicy = PolicyHelpers.UnpackPolicyResult(GlobalEnums.TransferCategory.EnergyTransfer, playerData, myTeamID,
      team)
  local unitPolicy = PolicyHelpers.UnpackUnitPolicyResult(playerData, myTeamID, team)
  return metalPolicy, energyPolicy, unitPolicy
end

---@param transferCategory string GlobalEnums.TransferCategory
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return table
function PolicyHelpers.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
  local fields, prefix, scratch
  if transferCategory == GlobalEnums.TransferCategory.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
    scratch = metalPlayerScratch
  elseif transferCategory == GlobalEnums.TransferCategory.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
    scratch = energyPlayerScratch
  elseif transferCategory == GlobalEnums.TransferCategory.UnitTransfer then
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
  return PolicyHelpers.UnpackPolicyResult(GlobalEnums.TransferCategory.UnitTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---@param transferCategory string GlobalEnums.TransferCategory
---@param policy table
---@param playerData table
function PolicyHelpers.PackPolicyResult(transferCategory, policy, playerData)
  local fields, prefix
  if transferCategory == GlobalEnums.TransferCategory.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
  elseif transferCategory == GlobalEnums.TransferCategory.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
  elseif transferCategory == GlobalEnums.TransferCategory.UnitTransfer then
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
  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, GlobalEnums.ResourceType.METAL)
  PolicyHelpers.PackPolicyResult(GlobalEnums.TransferCategory.MetalTransfer, policyResult, player)
end

---@param team number
---@param myTeamID number
---@param player table
function PolicyHelpers.PackEnergyPolicyResult(team, myTeamID, player)
  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, GlobalEnums.ResourceType.ENERGY)
  PolicyHelpers.PackPolicyResult(GlobalEnums.TransferCategory.EnergyTransfer, policyResult, player)
end

return PolicyHelpers

