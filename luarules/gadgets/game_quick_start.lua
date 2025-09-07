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
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCommands = Spring.GetUnitCommands
local spSetUnitHealth = Spring.SetUnitHealth
local spValidUnitID = Spring.ValidUnitID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitIsDead = Spring.GetUnitIsDead
local mathDiag = math.diag

local BONUS_METAL = 450
local BONUS_ENERGY = 2500
local MEX_MAX_DISTANCE = 500
local SOLAR_PENALTY_MULTIPLIER = 0.5

local factoryRequired = true
local isGoodWind = false

local unitDefNames = UnitDefNames

local commanderLandLabs = {
	armcom = {
		labs = { armlab = 0.4, armvp = 0.3, armap = 0.2 }
	},
	corcom = {
		labs = { corlab = 0.4, corvp = 0.3, corap = 0.2 }
	},
	legcom = {
		labs = { leglab = 0.4, legvp = 0.3, legap = 0.2 }
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
		converter = "cormakr",
		solar = "corsolar",
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

local baseBuildOptionWeights = {
	windmill = 0.25,
	mex = 0.25,
	converter = 0.1,
	solar = 0.25,
	tidal = 0.5,
}

local randomBuildOptionWeights = {}


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

local ENERGY_VALUE_CONVERSION_DIVISOR = 10
local COMMAND_STEAL_RANGE = 700
local FALLBACK_RESOURCES = 1000
local ALL_COMMANDS = -1
local UPDATE_FRAMES = Game.gameSpeed
local PREGAME_DELAY_FRAMES = 91
local MAP_CENTER_X = Game.mapSizeX / 2
local MAP_CENTER_Z = Game.mapSizeZ / 2

local teamsToBoost = {}
local commanderMetaList = {}
local nonPlayerTeams = {}
local boostableCommanders = {}
local queueCommanderCreation = {}
local partiallyBuiltStructures = {}
local buildQueues = {}


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
	local juice = availableMetal + BONUS_METAL + (availableEnergy + BONUS_ENERGY) / ENERGY_VALUE_CONVERSION_DIVISOR
	
	local isHuman = false
	if GG and GG.PowerLib and GG.PowerLib.HumanTeams then
		isHuman = GG.PowerLib.HumanTeams[teamID] == true
	end
	
	commanderMetaList[commanderID] = {
		teamID = teamID,
		juice = juice,
		lastCommandCheck = 0,
		factoryMade = false,
		thingsMade = {windmill = 0, mex = 0, converter = 0, solar = 0, tidal = 0, factory = 0},
		isWaiting = false,
		isHuman = isHuman
	}
	
	buildQueues[commanderID] = {}
	
	spGiveOrderToUnit(commanderID, CMD.WAIT, {}, 0)
	commanderMetaList[commanderID].isWaiting = true
	
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
	
	local unitDef = UnitDefs[unitDefID]
	local unitID = spCreateUnit(unitDef.name, buildX, buildY, buildZ, facing, teamID)
	if not unitID then
		return false, nil
	end
	
	local maxHealth = unitDef.health
	local currentHealth = math.ceil(maxHealth * buildProgress)
	spSetUnitHealth(unitID, {build = buildProgress, health = currentHealth})
	
	commanderData.juice = commanderData.juice - affordableJuice
	
	local unitName = unitDef.name
	local commanderDefID = spGetUnitDefID(commanderID)
	local commanderName = UnitDefs[commanderDefID].name
	local nonLabOptions = commanderNonLabOptions[commanderName]
	
	if nonLabOptions then
		for optionName, trueName in pairs(nonLabOptions) do
			if trueName == unitName then
				commanderData.thingsMade[optionName] = commanderData.thingsMade[optionName] + 1
				break
			end
		end
	end
	
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

local function createFactoryForFree(unitDefID, buildX, buildY, buildZ, facing, teamID, commanderData)
	local unitDef = UnitDefs[unitDefID]
	local unitID = spCreateUnit(unitDef.name, buildX, buildY, buildZ, facing, teamID)
	if not unitID then
		return false, nil
	end
	
	spSetUnitHealth(unitID, {build = 1, health = unitDef.health})
	
	if commanderData then
		commanderData.thingsMade.factory = commanderData.thingsMade.factory + 1
	end
	
	Spring.SpawnCEG("quickstart-spawn-pulse-large", buildX, buildY + 10, buildZ)
	
	return true, unitID
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

local function hasFactoryInQueue(commanderID)
	local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
	for i, cmd in ipairs(commands) do
		if isBuildCommand(cmd.id) then
			local buildDefID = -cmd.id
			local unitDef = UnitDefs[buildDefID]
			if unitDef and factoryOptions[unitDef.name] then
				return true, cmd
			end
		end
	end
	return false, nil
end

local function selectWeightedRandom(weightedOptions)
	local totalWeight = 0
	for _, weight in pairs(weightedOptions) do
		totalWeight = totalWeight + weight
	end
	
	if totalWeight <= 0 then
		return nil
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


local function convertDirectionToFacing(directionX, directionZ)
	local angle = math.atan2(directionX, -directionZ)
	local facing = math.floor((angle / (math.pi / 2)) + 0.5) % 4
	Spring.Echo("convertDirectionToFacing", directionX, directionZ, "angle:", angle, "facing:", facing)
	return facing
end

local function getLabFacingTowardsEnemy(unitID, buildX, buildZ)
	local nearestEnemyID = Spring.GetUnitNearestEnemy(unitID, 999999, false)
	if nearestEnemyID and Spring.ValidUnitID(nearestEnemyID) then
		local enemyX, enemyY, enemyZ = Spring.GetUnitPosition(nearestEnemyID)
		if enemyX then
			local directionX = enemyX - buildX
			local directionZ = enemyZ - buildZ
			return convertDirectionToFacing(directionX, directionZ)
		end
	end
	
	local directionX = MAP_CENTER_X - buildX
	local directionZ = MAP_CENTER_Z - buildZ
	return convertDirectionToFacing(directionX, directionZ)
end

local function snapToGrid(x, z, unitDefID)
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then
		return x, z
	end
	
	local SQUARE_SIZE = 8
	local BUILD_SQUARE_SIZE = SQUARE_SIZE * 2
	
	local xSize = SQUARE_SIZE * unitDef.xsize
	local zSize = SQUARE_SIZE * unitDef.zsize
	
	local snappedX, snappedZ = x, z
	
	if math.floor(xSize / 16) % 2 > 0 then
		snappedX = math.floor(x / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE + SQUARE_SIZE
	else
		snappedX = math.floor((x + SQUARE_SIZE) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE
	end
	
	if math.floor(zSize / 16) % 2 > 0 then
		snappedZ = math.floor(z / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE + SQUARE_SIZE
	else
		snappedZ = math.floor((z + SQUARE_SIZE) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE
	end
	
	return snappedX, snappedZ
end

local function generateCenterSkewedPositions(chunkStartX, chunkEndX, chunkStartZ, chunkEndZ, gridSpacing)
	local positions = {}
	local chunkCenterX = (chunkStartX + chunkEndX) / 2
	local chunkCenterZ = (chunkStartZ + chunkEndZ) / 2
	
	for searchX = chunkStartX, chunkEndX, gridSpacing do
		for searchZ = chunkStartZ, chunkEndZ, gridSpacing do
			local distance = (searchX - chunkCenterX)^2 + (searchZ - chunkCenterZ)^2
			table.insert(positions, {x = searchX, z = searchZ, distance = distance})
		end
	end
	
	table.sort(positions, function(a, b)
		return a.distance < b.distance
	end)
	
	return positions
end

local function findBuildLocationAndCreateUnit(x, y, z, unitDefID, teamID, commanderData, commanderID)
	if not commanderData or commanderData.juice <= 0 then
		return false
	end
	
	local isMetalMap = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].isMetalMap
	
	local unitDef = UnitDefs[unitDefID]
	local isMetalExtractor = unitDef and unitDef.extractsMetal and unitDef.extractsMetal > 0
	
	if isMetalExtractor and not isMetalMap then
		if GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList then
			local metalSpots = GG["resource_spot_finder"].metalSpotsList
			if metalSpots and #metalSpots > 0 then
				local spotsWithDistance = {}
				for i = 1, #metalSpots do
					local spot = metalSpots[i]
					local distanceSquared = (spot.x - x)^2 + (spot.z - z)^2
					if distanceSquared <= MEX_MAX_DISTANCE * MEX_MAX_DISTANCE then
						table.insert(spotsWithDistance, {
							spot = spot,
							distance = distanceSquared
						})
					end
				end
				
				table.sort(spotsWithDistance, function(a, b) return a.distance < b.distance end)
				
				for _, spotData in ipairs(spotsWithDistance) do
					local spot = spotData.spot
					local buildX, buildY, buildZ = spot.x, spot.y, spot.z
				local buildTest = Spring.TestBuildOrder(unitDefID, buildX, buildY, buildZ, 0)
				if buildTest > 0 then
					local facing = getLabFacingTowardsEnemy(commanderID, buildX, buildZ)
					
					local fullyBuilt, unitID = deductJuiceAndCreateUnit(commanderData, unitDefID, buildX, buildY, buildZ, facing, teamID, commanderID)
						if unitID then
							return unitID
						end
					end
				end
			end
		end
		
		return false
	end
	
	local maxDistance = 250
	local chunkSize = (maxDistance * 2) / 3
	local gridSpacing = 32
	
	local unitDef = UnitDefs[unitDefID]
	local isConverter = unitDef and (unitDef.name == "armmakr" or unitDef.name == "legeconv")
	
	
	local allChunks = {}
	if isConverter then
		allChunks = {
			{1, 1}, {2, 1}, {3, 1},
			{1, 2}, {3, 2},
			{1, 3}, {2, 3}, {3, 3}
		}
	else
		allChunks = {
			{1, 1}, {2, 1},
			{1, 2}, {3, 2},
			{1, 3}, {2, 3}, {3, 3}
		}
	end
	
	local chunksWithDistance = {}
	for i, chunk in ipairs(allChunks) do
		local chunkX, chunkZ = chunk[1], chunk[2]
		
		local chunkCenterX = x - maxDistance + (chunkX - 0.5) * chunkSize
		local chunkCenterZ = z - maxDistance + (chunkZ - 0.5) * chunkSize
		
		local distanceFromMapCenter = (chunkCenterX - MAP_CENTER_X)^2 + (chunkCenterZ - MAP_CENTER_Z)^2
		
		table.insert(chunksWithDistance, {
			chunk = chunk,
			distance = distanceFromMapCenter
		})
	end
	
	table.sort(chunksWithDistance, function(a, b) return a.distance > b.distance end)
	
	if not isConverter and #chunksWithDistance > 1 then
		table.remove(chunksWithDistance, 1)
	end
	
	for _, chunkData in ipairs(chunksWithDistance) do
		local chunkX, chunkZ = chunkData.chunk[1], chunkData.chunk[2]
		
		local chunkStartX = x - maxDistance + (chunkX - 1) * chunkSize
		local chunkEndX = x - maxDistance + chunkX * chunkSize
		local chunkStartZ = z - maxDistance + (chunkZ - 1) * chunkSize
		local chunkEndZ = z - maxDistance + chunkZ * chunkSize
		
		local positions = generateCenterSkewedPositions(chunkStartX, chunkEndX, chunkStartZ, chunkEndZ, gridSpacing)
		
		for _, pos in ipairs(positions) do
			local snappedX, snappedZ = snapToGrid(pos.x, pos.z, unitDefID)
			local searchY = spGetGroundHeight(snappedX, snappedZ)
			
			local buildTest = Spring.TestBuildOrder(unitDefID, snappedX, searchY, snappedZ, 0)
			if buildTest > 0 then
				local facing = getLabFacingTowardsEnemy(commanderID, snappedX, snappedZ)
				
				local fullyBuilt, unitID = deductJuiceAndCreateUnit(commanderData, unitDefID, snappedX, searchY, snappedZ, facing, teamID, commanderID)
				if unitID then
					return unitID
				end
			end
		end
	end
	
	return false
end


local function createRandomBuildQueue(commanderID, commanderData)
	local commanderDefID = spGetUnitDefID(commanderID)
	local commanderName = UnitDefs[commanderDefID].name
	local nonLabOptions = commanderNonLabOptions[commanderName]
	
	if not nonLabOptions then
		return
	end
	
	local buildQueue = {}
	
	local mexQuota = landBuildQuotas.mex or 0
	if mexQuota > 0 then
		local trueName = nonLabOptions.mex
		if trueName then
			local unitDefID = unitDefNames[trueName] and unitDefNames[trueName].id
			if unitDefID then
				local isMetalMap = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].isMetalMap
				local shouldAddMex = true
				
				if not isMetalMap then
					if not GG or not GG["resource_spot_finder"] or not GG["resource_spot_finder"].metalSpotsList or #GG["resource_spot_finder"].metalSpotsList == 0 then
						shouldAddMex = false
					end
				end
				
				if shouldAddMex then
					local alreadyMade = commanderData.thingsMade.mex or 0
					local stillNeeded = math.max(0, mexQuota - alreadyMade)
					
					for i = 1, stillNeeded do
						table.insert(buildQueue, {
							unitDefID = unitDefID,
							optionName = "mex",
							trueName = trueName,
							isQuotaItem = true
						})
					end
				end
			end
		end
	end
	
	for optionName, quota in pairs(landBuildQuotas) do
		if optionName ~= "mex" then
			local trueName = nonLabOptions[optionName]
			if trueName and quota > 0 then
				local unitDefID = unitDefNames[trueName] and unitDefNames[trueName].id
				if unitDefID then
					local weight = randomBuildOptionWeights[optionName] or 0
					if weight > 0 then
						local alreadyMade = commanderData.thingsMade[optionName] or 0
						local stillNeeded = math.max(0, quota - alreadyMade)
						
						for i = 1, stillNeeded do
							table.insert(buildQueue, {
								unitDefID = unitDefID,
								optionName = optionName,
								trueName = trueName,
								isQuotaItem = true
							})
						end
					end
				end
			end
		end
	end
	
	local nonMexStartIndex = (landBuildQuotas.mex or 0) + 1
	if nonMexStartIndex <= #buildQueue then
		for i = #buildQueue, nonMexStartIndex + 1, -1 do
			local j = math.random(nonMexStartIndex, i)
			buildQueue[i], buildQueue[j] = buildQueue[j], buildQueue[i]
		end
	end
	
	local hasFactoryInCommanderQueue = hasFactoryInQueue(commanderID)
	
	local weightedOptions = {}
	for optionName, weight in pairs(randomBuildOptionWeights) do
		local trueName = nonLabOptions[optionName]
		if trueName then
			local unitDefID = unitDefNames[trueName] and unitDefNames[trueName].id
			if unitDefID then
				local isFactory = factoryOptions[trueName]
				if not (isFactory and hasFactoryInCommanderQueue) then
					weightedOptions[optionName] = weight
				end
			end
		end
	end
	
	local overflowCount = 10
	for i = 1, overflowCount do
		local selectedOption = selectWeightedRandom(weightedOptions)
		if selectedOption then
			local trueName = nonLabOptions[selectedOption]
			local unitDefID = unitDefNames[trueName] and unitDefNames[trueName].id
			if unitDefID then
				table.insert(buildQueue, {
					unitDefID = unitDefID,
					optionName = selectedOption,
					trueName = trueName,
					isQuotaItem = false
				})
			end
		end
	end
	
	buildQueues[commanderID] = buildQueue
end

local function processFactoryRequirement(commanderID, commanderData)
	if not factoryRequired or commanderData.factoryMade then
		return
	end
	
	local commanderDefID = spGetUnitDefID(commanderID)
	local commanderName = UnitDefs[commanderDefID].name
	local landLabs = commanderLandLabs[commanderName]
	local seaLabs = commanderSeaLabs[commanderName]
	
	if not landLabs and not seaLabs then
		return
	end
	
	local factoryInQueue, factoryCommand = hasFactoryInQueue(commanderID)
	
	if factoryInQueue and factoryCommand then
		return
	else
		local availableFactories = {}
		
		if landLabs then
			for factoryName, _ in pairs(landLabs.labs) do
				local unitDefID = unitDefNames[factoryName] and unitDefNames[factoryName].id
				if unitDefID then
					table.insert(availableFactories, {
						unitDefID = unitDefID,
						name = factoryName
					})
				end
			end
		end
		
		if seaLabs then
			for factoryName, _ in pairs(seaLabs) do
				local unitDefID = unitDefNames[factoryName] and unitDefNames[factoryName].id
				if unitDefID then
					table.insert(availableFactories, {
						unitDefID = unitDefID,
						name = factoryName
					})
				end
			end
		end
		
		if #availableFactories > 0 then
			local factoryOrder = {}
			
			if commanderData.isHuman then
				local firstFactory = nil
				if landLabs and landLabs.labs then
					for labName, _ in pairs(landLabs.labs) do
						for _, factory in ipairs(availableFactories) do
							if factory.name == labName then
								firstFactory = factory
								break
							end
						end
						if firstFactory then
							break
						end
					end
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
					local probability = 0
					if landLabs and landLabs.labs[factory.name] then
						probability = landLabs.labs[factory.name]
					elseif seaLabs and seaLabs[factory.name] then
						probability = seaLabs[factory.name]
					end
					table.insert(sortedFactories, {
						factory = factory,
						probability = probability
					})
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
			
			local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
			
			local maxDistance = 250
			local chunkSize = (maxDistance * 2) / 3
			local gridSpacing = 32
			
			local allChunks = {
				{1, 1}, {2, 1}, {3, 1},
				{1, 2}, {3, 2},
				{1, 3}, {2, 3}, {3, 3}
			}
			
			local chunksWithDistance = {}
			for i, chunk in ipairs(allChunks) do
				local chunkX, chunkZ = chunk[1], chunk[2]
				local chunkCenterX = commanderX - maxDistance + (chunkX - 0.5) * chunkSize
				local chunkCenterZ = commanderZ - maxDistance + (chunkZ - 0.5) * chunkSize
				local distanceFromMapCenter = (chunkCenterX - MAP_CENTER_X)^2 + (chunkCenterZ - MAP_CENTER_Z)^2
				
				table.insert(chunksWithDistance, {
					chunk = chunk,
					distance = distanceFromMapCenter
				})
			end
			
			table.sort(chunksWithDistance, function(a, b) return a.distance < b.distance end)
			
			local factoryBuilt = false
			for _, factory in ipairs(factoryOrder) do
				if factoryBuilt then break end
				
				
				for _, chunkData in ipairs(chunksWithDistance) do
					if factoryBuilt then break end
					
					local chunkX, chunkZ = chunkData.chunk[1], chunkData.chunk[2]
					local chunkStartX = commanderX - maxDistance + (chunkX - 1) * chunkSize
					local chunkEndX = commanderX - maxDistance + chunkX * chunkSize
					local chunkStartZ = commanderZ - maxDistance + (chunkZ - 1) * chunkSize
					local chunkEndZ = commanderZ - maxDistance + chunkZ * chunkSize
					
					local positions = {}
					for searchX = chunkStartX, chunkEndX, gridSpacing do
						for searchZ = chunkStartZ, chunkEndZ, gridSpacing do
							table.insert(positions, {x = searchX, z = searchZ})
						end
					end
					
					table.sort(positions, function(a, b)
						local distA = (a.x - commanderX)^2 + (a.z - commanderZ)^2
						local distB = (b.x - commanderX)^2 + (b.z - commanderZ)^2
						return distA < distB
					end)
					
					for _, pos in ipairs(positions) do
						local snappedX, snappedZ = snapToGrid(pos.x, pos.z, factory.unitDefID)
						local searchY = spGetGroundHeight(snappedX, snappedZ)
						
						local buildTest = Spring.TestBuildOrder(factory.unitDefID, snappedX, searchY, snappedZ, 0)
						if buildTest > 0 then
							local facing = getLabFacingTowardsEnemy(commanderID, snappedX, snappedZ)
							
							local fullyBuilt, unitID = createFactoryForFree(factory.unitDefID, snappedX, searchY, snappedZ, facing, commanderData.teamID, commanderData)
							if fullyBuilt then
								commanderData.factoryMade = true
								factoryBuilt = true
								break
							end
						end
					end
				end
			end
			
		end
	end
end

local function processCommanderCommands(commanderID, commanderData)
	if teamsToBoost[commanderData.teamID] and hasResourcesLeft(commanderData) then
		local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
		if next(commands) then
			for i, cmd in ipairs(commands) do
				local buildsiteX, buildsiteZ = cmd.params[1], cmd.params[3]
				if isBuildCommand(cmd.id) and isCommanderInRange(commanderID, buildsiteX, buildsiteZ) then
					local buildDefID = -cmd.id
					local unitDef = UnitDefs[buildDefID]
					local isFactory = unitDef and factoryOptions[unitDef.name]
					
					if isFactory then
						local buildX, buildY, buildZ = cmd.params[1], cmd.params[2], cmd.params[3]
						local facing = getLabFacingTowardsEnemy(commanderID, buildX, buildZ)
						
						local fullyBuilt, unitID = createFactoryForFree(buildDefID, buildX, buildY, buildZ, facing, commanderData.teamID, commanderData)
						if fullyBuilt then
							commanderData.factoryMade = true
							spGiveOrderToUnit(commanderID, CMD.REMOVE, {i}, 0)
						end
					else
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

	local commanderCount = 0
	for _ in pairs(commanderMetaList) do commanderCount = commanderCount + 1 end
	for commanderID, commanderData in pairs(commanderMetaList) do
		local commanderData = commanderMetaList[commanderID]

		processCommanderCommands(commanderID, commanderData)

		if not buildQueues[commanderID] or #buildQueues[commanderID] == 0 then
			createRandomBuildQueue(commanderID, commanderData)
		end

		while commanderData.juice > 0 and #buildQueues[commanderID] > 0 do
			local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
			local buildItem = buildQueues[commanderID][1]
			
			if buildItem then
				local unitID = findBuildLocationAndCreateUnit(commanderX, commanderY, commanderZ, buildItem.unitDefID, commanderData.teamID, commanderData, commanderID)
				if unitID then
					table.remove(buildQueues[commanderID], 1)
					
					local hasQuotaItems = false
					for _, item in ipairs(buildQueues[commanderID]) do
						if item.isQuotaItem then
							hasQuotaItems = true
							break
						end
					end
					
					if not hasQuotaItems and commanderData.juice > 0 then
						createRandomBuildQueue(commanderID, commanderData)
					end
				else
					table.remove(buildQueues[commanderID], 1)
				end
			else
				break
			end
		end

		processFactoryRequirement(commanderID, commanderData)
		
		if commanderData.juice <= 0 and commanderData.isWaiting then
			spGiveOrderToUnit(commanderID, CMD.WAIT, {}, CMD.OPT_RIGHT)
			commanderData.isWaiting = false
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
		buildQueues[unitID] = nil
	elseif partiallyBuiltStructures[unitID] then
		partiallyBuiltStructures[unitID] = nil
	end
end

function gadget:Initialize()
	local minWind = Game.windMin
	local maxWind = Game.windMax
	
	local avgWind = {[0]={[1]="0.8",[2]="1.5",[3]="2.2",[4]="3.0",[5]="3.7",[6]="4.5",[7]="5.2",[8]="6.0",[9]="6.7",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.4",[15]="11.2",[16]="11.9",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[1]={[2]="1.6",[3]="2.3",[4]="3.0",[5]="3.8",[6]="4.5",[7]="5.2",[8]="6.0",[9]="6.7",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.4",[15]="11.2",[16]="11.9",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[2]={[3]="2.6",[4]="3.2",[5]="3.9",[6]="4.6",[7]="5.3",[8]="6.0",[9]="6.8",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.5",[15]="11.2",[16]="12.0",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[3]={[4]="3.6",[5]="4.2",[6]="4.8",[7]="5.5",[8]="6.2",[9]="6.9",[10]="7.6",[11]="8.3",[12]="9.0",[13]="9.8",[14]="10.5",[15]="11.2",[16]="12.0",[17]="12.7",[18]="13.5",[19]="14.2",[20]="15.0",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.7",[26]="19.2",[27]="19.7",[28]="20.0",[29]="20.4",[30]="20.7",},[4]={[5]="4.6",[6]="5.2",[7]="5.8",[8]="6.4",[9]="7.1",[10]="7.8",[11]="8.5",[12]="9.2",[13]="9.9",[14]="10.6",[15]="11.3",[16]="12.1",[17]="12.8",[18]="13.5",[19]="14.3",[20]="15.0",[21]="15.7",[22]="16.5",[23]="17.2",[24]="18.0",[25]="18.7",[26]="19.2",[27]="19.7",[28]="20.1",[29]="20.4",[30]="20.7",},[5]={[6]="5.5",[7]="6.1",[8]="6.8",[9]="7.4",[10]="8.0",[11]="8.7",[12]="9.4",[13]="10.1",[14]="10.8",[15]="11.5",[16]="12.2",[17]="12.9",[18]="13.6",[19]="14.4",[20]="15.1",[21]="15.8",[22]="16.5",[23]="17.3",[24]="18.0",[25]="18.8",[26]="19.3",[27]="19.7",[28]="20.1",[29]="20.4",[30]="20.7",},[6]={[7]="6.5",[8]="7.1",[9]="7.7",[10]="8.4",[11]="9.0",[12]="9.7",[13]="10.3",[14]="11.0",[15]="11.7",[16]="12.4",[17]="13.1",[18]="13.8",[19]="14.5",[20]="15.2",[21]="15.9",[22]="16.7",[23]="17.4",[24]="18.1",[25]="18.8",[26]="19.4",[27]="19.8",[28]="20.2",[29]="20.5",[30]="20.8",},[7]={[8]="7.5",[9]="8.1",[10]="8.7",[11]="9.3",[12]="10.0",[13]="10.6",[14]="11.3",[15]="11.9",[16]="12.6",[17]="13.3",[18]="14.0",[19]="14.7",[20]="15.4",[21]="16.1",[22]="16.8",[23]="17.5",[24]="18.2",[25]="19.0",[26]="19.5",[27]="19.9",[28]="20.3",[29]="20.6",[30]="20.9",},[8]={[9]="8.5",[10]="9.1",[11]="9.7",[12]="10.3",[13]="11.0",[14]="11.6",[15]="12.2",[16]="12.9",[17]="13.6",[18]="14.2",[19]="14.9",[20]="15.6",[21]="16.3",[22]="17.0",[23]="17.7",[24]="18.4",[25]="19.1",[26]="19.6",[27]="20.0",[28]="20.4",[29]="20.7",[30]="21.0",},[9]={[10]="9.5",[11]="10.1",[12]="10.7",[13]="11.3",[14]="11.9",[15]="12.6",[16]="13.2",[17]="13.8",[18]="14.5",[19]="15.2",[20]="15.8",[21]="16.5",[22]="17.2",[23]="17.9",[24]="18.6",[25]="19.3",[26]="19.8",[27]="20.2",[28]="20.5",[29]="20.8",[30]="21.1",},[10]={[11]="10.5",[12]="11.1",[13]="11.7",[14]="12.3",[15]="12.9",[16]="13.5",[17]="14.2",[18]="14.8",[19]="15.4",[20]="16.1",[21]="16.8",[22]="17.4",[23]="18.1",[24]="18.8",[25]="19.5",[26]="20.0",[27]="20.4",[28]="20.7",[29]="21.0",[30]="21.2",},[11]={[12]="11.5",[13]="12.1",[14]="12.7",[15]="13.3",[16]="13.9",[17]="14.5",[18]="15.1",[19]="15.8",[20]="16.4",[21]="17.1",[22]="17.7",[23]="18.4",[24]="19.1",[25]="19.7",[26]="20.2",[27]="20.6",[28]="20.9",[29]="21.2",[30]="21.4",},[12]={[13]="12.5",[14]="13.1",[15]="13.6",[16]="14.2",[17]="14.9",[18]="15.5",[19]="16.1",[20]="16.7",[21]="17.4",[22]="18.0",[23]="18.7",[24]="19.3",[25]="20.0",[26]="20.4",[27]="20.8",[28]="21.1",[29]="21.4",[30]="21.6",},[13]={[14]="13.5",[15]="14.1",[16]="14.6",[17]="15.2",[18]="15.8",[19]="16.5",[20]="17.1",[21]="17.7",[22]="18.4",[23]="19.0",[24]="19.6",[25]="20.3",[26]="20.7",[27]="21.1",[28]="21.4",[29]="21.6",[30]="21.8",},[14]={[15]="14.5",[16]="15.0",[17]="15.6",[18]="16.2",[19]="16.8",[20]="17.4",[21]="18.1",[22]="18.7",[23]="19.3",[24]="20.0",[25]="20.6",[26]="21.0",[27]="21.3",[28]="21.6",[29]="21.8",[30]="22.0",},[15]={[16]="15.5",[17]="16.0",[18]="16.6",[19]="17.2",[20]="17.8",[21]="18.4",[22]="19.0",[23]="19.6",[24]="20.3",[25]="20.9",[26]="21.3",[27]="21.6",[28]="21.9",[29]="22.1",[30]="22.3",},[16]={[17]="16.5",[18]="17.0",[19]="17.6",[20]="18.2",[21]="18.8",[22]="19.4",[23]="20.0",[24]="20.6",[25]="21.3",[26]="21.7",[27]="21.9",[28]="22.2",[29]="22.4",[30]="22.5",},[17]={[18]="17.5",[19]="18.0",[20]="18.6",[21]="19.2",[22]="19.8",[23]="20.4",[24]="21.0",[25]="21.6",[26]="22.0",[27]="22.3",[28]="22.5",[29]="22.7",[30]="22.8",},[18]={[19]="18.5",[20]="19.0",[21]="19.6",[22]="20.2",[23]="20.8",[24]="21.4",[25]="22.0",[26]="22.4",[27]="22.6",[28]="22.8",[29]="23.0",[30]="23.1",},[19]={[20]="19.5",[21]="20.0",[22]="20.6",[23]="21.2",[24]="21.8",[25]="22.4",[26]="22.7",[27]="22.9",[28]="23.1",[29]="23.2",[30]="23.4",},[20]={[21]="20.4",[22]="21.0",[23]="21.6",[24]="22.2",[25]="22.8",[26]="23.1",[27]="23.3",[28]="23.4",[29]="23.6",[30]="23.7",},[21]={[22]="21.4",[23]="22.0",[24]="22.6",[25]="23.2",[26]="23.5",[27]="23.6",[28]="23.8",[29]="23.9",[30]="24.0",},[22]={[23]="22.4",[24]="23.0",[25]="23.6",[26]="23.8",[27]="24.0",[28]="24.1",[29]="24.2",[30]="24.2",},[23]={[24]="23.4",[25]="24.0",[26]="24.2",[27]="24.4",[28]="24.4",[29]="24.5",[30]="24.5",},[24]={[25]="24.4",[26]="24.6",[27]="24.7",[28]="24.7",[29]="24.8",[30]="24.8",},}
	
	local averageWind
	if avgWind[minWind] and avgWind[minWind][maxWind] then
		averageWind = tonumber(avgWind[minWind][maxWind])
	else
		averageWind = math.max(minWind, maxWind * 0.75)
	end
	
	isGoodWind = averageWind > 7
	
	for optionName, baseWeight in pairs(baseBuildOptionWeights) do
		if optionName == "windmill" and not isGoodWind then
			randomBuildOptionWeights[optionName] = 0
		elseif optionName == "solar" and isGoodWind then
			randomBuildOptionWeights[optionName] = baseWeight * SOLAR_PENALTY_MULTIPLIER
		else
			randomBuildOptionWeights[optionName] = baseWeight
		end
	end
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