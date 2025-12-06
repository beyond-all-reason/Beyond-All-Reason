local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")

local Synced = {
  ValidateUnits = Shared.ValidateUnits,
  GetModeUnitTypes = Shared.GetModeUnitTypes,
}

---Get per-pair policy (expose) and cache it for UI consumption
---@param ctx PolicyContext
---@return UnitPolicyResult
function Synced.GetPolicy(ctx)
  local mode = ctx.springRepo.GetModOptions().unit_sharing_mode
  local canShare = ctx.areAlliedTeams and mode ~= SharedEnums.UnitSharingMode.Disabled
  return {
    canShare = canShare,
    senderTeamId = ctx.senderTeamId,
    receiverTeamId = ctx.receiverTeamId,
    sharingMode = mode,
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
      outcome = SharedEnums.UnitValidationOutcome.Failure,
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

---@param springRepo ISpring
---@param senderId number
---@param receiverId number
---@param policyResult UnitPolicyResult
function Synced.CachePolicyResult(springRepo, senderId, receiverId, policyResult)
  local baseKey = PolicyShared.MakeBaseKey(receiverId, SharedEnums.TransferCategory.UnitTransfer)
  local serialized = Shared.SerializePolicy(policyResult)
  springRepo.SetTeamRulesParam(senderId, baseKey, serialized)
end

return Synced
