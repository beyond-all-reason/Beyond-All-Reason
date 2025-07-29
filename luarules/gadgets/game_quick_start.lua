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
local spValidUnitID = Spring.ValidUnitID
local spGetGroundHeight = Spring.GetGroundHeight
local spSetUnitCosts = Spring.SetUnitCosts
local spUseTeamResource = Spring.UseTeamResource
local mathDiag = math.diag
local mathRandom = math.random
local mathCos = math.cos
local mathSin = math.sin

-- Constants
local PIXIE_COST_VALUE = 50 + 500/10  -- 50 metal + 500 energy / 60 = ~58.33 total cost
local COMMAND_STEAL_RANGE = 750
local PIXIE_ORBIT_RADIUS = 150
local PIXIE_HOVER_HEIGHT = 50
local UPDATE_FRAMES = 15
local PIXIE_UNIT_NAME = "armassistdrone"
local PI = math.pi
local PRIVATE = { private = true }

-- Helper function to calculate unit cost using the same formula
local function calculateUnitCost(unitDef)
	local metalCost = unitDef.metalCost or 0
	local energyCost = unitDef.energyCost or 0
	return metalCost + energyCost / 60
end

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
	-- Calculate how many pixies based on starting resources using cost formula
	-- Pixie cost: 5 metal + 50 energy (1/10th of their value)
	local pixiePurchaseCost = 5 + 50/60  -- 5 metal + 50 energy / 60 = ~5.83 total cost
	local totalAvailableCost = metalResources + energyResources / 60
	local totalPixies = math.floor(totalAvailableCost / pixiePurchaseCost)
	
	if totalPixies <= 0 then
		return
	end
	
	-- Deduct the total cost from team resources (proportionally)
	local totalPurchaseCost = totalPixies * pixiePurchaseCost
	local metalPortion = 5 / pixiePurchaseCost -- How much of cost is metal
	local energyPortion = (50/60) / pixiePurchaseCost -- How much of cost is energy
	
	local totalMetalCost = totalPurchaseCost * metalPortion
	local totalEnergyCost = totalPurchaseCost * energyPortion * 60 -- Convert back to energy units
	
	spUseTeamResource(teamID, "metal", totalMetalCost)
	spUseTeamResource(teamID, "energy", totalEnergyCost)
		
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
	for i = 1, totalPixies do
		local angle = (i / totalPixies) * 2 * PI
		local offsetX = mathCos(angle) * PIXIE_ORBIT_RADIUS
		local offsetZ = mathSin(angle) * PIXIE_ORBIT_RADIUS
		local pixieX = commanderX + offsetX
		local pixieY = spGetGroundHeight(pixieX, commanderZ + offsetZ) + PIXIE_HOVER_HEIGHT
		local pixieZ = commanderZ + offsetZ
		
		local pixieID = spCreateUnit(PIXIE_UNIT_NAME, pixieX, pixieY, pixieZ, 0, teamID)
		if pixieID then
			spSetUnitNoSelect(pixieID, true)
			spSetUnitRulesParam(pixieID, "is_pixie", 1, PRIVATE)
			spSetUnitRulesParam(pixieID, "commander_id", commanderID, PRIVATE)
			
			-- Debug: Show pixie build options
			local pixieDefID = spGetUnitDefID(pixieID)
			local pixieDef = UnitDefs[pixieDefID]
			if pixieDef then
				for i, buildOption in ipairs(pixieDef.buildOptions) do
					if i <= 5 then -- Only show first 5 to avoid spam
						local optionDef = UnitDefs[buildOption]
					end
				end
				if #pixieDef.buildOptions > 5 then
				end
				
				spSetUnitCosts(pixieID, {
					buildTime = 1,
					energyCost = 1,
					metalCost = 1
				})
			end
			
			pixieMetaList[pixieID] = {
				commanderID = commanderID,
				costValue = PIXIE_COST_VALUE,
				state = "orbiting", -- orbiting, moving, building, assisting, depleted
				targetCommand = nil,
				orbitAngle = angle,
				buildTarget = nil,
				assistTarget = nil,
				hasAppliedBoost = false -- Track if pixie has applied its boost
			}
			
			commanderMetaList[commanderID].pixieList[pixieID] = true
			
			-- Give initial orbit command
			spGiveOrderToUnit(pixieID, CMD.MOVE, {pixieX, pixieY, pixieZ}, 0)
		end
	end
end

local function getAvailablePixiesForCommand(commanderID, unitCost)
	if not commanderMetaList[commanderID] then
		return {}
	end
	
	local availablePixies = {}
	local totalCost = 0
	
	for pixieID, _ in pairs(commanderMetaList[commanderID].pixieList) do
		if pixieMetaList[pixieID] and pixieMetaList[pixieID].state == "orbiting" then
			totalCost = totalCost + pixieMetaList[pixieID].costValue
			availablePixies[#availablePixies + 1] = pixieID
			
			if totalCost >= unitCost then
				break
			end
		end
	end
	
	if totalCost >= unitCost then
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
	
	local unitCost = calculateUnitCost(unitDef)
	
	local availablePixies = getAvailablePixiesForCommand(commanderID, unitCost)
	if #availablePixies == 0 then
		return false
	end
	
	-- Remove the build command using its tag
	if cmdTag then
		spGiveOrderToUnit(commanderID, CMD.REMOVE, {cmdTag}, 0)
	end
	
	-- Assign available pixies to build this structure
	local assignedPixies = {}
	
	for _, pixieID in ipairs(availablePixies) do
		local pixie = pixieMetaList[pixieID]
		if pixie then
			pixie.state = "moving"
			pixie.targetCommand = buildCommand
			pixie.buildTarget = {
				x = targetX,
				y = targetY,
				z = targetZ,
				unitDefName = unitDefName
			}
			
			assignedPixies[#assignedPixies + 1] = pixieID
			
			-- Move pixie to build location
			spGiveOrderToUnit(pixieID, CMD.MOVE, {targetX, targetY, targetZ}, 0)
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
	if not pixie then
		return
	end
	
	local pixieX, pixieY, pixieZ = spGetUnitPosition(pixieID)
	if not pixieX then
		return
	end
	
	if pixie.state == "moving" and pixie.buildTarget then
		local target = pixie.buildTarget
		local distance = mathDiag(pixieX - target.x, pixieZ - target.z)
		
		if distance < 100 then -- Within build range
			pixie.state = "building"
			
			-- Check if pixie can build this unit type and give the build command
			local unitDef = UnitDefNames[target.unitDefName]
			if unitDef then
				-- Check if pixie can build this unit type
				local pixieDefID = spGetUnitDefID(pixieID)
				local pixieDef = UnitDefs[pixieDefID]
				local canBuild = false
				
				if pixieDef and pixieDef.buildOptions then
					for _, buildOption in ipairs(pixieDef.buildOptions) do
						if buildOption == unitDef.id then
							canBuild = true
							break
						end
					end
				end
				
				if canBuild then
					-- Use proper build positioning
					local bx, by, bz = Spring.Pos2BuildPos(unitDef.id, target.x, target.y, target.z, 0)
					local buildCmdID = -unitDef.id  -- Build commands are negative unitDefID
					local buildParams = {bx, by, bz, 0} -- x, y, z, facing
					
					-- Test if build position is valid
					local buildTest = Spring.TestBuildOrder(unitDef.id, bx, by, bz, 0)
					if buildTest ~= 0 then
						spGiveOrderToUnit(pixieID, buildCmdID, buildParams, 0)
					else
						-- Check if there's already a structure being built at this location
						local radius = 150 -- Increase radius to find nearby structures
						local nearbyUnits = Spring.GetUnitsInCylinder(bx, bz, radius)
						local assistTarget = nil
						
						for _, nearbyID in ipairs(nearbyUnits) do
							local nearbyDefID = spGetUnitDefID(nearbyID)
							local nearbyDef = UnitDefs[nearbyDefID]
							
							if nearbyDefID == unitDef.id then
								local health, maxHealth, _, _, buildProgress = spGetUnitHealth(nearbyID)
								if buildProgress and buildProgress < 1.0 then -- Under construction
									assistTarget = nearbyID
									break
								end
							end
						end
						
						if assistTarget then
							-- Give assist command (guard the structure)
							spGiveOrderToUnit(pixieID, CMD.GUARD, {assistTarget}, 0)
							pixie.assistTarget = assistTarget
							pixie.state = "assisting"
						else
							-- If no structure to build or assist, mark pixie as depleted since it has no work
							pixie.state = "depleted"
							pixie.buildTarget = nil
							pixie.assistTarget = nil
						end
					end
				else
					-- Return to orbiting if can't build this unit type
					pixie.state = "orbiting"
					pixie.buildTarget = nil
					pixie.assistTarget = nil
				end
			end
		end
	elseif pixie.state == "building" then
		-- Check if pixie is actively building something
		local commands = spGetUnitCommands(pixieID, 1)
		local buildingUnitID = nil
		
		if commands and #commands > 0 then
			local cmd = commands[1]
			if cmd.id < 0 then -- Has a build command
				-- Find what unit they're building/assisting
				local allUnits = Spring.GetUnitsInCylinder(pixieX, pixieZ, 150)
				for _, unitID in ipairs(allUnits) do
					local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
					if buildProgress and buildProgress < 1.0 then
						buildingUnitID = unitID
						break
					end
				end
			end
		end
		
		if buildingUnitID and not pixie.hasAppliedBoost then
			-- Pixie is building something - instantly apply its value (only once)
			local _, maxHealth, _, _, buildProgress = spGetUnitHealth(buildingUnitID)
			local unitDefID = spGetUnitDefID(buildingUnitID)
			local unitDef = UnitDefs[unitDefID]
			local unitCost = calculateUnitCost(unitDef)
			
			-- Calculate how much progress this pixie can contribute (dump all resources immediately)
			local progressToAdd = math.min(pixie.costValue / unitCost, 1.0 - buildProgress)
			
			if progressToAdd > 0 then
				-- Apply the progress instantly
				local newBuildProgress = buildProgress + progressToAdd
				local newHealth = maxHealth * newBuildProgress
				spSetUnitHealth(buildingUnitID, {build = newBuildProgress, health = newHealth})
				
				-- Deduct the used cost from pixie and mark as having applied boost
				local costUsed = progressToAdd * unitCost
				pixie.costValue = math.max(0, pixie.costValue - costUsed)
				pixie.hasAppliedBoost = true
				
				-- Check if pixie is depleted
				if pixie.costValue <= 0.1 then
					pixie.state = "depleted"
					pixie.buildTarget = nil
					pixie.assistTarget = nil
				elseif newBuildProgress >= 1.0 then
					-- Structure complete, mark pixie as depleted since it used its boost
					pixie.state = "depleted"
					pixie.buildTarget = nil
					pixie.assistTarget = nil
				end
			end
		elseif buildingUnitID == nil and pixie.hasAppliedBoost then
			-- Pixie was building but unit no longer exists, mark as depleted
			pixie.state = "depleted"
			pixie.buildTarget = nil
			pixie.assistTarget = nil
		else
			-- Not actively building, return to orbiting
			pixie.state = "orbiting"
			pixie.buildTarget = nil
			pixie.assistTarget = nil
			spGiveOrderToUnit(pixieID, CMD.STOP, {}, 0)
		end
	elseif pixie.state == "assisting" and pixie.assistTarget then
		-- Check if pixie is still assisting the target structure
		local assistTarget = pixie.assistTarget
		local targetExists = spValidUnitID(assistTarget)
		
		if targetExists and not pixie.hasAppliedBoost then
			local _, maxHealth, _, _, buildProgress = spGetUnitHealth(assistTarget)
			
			if buildProgress and buildProgress < 1.0 then
				-- Structure still under construction - apply pixie value (only once)
				local unitDefID = spGetUnitDefID(assistTarget)
				local unitDef = UnitDefs[unitDefID]
				local unitCost = calculateUnitCost(unitDef)
				
				-- Calculate how much progress this pixie can contribute (dump all resources immediately)
				local progressToAdd = math.min(pixie.costValue / unitCost, 1.0 - buildProgress)
				
				if progressToAdd > 0 then
					-- Apply the progress instantly
					local newBuildProgress = buildProgress + progressToAdd
					local newHealth = maxHealth * newBuildProgress
					spSetUnitHealth(assistTarget, {build = newBuildProgress, health = newHealth})
					
					-- Deduct the used cost from pixie and mark as having applied boost
					local costUsed = progressToAdd * unitCost
					pixie.costValue = math.max(0, pixie.costValue - costUsed)
					pixie.hasAppliedBoost = true
					
					-- Check if pixie is depleted
					if pixie.costValue <= 0.1 then
						pixie.state = "depleted"
						pixie.buildTarget = nil
						pixie.assistTarget = nil
					elseif newBuildProgress >= 1.0 then
						-- Structure complete, mark pixie as depleted since it used its boost
						pixie.state = "depleted"
						pixie.buildTarget = nil
						pixie.assistTarget = nil
					end
				end
			else
				-- Structure complete, mark pixie as depleted since it has no more work
				pixie.state = "depleted"
				pixie.buildTarget = nil
				pixie.assistTarget = nil
			end
		elseif targetExists and pixie.hasAppliedBoost then
			-- Pixie already applied boost, mark as depleted
			pixie.state = "depleted"
			pixie.buildTarget = nil
			pixie.assistTarget = nil
		else
			-- Assist target no longer exists, mark pixie as depleted
			pixie.state = "depleted"
			pixie.buildTarget = nil
			pixie.assistTarget = nil
		end
	end
	
	-- Remove pixie if depleted or very low resources
	if pixie.state == "depleted" or pixie.costValue <= 0.1 then
		local commanderData = commanderMetaList[pixie.commanderID]
		if commanderData then
			commanderData.pixieList[pixieID] = nil
		end
		pixieMetaList[pixieID] = nil
		spDestroyUnit(pixieID, false, true)
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
	
	-- Build commands have negative IDs (cmdID = -unitDefID)
	if cmdID < 0 then
		local unitDefID = -cmdID  -- Convert back to positive unitDefID
		
		-- Check if commander is within range of build target
		local commanderX, commanderY, commanderZ = spGetUnitPosition(commanderID)
		if not commanderX then
			return
		end
		
		-- Build command params are {x, y, z, facing}
		if not cmdParams or #cmdParams < 3 then
			return
		end
		
		local targetX, targetY, targetZ = cmdParams[1], cmdParams[2], cmdParams[3]
		local distance = mathDiag(commanderX - targetX, commanderZ - targetZ)
		
		if distance <= COMMAND_STEAL_RANGE then
			local unitDef = UnitDefs[unitDefID]
			if unitDef then
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
				end
			else
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
			local numPixies = 0
			for pixieID, _ in pairs(commanderData.pixieList) do
				if pixieMetaList[pixieID] then
					numPixies = numPixies + 1
				end
			end
			
			monitorCommanderCommands(commanderID)
			updatePixieOrbits(commanderID)
		end
	end
	
	-- Update all pixies (moving and building states)
	for pixieID, pixieData in pairs(pixieMetaList) do
		if pixieData.state == "moving" or pixieData.state == "building" then
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