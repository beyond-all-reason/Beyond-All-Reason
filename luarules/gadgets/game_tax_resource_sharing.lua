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

local POLICY_CACHE_TAINT_FRAME_RATE = 30 -- Rebuild policies every second to keep up with frequent cumulative sent changes

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

-- Track engine-pipeline resource stats to detect overflow receives and engine-driven sends
-- We record cumulative counters and take diffs per update window.
local lastRecvStats = {}   -- [teamId] = { m = 0, e = 0 }
local lastSentStats = {}   -- [teamId] = { m = 0, e = 0 }
local manualRecvSinceLastOverflowCalc = {} -- [teamId] = { m = 0, e = 0 }

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
  local teamList = Spring.GetTeamList()

  for _, senderTeamId in ipairs(teamList) do
    for _, receiverTeamId in ipairs(teamList) do
      InitializeNewTeam(senderTeamId, receiverTeamId)
    end
  end

  -- snapshot engine cumulative stats so first diff is zero
  for _, teamId in ipairs(teamList) do
    local _uM, _pM, _xM, recvM, sentM = Spring.GetTeamResourceStats(teamId, "m")
    local _uE, _pE, _xE, recvE, sentE = Spring.GetTeamResourceStats(teamId, "e")
    lastRecvStats[teamId] = { m = recvM, e = recvE }
    lastSentStats[teamId] = { m = sentM, e = sentE }
    manualRecvSinceLastOverflowCalc[teamId] = { m = 0, e = 0 }
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
  local updatedPolicyResult = BuildPolicyCache(policyCtx, resType)
  Comms.SendTransferChatMessages(transferResult, updatedPolicyResult)

  -- Track manual receives to avoid canceling/taxing them in overflow step
  if transferResult and transferResult.success and transferResult.received and transferResult.received > 0 then
    local key = (resType == SharedEnums.ResourceType.METAL) and 'm' or 'e'
    local bucket = manualRecvSinceLastOverflowCalc[receiverTeamId]
    if not bucket then
      bucket = { m = 0, e = 0 }
      manualRecvSinceLastOverflowCalc[receiverTeamId] = bucket
    end
    bucket[key] = (bucket[key]) + transferResult.received
  end

  return false
end

function gadget:GameFrame(frame)
  -- rebuild policy caches every 30 frames
  -- exactly one frame after teamhandler calls team->SlowUpdate() where overflow happens (and teamres stats get updated)
  if (frame % POLICY_CACHE_TAINT_FRAME_RATE) ~= 1 then
    return
  end

  local teamList = Spring.GetTeamList()

  -- tax overflows immediately when detected to prevent spending before taxation
  -- it is still theoretically possible to spend before taxation, but it is very unlikely
  if sharingTax and sharingTax > 0 then
    for _, teamId in ipairs(teamList) do
      local _uM, _pM, _xM, curRecvM, curSentM = Spring.GetTeamResourceStats(teamId, "m")
      local _uE, _pE, _xE, curRecvE, curSentE = Spring.GetTeamResourceStats(teamId, "e")

      local prevRecv = lastRecvStats[teamId]
      local prevSent = lastSentStats[teamId]
      if not prevRecv then
        prevRecv = { m = 0, e = 0 }
        lastRecvStats[teamId] = prevRecv
      end
      if not prevSent then
        prevSent = { m = 0, e = 0 }
        lastSentStats[teamId] = prevSent
      end

      local diffRecvM = math.max(0, curRecvM - prevRecv.m)
      local diffRecvE = math.max(0, curRecvE - prevRecv.e)

      local diffSentM = math.max(0, curSentM - prevSent.m)
      local diffSentE = math.max(0, curSentE - prevSent.e)

      -- Apply receiver-side tax only to overflow portion (engine received minus manual receives tracked)
      local manual = manualRecvSinceLastOverflowCalc[teamId]
      local overflowRecvM = math.max(0, diffRecvM - manual.m)
      local overflowRecvE = math.max(0, diffRecvE - manual.e)

      -- Tax overflow immediately when detected to prevent spending before taxation
      if overflowRecvM > 0 then
        local taxedM = overflowRecvM * sharingTax
        if taxedM > 0 then
          Spring.UseTeamResource(teamId, "metal", taxedM)
        end
      end
      if overflowRecvE > 0 then
        local taxedE = overflowRecvE * sharingTax
        if taxedE > 0 then
          Spring.UseTeamResource(teamId, "energy", taxedE)
        end
      end

      -- Attribute engine-driven sends to our cumulative sender counters so thresholds include overflow sharing
      -- Manual transfers bypass engine pipeline so they're counted in RegisterPostTransfer, overflow sends here
      if diffSentM > 0 then
        local cumulativeParam = Shared.GetCumulativeParam(SharedEnums.ResourceType.METAL)
        local cumulativeVal = tonumber(Spring.GetTeamRulesParam(teamId, cumulativeParam))
        Spring.SetTeamRulesParam(teamId, cumulativeParam, cumulativeVal + diffSentM)
      end
      if diffSentE > 0 then
        local cumulativeParam = Shared.GetCumulativeParam(SharedEnums.ResourceType.ENERGY)
        local cumulativeVal = tonumber(Spring.GetTeamRulesParam(teamId, cumulativeParam))
        Spring.SetTeamRulesParam(teamId, cumulativeParam, cumulativeVal + diffSentE)
      end

      -- Update stats for next frame comparison
      lastRecvStats[teamId].m = curRecvM
      lastRecvStats[teamId].e = curRecvE
      lastSentStats[teamId].m = curSentM
      lastSentStats[teamId].e = curSentE
    end
  end

  for _, teamId in ipairs(teamList) do
    manualRecvSinceLastOverflowCalc[teamId] = { m = 0, e = 0 }
  end

  -- 2) Rebuild policy caches
  local cacheRebuildCount = 0
  for _, senderTeamId in ipairs(teamList) do
    -- we also calculate me -> me for standardized resource request limits
    for _, receiverTeamId in ipairs(teamList) do
      local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
      for _, resourceType in ipairs(RESOURCE_TYPES) do
        BuildPolicyCache(ctx, resourceType)
        cacheRebuildCount = cacheRebuildCount + 1
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

