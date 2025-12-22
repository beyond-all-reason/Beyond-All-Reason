---@class ResourceExcessGadget : Gadget
---@field ResourceExcess fun(self, excesses: table<number, number[]>): boolean
local gadget = gadget ---@type ResourceExcessGadget

function gadget:GetInfo()
	return {
		name      = "Resource Excess Controller",
		desc      = "Handles resource excess via ResourceExcess callin (alternative to ProcessEconomy)",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = -199,  -- Load after Resource Transfer Controller
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/bar_economy_waterfill_solver.lua")

local ResourceType = SharedEnums.ResourceType

--------------------------------------------------------------------------------
-- Module state
--------------------------------------------------------------------------------

local springRepo = Spring
local isActive = false
local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 30 

--------------------------------------------------------------------------------
-- ResourceExcess Implementation
-- This mirrors the ProcessEconomy path but uses the ResourceExcess callin
-- Note: economyAudit.Begin("RE", frame) is called by C++ before this runs,
-- so source_path and frame context are already set for all logging.
--------------------------------------------------------------------------------

---Build team data table from current game state + excess table
---@param excesses table<number, number[]> { [teamID] = {metal, energy} }
---@return table<number, TeamResourceData>
local function BuildTeamData(excesses)
	local teams = {}
	local allTeams = springRepo.GetTeamList()
	
	for _, teamID in ipairs(allTeams) do
		local _, _, _, _, _, _, _, gaia = springRepo.GetTeamInfo(teamID)
		if not gaia then
			local mCur, mSto, mPull, mInc, mExp, mShare = springRepo.GetTeamResources(teamID, "metal")
			local eCur, eSto, ePull, eInc, eExp, eShare = springRepo.GetTeamResources(teamID, "energy")
			
			local teamExcess = excesses[teamID]
			local metalExcess = teamExcess and teamExcess[1] or 0
			local energyExcess = teamExcess and teamExcess[2] or 0
			
			local _, allyTeam = springRepo.GetTeamInfo(teamID)
			
			---@type TeamResourceData
			local teamData = {
				allyTeam = allyTeam,
				isDead = false,
				metal = {
					resourceType = "metal",
					current = mCur or 0,
					storage = mSto or 1000,
					pull = mPull or 0,
					income = mInc or 0,
					expense = mExp or 0,
					shareSlider = mShare or 0.99,
					excess = metalExcess,
				},
				energy = {
					resourceType = "energy",
					current = eCur or 0,
					storage = eSto or 1000,
					pull = ePull or 0,
					income = eInc or 0,
					expense = eExp or 0,
					shareSlider = eShare or 0.95,
					excess = energyExcess,
				}
			}
			teams[teamID] = teamData
		end
	end
	
	return teams
end

---Apply the waterfill results back to teams
---@param results table<number, TeamResourceData>
---@param frame number
---@param ledgers table<number, table<ResourceType, EconomyFlowLedger>>
local function ApplyResults(results, frame, ledgers)
	for teamId, team in pairs(results) do
		-- Clamp values to storage to prevent runaway growth
		local metalFinal = math.min(team.metal.current, team.metal.storage)
		local energyFinal = math.min(team.energy.current, team.energy.storage)
		
		-- Set the final resource levels (clamped)
		springRepo.SetTeamResource(teamId, "metal", metalFinal)
		springRepo.SetTeamResource(teamId, "energy", energyFinal)
		
		local ledger = ledgers[teamId] or {}
		local metalFlow = ledger[ResourceType.METAL] or { sent = 0, received = 0 }
		local energyFlow = ledger[ResourceType.ENERGY] or { sent = 0, received = 0 }

		-- Track stats using the correct API format: AddTeamResourceStats(teamID, {stat = {metal, energy}})
		local mSentVal = metalFlow.sent
		local eSentVal = energyFlow.sent
		local mRecvVal = metalFlow.received
		local eRecvVal = energyFlow.received
		
		if mSentVal > 0 or eSentVal > 0 then
			springRepo.AddTeamResourceStats(teamId, { sent = { mSentVal, eSentVal } })
		end
		if mRecvVal > 0 or eRecvVal > 0 then
			springRepo.AddTeamResourceStats(teamId, { received = { mRecvVal, eRecvVal } })
		end
	end
end

---Check if any team has excess resources
---@param excesses table<number, number[]>
---@return boolean
local function HasAnyExcess(excesses)
	for teamID, excess in pairs(excesses) do
		if excess[1] > 0 or excess[2] > 0 then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Gadget Callins
--------------------------------------------------------------------------------

---@param excesses table<number, number[]> { [teamID] = {metal, energy} }
---@return boolean handled Whether Lua handled the excess
function gadget:ResourceExcess(excesses)
	local frame = springRepo.GetGameFrame()
	
	-- If no excess, nothing to do
	if not HasAnyExcess(excesses) then
		return true  -- We handled it (trivially)
	end
	
	-- Build team data from current state + excesses
	local teams = BuildTeamData(excesses)
	EconomyLog.Breakpoint("LuaMunge")
	
	local teamCount = 0
	for _ in pairs(teams) do teamCount = teamCount + 1 end
	
	if teamCount == 0 then
		return true
	end
	
	-- Get tax config
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	
	-- Log frame start
	EconomyLog.FrameStart(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY], teamCount)
	
	-- Run the waterfill solver
	local updatedTeams, allLedgers = WaterfillSolver.Solve(springRepo, teams)
	EconomyLog.Breakpoint("Solver")
	
	-- Apply results back to engine
	ApplyResults(updatedTeams, frame, allLedgers)
	EconomyLog.Breakpoint("PostMunge")
	
	-- Log outputs
	for teamId, team in pairs(updatedTeams) do
		local ledger = allLedgers[teamId] or {}
		local m = ledger[ResourceType.METAL] or {}
		local e = ledger[ResourceType.ENERGY] or {}
		EconomyLog.TeamOutput(teamId, "metal", team.metal.current, m.sent or 0, m.received or 0)
		EconomyLog.TeamOutput(teamId, "energy", team.energy.current, e.sent or 0, e.received or 0)
	end
	
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory)
	EconomyLog.Breakpoint("PolicyCache")
	
	return true  -- We handled the excess
end

function gadget:Initialize()
	Spring.Echo("[ResourceExcessController] Initialize")
	
	-- Check if the ResourceExcess callin is available
	if not gadget.ResourceExcess then
		Spring.Echo("[ResourceExcessController] WARNING: ResourceExcess callin not available - need engine with PR 2642")
		isActive = false
		return
	end
	
	-- Check mode from engine (set via modrules.lua economy_audit_mode)
	local mode = Game.economyAuditMode or "off"
	Spring.Echo("[ResourceExcessController] Current mode: " .. tostring(mode))
	
	if mode == "process_economy" then
		Spring.Echo("[ResourceExcessController] ProcessEconomy mode - this gadget will be passive")
		isActive = false
	else
		Spring.Echo("[ResourceExcessController] ResourceExcess or Alternate mode - this gadget will handle excess")
		isActive = true
	end
end
