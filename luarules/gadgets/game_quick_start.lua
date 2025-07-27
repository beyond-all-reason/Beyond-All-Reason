function gadget:GetInfo()
	return {
		name = "Quick Start",
		desc = "Commanders instantly build structures until starting resources are expended",
		author = "SethDGamre", 
		date = "July 2025",
		license = "GPLv2",
		layer = 0,
		enabled = true
	}
end

local isSynced = gadgetHandler:IsSyncedCode()
local modOptions = Spring.GetModOptions()
if not isSynced then return false end

local shouldRunGadget = modOptions.quick_start == "enabled" or
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))

if not shouldRunGadget then return false end

local spGetUnitDefID = Spring.GetUnitDefID
local spGetTeamResources = Spring.GetTeamResources
local spGetUnitTeam = Spring.GetUnitTeam
local spSetUnitCosts = Spring.SetUnitCosts
local spSetUnitHealth = Spring.SetUnitHealth
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitPosition = Spring.GetUnitPosition
local mathDiag = math.diag

local teamsToBoost = {}
local teamStartingResources = {}
local teamResourcesSpent = {}
local unitsWithModifiedCosts = {}
local nonPlayerTeams = {}
local commanderStartingPositions = {}

local BUILD_TIME_REDUCTION_MULTIPLIER = 1/100
local ENERGY_REDUCTION_MULTIPLIER = 1/10
local MAX_RANGE = 1000
local UPDATE_FRAMES = 30

local function isBoostableCommander(unitDefinitionID)
	local unitDefinition = UnitDefs[unitDefinitionID]
	return unitDefinition and unitDefinition.customParams and unitDefinition.customParams.iscommander == "1"
end

local function restoreTeamUnitCosts(teamID)
	for unitID, originalCosts in pairs(unitsWithModifiedCosts) do
		local unitTeam = spGetUnitTeam(unitID)
		if unitTeam == teamID then
			spSetUnitCosts(unitID, {
				buildTime = originalCosts.buildTime,
				energyCost = originalCosts.energyCost,
				metalCost = originalCosts.metalCost
			})
			unitsWithModifiedCosts[unitID] = nil
		end
	end
end

local function checkIfNoMoreBoosts()
	for teamID, hasBoost in pairs(teamsToBoost) do
		if hasBoost then
			return false
		end
	end
	return true
end

local function disableBoostForTeam(teamID)
	if teamsToBoost[teamID] then
		teamsToBoost[teamID] = false
		restoreTeamUnitCosts(teamID)
		local shouldDisableGadget = checkIfNoMoreBoosts()
		if shouldDisableGadget then
			gadgetHandler:RemoveGadget(gadget)
		end
	end
end

function gadget:GameStart()
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if not nonPlayerTeams[teamID] then
			local currentMetalAmount = spGetTeamResources(teamID, "metal")
			local currentEnergyAmount = spGetTeamResources(teamID, "energy")
			teamStartingResources[teamID] = {
				metal = currentMetalAmount,
				energy = currentEnergyAmount
			}
			teamResourcesSpent[teamID] = {
				metal = 0,
				energy = 0
			}
			teamsToBoost[teamID] = true
		end
	end
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefinitionID = spGetUnitDefID(unitID)
		local unitTeam = spGetUnitTeam(unitID)
		if isBoostableCommander(unitDefinitionID) and teamsToBoost[unitTeam] then
			local positionX, positionY, positionZ = spGetUnitPosition(unitID)
			if positionX then
				commanderStartingPositions[unitID] = {
					x = positionX,
					y = positionY,
					z = positionZ,
					teamID = unitTeam
				}
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefinitionID, unitTeam, builderID)
	if not teamsToBoost[unitTeam] then
		return
	end
	if not builderID then
		return
	end
	local builderDefinitionID = spGetUnitDefID(builderID)
	if not isBoostableCommander(builderDefinitionID) then
		return
	end
	local unitDefinition = UnitDefs[unitDefinitionID]
	local metalCost = unitDefinition.metalCost or 0
	local energyCost = unitDefinition.energyCost or 0
	local reducedEnergyCost = energyCost * ENERGY_REDUCTION_MULTIPLIER
	local metalRemaining = teamStartingResources[unitTeam].metal - teamResourcesSpent[unitTeam].metal
	local energyRemaining = teamStartingResources[unitTeam].energy - teamResourcesSpent[unitTeam].energy
	local metalAffordabilityPercentage = metalCost > 0 and math.min(1.0, metalRemaining / metalCost) or 1.0
	local energyAffordabilityPercentage = reducedEnergyCost > 0 and math.min(1.0, energyRemaining / reducedEnergyCost) or 1.0
	local overallAffordabilityPercentage = math.min(metalAffordabilityPercentage, energyAffordabilityPercentage)

	if overallAffordabilityPercentage < 1.0 then
		teamResourcesSpent[unitTeam].metal = teamStartingResources[unitTeam].metal
		teamResourcesSpent[unitTeam].energy = teamStartingResources[unitTeam].energy
		local currentHealth, maxHealth = spGetUnitHealth(unitID)
		local partialBuildHealth = maxHealth * overallAffordabilityPercentage
		spSetUnitHealth(unitID, {build = overallAffordabilityPercentage, health = partialBuildHealth})
		disableBoostForTeam(unitTeam)
		return
	end

	teamResourcesSpent[unitTeam].metal = teamResourcesSpent[unitTeam].metal + metalCost
	teamResourcesSpent[unitTeam].energy = teamResourcesSpent[unitTeam].energy + reducedEnergyCost
	local originalBuildTime = unitDefinition.buildTime or 1000
	unitsWithModifiedCosts[unitID] = {
		buildTime = originalBuildTime,
		energyCost = energyCost,
		metalCost = metalCost
	}
	local acceleratedBuildTime = math.max(1, originalBuildTime * BUILD_TIME_REDUCTION_MULTIPLIER)
	spSetUnitCosts(unitID, {
		buildTime = acceleratedBuildTime,
		energyCost = reducedEnergyCost,
		metalCost = metalCost
	})
	local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
	if unitPositionX then
		Spring.SpawnCEG("botrailspawn", unitPositionX, unitPositionY, unitPositionZ, 0, 0, 0)
	end
	if teamResourcesSpent[unitTeam].metal >= teamStartingResources[unitTeam].metal or 
	   teamResourcesSpent[unitTeam].energy >= teamStartingResources[unitTeam].energy then
		disableBoostForTeam(unitTeam)
	end
end

function gadget:GameFrame(frameNumber)
	if frameNumber % UPDATE_FRAMES ~= 0 then
		return
	end
	for unitID, startingPosition in pairs(commanderStartingPositions) do
		if teamsToBoost[startingPosition.teamID] then
			local currentPositionX, currentPositionY, currentPositionZ = spGetUnitPosition(unitID)
			if currentPositionX then
				local deltaX = currentPositionX - startingPosition.x
				local deltaZ = currentPositionZ - startingPosition.z
				local distanceFromStart = mathDiag(deltaX, deltaZ)
				if distanceFromStart > MAX_RANGE then
					disableBoostForTeam(startingPosition.teamID)
				end
			end
		end
	end
end

function gadget:UnitDestroyed(unitID)
	unitsWithModifiedCosts[unitID] = nil
	commanderStartingPositions[unitID] = nil
end

function gadget:Initialize()
	if Spring.GetGameFrame() > 0 then
		gadget:GameStart()
	end
	nonPlayerTeams[Spring.GetGaiaTeamID()] = true
	local scavengerTeamID = Spring.Utilities.GetScavTeamID()
	if scavengerTeamID then
		nonPlayerTeams[scavengerTeamID] = true
	end
	local raptorTeamID = Spring.Utilities.GetRaptorTeamID()
	if raptorTeamID then
		nonPlayerTeams[raptorTeamID] = true
	end
end