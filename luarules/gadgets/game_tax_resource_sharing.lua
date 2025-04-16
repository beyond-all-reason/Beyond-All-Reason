local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name    = 'Tax Resource Sharing',
    desc    = 'Tax Resource Sharing when modoption enabled. Modified from "Prevent Excessive Share" by Niobium', -- taxing overflow needs to be handled by the engine
    author  = 'Rimilel',
    date    = 'April 2024',
    license = 'GNU GPL, v2 or later',
    layer   = 1, -- Needs to occur before "Prevent Excessive Share" since their restriction on AllowResourceTransfer is not compatible
    enabled = true
  }
end

local POLICY_CACHE_TAINT_FRAME_RATE_HEAVY = 150

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
local Helpers = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ModOptions = VFS.Include("common/luaUtilities/team_transfer/modoption_enums.lua")
local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

local RESOURCE_TYPES = SharedEnums.ResourceTypes
local contextFactory = ContextFactoryModule.create(Spring)
local policyResultFactory = ResourceTransfer.BuildResultFactory(sharingTax, metalTaxThreshold, energyTaxThreshold)

local lastGameFrameCacheUpdate = 0

--- Send chat messages for completed resource transfers
---@param transferResult ResourceTransferResult
---@param policyResult ResourcePolicyResult
---@param resourceType ResourceType
local function SendTransferChatMessages(transferResult, policyResult, resourceType)
  if transferResult.sent > 0 then
    local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
    local case = Helpers.DecideCommunicationCase(policyResult)

    if case == SharedEnums.ResourceCommunicationCase.OnTaxFree then
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType .. ':receivedAmount=' .. math.floor(transferResult.received))
    elseif case == SharedEnums.ResourceCommunicationCase.OnTaxed then
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType ..
        'Taxed:receivedAmount=' ..
        math.floor(transferResult.received) ..
        ':sentAmount=' ..
        math.floor(transferResult.sent) .. ':taxRatePercentage=' .. math.floor(policyResult.taxRate * 100 + 0.5))
    elseif case == SharedEnums.ResourceCommunicationCase.OnTaxedThreshold then
      local cumulativeUntaxed = math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)
      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
        pascalResourceType ..
        'TaxedThreshold:receivedAmount=' ..
        math.floor(transferResult.received) ..
        ':sentAmount=' ..
        math.floor(transferResult.sent) ..
        ':taxRatePercentage=' ..
        math.floor(policyResult.taxRate * 100 + 0.5) ..
        ':sentAmountUntaxed=' ..
        math.floor(cumulativeUntaxed) .. ':resourceShareThreshold=' .. math.floor(policyResult.resourceShareThreshold))
    end
  end
end

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

---@param policyContext PolicyContext
---@param resourceType ResourceType
---@return ResourcePolicyResult
function BuildPolicyCache(policyContext, resourceType, gameFrame)
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

local function InitializeNewTeam(senderTeamId, receiverTeamId, frame)
  local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
  for _, resourceType in ipairs(RESOURCE_TYPES) do
    local param = Helpers.GetCumulativeParam(resourceType)
    Spring.SetTeamRulesParam(senderTeamId, param, 0)
    BuildPolicyCache(ctx, resourceType, frame)
  end
end

function gadget:Initialize()
  local frame = Spring.GetGameFrame()
  local teamList = Spring.GetTeamList() or {}

  for _, senderTeamId in ipairs(teamList) do
    for _, receiverTeamId in ipairs(teamList) do
      InitializeNewTeam(senderTeamId, receiverTeamId, frame)
    end
  end
end

--------------------------------------------------------------
-- Callins
--------------------------------------------------------------

function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
  local resType = (resourceType == 'm' or resourceType == 'metal') and SharedEnums.ResourceType.METAL or SharedEnums.ResourceType.ENERGY
  local policyResult = Helpers.GetCachedPolicyResult(senderTeamId, receiverTeamId, resType)
  local ctx = contextFactory.resourceTransfer(senderTeamId, receiverTeamId, resType, amount, policyResult)

  local transferResult = ResourceTransfer.ResourceTransfer(ctx)
  ResourceTransfer.RegisterPostTransfer(transferResult, resType, Spring)
  ResourceTransfer.ApplyTransferResultToContext(transferResult, ctx)

  -- Immediately rebuild the policy cache using the mutated context
  local frame = Spring.GetGameFrame()
  local updatedPolicyResult = BuildPolicyCache(ctx, resType, frame)
  SendTransferChatMessages(transferResult, updatedPolicyResult, resType)
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
    for _, receiverTeamId in ipairs(teamList) do
      local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
      for _, resourceType in ipairs(RESOURCE_TYPES) do
        BuildPolicyCache(ctx, resourceType, frame)
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
      InitializeNewTeam(teamID, receiverTeamId, frame)
    end
  end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  -- Disallow reclaiming allied units for metal
  if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
    local targetID = cmdParams[1]
    local targetTeam
    if (targetID >= Game.maxUnits) then
      return true
    end

    targetTeam = Spring.GetUnitTeam(targetID)
    if targetTeam == nil then
      return true -- because what is going on this shouldn't happen
    end

    if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
      return false
    end
  elseif (cmdID == CMD.GUARD) then -- Also block guarding allied units that can reclaim
    local targetID = cmdParams[1]
    local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

    local targetTeam = Spring.GetUnitTeam(targetID)
    if targetTeam == nil then
      return true -- because what is going on this shouldn't happen
    end

    if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
      -- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
      if targetUnitDef.canReclaim then
        return false
      end
    end
  end
  return true
end
