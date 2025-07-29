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
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetGroundHeight = Spring.GetGroundHeight
local spSetUnitCosts = Spring.SetUnitCosts
local mathDiag = math.diag
local mathRandom = math.random
local mathCos = math.cos
local mathSin = math.sin

-- Constants
local PIXIE_METAL_VALUE = 50
local PIXIE_ENERGY_VALUE = 500
local COMMAND_STEAL_RANGE = 750
local PIXIE_ORBIT_RADIUS = 150
local PIXIE_HOVER_HEIGHT = 50
local UPDATE_FRAMES = 15
local PIXIE_UNIT_NAME = "corassistdrone"
local PI = math.pi
local PRIVATE = { private = true }

-- Data structures
local teamsToBoost = {}
local teamPixieCount = {}
local commanderMetaList = {}
local pixieMetaList = {}
local nonPlayerTeams = {}

local function isBoostableCommander(unitDefinitionID)
	local unitDefinition = UnitDefs[unitDefinitionID]
	return unitDefinition and unitDefinition.customParams and unitDefinition.customParams.iscommander == "1"
end

local function createPixiesForCommander(commanderID, teamID, metalResources, energyResources)
	local metalPixies = math.floor(metalResources / PIXIE_METAL_VALUE)
	local energyPixies = math.floor(energyResources / (PIXIE_ENERGY_VALUE / 10)) -- Cost 1/10th energy to buy pixie
	local totalPixies = math.min(metalPixies, energyPixies)
	
	if totalPixies <= 0 then
		return
	end
	
	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	if not commanderX then
		return
	end
	
	teamPixieCount[teamID] = totalPixies
	commanderMetaList[commanderID] = {
		teamID = teamID,
		pixieList = {},
		lastCommandCheck = 0,
		currentBuildCommand = nil
	}
	
	-- Create pixies in orbit around commander
	Spring.Echo("DEBUG: Creating " .. totalPixies .. " pixies for commander " .. commanderID .. " on team " .. teamID)
	for i = 1, totalPixies do
		local angle = (i / totalPixies) * 2 * PI
		local offsetX = mathCos(angle) * PIXIE_ORBIT_RADIUS
		local offsetZ = mathSin(angle) * PIXIE_ORBIT_RADIUS
		local pixieX = commanderX + offsetX
		local pixieY = spGetGroundHeight(pixieX, commanderZ + offsetZ) + PIXIE_HOVER_HEIGHT
		local pixieZ = commanderZ + offsetZ
		
		local pixieID = spCreateUnit(PIXIE_UNIT_NAME, pixieX, pixieY, pixieZ, 0, teamID)
		if pixieID then
			Spring.Echo("DEBUG: Created pixie " .. pixieID)
			spSetUnitNoSelect(pixieID, true)
			spSetUnitRulesParam(pixieID, "is_pixie", 1, PRIVATE)
			spSetUnitRulesParam(pixieID, "commander_id", commanderID, PRIVATE)
			spSetUnitHealth(pixieID, {health = 1, maxHealth = 1})
			
			-- Make pixie die in one hit
			local pixieDefID = spGetUnitDefID(pixieID)
			local pixieDef = UnitDefs[pixieDefID]
			if pixieDef then
				spSetUnitCosts(pixieID, {
					buildTime = 1,
					energyCost = 1,
					metalCost = 1
				})
			end
			
			pixieMetaList[pixieID] = {
				commanderID = commanderID,
				metalValue = PIXIE_METAL_VALUE,
				energyValue = PIXIE_ENERGY_VALUE,
				state = "orbiting", -- orbiting, moving, building
				targetCommand = nil,
				orbitAngle = angle,
				buildTarget = nil
			}
			
			commanderMetaList[commanderID].pixieList[pixieID] = true
			
			-- Give initial orbit command
			spGiveOrderToUnit(pixieID, CMD.MOVE, {pixieX, pixieY, pixieZ}, 0)
		end
	end
end

local function getAvailablePixiesForCommand(commanderID, metalCost, energyCost)
	if not commanderMetaList[commanderID] then
		return {}
	end
	
	local availablePixies = {}
	local totalMetal = 0
	local totalEnergy = 0
	
	for pixieID, _ in pairs(commanderMetaList[commanderID].pixieList) do
		if pixieMetaList[pixieID] and pixieMetaList[pixieID].state == "orbiting" then
			totalMetal = totalMetal + pixieMetaList[pixieID].metalValue
			totalEnergy = totalEnergy + pixieMetaList[pixieID].energyValue
			availablePixies[#availablePixies + 1] = pixieID
			
			if totalMetal >= metalCost and totalEnergy >= energyCost then
				break
			end
		end
	end
	
	if totalMetal >= metalCost and totalEnergy >= energyCost then
		return availablePixies
	else
		return {}
	end
end

local function assignPixiesToBuild(commanderID, buildCommand, targetX, targetY, targetZ, unitDefName, cmdTag)
	local unitDef = UnitDefNames[unitDefName]
	if not unitDef then
		Spring.Echo("DEBUG: Unit def not found for: " .. (unitDefName or "nil"))
		return false
	end
	
	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	
	Spring.Echo("DEBUG: Trying to build " .. unitDefName .. " - Cost: " .. metalCost .. "m, " .. energyCost .. "e")
	
	local availablePixies = getAvailablePixiesForCommand(commanderID, metalCost, energyCost)
	if #availablePixies == 0 then
		Spring.Echo("DEBUG: No available pixies for build command")
		return false
	end
	
	Spring.Echo("DEBUG: Assigning " .. #availablePixies .. " pixies to build " .. unitDefName)
	
	-- Remove the build command using its tag
	if cmdTag then
		spGiveOrderToUnit(commanderID, CMD.REMOVE, {cmdTag}, 0)
		Spring.Echo("DEBUG: Removed build command with tag: " .. cmdTag)
	else
		Spring.Echo("DEBUG: Warning: No command tag provided for removal")
	end
	
	-- Assign pixies to build
	local remainingMetal = metalCost
	local remainingEnergy = energyCost
	local assignedPixies = {}
	
	for _, pixieID in ipairs(availablePixies) do
		if remainingMetal <= 0 and remainingEnergy <= 0 then
			break
		end
		
		local pixie = pixieMetaList[pixieID]
		if pixie then
			local metalUsed = math.min(pixie.metalValue, remainingMetal)
			local energyUsed = math.min(pixie.energyValue, remainingEnergy)
			
			pixie.state = "moving"
			pixie.targetCommand = buildCommand
			pixie.buildTarget = {
				x = targetX,
				y = targetY,
				z = targetZ,
				unitDefName = unitDefName,
				metalCost = metalUsed,
				energyCost = energyUsed
			}
			
			-- Update pixie resources
			pixie.metalValue = pixie.metalValue - metalUsed
			pixie.energyValue = pixie.energyValue - energyUsed
			
			remainingMetal = remainingMetal - metalUsed
			remainingEnergy = remainingEnergy - energyUsed
			
			assignedPixies[#assignedPixies + 1] = pixieID
			
			-- Move pixie to build location
			Spring.Echo("DEBUG: Ordering pixie " .. pixieID .. " to move to build location (" .. targetX .. ", " .. targetY .. ", " .. targetZ .. ")")
			spGiveOrderToUnit(pixieID, CMD.MOVE, {targetX, targetY, targetZ}, 0)
		end
	end
	
	-- If there are leftover costs, handle partial build for last pixie
	if (remainingMetal > 0 or remainingEnergy > 0) and #assignedPixies > 0 then
		local lastPixieID = assignedPixies[#assignedPixies]
		local lastPixie = pixieMetaList[lastPixieID]
		if lastPixie then
			lastPixie.isPartialBuild = true
			lastPixie.partialBuildPercentage = 1.0 - math.max(remainingMetal / metalCost, remainingEnergy / energyCost)
		end
	end
	
	return true
end

local function updatePixieOrbits(commanderID)
	local commanderData = commanderMetaList[commanderID]
	if not commanderData then
		return
	end
	
	local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
	if not commanderX then
		return
	end
	
	for pixieID, _ in pairs(commanderData.pixieList) do
		local pixie = pixieMetaList[pixieID]
		if pixie and pixie.state == "orbiting" then
			-- Update orbit position
			pixie.orbitAngle = pixie.orbitAngle + 0.02
			local offsetX = mathCos(pixie.orbitAngle) * PIXIE_ORBIT_RADIUS
			local offsetZ = mathSin(pixie.orbitAngle) * PIXIE_ORBIT_RADIUS
			local newX = commanderX + offsetX
			local newY = spGetGroundHeight(newX, commanderZ + offsetZ) + PIXIE_HOVER_HEIGHT
			local newZ = commanderZ + offsetZ
			
			-- Only give new move command occasionally to avoid spam
			if mathRandom() < 0.1 then
				spGiveOrderToUnit(pixieID, CMD.MOVE, {newX, newY, newZ}, 0)
			end
		end
	end
end

local function checkPixieBuildProgress(pixieID)
	local pixie = pixieMetaList[pixieID]
	if not pixie or pixie.state ~= "moving" or not pixie.buildTarget then
		return
	end
	
	local pixieX, pixieY, pixieZ = spGetUnitPosition(pixieID)
	if not pixieX then
		return
	end
	
	local target = pixie.buildTarget
	local distance = mathDiag(pixieX - target.x, pixieZ - target.z)
	
	if distance < 100 then -- Within build range
		pixie.state = "building"
		Spring.Echo("DEBUG: Pixie " .. pixieID .. " is building " .. target.unitDefName .. " at distance " .. distance)
		
		-- Create the unit instantly
		local newUnitID = spCreateUnit(target.unitDefName, target.x, target.y, target.z, 0, spGetUnitTeam(pixieID))
		if newUnitID then
			Spring.Echo("DEBUG: Successfully created unit " .. newUnitID .. " (" .. target.unitDefName .. ")")
			-- Handle partial build
			if pixie.isPartialBuild then
				local buildPercentage = pixie.partialBuildPercentage or 1.0
				local currentHealth, maxHealth = spGetUnitHealth(newUnitID)
				local partialHealth = maxHealth * buildPercentage
				spSetUnitHealth(newUnitID, {build = buildPercentage, health = partialHealth})
				
				-- Give build command back to commander if partial
				if buildPercentage < 1.0 then
					spGiveOrderToUnit(pixie.commanderID, CMD.REPAIR, {newUnitID}, 0)
				end
			end
			
			-- Spawn effect
			local unitX, unitY, unitZ = spGetUnitPosition(newUnitID)
			if unitX then
				Spring.SpawnCEG("botrailspawn", unitX, unitY, unitZ, 0, 0, 0)
			end
		end
		
		-- Remove pixie if no resources left
		if pixie.metalValue <= 0 and pixie.energyValue <= 0 then
			local commanderData = commanderMetaList[pixie.commanderID]
			if commanderData then
				commanderData.pixieList[pixieID] = nil
			end
			pixieMetaList[pixieID] = nil
			spDestroyUnit(pixieID, false, true)
		else
			-- Pixie has leftover resources, return to orbiting
			pixie.state = "orbiting"
			pixie.buildTarget = nil
			pixie.targetCommand = nil
			pixie.isPartialBuild = nil
			pixie.partialBuildPercentage = nil
		end
	end
end

local function monitorCommanderCommands(commanderID)
	local commanderData = commanderMetaList[commanderID]
	if not commanderData then
		return
	end
	
	-- Get the command queue instead of just current command
	local commands = spGetUnitCommands(commanderID, 1) -- Get first command only
	if not commands or #commands == 0 then
		return
	end
	
	local cmd = commands[1]
	local cmdID = cmd.id
	local cmdParams = cmd.params
	local cmdTag = cmd.tag
	
	local paramsStr = cmdParams and table.concat(cmdParams, ", ") or "none"
	Spring.Echo("DEBUG: Commander " .. commanderID .. " has command: " .. cmdID .. " with params: " .. paramsStr .. " (tag: " .. (cmdTag or "nil") .. ")")
	
	-- Build commands have negative IDs (cmdID = -unitDefID)
	if cmdID < 0 then
		local unitDefID = -cmdID  -- Convert back to positive unitDefID
		Spring.Echo("DEBUG: Commander " .. commanderID .. " has build command for unitDefID: " .. unitDefID)
		
		-- Check if commander is within range of build target
		local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
		if not commanderX then
			return
		end
		
		-- Build command params are {x, y, z, facing}
		if not cmdParams or #cmdParams < 3 then
			Spring.Echo("DEBUG: Invalid build command params")
			return
		end
		
		local targetX, targetY, targetZ = cmdParams[1], cmdParams[2], cmdParams[3]
		local distance = mathDiag(commanderX - targetX, commanderZ - targetZ)
		
		Spring.Echo("DEBUG: Distance to build target: " .. distance .. " (limit: " .. COMMAND_STEAL_RANGE .. ")")
		
		if distance <= COMMAND_STEAL_RANGE then
			local unitDef = UnitDefs[unitDefID]
			if unitDef then
				Spring.Echo("DEBUG: Attempting to steal build command for: " .. unitDef.name)
				local success = assignPixiesToBuild(commanderID, cmdID, targetX, targetY, targetZ, unitDef.name, cmdTag)
				if success then
					commanderData.currentBuildCommand = {
						cmdID = cmdID,
						unitDefName = unitDef.name,
						x = targetX,
						y = targetY,
						z = targetZ,
						tag = cmdTag
					}
					Spring.Echo("DEBUG: Successfully stole build command")
				else
					Spring.Echo("DEBUG: Failed to steal build command")
				end
			else
				Spring.Echo("DEBUG: Could not find unit def for ID: " .. unitDefID)
			end
		end
	end
end

local function checkIfTeamFinished(teamID)
	local pixieCount = 0
	for commanderID, data in pairs(commanderMetaList) do
		if data.teamID == teamID then
			for pixieID, _ in pairs(data.pixieList) do
				if pixieMetaList[pixieID] then
					pixieCount = pixieCount + 1
				end
			end
		end
	end
	
	if pixieCount == 0 then
		teamsToBoost[teamID] = false
		return true
	end
	return false
end

function gadget:GameStart()
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
		if isBoostableCommander(unitDefinitionID) and teamsToBoost[unitTeam] then
			local metalAmount = spGetTeamResources(unitTeam, "metal")
			local energyAmount = spGetTeamResources(unitTeam, "energy")
			createPixiesForCommander(unitID, unitTeam, metalAmount, energyAmount)
		end
	end
end

function gadget:GameFrame(frameNumber)
	if frameNumber % UPDATE_FRAMES ~= 0 then
		return
	end
	
	-- Update all active commanders and their pixies
	for commanderID, commanderData in pairs(commanderMetaList) do
		if teamsToBoost[commanderData.teamID] then
			-- Debug: Show we're monitoring this commander
			local numPixies = 0
			for pixieID, _ in pairs(commanderData.pixieList) do
				if pixieMetaList[pixieID] then
					numPixies = numPixies + 1
				end
			end
			if frameNumber % (UPDATE_FRAMES * 10) == 0 then -- Only show every 10 updates to avoid spam
				Spring.Echo("DEBUG: Monitoring commander " .. commanderID .. " with " .. numPixies .. " pixies")
			end
			
			monitorCommanderCommands(commanderID)
			updatePixieOrbits(commanderID)
		end
	end
	
	-- Update all pixies
	for pixieID, pixieData in pairs(pixieMetaList) do
		if pixieData.state == "moving" then
			checkPixieBuildProgress(pixieID)
		end
	end
	
	-- Check if any teams are finished
	for teamID, isActive in pairs(teamsToBoost) do
		if isActive then
			checkIfTeamFinished(teamID)
		end
	end
end

function gadget:UnitDestroyed(unitID)
	-- Clean up commander data
	if commanderMetaList[unitID] then
		-- Destroy all pixies belonging to this commander
		for pixieID, _ in pairs(commanderMetaList[unitID].pixieList) do
			if pixieMetaList[pixieID] then
				pixieMetaList[pixieID] = nil
				spDestroyUnit(pixieID, false, true)
			end
		end
		commanderMetaList[unitID] = nil
	end
	
	-- Clean up pixie data
	if pixieMetaList[unitID] then
		local commanderID = pixieMetaList[unitID].commanderID
		if commanderMetaList[commanderID] then
			commanderMetaList[commanderID].pixieList[unitID] = nil
		end
		pixieMetaList[unitID] = nil
	end
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

function gadget:Shutdown()
	-- Clean up all pixies
	for pixieID, _ in pairs(pixieMetaList) do
		spDestroyUnit(pixieID, false, true)
	end
end