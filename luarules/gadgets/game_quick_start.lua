function gadget:GetInfo()
	return {
		name = "Quick Start v2",
		desc = "Instantly builds structures using starting resources until they are expended",
		author = "SethDGamre", 
		date = "July 2025",
		license = "GPLv2",
		layer = 0,
		enabled = true
	}
end

--[[ todo
-- need to implement water-based factory sel
]]

local isSynced = gadgetHandler:IsSyncedCode()
local modOptions = Spring.GetModOptions()
if not isSynced then return false end

local shouldRunGadget = modOptions.quick_start == "enabled" or "labs_required" or 
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))

if not shouldRunGadget then return false end

local spGetUnitPosition = Spring.GetUnitPosition
local spCreateUnit = Spring.CreateUnit
local spGetUnitCommands = Spring.GetUnitCommands
local spGetGroundHeight = Spring.GetGroundHeight
local spTestBuildOrder = Spring.TestBuildOrder
local spPos2BuildPos = Spring.Pos2BuildPos
local spSpawnCEG = Spring.SpawnCEG

local FACTORY_DISCOUNT_MULTIPLIER = 0.90
local FACTORY_DISCOUNT = 0
local BONUS_METAL = 450
local BONUS_ENERGY = 2500
local QUICK_START_COST_METAL = 800
local QUICK_START_COST_ENERGY = 400
local AUTO_MEX_MAX_DISTANCE = 500
local ENERGY_VALUE_CONVERSION_DIVISOR = 10
local INSTANT_BUILD_RANGE = 700
local MAX_SPACE_DISTANCE = INSTANT_BUILD_RANGE / 2
local ALL_COMMANDS = -1
local UPDATE_FRAMES = Game.gameSpeed
local PREGAME_DELAY_FRAMES = 61 --after gui_pregame_build.lua is loaded
local MAP_CENTER_X = Game.mapSizeX / 2
local MAP_CENTER_Z = Game.mapSizeZ / 2
local TEST_NOGO_DISTANCE = 100

local TEAM_RULES_FACTORY_PLACED_KEY = "quickStartFactoryPlaced"
local GAME_RULES_BASE_KEY = "quickStartJuiceBase"

local factoryRequired = modOptions.quick_start == "labs_required"
local isGoodWind = false
local isMetalMap = false
local metalSpotsList = nil
local BUILD_SPACING = 32
local SKIP_STEP = 3
local running = false
local initialized = false

local boostableCommanders = {} --zzz unpopulated
local queuedCommanders = {}
local commanders = {}
local defJuices = {}
local mexOverlapCheckTable = {}
local mexDefs = {}
local unitDefs = UnitDefs
local unitDefNames = UnitDefNames
local optionDefIDToTypes = {}
local factoryDiscounts = {}


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

local commanderSeaLabs = {
	armcom = { armsy = 1 },
	corcom = { corsy = 1 },
	legcom = { legsy = 1 },
}

local commanderNonLabOptions = {
	armcom = { 
		defaultFactory = "armlab",
		windmill = "armwin", --zzz need to store the types on the com
		mex = "armmex",
		converter = "armmakr",
		solar = "armsolar",
		tidal = "armtide",
		floatingConverter = "armfmkr",
	},
	corcom = {
		defaultFactory = "corlab",
		windmill = "corwin",
		mex = "cormex",
		converter = "cormakr",
		solar = "corsolar",
		tidal = "cortide",
		floatingConverter = "corfmkr",
	},
	legcom = {
		defaultFactory = "leglab",
		windmill = "legwin",
		mex = "legmex",
		converter = "legeconv",
		solar = "legsolar",
		tidal = "legtide",
		floatingConverter = "legfconv",
	}
}

local optionsToNodeType = {
	defaultFactory = "factory",
	windmill = "other",
	mex = "other",
	converter = "converters",
	solar = "other",
	tidal = "other",
	floatingConverter = "converters",
}


local commanderAllLabs = {}
for commanderName, landData in pairs(commanderLandLabs) do
	commanderAllLabs[commanderName] = {}
	for labName, weight in pairs(landData.labs) do
		commanderAllLabs[commanderName][labName] = weight
	end
	for labName, weight in pairs(commanderSeaLabs[commanderName]) do
		commanderAllLabs[commanderName][labName] = weight
	end
end
for unitDefID, unitDef in pairs(unitDefs) do
	--compile juice costs for all unit defs
	local metalCost, energyCost = unitDef.metalCost or 1, unitDef.energyCost or 1
	defJuices[unitDefID] = 	metalCost + (energyCost / ENERGY_VALUE_CONVERSION_DIVISOR)

	--for metal extractor detection
	if unitDef.extractsMetal > 0 then
		mexDefs[unitDefID] = true
	end

	if unitDef.customParams and unitDef.customParams.iscommander then
		boostableCommanders[unitDefID] = true
	end
end
for commanderName, labs in pairs(commanderAllLabs) do
	if unitDefNames[commanderName] then
	for labName, weight in pairs(labs) do
		local unitDefID = unitDefNames[labName].id
		FACTORY_DISCOUNT = math.min(FACTORY_DISCOUNT, defJuices[unitDefID] * FACTORY_DISCOUNT_MULTIPLIER)
		end
	end
end
for commanderName, nonLabOptions in pairs(commanderNonLabOptions) do
	Spring.Echo("commanderName", commanderName)
	if unitDefNames[commanderName] then
		for optionName, trueName in pairs(nonLabOptions) do
			Spring.Echo("optionName", optionName, "trueName", trueName, "commanderName", commanderName, "unitDefID", unitDefNames[trueName])
			Spring.Echo("name", trueName, "id", unitDefNames[trueName].id)
			optionDefIDToTypes[unitDefNames[trueName].id] = optionName
		end
	end
end

local function isBuildCommand(cmdID)
	return cmdID < 0
end

local function getBuildInstanceID(unitDefID, x, y)
	return unitDefID .. "_" .. x .. "_" .. y
end

local function initializeCommander(commanderID, teamID)
	local currentMetal = Spring.GetTeamResources(teamID, "metal") or 0
	local currentEnergy = Spring.GetTeamResources(teamID, "energy") or 0
	local juice = QUICK_START_COST_METAL + BONUS_METAL + (QUICK_START_COST_ENERGY + BONUS_ENERGY) / ENERGY_VALUE_CONVERSION_DIVISOR
	Spring.SetGameRulesParam(GAME_RULES_BASE_KEY, juice)
	
	local isHuman = false
	if GG and GG.PowerLib and GG.PowerLib.HumanTeams then
		isHuman = GG.PowerLib.HumanTeams[teamID] == true
	end
	
	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	local directionX = MAP_CENTER_X - commanderX
	local directionZ = MAP_CENTER_Z - commanderZ
	local angle = math.atan2(directionX, directionZ)
	local defaultFacing = math.floor((angle / (math.pi / 2)) + 0.5) % 4

	local commanderDefID = Spring.GetUnitDefID(commanderID)
	local commanderName = UnitDefs[commanderDefID].name
	local isInWater = commanderY < 0
	local buildDefs = {}
	for optionName, trueName in pairs(commanderNonLabOptions[commanderName]) do
		buildDefs[optionName] = unitDefNames[trueName].id
	end

	commanders[commanderID] = {
		teamID = teamID,
		juice = juice,
		factoryMade = false,
		thingsMade = {windmill = 0, mex = 0, converter = 0, solar = 0, tidal = 0, floatingConverter = 0, factory = 0},
		isHuman = isHuman,
		defaultFacing = defaultFacing,
		isInWater = isInWater,
		hasFactoryInQueue = false,
		commanderName = commanderName,
		buildDefs = buildDefs,
		buildPlots = {
			factory = {
				originX = commanderX, originZ = commanderZ, indexX = 0, indexZ = 0, skipDirection = "x"
			},
			converters = {
				originX = commanderX, originZ = commanderZ, indexX = 0, indexZ = 0, skipDirection = "x"
			},
			other = {
				originX = commanderX, originZ = commanderZ, indexX = 0, indexZ = 0, skipDirection = "x"
			}
		},
		buildQuotas = { 
		mex = 4, windmill = isInWater and 0 or (isGoodWind and 4 or 0), converter = isInWater and 0 or 2, 
		solar = isInWater and 0 or (isGoodWind and 1 or 4), tidal = isInWater and 6 or 0, floatingConverter = isInWater and 2 or 0 
		}
	}
	
	Spring.SetTeamResource(teamID, "metal", math.max(0, currentMetal - QUICK_START_COST_METAL))
	Spring.SetTeamResource(teamID, "energy", math.max(0, currentEnergy - QUICK_START_COST_ENERGY))
end

local function getCommanderBuildQueue(commanderID)
	local spawnQueue = {}
	local comData = commanders[commanderID]
	local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
	local juiceCost = 0
	for i, cmd in ipairs(commands) do
		if isBuildCommand(cmd.id) then --is a build command
		local spawnParams = {id = -cmd.id, x = cmd.params[1], y = cmd.params[2], z = cmd.params[3], facing = cmd.params[4] or 1}
			if  math.distance2d(comData.spawnX, comData.spawnZ, spawnParams.x, spawnParams.z) <= INSTANT_BUILD_RANGE then
				table.insert(spawnQueue, spawnParams)
				local juiceCost = juiceCost + defJuices[cmd.id] --zzz we gonna factor the discount in factories with an isFactory check in this calculation, and only update the usage of the discount if the build is actually successful.
				if juiceCost > comData.juice then
					return spawnQueue
				end
			end
		end
	end
	return spawnQueue
end

local function getBuildSpace(commanderID, option, noGoZones, testDistance)
	local noGoZones = noGoZones or {}
	local testSuccesses = 0
	local optionType = optionsToNodeType[option]
	local plotData = commanders[commanderID].buildPlots[optionType]
	local buildDefID = commanders[commanderID].buildDefs[option]
	local originX, originZ, indexX, indexZ = plotData.originX, plotData.originZ, plotData.indexX, plotData.indexZ
	local skipDirection = plotData.skipDirection
	local maxOffset = math.max(math.abs(indexX), math.abs(indexZ)) * BUILD_SPACING

	local spotsWithDistance = {}
	if not isMetalMap and option == "mex" then
		for i = 1, #metalSpotsList do
				local metalSpot = metalSpotsList[i]
				local distance = math.distance2d(metalSpot.x, metalSpot.z, originX, originZ)
				if distance <= AUTO_MEX_MAX_DISTANCE then
					table.insert(spotsWithDistance, {x = metalSpot.x, z = metalSpot.z, distance = distance})
				end
			end
			if spotsWithDistance[1] then
				table.sort(spotsWithDistance, function(a, b) return a.distance < b.distance end)
				return spotsWithDistance[1].x, spotsWithDistance[1].z
			else
				return nil, nil
			end
		elseif option == "mex" then
		
	end
	
	for offsetX = -maxOffset, maxOffset, BUILD_SPACING do
		local absOffsetX = math.abs(offsetX)
		if absOffsetX > MAX_SPACE_DISTANCE or (testDistance and absOffsetX > testDistance) then
			break
		end
			for offsetZ = -maxOffset, maxOffset, BUILD_SPACING do
				if not (offsetX < indexX or (offsetX == indexX and offsetZ < indexZ)) then
				local shouldSkip = false
				if skipDirection == "x" then
					local columnIndex = (offsetZ + maxOffset) / BUILD_SPACING
					shouldSkip = (columnIndex % SKIP_STEP) == 0
				elseif skipDirection == "z" then
					local rowIndex = (offsetX + maxOffset) / BUILD_SPACING
					shouldSkip = (rowIndex % SKIP_STEP) == 0
				end
				
				if not shouldSkip then
					local testX = originX + offsetX
					local testZ = originZ + offsetZ
					
					local tooCloseToNoGo = false
					for _, noGoZone in ipairs(noGoZones) do
						local distance = math.distance2d(testX, testZ, noGoZone.x, noGoZone.z)
						if distance <= TEST_NOGO_DISTANCE then
							tooCloseToNoGo = true
							break
						end
					end
					
					if not tooCloseToNoGo then
						local searchY = spGetGroundHeight(testX, testZ)
						local snappedX, snappedY, snappedZ = spPos2BuildPos(buildDefID, testX, searchY, testZ)
						local validPlot = snappedX and spTestBuildOrder(buildDefID, snappedX, snappedY, snappedZ, 0) > 0
						if validPlot then
							if testDistance then
								testSuccesses = testSuccesses + 1
							else
								plotData.indexX = offsetX
								plotData.indexZ = offsetZ
								return snappedX, snappedZ
							end
						end
					end
				end
			end
		end
	end

	if testDistance then
		return testSuccesses, nil
	end
	return nil, nil
end

local function generateBaseNodes(commanderID)
	local baseNodes = {}
	local comData = commanders[commanderID]
	local spawnX, spawnZ = comData.spawnX, comData.spawnZ
	local radialDistance = INSTANT_BUILD_RANGE / 2
	
	local angleIncrement = 2 * math.pi / 8
	for i = 0, 7 do
		local angle = i * angleIncrement
		local nodeX = spawnX + radialDistance * math.cos(angle)
		local nodeZ = spawnZ + radialDistance * math.sin(angle)
		
		baseNodes[i + 1] = {
			x = nodeX,
			z = nodeZ,
			isBad = false,
			distanceWeight = 0,
			score = 0
		}
	end
	
	local maxDistance = 0
	local minDistance = math.huge
	local goodNodes = {}
	
	for i, node in ipairs(baseNodes) do
		local testResult = getBuildSpace(commanderID, "factory", {}, BUILD_SPACING)
		if testResult < 8 then
			node.isBad = true
		else
			local distanceToCenter = math.distance2d(node.x, node.z, MAP_CENTER_X, MAP_CENTER_Z)
			node.distanceToCenter = distanceToCenter
			maxDistance = math.max(maxDistance, distanceToCenter)
			minDistance = math.min(minDistance, distanceToCenter)
			table.insert(goodNodes, node)
		end
	end
	
	if #goodNodes < 2 then
		return
	end
	
	local highestWeight = 0
	local factoryNodeIndex = 0
	
	for i, node in ipairs(goodNodes) do
		node.distanceWeight = 1 - (0.25 * (node.distanceToCenter - minDistance) / (maxDistance - minDistance))
		
		if node.distanceWeight > highestWeight then
			highestWeight = node.distanceWeight
			factoryNodeIndex = i
		end
		
		local testResult = getBuildSpace(commanderID, "factory", {}, MAX_SPACE_DISTANCE)
		node.score = testResult * node.distanceWeight
	end
	
	local factoryNode = nil
	if factoryNodeIndex > 0 then
		factoryNode = goodNodes[factoryNodeIndex]
		table.remove(goodNodes, factoryNodeIndex)
	end
	
	local bestPair = nil
	local bestPairScore = 0
	for i = 1, #goodNodes - 1 do
		for j = i + 1, #goodNodes do
			local node1 = goodNodes[i]
			local node2 = goodNodes[j]
			local pairScore = node1.score + node2.score
			if pairScore > bestPairScore then
				bestPairScore = pairScore
				bestPair = {node1, node2}
			end
		end
	end

	if not bestPair or not factoryNode then return end

	local result = { factory = factoryNode }
	if bestPair[1].score > bestPair[2].score then
		result.other = bestPair[1]
		result.converters = bestPair[2]
	else
		result.other = bestPair[2]
		result.converters = bestPair[1]
	end
	return result
end

local function filterOverlappingMexes() --zzz untested
	local mexesToRemove = {}
	
	for mexKey1, mexData1 in pairs(mexOverlapCheckTable) do
		local commanderID1, x1, z1 = mexData1[1], mexData1[2], mexData1[3]
		local comData1 = commanders[commanderID1]
		local distanceToCommander1 = math.distance2d(x1, z1, comData1.spawnX, comData1.spawnZ)
		
		for mexKey2, mexData2 in pairs(mexOverlapCheckTable) do
			if mexKey1 ~= mexKey2 then
				local x2, z2 = mexData2[2], mexData2[3]
				local distanceBetweenMexes = math.distance2d(x1, z1, x2, z2)
				
				if distanceBetweenMexes <= 32 then
					local commanderID2 = mexData2[1]
					local comData2 = commanders[commanderID2]
					local distanceToCommander2 = math.distance2d(x2, z2, comData2.spawnX, comData2.spawnZ)
					
					if distanceToCommander1 < distanceToCommander2 then
						mexesToRemove[mexKey1] = true
					else
						mexesToRemove[mexKey2] = true
					end
				end
			end
		end
	end
	
	for mexKey, _ in pairs(mexesToRemove) do
		mexOverlapCheckTable[mexKey] = nil
	end
end

local function addFactoryBuild(commanderID)
	local comData = commanders[commanderID]
	local commanderName = comData.commanderName
	local availableOptions = commanderAllLabs[commanderName]
	local selectedFactory = "armlab"
	
	if availableOptions then
		local totalWeight = 0
		local weightedOptions = {}
		
		for labName, weight in pairs(availableOptions) do
			totalWeight = totalWeight + weight
			table.insert(weightedOptions, {name = labName, weight = weight})
		end
		
		if totalWeight > 0 then
			local randomValue = math.random() * totalWeight
			local currentWeight = 0
			
			for _, option in ipairs(weightedOptions) do
				currentWeight = currentWeight + option.weight
				if randomValue <= currentWeight then
					selectedFactory = option.name
					break
				end
			end
		end
	end

	local buildX, buildZ = getBuildSpace(commanderID, "factory", {{comData.spawnX, comData.spawnZ}}, nil)
	if not buildX then return end
	table.insert(comData.spawnQueue, 1, {id = unitDefNames[selectedFactory].id, x = buildX, z = buildZ, facing = comData.defaultFacing or 0})
end

	local function generateBuildCommands(commanderID)
	local comData = commanders[commanderID]
	local totalJuice = 0
	local tryCount = 0
	while comData.juice > totalJuice and tryCount < 50 do

		local selectedOption = nil
		local weightedOptions = {}
		local totalWeight = 0
		
		for optionName, quota in pairs(comData.buildQuotas) do
			local currentCount = comData.thingsMade[optionName] or 0
			local remainingQuota = quota - currentCount
			
			if remainingQuota > 0 then
				table.insert(weightedOptions, {name = optionName, weight = remainingQuota})
				totalWeight = totalWeight + remainingQuota
			end
		end
		
		if totalWeight > 0 then
			local randomValue = math.random() * totalWeight
			local currentWeight = 0
			
			for _, option in ipairs(weightedOptions) do
				currentWeight = currentWeight + option.weight
				if randomValue <= currentWeight then
					selectedOption = option.name
					break
				end
			end
		end
		
		local nogoZones = {}
		table.insert(nogoZones, {comData.spawnX, comData.spawnZ})
		if comData.baseNodes.factory then
			table.insert(nogoZones, {comData.baseNodes.factory.x, comData.baseNodes.factory.z})
		end
		tryCount = tryCount + 1
		if selectedOption then
			local buildX, buildZ = getBuildSpace(commanderID, selectedOption, {{comData.spawnX, comData.spawnZ}, }, nil)
			if not buildX then
				comData.buildQuotas[selectedOption] = 0
				return
			else
				table.insert(comData.spawnQueue, 1, {id = comData.buildDefs[selectedOption], x = buildX, z = buildZ, facing = comData.defaultFacing or 0})
			end
		end
	end
end

local function tryToSpawnBuild(commanderID, buildDefID, buildX, buildZ, facing)
	local unitDef, comData, buildProgress = unitDefs[buildDefID], commanders[commanderID], 0
	local discount = factoryRequired and not comData.factoryMade and FACTORY_DISCOUNT or 0
	local juiceCost = defJuices[buildDefID] - discount
	if juiceCost > comData.juice then return false, nil end

	local unitID = spCreateUnit(unitDef.name, buildX, spGetGroundHeight(buildX, buildZ), buildZ, facing, comData.teamID)
	if not unitID then
		return false, nil
	end

	local affordableJuice = math.min(comData.juice, juiceCost)
	buildProgress = affordableJuice / juiceCost
	Spring.SetUnitHealth(unitID, {build = buildProgress, health = math.ceil(unitDef.health * buildProgress)})
	comData.juice = comData.juice - affordableJuice
	
	if unitDef.isFactory then
		Spring.SetTeamRulesParam(comData.teamID, TEAM_RULES_FACTORY_PLACED_KEY, 1)
		comData.thingsMade.factory = comData.thingsMade.factory + 1
	else
		local optionName = optionDefIDToTypes[buildDefID]
		if optionName then
			comData.thingsMade[optionName] = (comData.thingsMade[optionName] or 0) + 1
		end
	end
	
	spSpawnCEG("quickstart-spawn-pulse-large", buildX, buildY + 10, buildZ)
	if buildProgress < 1 then
		Spring.GiveOrderToUnit(commanderID, CMD.INSERT, {0, CMD.REPAIR, CMD.OPT_SHIFT, unitID}, CMD.OPT_ALT)
	end
	
	return buildProgress >= 1
end

function gadget:GameFrame(frame)
	if not initialized and frame > PREGAME_DELAY_FRAMES then
		initialized = true
		running = true
		for commanderID, teamID in pairs(queuedCommanders) do
			initializeCommander(commanderID, teamID)
		end
		queuedCommanders = nil
		for commanderID, comData in pairs(commanders) do
			comData.spawnX, comData.spawnY, comData.spawnZ = spGetUnitPosition(commanderID)
			comData.spawnQueue = getCommanderBuildQueue(commanderID) --returns list of build order items. Must be scrubbed of things out of range.
			for i, build in ipairs(comData.spawnQueue) do
				if math.distance2d(build.x, build.z, comData.spawnX, comData.spawnZ) > INSTANT_BUILD_RANGE then
					table.remove(comData.spawnQueue, i)
				elseif mexDefs[build.id] then
					mexOverlapCheckTable[getBuildInstanceID(build.id, build.x, build.z)] = {commanderID, build.x, build.z}
				end
			end
			comData.baseNodes = generateBaseNodes(commanderID)
		end
		filterOverlappingMexes()
	end

	while running do
		local allQueuesEmpty = true
		for commanderID, comData in pairs (commanders) do
			for i, build in ipairs(comData.spawnQueue) do
				local fullyBuilt = tryToSpawnBuild(commanderID, build.id, build.x, build.z, build.facing)
				if fullyBuilt then
					table.remove(comData.spawnQueue, 1)
				end
			end
			if comData.juice > 0 then
				if not comData.isHuman and not comData.factoryBuilt then
					addFactoryBuild(commanderID)
				end
				generateBuildCommands(commanderID)
			end
			if #comData.spawnQueue > 0 then
				allQueuesEmpty = false
			end
		end
		if allQueuesEmpty then
			running = false
		end
	end

	local allDiscountsUsed = true
	if frame % UPDATE_FRAMES == 0 then
		for teamID, used in pairs(factoryDiscounts) do
			if not used then
				allDiscountsUsed = false
				break
			end
		end
	end
	if initialized and allDiscountsUsed and not running then
		gadgetHandler:RemoveGadget()
	end
end

function gadget:UnitDestroyed(unitID)
	commanders[unitID] = nil
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if boostableCommanders[unitDefID] then
		queuedCommanders[unitID] = unitTeam
	end
	if factoryRequired and not factoryDiscounts[unitTeam] and unitDefs[unitDefID].isFactory and commanders[builderID] then
		factoryDiscounts[unitTeam] = true
		Spring.SetTeamRulesParam(unitTeam, TEAM_RULES_FACTORY_PLACED_KEY, 1)
		
		local unitDef = unitDefs[unitDefID]
		local fullJuiceCost = defJuices[unitDefID]
		local buildProgress = FACTORY_DISCOUNT / fullJuiceCost

		Spring.SetUnitHealth(unitID, {build = buildProgress, health = math.ceil(unitDef.health * buildProgress)})
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
	
	local frame = Spring.GetGameFrame()

	-- publish juice base immediately for UI to consume
	local immediateJuice = QUICK_START_COST_METAL + BONUS_METAL + (QUICK_START_COST_ENERGY + BONUS_ENERGY) / ENERGY_VALUE_CONVERSION_DIVISOR
	Spring.SetGameRulesParam(GAME_RULES_BASE_KEY, immediateJuice)

	if frame > 1 then
		local allUnits = Spring.GetAllUnits()
		for _, unitID in ipairs(allUnits) do
			local unitDefinitionID = Spring.GetUnitDefID(unitID)
			local unitTeam = Spring.GetUnitTeam(unitID)
			if boostableCommanders[unitDefinitionID] then
				initializeCommander(unitID, unitTeam)
			end
		end
	end
end