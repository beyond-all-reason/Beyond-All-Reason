---@class UnitTransferGadget : Gadget
---@field TeamShare fun(self, srcTeamID: number, dstTeamID: number)
local gadget = gadget ---@type UnitTransferGadget

function gadget:GetInfo()
  return {
    name    = 'Unit Transfer Controller',
    desc    = 'Controls unit ownership changes: sharing, takeovers, AllowUnitTransfer',
    author  = 'Rimilel, Attean, Antigravity',
    date    = 'April 2024',
    license = 'GNU GPL, v2 or later',
    layer   = -200,
    enabled = true
  }
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
  return false
end

local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")

--------------------------------------------------------------------------------
-- GameUnitTransferController
-- Engine contract: AllowUnitTransfer and TeamShare are called by the engine.
-- GG.TransferUnit is a Lua-side convenience for other gadgets.
--------------------------------------------------------------------------------

---@type ISpring
local springRepo = Spring
local contextFactory = ContextFactoryModule.create(springRepo)

local POLICY_CACHE_UPDATE_RATE = 150 -- 5 seconds
local lastPolicyCacheUpdate = 0

GG = GG or {}

local UnitTransferController = {}

--------------------------------------------------------------------------------
-- Policy Cache
--------------------------------------------------------------------------------

---@param policyContext PolicyContext
---@return UnitPolicyResult
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
-- GG API (Lua-side conveniences for other gadgets)
--------------------------------------------------------------------------------

---@param unitID number
---@param newTeamID number
---@param given boolean?
function GG.TransferUnit(unitID, newTeamID, given)
  springRepo.TransferUnit(unitID, newTeamID, given or false)
end

--------------------------------------------------------------------------------
-- Engine Controller Functions
--------------------------------------------------------------------------------

---@param unitID number
---@param unitDefID number
---@param fromTeamID number
---@param toTeamID number
---@param capture boolean
---@return boolean
function UnitTransferController.AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
  if capture then
    return true
  end
  local policyResult = Shared.GetCachedPolicyResult(fromTeamID, toTeamID, springRepo)
  local given = false
  local validation = Shared.ValidateUnits(policyResult, { unitID }, springRepo)
  if validation and validation.status ~= SharedEnums.UnitValidationOutcome.Failure then
    local transferCtx = contextFactory.unitTransfer(fromTeamID, toTeamID, { unitID }, given, policyResult, validation)
    UnitTransfer.UnitTransfer(transferCtx)
  end

  return false
end

---@param srcTeamID number
---@param dstTeamID number
function UnitTransferController.TeamShare(srcTeamID, dstTeamID)
  Spring.Echo("[TeamShare] COMPLETE TAKEOVER src=" .. tostring(srcTeamID) .. " dst=" .. tostring(dstTeamID))
  
  local units = springRepo.GetTeamUnits(srcTeamID) or {}
  for _, unitID in ipairs(units) do
    springRepo.TransferUnit(unitID, dstTeamID, true)
  end
end

--------------------------------------------------------------------------------
-- Gadget Callins (bridge to controller)
--------------------------------------------------------------------------------

function gadget:Initialize()
  Spring.Echo("[UnitTransferController] Initialize starting...")
  
  local teams = springRepo.GetTeamList() or {}
  Spring.Echo("[UnitTransferController] Found " .. #teams .. " teams")
  for _, sender in ipairs(teams) do
    for _, receiver in ipairs(teams) do
      InitializeNewTeam(sender, receiver)
    end
  end
  lastPolicyCacheUpdate = springRepo.GetGameFrame()
  
  -- Register the unit transfer controller with the engine
  -- Engine contract: AllowUnitTransfer and TeamShare are required
  Spring.Echo("[UnitTransferController] Registering GameUnitTransferController...")
  if Spring.SetUnitTransferController then
    ---@type GameUnitTransferController
    local controller = {
      AllowUnitTransfer = UnitTransferController.AllowUnitTransfer,
      TeamShare = UnitTransferController.TeamShare
    }
    Spring.SetUnitTransferController(controller)
    Spring.Echo("[UnitTransferController] SUCCESS: Registered GameUnitTransferController")
  else
    Spring.Echo("[UnitTransferController] WARNING: Spring.SetUnitTransferController not available - using gadget callins")
  end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
  return UnitTransferController.AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
end

function gadget:TeamShare(srcTeamID, dstTeamID)
  UnitTransferController.TeamShare(srcTeamID, dstTeamID)
end

function gadget:GameFrame(frame)
  UpdatePolicyCache(frame)
end
