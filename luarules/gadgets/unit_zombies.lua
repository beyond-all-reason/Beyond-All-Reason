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
local livingZombies = {}

-- local ZOMBIE_SOUNDS = {
-- 	"sounds/misc/zombie_1.wav",
-- 	"sounds/misc/zombie_2.wav",
-- 	"sounds/misc/zombie_3.wav",
-- }

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
		if (allyID ~= unitID) and (allyTeam == GaiaTeamID) then
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

local function SendResurrectionProgress(featureID, progress)
    SendToUnsynced("featureresurrect", featureID, progress)
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
function GiveZombieRandomOrders(unitID)
    -- Add safety check for valid unit
    if not Spring.ValidUnitID(unitID) then
        return false
    end
    
    -- Get unit position for relative order generation
    local ux, uy, uz = Spring.GetUnitPosition(unitID)
    if not ux then return false end
    
    -- Generate multiple fight orders in a chain
    local orderParams = {}
    local numOrders = 4  -- Number of sequential orders to give
    
    for i=1, numOrders do
        -- Generate position within reasonable range of current position
        local range = 2000
        local tx = math.max(0, math.min(Game.mapSizeX, ux + math.random(-range, range)))
        local tz = math.max(0, math.min(Game.mapSizeZ, uz + math.random(-range, range)))
        local ty = Spring.GetGroundHeight(tx, tz)
        
        if tx and ty and tz then
            table.insert(orderParams, tx)
            table.insert(orderParams, ty)
            table.insert(orderParams, tz)
        end
    end
    
    -- Issue the chain of orders with shift modifier to queue them
    if #orderParams > 0 then
        local options = {"shift"}  -- Add shift modifier to queue orders
        if Spring.GiveOrderToUnit(unitID, CMD.FIGHT, orderParams, options) then
            return true
        end
    end
    
    return false
end

local function CheckZombieOrders()
    local zombiesToCheck = {}
    -- Create a separate list of zombies to check
    for unitID, _ in pairs(livingZombies) do
        zombiesToCheck[#zombiesToCheck + 1] = unitID
    end
    
    -- Iterate over the separate list
    for _, unitID in ipairs(zombiesToCheck) do
        if livingZombies[unitID] and Spring.ValidUnitID(unitID) then
            local commands = Spring.GetUnitCommands(unitID, -1)
            local queueSize = commands and #commands or 0
            
            -- Give new orders if queue is empty or nearly empty
            if queueSize < 2 then
                if not GiveZombieRandomOrders(unitID) then
                    livingZombies[unitID] = nil
                end
            end
        else
            livingZombies[unitID] = nil
        end
    end
end

local function myGetFeatureRessurect(fId)
	local resName, face = spGetFeatureResurrect(fId)
	if resName == "" then
		local featureDef = FeatureDefs[Spring.GetFeatureDefID(fId)]
		local featureName = featureDef.name or ""
		-- Check if feature is resurrectable
		if featureDef and featureDef.resurrectable == 1 then
			resName = featureName:gsub('(.*)_.*', '%1') --filter out _dead
			face = face or 0
		end
	end
	return resName, face
end

-- Set Gaia resource storage
local function SetGaiaResources()
    -- Give Gaia some storage
    Spring.SetTeamResource(GaiaTeamID, "ms", 999999)
    Spring.SetTeamResource(GaiaTeamID, "es", 999999)
    -- Give Gaia some resources
    Spring.SetTeamResource(GaiaTeamID, "m", 999999)
    Spring.SetTeamResource(GaiaTeamID, "e", 999999)
end

function gadget:Initialize()
    Spring.Echo("Zombie Gadget Initializing...")
    SetGaiaResources()
    
    if not modOptions or modOptions.zombies == false then
        Spring.Echo("Zombie Gadget disabled by mod options")
        gadgetHandler:RemoveGadget()
        return
    end
    
    Spring.Echo("Zombie Gadget: Basic initialization complete")
    
    -- Check if we're loading into an ongoing game
    local currentFrame = spGetGameFrame()
    if currentFrame > 1 then
        -- Initialize basic variables
        mapWidth = Game.mapSizeX
        mapHeight = Game.mapSizeZ
        if not defined then
            UnitFinished = function(unitID, unitDefID, teamID, builderID)
                if (teamID == GaiaTeamID) and not (zombies[unitID]) then
                    spGiveOrderToUnit(unitID, CMD_REPEAT, 1, 0)
                    spGiveOrderToUnit(unitID, CMD_MOVE_STATE, 2, 0)
                    GiveZombieRandomOrders(unitID)
                    zombies[unitID] = true
                end
            end
            defined = true
        end
        
        -- Set current gameframe
        gameframe = currentFrame
        
        -- Process existing units
        local units = spGetAllUnits()
        for i = 1, #units do
            local unitID = units[i]
            if unitID then
                local unitTeam = spGetUnitTeam(unitID)
                if unitTeam == GaiaTeamID then
                    local unitDefID = spGetUnitDefID(unitID)
                    if unitDefID then
                        gadget:UnitFinished(unitID, unitDefID, unitTeam)
                    end
                end
            end
        end
        
        -- Process existing features
        local features = spGetAllFeatures()
        for i = 1, #features do
            if features[i] then
                gadget:FeatureCreated(features[i], 1)
            end
        end
    end
end

-- Keep the GameFrame handler for new games
function gadget:GameFrame(f)
    if f == 1 and not defined then
        Spring.Echo("Zombie Gadget: First frame initialization")
        -- Initialize basic variables only
        mapWidth = Game.mapSizeX
        mapHeight = Game.mapSizeZ
        if not defined then
            UnitFinished = function(unitID, unitDefID, teamID, builderID)
                if (teamID == GaiaTeamID) and not (zombies[unitID]) then
                    spGiveOrderToUnit(unitID, CMD_REPEAT, 1, 0)
                    spGiveOrderToUnit(unitID, CMD_MOVE_STATE, 2, 0)
                    GiveZombieRandomOrders(unitID)
                    zombies[unitID] = true
                end
            end
            defined = true
        end
    end
    
    -- Update gameframe
    gameframe = f
    
    -- Log periodic checks
    if (f%32) == 0 then
        local zombieCount = 0
        for _ in pairs(livingZombies) do zombieCount = zombieCount + 1 end
        Spring.Echo("Zombie Gadget Frame " .. f .. ": Processing " .. zombiesToSpawnCount .. " pending zombies, " .. zombieCount .. " living zombies")
        
        for i = zombiesToSpawnCount, 1, -1 do
            local featureID = zombiesToSpawnList[i]
            if featureID and zombies_to_spawn[featureID] then
                Spring.Echo("Processing zombie spawn for feature: " .. featureID)
                -- Calculate and send progress
                local startFrame = reclaimed_data[featureID][1]
                local totalTime = zombies_to_spawn[featureID] - startFrame
                local currentTime = f - startFrame
                local progress = math.min(1, currentTime / totalTime)
                SendResurrectionProgress(featureID, progress)
                
                if zombies_to_spawn[featureID] <= f then
                    local resName, face = myGetFeatureRessurect(featureID)
                    if resName then
                        local x, y, z = spGetFeaturePosition(featureID)
                        if x and y and z then
                            -- Create the zombie unit
                            local unitID = spCreateUnit(resName, x, y, z, face, GaiaTeamID)
                            if unitID then
                                Spring.Echo("Successfully spawned zombie unit:", unitID)
                                
                                -- Add to living zombies list
                                livingZombies[unitID] = true
                                
                                -- Spawn CEG effect
                                Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0, 0, 0)
                                
                                -- Set fire state to 3 (Fire At Everything)
                                Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, {3}, 0)
                                
                                -- Give initial orders to the zombie
                                local nearestEnemy = Spring.GetUnitNearestEnemy(unitID, 999999, false)
                                if nearestEnemy then
                                    local tx, ty, tz = Spring.GetUnitPosition(nearestEnemy)
                                    if tx then
                                        Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
                                        Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {tx + math.random(-128, 128), ty, tz + math.random(-128, 128)}, {"shift"})
                                    end
                                else
                                    -- If no enemy found, move randomly from spawn position
                                    Spring.GiveOrderToUnit(unitID, CMD.MOVE, {x + math.random(-256, 256), y, z + math.random(-256, 256)}, {})
                                end
                                
                                -- Remove the feature
                                spDestroyFeature(featureID)
                                RemoveZombieToSpawn(featureID)
                                
                                -- Initialize the new zombie
                                gadget:UnitFinished(unitID, UnitDefNames[resName].id, GaiaTeamID)
                            end
                        end
                    end
                end
            end
        end
    end
    
    if (f%640) == 1 then
        Spring.Echo("Checking orders for all living zombies")
        CheckZombieOrders()
    end
    
    -- Every 2 seconds, check for abandoned resurrections
    if (f%60) == 0 then
        -- Get all features
        local features = Spring.GetAllFeatures()
        for _, featureID in ipairs(features) do
            -- If not already in our queue
            if not zombies_to_spawn[featureID] then
                local resName, face = myGetFeatureRessurect(featureID)
                -- Check if feature is being actively resurrected
                local resName_active, _ = Spring.GetFeatureResurrect(featureID)
                
                if resName and face and resName_active == "" then
                    local ud = resName and UnitDefNames[resName]
                    if ud and not NonZombies[resName] then
                        -- Use constant resurrection time
                        local rez_time = ZOMBIES_REZ_MIN
                        reclaimed_data[featureID] = {f, rez_time, 0}
                        zombies_to_spawn[featureID] = f + (rez_time * 32)
                        
                        zombiesToSpawnCount = zombiesToSpawnCount + 1
                        zombiesToSpawnList[zombiesToSpawnCount] = featureID
                        zombiesToSpawnMap[featureID] = zombiesToSpawnCount
                    end
                end
            end
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if zombies[unitID] then
		zombies[unitID] = nil
	end
end

function gadget:UnitTaken(unitID, unitDefID, teamID, newTeamID)
	if zombies[unitID] and newTeamID ~= GaiaTeamID then
		zombies[unitID] = nil
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
    Spring.Echo("Feature created: " .. featureID .. ", checking if it can become a zombie")
    
    local resName, face = myGetFeatureRessurect(featureID)
    if resName then
        Spring.Echo("Feature " .. featureID .. " can be resurrected as: " .. resName)
    end
    
    if resName and face and not zombies_to_spawn[featureID] then
        local ud = resName and UnitDefNames[resName]
        if ud and not NonZombies[resName] then
            Spring.Echo("Adding feature " .. featureID .. " to zombie spawn queue")
            -- Use constant resurrection time
            local rez_time = ZOMBIES_REZ_MIN
            reclaimed_data[featureID] = {gameframe, rez_time, 0}
            zombies_to_spawn[featureID] = gameframe + (rez_time * 32)
            
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