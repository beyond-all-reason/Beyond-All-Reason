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

--------------------------------------------------------------------------------
-- Module globals
--------------------------------------------------------------------------------

GG = GG or {}

---@type ISpring
local springRepo = Spring
local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 30 -- Update every SlowUpdate (1 second at 30fps)

--------------------------------------------------------------------------------
-- GG API (Lua-side conveniences for other gadgets)
--------------------------------------------------------------------------------

function GG.GetTeamResourceData(teamID, resource)
	return springRepo.GetTeamResourceData(teamID, resource)
end

function GG.SetTeamResourceData(teamID, resourceData)
	return springRepo.SetTeamResourceData(teamID, resourceData)
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
	
	-- Register ProcessEconomy controller unless in pure RESOURCE_EXCESS mode
	-- (in ALTERNATE mode, the engine will skip calling ProcessEconomy on alternate cycles)
	if currentMode ~= "resource_excess" then
		Spring.Echo("[ResourceTransferController] Registering GameEconomyController...")
		---@type GameEconomyController
		local controller = { ProcessEconomy = ProcessEconomy }
		Spring.SetEconomyController(controller)
		Spring.Echo("[ResourceTransferController] SUCCESS: Registered GameEconomyController")
	else
		Spring.Echo("[ResourceTransferController] RESOURCE_EXCESS mode - skipping ProcessEconomy registration")
		Spring.Echo("[ResourceTransferController] ResourceExcessController will handle excess via gadget:ResourceExcess")
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
