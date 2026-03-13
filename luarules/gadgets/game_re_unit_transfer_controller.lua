---@class REUnitTransferGadget : Gadget
local gadget = gadget ---@type REUnitTransferGadget

function gadget:GetInfo()
  return {
    name    = 'RE Unit Transfer Controller',
    desc    = 'Controls unit ownership changes via standard gadget callins (ResourceExcess path)',
    author  = 'Rimilel, Attean, Antigravity',
    date    = '2025',
    license = 'GNU GPL, v2 or later',
    layer   = -200,
    enabled = not Game.gameEconomy,
  }
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
  return false
end

local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")

local function shouldStunUnit(unitDefID, stunCategory)
  if not stunCategory then
    return false
  end
  return Shared.IsShareableDef(unitDefID, stunCategory, UnitDefs)
end

local function applyStun(unitID, unitDefID, policyResult)
  local stunSeconds = tonumber(policyResult.stunSeconds) or 0
  if stunSeconds <= 0 then
    return
  end
  local stunCategory = policyResult.stunCategory
  if not shouldStunUnit(unitDefID, stunCategory) then
    return
  end
  local _, maxHealth = Spring.GetUnitHealth(unitID)
  local paralyzeFrames = stunSeconds * 30
  Spring.AddUnitDamage(unitID, maxHealth * 5, paralyzeFrames)
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

---@type SpringSynced
local springRepo = Spring
local contextFactory = ContextFactoryModule.create(springRepo)

local POLICY_CACHE_UPDATE_RATE = 150
local lastPolicyCacheUpdate = 0

GG = GG or {}

--------------------------------------------------------------------------------
-- Policy Cache
--------------------------------------------------------------------------------

local function BuildPolicyCache(policyContext)
  local policyResult = UnitTransfer.GetPolicy(policyContext)
  UnitTransfer.CachePolicyResult(
    springRepo,
    policyContext.senderTeamId,
    policyContext.receiverTeamId,
    policyResult
  )
  return policyResult
end

local function InitializeNewTeam(senderTeamId, receiverTeamId)
  local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
  BuildPolicyCache(ctx)
end

local function UpdatePolicyCache(frame)
  if frame < lastPolicyCacheUpdate + POLICY_CACHE_UPDATE_RATE then
    return
  end
  lastPolicyCacheUpdate = frame
  
  local teamList = springRepo.GetTeamList() or {}
  for _, senderTeamId in ipairs(teamList) do
    for _, receiverTeamId in ipairs(teamList) do
      local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
      BuildPolicyCache(ctx)
    end
  end
end

--------------------------------------------------------------------------------
-- GG API
--------------------------------------------------------------------------------

function GG.TransferUnit(unitID, newTeamID, given)
  springRepo.TransferUnit(unitID, newTeamID, given or false)
end

function GG.TransferUnits(unitIDs, newTeamID, given)
  local transferred = 0
  for _, unitID in ipairs(unitIDs) do
    local success = springRepo.TransferUnit(unitID, newTeamID, given or false)
    if success then
      transferred = transferred + 1
    end
  end
  return transferred
end

function GG.ShareUnits(senderTeamID, targetTeamID, unitIDs)
  local policyResult = Shared.GetCachedPolicyResult(senderTeamID, targetTeamID, springRepo)
  local validation = Shared.ValidateUnits(policyResult, unitIDs, springRepo)
  
  if not validation or validation.status == TransferEnums.UnitValidationOutcome.Failure then
    return {
      success = false,
      outcome = validation and validation.status or TransferEnums.UnitValidationOutcome.Failure,
      senderTeamId = senderTeamID,
      receiverTeamId = targetTeamID,
      validationResult = validation or { validUnitIds = {}, invalidUnitIds = unitIDs, status = TransferEnums.UnitValidationOutcome.Failure },
      policyResult = policyResult
    }
  end
  
  local transferCtx = contextFactory.unitTransfer(senderTeamID, targetTeamID, unitIDs, true, policyResult, validation)
  local result = UnitTransfer.UnitTransfer(transferCtx)
  
  local outcome = result.outcome
  if outcome == TransferEnums.UnitValidationOutcome.Success or outcome == TransferEnums.UnitValidationOutcome.PartialSuccess then
    Spring.SendLuaUIMsg("unit_transfer:success:" .. senderTeamID)
  else
    Spring.SendLuaUIMsg("unit_transfer:failed:" .. senderTeamID)
  end
  
  return result
end

--------------------------------------------------------------------------------
-- Gadget callins (standard AllowUnitTransfer, no SetUnitTransferController)
--------------------------------------------------------------------------------

function gadget:Initialize()
  
  local teams = springRepo.GetTeamList() or {}
  for _, sender in ipairs(teams) do
    for _, receiver in ipairs(teams) do
      InitializeNewTeam(sender, receiver)
    end
  end
  lastPolicyCacheUpdate = springRepo.GetGameFrame()
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
  if capture then
    return true
  end
  
  local policyResult = Shared.GetCachedPolicyResult(fromTeamID, toTeamID, springRepo)
  local validation = Shared.ValidateUnits(policyResult, { unitID }, springRepo)
  local allowed = validation and validation.status ~= TransferEnums.UnitValidationOutcome.Failure
  
  if allowed and policyResult then
    applyStun(unitID, unitDefID, policyResult)
  end
  
  return allowed
end

function gadget:RecvLuaMsg(msg, playerID)
  local params = LuaRulesMsg.ParseUnitTransfer(msg)
  if params then
    local _, _, _, senderTeamID = springRepo.GetPlayerInfo(playerID, false)
    if senderTeamID then
      GG.ShareUnits(senderTeamID, params.targetTeamID, params.unitIDs)
    end
    return true
  end
  return false
end

function gadget:GameFrame(frame)
  UpdatePolicyCache(frame)
end
