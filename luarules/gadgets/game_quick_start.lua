function gadget:GetInfo()
	return {
		name = "Quick Start",
		desc = "Instantly builds structures using starting resources until they are expended",
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
local spGetUnitPosition = Spring.GetUnitPosition
local spCreateUnit = Spring.CreateUnit
local spDestroyUnit = Spring.DestroyUnit
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitCommands = Spring.GetUnitCommands
local spSetUnitNoSelect = Spring.SetUnitNoSelect
local spSetUnitHealth = Spring.SetUnitHealth
local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spValidUnitID = Spring.ValidUnitID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitIsDead = Spring.GetUnitIsDead
local mathDiag = math.diag
local mathRandom = math.random
local mathCos = math.cos
local mathSin = math.sin
local random = math.random

local unitDefNames = UnitDefNames

local commanderLandLabs = {
	armcom = {
		labs = { armlab = 0.4, armvp = 0.4, armap = 0.5 }
	},
	corcom = {
		labs = { corlab = 0.4, corvp = 0.4, corap = 0.5 }
	},
	legcom = {
		labs = { leglab = 0.4, legvp = 0.4, legap = 0.5 }
	}
}

local commanderNonLabOptions = {
	armcom = { 
		windmill = "armwin",
		mex = "armmex",
		converter = "armmakr",
		solar = "armsolar",
		tidal = "armtide",
	},
	corcom = {
		windmill = "corwin",
		mex = "cormex",
		converter = "armmakr",
		solar = "armsolar",
		tidal = "cortide",
	},
	legcom = {
		windmill = "legwin",
		mex = "legmex",
		converter = "legeconv",
		solar = "legsolar",
		tidal = "legtide",
	}
}

local landBuildQuotas = {
	mex = 4,
	windmill = 4,
	converter = 2,
	solar = 4,
}

local randomBuildOptionWeights = {
	windmill = 0.25,
	mex = 0.25,
	converter = 0.1,
	solar = 0.25,
	tidal = 0.5,
}

local commanderSeaLabs = {
	armcom = { armsy = 0.8, armfhp = 0.2},
	corcom = { corsy = 0.8, corfhp = 0.2},
	legcom = { legsy = 0.8, legfhp = 0.2},
}

local factoryOptions = {}
for commanderName, landLabs in pairs(commanderLandLabs) do
	for unitName, _ in pairs(landLabs.labs) do
		factoryOptions[unitName] = true
	end
end
for commanderName, seaLabs in pairs(commanderSeaLabs) do
	for unitName, _ in pairs(seaLabs) do
		factoryOptions[unitName] = true
	end
end

local gaiaTeamID = Spring.GetGaiaTeamID()

local ENERGY_VALUE_CONVERSION_DIVISOR = 10
local COMMAND_STEAL_RANGE = 700
local FALLBACK_RESOURCES = 1000
local ALL_COMMANDS = -1
local UPDATE_FRAMES = Game.gameSpeed
local PREGAME_DELAY_FRAMES = 91
local PRIVATE = { private = true }

local teamsToBoost = {}
local commanderMetaList = {}
local nonPlayerTeams = {}
local boostableCommanders = {}
local queueCommanderCreation = {}
local partiallyBuiltStructures = {}


for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.iscommander then
		boostableCommanders[unitDefID] = true
	end
end

local function initializeCommander(commanderID, teamID, startingMetal, startingEnergy)
	if not Spring.ValidUnitID(commanderID) or Spring.GetUnitIsDead(commanderID) then
		return
	end
	
	local currentMetal = spGetTeamResources(teamID, "metal") or 0
	local currentEnergy = spGetTeamResources(teamID, "energy") or 0
	local startMetal = startingMetal or 0
	local startEnergy = startingEnergy or 0
	
	local availableMetal = math.min(currentMetal, startMetal)
	local availableEnergy = math.min(currentEnergy, startEnergy)
	local juice = availableMetal + (availableEnergy / ENERGY_VALUE_CONVERSION_DIVISOR)
	
	commanderMetaList[commanderID] = {
		teamID = teamID,
		juice = juice,
		lastCommandCheck = 0,
		factoryMade = false,
		thingsMade = {windmill = 0, mex = 0, converter = 0, solar = 0, tidal = 0}
	}
	
	Spring.SetTeamResource(teamID, "metal", math.max(0, currentMetal - startMetal))
	Spring.SetTeamResource(teamID, "energy", math.max(0, currentEnergy - startEnergy))
end

local function calculateJuiceCost(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then
		return 0
	end
	
	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	return metalCost + (energyCost / ENERGY_VALUE_CONVERSION_DIVISOR)
end

local function deductJuiceAndCreateUnit(commanderData, unitDefID, buildX, buildY, buildZ, facing, teamID, commanderID)
	local juiceCost = calculateJuiceCost(unitDefID)
	if juiceCost <= 0 or commanderData.juice <= 0 then
		return false, nil
	end
	
	local affordableJuice = math.min(commanderData.juice, juiceCost)
	local buildProgress = affordableJuice / juiceCost
	
	if buildProgress <= 0 then
		return false, nil
	end
	
	local unitDef = UnitDefs[unitDefID]
	local unitID = spCreateUnit(unitDef.name, buildX, buildY, buildZ, facing, teamID)
	if not unitID then
		return false, nil
	end
	
	local maxHealth = unitDef.health
	local currentHealth = math.ceil(maxHealth * buildProgress)
	spSetUnitHealth(unitID, {build = buildProgress, health = currentHealth})
	
	commanderData.juice = commanderData.juice - affordableJuice
	
	Spring.SpawnCEG("quickstart-spawn-pulse-large", buildX, buildY + 10, buildZ)
	
	if buildProgress < 1 then
		partiallyBuiltStructures[unitID] = {
			commanderID = commanderID,
			buildProgress = buildProgress,
			originalCommand = nil
		}
	end
	
	return buildProgress >= 1, unitID
end

local function tryToBuildCommand(commanderID, cmd)
	local buildDefID = -cmd.id
	local buildX, buildY, buildZ = cmd.params[1], cmd.params[2], cmd.params[3]
	local commanderData = commanderMetaList[commanderID]
	
	if not commanderData then return false, nil end
	
	local fullyBuilt, unitID = deductJuiceAndCreateUnit(commanderData, buildDefID, buildX, buildY, buildZ, 0, commanderData.teamID, commanderID)
	if unitID and partiallyBuiltStructures[unitID] then
		partiallyBuiltStructures[unitID].originalCommand = cmd
	end
	
	return fullyBuilt, unitID
end

local function isBuildCommand(cmdID)
	if not cmdID then
		return false
	end
	return cmdID < 0
end

local function isCommanderInRange(commanderID, targetX, targetZ)
	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	if not commanderX then
		return false
	end
	
	local distance = mathDiag(commanderX - targetX, commanderZ - targetZ)
	return distance <= COMMAND_STEAL_RANGE
end

local function hasResourcesLeft(commanderData)
	return commanderData.juice > 0
end

local function canAffordAnyPartialBuild(commanderData)
	return commanderData.juice > 0
end

local function isMetalExtractor(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	return unitDef and unitDef.extractsMetal and unitDef.extractsMetal > 0
end

local function findClosestMetalSpot(x, z)
	if not GG or not GG["resource_spot_finder"] or not GG["resource_spot_finder"].metalSpotsList then
		return nil
	end
	
	local metalSpots = GG["resource_spot_finder"].metalSpotsList
	if not metalSpots or #metalSpots == 0 then
		return nil
	end
	
	local closestSpot = nil
	local closestDistance = math.huge
	
	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local distance = math.sqrt((spot.x - x)^2 + (spot.z - z)^2)
		if distance < closestDistance then
			closestDistance = distance
			closestSpot = spot
		end
	end
	
	return closestSpot
end

local function findBuildLocationAndCreateUnit(x, y, z, unitDefID, teamID, commanderData, commanderID)
	Spring.Echo("findBuildLocationAndCreateUnit")
	if not commanderData or commanderData.juice <= 0 then
		return false
	end
	
	local buildX, buildY, buildZ = x, y, z
	local facing = 0
	
	if isMetalExtractor(unitDefID) then
		local metalSpot = findClosestMetalSpot(x, z)
		if metalSpot then
			buildX = metalSpot.x
			buildY = metalSpot.y
			buildZ = metalSpot.z
			Spring.Echo("Found metal spot at", buildX, buildY, buildZ)
		else
			Spring.Echo("No metal spot found, using random placement")
		end
	end
	
	local buildTest = Spring.TestBuildOrder(unitDefID, buildX, buildY, buildZ, 0)
	if buildTest > 0 then
		local mapCenterX = Game.mapSizeX / 2
		local mapCenterZ = Game.mapSizeZ / 2
		local directionX = mapCenterX - buildX
		local directionZ = mapCenterZ - buildZ
		facing = math.floor((math.atan2(directionZ, directionX) * 32768 / math.pi) + 0.5)
		
		local fullyBuilt, unitID = deductJuiceAndCreateUnit(commanderData, unitDefID, buildX, buildY, buildZ, facing, teamID, commanderID)
		if unitID then
			return unitID
		end
	end
	
	if not isMetalExtractor(unitDefID) then
		local searchRadius = 200
		local maxAttempts = 25
		
		for attempt = 1, maxAttempts do
			local randomAngle = mathRandom() * 2 * math.pi
			local randomDistance = mathRandom() * searchRadius
			local searchX = x + mathCos(randomAngle) * randomDistance
			local searchZ = z + mathSin(randomAngle) * randomDistance
			local searchY = spGetGroundHeight(searchX, searchZ)
			Spring.Echo("searchX", searchX, "searchY", searchY, "searchZ", searchZ)
			
			local buildTest = Spring.TestBuildOrder(unitDefID, searchX, searchY, searchZ, 0)
			if buildTest > 0 then
				local mapCenterX = Game.mapSizeX / 2
				local mapCenterZ = Game.mapSizeZ / 2
				local directionX = mapCenterX - searchX
				local directionZ = mapCenterZ - searchZ
				facing = math.floor((math.atan2(directionZ, directionX) * 32768 / math.pi) + 0.5)
				
				local fullyBuilt, unitID = deductJuiceAndCreateUnit(commanderData, unitDefID, searchX, searchY, searchZ, facing, teamID, commanderID)
				if unitID then
					return unitID
				end
			end
		end
	end
	
	return false
end

local function processCommanderCommands(commanderID, commanderData)
	if teamsToBoost[commanderData.teamID] and canAffordAnyPartialBuild(commanderData) then
		local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
		if next(commands) then
			for i, cmd in ipairs(commands) do
				local buildsiteX, buildsiteZ = cmd.params[1], cmd.params[3]
				if isBuildCommand(cmd.id) and isCommanderInRange(commanderID, buildsiteX, buildsiteZ) then
					local fullyBuilt, unitID = tryToBuildCommand(commanderID, cmd)
					if fullyBuilt then
						spGiveOrderToUnit(commanderID, CMD.REMOVE, {i}, 0)
					end
					if not unitID then
						break
					end
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if boostableCommanders[unitDefID] then
		teamsToBoost[unitTeam] = true
		queueCommanderCreation[unitID] = unitTeam
	end
end

local initialized = false
function gadget:GameFrame(frame)
	if not initialized and frame > PREGAME_DELAY_FRAMES then
		for unitID, teamID in pairs(queueCommanderCreation) do
			initializeCommander(unitID, teamID, modOptions.startmetal or FALLBACK_RESOURCES, modOptions.startenergy or FALLBACK_RESOURCES)
		end
		queueCommanderCreation = {}
		initialized = true
	end

	if frame % UPDATE_FRAMES ~= 0 then return end

	for commanderID, commanderData in pairs(commanderMetaList) do
		local commanderData = commanderMetaList[commanderID]

		processCommanderCommands(commanderID, commanderData)

		if commanderData.juice > 0 then
			Spring.Echo("commanderData.juice > 0")
			local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
			local commanderDefID = spGetUnitDefID(commanderID)
			local commanderName = UnitDefs[commanderDefID].name
			local nonLabOptions = commanderNonLabOptions[commanderName]
			
			if nonLabOptions then
				for optionName, count in pairs(commanderData.thingsMade) do
					Spring.Echo("optionName", optionName, "count", count)
					local weight = randomBuildOptionWeights[optionName]
					if random() > weight then
						Spring.Echo("random() > weight")
						local trueName = nonLabOptions[optionName]
						if trueName then
							local unitDefID = unitDefNames[trueName] and unitDefNames[trueName].id
							if unitDefID then
								findBuildLocationAndCreateUnit(commanderX, commanderY, commanderZ, unitDefID, commanderData.teamID, commanderData, commanderID)
							end
						end
					end
				end
			end
		else
			--remove unit?
		end
	end

	for unitID, structureData in pairs(partiallyBuiltStructures) do --zzz this complexity is no longer needed because we only need to issue repair command once
		if spValidUnitID(unitID) and not spGetUnitIsDead(unitID) then
			local commanderID = structureData.commanderID
			if commanderMetaList[commanderID] and teamsToBoost[commanderMetaList[commanderID].teamID] then
				local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
				local alreadyRepairing = false
				for _, cmd in ipairs(commands) do
					if cmd.id == CMD.REPAIR and cmd.params[1] == unitID then
						alreadyRepairing = true
						break
					end
				end
				
				if not alreadyRepairing then
					spGiveOrderToUnit(commanderID, CMD.INSERT, {0, CMD.REPAIR, CMD.OPT_SHIFT, unitID}, CMD.OPT_ALT)
				end
			end
		else
			partiallyBuiltStructures[unitID] = nil
		end
	end

	local allResourcesExhausted = true
	for commanderID, commanderData in pairs(commanderMetaList) do
		if teamsToBoost[commanderData.teamID] and hasResourcesLeft(commanderData) then
			allResourcesExhausted = false
			break
		end
	end

	if initialized and allResourcesExhausted then
		gadgetHandler:RemoveGadget()
	end
end

function gadget:UnitDestroyed(unitID)
	if commanderMetaList[unitID] then
		commanderMetaList[unitID] = nil
	elseif partiallyBuiltStructures[unitID] then
		partiallyBuiltStructures[unitID] = nil
	end
end

function gadget:Initialize()
	local frame = Spring.GetGameFrame()

	if frame > 1 then
		local teamList = Spring.GetTeamList()
		for _, teamID in ipairs(teamList) do
			if not nonPlayerTeams[teamID] then
				teamsToBoost[teamID] = true
			end
		end
		
		local allUnits = Spring.GetAllUnits()
		for _, unitID in ipairs(allUnits) do
			local unitDefinitionID = spGetUnitDefID(unitID)
			local unitTeam = spGetUnitTeam(unitID)
			if teamsToBoost[unitTeam] and boostableCommanders[unitDefinitionID] then
				initializeCommander(unitID, unitTeam, modOptions.startmetal or FALLBACK_RESOURCES, modOptions.startenergy or FALLBACK_RESOURCES)
			end
		end
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

function gadget:Shutdown()
	partiallyBuiltStructures = {}
end