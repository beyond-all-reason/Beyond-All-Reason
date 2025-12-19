local gadget = gadget ---@type Gadget

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
local AuditLog = VFS.Include("common/luaUtilities/economy/economy_audit_log.lua")
local Stopwatch = VFS.Include("common/luaUtilities/stopwatch.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/bar_economy_waterfill_solver.lua")

local ResourceType = SharedEnums.ResourceType

--------------------------------------------------------------------------------
-- Module state
--------------------------------------------------------------------------------

local springRepo = Spring
local isActive = false

--------------------------------------------------------------------------------
-- ResourceExcess Implementation
-- This mirrors the ProcessEconomy path but uses the ResourceExcess callin
--------------------------------------------------------------------------------

---Build team data table from current game state + excess table
---@param excesses table<number, number[]> { [teamID] = {metal, energy} }
---@return TeamResourceData[]
local function BuildTeamData(excesses)
	local teams = {}
	local allTeams = springRepo.GetTeamList()
	
	for _, teamID in ipairs(allTeams) do
		local _, _, _, _, _, _, _, gaia = springRepo.GetTeamInfo(teamID)
		if not gaia then
			local mCur, mSto, _, _, _, mShare = springRepo.GetTeamResources(teamID, "metal")
			local eCur, eSto, _, _, _, eShare = springRepo.GetTeamResources(teamID, "energy")
			
			-- Get excess from the excesses table (resources that overflowed this frame)
			local teamExcess = excesses[teamID]
			local metalExcess = teamExcess and teamExcess[1] or 0
			local energyExcess = teamExcess and teamExcess[2] or 0
			
			-- Add the excess back to current (it was already clamped by engine)
			-- This gives us the "true" amount before clamping
			local metalWithExcess = (mCur or 0) + metalExcess
			local energyWithExcess = (eCur or 0) + energyExcess
			
			local _, allyTeam = springRepo.GetTeamInfo(teamID)
			
			teams[#teams + 1] = {
				id = teamID,
				allyTeam = allyTeam,
				metal = {
					current = metalWithExcess,
					storage = mSto or 1000,
					shareSlider = mShare or 0.99,
					excess = metalExcess,
				},
				energy = {
					current = energyWithExcess,
					storage = eSto or 1000,
					shareSlider = eShare or 0.95,
					excess = energyExcess,
				}
			}
		end
	end
	
	return teams
end

---Apply the waterfill results back to teams
---@param results TeamResourceData[]
---@param frame number
local function ApplyResults(results, frame)
	for _, team in ipairs(results) do
		if team.id then
			-- Clamp values to storage to prevent runaway growth
			local metalFinal = math.min(team.metal.current, team.metal.storage)
			local energyFinal = math.min(team.energy.current, team.energy.storage)
			
			-- Set the final resource levels (clamped)
			springRepo.SetTeamResource(team.id, "metal", metalFinal)
			springRepo.SetTeamResource(team.id, "energy", energyFinal)
			
			-- Update cumulative sent tracking
			local mSent = springRepo.GetTeamRulesParam(team.id, "cumulativeMetalSent") or 0
			local eSent = springRepo.GetTeamRulesParam(team.id, "cumulativeEnergySent") or 0
			springRepo.SetTeamRulesParam(team.id, "cumulativeMetalSent", mSent + (team.metal.sent or 0))
			springRepo.SetTeamRulesParam(team.id, "cumulativeEnergySent", eSent + (team.energy.sent or 0))
			
			-- Track stats using the correct API format: AddTeamResourceStats(teamID, {stat = {metal, energy}})
			local mSentVal = team.metal.sent or 0
			local eSentVal = team.energy.sent or 0
			local mRecvVal = team.metal.received or 0
			local eRecvVal = team.energy.received or 0
			
			if mSentVal > 0 or eSentVal > 0 then
				springRepo.AddTeamResourceStats(team.id, { sent = { mSentVal, eSentVal } })
			end
			if mRecvVal > 0 or eRecvVal > 0 then
				springRepo.AddTeamResourceStats(team.id, { received = { mRecvVal, eRecvVal } })
			end
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
	
	local stopwatch = Stopwatch.new(springRepo.GetAuditTimer)
	stopwatch:Start()
	
	-- Build team data from current state + excesses
	local teams = BuildTeamData(excesses)
	stopwatch:Breakpoint("BuildTeamData")
	
	if #teams == 0 then
		return true
	end
	
	-- Get tax config
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	
	-- Log frame start
	AuditLog.FrameStart(frame, taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY], #teams)
	
	-- Run the waterfill solver
	local updatedTeams, allLedgers = WaterfillSolver.ProcessEconomy(springRepo, teams, frame)
	stopwatch:Breakpoint("WaterfillSolver")
	
	-- Apply results back to engine
	ApplyResults(updatedTeams, frame)
	stopwatch:Breakpoint("ApplyResults")
	
	-- Log outputs
	for _, team in ipairs(updatedTeams) do
		if team.id then
			AuditLog.TeamOutput(frame, team.id, "metal", team.metal.current, team.metal.sent or 0, team.metal.received or 0)
			AuditLog.TeamOutput(frame, team.id, "energy", team.energy.current, team.energy.sent or 0, team.energy.received or 0)
		end
	end
	
	stopwatch:Log(frame, "[SolverAudit-ResourceExcess]")
	
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
	local mode = AuditLog.GetMode()
	Spring.Echo("[ResourceExcessController] Current mode: " .. tostring(mode))
	
	if mode == "process_economy" then
		Spring.Echo("[ResourceExcessController] ProcessEconomy mode - this gadget will be passive")
		isActive = false
	else
		Spring.Echo("[ResourceExcessController] ResourceExcess or Alternate mode - this gadget will handle excess")
		isActive = true
	end
end

