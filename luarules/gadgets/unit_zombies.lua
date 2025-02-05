local version = "0.1.3"

function gadget:GetInfo()
	return {
		name      = "Zombie Resurrection",
		desc      = "Resurrects dead units as zombies",
		author    = "Rafal",
		date      = "March 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--SYNCED-------------------------------------------------------------------

-- changelog
-- 6 august 2014 - 0.1.3. Some magic which might fix crash. (At least it fixed the original zombie gadget)
-- 7 april 2014 - 0.1.2. Added permaslow option. Default on. 50% is max slow for now.
-- 5 april 2014 - 0.1.1. Sfx, gfx, factory orders added. Slow down upon reclaim added. Thanks Anarchid.
-- 5 april 2014 - 0.1.0. Release.

local modOptions = Spring.GetModOptions()

-- Now to load utilities and/or configuration
--VFS.Include("LuaRules/Configs/targetReachableTester.lua")

-- configs
local ZOMBIE_MAX_RESURRECTION_TIME = Game.gameSpeed * 3  -- Maximum time (in seconds) a unit can take to resurrect, regardless of cost
local ZOMBIE_GUARD_RADIUS = 300           -- How far zombies look for allies to guard (in units)
local ZOMBIE_ORDER_MIN = 10               -- Minimum number of random orders to give zombies
local ZOMBIE_ORDER_MAX = 30               -- Maximum number of random orders to give zombies
local ZOMBIE_GUARD_CHANCE = 0.6           -- Probability (0-1) that a zombie will guard nearby allies
local WARNING_TIME = 15 * Game.gameSpeed -- frames to start being scary before actual reanimation event
local ZOMBIES_REZ_MIN = tonumber(modOptions.zombies_delay)
if (tonumber(ZOMBIES_REZ_MIN) == nil) then
	-- minimum of 10 seconds, max is determined by rez speed
	ZOMBIES_REZ_MIN = 10
end

local ZOMBIES_REZ_SPEED = tonumber(modOptions.zombies_rezspeed)
if (tonumber(ZOMBIES_REZ_SPEED) == nil) then
	-- 12m/s, big units have a really long time to respawn
	ZOMBIES_REZ_SPEED = 12
end

local ZOMBIES_PERMA_SLOW = tonumber(modOptions.zombies_permaslow)
if (tonumber(ZOMBIES_PERMA_SLOW) == nil) then
	-- from 0 to 1, symbolises from 0% to 50% slow which is always on
	ZOMBIES_PERMA_SLOW = 1
end

if ZOMBIES_PERMA_SLOW == 0 then
	ZOMBIES_PERMA_SLOW = nil
else
	ZOMBIES_PERMA_SLOW = 1 - ZOMBIES_PERMA_SLOW*0.5
end

local ZOMBIES_PARTIAL_RECLAIM = (tonumber(modOptions.zombies_partial_reclaim) == 1)

--localized functions
local spGetGroundHeight           = Spring.GetGroundHeight
local spGetUnitPosition           = Spring.GetUnitPosition
local spGetFeaturePosition        = Spring.GetFeaturePosition
local spCreateUnit                = Spring.CreateUnit
local spGetUnitDefID              = Spring.GetUnitDefID
local spGetUnitTeam               = Spring.GetUnitTeam
local spGetAllUnits               = Spring.GetAllUnits
local spGetGameFrame              = Spring.GetGameFrame
local spGetAllFeatures            = Spring.GetAllFeatures
local spGiveOrderToUnit           = Spring.GiveOrderToUnit
local spGetUnitCommandCount       = Spring.GetUnitCommandCount
local spDestroyFeature            = Spring.DestroyFeature
local spGetFeatureResurrect       = Spring.GetFeatureResurrect
local spGetUnitIsDead             = Spring.GetUnitIsDead
local spGiveOrderArrayToUnitArray = Spring.GiveOrderArrayToUnitArray
local spGetUnitsInCylinder        = Spring.GetUnitsInCylinder
local spSetTeamResource           = Spring.SetTeamResource
local spGetUnitHealth             = Spring.GetUnitHealth
local spSetUnitRulesParam         = Spring.SetUnitRulesParam
local spGetUnitRulesParam         = Spring.GetUnitRulesParam
local spGetFeatureDefID           = Spring.GetFeatureDefID
local spSpawnCEG 					= Spring.SpawnCEG
local random = math.random
local floor = math.floor
local function disSQ(x1, y1, x2, y2) return (x1 - x2)^2 + (y1 - y2)^2 end

--constants
local GaiaTeamID     = Spring.GetGaiaTeamID()
local GAME_SPEED = Game.gameSpeed
local mapWidth
local mapHeight
local ZOMBIE_ORDER_CHECK_INTERVAL = Game.gameSpeed * 10    -- How often (in frames) to check if zombies need new orders
local ZOMBIE_CHECK_INTERVAL = Game.gameSpeed    -- How often (in frames) everything else is checked

local CMD_REPEAT = CMD.REPEAT
local CMD_MOVE_STATE = CMD.MOVE_STATE
local CMD_INSERT = CMD.INSERT
local CMD_FIGHT = CMD.FIGHT
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_GUARD = CMD.GUARD
local CMD_FIRE_STATE = CMD.FIRE_STATE

local ISNT_ZOMBIE = 0
local IS_ZOMBIE = 1
local IS_NEUTRAL = 2


--variables
local gameFrame = 0
local initiationFrame = 0
local LOS_ACCESS = {inlos = true}


--tables
local zombieCorpseDefs = {}
local zombieUnitDefs = {}
local zombieWatch = {}
local corpseCheckFrames = {}
local corpsesData = {}

-- Populate zombieUnitDefs with units that have resurrectable _dead corpses
for unitDefID, unitDef in pairs(UnitDefs) do
	local corpseDefName = unitDef.name .. "_dead"
	Spring.Echo("Checking corpseDefName: " .. corpseDefName)
	if FeatureDefNames[corpseDefName] then
		local featureDefID = FeatureDefNames[corpseDefName].id
		local metalCost = unitDef.metalCost or 100 --fallback number chosen arbitrarily
		local spawnSeconds = math.floor(metalCost / ZOMBIES_REZ_SPEED)
		spawnSeconds = math.max(spawnSeconds, ZOMBIES_REZ_MIN)
		spawnSeconds = math.min(spawnSeconds, ZOMBIE_MAX_RESURRECTION_TIME)
		local spawnFrames = spawnSeconds * Game.gameSpeed

		Spring.Echo("Found resurrectable corpse: " .. corpseDefName, FeatureDefNames[corpseDefName].id)
		zombieCorpseDefs[featureDefID] = {unitDefID = unitDefID, spawnDelayFrames = spawnFrames}
		zombieUnitDefs[unitDefID] = true
	end
end


--custom functions
local function executeInitialize()		
	local units = spGetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		local identifiedZombie = spGetUnitRulesParam(unitID, "zombie")
		if identifiedZombie and identifiedZombie == IS_ZOMBIE then
			zombieWatch[unitID] = spGetUnitDefID(unitID)
			spGiveOrderToUnit(unitID, CMD_REPEAT, 1, 0)
			spGiveOrderToUnit(unitID, CMD_MOVE_STATE, 2, 0)
			spGiveOrderToUnit(unitID, CMD_FIRE_STATE, 3, 0)
		end
	end
	
	local features = spGetAllFeatures()
	for i = 1, #features do
		gadget:FeatureCreated(features[i], 1)
	end
end

local function GetUnitNearestAlly(unitID, range)
	local best_ally
	local best_dist
	local x, y, z = spGetUnitPosition(unitID)
	local units = spGetUnitsInCylinder(x, z, range)
	for i = 1, #units do
		local allyID = units[i]
		local allyTeam = spGetUnitTeam(allyID)
--		local allyDefID = spGetUnitDefID(allyID)
		if (allyID ~= unitID) and (allyTeam == GaiaTeamID) then -- and (getMovetype(UnitDefs[allyDefID]) ~= false)
			local ox, oy, oz = spGetUnitPosition(allyID)
			local dist = disSQ(x, z, ox ,oz)
			if ((best_dist == nil) or (dist < best_dist)) then
				best_ally = allyID
				best_dist = dist
			end
		end
	end
	return best_ally
end

local function issueRandomFactoryBuildOrders(unitID, unitDefID) -- give factory something to do
	local buildopts = UnitDefs[unitDefID].buildOptions
	if (not buildopts) or #buildopts <= 0 then
		return
	end
	local orders = {}
	--local x,y,z = spGetUnitPosition(unitID)
	for i = 1, random(ZOMBIE_ORDER_MIN, ZOMBIE_ORDER_MAX) do
		orders[#orders + 1] = {-buildopts[random(1, #buildopts)], 0, 0 }
	end
	if (#orders > 0) then
		if not spGetUnitIsDead(unitID) then
			spGiveOrderArrayToUnitArray({unitID}, orders)
		end
	end
end

local function spawnCEG(x, y, z, size)
	spSpawnCEG("scav-spawnexplo", x, y, z, 0, 0, 0, size)
end

local function progressCEG(featureID, x, y, z)
	local radius = Spring.GetFeatureRadius(featureID)

	local effects = {
		"scavmist",
		"scavradiation-lightning"
	}
	local selectedEffect = effects[random(#effects)]
	spSpawnCEG(selectedEffect, x, y, z, 0, 0, 0, 10 + radius, 10 + radius)
end

local function issueRandomOrders(unitID, unitDefID) --zzz need to estimate path and check if the final coordinate is close to the target location
	Spring.Echo("issueRandomOrders called for unitID:", unitID, "unitDefID:", unitDefID)
	if spGetUnitIsDead(unitID) then
		Spring.Echo("Unit is dead, exiting function.")
		return
	end
	
	local randomX, randomY, randomZ
	local orders = {}
	local nearAlly
	if (UnitDefs[unitDefID].canAttack) then
		nearAlly = GetUnitNearestAlly(unitID, ZOMBIE_GUARD_RADIUS)
		if (nearAlly) then
			if Spring.GetUnitCurrentCommand(nearAlly) == CMD_GUARD then
				Spring.Echo("Nearby ally is guarding, setting nearAlly to nil.")
				nearAlly = nil -- i dont want chain guards...
			end
		end
	end
	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	Spring.Echo("Unit position:", unitX, unitY, unitZ)

	if (nearAlly) and random() < ZOMBIE_GUARD_CHANCE then
		orders[#orders + 1] = {CMD_GUARD, {nearAlly}, 0}
		Spring.Echo("Added guard order for nearAlly:", nearAlly)
	end

	for i = 1, random(ZOMBIE_ORDER_MIN, ZOMBIE_ORDER_MAX) do
		Spring.Echo("Generating random order:", i, mapWidth, mapHeight)
		randomX = random(0, mapWidth)
		Spring.Echo("Random X:", randomX)
		randomZ = random(0, mapHeight)
		Spring.Echo("Random Z:", randomZ)
		randomY = spGetGroundHeight(randomX, randomZ)
		Spring.Echo("Random Y:", randomY)
		Spring.Echo("Generated random order:", i, "to position:", randomX, randomY, randomZ)

		if 1 == 1 then
			orders[#orders+1] = {CMD_FIGHT, {randomX, randomY, randomZ}, CMD_OPT_SHIFT}
			Spring.Echo("Adding fight order to position:", randomX, randomY, randomZ)
			spGiveOrderToUnit(unitID, CMD_FIGHT, {randomX, randomY, randomZ}, {"shift", "alt", "ctrl"})
			Spring.Echo("Added fight order to position:", randomX, randomY, randomZ)
		else
			Spring.Echo("Target not reachable:", randomX, randomY, randomZ)
		end
	end

	if (#orders > 0) then
		Spring.TransferUnit (unitID, 0)
		--spGiveOrderArrayToUnitArray({unitID}, orders)
		Spring.Echo("Issued orders to unitID:", unitID, "Orders count:", #orders)
	else
		Spring.Echo("No orders to issue for unitID:", unitID)
	end

	if (UnitDefs[unitDefID].isFactory) then
		issueRandomFactoryBuildOrders(unitID, unitDefID) -- give factory something to do
		zombieWatch[unitID] = nil -- no need to update factory orders anymore
		Spring.Echo("Factory orders issued for unitID:", unitID)
	end
end

--call-ins
function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local featureData = corpsesData[featureID]
	if featureData then
		featureData.tamperedFrame = gameFrame
	end
	return true
end

--zombieCorpseDefs[featureDefID] = {unitDefID = unitDefID, resurrectionDelayFrames = resurrectionFrames}
-- corpsesData[featureID] = {featureDefID = number, resurrectionFrames = number}
-- zombiesToSpawn = {unitDefID = number, featureID = number}
-- local zombieWatch[frame] = [1] = featureID, [2] = featureID
-- local zombieCorpseDefs = {}
-- local zombieDefRezCounts = {}
-- local zombieWatch = {}
-- local corpseCheckFrames = {}
-- local corpsesData = {}
function gadget:GameFrame(frame)
	gameFrame = frame

	--spawn this frame's zombies
	local corpsesToCheck = corpseCheckFrames[frame]
	if corpsesToCheck then
		for i = 1, #corpsesToCheck do
			local featureID = corpsesToCheck[i]
			local corpseData = corpsesData[featureID]
			local featureX, featureY, featureZ
			if corpseData then
			featureX, featureY, featureZ = spGetFeaturePosition(featureID)
			end
			if not featureX then --feature is gone
				corpsesData[featureID] = nil
			else --feature is still there
				local featureData = corpsesData[featureID]
				local featureDefData = zombieCorpseDefs[featureData.featureDefID]
				if featureData.tamperedFrame then --tampered means the corpse has been tampered with, so we need to reset the check frame
					local newFrame = featureData.tamperedFrame + featureDefData.spawnDelayFrames
					featureData.spawnFrame = newFrame
					corpsesToCheck[newFrame] = corpsesToCheck[newFrame] or {}
					corpsesToCheck[newFrame][#corpsesToCheck[newFrame] + 1] = featureID
				else
					local unitDefID = featureDefData.unitDefID
					local unitID = spCreateUnit(unitDefID, featureX, featureY, featureZ, 0, GaiaTeamID)
					spDestroyFeature(featureID)
					spawnCEG(featureX, featureY, featureZ, UnitDefs[unitDefID].xsize)
					corpsesData[featureID] = nil
					if unitID then
						zombieWatch[unitID] = unitDefID
						spSetUnitRulesParam(unitID, "zombie", IS_ZOMBIE)
					end
				end
			end
			corpseCheckFrames[frame] = nil
		end
	end

	--progress CEGs
	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		for featureID, featureData in pairs(corpsesData) do
			local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
			if not featureX then --doesn't exist anymore
				corpsesData[featureID] = nil
			elseif featureData.spawnFrame - frame < WARNING_TIME then
				progressCEG(featureID, featureX, featureY, featureZ)
			end
		end
	end

	--check if any zombies need new orders
	if frame % ZOMBIE_ORDER_CHECK_INTERVAL == 1 then
		for unitID, unitDefID in pairs(zombieWatch) do
			if spGetUnitIsDead(unitID) then
				zombieWatch[unitID] = nil
			else
				local queueSize = spGetUnitCommandCount(unitID)
				if not (queueSize) or not (queueSize > 0) then
					issueRandomOrders(unitID, unitDefID)
				end
			end
		end
	end

	if frame == initiationFrame then
		executeInitialize()
	end
end

function gadget:FeatureCreated(featureID, allyTeam)
	local featureDefID = spGetFeatureDefID(featureID)
	if zombieCorpseDefs[featureDefID] then
		local spawnDelayFrames = zombieCorpseDefs[featureDefID].spawnDelayFrames
		local spawnFrame = gameFrame + spawnDelayFrames
		corpsesData[featureID] = {featureDefID = featureDefID, spawnDelayFrames = spawnDelayFrames, spawnFrame = spawnFrame}
		corpseCheckFrames[spawnFrame] = corpseCheckFrames[spawnFrame] or {}
		corpseCheckFrames[spawnFrame][#corpseCheckFrames[spawnFrame] + 1] = featureID
	end
end


function gadget:FeatureDestroyed(featureID, allyTeam)
	corpsesData[featureID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
		local identifiedZombie = spGetUnitRulesParam(unitID, "zombie")
		if identifiedZombie and identifiedZombie == IS_ZOMBIE then
			zombieWatch[unitID] = unitDefID
		else
			spSetUnitRulesParam(unitID, "zombie", ISNT_ZOMBIE)
		end
	else
		spSetUnitRulesParam(unitID, "zombie", ISNT_ZOMBIE)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	zombieWatch[unitID] = nil
end

function gadget:Initialize()
	mapWidth = Game.mapSizeX
	mapHeight = Game.mapSizeZ
	GaiaTeamID = Spring.GetGaiaTeamID()
	initiationFrame = spGetGameFrame() + 1 --to avoid race conditions
end
--zzz need to come up with a better way to handle zombie reloads. Maybe set customrulesparam that they're a zombie? 
--upon reload, ask what units are zombies and continue treating them as such.




-- function gadget:GameFrame(f)
-- 	gameframe = f
-- 	if (f%GAME_SPEED) == 0 then
-- 			local featureID = zombiesToSpawnList[index]
-- 			local x, y, z = spGetFeaturePosition(featureID)

-- 			if time_to_spawn <= f then
-- 				if not RemoveZombieToSpawn(featureID) then
-- 					index = index + 1
-- 				end
-- 				local resName, face = spGetFeatureResurrect(featureID)
-- 				local partialReclaim = 1
-- 				if ZOMBIES_PARTIAL_RECLAIM then
-- 					local currentMetal, maxMetal = Spring.GetFeatureResources(featureID)
-- 					if currentMetal and maxMetal and (maxMetal > 0) then
-- 						partialReclaim = currentMetal/maxMetal
-- 					end
-- 				end
-- 				spDestroyFeature(featureID)
-- 				local unitID = spCreateUnit(resName, x, y, z, face, GaiaTeamID)
-- 				if (unitID) then
-- 					Spring.Echo("Zombie created: " .. resName .. " (ID: " .. unitID .. ")")
-- 					local size = UnitDefNames[resName].xsize
-- 					spSpawnCEG("scav-spawnexplo", x, y, z, 0, 0, 0, size)
-- 					Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, 3, 0)
-- 					if partialReclaim ~= 1 then
-- 						local health = Spring.GetUnitHealth(unitID)
-- 						if health then
-- 							Spring.SetUnitHealth(unitID, health*partialReclaim)
-- 							--spSetUnitRulesParam(unitID, "zombie_partialReclaim", partialReclaim, PRIVATE_ACCESS)
-- 						end
-- 					end
-- 				end
-- 			else
-- 				local steps_to_spawn = floor((time_to_spawn - f) / GAME_SPEED)
-- 				local resName, face = myGetFeatureRessurect(featureID)
-- 				if steps_to_spawn <= WARNING_TIME then
-- 					local r = Spring.GetFeatureRadius(featureID)

-- 					local effects = {
-- 						"scavmist",
-- 						"scavradiation-lightning"
-- 					}
-- 					local selectedEffect = effects[random(#effects)]
-- 					spSpawnCEG(selectedEffect, x, y, z, 0, 0, 0, 10 + r, 10 + r)

-- 					if steps_to_spawn == WARNING_TIME then
-- 						-- local z_sound = ZOMBIE_SOUNDS[math.random(#ZOMBIE_SOUNDS)]
-- 					end
-- 				end
-- 				index = index + 1
-- 			end
-- 			iterations = iterations + 1  -- Increment iterations
-- 		end
-- 		if iterations >= maxIterations then
-- 			Spring.Echo("Warning: Exiting zombie spawn loop after reaching maximum iterations.")
-- 		end
-- 	end
-- 	if (f%ZOMBIE_ORDER_CHECK_INTERVAL) == 1 then
-- 		CheckZombieOrders()
-- 	end
-- 	-- if f == 1 then
-- 	-- 	spSetTeamResource(GaiaTeamID, "ms", 500)
-- 	-- 	spSetTeamResource(GaiaTeamID, "es", 10500)
-- 	-- end
-- end
-- -- settings gaiastorage before frame 1 somehow doesnt work, well i can guess why...
