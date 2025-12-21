--- Unit validation helpers for advplayerslist.lua
local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")

local UNIT_VALIDATION_PREFIX = "unit_validation_"

local UnitValidationFields = {
  status = true,
  invalidUnitCount = true,
  invalidUnitIds = true,
  invalidUnitNames = true,
  validUnitCount = true,
  validUnitIds = true,
  validUnitNames = true,
}

local validationResultScratch = {}

local UnitValidationHelpers = {}

---@param validationResult UnitValidationResult
---@param playerData table
function UnitValidationHelpers.PackSelectedUnitsValidation(validationResult, playerData)
  for field, _ in pairs(UnitValidationFields) do
    playerData[UNIT_VALIDATION_PREFIX .. field] = validationResult and validationResult[field] or nil
  end
end

---@param playerData table
function UnitValidationHelpers.ClearSelectedUnitsValidation(playerData)
  for field, _ in pairs(UnitValidationFields) do
    playerData[UNIT_VALIDATION_PREFIX .. field] = nil
  end
end

---@param playerData table
---@return UnitValidationResult | nil
function UnitValidationHelpers.UnpackSelectedUnitsValidation(playerData)
  if playerData[UNIT_VALIDATION_PREFIX .. "status"] == nil then
    return nil
  end
  local scratch = validationResultScratch
  for field, _ in pairs(UnitValidationFields) do
    scratch[field] = playerData[UNIT_VALIDATION_PREFIX .. field]
  end
  return scratch
end

---@param player table
---@param myTeamID number
---@param selectedUnits number[]
function UnitValidationHelpers.UpdatePlayerUnitValidations(player, myTeamID, selectedUnits)
  for playerID, playerData in pairs(player) do
    if playerData.team and playerID ~= myTeamID then
      if selectedUnits and #selectedUnits > 0 then
        local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, playerData.team, Spring)
        local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits, Spring)
        UnitValidationHelpers.PackSelectedUnitsValidation(validationResult, playerData)
      else
        UnitValidationHelpers.ClearSelectedUnitsValidation(playerData)
      end
    end
  end
end

return UnitValidationHelpers

