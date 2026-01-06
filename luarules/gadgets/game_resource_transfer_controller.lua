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
-- Table Pooling
--------------------------------------------------------------------------------
local resultCache = {}

---@type table<number, table<ResourceType, EconomyTeamResult>>
local resultPool = {}

---@param teamId number
---@param resourceType ResourceType
---@return EconomyTeamResult
local function GetPooledEntry(teamId, resourceType)
	local teamPool = resultPool[teamId]
	if not teamPool then
		teamPool = {}
		resultPool[teamId] = teamPool
	end
	local entry = teamPool[resourceType]
	if not entry then
		entry = {}
		teamPool[resourceType] = entry
	end
	return entry
end

--------------------------------------------------------------------------------
-- ProcessEconomy Controller Function
-- 
-- This is called by C++ via the registered controller pattern.
-- Unlike ResourceExcess where Lua does SetTeamResource calls, here C++
-- applies the results. This measures the cost of a centralized controller
-- where the engine handles internal state changes.
--
-- C++ timing:
--   economyAudit.Begin("PE", frame)
--   economyAudit.Breakpoint("CppMunge")  -- after building teams table
--   lua_pcall(ProcessEconomy, frame, teams) -> returns results
--   economyAudit.Breakpoint("LuaTotal")  -- after Lua returns
--   C++ iterates results and applies via ParseEconomyResult
--   economyAudit.Breakpoint("CppSetters")  -- after applying
--   economyAudit.End()
--
-- Lua breakpoints capture internal timing:
--   LuaMunge -> Solver -> PostMunge -> PolicyCache
--------------------------------------------------------------------------------

---@param frame number
---@param teams table<number, TeamResourceData>
---@return EconomyTeamResult[]
local function ProcessEconomy(frame, teams)
	-- Debug: confirm controller is being called
	if frame % 300 == 0 then
		Spring.Echo("[ProcessEconomyController] Processing frame=" .. frame)
	end
	
	-- Count teams (keys are team IDs, possibly non-consecutive or 0-based)
	local teamCount = 0
	for _ in pairs(teams) do teamCount = teamCount + 1 end
	
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	EconomyLog.FrameStart(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY], teamCount)
	
	EconomyLog.Breakpoint("LuaMunge")

	-- TeamInput logging is handled inside the solver
	local updatedTeams, allLedgers = ResourceTransfer.WaterfillSolve(springRepo, teams)
	
	EconomyLog.Breakpoint("Solver")

	for i = #resultCache, 1, -1 do resultCache[i] = nil end

	local idx = 0
	for teamId, team in pairs(updatedTeams) do
		local ledger = allLedgers[teamId]
		local mSent = ledger[ResourceType.METAL].sent
		local mRecv = ledger[ResourceType.METAL].received
		local eSent = ledger[ResourceType.ENERGY].sent
		local eRecv = ledger[ResourceType.ENERGY].received
		
		EconomyLog.TeamOutput(teamId, "metal", team.metal.current, mSent, mRecv)
		EconomyLog.TeamOutput(teamId, "energy", team.energy.current, eSent, eRecv)
		
		idx = idx + 1
		local mEntry = GetPooledEntry(teamId, ResourceType.METAL)
		mEntry.teamId = teamId
		mEntry.resourceType = ResourceType.METAL
		mEntry.current = team.metal.current
		mEntry.sent = mSent
		mEntry.received = mRecv
		resultCache[idx] = mEntry
		
		idx = idx + 1
		local eEntry = GetPooledEntry(teamId, ResourceType.ENERGY)
		eEntry.teamId = teamId
		eEntry.resourceType = ResourceType.ENERGY
		eEntry.current = team.energy.current
		eEntry.sent = eSent
		eEntry.received = eRecv
		resultCache[idx] = eEntry
	end

	EconomyLog.Breakpoint("PostMunge")

	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory)
	EconomyLog.Breakpoint("PolicyCache")
	
	return resultCache
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

---Apply the solver results back to teams via Spring API
---@param results table<number, TeamResourceData>
---@param ledgers table<number, table<ResourceType, EconomyFlowLedger>>
local function ApplyResults(results, ledgers)
	for teamId, team in pairs(results) do
		if not team.metal or not team.energy then
			break
		end
		
		local metalFinal = math.min(team.metal.current, team.metal.storage)
		local energyFinal = math.min(team.energy.current, team.energy.storage)
		
		springRepo.SetTeamResource(teamId, "metal", metalFinal)
		springRepo.SetTeamResource(teamId, "energy", energyFinal)
		
		local ledger = ledgers[teamId]
		local metalFlow = ledger[ResourceType.METAL]
		local energyFlow = ledger[ResourceType.ENERGY]

		local mSentVal = metalFlow.sent
		local eSentVal = energyFlow.sent
		local mRecvVal = metalFlow.received
		local eRecvVal = energyFlow.received
		
		if mSentVal > 0 or eSentVal > 0 then
			statsSentBuffer.sent[1] = mSentVal
			statsSentBuffer.sent[2] = eSentVal
			springRepo.AddTeamResourceStats(teamId, statsSentBuffer)
		end
		if mRecvVal > 0 or eRecvVal > 0 then
			statsRecvBuffer.received[1] = mRecvVal
			statsRecvBuffer.received[2] = eRecvVal
			springRepo.AddTeamResourceStats(teamId, statsRecvBuffer)
		end
	end
end

---@param frame number Game frame from C++
---@param excesses table<number, {metal: number, energy: number}> Excess values only
---@return boolean handled Whether Lua handled the excess
local function ResourceExcessController(frame, excesses)
	local teams = BuildTeamData(excesses)
	
	local teamCount = 0
	for _ in pairs(teams) do teamCount = teamCount + 1 end
	
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	EconomyLog.FrameStart(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY], teamCount)
	
	EconomyLog.Breakpoint("LuaMunge")
	
	local success, updatedTeams, allLedgers = pcall(WaterfillSolver.Solve, springRepo, teams)
	if not success then
		Spring.Log("ResourceTransferController", LOG.ERROR, "Solver: " .. tostring(updatedTeams))
		return false
	end
	
	EconomyLog.Breakpoint("Solver")
	
	ApplyResults(updatedTeams, allLedgers)
	
	EconomyLog.Breakpoint("LuaSetters")
	
	for teamId, team in pairs(updatedTeams) do
		local ledger = allLedgers[teamId] or {}
		if team.metal then
			local mFlow = ledger[ResourceType.METAL] or { sent = 0, received = 0 }
			EconomyLog.TeamOutput(teamId, ResourceType.METAL, team.metal.current, mFlow.sent, mFlow.received)
		end
		if team.energy then
			local eFlow = ledger[ResourceType.ENERGY] or { sent = 0, received = 0 }
			EconomyLog.TeamOutput(teamId, ResourceType.ENERGY, team.energy.current, eFlow.sent, eFlow.received)
		end
	end
	
	EconomyLog.Breakpoint("PostMunge")
	
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory)
	
	EconomyLog.Breakpoint("PolicyCache")
	
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
