---@class ResourceExcessGadget : Gadget
local gadget = gadget ---@type ResourceExcessGadget

function gadget:GetInfo()
	return {
		name      = "Resource Excess Controller",
		desc      = "Handles resource excess via ResourceExcess callin (alternative to ProcessEconomy)",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = -199,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")

local ResourceType = SharedEnums.ResourceType

--------------------------------------------------------------------------------
-- Module state
--------------------------------------------------------------------------------

local springRepo = Spring
local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 30

---@type table<number, TeamResourceData>
local teamsCache = {}

local statsSentBuffer = { sent = { 0, 0 } }
local statsRecvBuffer = { received = { 0, 0 } }

--------------------------------------------------------------------------------
-- ResourceExcess Controller Function
-- 
-- This emulates the per-gadget callin pattern to measure full API overhead.
-- Unlike ProcessEconomy where C++ pre-builds team data, here:
-- 1. C++ only passes the excesses table (teamID -> {metal, energy} excess).
-- 2. Lua must query Spring.GetTeamResources() to build team data.
-- 3. Lua runs the solver AND applies results via Spring.SetTeamResource.
-- 
-- This measures the real cost of the "flexible" per-gadget API pattern where
-- each gadget queries engine state independently.
--
-- C++ timing:
--   economyAudit.Begin("RE", frame)
--   economyAudit.Breakpoint("CppMunge")  -- minimal, just pushing excesses
--   lua_pcall(controller, frame, excesses)
--   economyAudit.Breakpoint("LuaTotal")  -- all Lua work
--   economyAudit.End()
--
-- Lua breakpoints capture internal timing:
--   LuaMunge (API queries) -> Solver -> LuaSetters -> PostMunge -> PolicyCache
--------------------------------------------------------------------------------

---Build team data by querying Spring API - emulates per-gadget lookup pattern
---This is the key overhead we're measuring vs ProcessEconomy's C++ pre-build
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
---This is the key measurement: cost of Lua calling SetTeamResource per team/resource
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
	-- Build team data by querying Spring API (emulates per-gadget pattern)
	local teams = BuildTeamData(excesses)
	
	-- Count teams
	local teamCount = 0
	for _ in pairs(teams) do teamCount = teamCount + 1 end
	
	-- Get tax config and log frame start
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	EconomyLog.FrameStart(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY], teamCount)
	
	-- LuaMunge measures all pre-solver prep work (BuildTeamData, team counting, config)
	EconomyLog.Breakpoint("LuaMunge")
	
	-- Run the waterfill solver
	local success, updatedTeams, allLedgers = pcall(WaterfillSolver.Solve, springRepo, teams)
	if not success then
		Spring.Log("ResourceExcessController", LOG.ERROR, "Solver: " .. tostring(updatedTeams))
		return false
	end
	
	EconomyLog.Breakpoint("Solver")
	
	-- Apply results via Lua->C++ API calls (this is what we're measuring)
	ApplyResults(updatedTeams, allLedgers)
	
	EconomyLog.Breakpoint("LuaSetters")
	
	-- Log team outputs
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
	
	-- Update policy cache periodically
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory)
	
	EconomyLog.Breakpoint("PolicyCache")
	
	return true
end

--------------------------------------------------------------------------------
-- Gadget Callins
--------------------------------------------------------------------------------

local controllerRegistered = false
local activeMode = "off"

local function RegisterController()
	if controllerRegistered then return end
	
	if not Spring.SetResourceExcessController then
		Spring.Log("ResourceExcessController", LOG.WARNING, "SetResourceExcessController not available")
		return
	end
	
	Spring.SetResourceExcessController(ResourceExcessController)
	controllerRegistered = true
	Spring.Log("ResourceExcessController", LOG.INFO, "Registered")
end

function gadget:Initialize()
	activeMode = Game.economyAuditMode or "off"
	Spring.Log("ResourceExcessController", LOG.INFO, "Init mode=" .. tostring(activeMode))
	
	if activeMode == "process_economy" then
		return
	end
	
	RegisterController()
end

function gadget:GamePreload()
end

function gadget:GameStart()
	if activeMode ~= "process_economy" then
		controllerRegistered = false
		RegisterController()
	end
end
