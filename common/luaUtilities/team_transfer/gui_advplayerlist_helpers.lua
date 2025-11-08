--- holds helper functions for the gui_advplayerslist.lua
--- these are related to team transfer, but highly specific to the gui
--- gui_advplayerslist has severe restrictions on the number of local cosures due to lua 5.1's 200 cap
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local METAL_POLICY_PREFIX = "metal_"
local ENERGY_POLICY_PREFIX = "energy_"
local UNIT_POLICY_PREFIX = "unit_"
local UNIT_VALIDATION_PREFIX = "unit_validation_"

local metalPlayerScratch = {}
local energyPlayerScratch = {}
local unitPlayerScratch = {}
local validationResultScratch = {}

local UnitValidationFields = {
  status = true,
  invalidUnitCount = true,
  invalidUnitIds = true,
  invalidUnitNames = true,
  validUnitCount = true,
  validUnitIds = true,
  validUnitNames = true,
}

local Helpers = {}

---@param player table
---@param resourceType string
---@param senderTeamId number
---@return ResourcePolicyResult policyResult, string pascalResourceType
function Helpers.GetPlayerPolicy(player, resourceType, senderTeamId)
  local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or
  SharedEnums.TransferCategory.EnergyTransfer
  local policyResult = Helpers.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
  local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
  return policyResult, pascalResourceType
end

--- Handle resource transfer logic
---@param targetPlayer table
---@param resourceType string
---@param shareAmount number
---@param senderTeamId number
function Helpers.HandleResourceTransfer(targetPlayer, resourceType, shareAmount, senderTeamId)
  local policyResult, pascalResourceType = Helpers.GetPlayerPolicy(targetPlayer, resourceType, senderTeamId)

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

-- UI state packing functions for player data
---@param validationResult UnitValidationResult
---@param playerData table
function Helpers.PackSelectedUnitsValidation(validationResult, playerData)
  for field, _ in pairs(UnitValidationFields) do
    playerData[UNIT_VALIDATION_PREFIX .. field] = validationResult and validationResult[field] or nil
  end
end

---@param playerData table
function Helpers.ClearSelectedUnitsValidation(playerData)
  for field, _ in pairs(UnitValidationFields) do
    playerData[UNIT_VALIDATION_PREFIX .. field] = nil
  end
end

---@param playerData table
---@return UnitValidationResult | nil
function Helpers.UnpackSelectedUnitsValidation(playerData)
  if playerData[UNIT_VALIDATION_PREFIX .. "status"] == nil then
    return nil
  end
  local scratch = validationResultScratch
  for field, _ in pairs(UnitValidationFields) do
    scratch[field] = playerData[UNIT_VALIDATION_PREFIX .. field]
  end
  return scratch
end

---@param playerData table
---@param myTeamID number
---@param playerTeamID number
function Helpers.PackAllPoliciesForPlayer(playerData, myTeamID, playerTeamID)
  -- Pack all policy types for the player
  Helpers.PackMetalPolicyResult(playerTeamID, myTeamID, playerData)
  Helpers.PackEnergyPolicyResult(playerTeamID, myTeamID, playerData)

  -- For unit policy, we need to get it from cache and pack it
  local unitPolicy = UnitShared.GetCachedPolicyResult(myTeamID, playerTeamID, Spring)
  Helpers.PackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, unitPolicy, playerData)
end

---@param playerData table
---@param myTeamID number
---@param team number
---@return table, table, table
function Helpers.UnpackAllPolicies(playerData, myTeamID, team)
  local metalPolicy = Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, myTeamID, team)
  local energyPolicy = Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, myTeamID, team)
  local unitPolicy = Helpers.UnpackUnitPolicyResult(playerData, myTeamID, team)
  return metalPolicy, energyPolicy, unitPolicy
end

---Unpack policy result for a given transfer category
---@param transferCategory string SharedEnums.TransferCategory
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return table
function Helpers.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
  local fields, prefix, scratch
  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
    scratch = metalPlayerScratch
  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
    scratch = energyPlayerScratch
  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
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

---Unpack unit policy result from player data
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return UnitPolicyResult
function Helpers.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
  return Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---Pack policy result for a given transfer category
---@param transferCategory string SharedEnums.TransferCategory
---@param policy table
---@param playerData table
function Helpers.PackPolicyResult(transferCategory, policy, playerData)
  local fields, prefix
  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = METAL_POLICY_PREFIX
  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
    fields = ResourceShared.ResourcePolicyFields
    prefix = ENERGY_POLICY_PREFIX
  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
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
function Helpers.PackMetalPolicyResult(team, myTeamID, player)
  -- Get the metal policy and pack it
  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.METAL)
  Helpers.PackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, policyResult, player)
end

---@param team number
---@param myTeamID number
---@param player table
function Helpers.PackEnergyPolicyResult(team, myTeamID, player)
  -- Get the energy policy and pack it
  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.ENERGY)
  Helpers.PackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, policyResult, player)
end

-- Function to handle selection changes and update validations for all players
---@param player table -- The player table from gui_advplayerslist.lua
---@param myTeamID number
---@param selectedUnits number[]
function Helpers.UpdatePlayerUnitValidations(player, myTeamID, selectedUnits)
  for playerID, playerData in pairs(player) do
    if playerData.team and playerID ~= myTeamID then
      if selectedUnits and #selectedUnits > 0 then
        local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, playerData.team, Spring)
        local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits, Spring)
        Helpers.PackSelectedUnitsValidation(validationResult, playerData)
      else
        Helpers.ClearSelectedUnitsValidation(playerData)
      end
    end
  end
end

return Helpers
