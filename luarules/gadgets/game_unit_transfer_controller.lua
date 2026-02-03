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

local SharedEnums = VFS.Include("modes/global_enums.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")

local economicGroups = {
  energy = true,
  metal = true,
}

local builderGroups = {
  builder = true,
  buildert2 = true,
  buildert3 = true,
}

local function shouldStunUnit(unitDefID, stunCategory)
  if stunCategory == SharedEnums.UnitStunCategory.All then
    return true
  end
  if stunCategory == SharedEnums.UnitStunCategory.Disabled then
    return false
  end

  local unitDef = UnitDefs[unitDefID]
  local group = unitDef and unitDef.customParams and unitDef.customParams.unitgroup
  if not group then
    return false
  end

  if stunCategory == SharedEnums.UnitStunCategory.Economic then
    return economicGroups[group]
  elseif stunCategory == SharedEnums.UnitStunCategory.Builders then
    return builderGroups[group]
  elseif stunCategory == SharedEnums.UnitStunCategory.EconomicAndBuilders then
    return economicGroups[group] or builderGroups[group]
  end

  return false
end

local function applyStun(unitID, unitDefID, policyResult)
  if policyResult.stunSeconds <= 0 then
    return
  end
  if not shouldStunUnit(unitDefID, policyResult.stunCategory) then
    return
  end
  local _, maxHealth = Spring.GetUnitHealth(unitID)
  Spring.AddUnitDamage(unitID, maxHealth * 5, policyResult.stunSeconds)
end

--------------------------------------------------------------------------------
-- GameUnitTransferController
-- Engine contract: AllowUnitTransfer and TeamShare (registered via SetUnitTransferController)
-- Game API: GG.ShareUnits is the public API for synced gadgets and unsynced (via LuaSendMsg)
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

---@param unitIDs number[]
---@param newTeamID number
---@param given boolean?
---@return number transferred count of successfully transferred units
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

---@param senderTeamID number
---@param targetTeamID number
---@param unitIDs number[]
---@return UnitTransferResult
function GG.ShareUnits(senderTeamID, targetTeamID, unitIDs)
  local policyResult = Shared.GetCachedPolicyResult(senderTeamID, targetTeamID, springRepo)
  local validation = Shared.ValidateUnits(policyResult, unitIDs, springRepo)
  
  if not validation or validation.status == SharedEnums.UnitValidationOutcome.Failure then
    Spring.Echo(string.format("[UnitTransferController] Transfer denied: policy.canShare=%s validation.status=%s",
      tostring(policyResult and policyResult.canShare),
      tostring(validation and validation.status)))
    ---@type UnitTransferResult
    return {
      success = false,
      outcome = validation and validation.status or SharedEnums.UnitValidationOutcome.Failure,
      senderTeamId = senderTeamID,
      receiverTeamId = targetTeamID,
      validationResult = validation or { validUnitIds = {}, invalidUnitIds = unitIDs, status = SharedEnums.UnitValidationOutcome.Failure },
      policyResult = policyResult
    }
  end
  
  local transferCtx = contextFactory.unitTransfer(senderTeamID, targetTeamID, unitIDs, true, policyResult, validation)
  local result = UnitTransfer.UnitTransfer(transferCtx)
  
  Spring.Echo(string.format("[UnitTransferController] Transfer result: outcome=%s valid=%d invalid=%d", 
    tostring(result.outcome), 
    #(result.validationResult.validUnitIds or {}),
    #(result.validationResult.invalidUnitIds or {})))
  
  return result
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
  local validation = Shared.ValidateUnits(policyResult, { unitID }, springRepo)
  
  local allowed = validation and validation.status ~= SharedEnums.UnitValidationOutcome.Failure
  
  if allowed and policyResult then
    applyStun(unitID, unitDefID, policyResult)
  end
  
  return allowed
end

---@param srcTeamID number
---@param dstTeamID number
function UnitTransferController.TeamShare(srcTeamID, dstTeamID)
  Spring.Echo("[TeamShare] WARNING: Full team takeover triggered! src=" .. tostring(srcTeamID) .. " dst=" .. tostring(dstTeamID))
  Spring.Echo("[TeamShare] This should only happen on player resignation or /take command")
  
  local units = springRepo.GetTeamUnits(srcTeamID) or {}
  Spring.Echo("[TeamShare] Transferring " .. #units .. " units")
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

function gadget:RecvLuaMsg(msg, playerID)
  local params = LuaRulesMsg.ParseUnitTransfer(msg)
  if params then
    local _, _, _, senderTeamID = springRepo.GetPlayerInfo(playerID, false)
    if senderTeamID then
      Spring.Echo(string.format("[UnitTransferController] RecvLuaMsg: player=%d team=%d -> target=%d units=%d", 
        playerID, senderTeamID, params.targetTeamID, #params.unitIDs))
      GG.ShareUnits(senderTeamID, params.targetTeamID, params.unitIDs)
    end
    return true
  end
  return false
end

function gadget:GameFrame(frame)
  UpdatePolicyCache(frame)
end
