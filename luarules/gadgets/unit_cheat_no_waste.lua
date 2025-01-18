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

if modOptions.nowasting == "default" or modOptions.nowasting == "disabled" then Spring.Echo("disabled/default") return false end

local aiTeams = {}
local humanTeams = {}
local boostableTeams = {}

--set teams to boost
local boostableAllies = {}
local overflowingAllies = {}
local teamBoostableUnits = {}
local allAlliesList = Spring.GetAllyTeamList()
for allyNumber, _ in pairs (alliesList) do
	local teamIDs = Spring.GetTeamList (allyNumber)
	allAlliesList[allyNumber] = teamIDs
end
Spring.Echo("Allies and Teams", allAlliesList)
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
	Spring.Echo("Boostable Teams", boostableAllies)
end


--localized functions
local spGetTeamResources = Spring.GetTeamResources
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed

--tables
local builderWatchDefs = {}
local builderWatch = {}

for id, def in pairs(UnitDefs) do
	if def.buildSpeed and def.buildSpeed > 0 then
		builderWatchDefs[id] = def.buildSpeed
		--Spring.Echo(def.name, "def.buildSpeed", def.buildSpeed)
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
		--Spring.Echo(alliedTeam.." returns",  metal, metalStorage, pull, metalIncome, metalExpense,share, metalSent, metalReceived)
		--returns, 359.875702, 1500, 21.6683731, 22.6691532, 21.6683731, 0.99000001, 0, 1.24321938
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
				--Spring.Echo(unitID, buildPower, boostMultiplier)
			else
				units[unitID] = nil
			end
		end
	end
end

local function updateWinningTeams()
	local allyPowersTable = {}
	local totalPower = 0
	local allyTeams = Spring.GetAllyTeamList()
	for alliedTeamNumber, teams in pairs(allAlliesList) do
		local totalAllyPower = 0
		for teamID, _ in pairs(teams) do
			local teamPower = GG.PowerLib.TeamPower(teamID)
			totalAllyPower = totalAllyPower + teamPower
		end
		allyPowersTable[alliedTeamNumber] = totalAllyPower
	end
	local averageAllyPower = totalPower / #allyPowersTable

	for alliedTeamNumber, power in pairs(allyPowersTable) do
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
		--Spring.Echo("AlliedTeam "..alliedTeam, newBuildPowerMultiplier, oldBuildPowerMultiplier)
			if oldBuildPowerMultiplier ~= newBuildPowerMultiplier then
				--Spring.Echo("BP change", newBuildPowerMultiplier)
				updateAllyUnitsBuildPowers(alliedTeam, newBuildPowerMultiplier)
				overflowingAllies[alliedTeam] = newBuildPowerMultiplier
			end
			updateWinningTeams(alliedTeam)
		end
	end
end