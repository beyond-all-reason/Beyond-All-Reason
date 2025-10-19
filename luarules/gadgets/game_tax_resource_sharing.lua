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
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")

local RESOURCE_TYPES = SharedEnums.ResourceTypes
local contextFactory = ContextFactoryModule.create(Spring)
local policyResultFactory = ResourceTransfer.BuildResultFactory(sharingTax, metalTaxThreshold, energyTaxThreshold)

local lastGameFrameCacheUpdate = 0

local function isAlliedUnit(teamID, unitID)
	local unitTeam = Spring.GetUnitTeam(unitID)
	return teamID and unitTeam and teamID ~= unitTeam and Spring.AreTeamsAllied(teamID, unitTeam)
end

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

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	-- Allows CMD.RECLAIM, CMD.GUARD
	-- Disallow reclaiming allied units for metal
	if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
		local targetID = cmdParams[1]
		if(targetID >= Game.maxUnits) then
			return true
		end
		if isAlliedUnit(unitTeam, targetID) then
			return false
		end
	-- Also block guarding allied units that can reclaim
	elseif (cmdID == CMD.GUARD) then
		local targetID = cmdParams[1]
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

		if isAlliedUnit(unitTeam, targetID) then
			-- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
			if targetUnitDef.canReclaim then
				return false
			end
		end
	end
end

