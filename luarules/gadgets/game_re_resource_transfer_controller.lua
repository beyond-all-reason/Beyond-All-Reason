local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "RE Resource Transfer Controller",
		desc      = "Controls resource transfers via Water-Fill algorithm (ResourceExcess path)",
		author    = "Antigravity",
		date      = "2025",
		license   = "GPL-v2",
		layer     = -200,
		enabled   = not Game.gameEconomy,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- GG API
--------------------------------------------------------------------------------

GG = GG or {}

function GG.GetTeamResources(teamID, resource)
	return Spring.GetTeamResources(teamID, resource)
end

function GG.AddTeamResource(teamID, resource, amount)
	local current = Spring.GetTeamResources(teamID, resource)
	return Spring.SetTeamResource(teamID, resource, current + amount)
end

--------------------------------------------------------------------------------
-- Module imports
--------------------------------------------------------------------------------

local GlobalEnums = VFS.Include("modes/global_enums.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")

local ResourceType = GlobalEnums.ResourceType
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")

local tracyAvailable = tracy and tracy.ZoneBeginN and tracy.ZoneEnd

--------------------------------------------------------------------------------
-- Module globals
--------------------------------------------------------------------------------

local contextFactory = ContextFactoryModule.create(Spring)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 30

---@type table<number, TeamResourceData>
local teamsCache = {}
local statsSentBuffer = { sent = { 0, 0 } }
local statsRecvBuffer = { received = { 0, 0 } }

function GG.ShareTeamResource(teamID, targetTeamID, resource, amount)
	local policyResult = Shared.GetCachedPolicyResult(teamID, targetTeamID, resource, Spring)
	local ctx = contextFactory.resourceTransfer(teamID, targetTeamID, resource, amount, policyResult)
	local transferResult = ResourceTransfer.ResourceTransfer(ctx)
	
	if transferResult.success then
		ResourceTransfer.RegisterPostTransfer(ctx, transferResult)
		Comms.SendTransferChatMessages(transferResult, transferResult.policyResult)
	end
	
	return transferResult
end

function GG.SetTeamShareLevel(teamID, resource, level)
	Spring.SetTeamShareLevel(teamID, resource, level)
	lastPolicyUpdate = 0
end

function GG.GetTeamShareLevel(teamID, resource)
	local _, _, _, _, _, share = Spring.GetTeamResources(teamID, resource)
	return share
end

local function InitializeNewTeam(senderTeamId)
	local taxRate, thresholds = SharedConfig.getTaxConfig(Spring)
	local resultFactory = ResourceTransfer.BuildResultFactory(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY])
	local allTeams = Spring.GetTeamList()

	for _, receiverID in ipairs(allTeams) do
		local ctx = contextFactory.policy(senderTeamId, receiverID)
		
		for _, resourceType in ipairs(GlobalEnums.ResourceTypes) do
			local param = Shared.GetCumulativeParam(resourceType)
			Spring.SetTeamRulesParam(senderTeamId, param, 0)
		end

		local metalPolicy = resultFactory(ctx, ResourceType.METAL)
		ResourceTransfer.CachePolicyResult(Spring, senderTeamId, receiverID, ResourceType.METAL, metalPolicy)
		
		local energyPolicy = resultFactory(ctx, ResourceType.ENERGY)
		ResourceTransfer.CachePolicyResult(Spring, senderTeamId, receiverID, ResourceType.ENERGY, energyPolicy)
	end
end

function gadget:PlayerAdded(playerID)
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)
	if teamID then
		InitializeNewTeam(teamID)
	end
end

--------------------------------------------------------------------------------
-- ResourceExcess handler
-- 
-- Standard gadget callin: engine fires this every frame with per-team excess.
-- We query full team state, run the solver, and apply results via setters.
--------------------------------------------------------------------------------

local pendingPolicyUpdate = false
local pendingPolicyFrame = 0

---Build team data by querying Spring API
---@param excesses table Excess values from engine (keyed by teamID)
---@return table<number, TeamResourceData>
local function BuildTeamData(excesses)
	local teamList = Spring.GetTeamList() or {}
	
	for _, teamId in ipairs(teamList) do
		local mCur, mStor, mPull, mInc, mExp, mShare = Spring.GetTeamResources(teamId, "metal")
		local eCur, eStor, ePull, eInc, eExp, eShare = Spring.GetTeamResources(teamId, "energy")
		
		if mCur and eCur then
			local _, _, isDead, _, _, allyTeam = Spring.GetTeamInfo(teamId)
			
			local team = teamsCache[teamId]
			if not team then
				team = {
					metal = {},
					energy = {},
					allyTeam = allyTeam,
					isDead = false,
				}
				teamsCache[teamId] = team
			end
			
			team.allyTeam = allyTeam
			team.isDead = (isDead == true)
			
			local metal = team.metal
			metal.resourceType = "metal"
			metal.current = mCur
			metal.storage = mStor or 0
			metal.pull = mPull or 0
			metal.income = mInc or 0
			metal.expense = mExp or 0
			metal.shareSlider = mShare or 0
			
			local energy = team.energy
			energy.resourceType = "energy"
			energy.current = eCur
			energy.storage = eStor or 0
			energy.pull = ePull or 0
			energy.income = eInc or 0
			energy.expense = eExp or 0
			energy.shareSlider = eShare or 0
		end
	end
	
	return teamsCache
end

---Apply solver results to teams via Spring API
---@param results EconomyTeamResult[]
local function ApplyResults(results)
	local teamStats = {}
	
	for _, result in ipairs(results) do
		local teamId = result.teamId
		local resName = result.resourceType == ResourceType.METAL and "metal" or "energy"
		local resIdx = result.resourceType == ResourceType.METAL and 1 or 2
		
		Spring.SetTeamResource(teamId, resName, result.current)
		
		local stats = teamStats[teamId]
		if not stats then
			stats = { sent = { 0, 0 }, received = { 0, 0 } }
			teamStats[teamId] = stats
		end
		stats.sent[resIdx] = result.sent
		stats.received[resIdx] = result.received
	end
	
	for teamId, stats in pairs(teamStats) do
		if stats.sent[1] > 0 or stats.sent[2] > 0 then
			statsSentBuffer.sent[1] = stats.sent[1]
			statsSentBuffer.sent[2] = stats.sent[2]
			Spring.AddTeamResourceStats(teamId, statsSentBuffer)
		end
		if stats.received[1] > 0 or stats.received[2] > 0 then
			statsRecvBuffer.received[1] = stats.received[1]
			statsRecvBuffer.received[2] = stats.received[2]
			Spring.AddTeamResourceStats(teamId, statsRecvBuffer)
		end
	end
end

local function DeferredPolicyUpdate()
	if not pendingPolicyUpdate then return end
	pendingPolicyUpdate = false
	
	if tracyAvailable then tracy.ZoneBeginN("RE_PolicyCache_Deferred") end
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(
		Spring, pendingPolicyFrame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory
	)
	if tracyAvailable then tracy.ZoneEnd() end
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:ResourceExcess(excesses)
	if tracyAvailable then tracy.ZoneBeginN("RE_Lua") end

	local teams = BuildTeamData(excesses)
	
	local success, results = pcall(WaterfillSolver.SolveToResults, Spring, teams)
	if not success then
		if tracyAvailable then tracy.ZoneEnd() end
		Spring.Log("REResourceTransferController", LOG.ERROR, "Solver: " .. tostring(results))
		return false
	end
	
	ApplyResults(results)
	
	pendingPolicyUpdate = true
	pendingPolicyFrame = Spring.GetGameFrame()
	
	if tracyAvailable then tracy.ZoneEnd() end
	return true
end

function gadget:RecvLuaMsg(msg, playerID)
	local params = LuaRulesMsg.ParseResourceShare(msg)
	if params then
		GG.ShareTeamResource(params.senderTeamID, params.targetTeamID, params.resourceType, params.amount)
		return true
	end
	return false
end

function gadget:Initialize()
	Spring.Echo("[REResourceTransferController] Initialize (ResourceExcess path)")
	
	local teamList = Spring.GetTeamList()
	for _, senderTeamId in ipairs(teamList) do
		InitializeNewTeam(senderTeamId)
	end
	lastPolicyUpdate = Spring.GetGameFrame()
end

function gadget:GameFrame(frame)
	DeferredPolicyUpdate()
end
