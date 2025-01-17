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


local aiTeams
local humanTeams
local teams = {}


function gadget:Initialize()
	aiTeams = GG.PowerLib.AiTeams
	Spring.Echo(aiTeams)
	humanTeams = GG.PowerLib.HumanTeams
end

--Spring.Echo("resultant teams 2", teams)

if modOptions.nowasting == "ai" and not next(teams) then Spring.Echo("no AI teams") return false end

Spring.Echo("test2", GG.PowerLib.AiTeams, GG.PowerLib.HumanTeams)

Spring.Echo("the teams", aiTeams, humanTeams)
for teamID, _ in pairs (aiTeams) do
	teams[teamID] = true
	--Spring.Echo("robo teamID", teamID)
end
if modOptions.nowasting == "all" then
	for teamID, _ in pairs (humanTeams) do
		teams[teamID] = true
		--Spring.Echo("player teamID", teamID)
	end
end

--set teams to boost
local boostableAllies = {}
local overflowingAllies = {}
local teamBoostableUnits = {}

for teamID, _ in pairs(teams) do
	local alliedTeam = select(6, Spring.GetTeamInfo(teamID))
	Spring.Echo("GetTeamInfo", Spring.GetTeamInfo(teamID))
	Spring.Echo("alliedteam", alliedTeam, "boostableAllies[alliedTeam]", boostableAllies[alliedTeam])
	boostableAllies[alliedTeam] = boostableAllies[alliedTeam] or {}
	boostableAllies[alliedTeam][teamID] = true
	overflowingAllies[alliedTeam] = 1
	teamBoostableUnits[teamID] = {}
end
--Spring.Echo("Boostable Teams", boostableAllies)



--localized functions
local spGetTeamResources = Spring.GetTeamResources
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed

--tables
local builderWatchDefs = {}
local builderWatch = {}

for id, def in pairs(UnitDefs) do
	if def.buildSpeed then
		builderWatchDefs[id] = def.buildSpeed
	end
end

local function updateTeamOverflowing(alliedTeam)
	local teamIDs = boostableAllies[alliedTeam]
	local allyteamOverflowingMetal = 1
    local allyteamOverflowingEnergy = 1

    local totalEnergy = 0
    local totalEnergyStorage = 0
    local totalMetal = 0
    local totalMetalStorage = 0
    local energyPercentile, metalPercentile

	for teamID, _ in pairs(teamIDs) do
		local energy, energyStorage, _, _, _, energyShare, energySent = spGetTeamResources(teamID, "energy")
		totalEnergy = totalEnergy + energy
		totalEnergyStorage = totalEnergyStorage + energyStorage
		local metal, metalStorage, _, _, _, metalShare, metalSent = spGetTeamResources(teamID, "metal")
		totalMetal = totalMetal + metal
		totalMetalStorage = totalMetalStorage + metalStorage

		energyPercentile = totalEnergy / totalEnergyStorage
		metalPercentile = totalMetal / totalMetalStorage
	end    
	energyPercentile = totalEnergy / totalEnergyStorage
	metalPercentile = totalMetal / totalMetalStorage
	if energyPercentile > 0.975 then
		allyteamOverflowingEnergy = (energyPercentile - 0.975) * (1 / 0.025)
	end
	if metalPercentile > 0.975 then
		allyteamOverflowingMetal = (metalPercentile - 0.975) * (1 / 0.025)
	end

	local overflowMultiplier = math.max(allyteamOverflowingEnergy, allyteamOverflowingMetal, 1)
	return overflowMultiplier
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
	if frame % 90 == 0 then
		for alliedTeam, oldBuildPowerMultiplier in pairs(overflowingAllies) do
		local newBuildPowerMultiplier = updateTeamOverflowing(alliedTeam)
			if oldBuildPowerMultiplier ~= newBuildPowerMultiplier then
				updateAllyUnitsBuildPowers(alliedTeam, newBuildPowerMultiplier)
			end
		end
	end
end