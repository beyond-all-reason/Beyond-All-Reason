function gadget:GetInfo()
	return {
		name      = "Corpse Revival",
		desc      = "Resurrects corpses as Scavengers or hostile Gaia",
		author    = "SethDGamre, code snippets/inspiration from Rafal",
		date      = "March 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 2,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local modOptions = Spring.GetModOptions()

if not modOptions.revival then
	return false
end

local ZOMBIE_GUARD_RADIUS = 300           -- Radius for zombies to guard allies
local ZOMBIE_ORDER_MIN = 5                -- Min random orders for zombies
local ZOMBIE_ORDER_MAX = 15               -- Max random orders for zombies
local ZOMBIE_GUARD_CHANCE = 0.65          -- Chance a zombie will guard allies
local WARNING_TIME = 15 * Game.gameSpeed  -- Frames to start warning before reanimation
local ZOMBIES_REZ_MIN = 30 				  -- in seconds
local ZOMBIE_REZ_MAX = 120 				  -- in seconds
local ZOMBIE_MAX_XP = 2					  -- Maximum experience value for zombies, skewed towards median

local ZOMBIES_REZ_SPEED = modOptions.revival_rezspeed
local ZOMBIES_COUNT_MULTIPLIER = modOptions.revival_count_multiplier

local ZOMBIE_ORDER_CHECK_INTERVAL = Game.gameSpeed * 10    -- How often (in frames) to check if zombies need new orders
local ZOMBIE_CHECK_INTERVAL = Game.gameSpeed    -- How often (in frames) everything else is checked

local CMD_REPEAT = CMD.REPEAT
local CMD_MOVE_STATE = CMD.MOVE_STATE
local CMD_FIGHT = CMD.FIGHT
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_GUARD = CMD.GUARD
local CMD_FIRE_STATE = CMD.FIRE_STATE

local ISNT_ZOMBIE = 0
local IS_ZOMBIE = 1

local spGetGroundHeight           = Spring.GetGroundHeight
local spGetUnitPosition           = Spring.GetUnitPosition
local spGetFeaturePosition        = Spring.GetFeaturePosition
local spCreateUnit                = Spring.CreateUnit
local spTransferUnit              = Spring.TransferUnit
local spGetUnitDefID              = Spring.GetUnitDefID
local spGetUnitTeam               = Spring.GetUnitTeam
local spGetAllUnits               = Spring.GetAllUnits
local spGetGameFrame              = Spring.GetGameFrame
local spGetAllFeatures            = Spring.GetAllFeatures
local spGiveOrderToUnit           = Spring.GiveOrderToUnit
local spGetUnitCommandCount       = Spring.GetUnitCommandCount
local spDestroyFeature            = Spring.DestroyFeature
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
local spSpawnCEG 				  = Spring.SpawnCEG
local spGetFeatureResources 	  = Spring.GetFeatureResources
local spGetFeatureHealth		  = Spring.GetFeatureHealth
local spDestroyUnit 			  = Spring.DestroyUnit
local spCreateFeature			  = Spring.CreateFeature
local spSpawnExplosion 			  = Spring.SpawnExplosion
local spPlaySoundFile 			  = Spring.PlaySoundFile
local spGetFeatureRadius		  = Spring.GetFeatureRadius
local spGetUnitCurrentCommand	  = Spring.GetUnitCurrentCommand
local spSetUnitExperience		  = Spring.SetUnitExperience
local random 					  = math.random
local distance2dSquared 		  = math.distance2dSquared

local teams = Spring.GetTeamList()
local scavTeamID
local gaiaTeamID = Spring.GetGaiaTeamID()
for _, teamID in ipairs(teams) do

	local teamLuaAI = Spring.GetTeamLuaAI(teamID)
	if (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
		scavTeamID = teamID
	end
end
local mapWidth
local mapHeight

local gameFrame = 0
local adjustedRezSpeed = ZOMBIES_REZ_SPEED

local zombieCorpseDefs = {}
local zombieWatch = {}
local corpseCheckFrames = {}
local corpsesData = {}
local zombieHeapDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	local corpseDefName = unitDef.corpse
	if FeatureDefNames[corpseDefName] then
		local corpseDefID = FeatureDefNames[corpseDefName].id
		local spawnSeconds = math.floor(unitDef.metalCost / adjustedRezSpeed)

		spawnSeconds = math.clamp(spawnSeconds, ZOMBIES_REZ_MIN, ZOMBIE_REZ_MAX)
		local spawnFrames = spawnSeconds * Game.gameSpeed
		zombieCorpseDefs[corpseDefID] = {unitDefID = unitDefID, spawnDelayFrames = spawnFrames}

		local zombieDefData = {}
		local deathExplosionName = unitDef.deathExplosion
		local explosionDefID = WeaponDefNames[deathExplosionName].id
		zombieDefData.explosionDefID = explosionDefID
		
		local heapDefName = FeatureDefs[corpseDefID].deathFeatureID
		if heapDefName then
			zombieDefData.heapDefID = heapDefName
		end

		zombieHeapDefs[unitDefID] = zombieDefData
	end
end

local function setGaiaStorage()
	local metalStorageToSet = 1000000
	local energyStorageToSet = 1000000

	local _, currentMetalStorage = Spring.GetTeamResources(gaiaTeamID, "metal")
	if currentMetalStorage and currentMetalStorage < metalStorageToSet then
		spSetTeamResource(gaiaTeamID, "ms", metalStorageToSet)
	end
	
	local _, currentEnergyStorage = Spring.GetTeamResources(gaiaTeamID, "energy")
	if currentEnergyStorage and currentEnergyStorage < energyStorageToSet then
		spSetTeamResource(gaiaTeamID, "es", energyStorageToSet)
	end
end

local function calculateHealthRatio(featureID)
	local partialReclaimRatio = 1
	local damagedReductionRatio = 1
	local currentMetal, maxMetal = spGetFeatureResources(featureID)
	if currentMetal and maxMetal and currentMetal ~= 0 and maxMetal ~= 0 then
		partialReclaimRatio = currentMetal/maxMetal
	end
	local health, maxHealth = spGetFeatureHealth(featureID)
	if health and maxHealth and health ~= 0 and maxHealth ~= 0 then
		damagedReductionRatio = health/maxHealth
	end
	local healthRatio = (partialReclaimRatio + damagedReductionRatio) * 0.5 --average the two ratios to skew the result towards maximum health
	return healthRatio
end

local function GetUnitNearestAlly(unitID, unitDefID, range)
	local bestAllyID
	local bestDistanceSquared
	local x, y, z = spGetUnitPosition(unitID)
	local units = spGetUnitsInCylinder(x, z, range)
	for i = 1, #units do
		local allyID = units[i]
		local allyTeam = spGetUnitTeam(allyID)
		local allyDefID = spGetUnitDefID(allyID)
		if (allyID ~= unitID) and (allyTeam == gaiaTeamID) and UnitDefs[allyDefID].canAttack and spGetUnitCurrentCommand(allyID) ~= CMD_GUARD then
			local ox, oy, oz = spGetUnitPosition(allyID)
			local currentDistanceSquared = distance2dSquared(x, z, ox, oz)
			if spTestMoveOrder(unitDefID, ox, oy, oz) and ((bestDistanceSquared == nil) or (currentDistanceSquared < bestDistanceSquared)) then
				bestAllyID = allyID
				bestDistanceSquared = currentDistanceSquared
			end
		end
	end
	return bestAllyID
end

local function issueRandomFactoryBuildOrders(unitID, unitDefID)
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
	local radius = spGetFeatureRadius(featureID)

	local effects = {
		"scavmist",
		"scavradiation-lightning",
	}
	local selectedEffect = effects[random(#effects)]
	spSpawnCEG(selectedEffect, x, y, z, 0, 0, 0, radius * 0.25)
	spSpawnCEG("scaspawn-trail", x, y, z, 0, 0, 0, radius)
end

local function playSpawnSound(x, y, z)
	local effects = {
		"xploelc2",
		"xploelc3",
	}
	local selectedEffect = effects[random(#effects)]
	spPlaySoundFile(selectedEffect, 0.5, x, y, z, 'sfx')
end

local function issueRandomOrders(unitID, unitDefID)
	if spGetUnitIsDead(unitID) then return end
	local unitDef = UnitDefs[unitDefID]
	
	local orders = {}
	local nearAlly = (unitDef.canAttack) and GetUnitNearestAlly(unitID, unitDefID, ZOMBIE_GUARD_RADIUS) or nil
	if nearAlly then
		if random() < ZOMBIE_GUARD_CHANCE then
			orders[#orders + 1] = {CMD_GUARD, {nearAlly}, 0}
		end
	end

	if unitDef.speed > 0 then
		for i = 1, random(ZOMBIE_ORDER_MIN, ZOMBIE_ORDER_MAX) do
			local randomX = random(0, mapWidth)
			local randomZ = random(0, mapHeight)
			local randomY = spGetGroundHeight(randomX, randomZ)

			if spTestMoveOrder(unitDefID, randomX, randomY, randomZ) then
				orders[#orders + 1] = {CMD_FIGHT, {randomX, randomY, randomZ}, CMD_OPT_SHIFT}
			end
		end
	elseif not unitDef.isFactory then
		orders[#orders + 1] = {CMD_FIGHT, {0, 0, 0}, CMD_OPT_SHIFT} --immobile units only need a single fight order
	end

	if #orders > 0 then
		spGiveOrderArrayToUnitArray({unitID}, orders)
	end

	if unitDef.isFactory then
		issueRandomFactoryBuildOrders(unitID, unitDefID)
	end
end

local function resetSpawn(featureID, featureData, featureDefData)
	local newFrame = featureData.tamperedFrame + featureDefData.spawnDelayFrames
	featureData.spawnFrame = newFrame
	featureData.creationFrame = featureData.tamperedFrame
	featureData.tamperedFrame = nil
	corpseCheckFrames[newFrame] = corpseCheckFrames[newFrame] or {}
	corpseCheckFrames[newFrame][#corpseCheckFrames[newFrame] + 1] = featureID
end

local function setZombieStates(unitID, unitDefID)
	local unitDef = UnitDefs[unitDefID]
	spGiveOrderToUnit(unitID, CMD_REPEAT, 1, 0)
	spGiveOrderToUnit(unitID, CMD_MOVE_STATE, 2, 0)
	spGiveOrderToUnit(unitID, CMD_FIRE_STATE, 2, 0)
end

local function spawnZombies(featureID, unitDefID, healthReductionRatio, x, y, z)
	local unitDef = UnitDefs[unitDefID]
	local spawnCount = unitDef.speed > 0 and ZOMBIES_COUNT_MULTIPLIER or 1 -- units that can't move will stay stacked, which is not desired
	local size = unitDef.xsize

	spDestroyFeature(featureID)
	corpsesData[featureID] = nil
	playSpawnSound(x, y, z)

	for i = 1, spawnCount do
		local randomX = x + random(-size * ZOMBIES_COUNT_MULTIPLIER, size * ZOMBIES_COUNT_MULTIPLIER)
		local randomZ = z + random(-size * ZOMBIES_COUNT_MULTIPLIER, size * ZOMBIES_COUNT_MULTIPLIER)
		local adjustedY = spGetGroundHeight(randomX, randomZ)

	
		local unitID = spCreateUnit(unitDefID, randomX, adjustedY, randomZ, 0, gaiaTeamID)
		if unitID then
			spSpawnCEG("scav-spawnexplo", randomX, adjustedY, randomZ, 0, 0, 0, unitDef.xsize)
			spSetUnitExperience(unitID, (random() * ZOMBIE_MAX_XP + random() * ZOMBIE_MAX_XP) / 2)
			local unitHealth = spGetUnitHealth(unitID)
			spSetUnitHealth(unitID, unitHealth * healthReductionRatio)
			spSetUnitRulesParam(unitID, "zombie", IS_ZOMBIE)

			if scavTeamID then
				spTransferUnit(unitID, scavTeamID)
			else
				zombieWatch[unitID] = unitDefID
				issueRandomOrders(unitID, unitDefID)
				setZombieStates(unitID, unitDefID)
			end
		end
	end
end

local function updateAdjustedRezSpeed()
    local multiplier = 2
    local highestPowerData = GG.PowerLib.HighestPlayerTeamPower()
    if highestPowerData and highestPowerData.power then
        adjustedRezSpeed = ZOMBIES_REZ_SPEED * GG.PowerLib.TechGuesstimate(highestPowerData.power) * multiplier
    end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local featureData = corpsesData[featureID]
	if featureData then
		featureData.tamperedFrame = gameFrame
	end
	return true
end

function gadget:GameFrame(frame)
	gameFrame = frame

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
				if featureData.tamperedFrame then
					resetSpawn(featureID, featureData, featureDefData)
				else
					local healthReductionRatio = calculateHealthRatio(featureID)
					spawnZombies(featureID, featureDefData.unitDefID, healthReductionRatio, featureX, featureY, featureZ)
				end
			end
			corpseCheckFrames[frame] = nil
		end
	end

	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		Spring.AddTeamResource(gaiaTeamID, "metal", 1000000)
		Spring.AddTeamResource(gaiaTeamID, "energy", 1000000)
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
		updateAdjustedRezSpeed()
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
	if unitTeam == gaiaTeamID then
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
		if damage >= health then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			local defData = zombieHeapDefs[unitDefID]
			spDestroyUnit(unitID, false, true, attackerID)
			spSpawnExplosion(unitX, unitY, unitZ, 0, 0, 0, {weaponDef = defData.explosionDefID} )
			if defData.heapDefID then
				spCreateFeature(defData.heapDefID, unitX, unitY, unitZ)
			end
		end
	end
end

function gadget:Initialize()
	mapWidth = Game.mapSizeX
	mapHeight = Game.mapSizeZ
	gameFrame = spGetGameFrame()
	local units = spGetAllUnits()
	for _, unitID in ipairs(units) do
		local identifiedZombie = spGetUnitRulesParam(unitID, "zombie")
		if identifiedZombie and identifiedZombie == IS_ZOMBIE then
			local unitDefID = spGetUnitDefID(unitID)
			zombieWatch[unitID] = unitDefID
			setZombieStates(unitID, unitDefID)
		end
	end
	
	local features = spGetAllFeatures()
	for _, featureID in ipairs(features) do
		gadget:FeatureCreated(featureID, gaiaTeamID)
	end
end

function gadget:GameStart()
	setGaiaStorage()
end