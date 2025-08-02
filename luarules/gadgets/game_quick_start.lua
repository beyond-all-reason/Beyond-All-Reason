function gadget:GetInfo()
	return {
		name = "Quick Start",
		desc = "Pixies spawn around commanders to instantly build structures until starting resources are expended",
		author = "SethDGamre", 
		date = "July 2025",
		license = "GPLv2",
		layer = 0,
		enabled = true
	}
end


--[[
todo:
commander radar range should be read dynamically from the unitdef and made the range of the pixies steal range

something about the way I detect and remove commands from the commander's command queue causes pre-queued commands to fail.
]]

local isSynced = gadgetHandler:IsSyncedCode()
local modOptions = Spring.GetModOptions()
if not isSynced then return false end

local shouldRunGadget = modOptions.quick_start == "enabled" or
	(modOptions.quick_start == "default" and (modOptions.temp_enable_territorial_domination or modOptions.deathmode == "territorial_domination"))

if not shouldRunGadget then return false end

-- Spring API shortcuts
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

local gaiaTeamID = Spring.GetGaiaTeamID()

-- Constants
local RESOURCES_RATIO_TO_BE_CLAIMED_BY_PIXIES = 0.95
local ENERGY_VALUE_CONVERSION_DIVISOR = 10
local PIXIE_METAL_COST = 50
local PIXIE_ENERGY_COST = 500
local PIXIE_COMBO_COST = PIXIE_METAL_COST + PIXIE_ENERGY_COST/ENERGY_VALUE_CONVERSION_DIVISOR
local COMMAND_STEAL_RANGE = 700 --same as com's radardistance
local PIXIE_ORBIT_RADIUS = 150
local PIXIE_HOVER_HEIGHT = 50
local FALLBACK_RESOURCES = 1000
local ALL_COMMANDS = -1
local UPDATE_FRAMES = 15
local PREGAME_DELAY_FRAMES = 150
local PIXIE_UNIT_NAME = "armassistdrone"
local PI = math.pi
local PRIVATE = { private = true }

local STATES = {
	EMPTY = 0,
	ORBITING = 1,
	BUILDING = 2,
	GUARDING = 3,
}

-- Helper function to calculate unit cost using the same formula
local function calculateUnitCost(unitDef)
	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	return metalCost + energyCost / 60
end

-- Data structures
local teamsToBoost = {}
local commanderMetaList = {}
local pixieMetaList = {}
local nonPlayerTeams = {}
local boostableCommanders = {}
local unitCosts = {}
local pixieBuildClusters = {} -- zzz when we assign a builder pixie to start a structure, we iterate over its stored guardians and make sure they're all nanolathing. If they are, then we can trigger instabuild.
local queuePixieCreation = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.iscommander then
		boostableCommanders[unitDefID] = true
	end
	unitCosts[unitDefID] = calculateUnitCost(unitDef)
end

local function getUnitCosts(buildingUnitID)
	local originalCost = unitCosts[spGetUnitDefID(buildingUnitID)]
	local currentBuildProgress = select(4, spGetUnitHealth(buildingUnitID))
	return originalCost,  originalCost - (originalCost * currentBuildProgress)
end

local function getRandomMoveLocation(centerX, centerZ, maxDistance)
	local angle = mathRandom() * 2 * PI
	local distance = mathRandom() * maxDistance
	local offsetX = mathCos(angle) * distance
	local offsetZ = mathSin(angle) * distance
	return centerX + offsetX, centerZ + offsetZ
end

local function createPixiesForCommander(commanderID, teamID, startingMetal, startingEnergy)
	local convertedEnergy = startingEnergy / ENERGY_VALUE_CONVERSION_DIVISOR
	local convertedMetal = startingMetal
	local totalCombinedResources = convertedMetal + convertedEnergy * RESOURCES_RATIO_TO_BE_CLAIMED_BY_PIXIES
	local totalPixies = math.floor(totalCombinedResources / PIXIE_COMBO_COST)
	
	if totalPixies <= 0 or not Spring.ValidUnitID(commanderID) or Spring.GetUnitIsDead(commanderID) then
		return
	end
	
	local currentMetal = spGetTeamResources(teamID, "metal")
	local currentEnergy = spGetTeamResources(teamID, "energy")
	Spring.SetTeamResource(teamID, "metal", math.max(0, currentMetal - convertedMetal))
	Spring.SetTeamResource(teamID, "energy", math.max(0, currentEnergy - convertedEnergy))


	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	commanderMetaList[commanderID] = {
		teamID = teamID,
		pixieList = {},
		lastCommandCheck = 0,
		currentBuildCommand = nil
	}
	
	for i = 1, totalPixies do
		local pixieY = spGetGroundHeight(commanderX, commanderZ) + PIXIE_HOVER_HEIGHT
		
		local pixieID = spCreateUnit(PIXIE_UNIT_NAME, commanderX, pixieY, commanderZ, 0, teamID)
		if pixieID then
			spSetUnitNoSelect(pixieID, true)
			spSetUnitRulesParam(pixieID, "is_pixie", 1, PRIVATE)
			spSetUnitRulesParam(pixieID, "pixie_commander_id", commanderID, PRIVATE)
			
			pixieMetaList[pixieID] = {
				commanderID = commanderID,
				value = PIXIE_COMBO_COST,
				state = STATES.ORBITING,
				stateData = {},
			}
			
			commanderMetaList[commanderID].pixieList[pixieID] = true
			
			local moveX, moveZ = getRandomMoveLocation(commanderX, commanderZ, PIXIE_ORBIT_RADIUS)
			spGiveOrderToUnit(pixieID, CMD.MOVE, {moveX, pixieY, moveZ}, 0)
		end
	end
end

local function assignBuildCommand(pixieID, cmd)
	local buildX, buildY, buildZ = cmd.params[1], cmd.params[2], cmd.params[3]
	local unitDefID = cmd.id
	
	spGiveOrderToUnit(pixieID, unitDefID, {buildX, buildY, buildZ}, {})
end

local function assignPixiesToBuild(commanderID, cmd)
	local buildDefID = -cmd.id
	local buildCostRemaining = unitCosts[buildDefID]
	if not buildCostRemaining then
		return false
	end
	
	local pixies = commanderMetaList[commanderID].pixieList
	local buildX, buildY, buildZ = cmd.params[1], cmd.params[2], cmd.params[3]
	
	local pixieDistances = {}
	for pixieID, _ in pairs(pixies) do
		local pixieData = pixieMetaList[pixieID]
		if pixieData.state == STATES.ORBITING then
			local pixieX, pixieY, pixieZ = spGetUnitPosition(pixieID)
			local distance = mathDiag(pixieX - buildX, pixieZ - buildZ)
			table.insert(pixieDistances, {pixieID = pixieID, distance = distance})
		end
	end
	
	table.sort(pixieDistances, function(a, b) return a.distance < b.distance end)
	
	local chosenBuilderID = nil
	for _, pixieInfo in ipairs(pixieDistances) do
		local pixieID = pixieInfo.pixieID
		local pixieData = pixieMetaList[pixieID]
		
		if not chosenBuilderID then
			chosenBuilderID = pixieID
			if not pixieBuildClusters[commanderID] then
				pixieBuildClusters[commanderID] = {}
			end
			pixieBuildClusters[commanderID][chosenBuilderID] = {}
			assignBuildCommand(pixieID, cmd)
			pixieData.state = STATES.BUILDING
		else
			pixieBuildClusters[commanderID][chosenBuilderID][pixieID] = true
			pixieData.state = STATES.GUARDING
			pixieData.stateData = {builderID = chosenBuilderID}
			spGiveOrderToUnit(pixieID, CMD.GUARD, {chosenBuilderID}, 0)
		end

		buildCostRemaining = buildCostRemaining - pixieData.value
		if buildCostRemaining <= 0 then
			break
		end
	end

	if buildCostRemaining <= 0 then
		return true
	end
	return false
end

local function depletePixies(pixies)
	if #pixies > 0 then
		-- Array-style table, use ipairs
		for i, pixieID in ipairs(pixies) do
			if spValidUnitID(pixieID) and not spGetUnitIsDead(pixieID) then
				Spring.AddUnitDamage(pixieID, select(1, spGetUnitHealth(pixieID)), 0, gaiaTeamID, 0)
			end
		end
	else
		-- Hash-style table, use pairs
		for pixieID, _ in pairs(pixies) do
			if spValidUnitID(pixieID) and not spGetUnitIsDead(pixieID) then
				Spring.AddUnitDamage(pixieID, select(1, spGetUnitHealth(pixieID)), 0, gaiaTeamID, 0)
			end
		end
	end
end

local function applyPixieBoostToBuilding(buildingUnitID, pixies)
	local originalCost, remainingCost = getUnitCosts(buildingUnitID)
	local buildProgress = 0
	local healthToApply = 0
	for _, pixieID in ipairs(pixies) do
		local pixieData = pixieMetaList[pixieID]
		if pixieData then
			remainingCost = remainingCost - pixieData.value
			if remainingCost == 0 then
				pixieData.value = 0
				break
			elseif remainingCost < 0 then
				pixieData.value = pixieData.value + remainingCost
				remainingCost = 0
				break
			else
				pixieData.value = 0
			end
		end
	end
	local maxHealth = UnitDefs[spGetUnitDefID(buildingUnitID)].health
	if remainingCost > 0 then
		buildProgress = 1 - remainingCost / originalCost
		healthToApply = math.ceil(maxHealth * buildProgress)
	else
		buildProgress = 1
		healthToApply = maxHealth
	end

	local buildingX, buildingY, buildingZ = spGetUnitPosition(buildingUnitID)
	Spring.SpawnCEG("quickstart-spawn-pulse-large", buildingX, buildingY + 10, buildingZ)

	for _, pixieID in ipairs(pixies) do
		local pixieX, pixieY, pixieZ = spGetUnitPosition(pixieID)
		Spring.SpawnCEG("botrailspawn", pixieX, pixieY - 20, pixieZ)
	end

	spSetUnitHealth(buildingUnitID, {build = buildProgress, health = healthToApply})
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

local function erasePixieBuildCluster(commanderID, builderPixieID)
	-- Reset guarding pixies back to orbiting
	for pixieID, _ in pairs(pixieBuildClusters[commanderID][builderPixieID]) do
		local pixieData = pixieMetaList[pixieID]
		if pixieData then
			pixieData.state = STATES.ORBITING
		end
	end
	
	-- Reset builder pixie back to orbiting
	local builderPixieData = pixieMetaList[builderPixieID]
	if builderPixieData then
		builderPixieData.state = STATES.ORBITING
	end
	
	if pixieBuildClusters[commanderID] and pixieBuildClusters[commanderID][builderPixieID] then
		pixieBuildClusters[commanderID][builderPixieID] = nil
	end
end

local function arePixiesAllGone()
	local pixieCount = 0
	for commanderID, data in pairs(commanderMetaList) do
		for pixieID, _ in pairs(data.pixieList) do
			if pixieMetaList[pixieID] and not Spring.GetUnitIsDead(pixieID) and Spring.ValidUnitID(pixieID) then
				pixieCount = pixieCount + 1
			end
		end
	end
	
	return pixieCount == 0
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if boostableCommanders[unitDefID] then
		teamsToBoost[unitTeam] = true
		queuePixieCreation[unitID] = unitTeam
	end
end

local initialized = false
function gadget:GameFrame(frame)
	if not initialized and frame > PREGAME_DELAY_FRAMES then
		for unitID, teamID in pairs(queuePixieCreation) do
			createPixiesForCommander(unitID, teamID, modOptions.startmetal or FALLBACK_RESOURCES, modOptions.startenergy or FALLBACK_RESOURCES)
		end
		queuePixieCreation = {}
		initialized = true
	end
	if frame % UPDATE_FRAMES ~= 0 then return end
	-- if pixies currently have move command, switch back to orbiting
	for pixieID, pixieData in pairs(pixieMetaList) do
		if pixieID and spValidUnitID(pixieID) and not spGetUnitIsDead(pixieID) then
			if pixieData.state ~= STATES.ORBITING then
				local cmdID = Spring.GetUnitCurrentCommand(pixieID)
				if not cmdID or cmdID and cmdID == CMD.MOVE then -- second command is always move for error detection
					pixieData.state = STATES.ORBITING
				end
			end
		end
	end

	--move idle pixies around the commander
	for pixieID, pixieData in pairs(pixieMetaList) do
		if pixieID and spValidUnitID(pixieID) and not spGetUnitIsDead(pixieID) and pixieData.state == STATES.ORBITING then
			local commanderX, commanderY, commanderZ = spGetUnitPosition(pixieData.commanderID)
			if commanderX then
				local moveX, moveZ = getRandomMoveLocation(commanderX, commanderZ, PIXIE_ORBIT_RADIUS)
				local moveY = spGetGroundHeight(moveX, moveZ)
				spGiveOrderToUnit(pixieID, CMD.MOVE, {moveX, moveY, moveZ}, 0)
			end
		end
	end

	-- Update all active commanders and their pixies
	for commanderID, commanderData in pairs(commanderMetaList) do
		if teamsToBoost[commanderData.teamID] then
			--check and assign build commands for pixies
			local commands = spGetUnitCommands(commanderID, ALL_COMMANDS)
			if next(commands) then
				for _, cmd in ipairs(commands) do
					local pixiesCanBuildCompletely = false
					local buildsiteX, buildsiteZ = cmd.params[1], cmd.params[3]
					if isBuildCommand(cmd.id) and isCommanderInRange(commanderID, buildsiteX, buildsiteZ) then
						pixiesCanBuildCompletely = assignPixiesToBuild(commanderID, cmd)
					end
					if pixiesCanBuildCompletely then
						spGiveOrderToUnit(commanderID, CMD.REMOVE, {cmd.tag}, 0)
					end
				end
			end

			--check if any pixies currently are nanolathing (for synced instabuild effects)
			local buildClusters = pixieBuildClusters[commanderID]
			if buildClusters then
				for builderPixieID, guardingPixies in pairs(buildClusters) do
					local eraseCluster = false
					local builderPixieCMD = spGetUnitCurrentCommand(builderPixieID)
					if not builderPixieCMD or 
					builderPixieCMD and not isBuildCommand(builderPixieCMD) and not spGetUnitIsDead(builderPixieID) and spValidUnitID(builderPixieID) then
						eraseCluster = true
					else
						local allReady = true
						local buildingUnitID = nil
						local allPixies = {builderPixieID}
						for guardingPixieID, _ in pairs(guardingPixies) do
							table.insert(allPixies, guardingPixieID)
							eraseCluster = spGetUnitIsDead(guardingPixieID) or not spValidUnitID(guardingPixieID)
							allReady = allReady and Spring.GetUnitIsBuilding(guardingPixieID) ~= nil --returns number if true
						end
						buildingUnitID = Spring.GetUnitIsBuilding(builderPixieID)
						allReady = allReady and buildingUnitID ~= nil
						if allReady and buildingUnitID then
							applyPixieBoostToBuilding(buildingUnitID, allPixies)
							-- Clean up cluster metadata BEFORE destroying units to prevent double cleanup
							erasePixieBuildCluster(commanderID, builderPixieID)
						elseif eraseCluster then
							erasePixieBuildCluster(commanderID, builderPixieID) -- not enough pixies to build, probably died or construction cancelled.
						end
					end
				end
			end
		end
	end

	--deplete pixies that have no value left - collect first to avoid concurrent modification
	local pixiesToDeplete = {}
	for pixieID, pixieData in pairs(pixieMetaList) do
		if pixieData.value <= 0 then
			table.insert(pixiesToDeplete, pixieID)
		end
	end
	
	if #pixiesToDeplete > 0 then
		depletePixies(pixiesToDeplete)
	end

	local removeGadget = arePixiesAllGone() and initialized
	if removeGadget then
		gadgetHandler:RemoveGadget()
	end
end

function gadget:UnitDestroyed(unitID)

	if commanderMetaList[unitID] then --commander died
		local pixies = commanderMetaList[unitID].pixieList
		for pixieID, _ in pairs(pixies) do
			pixieMetaList[pixieID] = nil
		end
		depletePixies(pixies)
		commanderMetaList[unitID] = nil
	elseif pixieMetaList[unitID] then --pixie died
		local pixieData = pixieMetaList[unitID]
		local commanderID = pixieData.commanderID
		if commanderMetaList[commanderID] then
			commanderMetaList[commanderID].pixieList[unitID] = nil
		end
		if pixieData.state == STATES.BUILDING then
			erasePixieBuildCluster(commanderID, unitID)
		elseif pixieData.stateData and pixieData.stateData.builderID then
			local builderID = pixieData.stateData.builderID
			if pixieBuildClusters[commanderID] and pixieBuildClusters[commanderID][builderID] then
				pixieBuildClusters[commanderID][builderID][unitID] = nil
			end
		end
		pixieMetaList[unitID] = nil
	end
end

function gadget:Initialize()
	if Spring.GetGameFrame() > 1 then
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
				createPixiesForCommander(unitID, unitTeam, modOptions.startmetal or FALLBACK_RESOURCES, modOptions.startenergy or FALLBACK_RESOURCES)
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
	-- Clean up all pixies
	for pixieID, _ in pairs(pixieMetaList) do
		spDestroyUnit(pixieID, false, true)
	end
end