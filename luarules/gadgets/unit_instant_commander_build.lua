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
local modoptions = Spring.GetModOptions()
if not isSynced then return false end

local shouldRun = modoptions.quick_start == "enabled" or
	(modoptions.quick_start == "default" and (modoptions.temp_enable_territorial_domination or modoptions.deathmode == "territorial_domination"))

if not shouldRun then return false end

local spGetUnitDefID = Spring.GetUnitDefID
local spGetTeamResources = Spring.GetTeamResources
local spGetUnitTeam = Spring.GetUnitTeam
local spSetUnitCosts = Spring.SetUnitCosts
local spSetUnitHealth = Spring.SetUnitHealth
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitPosition = Spring.GetUnitPosition
local mathDiag = math.diag

local teamInstantBuild = {}
local teamStartingResources = {}
local teamResourcesSpent = {}
local modifiedUnits = {}
local nonPlayerTeams = {}
local commanderStartingPositions = {}

local BUILD_TIME_REDUCTION_MULTIPLIER = 0.01
local ENERGY_REDUCTION_MULTIPLIER = 1/10
local MAX_RANGE = 750
local UPDATE_FRAMES = 30

local function isInstantBuildCommander(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	return unitDef and unitDef.customParams and unitDef.customParams.iscommander == "1"
end

local function restoreTeamUnitCosts(teamID)
	for unitID, originalCosts in pairs(modifiedUnits) do
		local unitTeam = spGetUnitTeam(unitID)
		if unitTeam == teamID then
			spSetUnitCosts(unitID, {
				buildTime = originalCosts.buildTime,
				energyCost = originalCosts.energyCost,
				metalCost = originalCosts.metalCost
			})
			modifiedUnits[unitID] = nil
		end
	end
end

local function checkIfNoMoreBoosts()
	for teamID, hasInstantBuild in pairs(teamInstantBuild) do
		if hasInstantBuild then
			return false
		end
	end
	return true
end

local function disableInstantBuildForTeam(teamID)
	if teamInstantBuild[teamID] then
		teamInstantBuild[teamID] = false
		restoreTeamUnitCosts(teamID)
		local disableGadget = checkIfNoMoreBoosts()
		if disableGadget then
			gadgetHandler:RemoveGadget(gadget)
		end
	end
end

function gadget:GameStart()
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if not nonPlayerTeams[teamID] then
			local metalCurrent = spGetTeamResources(teamID, "metal")
			local energyCurrent = spGetTeamResources(teamID, "energy")
			teamStartingResources[teamID] = {
				metal = metalCurrent,
				energy = energyCurrent
			}
			teamResourcesSpent[teamID] = {
				metal = 0,
				energy = 0
			}
			teamInstantBuild[teamID] = true
		end
	end
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefID = spGetUnitDefID(unitID)
		local unitTeam = spGetUnitTeam(unitID)
		if isInstantBuildCommander(unitDefID) and teamInstantBuild[unitTeam] then
			local x, y, z = spGetUnitPosition(unitID)
			if x then
				commanderStartingPositions[unitID] = {
					x = x,
					y = y,
					z = z,
					teamID = unitTeam
				}
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not teamInstantBuild[unitTeam] then
		return
	end
	if not builderID then
		return
	end
	local builderDefID = spGetUnitDefID(builderID)
	if not isInstantBuildCommander(builderDefID) then
		return
	end
	local unitDef = UnitDefs[unitDefID]
	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	local reducedEnergyCost = energyCost * ENERGY_REDUCTION_MULTIPLIER
	local metalRemaining = teamStartingResources[unitTeam].metal - teamResourcesSpent[unitTeam].metal
	local energyRemaining = teamStartingResources[unitTeam].energy - teamResourcesSpent[unitTeam].energy
	local metalPercentage = metalCost > 0 and math.min(1.0, metalRemaining / metalCost) or 1.0
	local energyPercentage = reducedEnergyCost > 0 and math.min(1.0, energyRemaining / reducedEnergyCost) or 1.0
	local resourcePercentage = math.min(metalPercentage, energyPercentage)

	if resourcePercentage < 1.0 then
		teamResourcesSpent[unitTeam].metal = teamStartingResources[unitTeam].metal
		teamResourcesSpent[unitTeam].energy = teamStartingResources[unitTeam].energy
		local currentHealth, maxHealth = spGetUnitHealth(unitID)
		local healthForProgress = maxHealth * resourcePercentage
		spSetUnitHealth(unitID, {build = resourcePercentage, health = healthForProgress})
		disableInstantBuildForTeam(unitTeam)
		return
	end

	teamResourcesSpent[unitTeam].metal = teamResourcesSpent[unitTeam].metal + metalCost
	teamResourcesSpent[unitTeam].energy = teamResourcesSpent[unitTeam].energy + reducedEnergyCost
	local originalBuildTime = unitDef.buildTime or 1000
	modifiedUnits[unitID] = {
		buildTime = originalBuildTime,
		energyCost = energyCost,
		metalCost = metalCost
	}
	local reducedBuildTime = math.max(1, originalBuildTime * BUILD_TIME_REDUCTION_MULTIPLIER)
	spSetUnitCosts(unitID, {
		buildTime = reducedBuildTime,
		energyCost = reducedEnergyCost,
		metalCost = metalCost
	})
	local x, y, z = Spring.GetUnitPosition(unitID)
	if x then
		Spring.SpawnCEG("botrailspawn", x, y, z, 0, 0, 0)
	end
	if teamResourcesSpent[unitTeam].metal >= teamStartingResources[unitTeam].metal or 
	   teamResourcesSpent[unitTeam].energy >= teamStartingResources[unitTeam].energy then
		disableInstantBuildForTeam(unitTeam)
	end
end

function gadget:GameFrame(frameNumber)
	if frameNumber % UPDATE_FRAMES ~= 0 then
		return
	end
	for unitID, startingPosition in pairs(commanderStartingPositions) do
		if teamInstantBuild[startingPosition.teamID] then
			local currentX, currentY, currentZ = spGetUnitPosition(unitID)
			if currentX then
				local dx = currentX - startingPosition.x
				local dz = currentZ - startingPosition.z
				local distance = mathDiag(dx, dz)
				if distance > MAX_RANGE then
					disableInstantBuildForTeam(startingPosition.teamID)
				end
			end
		end
	end
end

function gadget:UnitDestroyed(unitID)
	modifiedUnits[unitID] = nil
	commanderStartingPositions[unitID] = nil
end

function gadget:Initialize()
	if Spring.GetGameFrame() > 0 then
		gadget:GameStart()
	end
	nonPlayerTeams[Spring.GetGaiaTeamID()] = true
	local scavTeamID = Spring.Utilities.GetScavTeamID()
	if scavTeamID then
		nonPlayerTeams[scavTeamID] = true
	end
	local raptorTeamID = Spring.Utilities.GetRaptorTeamID()
	if raptorTeamID then
		nonPlayerTeams[raptorTeamID] = true
	end
end