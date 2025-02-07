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

local modOptions = Spring.GetModOptions()

local isScavengerGame = Spring.Utilities.Gametype.IsScavengers()
if (modOptions.zombies == false and not isScavengerGame) or (isScavengerGame and not table.contains(exemptDifficultyLevels, modOptions.scav_difficulty)) then
	return false
end

-- configs
local ZOMBIE_MAX_RESURRECTION_TIME = Game.gameSpeed * 3  -- Maximum time (in seconds) a unit can take to resurrect, regardless of cost
local ZOMBIE_GUARD_RADIUS = 300           -- How far zombies look for allies to guard (in units)
local ZOMBIE_ORDER_MIN = 10               -- Minimum number of random orders to give zombies
local ZOMBIE_ORDER_MAX = 30               -- Maximum number of random orders to give zombies
local ZOMBIE_GUARD_CHANCE = 0.6           -- Probability (0-1) that a zombie will guard nearby allies
local WARNING_TIME = 15 * Game.gameSpeed -- frames to start being scary before actual reanimation event

local ZOMBIES_REZ_MIN = tonumber(modOptions.zombies_delay)
local ZOMBIES_REZ_SPEED = tonumber(modOptions.zombies_rezspeed)
local ZOMBIES_PARTIAL_RECLAIM = modOptions.zombies_partial_reclaim

--localized functions
local spGetGroundHeight           = Spring.GetGroundHeight
local spGetUnitPosition           = Spring.GetUnitPosition
local spGetFeaturePosition        = Spring.GetFeaturePosition
local spCreateUnit                = Spring.CreateUnit
local spTransferUnit				  = Spring.TransferUnit
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
local spSetUnitHealth             = Spring.SetUnitHealth
local spSetUnitRulesParam         = Spring.SetUnitRulesParam
local spGetUnitRulesParam         = Spring.GetUnitRulesParam
local spGetFeatureDefID           = Spring.GetFeatureDefID
local spTestMoveOrder             = Spring.TestMoveOrder
local spSpawnCEG 					= Spring.SpawnCEG
local spGetFeatureResources 		= Spring.GetFeatureResources
local spGetFeatureHealth			= Spring.GetFeatureHealth
local spDestroyUnit 				= Spring.DestroyUnit
local spCreateFeature				= Spring.CreateFeature
local random = math.random
local function disSQ(x1, y1, x2, y2) return (x1 - x2)^2 + (y1 - y2)^2 end

--constants
local teams = Spring.GetTeamList()
local scavTeamID
if isScavengerGame then
	for _, teamID in ipairs(teams) do
		local teamLuaAI = Spring.GetTeamLuaAI(teamID)
		if (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
			scavTeamID = teamID
		end
	end
end

local GaiaTeamID = Spring.GetGaiaTeamID()
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


--tables
local zombieCorpseDefs = {}
local zombieWatch = {}
local corpseCheckFrames = {}
local corpsesData = {}
local zombieDefHeaps = {}

-- Populate zombieUnitDefs with units that have resurrectable _dead corpses
for unitDefID, unitDef in pairs(UnitDefs) do
	local corpseDefName = unitDef.name .. "_dead"
	if FeatureDefNames[corpseDefName] then
		local featureDefID = FeatureDefNames[corpseDefName].id
		local metalCost = unitDef.metalCost or 100 --fallback number chosen arbitrarily
		local spawnSeconds = math.floor(metalCost / ZOMBIES_REZ_SPEED)
		spawnSeconds = math.max(spawnSeconds, ZOMBIES_REZ_MIN)
		spawnSeconds = math.min(spawnSeconds, ZOMBIE_MAX_RESURRECTION_TIME)
		local spawnFrames = spawnSeconds * Game.gameSpeed

		zombieCorpseDefs[featureDefID] = {unitDefID = unitDefID, spawnDelayFrames = spawnFrames}
		local heapDefName = unitDef.name .. "_heap"
		if FeatureDefNames[heapDefName] then
			zombieDefHeaps[unitDefID] = {heap = FeatureDefNames[heapDefName].id, explosion = unitDef.explodeAs}
			Spring.Echo{"explodeAs", unitDef.explodeAs}
		end
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

	spSetTeamResource(GaiaTeamID, "ms", 500)
	spSetTeamResource(GaiaTeamID, "es", 10500)
end

local function GetUnitNearestAlly(unitID, unitDefID, range)
	local best_ally
	local best_dist
	local x, y, z = spGetUnitPosition(unitID)
	local units = spGetUnitsInCylinder(x, z, range)
	for i = 1, #units do
		local allyID = units[i]
		local allyTeam = spGetUnitTeam(allyID)
		if (allyID ~= unitID) and (allyTeam == GaiaTeamID) then -- and (getMovetype(UnitDefs[allyDefID]) ~= false)
			local ox, oy, oz = spGetUnitPosition(allyID)
			local dist = disSQ(x, z, ox ,oz)
			if spTestMoveOrder(unitDefID, ox, oy, oz) and ((best_dist == nil) or (dist < best_dist)) then
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
	for i = 1, random(ZOMBIE_ORDER_MIN, ZOMBIE_ORDER_MAX) do
		orders[#orders + 1] = {-buildopts[random(1, #buildopts)], 0, 0 }
	end
	if (#orders > 0) then
		if not spGetUnitIsDead(unitID) then
			spGiveOrderArrayToUnitArray({unitID}, orders)
		end
	end
end

local function warningCEG(featureID, x, y, z)
	local radius = Spring.GetFeatureRadius(featureID)

	local effects = {
		"scavmist",
		"scavradiation-lightning",
	}
	local selectedEffect = effects[random(#effects)]
	spSpawnCEG(selectedEffect, x, y, z, 0, 0, 0, radius * 0.25)
	spSpawnCEG("scaspawn-trail", x, y, z, 0, 0, 0, radius)
end

local function issueRandomOrders(unitID, unitDefID)
	if spGetUnitIsDead(unitID) then
		return
	end
	
	local randomX, randomY, randomZ
	local orders = {}
	local nearAlly
	if (UnitDefs[unitDefID].canAttack) then
		nearAlly = GetUnitNearestAlly(unitID, unitDefID, ZOMBIE_GUARD_RADIUS)
		if (nearAlly) then
			if Spring.GetUnitCurrentCommand(nearAlly) == CMD_GUARD then
				nearAlly = nil -- i dont want chain guards...
			end
		end
	end
	local unitX, unitY, unitZ = spGetUnitPosition(unitID)

	if (nearAlly) and random() < ZOMBIE_GUARD_CHANCE then
		orders[#orders + 1] = {CMD_GUARD, {nearAlly}, 0}
	end

	for i = 1, random(ZOMBIE_ORDER_MIN, ZOMBIE_ORDER_MAX) do
		randomX = random(0, mapWidth)
		randomZ = random(0, mapHeight)
		randomY = spGetGroundHeight(randomX, randomZ)

		if spTestMoveOrder(unitDefID, randomX, randomY, randomZ) then
			orders[#orders+1] = {CMD_FIGHT, {randomX, randomY, randomZ}, CMD_OPT_SHIFT}
		end
	end

	if (#orders > 0) then
		spGiveOrderArrayToUnitArray({unitID}, orders)
	end

	if (UnitDefs[unitDefID].isFactory) then
		issueRandomFactoryBuildOrders(unitID, unitDefID) -- give factory something to do
		zombieWatch[unitID] = nil -- no need to update factory orders anymore
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
					featureData.tamperedFrame = nil
					featureData.spawnFrame = newFrame
					corpsesToCheck[newFrame] = corpsesToCheck[newFrame] or {}
					corpsesToCheck[newFrame][#corpsesToCheck[newFrame] + 1] = featureID
				else
					local healthReductionRatio = 1
					if ZOMBIES_PARTIAL_RECLAIM then
						local partialReclaim = 1
						local currentMetal, maxMetal = spGetFeatureResources(featureID)
						if currentMetal and maxMetal and (maxMetal > 0) then
							partialReclaim = currentMetal/maxMetal
						end
						local health, maxHealth = spGetFeatureHealth(featureID)
						if health and maxHealth and (maxHealth > 0) then
							healthReductionRatio = health/maxHealth
						end
						healthReductionRatio = math.min(healthReductionRatio, partialReclaim)
					end
					local unitDefID = featureDefData.unitDefID
					local unitID = spCreateUnit(unitDefID, featureX, featureY, featureZ, 0, GaiaTeamID)
					spDestroyFeature(featureID)
					local unitHealth = spGetUnitHealth(unitID)
					spSetUnitHealth(unitID, unitHealth * healthReductionRatio)
					spSpawnCEG("scav-spawnexplo", featureX, featureY, featureZ, 0, 0, 0, UnitDefs[unitDefID].xsize)
					corpsesData[featureID] = nil
					if unitID then

						if scavTeamID then
							spTransferUnit(unitID, scavTeamID)
						else
							zombieWatch[unitID] = unitDefID
							spSetUnitRulesParam(unitID, "zombie", IS_ZOMBIE)
							issueRandomOrders(unitID, unitDefID)
						end
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
				warningCEG(featureID, featureX, featureY, featureZ)
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
				if not (queueSize) or (queueSize == 0) then
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
		corpsesData[featureID] = {featureDefID = featureDefID, spawnDelayFrames = spawnDelayFrames, creationFrame = gameFrame, spawnFrame = spawnFrame}
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

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID)
	if zombieWatch[unitID] then
		local health = spGetUnitHealth(unitID)
		Spring.Echo(health)
		if damage >= health then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			spDestroyUnit(unitID, true, true, attackerID)
			local heapDefID = zombieDefHeaps[unitDefID]
			local radius = Spring.GetUnitRadius(unitID)
			spSpawnCEG("scav-spawnexplo", unitX, unitY, unitZ, 0, 0, 0, radius)
			if heapDefID then
				spCreateFeature(heapDefID, unitX, unitY, unitZ)
			end
			Spring.Echo(heapDefID, unitX, unitY, unitZ)
		end
	end
end



function gadget:Initialize()
	mapWidth = Game.mapSizeX

	mapHeight = Game.mapSizeZ
	GaiaTeamID = Spring.GetGaiaTeamID()
	initiationFrame = spGetGameFrame() + 1 --to avoid race conditions
end