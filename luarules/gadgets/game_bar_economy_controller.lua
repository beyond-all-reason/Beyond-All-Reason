function gadget:GetInfo()
	return {
		name      = "BAR Economy Controller",
		desc      = "Controls resource sharing via Water-Fill algorithm",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local BarEconomy = VFS.Include("common/luaUtilities/economy/bar_economy_waterfill_solver.lua")
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")

local MOD_OPTIONS = SharedEnums.ModOptions
local ResourceType = SharedEnums.ResourceType

local modOptions = Spring.GetModOptions()
if modOptions.game_economy ~= "1" then
	return
end

local springRepo = {
	GetModOptions = Spring.GetModOptions,
	GetTeamRulesParam = Spring.GetTeamRulesParam,
	SetTeamRulesParam = Spring.SetTeamRulesParam,
	GetTeamResources = Spring.GetTeamResources,
	AreTeamsAllied = Spring.AreTeamsAllied,
	IsCheatingEnabled = Spring.IsCheatingEnabled,
	GetGaiaTeamID = Spring.GetGaiaTeamID,	
	GetTeamInfo = Spring.GetTeamInfo,
	GetTeamLuaAI = Spring.GetTeamLuaAI,
	AddTeamResource = Spring.AddTeamResource,
}

local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 150 -- Update every ~5 seconds (assuming 30fps)

local function CalculateSenderPolicies(springRepo, teams)
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	local resultFactory = ResourceTransfer.BuildResultFactory(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY])
	
	local policies = {}
	
	-- We need to calculate a policy for each team that represents their ability to share with the pool (allies).
	-- Since the solver pools resources by AllyTeam, we can just pick one ally as the "receiver" context 
	-- to generate the policy, or use a generic context if supported.
	-- ContextFactory.policy requires a specific receiver.
	-- Let's assume we can use the team itself as receiver to check "self" policy, 
	-- but for sharing we need an ally.
	-- Actually, the solver needs to know: "How much can this team contribute to the pool?"
	-- This is determined by:
	-- 1. Their current resources (handled by solver)
	-- 2. Their tax-free allowance (policy)
	-- 3. The tax rate (policy)
	-- 4. Their share slider (handled by solver)
	
	-- So we need to generate a policy that gives us 'remainingTaxFreeAllowance' and 'taxRate'.
	-- We can generate this by creating a dummy policy context where the receiver is an ally.
	-- If no ally exists, they can't share anyway (handled by solver grouping).
	
	-- Optimization: We can just calculate the "Sender Policy" once per team.
	
	for _, team in ipairs(teams) do
		if team.id and not team.isDead then
			local senderID = team.id
			-- Find an ally to form a context. If none, we can't share.
			-- But we still need a policy object for the solver to read taxRate etc.
			-- We can use the team itself as receiver for the context creation if needed,
			-- or just pick the first ally.
			-- ContextFactory.policy(sender, receiver)
			
			-- For now, let's use the team itself as the receiver to generate the "base" policy 
			-- (thresholds etc are sender-based).
			local ctx = contextFactory.policy(senderID, senderID) 
			
			local metalPolicy = resultFactory(ctx, ResourceType.METAL)
			local energyPolicy = resultFactory(ctx, ResourceType.ENERGY)
			
			policies[senderID] = {
				[ResourceType.METAL] = metalPolicy,
				[ResourceType.ENERGY] = energyPolicy
			}
			
			-- Cache the policy for UI (we might want to throttle this part if it's slow, but let's do it every frame for now for correctness)
			-- Note: The UI expects pairwise policies. This loop only calculates "self" policy.
			-- To fully support the UI pairwise view, we'd need the N*N loop.
			-- But for the solver, we only need the "sender" capability.
			
			-- User asked to "restore policy caching... similar to how it was".
			-- The N*N loop was for the UI matrix.
			-- So we should probably keep the N*N loop for caching, but maybe throttle it?
			-- And use the "self" policy (or derived) for the solver.
		end
	end
	
	return policies
end

local function UpdatePolicyCache(frame)
	if frame < lastPolicyUpdate + POLICY_UPDATE_RATE then
		return
	end

	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	local resultFactory = ResourceTransfer.BuildResultFactory(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY])
	
	local allTeams = Spring.GetTeamList()
	for _, senderID in ipairs(allTeams) do
		for _, receiverID in ipairs(allTeams) do
			local ctx = contextFactory.policy(senderID, receiverID)
			
			local metalPolicy = resultFactory(ctx, ResourceType.METAL)
			ResourceTransfer.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.METAL, metalPolicy)
			
			local energyPolicy = resultFactory(ctx, ResourceType.ENERGY)
			ResourceTransfer.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.ENERGY, energyPolicy)
		end
	end
end

function gadget:ProcessEconomy(frame, teams)
	local policies = CalculateSenderPolicies(springRepo, teams)
	
	-- Capture pre-update current values to calculate excess later
	local preValues = {}
	for _, team in ipairs(teams) do
		if team.id then
			preValues[team.id] = {
				metal = team.metal.current,
				energy = team.energy.current
			}
		end
	end

	local updatedTeams, allLedgers = BarEconomy.ProcessEconomy(springRepo, teams, policies)
	
	local result = {}
	for _, team in ipairs(updatedTeams) do
		if team.id then
			local pre = preValues[team.id]
			-- Calculate excess: (Start + Received - Sent) - End
			-- If the result is positive, it means we had more resources available than what we ended up with (after storage clamping),
			-- so the difference is what was "lost" or excess.
			local mExcess = 0
			local eExcess = 0
			
			if pre then
				mExcess = math.max(0, (pre.metal + team.metal.received - team.metal.sent) - team.metal.current)
				eExcess = math.max(0, (pre.energy + team.energy.received - team.energy.sent) - team.energy.current)
			end

			result[team.id] = {
				metal = {
					current = team.metal.current,
					sent = team.metal.sent,
					received = team.metal.received,
					excess = mExcess
				},
				energy = {
					current = team.energy.current,
					sent = team.energy.sent,
					received = team.energy.received,
					excess = eExcess
				}
			}
		end
	end
	
	UpdatePolicyCache(frame)
	return result
end
