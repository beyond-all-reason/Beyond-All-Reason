local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name    = 'Unit Sharing Mode',
    desc    = 'Controls which units can be shared with allies',
    author  = 'Rimilel, Attean',
    date    = 'April 2024',
    license = 'GNU GPL, v2 or later',
    layer   = 1,
    enabled = true
  }
end

local POLICY_CACHE_TAINT_FRAME_RATE_HEAVY = 150 --5 seconds

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
  return false
end

local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")

------------------------------------------------
--- Initialization
------------------------------------------------

local contextFactory = ContextFactoryModule.create(Spring)

local lastGameFrameCacheUpdate = 0

---@param policyContext PolicyContext
---@return UnitPolicyResult
function BuildPolicyCache(policyContext)
  local policyResult = UnitTransfer.GetPolicy(policyContext)
  UnitTransfer.CachePolicyResult(
    Spring,
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

function gadget:Initialize()
  local teams = Spring.GetTeamList() or {}
  for _, sender in ipairs(teams) do
    for _, receiver in ipairs(teams) do
      InitializeNewTeam(sender, receiver)
    end
  end
  lastGameFrameCacheUpdate = Spring.GetGameFrame()
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
  if capture then
    return true
  end
  local policyResult = Shared.GetCachedPolicyResult(fromTeamID, toTeamID)
  local given = false
  local validation = Shared.ValidateUnits(policyResult, { unitID })
  if validation and validation.status ~= SharedEnums.UnitValidationOutcome.Failure then
    local transferCtx = contextFactory.unitTransfer(fromTeamID, toTeamID, { unitID }, given, policyResult, validation)
    UnitTransfer.UnitTransfer(transferCtx)
  end

  return false
end

function gadget:GameFrame(frame)
  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE_HEAVY
  if frame < nextSchedHeavy then
    return
  end
  local teamList = Spring.GetTeamList() or {}
  lastGameFrameCacheUpdate = frame
  -- Update policies for all team pairs to ensure UI has current alliance status
  for _, senderTeamId in ipairs(teamList) do
    for _, receiverTeamId in ipairs(teamList) do
      local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
      BuildPolicyCache(ctx)
    end
  end
end
