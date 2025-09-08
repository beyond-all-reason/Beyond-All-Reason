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

local shouldRunGadget = modOptions.quick_start == "enabled" or "labs_required" or 
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))

if not shouldRunGadget then return false end

--todo
--when factory is not required, specifically not-human players should have a factory made for them.

local spGetUnitDefID = Spring.GetUnitDefID
local spGetTeamResources = Spring.GetTeamResources
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spCreateUnit = Spring.CreateUnit
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCommands = Spring.GetUnitCommands
local spSetUnitHealth = Spring.SetUnitHealth
local spValidUnitID = Spring.ValidUnitID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitIsDead = Spring.GetUnitIsDead
local spTestBuildOrder = Spring.TestBuildOrder
local spPos2BuildPos = Spring.Pos2BuildPos
local spSetTeamResource = Spring.SetTeamResource
 local spSetTeamRulesParam = Spring.SetTeamRulesParam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSetGameRulesParam = Spring.SetGameRulesParam
local spSpawnCEG = Spring.SpawnCEG
local spGetGameFrame = Spring.GetGameFrame
local spGetAllUnits = Spring.GetAllUnits

local BONUS_METAL = 450
local BONUS_ENERGY = 2500
local QUICK_START_COST_METAL = 800
local QUICK_START_COST_ENERGY = 400
local AUTO_MEX_MAX_DISTANCE = 500
local SOLAR_PENALTY_MULTIPLIER = 0.25

local factoryRequired = modOptions.quick_start == "labs_required"
local isGoodWind = false
local isMetalMap = false
local metalSpotsList = nil
local GRID_SPACING = 32

local unitDefNames = UnitDefNames

local commanderLandLabs = {
	armcom = {
		labs = { armlab = 0.3, armvp = 0.3, armap = 0.1 }
	},
	corcom = {
		labs = { corlab = 0.3, corvp = 0.3, corap = 0.1 }
	},
	legcom = {
		labs = { leglab = 0.3, legvp = 0.3, legap = 0.1 }
	}
}

local commanderNonLabOptions = {
	armcom = { 
		windmill = "armwin",
		mex = "armmex",
		converter = "armmakr",
		solar = "armsolar",
		tidal = "armtide",
		floatingConverter = "armfmkr",
	},
	corcom = {
		windmill = "corwin",
		mex = "cormex",
		converter = "cormakr",
		solar = "corsolar",
		tidal = "cortide",
		floatingConverter = "corfmkr",
	},
	legcom = {
		windmill = "legwin",
		mex = "legmex",
		converter = "legeconv",
		solar = "legsolar",
		tidal = "legtide",
		floatingConverter = "legfconv",
	}
}


local baseBuildOptionWeights = {
	windmill = 0.3,
	mex = 0.25,
	converter = 0.1,
	floatingConverter = 0.1,
	solar = 0.25,
	tidal = 0.5,
}

local randomBuildOptionWeights = {}


local commanderSeaLabs = {
	armcom = { armsy = 1 },
	corcom = { corsy = 1 },
	legcom = { legsy = 1 },
}


local ENERGY_VALUE_CONVERSION_DIVISOR = 10
local COMMAND_STEAL_RANGE = 700
local ALL_COMMANDS = -1
local UPDATE_FRAMES = Game.gameSpeed
local PREGAME_DELAY_FRAMES = 61 --after gui_pregame_build.lua is loaded
local MAP_CENTER_X = Game.mapSizeX / 2
local MAP_CENTER_Z = Game.mapSizeZ / 2

local TEAM_RULES_TOTAL_KEY = "quickStartJuiceTotal"
local TEAM_RULES_REMAINING_KEY = "quickStartJuiceRemaining"
local TEAM_RULES_FACTORY_PLACED_KEY = "quickStartFactoryPlaced"
local GAME_RULES_BASE_KEY = "quickStartJuiceBase"

local commanderMetaList = {}
local boostableCommanders = {}
local queueCommanderCreation = {}
local buildQueues = {}


for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.iscommander then
		boostableCommanders[unitDefID] = true
	end
end

local function generateChunksTable(centerX, centerZ)
	local maxDistance = 250
	local chunkSize = (maxDistance * 2) / 3
	
	local allChunks = {
		{1, 1}, {2, 1}, {3, 1},
		{1, 2}, {3, 2},
		{1, 3}, {2, 3}, {3, 3}
	}
	
	local chunksWithDistance = {}
	for i, chunk in ipairs(allChunks) do
		local chunkX, chunkZ = chunk[1], chunk[2]
		local chunkCenterX = centerX - maxDistance + (chunkX - 0.5) * chunkSize
		local chunkCenterZ = centerZ - maxDistance + (chunkZ - 0.5) * chunkSize
		local distanceFromMapCenter = math.distance2dSquared(chunkCenterX, chunkCenterZ, MAP_CENTER_X, MAP_CENTER_Z)
		
		table.insert(chunksWithDistance, {
			chunk = chunk,
			distance = distanceFromMapCenter,
			chunkStartX = centerX - maxDistance + (chunkX - 1) * chunkSize,
			chunkEndX = centerX - maxDistance + chunkX * chunkSize,
			chunkStartZ = centerZ - maxDistance + (chunkZ - 1) * chunkSize,
			chunkEndZ = centerZ - maxDistance + chunkZ * chunkSize
		})
	end
	
	table.sort(chunksWithDistance, function(a, b) return a.distance < b.distance end)
	
	for i, chunkData in ipairs(chunksWithDistance) do
		if i == 1 then
			chunkData.preferredUsage = "factory"
		elseif i == #chunksWithDistance then
			chunkData.preferredUsage = "converter"
		else
			chunkData.preferredUsage = "else"
		end
	end
	
	return chunksWithDistance
end

local function generateChunkPositionsSorted(chunkData, targetX, targetZ)
	local positions = {}
	for searchX = chunkData.chunkStartX, chunkData.chunkEndX, GRID_SPACING do
		for searchZ = chunkData.chunkStartZ, chunkData.chunkEndZ, GRID_SPACING do
			table.insert(positions, {x = searchX, z = searchZ})
		end
	end
	local cx = targetX or (chunkData.chunkStartX + chunkData.chunkEndX) / 2
	local cz = targetZ or (chunkData.chunkStartZ + chunkData.chunkEndZ) / 2
	table.sort(positions, function(a, b)
		local distA = math.distance2dSquared(a.x, a.z, cx, cz)
		local distB = math.distance2dSquared(b.x, b.z, cx, cz)
		return distA < distB
	end)
	return positions
end

local function initializeCommander(commanderID, teamID)
	if not spValidUnitID(commanderID) or spGetUnitIsDead(commanderID) then
		return
	end
	
	local currentMetal = spGetTeamResources(teamID, "metal") or 0
	local currentEnergy = spGetTeamResources(teamID, "energy") or 0

	local juice = QUICK_START_COST_METAL + BONUS_METAL + (QUICK_START_COST_ENERGY + BONUS_ENERGY) / ENERGY_VALUE_CONVERSION_DIVISOR

	spSetGameRulesParam(GAME_RULES_BASE_KEY, juice)
	local currentTotal = spGetTeamRulesParam(teamID, TEAM_RULES_TOTAL_KEY) or 0
	local currentRemaining = spGetTeamRulesParam(teamID, TEAM_RULES_REMAINING_KEY) or 0
	local newTotal = currentTotal + juice
	local newRemaining = currentRemaining + juice
	spSetTeamRulesParam(teamID, TEAM_RULES_TOTAL_KEY, newTotal)
	spSetTeamRulesParam(teamID, TEAM_RULES_REMAINING_KEY, newRemaining)
	
	local isHuman = false
	if GG and GG.PowerLib and GG.PowerLib.HumanTeams then
		isHuman = GG.PowerLib.HumanTeams[teamID] == true
	end
	
	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	local directionX = MAP_CENTER_X - commanderX
	local directionZ = MAP_CENTER_Z - commanderZ
	local angle = math.atan2(directionX, directionZ)
	local defaultFacing = math.floor((angle / (math.pi / 2)) + 0.5) % 4
	
	local chunksWithDistance = generateChunksTable(commanderX, commanderZ)

	local commanderDefID = spGetUnitDefID(commanderID)
	local commanderName = UnitDefs[commanderDefID].name
	local nonLabOptions = commanderNonLabOptions[commanderName]
	local isInWater = commanderY < 0	

	commanderMetaList[commanderID] = {
		teamID = teamID,
		juice = juice,
		factoryMade = false,
		thingsMade = {windmill = 0, mex = 0, converter = 0, solar = 0, tidal = 0, floatingConverter = 0, factory = 0},
		isHuman = isHuman,
		defaultFacing = defaultFacing,
		chunksWithDistance = chunksWithDistance,
		isInWater = isInWater,
		hasFactoryInQueue = false,
		commanderName = commanderName,
		nonLabOptions = nonLabOptions,
		buildQuotas = {
			mex = 4,
			windmill = isInWater and 0 or (isGoodWind and 4 or 0),
			converter = isInWater and 0 or 2,
			solar = isInWater and 0 or (isGoodWind and 1 or 4),
			tidal = isInWater and 6 or 0,
			floatingConverter = isInWater and 2 or 0,
		}
	}
	
	buildQueues[commanderID] = {}
	
	spSetTeamResource(teamID, "metal", math.max(0, currentMetal - QUICK_START_COST_METAL))
	spSetTeamResource(teamID, "energy", math.max(0, currentEnergy - QUICK_START_COST_ENERGY))
end

local function calculateJuiceCost(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	
	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	return metalCost + (energyCost / ENERGY_VALUE_CONVERSION_DIVISOR)
end

local function deductJuiceAndCreateUnit(commanderData, unitDefID, buildX, buildY, buildZ, facing, teamID, commanderID, isFree)
	if commanderData.juice <= 0 and not isFree then
		return false, nil
	end
	
	local unitDef = UnitDefs[unitDefID]
	local unitID = spCreateUnit(unitDef.name, buildX, buildY, buildZ, facing, teamID)
	if not unitID then
		return false, nil
	end
	
	local buildProgress
	if isFree then
		buildProgress = 1
		spSetUnitHealth(unitID, {build = 1, health = unitDef.health})
	else
		local juiceCost = calculateJuiceCost(unitDefID)
		local affordableJuice = math.min(commanderData.juice, juiceCost)
		buildProgress = affordableJuice / juiceCost
		spSetUnitHealth(unitID, {build = buildProgress, health = math.ceil(unitDef.health * buildProgress)})
		commanderData.juice = commanderData.juice - affordableJuice
		local remaining = spGetTeamRulesParam(teamID, TEAM_RULES_REMAINING_KEY) or 0
		spSetTeamRulesParam(teamID, TEAM_RULES_REMAINING_KEY, math.max(0, remaining - affordableJuice))
	end
	
	local nonLabOptions = commanderData.nonLabOptions
	local isFactory = unitDef.isFactory
	
	if isFactory then
		spSetTeamRulesParam(teamID, TEAM_RULES_FACTORY_PLACED_KEY, 1)
		commanderData.thingsMade.factory = commanderData.thingsMade.factory + 1
	else
		for optionName, trueName in pairs(nonLabOptions) do
			if trueName == unitDef.name then
				commanderData.thingsMade[optionName] = (commanderData.thingsMade[optionName] or 0) + 1
				break
			end
		end
	end
	
	spSpawnCEG("quickstart-spawn-pulse-large", buildX, buildY + 10, buildZ)
	
	if buildProgress < 1 then
		spGiveOrderToUnit(commanderID, CMD.INSERT, {0, CMD.REPAIR, CMD.OPT_SHIFT, unitID}, CMD.OPT_ALT)
	end
	
	return buildProgress >= 1
end

local function isBuildCommand(cmdID)
	if not cmdID then return false end
	return cmdID < 0
end

local function isCommanderInRange(commanderX, commanderZ, targetX, targetZ)
	local distance = math.distance2d(commanderX, commanderZ, targetX, targetZ)
	return distance <= COMMAND_STEAL_RANGE
end

local function selectWeightedRandom(weightedOptions)
	local totalWeight = 0
	for _, weight in pairs(weightedOptions) do
		totalWeight = totalWeight + weight
	end
	
	local randomValue = math.random() * totalWeight
	local currentWeight = 0
	
	for optionName, weight in pairs(weightedOptions) do
		currentWeight = currentWeight + weight
		if randomValue <= currentWeight then
			return optionName
		end
	end
	
	return nil
end

local function attemptBuildAtLocation(x, y, z, unitDefID, teamID, commanderData, commanderID)
	local unitDef = UnitDefs[unitDefID]
	local isMetalExtractor = unitDef and unitDef.extractsMetal and unitDef.extractsMetal > 0
	
	if isMetalExtractor and not isMetalMap and metalSpotsList and #metalSpotsList > 0 then
		local spotsWithDistance = {}
		for i = 1, #metalSpotsList do
			local spot = metalSpotsList[i]
			local distanceSquared = math.distance2dSquared(spot.x, spot.z, x, z)
			if distanceSquared <= AUTO_MEX_MAX_DISTANCE * AUTO_MEX_MAX_DISTANCE then
				table.insert(spotsWithDistance, {spot = spot, distance = distanceSquared})
			end
		end
		
		table.sort(spotsWithDistance, function(a, b) return a.distance < b.distance end)
		
		for _, spotData in ipairs(spotsWithDistance) do
			local spot = spotData.spot
			if spTestBuildOrder(unitDefID, spot.x, spot.y, spot.z, 0) > 0 then
				local fullyBuilt = deductJuiceAndCreateUnit(commanderData, unitDefID, spot.x, spot.y, spot.z, commanderData.defaultFacing or 0, teamID, commanderID, false)
				if fullyBuilt then
					return true
				end
			end
		end
		return false
	end
	
	local nonLabOptions = commanderData.nonLabOptions
	local isConverter = nonLabOptions and nonLabOptions.converter == (unitDef and unitDef.name)
	
	local chunksWithDistance = {}
	local targetUsage = isConverter and "converter" or "else"
	for _, chunkData in ipairs(commanderData.chunksWithDistance) do
		if chunkData.preferredUsage == targetUsage then
			table.insert(chunksWithDistance, chunkData)
		end
	end
	
	if not isConverter then
		table.sort(chunksWithDistance, function(a, b) return a.distance > b.distance end)
	end
	
	for _, chunkData in ipairs(chunksWithDistance) do
		local positions = generateChunkPositionsSorted(chunkData)
		
		for _, pos in ipairs(positions) do
			local searchY = spGetGroundHeight(pos.x, pos.z)
			local snappedX, snappedY, snappedZ = spPos2BuildPos(unitDefID, pos.x, searchY, pos.z)
			
			if snappedX and spTestBuildOrder(unitDefID, snappedX, snappedY, snappedZ, 0) > 0 then
				local fullyBuilt = deductJuiceAndCreateUnit(commanderData, unitDefID, snappedX, snappedY, snappedZ, commanderData.defaultFacing or 0, teamID, commanderID, false)
				if fullyBuilt then
					return true
				end
			end
		end
	end
end

local function generateRandomBuildQueue(commanderID, commanderData)
	local buildQueue = {}
	
	if commanderData.buildQuotas.mex > 0 and (isMetalMap or (metalSpotsList and #metalSpotsList > 0)) then
		local alreadyMade = commanderData.thingsMade.mex or 0
		local stillNeeded = math.max(0, commanderData.buildQuotas.mex - alreadyMade)
		for i = 1, stillNeeded do
			table.insert(buildQueue, "mex")
		end
	end
	
	for optionName, quota in pairs(commanderData.buildQuotas) do
		if optionName ~= "mex" and quota > 0 then
			local weight = randomBuildOptionWeights[optionName] or 0
			if weight > 0 then
				local alreadyMade = commanderData.thingsMade[optionName] or 0
				local stillNeeded = math.max(0, quota - alreadyMade)
				for i = 1, stillNeeded do
					table.insert(buildQueue, optionName)
				end
			end
		end
	end
	
	local mexCount = commanderData.buildQuotas.mex or 0
	local nonMexStartIndex = mexCount + 1
	if nonMexStartIndex <= #buildQueue then
		for i = #buildQueue, nonMexStartIndex + 1, -1 do
			local j = math.random(nonMexStartIndex, i)
			buildQueue[i], buildQueue[j] = buildQueue[j], buildQueue[i]
		end
	end

	local overflowCount = 10
	for i = 1, overflowCount do
		local selectedOption = selectWeightedRandom(randomBuildOptionWeights)
		if selectedOption then
			table.insert(buildQueue, selectedOption)
		end
	end
	buildQueues[commanderID] = buildQueue
end

local function buildFactoryOrder(commanderData, availableFactories, labsUsed)
	local factoryOrder = {}
	if commanderData.isHuman then
		local firstFactory = nil
		for labName, _ in pairs(labsUsed) do
			for _, factory in ipairs(availableFactories) do
				if factory.name == labName then
					firstFactory = factory
					break
				end
			end
			if firstFactory then break end
		end
		if firstFactory then
			table.insert(factoryOrder, firstFactory)
		end
		for _, factory in ipairs(availableFactories) do
			if factory ~= firstFactory then
				table.insert(factoryOrder, factory)
			end
		end
	else
		local sortedFactories = {}
		for _, factory in ipairs(availableFactories) do
			local probability = labsUsed[factory.name] or 0
			table.insert(sortedFactories, {factory = factory, probability = probability})
		end
		table.sort(sortedFactories, function(a, b) return a.probability > b.probability end)
		local randomIndex = math.random(#availableFactories)
		table.insert(factoryOrder, availableFactories[randomIndex])
		for _, sortedFactory in ipairs(sortedFactories) do
			if sortedFactory.factory ~= availableFactories[randomIndex] then
				table.insert(factoryOrder, sortedFactory.factory)
			end
		end
	end
	return factoryOrder
end

local function filterFactoryChunks(chunks)
	local result = {}
	for _, chunkData in ipairs(chunks) do
		if chunkData.preferredUsage == "factory" then
			table.insert(result, chunkData)
		end
	end
	return result
end

local function ensureFactoryBuilt(commanderID, commanderData)
	if not factoryRequired or commanderData.factoryMade then
		return
	end
	local landLabs = commanderLandLabs[commanderData.commanderName]
	local seaLabs = commanderSeaLabs[commanderData.commanderName]
	if commanderData.hasFactoryInQueue then
		return
	end
	local labsUsed = commanderData.isInWater and seaLabs or landLabs.labs
	local availableFactories = {}
	for factoryName, _ in pairs(labsUsed) do
		local unitDefID = unitDefNames[factoryName].id
		table.insert(availableFactories, {unitDefID = unitDefID, name = factoryName})
	end
	local factoryOrder = buildFactoryOrder(commanderData, availableFactories, labsUsed)
	local chunksWithDistance = filterFactoryChunks(commanderData.chunksWithDistance)
	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	for _, factory in ipairs(factoryOrder) do
		for _, chunkData in ipairs(chunksWithDistance) do
			local positions = generateChunkPositionsSorted(chunkData, commanderX, commanderZ)
			for _, pos in ipairs(positions) do
				local searchY = spGetGroundHeight(pos.x, pos.z)
				local snappedX, snappedY, snappedZ = spPos2BuildPos(factory.unitDefID, pos.x, searchY, pos.z)
				if spTestBuildOrder(factory.unitDefID, snappedX, snappedY, snappedZ, 0) > 0 then
					local facing = commanderData.defaultFacing or 0
					local isFree = factoryRequired and not commanderData.factoryMade
					local fullyBuilt = deductJuiceAndCreateUnit(commanderData, factory.unitDefID, snappedX, snappedY, snappedZ, facing, commanderData.teamID, commanderID, isFree)
					if fullyBuilt then
						commanderData.factoryMade = true
						return
					end
				end
			end
		end
	end
end

local function executeQueuedBuildCommands(commanderID, commanderData, commanderX, commanderZ)
	commanderData.hasFactoryInQueue = false
	
	if commanderData.juice > 0 then
		local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
		if next(commands) then
			for i, cmd in ipairs(commands) do
				local buildsiteX, buildsiteZ = cmd.params[1], cmd.params[3]
				if isBuildCommand(cmd.id) and isCommanderInRange(commanderX, commanderZ, buildsiteX, buildsiteZ) then
					local buildDefID = -cmd.id
					local unitDef = UnitDefs[buildDefID]
					local isFactory = unitDef and unitDef.isFactory
					
					local buildX, buildY, buildZ = cmd.params[1], cmd.params[2], cmd.params[3]
					local facing = commanderData.defaultFacing or 0
					
					local isFree = false
					if isFactory then
						commanderData.hasFactoryInQueue = true
						isFree = factoryRequired and not commanderData.factoryMade
					end
					
					local fullyBuilt = deductJuiceAndCreateUnit(commanderData, buildDefID, buildX, buildY, buildZ, facing, commanderData.teamID, commanderID, isFree)
					if fullyBuilt then
						if isFactory then
							commanderData.factoryMade = true
						end
						spGiveOrderToUnit(commanderID, CMD.REMOVE, {i}, 0)
					elseif not isFactory then
						break
					end
				end
				if commanderData.juice <= 0 then
					break
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if boostableCommanders[unitDefID] then
		queueCommanderCreation[unitID] = unitTeam
	end
end

local initialized = false
function gadget:GameFrame(frame)
	if not initialized and frame > PREGAME_DELAY_FRAMES then
		for unitID, teamID in pairs(queueCommanderCreation) do
			initializeCommander(unitID, teamID)
		end
		queueCommanderCreation = {}
		initialized = true
	end

	if frame % UPDATE_FRAMES ~= 0 then return end

	for commanderID, commanderData in pairs(commanderMetaList) do
		
		local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
		if commanderX then
			commanderData.isInWater = commanderY < 0
		end

		executeQueuedBuildCommands(commanderID, commanderData, commanderX, commanderZ)
		while commanderData.juice > 0 do
			if #buildQueues[commanderID] == 0 then
				generateRandomBuildQueue(commanderID, commanderData)
			end
			
			if #buildQueues[commanderID] == 0 then
				break
			end
			
			local queueItem = buildQueues[commanderID][1]
			table.remove(buildQueues[commanderID], 1)
			
			local unitDefID
			if type(queueItem) == "string" then
				local commanderDefID = spGetUnitDefID(commanderID)
				local commanderName = UnitDefs[commanderDefID].name
				local nonLabOptions = commanderNonLabOptions[commanderName]
				local trueName = nonLabOptions[queueItem]
				unitDefID = trueName and unitDefNames[trueName].id
			else
				unitDefID = queueItem
			end
			
			if unitDefID then
				local success = attemptBuildAtLocation(commanderX, commanderY, commanderZ, unitDefID, commanderData.teamID, commanderData, commanderID)
			end
		end
		ensureFactoryBuilt(commanderID, commanderData)
	end


	local allResourcesExhausted = true
	for commanderID, commanderData in pairs(commanderMetaList) do
		if commanderData.juice > 0 then
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
		buildQueues[unitID] = nil
	end
end

function gadget:Initialize()
	local minWind = Game.windMin
	local maxWind = Game.windMax
	
	-- precomputed average wind values, from wind random monte carlo simulation, given minWind and maxWind
	local avgWind = {[0]={[1]="0.8",[2]="1.5",[3]="2.2",[4]="3.0",[5]="3.7",[6]="4.5",[7]="5.2",[8]="6.0",[9]="6.7",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.4",[15]="11.2",[16]="11.9",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[1]={[2]="1.6",[3]="2.3",[4]="3.0",[5]="3.8",[6]="4.5",[7]="5.2",[8]="6.0",[9]="6.7",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.4",[15]="11.2",[16]="11.9",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[2]={[3]="2.6",[4]="3.2",[5]="3.9",[6]="4.6",[7]="5.3",[8]="6.0",[9]="6.8",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.5",[15]="11.2",[16]="12.0",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[3]={[4]="3.6",[5]="4.2",[6]="4.8",[7]="5.5",[8]="6.2",[9]="6.9",[10]="7.6",[11]="8.3",[12]="9.0",[13]="9.8",[14]="10.5",[15]="11.2",[16]="12.0",[17]="12.7",[18]="13.5",[19]="14.2",[20]="15.0",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.7",[26]="19.2",[27]="19.7",[28]="20.0",[29]="20.4",[30]="20.7",},[4]={[5]="4.6",[6]="5.2",[7]="5.8",[8]="6.4",[9]="7.1",[10]="7.8",[11]="8.5",[12]="9.2",[13]="9.9",[14]="10.6",[15]="11.3",[16]="12.1",[17]="12.8",[18]="13.5",[19]="14.3",[20]="15.0",[21]="15.7",[22]="16.5",[23]="17.2",[24]="18.0",[25]="18.7",[26]="19.2",[27]="19.7",[28]="20.1",[29]="20.4",[30]="20.7",},[5]={[6]="5.5",[7]="6.1",[8]="6.8",[9]="7.4",[10]="8.0",[11]="8.7",[12]="9.4",[13]="10.1",[14]="10.8",[15]="11.5",[16]="12.2",[17]="12.9",[18]="13.6",[19]="14.4",[20]="15.1",[21]="15.8",[22]="16.5",[23]="17.3",[24]="18.0",[25]="18.8",[26]="19.3",[27]="19.7",[28]="20.1",[29]="20.4",[30]="20.7",},[6]={[7]="6.5",[8]="7.1",[9]="7.7",[10]="8.4",[11]="9.0",[12]="9.7",[13]="10.3",[14]="11.0",[15]="11.7",[16]="12.4",[17]="13.1",[18]="13.8",[19]="14.5",[20]="15.2",[21]="15.9",[22]="16.7",[23]="17.4",[24]="18.1",[25]="18.8",[26]="19.4",[27]="19.8",[28]="20.2",[29]="20.5",[30]="20.8",},[7]={[8]="7.5",[9]="8.1",[10]="8.7",[11]="9.3",[12]="10.0",[13]="10.6",[14]="11.3",[15]="11.9",[16]="12.6",[17]="13.3",[18]="14.0",[19]="14.7",[20]="15.4",[21]="16.1",[22]="16.8",[23]="17.5",[24]="18.2",[25]="19.0",[26]="19.5",[27]="19.9",[28]="20.3",[29]="20.6",[30]="20.9",},[8]={[9]="8.5",[10]="9.1",[11]="9.7",[12]="10.3",[13]="11.0",[14]="11.6",[15]="12.2",[16]="12.9",[17]="13.6",[18]="14.2",[19]="14.9",[20]="15.6",[21]="16.3",[22]="17.0",[23]="17.7",[24]="18.4",[25]="19.1",[26]="19.6",[27]="20.0",[28]="20.4",[29]="20.7",[30]="21.0",},[9]={[10]="9.5",[11]="10.1",[12]="10.7",[13]="11.3",[14]="11.9",[15]="12.6",[16]="13.2",[17]="13.8",[18]="14.5",[19]="15.2",[20]="15.8",[21]="16.5",[22]="17.2",[23]="17.9",[24]="18.6",[25]="19.3",[26]="19.8",[27]="20.2",[28]="20.5",[29]="20.8",[30]="21.1",},[10]={[11]="10.5",[12]="11.1",[13]="11.7",[14]="12.3",[15]="12.9",[16]="13.5",[17]="14.2",[18]="14.8",[19]="15.4",[20]="16.1",[21]="16.8",[22]="17.4",[23]="18.1",[24]="18.8",[25]="19.5",[26]="20.0",[27]="20.4",[28]="20.7",[29]="21.0",[30]="21.2",},[11]={[12]="11.5",[13]="12.1",[14]="12.7",[15]="13.3",[16]="13.9",[17]="14.5",[18]="15.1",[19]="15.8",[20]="16.4",[21]="17.1",[22]="17.7",[23]="18.4",[24]="19.1",[25]="19.7",[26]="20.2",[27]="20.6",[28]="20.9",[29]="21.2",[30]="21.4",},[12]={[13]="12.5",[14]="13.1",[15]="13.6",[16]="14.2",[17]="14.9",[18]="15.5",[19]="16.1",[20]="16.7",[21]="17.4",[22]="18.0",[23]="18.7",[24]="19.3",[25]="20.0",[26]="20.4",[27]="20.8",[28]="21.1",[29]="21.4",[30]="21.6",},[13]={[14]="13.5",[15]="14.1",[16]="14.6",[17]="15.2",[18]="15.8",[19]="16.5",[20]="17.1",[21]="17.7",[22]="18.4",[23]="19.0",[24]="19.6",[25]="20.3",[26]="20.7",[27]="21.1",[28]="21.4",[29]="21.6",[30]="21.8",},[14]={[15]="14.5",[16]="15.0",[17]="15.6",[18]="16.2",[19]="16.8",[20]="17.4",[21]="18.1",[22]="18.7",[23]="19.3",[24]="20.0",[25]="20.6",[26]="21.0",[27]="21.3",[28]="21.6",[29]="21.8",[30]="22.0",},[15]={[16]="15.5",[17]="16.0",[18]="16.6",[19]="17.2",[20]="17.8",[21]="18.4",[22]="19.0",[23]="19.6",[24]="20.3",[25]="20.9",[26]="21.3",[27]="21.6",[28]="21.9",[29]="22.1",[30]="22.3",},[16]={[17]="16.5",[18]="17.0",[19]="17.6",[20]="18.2",[21]="18.8",[22]="19.4",[23]="20.0",[24]="20.6",[25]="21.3",[26]="21.7",[27]="21.9",[28]="22.2",[29]="22.4",[30]="22.5",},[17]={[18]="17.5",[19]="18.0",[20]="18.6",[21]="19.2",[22]="19.8",[23]="20.4",[24]="21.0",[25]="21.6",[26]="22.0",[27]="22.3",[28]="22.5",[29]="22.7",[30]="22.8",},[18]={[19]="18.5",[20]="19.0",[21]="19.6",[22]="20.2",[23]="20.8",[24]="21.4",[25]="22.0",[26]="22.4",[27]="22.6",[28]="22.8",[29]="23.0",[30]="23.1",},[19]={[20]="19.5",[21]="20.0",[22]="20.6",[23]="21.2",[24]="21.8",[25]="22.4",[26]="22.7",[27]="22.9",[28]="23.1",[29]="23.2",[30]="23.4",},[20]={[21]="20.4",[22]="21.0",[23]="21.6",[24]="22.2",[25]="22.8",[26]="23.1",[27]="23.3",[28]="23.4",[29]="23.6",[30]="23.7",},[21]={[22]="21.4",[23]="22.0",[24]="22.6",[25]="23.2",[26]="23.5",[27]="23.6",[28]="23.8",[29]="23.9",[30]="24.0",},[22]={[23]="22.4",[24]="23.0",[25]="23.6",[26]="23.8",[27]="24.0",[28]="24.1",[29]="24.2",[30]="24.2",},[23]={[24]="23.4",[25]="24.0",[26]="24.2",[27]="24.4",[28]="24.4",[29]="24.5",[30]="24.5",},[24]={[25]="24.4",[26]="24.6",[27]="24.7",[28]="24.7",[29]="24.8",[30]="24.8",},}
	
	-- pull average wind from precomputed table, if it exists
	local averageWind
	if avgWind[minWind] and avgWind[minWind][maxWind] then
		averageWind = tonumber(avgWind[minWind][maxWind])
	else
		averageWind = math.max(minWind, maxWind * 0.75)
	end
	
	isGoodWind = averageWind > 7
	
	isMetalMap = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].isMetalMap
	metalSpotsList = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList
	
	randomBuildOptionWeights = {}
	for optionName, baseWeight in pairs(baseBuildOptionWeights) do
		randomBuildOptionWeights[optionName] = baseWeight
	end
	
	if not isGoodWind then
		randomBuildOptionWeights.windmill = 0
	end
	
	if isGoodWind then
		randomBuildOptionWeights.solar = randomBuildOptionWeights.solar * SOLAR_PENALTY_MULTIPLIER
	end
	local frame = spGetGameFrame()


	-- publish juice base immediately for UI to consume
	local immediateJuice = QUICK_START_COST_METAL + BONUS_METAL + (QUICK_START_COST_ENERGY + BONUS_ENERGY) / ENERGY_VALUE_CONVERSION_DIVISOR
	spSetGameRulesParam(GAME_RULES_BASE_KEY, immediateJuice)

	if frame > 1 then
		local allUnits = spGetAllUnits()
		for _, unitID in ipairs(allUnits) do
			local unitDefinitionID = spGetUnitDefID(unitID)
			local unitTeam = spGetUnitTeam(unitID)
			if boostableCommanders[unitDefinitionID] then
				initializeCommander(unitID, unitTeam)
			end
		end
	end
end