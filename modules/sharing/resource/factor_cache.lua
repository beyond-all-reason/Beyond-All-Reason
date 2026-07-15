local Enums = VFS.Include("modules/sharing/enums.lua")
local Shared = VFS.Include("modules/sharing/resource/shared.lua")
local PolicyEvents = VFS.Include("modules/sharing/policy_events.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")

--- Per-team resource factor cache: each team's taxed-sendable/capacity record
--- is serialized into team rules params on a cadence; any (sender, receiver)
--- pair policy is rebuilt from two factors on read (Shared.GetCachedPolicyResult).

local ResourceType = Enums.ResourceType
local METAL = ResourceType.METAL
local ENERGY = ResourceType.ENERGY

local M = {}

---Compute and cache one team's resource factor record for a single resource.
---@param springRepo EngineSynced
---@param teamId integer
---@param resourceType ResourceName
---@param ctx PolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's tax
function M.CacheTeamFactor(springRepo, teamId, resourceType, ctx)
	local data = (resourceType == METAL) and ctx.sender.metal or ctx.sender.energy
	local effectiveRate = Helpers.ResolveEffectiveTaxRate(ctx)
	local isNonPlayer = Helpers.IsNonPlayerTeam(springRepo, teamId)
	local active = Helpers.TeamActive(springRepo, teamId)
	local factor = {
		taxedSendable = math.max(0, data.current) * (1 - effectiveRate),
		taxRate = effectiveRate,
		capacity = data.storage - data.current,
		isNonPlayer = isNonPlayer,
		active = active,
	}
	springRepo.SetTeamRulesParam(teamId, Shared.MakeFactorKey(resourceType), Shared.SerializeResourceFactor(factor))
	-- Policy fields only; live amounts (taxedSendable/capacity) would fire every economy tick.
	local signature = string.format("%s|%s|%s", tostring(effectiveRate), tostring(active), tostring(isNonPlayer))
	local category = (resourceType == METAL) and Enums.PolicyType.MetalTransfer or Enums.PolicyType.EnergyTransfer
	PolicyEvents.NotifyIfChanged(teamId, category, signature)
end

---refresh the per-team resource factor cache (O(teams), factors are independent); pairs reconstructed on read
---@param springRepo EngineSynced
---@param frame number
---@param lastUpdate number
---@param updateRate number
---@param contextFactory table
---@return number lastUpdate New last update frame
function M.UpdatePolicyCache(springRepo, frame, lastUpdate, updateRate, contextFactory)
	if frame < lastUpdate + updateRate then
		return lastUpdate
	end

	contextFactory.clearResourceCache()

	local allTeams = springRepo.GetTeamList()
	for _, teamId in ipairs(allTeams) do
		local ctx = contextFactory.policy(teamId, teamId)
		M.CacheTeamFactor(springRepo, teamId, METAL, ctx)
		M.CacheTeamFactor(springRepo, teamId, ENERGY, ctx)
	end

	return frame
end

return M
