local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name    = 'Tax Resource Sharing',
    desc    = 'Tax Resource Sharing when modoption enabled. Modified from "Prevent Excessive Share" by Niobium', -- taxing overflow needs to be handled by the engine
    author  = 'Rimilel, Attean',
    date    = 'April 2024',
    license = 'GNU GPL, v2 or later',
    layer   = 1, -- Needs to occur before "Prevent Excessive Share" since their restriction on AllowResourceTransfer is not compatible
    enabled = true
  }
end

local POLICY_CACHE_TAINT_FRAME_RATE = 30 -- every 1 second to keep up with overflow detection

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
  return false
end

local sharingTax = tonumber(Spring.GetModOptions().tax_resource_sharing_amount) or 0
local energyTaxThreshold = tonumber(Spring.GetModOptions().player_energy_send_threshold) or 0
local metalTaxThreshold = tonumber(Spring.GetModOptions().player_metal_send_threshold) or 0

local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

local RESOURCE_TYPES = SharedEnums.ResourceTypes
local contextFactory = ContextFactoryModule.create(Spring)
local policyResultFactory = ResourceTransfer.BuildResultFactory(sharingTax, metalTaxThreshold, energyTaxThreshold)

local lastGameFrameCacheUpdate = 0

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

---@param policyContext PolicyContext
---@param resourceType ResourceType
---@return ResourcePolicyResult
function BuildPolicyCache(policyContext, resourceType)
  local policyResult = policyResultFactory(policyContext, resourceType)
  ResourceTransfer.CachePolicyResult(
    Spring,
    policyContext.senderTeamId,
    policyContext.receiverTeamId,
    resourceType,
    policyResult
  )
  return policyResult
end

local function InitializeNewTeam(senderTeamId, receiverTeamId)
  local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
  for _, resourceType in ipairs(RESOURCE_TYPES) do
    local param = Shared.GetCumulativeParam(resourceType)
    Spring.SetTeamRulesParam(senderTeamId, param, 0)
    BuildPolicyCache(ctx, resourceType)
  end
end

function gadget:Initialize()
  local teamList = Spring.GetTeamList() or {}

  for _, senderTeamId in ipairs(teamList) do
    for _, receiverTeamId in ipairs(teamList) do
      InitializeNewTeam(senderTeamId, receiverTeamId)
    end
  end
  lastGameFrameCacheUpdate = Spring.GetGameFrame()
end

--------------------------------------------------------------
-- Callins
--------------------------------------------------------------

function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
  local resType = (resourceType == 'm' or resourceType == 'metal') and SharedEnums.ResourceType.METAL or
      SharedEnums.ResourceType.ENERGY
  local policyResult = Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId, resType)
  local ctx = contextFactory.resourceTransfer(senderTeamId, receiverTeamId, resType, amount, policyResult)

  local transferResult = ResourceTransfer.ResourceTransfer(ctx)
  ResourceTransfer.RegisterPostTransfer(ctx, transferResult)

  -- immediately rebuild the cache for this resource
  local policyCtx = contextFactory.policy(senderTeamId, receiverTeamId)
  local frame = Spring.GetGameFrame()
  local updatedPolicyResult = BuildPolicyCache(policyCtx, resType)
  Comms.SendTransferChatMessages(transferResult, updatedPolicyResult)

  return false
end

function gadget:GameFrame(frame)
  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE_HEAVY
  if frame < nextSchedHeavy then
    return
  end
  local teamList = Spring.GetTeamList() or {}
  lastGameFrameCacheUpdate = frame
  for _, senderTeamId in ipairs(teamList) do
    -- we also calculate me -> me for standardized resource request limits
    for _, receiverTeamId in ipairs(teamList) do
      local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
      for _, resourceType in ipairs(RESOURCE_TYPES) do
        BuildPolicyCache(ctx, resourceType)
      end
    end
  end
end

-- Keep cache in sync with roster changes
function gadget:PlayerAdded(playerID)
  local frame = Spring.GetGameFrame()
  local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)
  if teamID then
    for _, receiverTeamId in ipairs(Spring.GetTeamList() or {}) do
      InitializeNewTeam(teamID, receiverTeamId)
    end
  end
end

