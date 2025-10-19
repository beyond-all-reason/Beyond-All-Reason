local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local TeamTransferCache = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")

local ResourceComms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local UnitComms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")

local metalPolicyScratch = {}
local energyPolicyScratch = {}
local unitPolicyScratch = {}
local selectedUnitsValidationScratch = {}

local METAL_POLICY_PREFIX = "metalPolicy_"
local ENERGY_POLICY_PREFIX = "energyPolicy_"
local UNIT_POLICY_PREFIX = "unitPolicy_"
local SELECTED_UNITS_VALIDATION_PREFIX = "selectedUnitsValidation_"
local SELECTED_UNITS_VALIDATION_FIELDS = {
  "status",
  "validUnitCount",
  "validUnitIds",
  "invalidUnitCount",
  "invalidUnitIds",
  "validUnitNames",
  "invalidUnitNames"
}

local ResourceWidgets = {
  CalculateSenderTaxedAmount = ResourceShared.CalculateSenderTaxedAmount,
  FormatNumberForUI = ResourceComms.FormatNumberForUI,
  CommunicationCase = SharedEnums.ResourceCommunicationCase,
  GetCachedPolicyResult = ResourceShared.GetCachedPolicyResult,
  ResourceTypes = SharedEnums.ResourceTypes,
  DecideCommunicationCase = ResourceComms.DecideCommunicationCase,
  TooltipText = ResourceComms.TooltipText,
  SendTransferChatMessages = ResourceComms.SendTransferChatMessages,
}
ResourceWidgets.__index = ResourceWidgets

local UnitWidgets = {
  GetCachedPolicyResult = UnitShared.GetCachedPolicyResult,
  ValidateUnits = UnitShared.ValidateUnits,
  DecideCommunicationCase = UnitComms.DecideCommunicationCase,
  TooltipText = UnitComms.UnitShareTooltip,
}
UnitWidgets.__index = UnitWidgets

local TeamTransfer = {
  Resources = ResourceWidgets,
  Units = UnitWidgets,
}

--------------------------------------------------------
--- Resource Transfer
--------------------------------------------------------

---@param player table
---@param resourceType string
---@param senderTeamId number
---@return ResourcePolicyResult policyResult
function ResourceWidgets.GetPlayerPolicy(player, resourceType, senderTeamId)
  local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
  local policyResult = TeamTransfer.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
  return policyResult
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
  else
    if shareAmount and shareAmount > 0 then
      Spring.ShareResources(targetPlayer.team, resourceType, shareAmount)
    end
  end
end

--------------------------------------------------------
--- gui_advplayerlist.lua helper functions
--------------------------------------------------------

---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return ResourcePolicyResult? metalPolicy, ResourcePolicyResult? energyPolicy, UnitPolicyResult? unitPolicy
function TeamTransfer.UnpackAllPolicies(playerData, senderTeamId, receiverTeamId)
  local hasPackedData = playerData[METAL_POLICY_PREFIX .. "canShare"] ~= nil
  if not hasPackedData then return nil, nil, nil end

  local metalPolicy = TeamTransfer.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
  local energyPolicy = TeamTransfer.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
  local unitPolicy = TeamTransfer.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)

  return metalPolicy, energyPolicy, unitPolicy
end

---Unpack selected units validation result from player data
---@param playerData table
---@return UnitValidationResult
function TeamTransfer.UnpackSelectedUnitsValidation(playerData)
  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
    selectedUnitsValidationScratch[field] = playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field]
  end
  return selectedUnitsValidationScratch
end

---Pack selected units validation result into player data
---@param validationResult table
---@param playerData table
function TeamTransfer.PackSelectedUnitsValidation(validationResult, playerData)
  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
    playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field] = validationResult[field]
  end
end

---Clear selected units validation result from player data
---@param playerData table
function TeamTransfer.ClearSelectedUnitsValidation(playerData)
  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
    playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field] = nil
  end
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
  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
    scratch = unitPolicyScratch
    fields = UnitShared.UnitPolicyFields
    prefix = UNIT_POLICY_PREFIX
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
function TeamTransfer.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---Unpack energy policy result from player data
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return ResourcePolicyResult
function TeamTransfer.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, senderTeamId,
    receiverTeamId)
end

---Unpack unit policy result from player data
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
---@return UnitPolicyResult
function TeamTransfer.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
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

---Pack unit policy result into player data
---@param senderTeamId number
---@param receiverTeamId number
---@param playerData table
function TeamTransfer.PackUnitPolicyResult(senderTeamId, receiverTeamId, playerData)
  local policy = UnitWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId)
  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, policy, playerData)
end

--- Pack all policies for a given player
---@param playerData table
---@param senderTeamId number
---@param receiverTeamId number
function TeamTransfer.PackAllPoliciesForPlayer(playerData, senderTeamId, receiverTeamId)
  TeamTransfer.PackMetalPolicyResult(senderTeamId, receiverTeamId, playerData)
  TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playerData)
  TeamTransfer.PackUnitPolicyResult(senderTeamId, receiverTeamId, playerData)
end

return TeamTransfer
