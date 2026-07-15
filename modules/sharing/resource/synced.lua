local Enums = VFS.Include("modules/sharing/enums.lua")
local Comms = VFS.Include("modules/sharing/resource/comms.lua")
local Shared = VFS.Include("modules/sharing/resource/shared.lua")
local WaterfillSolver = VFS.Include("modules/sharing/economy/waterfill_solver.lua")
local PolicyEvents = VFS.Include("modules/sharing/policy_events.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

local ResourceType = Enums.ResourceType
local METAL = ResourceType.METAL
local ENERGY = ResourceType.ENERGY

local Gadgets = {
	SendTransferChatMessages = Comms.SendTransferChatMessages,
}

-- Deny gates + terminal compute live in modules/sharing/policies/resource/
-- (one pure policy per file, filename order); the transfer executor lives in
-- modules/sharing/actions/resource_transfer.lua. Loaded lazily so including
-- this library stays cheap.
local resourcePolicies ---@type PolicyDescriptor[]|nil
local function getResourcePolicies()
	if not resourcePolicies then
		resourcePolicies = ModuleHandler.LoadPolicies("sharing").resource or {}
	end
	return resourcePolicies
end

local ResourceTransferAction = ModuleHandler.Include("modules/sharing/actions/resource_transfer.lua")

--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
---@param ctx ResourceTransferContext
---@return ResourceTransferResult
function Gadgets.ResourceTransfer(ctx)
	return ResourceTransferAction.execute(ctx)
end

---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
function Gadgets.CalcResourcePolicy(ctx, resourceType)
	return ModuleHandler.Evaluate(getResourcePolicies(), ctx, resourceType) --[[@as ResourcePolicyResult]]
end

---Compute and cache one team's resource factor record for a single resource.
---@param springRepo EngineSynced
---@param teamId integer
---@param resourceType ResourceName
---@param ctx PolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's tax
function Gadgets.CacheTeamFactor(springRepo, teamId, resourceType, ctx)
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
function Gadgets.UpdatePolicyCache(springRepo, frame, lastUpdate, updateRate, contextFactory)
	if frame < lastUpdate + updateRate then
		return lastUpdate
	end

	contextFactory.clearResourceCache()

	local allTeams = springRepo.GetTeamList()
	for _, teamId in ipairs(allTeams) do
		local ctx = contextFactory.policy(teamId, teamId)
		Gadgets.CacheTeamFactor(springRepo, teamId, METAL, ctx)
		Gadgets.CacheTeamFactor(springRepo, teamId, ENERGY, ctx)
	end

	return frame
end

---@param springRepo EngineSynced
---@param teamsList TeamResourceData[]
function Gadgets.WaterfillSolve(springRepo, teamsList)
	return WaterfillSolver.Solve(springRepo, teamsList)
end

return Gadgets
