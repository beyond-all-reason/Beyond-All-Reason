local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Resource Transfer Controller",
		desc      = "Controls resource transfers via Water-Fill algorithm",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = -200,  -- Load very early so GG.* functions are available to other gadgets (ai_simpleai is -100)
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")

local ResourceType = SharedEnums.ResourceType
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")

local tracyAvailable = tracy and tracy.ZoneBeginN and tracy.ZoneEnd

--------------------------------------------------------------------------------
-- Spring API wrapper (adds GetTeamResourceData helper)
--------------------------------------------------------------------------------

---@param teamID number
---@param resourceType ResourceType|string
---@return ResourceData
local function GetTeamResourceData(teamID, resourceType)
	local resName = resourceType == SharedEnums.ResourceType.METAL and "metal" or "energy"
	local cur, stor, pull, inc, exp, share = Spring.GetTeamResources(teamID, resName)
	return {
		resourceType = resName,
		current = cur or 0,
		storage = stor or 0,
		pull = pull or 0,
		income = inc or 0,
		expense = exp or 0,
		shareSlider = share or 0,
	}
end

---@type ISpring
local springRepo = setmetatable({
	GetTeamResourceData = GetTeamResourceData,
}, { __index = Spring })

--------------------------------------------------------------------------------
-- Module globals
--------------------------------------------------------------------------------

GG = GG or {}
local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 30 -- Update every SlowUpdate (1 second at 30fps)

---@type table<number, TeamResourceData>
local teamsCache = {}
local statsSentBuffer = { sent = { 0, 0 } }
local statsRecvBuffer = { received = { 0, 0 } }

--------------------------------------------------------------------------------
-- GG API (Lua-side conveniences for other gadgets)
--------------------------------------------------------------------------------

function GG.GetTeamResourceData(teamID, resource)
	return GetTeamResourceData(teamID, resource)
end

function GG.SetTeamResource(teamID, resource, amount)
	return springRepo.SetTeamResource(teamID, resource, amount)
end

function GG.GetTeamResources(teamID, resource)
	return springRepo.GetTeamResources(teamID, resource)
end

function GG.AddTeamResource(teamID, resource, amount)
	local current = springRepo.GetTeamResources(teamID, resource)
	return springRepo.SetTeamResource(teamID, resource, current + amount)
end

---@param teamID number Sender team ID
---@param targetTeamID number Receiver team ID  
---@param resource string|ResourceType Resource type
---@param amount number Desired amount to transfer
---@return ResourceTransferResult
function GG.ShareTeamResource(teamID, targetTeamID, resource, amount)
	local policyResult = Shared.GetCachedPolicyResult(teamID, targetTeamID, resource, springRepo)
	local ctx = contextFactory.resourceTransfer(teamID, targetTeamID, resource, amount, policyResult)
	local transferResult = ResourceTransfer.ResourceTransfer(ctx)
	
	if transferResult.success then
		ResourceTransfer.RegisterPostTransfer(ctx, transferResult)
		Comms.SendTransferChatMessages(transferResult, transferResult.policyResult)
	end
	
	return transferResult
end

---@param teamID number
---@param resource string|ResourceType
---@param level number
function GG.SetTeamShareLevel(teamID, resource, level)
	Spring.SetTeamShareLevel(teamID, resource, level)
	lastPolicyUpdate = 0 -- Force policy cache refresh on next ProcessEconomy
end

---@param teamID number
---@param resource string|ResourceType
---@return number?
function GG.GetTeamShareLevel(teamID, resource)
	local _, _, _, _, _, share = springRepo.GetTeamResources(teamID, resource)
	return share
end

local function InitializeNewTeam(senderTeamId)
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	local resultFactory = ResourceTransfer.BuildResultFactory(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY])
	local allTeams = springRepo.GetTeamList()

	for _, receiverID in ipairs(allTeams) do
		local ctx = contextFactory.policy(senderTeamId, receiverID)
		
		-- Initialize accumulators
		for _, resourceType in ipairs(SharedEnums.ResourceTypes) do
			local param = Shared.GetCumulativeParam(resourceType)
			springRepo.SetTeamRulesParam(senderTeamId, param, 0)
		end

		local metalPolicy = resultFactory(ctx, ResourceType.METAL)
		ResourceTransfer.CachePolicyResult(springRepo, senderTeamId, receiverID, ResourceType.METAL, metalPolicy)
		
		local energyPolicy = resultFactory(ctx, ResourceType.ENERGY)
		ResourceTransfer.CachePolicyResult(springRepo, senderTeamId, receiverID, ResourceType.ENERGY, energyPolicy)
	end
end

function gadget:PlayerAdded(playerID)
	local _, _, _, teamID = springRepo.GetPlayerInfo(playerID, false)
	if teamID then
		InitializeNewTeam(teamID)
	end
end

--------------------------------------------------------------------------------
-- ProcessEconomy Controller Function
-- 
-- Called by C++ via the registered controller pattern.
-- Returns EconomyTeamResult[] directly from the solver.
-- Policy cache update is deferred to GameFrame to avoid blocking.
--------------------------------------------------------------------------------

local pendingPolicyUpdate = false
local pendingPolicyFrame = 0

---@param frame number
---@param teams table<number, TeamResourceData>
---@return EconomyTeamResult[]
local function ProcessEconomy(frame, teams)
	if tracyAvailable then tracy.ZoneBeginN("PE_Lua") end

	if frame % 300 == 0 then
		Spring.Echo("[ProcessEconomyController] Processing frame=" .. frame)
	end
	
	local results = WaterfillSolver.SolveToResults(springRepo, teams)
	
	pendingPolicyUpdate = true
	pendingPolicyFrame = frame
	
	if tracyAvailable then tracy.ZoneEnd() end
	return results
end

local function DeferredPolicyUpdate()
	if not pendingPolicyUpdate then return end
	pendingPolicyUpdate = false
	
	if tracyAvailable then tracy.ZoneBeginN("PE_PolicyCache_Deferred") end
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(
		springRepo, pendingPolicyFrame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory
	)
	if tracyAvailable then tracy.ZoneEnd() end
end

--------------------------------------------------------------------------------
-- ResourceExcess Controller Functions (merged from game_resource_excess_controller)
-- 
-- Alternative mode where Lua queries team state and applies results directly.
--------------------------------------------------------------------------------

---Build team data by querying Spring API - emulates per-gadget lookup pattern
---@param excesses table<number, {metal: number, energy: number}> Excess values from C++
---@return table<number, TeamResourceData> teams Full team data structure
local function BuildTeamData(excesses)
	local teamList = springRepo.GetTeamList() or {}
	
	for _, teamId in ipairs(teamList) do
		local mCur, mStor, mPull, mInc, mExp, mShare = springRepo.GetTeamResources(teamId, "metal")
		local eCur, eStor, ePull, eInc, eExp, eShare = springRepo.GetTeamResources(teamId, "energy")
		
		if mCur and eCur then
			local _, _, isDead, _, _, allyTeam = springRepo.GetTeamInfo(teamId)
			local excess = excesses[teamId] or { metal = 0, energy = 0 }
			
			local team = teamsCache[teamId]
			if not team then
				team = {
					metal = {},
					energy = {},
				}
				teamsCache[teamId] = team
			end
			
			team.allyTeam = allyTeam
			team.isDead = (isDead == true)
			
			local metal = team.metal
			metal.resourceType = "metal"
			metal.current = mCur
			metal.storage = mStor
			metal.pull = mPull
			metal.income = mInc
			metal.expense = mExp
			metal.shareSlider = mShare
			metal.excess = excess.metal
			
			local energy = team.energy
			energy.resourceType = "energy"
			energy.current = eCur
			energy.storage = eStor
			energy.pull = ePull
			energy.income = eInc
			energy.expense = eExp
			energy.shareSlider = eShare
			energy.excess = excess.energy
		end
	end
	
	return teamsCache
end

---Apply EconomyTeamResult[] to teams via Spring API
---@param results EconomyTeamResult[]
local function ApplyResults(results)
	local teamStats = {}
	
	for _, result in ipairs(results) do
		local teamId = result.teamId
		local resName = result.resourceType == ResourceType.METAL and "metal" or "energy"
		local resIdx = result.resourceType == ResourceType.METAL and 1 or 2
		
		springRepo.SetTeamResource(teamId, resName, result.current)
		
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
			springRepo.AddTeamResourceStats(teamId, statsSentBuffer)
		end
		if stats.received[1] > 0 or stats.received[2] > 0 then
			statsRecvBuffer.received[1] = stats.received[1]
			statsRecvBuffer.received[2] = stats.received[2]
			springRepo.AddTeamResourceStats(teamId, statsRecvBuffer)
		end
	end
end

---@param frame number Game frame from C++
---@param excesses table<number, {metal: number, energy: number}> Excess values only
---@return boolean handled Whether Lua handled the excess
local function ResourceExcessController(frame, excesses)
	if tracyAvailable then tracy.ZoneBeginN("RE_Lua") end

	local teams = BuildTeamData(excesses)
	
	local success, results = pcall(WaterfillSolver.SolveToResults, springRepo, teams)
	if not success then
		if tracyAvailable then tracy.ZoneEnd() end
		Spring.Log("ResourceTransferController", LOG.ERROR, "Solver: " .. tostring(results))
		return false
	end
	
	ApplyResults(results)
	
	pendingPolicyUpdate = true
	pendingPolicyFrame = frame
	
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
	Spring.Echo("[ResourceTransferController] Initialize starting...")
	
	-- Mode is now controlled at engine level via modrules.lua economy_audit_mode
	local currentMode = Game.economyAuditMode or "off"
	Spring.Echo("[ResourceTransferController] Engine audit mode: " .. tostring(currentMode))
	
	local teamList = springRepo.GetTeamList()
	Spring.Echo("[ResourceTransferController] Found " .. #teamList .. " teams")
	for _, senderTeamId in ipairs(teamList) do
		InitializeNewTeam(senderTeamId)
	end
	lastPolicyUpdate = springRepo.GetGameFrame()
	
	-- Register appropriate controller(s) based on mode
	local registerPE = currentMode == "process_economy" or currentMode == "alternate"
	local registerRE = currentMode == "resource_excess" or currentMode == "alternate"
	
	if registerPE then
		Spring.Echo("[ResourceTransferController] Registering GameEconomyController...")
		---@type GameEconomyController
		local controller = { ProcessEconomy = ProcessEconomy }
		Spring.SetEconomyController(controller)
		Spring.Echo("[ResourceTransferController] SUCCESS: Registered GameEconomyController")
	end
	
	if registerRE then
		Spring.Echo("[ResourceTransferController] Registering ResourceExcessController...")
		if Spring.SetResourceExcessController then
			Spring.SetResourceExcessController(ResourceExcessController)
			Spring.Echo("[ResourceTransferController] SUCCESS: Registered ResourceExcessController")
		else
			Spring.Log("ResourceTransferController", LOG.WARNING, "SetResourceExcessController not available")
		end
	end
	
	if not registerPE and not registerRE then
		Spring.Echo("[ResourceTransferController] Mode '" .. tostring(currentMode) .. "' - no controllers registered")
	end
end

function gadget:GameStart()
	if not Spring.IsEconomyAuditEnabled() then return end
	
	local gaiaTeamId = Spring.GetGaiaTeamID()
	local teamList = springRepo.GetTeamList() or {}
	for _, teamId in ipairs(teamList) do
		local _, leader, _, isAI, _, allyTeam = Spring.GetTeamInfo(teamId)
		local isGaia = (teamId == gaiaTeamId)
		local name
		if isAI then
			local niceName = Spring.GetGameRulesParam('ainame_' .. teamId)
			if niceName then
				name = niceName
			else
				local _, aiName = Spring.GetAIInfo(teamId)
				name = aiName or ("AI " .. teamId)
			end
		else
			local playerName = leader and Spring.GetPlayerInfo(leader, false) or nil
			name = playerName or ("Player " .. teamId)
		end
		EconomyLog.TeamInfo(teamId, name, isAI, allyTeam, isGaia)
	end
end

function gadget:GameFrame(frame)
	DeferredPolicyUpdate()
end
