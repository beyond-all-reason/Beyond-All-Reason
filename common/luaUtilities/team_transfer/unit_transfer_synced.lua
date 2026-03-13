local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_serialization_helpers.lua")

local Synced = {
  ValidateUnits = Shared.ValidateUnits,
  GetModeUnitTypes = Shared.GetModeUnitTypes,
}

---Get per-pair policy (expose) and cache it for UI consumption
---@param ctx PolicyContext
---@return UnitPolicyResult
function Synced.GetPolicy(ctx)
  local modOptions = ctx.springRepo.GetModOptions()
  local modes = ctx.unitSharingModes or { modOptions.unit_sharing_mode or ModeEnums.UnitFilterCategory.None }
  local canShare = ctx.areAlliedTeams and not (#modes == 1 and modes[1] == ModeEnums.UnitFilterCategory.None)
  local stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0
  local stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource
  return {
    canShare = canShare,
    senderTeamId = ctx.senderTeamId,
    receiverTeamId = ctx.receiverTeamId,
    sharingModes = modes,
    stunSeconds = stunSeconds,
    stunCategory = stunCategory,
    techBlocking = ctx.ext and ctx.ext.techBlocking or nil,
  }
end

---Execute unit transfer with pre-validated units
---@param ctx UnitTransferContext
---@return UnitTransferResult
function Synced.UnitTransfer(ctx)
  local policyResult = ctx.policyResult

  if not policyResult.canShare then
    ---@type UnitTransferResult
    return {
      success = false,
      outcome = TransferEnums.UnitValidationOutcome.Failure,
      senderTeamId = ctx.senderTeamId,
      receiverTeamId = ctx.receiverTeamId,
      validationResult = ctx.validationResult,
      policyResult = ctx.policyResult
    }
  end

  local transferredUnits = {}
  local failedUnits = {}

  for _, unitId in ipairs(ctx.validationResult.validUnitIds) do
    -- ctx.given should always be false here because we short-circuit inside AllowResourceTransfer
    local success = ctx.springRepo.TransferUnit(unitId, ctx.receiverTeamId, ctx.given)
    if success then
      table.insert(transferredUnits, unitId)
    else
      table.insert(failedUnits, unitId)
    end
  end

  for _, unitId in ipairs(ctx.validationResult.invalidUnitIds) do
    table.insert(failedUnits, unitId)
  end

  ---@type UnitTransferResult
  return {
    outcome = ctx.validationResult.status,
    senderTeamId = ctx.senderTeamId,
    receiverTeamId = ctx.receiverTeamId,
    validationResult = ctx.validationResult,
    policyResult = ctx.policyResult
  }
end

---@param springRepo SpringSynced
---@param senderId number
---@param receiverId number
---@param policyResult UnitPolicyResult
function Synced.CachePolicyResult(springRepo, senderId, receiverId, policyResult)
  local baseKey = PolicyShared.MakeBaseKey(receiverId, TransferEnums.TransferCategory.UnitTransfer)
  local serialized = Shared.SerializePolicy(policyResult)
  springRepo.SetTeamRulesParam(senderId, baseKey, serialized)
end

return Synced
