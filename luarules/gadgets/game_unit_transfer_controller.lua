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

local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")
local PolicyEvents = VFS.Include("common/luaUtilities/team_transfer/policy_events.lua")

local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

-- mobile builders get buildspeed-0 debuff instead of stun

local debuffedUnits = {} -- unitID -> expireFrame

local mobileBuilderDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
  if UnitSharingCategories.isMobileBuilderDef(unitDef) then
    mobileBuilderDefs[unitDefID] = true
  end
end

local function applyBuildDelay(unitID, unitDefID, stunSeconds)
  local startFrame = Spring.GetGameFrame()
  local expireFrame = startFrame + (stunSeconds * Game.gameSpeed)
  debuffedUnits[unitID] = expireFrame
  PolicyEvents.NotifyBuildDelay(unitID, startFrame, expireFrame)
end

local function shouldStunUnit(unitDefID, stunCategory)
  if not stunCategory then
    return false
  end
  return Shared.IsShareableDef(unitDefID, stunCategory, UnitDefs)
end

local function applyStun(unitID, unitDefID, policyResult)
  -- Mobile builders get the build delay debuff instead of stun when enabled.
  -- Independent of the eco-building stun: applies whenever the delay is set.
  local buildDelaySeconds = tonumber(policyResult.buildDelaySeconds) or 0
  if buildDelaySeconds > 0 and mobileBuilderDefs[unitDefID] then
    applyBuildDelay(unitID, unitDefID, buildDelaySeconds)
    return
  end

  local stunSeconds = tonumber(policyResult.stunSeconds) or 0
  if stunSeconds <= 0 then
    return
  end

  local stunCategory = policyResult.stunCategory
  if not shouldStunUnit(unitDefID, stunCategory) then
    return
  end
  local _, maxHealth = Spring.GetUnitHealth(unitID)
  Spring.AddUnitDamage(unitID, maxHealth * 5, stunSeconds)
end

-- engine contract via SetUnitTransferController: AllowUnitTransfer + TeamShare

---@type SpringSynced
local springRepo = Spring
local contextFactory = ContextFactoryModule.create(springRepo)

local POLICY_CACHE_UPDATE_RATE = 150 -- 5 seconds
local lastPolicyCacheUpdate = 0

GG = GG or {}

local UnitTransferController = {}

-- Factors are per-team and independent, so a new/changed team only needs its own record
-- rewritten; GetCachedPolicyResult pairs it against every other team on read.
---@param teamId number
local function InitializeNewTeam(teamId)
  local ctx = contextFactory.policy(teamId, teamId)
  UnitTransfer.CacheTeamFactor(springRepo, teamId, ctx)
end

local function UpdatePolicyCache(frame)
  if frame < lastPolicyCacheUpdate + POLICY_CACHE_UPDATE_RATE then
    return
  end
  lastPolicyCacheUpdate = frame

  local teamList = springRepo.GetTeamList() or {}
  for _, teamId in ipairs(teamList) do
    InitializeNewTeam(teamId)
  end
end

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
  
  if not validation or validation.status == TransferEnums.UnitValidationOutcome.Failure then
    ---@type UnitTransferResult
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
    for _, unitID in ipairs(validation.validUnitIds) do
      applyStun(unitID, springRepo.GetUnitDefID(unitID), policyResult)
    end
    Spring.SendLuaUIMsg("unit_transfer:success:" .. senderTeamID)
  else
    Spring.SendLuaUIMsg("unit_transfer:failed:" .. senderTeamID)
  end
  
  return result
end

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

  if Spring.GetGameRulesParam("isTakeInProgress") == 1 then
    return true
  end
  
  local policyResult = Shared.GetCachedPolicyResult(fromTeamID, toTeamID, springRepo)
  
  local validation = Shared.ValidateUnits(policyResult, { unitID }, springRepo)
  
  local allowed = validation and validation.status ~= TransferEnums.UnitValidationOutcome.Failure

  return allowed
end

---@param srcTeamID number
---@param dstTeamID number
function UnitTransferController.TeamShare(srcTeamID, dstTeamID)
  local units = springRepo.GetTeamUnits(srcTeamID) or {}
  for _, unitID in ipairs(units) do
    springRepo.TransferUnit(unitID, dstTeamID, true)
  end
end

function gadget:Initialize()
  local teams = springRepo.GetTeamList() or {}
  for _, teamId in ipairs(teams) do
    InitializeNewTeam(teamId)
  end
  lastPolicyCacheUpdate = springRepo.GetGameFrame()

  if Spring.SetUnitTransferController then
    ---@type GameUnitTransferController
    local controller = {
      AllowUnitTransfer = UnitTransferController.AllowUnitTransfer,
      TeamShare = UnitTransferController.TeamShare
    }
    Spring.SetUnitTransferController(controller)
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
      GG.ShareUnits(senderTeamID, params.targetTeamID, params.unitIDs)
    end
    return true
  end
  return false
end

function gadget:GameFrame(frame)
  UpdatePolicyCache(frame)

  for unitID, expireFrame in pairs(debuffedUnits) do
    if frame >= expireFrame then
      debuffedUnits[unitID] = nil
      PolicyEvents.NotifyBuildDelayEnd(unitID)
    end
  end
end

function gadget:UnitDestroyed(unitID)
  if debuffedUnits[unitID] then
    debuffedUnits[unitID] = nil
    PolicyEvents.NotifyBuildDelayEnd(unitID)
  end
end

function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part)
  if debuffedUnits[builderID] and spGetUnitIsBeingBuilt(unitID) then
    return false
  end
  return true
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
  if debuffedUnits[builderID] then
    return false
  end
  return true
end
