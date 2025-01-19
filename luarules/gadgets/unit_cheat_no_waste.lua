function gadget:GetInfo()
	return {
		name = "Cheat No Waste",
		desc = "Increase buildpower to stop wasting resources",
		author = "SethDGamre",
		date = "January 2025",
		license = "GPLv2",
		layer = 1,
		enabled = true
	}
end

--early exits
if not gadgetHandler:IsSyncedCode() then return false end

local modOptions = Spring.GetModOptions()

if modOptions.nowasting == "default" or modOptions.nowasting == "disabled" then return false end

--tables
local aiTeams = {}
local humanTeams = {}
local boostableTeams = {}
local boostableAllies = {}
local overflowingAllies = {}
local teamBoostableUnits = {}
local builderWatchDefs = {}
local builderWatch = {}

local isAllyTeamWinning
local averageAlliedTechGuesstimate

function gadget:Initialize()
	aiTeams = GG.PowerLib.AiTeams
	for teamID, _ in pairs (aiTeams) do
		boostableTeams[teamID] = true
	end
	humanTeams = GG.PowerLib.HumanTeams
	if modOptions.nowasting == "all" then
		for teamID, _ in pairs (humanTeams) do
			boostableTeams[teamID] = true
		end
	end

	for teamID, _ in pairs(boostableTeams) do
		local alliedTeam = select(6, Spring.GetTeamInfo(teamID))
		boostableAllies[alliedTeam] = boostableAllies[alliedTeam] or {}
		boostableAllies[alliedTeam][teamID] = true
		overflowingAllies[alliedTeam] = 1
		teamBoostableUnits[teamID] = {}
	end

	isAllyTeamWinning = GG.PowerLib.IsAllyTeamWinning
	averageAlliedTechGuesstimate = GG.PowerLib.AverageAlliedTechGuesstimate
end

--localized functions
local spGetTeamResources = Spring.GetTeamResources
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed

for id, def in pairs(UnitDefs) do
	if def.buildSpeed and def.buildSpeed > 0 and def.speed and def.speed == 0 then
		builderWatchDefs[id] = def.buildSpeed
	end
end

local function updateTeamOverflowing(alliedTeam, oldMultiplier)
	local teamIDs = boostableAllies[alliedTeam]

    local totalMetal = 0
    local totalMetalStorage = 0
	local totalMetalReceived = 0
    local metalPercentile = 0

	local wastingMetal = true
	for teamID, _ in pairs(teamIDs) do
		local metal, metalStorage, pull, metalIncome, metalExpense,share, metalSent, metalReceived = spGetTeamResources(teamID, "metal")
		totalMetal = totalMetal + metal
		totalMetalStorage = totalMetalStorage + metalStorage
		totalMetalReceived = totalMetalReceived + metalReceived

		metalPercentile = totalMetal / totalMetalStorage
		if metalPercentile < 0.95 then
			wastingMetal = false
		end
	end
	if totalMetalStorage / 4 > totalMetal then
		local newMultiplier = math.max(oldMultiplier / 1.25, 1)
		return newMultiplier
	elseif wastingMetal == true and (modOptions.dynamiccheats == false or 
									(isAllyTeamWinning(_, alliedTeam, 1.5) == false and averageAlliedTechGuesstimate(_, alliedTeam) >= 1)) then
		local newMultiplier = math.min(oldMultiplier * 1.25, 100)
		Spring.Echo(alliedTeam, "Increase BP", newMultiplier)
		return newMultiplier
	else
		return oldMultiplier
	end
end

local function updateAllyUnitsBuildPowers(alliedTeam, boostMultiplier)
	local teamIDs = boostableAllies[alliedTeam]
	for teamID, _ in pairs(teamIDs) do
		local units = teamBoostableUnits[teamID]
		for unitID, buildPower in pairs(units) do
			if builderWatch[unitID] then
				spSetUnitBuildSpeed(unitID, buildPower * boostMultiplier)
			else
				units[unitID] = nil
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderWatchDefs[unitDefID] then
		if teamBoostableUnits[unitTeam] then
			teamBoostableUnits[unitTeam][unitID] = builderWatchDefs[unitDefID]
			builderWatch[unitID] = true
		end
	end
end

function gadget:UnitDestroyed(unitID)
	builderWatch[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % 120 == 0 then
		for alliedTeam, oldBuildPowerMultiplier in pairs(overflowingAllies) do
		local newBuildPowerMultiplier = updateTeamOverflowing(alliedTeam, oldBuildPowerMultiplier)
			if newBuildPowerMultiplier ~= 1 then
				updateAllyUnitsBuildPowers(alliedTeam, newBuildPowerMultiplier)
				overflowingAllies[alliedTeam] = newBuildPowerMultiplier
			end
			if newBuildPowerMultiplier == 1 then
				for teamID, _ in pairs(boostableAllies[alliedTeam]) do
					Spring.SetTeamRulesParam(teamID, "suspendbuilderpriority", 0)
				end
			else
				for teamID, _ in pairs(boostableAllies[alliedTeam]) do
					Spring.SetTeamRulesParam(teamID, "suspendbuilderpriority", 1)
				end
			end
		end
	end
end