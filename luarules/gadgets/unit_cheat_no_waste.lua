function gadget:GetInfo()
	return {
		name = "Cheat No Waste",
		desc = "Increase buildpower to stop wasting resources",
		author = "SethDGamre",
		date = "January 2025",
		license = "GPLv2",
		layer = 0,
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
local allAlliesList = Spring.GetAllyTeamList()
local builderWatchDefs = {}
local builderWatch = {}
for allyNumber, _ in pairs (allAlliesList) do
	local teamIDs = Spring.GetTeamList (allyNumber)
	allAlliesList[allyNumber] = teamIDs
end
local balancedAllies = {}

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
end

--localized functions
local spGetTeamResources = Spring.GetTeamResources
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed

for id, def in pairs(UnitDefs) do
	if def.buildSpeed and def.buildSpeed > 0 then
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
		if metalPercentile < 0.975 then
			wastingMetal = false
		end
	end    
	if totalMetalStorage > (totalMetal * 4) then
		local newMultiplier = math.max(oldMultiplier / 1.5, 1)
		return newMultiplier
	elseif wastingMetal == true and (not modOptions.dynamiccheats or balancedAllies[alliedTeam] == true) then
		local newMultiplier = math.min(oldMultiplier * 1.5, 100)
		Spring.Echo(alliedTeam, "WE GONNA BOOST", newMultiplier)
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

local function updateWinningTeams()
	local allyPowersTable = {}
	local totalPower = 0
	local allyTeamsCount = 0
	for alliedTeamNumber, teams in pairs(allAlliesList) do
		local totalAllyPower = 0
		for teamID, _ in pairs(teams) do
			local teamPower = GG.PowerLib.TeamPower(teamID)
			totalAllyPower = totalAllyPower + teamPower
		end
		if totalAllyPower > 0 then --ignore dead teams
			allyTeamsCount = allyTeamsCount + 1
			allyPowersTable[alliedTeamNumber] = totalAllyPower
			totalPower = totalPower + totalAllyPower
		end
	end

	local averageAllyPower = totalPower / allyTeamsCount

	for alliedTeamNumber, power in pairs(allyPowersTable) do
		Spring.Echo(alliedTeamNumber, power, averageAllyPower, averageAllyPower * 1.25)
		if power < averageAllyPower * 1.25 then
			balancedAllies[alliedTeamNumber] = true
		else
			balancedAllies[alliedTeamNumber] = false
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
	if frame % 150 == 0 then
		for alliedTeam, oldBuildPowerMultiplier in pairs(overflowingAllies) do
		local newBuildPowerMultiplier = updateTeamOverflowing(alliedTeam, oldBuildPowerMultiplier)
			if oldBuildPowerMultiplier ~= newBuildPowerMultiplier then
				updateAllyUnitsBuildPowers(alliedTeam, newBuildPowerMultiplier)
				overflowingAllies[alliedTeam] = newBuildPowerMultiplier
			end
			updateWinningTeams(alliedTeam)
			Spring.Echo("BalancedAllies", balancedAllies)
		end
	end
end