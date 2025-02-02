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
VFS.Include("LuaRules/Configs/targetReachableTester.lua")

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

local GaiaTeamID     = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID, false))

local gameframe = 0
local LOS_ACCESS = {inlos = true}
local PRIVATE_ACCESS = {private = true}

local random = math.random
local floor = math.floor

local mapWidth
local mapHeight

local reclaimed_data = {} -- holds initial gameframe, initial time in seconds, % of feature reclaimed
local zombies_to_spawn = {}
local zombiesToSpawnList = {}
local zombiesToSpawnMap = {}
local zombiesToSpawnCount = 0
local zombies = {}

local ZOMBIE_SOUNDS = {
	"sounds/misc/zombie_1.wav",
	"sounds/misc/zombie_2.wav",
	"sounds/misc/zombie_3.wav",
}
local REZ_SOUND = "sounds/misc/resurrect.wav"

local defined = false -- wordaround, because i meet some kind of racing condition, if any gadget spawns gaia BEFORE this gadget can process all the stuff...

local NonZombies = {
	["asteroid"] = true,
}

local WARNING_TIME = 5 -- seconds to start being scary before actual reanimation event
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

local CMD_REPEAT = CMD.REPEAT
local CMD_MOVE_STATE = CMD.MOVE_STATE
local CMD_INSERT = CMD.INSERT
local CMD_FIGHT = CMD.FIGHT
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_GUARD = CMD.GUARD

local function disSQ(x1, y1, x2, y2)
	return (x1 - x2)^2 + (y1 - y2)^2
end

local function SetZombieSlow(unitID, slowed)
	spSetUnitRulesParam(unitID, "zombieSpeedMult", (slowed and 0.5) or 1, LOS_ACCESS)
	--GG.UpdateUnitAttributes(unitID)
end

local function RemoveZombieToSpawn(featureID)
	if not zombiesToSpawnMap[featureID] then
		return false
	end
	zombies_to_spawn[featureID] = nil
	reclaimed_data[featureID] = nil
	
	local index = zombiesToSpawnMap[featureID]
	
	zombiesToSpawnList[index] = zombiesToSpawnList[zombiesToSpawnCount]
	zombiesToSpawnMap[zombiesToSpawnList[zombiesToSpawnCount]] = index
	
	zombiesToSpawnList[zombiesToSpawnCount] = nil
	zombiesToSpawnMap[featureID] = nil
	zombiesToSpawnCount = zombiesToSpawnCount - 1
	
	return true
end

local function GetUnitNearestAlly(unitID, range)
	local best_ally
	local best_dist
	local x, y, z = spGetUnitPosition(unitID)
	local units = spGetUnitsInCylinder(x, z, range)
	for i = 1, #units do
		local allyID = units[i]
		local allyTeam = spGetUnitTeam(allyID)
		local allyDefID = spGetUnitDefID(allyID)
		if (allyID ~= unitID) and (allyTeam == GaiaTeamID) then -- and (getMovetype(UnitDefs[allyDefID]) ~= false)
			local ox, oy, oz = spGetUnitPosition(allyID)
			local dist = disSQ(x, z, ox ,oz)
			if IsTargetReallyReachable(unitID, ox, oy, oz, x, y, z) and ((best_dist == nil) or (dist < best_dist)) then
				best_ally = allyID
				best_dist = dist
			end
		end
	end
	return best_ally
end

local function OpenAllClownSlots(unitID, unitDefID) -- give factory something to do
	local buildopts = UnitDefs[unitDefID].buildOptions
	if (not buildopts) or #buildopts <= 0 then
		return
	end
	local orders = {}
	--local x,y,z = spGetUnitPosition(unitID)
	for i = 1, random(10, 30) do
		orders[#orders + 1] = {-buildopts[random(1, #buildopts)], 0, 0 }
	end
	if (#orders > 0) then
		if not spGetUnitIsDead(unitID) then
			spGiveOrderArrayToUnitArray({unitID}, orders)
		end
	end
end

-- reclaiming zombies 'causes delay in rez, basically you have to have about ZOMBIES_REZ_SPEED/2 or bigger BP to reclaim faster than it resurrects...
-- TODO do more math to figure out how to perform it better?
function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if (zombies_to_spawn[featureID]) then
		local base_time = reclaimed_data[featureID]
		base_time[3] = base_time[3] - part
		zombies_to_spawn[featureID] = base_time[1] + base_time[2] * (1+base_time[3]) * 32
	end
	return true
end

-- in halloween gadget, sometimes giving order to unit would result in crash because unit happened to be dead at the time order was given
-- TODO probably same units in groups could get same orders...
local function BringingDownTheHeavens(unitID)
	local unitDefID = (not spGetUnitIsDead(unitID)) and spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end
	
	local rx,rz,ry
	local orders = {}
	local near_ally
	if (UnitDefs[unitDefID].canAttack) then
		near_ally = GetUnitNearestAlly(unitID, 300)
		if (near_ally) then
			if Spring.GetUnitCurrentCommand(near_ally) == CMD_GUARD then
				near_ally = nil -- i dont want chain guards...
			end
		end
	end
	local x,y,z = spGetUnitPosition(unitID)
	if (near_ally) and random(0, 5) < 4 then -- 60% chance to guard nearest ally
		orders[#orders + 1] = {CMD_GUARD, {near_ally}, 0}
	end
	for i = 1, random(10, 30) do
		rx = random(0, mapWidth)
		rz = random(0, mapHeight)
		ry = spGetGroundHeight(rx,rz)
		if IsTargetReallyReachable(unitID, rx, ry, rz, x, y, z) then
			orders[#orders+1] = {CMD_FIGHT, {rx, ry, rz}, CMD_OPT_SHIFT}
		end
	end
	if (#orders > 0) then
		if not spGetUnitIsDead(unitID) then
			spGiveOrderArrayToUnitArray({unitID},orders)
		end
	end
	if (UnitDefs[unitDefID].isFactory) then
		OpenAllClownSlots(unitID, unitDefID) -- give factory something to do
		zombies[unitID] = nil -- no need to update factory orders anymore
	end
end

local function CheckZombieOrders()	-- i can't rely on Idle because if for example unit is unloaded it doesnt count as idle... weird
	for unitID, _ in pairs(zombies) do
		local queueSize = spGetUnitCommandCount(unitID)
		if not (queueSize) or not (queueSize > 0) then -- oh
			BringingDownTheHeavens(unitID)
		end
	end
end

local function myGetFeatureRessurect(fId)
	local resName, face = spGetFeatureResurrect(fId)
	if resName == "" then
		local featureDef = FeatureDefs[Spring.GetFeatureDefID(fId)]
		local featureName = featureDef.name or ""
		if featureDef.resurrectable == 1 then
			resName = featureName:gsub('(.*)_.*', '%1') --filter out _dead
			face = face or 0
		end
	end
	return resName, face
end

function gadget:GameFrame(f)
	gameframe = f
	Spring.Echo("frame: " .. f)
	if (f%32) == 0 then
		local spSpawnCEG = Spring.SpawnCEG -- putting the localization here because cannot localize in global scope since spring 97
		local index = 1
		while index <= zombiesToSpawnCount do
			local featureID = zombiesToSpawnList[index]
			local time_to_spawn = zombies_to_spawn[featureID]
			local x, y, z = spGetFeaturePosition(featureID)

			if time_to_spawn <= f then
				if not RemoveZombieToSpawn(featureID) then
					index = index + 1
				end
				local resName, face = myGetFeatureRessurect(featureID)
				local partialReclaim = 1
				if ZOMBIES_PARTIAL_RECLAIM then
					local currentMetal, maxMetal = Spring.GetFeatureResources(featureID)
					if currentMetal and maxMetal and (maxMetal > 0) then
						partialReclaim = currentMetal/maxMetal
					end
				end
				spDestroyFeature(featureID)
				local unitID = spCreateUnit(resName, x, y, z, face, GaiaTeamID)
				if (unitID) then
					local size = UnitDefNames[resName].xsize
					spSpawnCEG("scav-spawnexplo", x, y, z, 0, 0, 0, size)
					Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, 3, 0)
					if partialReclaim ~= 1 then
						local health = Spring.GetUnitHealth(unitID)
						if health then
							Spring.SetUnitHealth(unitID, health*partialReclaim)
							--spSetUnitRulesParam(unitID, "zombie_partialReclaim", partialReclaim, PRIVATE_ACCESS)
						end
					end
				end
			else
				local steps_to_spawn = floor((time_to_spawn - f) / 32)
				local resName, face = myGetFeatureRessurect(featureID)
				if steps_to_spawn <= WARNING_TIME then
					local r = Spring.GetFeatureRadius(featureID)

					spSpawnCEG("scav-spawnexplo", x, y, z, 0, 0, 0, 10 + r, 10 + r)

					if steps_to_spawn == WARNING_TIME then
						local z_sound = ZOMBIE_SOUNDS[math.random(#ZOMBIE_SOUNDS)]
					end
				end
				index = index + 1
			end
		end
	end
	if (f%640) == 1 then
		-- CheckZombieOrders()
	end
	-- if f == 1 then
	-- 	spSetTeamResource(GaiaTeamID, "ms", 500)
	-- 	spSetTeamResource(GaiaTeamID, "es", 10500)
	-- end
end
-- settings gaiastorage before frame 1 somehow doesnt work, well i can guess why...

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if zombies[unitID] then
		zombies[unitID] = nil
	end
end

function gadget:UnitTaken(unitID, unitDefID, teamID, newTeamID)
	if zombies[unitID] and newTeamID ~= GaiaTeamID then
		zombies[unitID] = nil
		-- taking away zombie from zombie team unpermaslows it
		if ZOMBIES_PERMA_SLOW then
			SetZombieSlow(unitID, false)
		end
	elseif newTeamID == GaiaTeamID then
		gadget:UnitFinished(unitID, unitDefID, newTeamID)
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	gadget:UnitFinished(unitID, unitDefID, teamID)
end

local UnitFinished = function(_,_,_) end

function gadget:UnitFinished(unitID, unitDefID, teamID)
	UnitFinished(unitID, unitDefID, teamID)
end

function gadget:FeatureCreated(featureID, allyTeam)
	local resName, face = myGetFeatureRessurect(featureID)
	if resName and face and not zombies_to_spawn[featureID] then
		local ud = resName and UnitDefNames[resName]
		if ud and not NonZombies[resName] then
			local rez_time = ud.metalCost / ZOMBIES_REZ_SPEED
			if (rez_time < ZOMBIES_REZ_MIN) then
				  rez_time = ZOMBIES_REZ_MIN
			end
			reclaimed_data[featureID] = {gameframe, rez_time, 0}
			zombies_to_spawn[featureID] = gameframe + (rez_time*32)
			
			zombiesToSpawnCount = zombiesToSpawnCount + 1
			zombiesToSpawnList[zombiesToSpawnCount] = featureID
			zombiesToSpawnMap[featureID] = zombiesToSpawnCount
		end
	end
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	if (zombies_to_spawn[featureID]) then
		RemoveZombieToSpawn(featureID)
	end
end

local function ReInit(reinit)
	Spring.Echo("[Zombies ReInit] Starting ReInit, reinit param:", reinit)
	
	Spring.Echo("[Zombies ReInit] Setting map dimensions...")
	mapWidth = Game.mapSizeX
	mapHeight = Game.mapSizeZ
	Spring.Echo("[Zombies ReInit] Map dimensions set to:", mapWidth, "x", mapHeight)
	
	if not (defined) then
		Spring.Echo("[Zombies ReInit] First-time initialization...")
		UnitFinished = function(unitID, unitDefID, teamID, builderID)
			Spring.Echo("[Zombies ReInit] Processing new unit:", unitID, "team:", teamID)
			if (teamID == GaiaTeamID) and not (zombies[unitID]) then
				Spring.Echo("[Zombies ReInit] Unit is Gaia team and not already zombie, processing...")
				spGiveOrderToUnit(unitID, CMD_REPEAT, 1, 0)
				spGiveOrderToUnit(unitID, CMD_MOVE_STATE, 2, 0)
				BringingDownTheHeavens(unitID)
				zombies[unitID] = true
				if ZOMBIES_PERMA_SLOW then
					Spring.Echo("[Zombies ReInit] Applying perma-slow to zombie")
					local maxHealth = select(2, spGetUnitHealth(unitID))
					if maxHealth then
						SetZombieSlow(unitID, true)
					end
				end
			end
		end
		Spring.Echo("[Zombies ReInit] UnitFinished function defined")
		defined = true
	end
	
	if (reinit) then
		Spring.Echo("[Zombies ReInit] Performing full reinit...")
		gameframe = spGetGameFrame()
		Spring.Echo("[Zombies ReInit] Current gameframe:", gameframe)
		
		Spring.Echo("[Zombies ReInit] Processing existing units...")
		local units = spGetAllUnits()
		Spring.Echo("[Zombies ReInit] Found", #units, "existing units")
		for i = 1, #units do
			local unitID = units[i]
			local unitTeam = spGetUnitTeam(unitID)
			Spring.Echo("[Zombies ReInit] Checking unit:", unitID, "team:", unitTeam)
			if (unitTeam == GaiaTeamID) then
				Spring.Echo("[Zombies ReInit] Processing Gaia unit:", unitID)
				gadget:UnitFinished(unitID, spGetUnitDefID(unitID), unitTeam)
			end
		end
		
		Spring.Echo("[Zombies ReInit] Processing existing features...")
		local features = spGetAllFeatures()
		Spring.Echo("[Zombies ReInit] Found", #features, "existing features")
		for i = 1, #features do
			Spring.Echo("[Zombies ReInit] Processing feature:", features[i])
			gadget:FeatureCreated(features[i], 1)
		end
	end
	
	Spring.Echo("[Zombies ReInit] ReInit complete!")
end

function gadget:Initialize()
	Spring.Echo("[Zombies] Initializing zombie gadget...")
	
	if not GG.Zombies then
		Spring.Echo("[Zombies] Creating global Zombies table")
		GG.Zombies = {}
	end
	
	Spring.Echo("[Zombies] Setting up team IDs...")
	GaiaTeamID = Spring.GetGaiaTeamID()
	Spring.Echo("[Zombies] Gaia Team ID:", GaiaTeamID)
	
	Spring.Echo("[Zombies] Initializing data structures...")
	zombies_to_spawn = {}
	reclaimed_data = {}
	zombiesToSpawnList = {}
	zombiesToSpawnMap = {}
	zombiesToSpawnCount = 0
	Spring.Echo("[Zombies] Data structures initialized")
	
	Spring.Echo("[Zombies] Setting up unit arrays...")
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		Spring.Echo("[Zombies] Processing unit:", unitID, "DefID:", unitDefID)
		gadget:UnitFinished(unitID, unitDefID)
	end
	
	Spring.Echo("[Zombies] Initialization complete!")
end

function gadget:GameStart()
	Spring.Echo("reinit debug")
	ReInit(true) -- anything it does doesnt mess with existing zombies
end