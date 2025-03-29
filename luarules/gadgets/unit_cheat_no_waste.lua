local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Cheat No Waste",
		desc = "Increase buildpower for human/AI player teams to stop wasting resources",
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

--static variables

--increasing this will magnify the rate at which buildpower is increased or decayed in a compounding fashion.
local buildPowerCompounder = 1.25

--the max compounded buildpower multiplier allowed
local maxBuildPowerMultiplier = 20

--(dynamic cheats only) while allied teams have a total power this many times greater than the average of all player teams, cheating is suspended
local dynamicModeAllyIsWinningRatio = 1.5

--(dynamic cheats only) if the allied teams' tech level is guesstimated below this number, cheating isn't allowed.
local minimumTechLvlToCheat = 1

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

--localized functions
local spGetTeamResources = Spring.GetTeamResources
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed

for id, def in pairs(UnitDefs) do
	if def.buildSpeed and def.buildSpeed > 0 and def.speed and def.speed == 0 then --we only want base factories and construction turrets to get boosted
		builderWatchDefs[id] = def.buildSpeed
	end
end

local function updateTeamOverflowing(allyID, oldMultiplier)
	--static
	local metalToStorageRatioMultiplier = 0.25
	local isWastingPercentileThreshold = 0.95

	--variables
	local teamIDs = boostableAllies[allyID]
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
		if metalPercentile < isWastingPercentileThreshold then
			wastingMetal = false
		end
	end

	local alliesAreWinning = isAllyTeamWinning(_, allyID, dynamicModeAllyIsWinningRatio)

	if totalMetalStorage * metalToStorageRatioMultiplier > totalMetal or (modOptions.dynamiccheats == true and alliesAreWinning == true) then
		local newMultiplier = math.max(oldMultiplier / buildPowerCompounder, 1)
		return newMultiplier
	elseif wastingMetal == true and (modOptions.dynamiccheats == false or
									(alliesAreWinning == false and averageAlliedTechGuesstimate(_, allyID) >= minimumTechLvlToCheat)) then
		local newMultiplier = math.min(oldMultiplier * buildPowerCompounder, maxBuildPowerMultiplier)
		return newMultiplier
	else
		return oldMultiplier
	end
end

local function updateAllyUnitsBuildPowers(allyID, boostMultiplier)
	local teamIDs = boostableAllies[allyID]
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

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	builderWatch[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % 600 == 0 then
		for allyID, oldBuildPowerMultiplier in pairs(overflowingAllies) do
		local newBuildPowerMultiplier = updateTeamOverflowing(allyID, oldBuildPowerMultiplier)
			if newBuildPowerMultiplier ~= 1 then
				updateAllyUnitsBuildPowers(allyID, newBuildPowerMultiplier)
				overflowingAllies[allyID] = newBuildPowerMultiplier
			end
			if newBuildPowerMultiplier == 1 then
				for teamID, _ in pairs(boostableAllies[allyID]) do
					Spring.SetTeamRulesParam(teamID, "suspendbuilderpriority", 0)
				end
			else
				for teamID, _ in pairs(boostableAllies[allyID]) do
					Spring.SetTeamRulesParam(teamID, "suspendbuilderpriority", 1)
				end
			end
		end
	end
end

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
		local allyID = select(6, Spring.GetTeamInfo(teamID))
		boostableAllies[allyID] = boostableAllies[allyID] or {}
		boostableAllies[allyID][teamID] = true
		overflowingAllies[allyID] = 1
		teamBoostableUnits[teamID] = {}
	end

	isAllyTeamWinning = GG.PowerLib.IsAllyTeamWinning
	averageAlliedTechGuesstimate = GG.PowerLib.AverageAlliedTechGuesstimate
end