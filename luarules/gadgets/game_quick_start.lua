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

local BONUS_METAL = 450 -- the amount of metal produced during a normal build order up to the 1:30 mark.
local BONUS_ENERGY = 2500 -- the amount of energy produced during a normal build order up to the 1:30 mark.
local MEX_MAX_DISTANCE = 500 -- maximum distance metal extractors will search for metal spots on non-metal maps

local factoryRequired = true

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
local buildQueues = {} -- Random build queues for each commander


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
	local juice = availableMetal + BONUS_METAL + ((availableEnergy + BONUS_ENERGY) / ENERGY_VALUE_CONVERSION_DIVISOR)
	
	commanderMetaList[commanderID] = {
		teamID = teamID,
		juice = juice,
		lastCommandCheck = 0,
		factoryMade = false,
		thingsMade = {windmill = 0, mex = 0, converter = 0, solar = 0, tidal = 0, factory = 0}
	}
	
	-- Initialize empty build queue
	buildQueues[commanderID] = {}
	
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
	
	-- Track the type of structure built
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
	
	-- Build completely for free
	spSetUnitHealth(unitID, {build = 1, health = unitDef.health})
	
	-- Track the factory in tallies
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

local function canAffordAnyPartialBuild(commanderData)
	return commanderData.juice > 0
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
	
	-- Snap X coordinate
	if math.floor(xSize / 16) % 2 > 0 then
		snappedX = math.floor(x / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE + SQUARE_SIZE
	else
		snappedX = math.floor((x + SQUARE_SIZE) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE
	end
	
	-- Snap Z coordinate
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
	
	-- Generate all grid positions
	for searchX = chunkStartX, chunkEndX, gridSpacing do
		for searchZ = chunkStartZ, chunkEndZ, gridSpacing do
			table.insert(positions, {x = searchX, z = searchZ})
		end
	end
	
	-- Sort by distance from chunk center (closest first)
	table.sort(positions, function(a, b)
		local distA = math.sqrt((a.x - chunkCenterX)^2 + (a.z - chunkCenterZ)^2)
		local distB = math.sqrt((b.x - chunkCenterX)^2 + (b.z - chunkCenterZ)^2)
		return distA < distB
	end)
	
	return positions
end

local function findBuildLocationAndCreateUnit(x, y, z, unitDefID, teamID, commanderData, commanderID)
	if not commanderData or commanderData.juice <= 0 then
		return false
	end
	
	-- Check if this is a metal map
	local isMetalMap = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].isMetalMap
	
	-- Check if this is a metal extractor
	local unitDef = UnitDefs[unitDefID]
	local isMetalExtractor = unitDef and unitDef.extractsMetal and unitDef.extractsMetal > 0
	
	-- On metal maps, metal extractors can be built anywhere (like other structures)
	-- On non-metal maps, metal extractors MUST be built on metal spots or not at all
	if isMetalExtractor and not isMetalMap then
		-- Use metal spot snapping for non-metal maps - NO FALLBACK to grid placement
		if GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList then
			local metalSpots = GG["resource_spot_finder"].metalSpotsList
			if metalSpots and #metalSpots > 0 then
				-- Sort metal spots by distance from commander position
				local spotsWithDistance = {}
				for i = 1, #metalSpots do
					local spot = metalSpots[i]
					local distance = math.sqrt((spot.x - x)^2 + (spot.z - z)^2)
					if distance <= MEX_MAX_DISTANCE then
						table.insert(spotsWithDistance, {
							spot = spot,
							distance = distance
						})
					end
				end
				
				-- Sort by distance (closest first)
				table.sort(spotsWithDistance, function(a, b) return a.distance < b.distance end)
				
				-- Try each metal spot in order of distance
				for _, spotData in ipairs(spotsWithDistance) do
					local spot = spotData.spot
					local buildX, buildY, buildZ = spot.x, spot.y, spot.z
					local buildTest = Spring.TestBuildOrder(unitDefID, buildX, buildY, buildZ, 0)
					if buildTest > 0 then
						local mapCenterX = Game.mapSizeX / 2
						local mapCenterZ = Game.mapSizeZ / 2
						local directionX = mapCenterX - buildX
						local directionZ = mapCenterZ - buildZ
						local facing = math.floor((math.atan2(directionZ, directionX) * 32768 / math.pi) + 0.5)
						
						local fullyBuilt, unitID = deductJuiceAndCreateUnit(commanderData, unitDefID, buildX, buildY, buildZ, facing, teamID, commanderID)
						if unitID then
							return unitID
						end
					end
				end
			end
		end
		
		-- If we reach here, no valid metal spots were found for metal extractor on non-metal map
		-- Return false to skip building this metal extractor entirely
		return false
	end
	
	-- Grid-based systematic placement for all structures (including metal extractors on metal maps)
	local maxDistance = 250
	local chunkSize = (maxDistance * 2) / 3 -- Divide into 3x3 grid
	local gridSpacing = 32 -- Grid spacing for systematic placement
	
	-- Check if this is an energy converter
	local unitDef = UnitDefs[unitDefID]
	local isConverter = unitDef and (unitDef.name == "armmakr" or unitDef.name == "legeconv")
	
	local mapCenterX = Game.mapSizeX / 2
	local mapCenterZ = Game.mapSizeZ / 2
	
	-- Calculate all possible chunks with their distances from map center
	local allChunks = {}
	if isConverter then
		-- Energy converters use all 8 chunks (3x3), excluding the middle one (chunk 5)
		allChunks = {
			{1, 1}, {2, 1}, {3, 1}, -- Top row
			{1, 2}, {3, 2}, -- Middle row (excluding center)
			{1, 3}, {2, 3}, {3, 3}  -- Bottom row
		}
	else
		-- Other structures use 7 chunks (3x3), excluding the middle one (chunk 5) and the farthest chunk (reserved for converters)
		allChunks = {
			{1, 1}, {2, 1}, -- Top row (excluding top-right for converters)
			{1, 2}, {3, 2}, -- Middle row (excluding center)
			{1, 3}, {2, 3}, {3, 3}  -- Bottom row
		}
	end
	
	-- Calculate distance from map center for each chunk and sort by distance (farthest first)
	local chunksWithDistance = {}
	for i, chunk in ipairs(allChunks) do
		local chunkX, chunkZ = chunk[1], chunk[2]
		
		-- Calculate chunk center
		local chunkCenterX = x - maxDistance + (chunkX - 0.5) * chunkSize
		local chunkCenterZ = z - maxDistance + (chunkZ - 0.5) * chunkSize
		
		-- Calculate distance from map center
		local distanceFromMapCenter = math.sqrt((chunkCenterX - mapCenterX)^2 + (chunkCenterZ - mapCenterZ)^2)
		
		table.insert(chunksWithDistance, {
			chunk = chunk,
			distance = distanceFromMapCenter
		})
	end
	
	-- Sort by distance (farthest first)
	table.sort(chunksWithDistance, function(a, b) return a.distance > b.distance end)
	
	-- For non-converters, skip the farthest chunk (reserved for converters)
	if not isConverter and #chunksWithDistance > 1 then
		table.remove(chunksWithDistance, 1) -- Remove the farthest chunk
	end
	
	-- Try each chunk in order of distance from map center
	for _, chunkData in ipairs(chunksWithDistance) do
		local chunkX, chunkZ = chunkData.chunk[1], chunkData.chunk[2]
		
		-- Calculate chunk boundaries
		local chunkStartX = x - maxDistance + (chunkX - 1) * chunkSize
		local chunkEndX = x - maxDistance + chunkX * chunkSize
		local chunkStartZ = z - maxDistance + (chunkZ - 1) * chunkSize
		local chunkEndZ = z - maxDistance + chunkZ * chunkSize
		
		-- Generate center-skewed positions for this chunk
		local positions = generateCenterSkewedPositions(chunkStartX, chunkEndX, chunkStartZ, chunkEndZ, gridSpacing)
		
		-- Try each position in order of distance from chunk center
		for _, pos in ipairs(positions) do
			-- Snap to proper grid
			local snappedX, snappedZ = snapToGrid(pos.x, pos.z, unitDefID)
			local searchY = spGetGroundHeight(snappedX, snappedZ)
			
			local buildTest = Spring.TestBuildOrder(unitDefID, snappedX, searchY, snappedZ, 0)
			if buildTest > 0 then
				local directionX = mapCenterX - snappedX
				local directionZ = mapCenterZ - snappedZ
				local facing = math.floor((math.atan2(directionZ, directionX) * 32768 / math.pi) + 0.5)
				
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
	
	-- First pass: Add metal extractors FIRST (highest priority)
	local mexQuota = landBuildQuotas.mex or 0
	if mexQuota > 0 then
		local trueName = nonLabOptions.mex
		if trueName then
			local unitDefID = unitDefNames[trueName] and unitDefNames[trueName].id
			if unitDefID then
				-- Check if this is a non-metal map and if metal spots are available
				local isMetalMap = GG and GG["resource_spot_finder"] and GG["resource_spot_finder"].isMetalMap
				local shouldAddMex = true
				
				if not isMetalMap then
					-- On non-metal maps, only add metal extractors if metal spots are available
					if not GG or not GG["resource_spot_finder"] or not GG["resource_spot_finder"].metalSpotsList or #GG["resource_spot_finder"].metalSpotsList == 0 then
						shouldAddMex = false
					end
				end
				
				if shouldAddMex then
					local alreadyMade = commanderData.thingsMade.mex or 0
					local stillNeeded = math.max(0, mexQuota - alreadyMade)
					
					-- Always try to build full quota - let the building logic handle spot availability
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
	
	-- Second pass: Add other structures to meet quotas (excluding metal extractors)
	for optionName, quota in pairs(landBuildQuotas) do
		if optionName ~= "mex" then -- Skip metal extractors as they're already added
			local trueName = nonLabOptions[optionName]
			if trueName and quota > 0 then
				local unitDefID = unitDefNames[trueName] and unitDefNames[trueName].id
				if unitDefID then
					local alreadyMade = commanderData.thingsMade[optionName] or 0
					local stillNeeded = math.max(0, quota - alreadyMade)
					
					-- Add only what's still needed to meet quota
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
	
	-- Shuffle only the non-metal-extractor quota items
	local nonMexStartIndex = (landBuildQuotas.mex or 0) + 1
	if nonMexStartIndex <= #buildQueue then
		for i = #buildQueue, nonMexStartIndex + 1, -1 do
			local j = math.random(nonMexStartIndex, i)
			buildQueue[i], buildQueue[j] = buildQueue[j], buildQueue[i]
		end
	end
	
	-- Second pass: Add random structures for overflow (once quotas are met)
	local allStructures = {}
	for optionName, trueName in pairs(nonLabOptions) do
		local unitDefID = unitDefNames[trueName] and unitDefNames[trueName].id
		if unitDefID then
			table.insert(allStructures, {
				unitDefID = unitDefID,
				optionName = optionName,
				trueName = trueName,
				isQuotaItem = false
			})
		end
	end
	
	-- Add some random overflow structures
	local overflowCount = math.min(10, #allStructures) -- Add up to 10 random structures
	for i = 1, overflowCount do
		local randomIndex = math.random(#allStructures)
		local randomStructure = allStructures[randomIndex]
		table.insert(buildQueue, randomStructure)
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
	
	local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
	local factoryInQueue = false
	local factoryCommand = nil
	
	for i, cmd in ipairs(commands) do
		if isBuildCommand(cmd.id) then
			local buildDefID = -cmd.id
			local unitDef = UnitDefs[buildDefID]
			if unitDef and factoryOptions[unitDef.name] then
				factoryInQueue = true
				factoryCommand = cmd
				break
			end
		end
	end
	
	if factoryInQueue and factoryCommand then
		local buildDefID = -factoryCommand.id
		local buildX, buildY, buildZ = factoryCommand.params[1], factoryCommand.params[2], factoryCommand.params[3]
		local fullyBuilt, unitID = createFactoryForFree(buildDefID, buildX, buildY, buildZ, 0, commanderData.teamID, commanderData)
		if fullyBuilt then
			commanderData.factoryMade = true
			spGiveOrderToUnit(commanderID, CMD.REMOVE, {1}, 0)
		end
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
			-- Sort factories by probability (highest first) for fallback
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
			
			-- Try random factory first, then fallback to highest probability
			local factoryOrder = {}
			local randomIndex = math.random(#availableFactories)
			table.insert(factoryOrder, availableFactories[randomIndex])
			
			-- Add remaining factories in probability order (excluding the random one)
			for _, sortedFactory in ipairs(sortedFactories) do
				if sortedFactory.factory ~= availableFactories[randomIndex] then
					table.insert(factoryOrder, sortedFactory.factory)
				end
			end
			
			local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
			local mapCenterX = Game.mapSizeX / 2
			local mapCenterZ = Game.mapSizeZ / 2
			
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
				local distanceFromMapCenter = math.sqrt((chunkCenterX - mapCenterX)^2 + (chunkCenterZ - mapCenterZ)^2)
				
				table.insert(chunksWithDistance, {
					chunk = chunk,
					distance = distanceFromMapCenter
				})
			end
			
			table.sort(chunksWithDistance, function(a, b) return a.distance < b.distance end)
			
			-- Try each factory type until one succeeds
			local factoryBuilt = false
			for _, factory in ipairs(factoryOrder) do
				if factoryBuilt then break end
				
				
				-- Try each chunk in order of distance from map center
				for _, chunkData in ipairs(chunksWithDistance) do
					if factoryBuilt then break end
					
					local chunkX, chunkZ = chunkData.chunk[1], chunkData.chunk[2]
					local chunkStartX = commanderX - maxDistance + (chunkX - 1) * chunkSize
					local chunkEndX = commanderX - maxDistance + chunkX * chunkSize
					local chunkStartZ = commanderZ - maxDistance + (chunkZ - 1) * chunkSize
					local chunkEndZ = commanderZ - maxDistance + chunkZ * chunkSize
					
					-- Generate all positions in this chunk
					local positions = {}
					for searchX = chunkStartX, chunkEndX, gridSpacing do
						for searchZ = chunkStartZ, chunkEndZ, gridSpacing do
							table.insert(positions, {x = searchX, z = searchZ})
						end
					end
					
					-- Sort by distance from commander (closest first)
					table.sort(positions, function(a, b)
						local distA = math.sqrt((a.x - commanderX)^2 + (a.z - commanderZ)^2)
						local distB = math.sqrt((b.x - commanderX)^2 + (b.z - commanderZ)^2)
						return distA < distB
					end)
					
					-- Try each position in order of distance from commander
					for _, pos in ipairs(positions) do
						local snappedX, snappedZ = snapToGrid(pos.x, pos.z, factory.unitDefID)
						local searchY = spGetGroundHeight(snappedX, snappedZ)
						
						local buildTest = Spring.TestBuildOrder(factory.unitDefID, snappedX, searchY, snappedZ, 0)
						if buildTest > 0 then
							local directionX = mapCenterX - snappedX
							local directionZ = mapCenterZ - snappedZ
							local facing = math.floor((math.atan2(directionZ, directionX) * 32768 / math.pi) + 0.5)
							
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
			
			if not factoryBuilt then
			end
		end
	end
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

	local commanderCount = 0
	for _ in pairs(commanderMetaList) do commanderCount = commanderCount + 1 end
	for commanderID, commanderData in pairs(commanderMetaList) do
		local commanderData = commanderMetaList[commanderID]

		-- PRIORITY 1: Process commander's command queue first (intercept existing commands)
		processCommanderCommands(commanderID, commanderData)

		-- PRIORITY 2: Build metal extractors first (highest priority for resource income)
		-- Create build queue if it doesn't exist
		if not buildQueues[commanderID] or #buildQueues[commanderID] == 0 then
			createRandomBuildQueue(commanderID, commanderData)
		end

		-- Build structures from the queue sequentially (MEX first, then other structures)
		while commanderData.juice > 0 and #buildQueues[commanderID] > 0 do
			local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
			local buildItem = buildQueues[commanderID][1] -- Get first item from queue
			
			if buildItem then
				local unitID = findBuildLocationAndCreateUnit(commanderX, commanderY, commanderZ, buildItem.unitDefID, commanderData.teamID, commanderData, commanderID)
				if unitID then
					-- Successfully built, remove from queue
					table.remove(buildQueues[commanderID], 1)
					
					-- Check if we just finished all quota items and need to regenerate queue
					local hasQuotaItems = false
					for _, item in ipairs(buildQueues[commanderID]) do
						if item.isQuotaItem then
							hasQuotaItems = true
							break
						end
					end
					
					-- If no more quota items and still have juice, regenerate queue for overflow
					if not hasQuotaItems and commanderData.juice > 0 then
						createRandomBuildQueue(commanderID, commanderData)
					end
				else
					-- Failed to build, remove from queue to prevent infinite loop
					table.remove(buildQueues[commanderID], 1)
				end
			else
				break
			end
		end

		-- PRIORITY 3: Build factories last (after MEX and other structures are done)
		processFactoryRequirement(commanderID, commanderData)
		
		if commanderData.juice <= 0 then
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
		buildQueues[unitID] = nil
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