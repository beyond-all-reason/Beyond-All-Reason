function gadget:GetInfo()
	return {
		name    = "Zombies",
		desc    = "Resurrects corpses as Scavengers or hostile Gaia Zombies",
		author  = "SethDGamre, code snippets/inspiration from Rafal",
		date    = "March 2024",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local modOptions                  = Spring.GetModOptions()

local ZOMBIE_GUARD_RADIUS         = 300  -- Radius for zombies to guard allies
local ZOMBIE_MAX_ORDER_ATTEMPTS   = 10
local ZOMBIE_MAX_ORDERS_ISSUED    = 2
local ZOMBIE_FACTORY_BUILD_COUNT  = 20
local ZOMBIE_GUARD_CHANCE         = 0.65 -- Chance a zombie will guard allies
local WARNING_TIME                = 15 * Game.gameSpeed -- Frames to start warning before reanimation

local ZOMBIE_MAX_XP               = 2    -- Maximum experience value for zombies, skewed towards median

local zombieModeConfigs           = {
	normal = {
		rezSpeed = 16,
		rezMin = 60,
		rezMax = 180,
		countMin = 1,
		countMax = 1
	},
	hard = {
		rezSpeed = 24,
		rezMin = 30,
		rezMax = 90,
		countMin = 1,
		countMax = 1
	},
	nightmare = {
		rezSpeed = 24,
		rezMin = 30,
		rezMax = 90,
		countMin = 2,
		countMax = 5
	},
	extreme = {
		rezSpeed = 48,
		rezMin = 30,
		rezMax = 45,
		countMin = 4,
		countMax = 10
	}
}

local currentZombieMode           = "normal"
local currentZombieConfig         = zombieModeConfigs.normal

local ZOMBIE_ORDER_CHECK_INTERVAL = Game.gameSpeed * 3 -- How often (in frames) to check if zombies need new orders
local ZOMBIE_CHECK_INTERVAL       = Game.gameSpeed     -- How often (in frames) everything else is checked
local STUCK_CHECK_INTERVAL        = Game.gameSpeed * 12 -- How often (in frames) to check if zombies are stuck

local STUCK_DISTANCE              = 50                 -- How far (in units) a zombie can move before being considered stuck
local MAX_NOGO_ZONES              = 10                 -- How many no-go zones a zombie can have before being considered stuck
local NOGO_ZONE_RADIUS            = 600                -- How far (in units) a no-go zone is
local ENEMY_ATTACK_DISTANCE       = 1000                -- How far (in units) a zombie will detect and choose to attack an enemy
local ORDER_DISTANCE              = 800                -- How far (in units) a zombie moves per order

local CMD_REPEAT                  = CMD.REPEAT
local CMD_MOVE_STATE              = CMD.MOVE_STATE
local CMD_GUARD                   = CMD.GUARD
local CMD_FIRE_STATE              = CMD.FIRE_STATE
local CMD_MOVE                    = CMD.MOVE
local CMD_RECLAIM                 = CMD.RECLAIM
local CMD_FIGHT                   = CMD.FIGHT
local CMD_OPT_SHIFT               = {"shift"}

local FIRE_STATE_FIRE_AT_ALL      = 3
local FIRE_STATE_RETURN_FIRE      = 1
local MOVE_STATE_HOLD_POSITION    = 0
local ENABLE_REPEAT               = 1
local NULL_ATTACKER               = -1
local ENVIRONMENTAL_DAMAGE_ID     = Game.envDamageTypes.GroundCollision
local UNAUTHORIZED_TEXT           = "You are not authorized to use zombie commands" --i18n library doesn't exist in gadget space.

local MAP_SIZE_X                  = Game.mapSizeX
local MAP_SIZE_Z                  = Game.mapSizeZ

local spGetUnitRotation           = Spring.GetUnitRotation
local spGetUnitNearestEnemy       = Spring.GetUnitNearestEnemy
local spValidUnitID               = Spring.ValidUnitID
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
local spGiveOrderArrayToUnit      = Spring.GiveOrderArrayToUnit
local spGetUnitsInCylinder        = Spring.GetUnitsInCylinder
local spSetTeamResource           = Spring.SetTeamResource
local spGetUnitHealth             = Spring.GetUnitHealth
local spSetUnitHealth             = Spring.SetUnitHealth
local spSetUnitRulesParam         = Spring.SetUnitRulesParam
local spGetUnitRulesParam         = Spring.GetUnitRulesParam
local spGetFeatureDefID           = Spring.GetFeatureDefID
local spTestMoveOrder             = Spring.TestMoveOrder
local spSpawnCEG                  = Spring.SpawnCEG
local spGetFeatureResources       = Spring.GetFeatureResources
local spGetFeatureHealth          = Spring.GetFeatureHealth
local spDestroyUnit               = Spring.DestroyUnit
local spGetUnitDirection          = Spring.GetUnitDirection
local spCreateFeature             = Spring.CreateFeature
local spSpawnExplosion            = Spring.SpawnExplosion
local spPlaySoundFile             = Spring.PlaySoundFile
local spGetFeatureRadius          = Spring.GetFeatureRadius
local spGetUnitCurrentCommand     = Spring.GetUnitCurrentCommand
local spSetUnitExperience         = Spring.SetUnitExperience
local spGetUnitExperience         = Spring.GetUnitExperience
local spGetUnitIsBeingBuilt      = Spring.GetUnitIsBeingBuilt
local spGetUnitHeight           = Spring.GetUnitHeight
local random                      = math.random
local distance2dSquared           = math.distance2dSquared
local pi                          = math.pi
local tau                         = 2 * pi
local cos                         = math.cos
local sin                         = math.sin
local floor                       = math.floor
local clamp                       = math.clamp
local ceil                        = math.ceil

local teams                       = Spring.GetTeamList()
local scavTeamID
local gaiaTeamID                  = Spring.GetGaiaTeamID()
for _, teamID in ipairs(teams) do
	local teamLuaAI = Spring.GetTeamLuaAI(teamID)
	if (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
		scavTeamID = teamID
	end
end

local ordersEnabled = true
local gameFrame = 0
local adjustedRezSpeed = currentZombieConfig.rezSpeed
local isIdleMode = false
local autoSpawningEnabled = true
local debugMode = false

local extraDefs = {}
local factoriesWithCombatOptions = {}
local zombiesBeingBuilt = {}
local zombieCorpseDefs = {}
local zombieWatch = {}
local corpseCheckFrames = {}
local corpsesData = {}
local zombieHeapDefs = {}
local fightingDefs = {}
local unitDefWithWeaponRanges = {}
local repairingUnits = {}
local aaOnlyUnits = {}
local antiUnderWaterOnlyUnits = {}
local flyingUnits = {}
local unitDefs = UnitDefs
local unitDefNames = UnitDefNames
local featureDefNames = FeatureDefNames
local featureDefs = FeatureDefs

local warningEffects = {
	"scavmist",
	"scavradiation-lightning",
}
local spawnEffects = {
	"xploelc2",
	"xploelc3",
}

for unitDefID, unitDef in pairs(unitDefs) do
	local corpseDefName = unitDef.corpse
	if featureDefNames[corpseDefName] then
		local corpseDefID = featureDefNames[corpseDefName].id
		local spawnSeconds = floor(unitDef.metalCost / adjustedRezSpeed)

		spawnSeconds = clamp(spawnSeconds, currentZombieConfig.rezMin, currentZombieConfig.rezMax)
		local spawnFrames = spawnSeconds * Game.gameSpeed
		zombieCorpseDefs[corpseDefID] = { unitDefID = unitDefID, spawnDelayFrames = spawnFrames }

		local zombieDefData = {}
		local deathExplosionName = unitDef.deathExplosion
		local explosionDefID = WeaponDefNames[deathExplosionName].id
		zombieDefData.explosionDefID = explosionDefID

		local heapDefName = featureDefs[corpseDefID].deathFeatureID
		if heapDefName then
			zombieDefData.heapDefID = heapDefName
		end

		zombieHeapDefs[unitDefID] = zombieDefData
	end

	if unitDef.weapons and #unitDef.weapons > 0 then
		for i = 1, #unitDef.weapons do
			local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
			if weaponDef and weaponDef.range and weaponDef.range > 0 then
				unitDefWithWeaponRanges[unitDefID] = weaponDef.range
				break
			end
		end
	end

	if unitDef.canFight then
		fightingDefs[unitDefID] = true
	end

	if unitDef.canRepair then
		repairingUnits[unitDefID] = true
	end

	if unitDef.weapons and #unitDef.weapons > 0 then
		local hasWeapons = false
		local allWeaponsAA = true
		local allWeaponsUnderwater = true
		local hasNonUnderwaterWeapons = false

		for i = 1, #unitDef.weapons do
			local weaponDefID = unitDef.weapons[i].weaponDef
			if weaponDefID then
				local weaponDef = WeaponDefs[weaponDefID]
				if weaponDef and weaponDef.range and weaponDef.range > 0 and not (weaponDef.customParams and weaponDef.customParams.bogus) then
					hasWeapons = true

					local isAAWeapon = false
					if unitDef.weapons[i].onlyTargets and unitDef.weapons[i].onlyTargets.vtol then
						isAAWeapon = true
					end

					local isUnderwaterOnly = weaponDef.waterWeapon or false

					if not isAAWeapon then
						allWeaponsAA = false
					end

					if not isUnderwaterOnly then
						allWeaponsUnderwater = false
						hasNonUnderwaterWeapons = true
					end
				end
			end
		end

		if hasWeapons and allWeaponsAA then
			aaOnlyUnits[unitDefID] = true
		end

		if hasWeapons and allWeaponsUnderwater and not hasNonUnderwaterWeapons then
			antiUnderWaterOnlyUnits[unitDefID] = true
		end
	end
end

for unitDefID, unitDef in pairs(unitDefs) do
	extraDefs[unitDefID] = {}
	if unitDef.speed > 0 then
		extraDefs[unitDefID].isMobile = true
	elseif #unitDef.buildOptions > 0 then
		local combatOptions = {}
		for i = 1, #unitDef.buildOptions do
			local optionDefID = unitDef.buildOptions[i]
			if unitDefWithWeaponRanges[optionDefID] then
				combatOptions[#combatOptions + 1] = optionDefID
			end
		end
		if #combatOptions > 0 then
			factoriesWithCombatOptions[unitDefID] = combatOptions
		end
	end
end

local function initializeZombie(unitID, unitDefID)
	local x, y, z = spGetUnitPosition(unitID)
	zombieWatch[unitID] = { unitDefID = unitDefID, lastLocation = { x = x, y = y, z = z }, noGoZones = {}, isStuck = false }
end

local function isZombie(unitID)
	local isZombieRulesParam = spGetUnitRulesParam(unitID, "zombie")
	return isZombieRulesParam and isZombieRulesParam == 1
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

local function updateAdjustedRezSpeed()
	local techGuesstimateMultiplier = 2
	if GG.PowerLib and GG.PowerLib.HighestPlayerTeamPower and GG.PowerLib.TechGuesstimate then
		local highestPowerData = GG.PowerLib.HighestPlayerTeamPower()
		if highestPowerData and highestPowerData.power then
			adjustedRezSpeed = currentZombieConfig.rezSpeed * GG.PowerLib.TechGuesstimate(highestPowerData.power) *
			techGuesstimateMultiplier
		end
	end
end

local function applyZombieModeSettings(mode)
	local config = zombieModeConfigs[mode]
	if not config then
		config = zombieModeConfigs.normal
	end

	currentZombieMode = mode
	currentZombieConfig = config

	updateAdjustedRezSpeed()
end

local function calculateHealthRatio(featureID)
	local partialReclaimRatio = 1
	local damagedReductionRatio = 1
	local currentMetal, maxMetal = spGetFeatureResources(featureID)
	if currentMetal and maxMetal and currentMetal ~= 0 and maxMetal ~= 0 then
		partialReclaimRatio = currentMetal / maxMetal
	end
	local health, maxHealth = spGetFeatureHealth(featureID)
	if health and maxHealth and health ~= 0 and maxHealth ~= 0 then
		damagedReductionRatio = health / maxHealth
	end
	local healthRatio = (partialReclaimRatio + damagedReductionRatio) * 0.5 --average the two ratios to skew the result towards maximum health
	return healthRatio
end

--we use this instead of spGetUnitNearestAlly to make sure the unit is not guarding something on terrain it cannot traverse (like boats/land)
local function GetUnitNearestReachableAlly(unitID, unitDefID, range)
	local bestAllyID
	local bestDistanceSquared
	local x, y, z = spGetUnitPosition(unitID)
	if not x or not z then
		return nil
	end

	local readAsGaia = { ctrl = gaiaTeamID, read = gaiaTeamID, select = gaiaTeamID }
	local gaiaUnits = CallAsTeam(readAsGaia, spGetUnitsInCylinder, x, z, range, ALLIES)

	for i = 1, #gaiaUnits do
		local allyID = gaiaUnits[i]
		local allyDefID = spGetUnitDefID(allyID)
		local currentCommand = spGetUnitCurrentCommand(allyID)
		if (allyID ~= unitID) and fightingDefs[allyDefID] and currentCommand ~= CMD_GUARD and extraDefs[allyDefID].isMobile and not spGetUnitIsBeingBuilt(unitID) then
			local ox, oy, oz = spGetUnitPosition(allyID)
			if ox and oy and oz then
				local currentDistanceSquared = distance2dSquared(x, z, ox, oz)
				if spTestMoveOrder(unitDefID, ox, oy, oz) and ((bestDistanceSquared == nil) or (currentDistanceSquared < bestDistanceSquared)) then
					bestAllyID = allyID
					bestDistanceSquared = currentDistanceSquared
				end
			end
		end
	end
	return bestAllyID
end

local function issueRandomFactoryBuildOrders(unitID, unitDefID)
	local combatOptions = factoriesWithCombatOptions[unitDefID]

	if not combatOptions or #combatOptions == 0 then
		return
	end

	local builds = {}
	for i = 1, ZOMBIE_FACTORY_BUILD_COUNT do
		builds[#builds + 1] = { -combatOptions[random(1, #combatOptions)], 0, 0 }
	end

	if (#builds > 0) then
		spGiveOrderArrayToUnit(unitID, builds)
	end
end

local function warningCEG(featureID, x, y, z)
	local radius = spGetFeatureRadius(featureID)

	local selectedEffect = warningEffects[random(#warningEffects)]
	spSpawnCEG(selectedEffect, x, y, z, 0, 0, 0, radius * 0.25)
	spSpawnCEG("scaspawn-trail", x, y, z, 0, 0, 0, radius)
end

local function playSpawnSound(x, y, z)
	local selectedEffect = spawnEffects[random(#spawnEffects)]
	spPlaySoundFile(selectedEffect, 0.5, x, y, z, 0)
end

-- for some reason, engine gives us the LEFT direction as the yaw instead of the forwards direction. This gets and corrects it.
local function getActualForwardsYaw(unitID)
	return select(2, spGetUnitRotation(unitID)) + (pi / 2)
end

local function canAttackTarget(attackerID, attackerDefID, targetID, targetYPosition)
	if aaOnlyUnits[attackerDefID] then
		local targetDef = unitDefs[targetID]
		if targetDef and targetDef.canFly and aaOnlyUnits[attackerDefID] then
			return true
		end
	elseif antiUnderWaterOnlyUnits[attackerDefID] then
		if targetYPosition <= 0 then
			return true
		end
	elseif targetYPosition + spGetUnitHeight(targetID) >= 0 and not flyingUnits[targetID] then
		return true
	end
	return false
end

local function updateOrders(unitID, unitDefID, closestKnownEnemy, currentCommand)
	if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
		zombieWatch[unitID] = nil
		return
	end
	local isAlreadyGuarding = currentCommand and currentCommand == CMD_GUARD
	local nearAlly = currentCommand ~= CMD_MOVE and not isAlreadyGuarding and fightingDefs[unitDefID] and
	GetUnitNearestReachableAlly(unitID, unitDefID, ZOMBIE_GUARD_RADIUS) or nil
	local weaponRange = unitDefWithWeaponRanges[unitDefID]
	local data = zombieWatch[unitID]
	
	if repairingUnits[unitDefID] and closestKnownEnemy and not data.isStuck then
		local enemyDefID = spGetUnitDefID(closestKnownEnemy)
		if enemyDefID and unitDefs[enemyDefID].reclaimable then
			spGiveOrderToUnit(unitID, CMD_RECLAIM, { closestKnownEnemy }, 0)
		else
			data.isStuck = true
		end
	elseif not data.isStuck and nearAlly and not closestKnownEnemy and random() < ZOMBIE_GUARD_CHANCE then
		spGiveOrderToUnit(unitID, CMD_GUARD, { nearAlly }, 0)
	elseif extraDefs[unitDefID].isMobile then
		local x, y, z = spGetUnitPosition(unitID)
		local ordersIssued = 0
		for attempts = 1, ZOMBIE_MAX_ORDER_ATTEMPTS do
			local inNoGoZone = false
			if not data.isStuck and closestKnownEnemy and weaponRange then
				local enemyX, enemyY, enemyZ = spGetUnitPosition(closestKnownEnemy)
				if enemyX and canAttackTarget(unitID, unitDefID, closestKnownEnemy, enemyY) then
					local CLOSER_VARIANCE = 0.5
					weaponRange = weaponRange * CLOSER_VARIANCE
					local dx = x - enemyX
					local dz = z - enemyZ

					local distance = math.sqrt(dx * dx + dz * dz)

					if distance > 0 then
						local normalizedDx = dx / distance
						local normalizedDz = dz / distance

						attemptX = enemyX + normalizedDx * weaponRange
						attemptZ = enemyZ + normalizedDz * weaponRange
						attemptY = spGetGroundHeight(attemptX, attemptZ)
					end
				end
				closestKnownEnemy = nil
			else
				if isAlreadyGuarding then
					break
				end
				if data.isStuck or attempts == ZOMBIE_MAX_ORDER_ATTEMPTS then
					local randomAngle = random() * tau
					attemptX = x + ORDER_DISTANCE * cos(randomAngle)
					attemptZ = z + ORDER_DISTANCE * sin(randomAngle)
				else
					local ANGLE_COMPOUNDER = 1.5
					local biasDirection = (random() > 0.5) and 1 or -1
					local baseAngleOffset = pi / 4
					local angleOffset = baseAngleOffset * (ANGLE_COMPOUNDER ^ (attempts - 1))
					local movementAngle = getActualForwardsYaw(unitID) + (biasDirection * angleOffset)

					attemptX = x + ORDER_DISTANCE * cos(movementAngle)
					attemptZ = z + ORDER_DISTANCE * sin(movementAngle)
				end

				if attemptX < 0 or attemptX > MAP_SIZE_X or attemptZ < 0 or attemptZ > MAP_SIZE_Z then
					data.isStuck = true
				end

				attemptY = spGetGroundHeight(attemptX, attemptZ)
			end
			for _, zone in ipairs(data.noGoZones) do
				local dx = attemptX - zone.x
				local dz = attemptZ - zone.z
				if (dx * dx + dz * dz) < (NOGO_ZONE_RADIUS * NOGO_ZONE_RADIUS) then
					inNoGoZone = true
					break
				end
			end
			if attemptX then
				local POSITION_VARIANCE = 50
				attemptX = attemptX + random(-POSITION_VARIANCE, POSITION_VARIANCE)
				attemptZ = attemptZ + random(-POSITION_VARIANCE, POSITION_VARIANCE)
				if not inNoGoZone and spTestMoveOrder(unitDefID, attemptX, attemptY, attemptZ) then
					spGiveOrderToUnit(unitID, CMD_MOVE, { attemptX, attemptY, attemptZ }, CMD_OPT_SHIFT)
					ordersIssued = ordersIssued + 1
					if ordersIssued >= ZOMBIE_MAX_ORDERS_ISSUED then
						break
					end
				end
			end
		end
	end

	if factoriesWithCombatOptions[unitDefID] then
		local factoryCommands = Spring.GetFactoryCommands(unitID, -1) or {}
		local currentCommandCount = #factoryCommands
		if currentCommandCount < ZOMBIE_FACTORY_BUILD_COUNT then
			issueRandomFactoryBuildOrders(unitID, unitDefID)
		end
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

local function getScavVariantUnitDefID(unitDefID)
	local unitDef = unitDefs[unitDefID]
	if not unitDef then
		return unitDefID
	end

	if string.find(unitDef.name, "_scav") then
		return unitDefID
	end

	local scavUnitDefName = unitDef.name .. "_scav"
	local scavUnitDef = unitDefNames[scavUnitDefName]
	return scavUnitDef and scavUnitDef.id or unitDefID
end

local function setZombieStates(unitID, unitDefID)
	if factoriesWithCombatOptions[unitDefID] then
		spGiveOrderToUnit(unitID, CMD_REPEAT, ENABLE_REPEAT, 0)
	end
	spGiveOrderToUnit(unitID, CMD_MOVE_STATE, MOVE_STATE_HOLD_POSITION, 0)
	if ordersEnabled then
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, FIRE_STATE_FIRE_AT_ALL, 0)
	else
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, FIRE_STATE_RETURN_FIRE, 0)
	end
	spSetUnitRulesParam(unitID, "resurrected", 0, { inlos = true })
end

local function spawnZombies(featureID, unitDefID, healthReductionRatio, x, y, z)
	local unitDef = unitDefs[unitDefID]
	local spawnCount = 1
	if extraDefs[unitDefID].isMobile then
		--We bias downwards because lower values are preferred, it should be uncommon to find strong zombies but still possible
		spawnCount = floor((random(currentZombieConfig.countMin, currentZombieConfig.countMax) + random(currentZombieConfig.countMin,
			currentZombieConfig.countMax)) / 2) --skew results towards average to produce better gameplay
	end
	local size = unitDef.xsize

	spDestroyFeature(featureID)
	corpsesData[featureID] = nil
	playSpawnSound(x, y, z)

	for i = 1, spawnCount do
		local randomX = x + random(-size * spawnCount, size * spawnCount)
		local randomZ = z + random(-size * spawnCount, size * spawnCount)
		local adjustedY = spGetGroundHeight(randomX, randomZ)

		local unitDefToCreate = getScavVariantUnitDefID(unitDefID)
		local unitID = spCreateUnit(unitDefToCreate, randomX, adjustedY, randomZ, 0, gaiaTeamID)
		if unitID then
			local size = ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
			local sizeName = "small"
			if size > 4.5 then
				sizeName = "huge"
			elseif size > 3.5 then
				sizeName = "large"
			elseif size > 2.5 then
				sizeName = "medium"
			elseif size > 1.5 then
				sizeName = "small"
			else
				sizeName = "tiny"
			end
			spSpawnCEG("scav-spawnexplo-" .. sizeName, randomX, adjustedY, randomZ, 0, 0, 0)
			if modOptions.zombies ~= "normal" then
				spSetUnitExperience(unitID, (random() * ZOMBIE_MAX_XP + random() * ZOMBIE_MAX_XP) / 2) -- to skew the experience towards the median
			end
			local unitHealth = spGetUnitHealth(unitID)
			spSetUnitHealth(unitID, unitHealth * healthReductionRatio)
			spSetUnitRulesParam(unitID, "zombie", 1)
			if scavTeamID then
				spTransferUnit(unitID, scavTeamID)
			else
				initializeZombie(unitID, unitDefID)
				if ordersEnabled then
					local closestKnownEnemy = spGetUnitNearestEnemy(unitID, ENEMY_ATTACK_DISTANCE, true)
					local currentCommand = spGetUnitCurrentCommand(unitID)
					updateOrders(unitID, unitDefToCreate, closestKnownEnemy, currentCommand)
				end
				setZombieStates(unitID, unitDefID)
			end
		end
	end
end

local function setZombie(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end

	local scavUnitDefID = getScavVariantUnitDefID(unitDefID)

	-- If we need to convert to _scav variant
	if scavUnitDefID ~= unitDefID then
		local x, y, z = spGetUnitPosition(unitID)
		local facing = spGetUnitDirection(unitID)
		local teamID = spGetUnitTeam(unitID)
		local newUnitID
		if x and facing and teamID then
			newUnitID = spCreateUnit(scavUnitDefID, x, y, z, facing, teamID)
		end
		if newUnitID then
			local health, maxHealth = spGetUnitHealth(unitID)
			if health and maxHealth then
				local originalHealthRatio = health / maxHealth
				spSetUnitHealth(newUnitID, originalHealthRatio * maxHealth)
			end
			local experience = spGetUnitExperience(unitID)
			spSetUnitExperience(newUnitID, experience)

			spDestroyUnit(unitID, false, true)

			unitID = newUnitID
			unitDefID = scavUnitDefID
		end
	end

	spSetUnitRulesParam(unitID, "zombie", 1)
	initializeZombie(unitID, unitDefID)
	setZombieStates(unitID, unitDefID)
end

local function clearUnitOrders(unitID)
	if spValidUnitID(unitID) then
		spGiveOrderToUnit(unitID, CMD.STOP, {}, {})
	end
end

local function clearAllOrders()
	for zombieID, _ in pairs(zombieWatch) do
		clearUnitOrders(zombieID)
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local featureData = corpsesData[featureID]
	if featureData then
		featureData.tamperedFrame = gameFrame
	end
	return true
end

function UnitEnteredAir(unitID)
	flyingUnits[unitID] = true
end

function UnitLeftAir(unitID)
	flyingUnits[unitID] = nil
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
			else        --feature is still there
				local featureDefData = zombieCorpseDefs[corpseData.featureDefID]
				if corpseData.tamperedFrame then
					resetSpawn(featureID, corpseData, featureDefData)
				else
					local healthReductionRatio = calculateHealthRatio(featureID)
					spawnZombies(featureID, featureDefData.unitDefID, healthReductionRatio, featureX, featureY, featureZ)
				end
			end
		end
		corpseCheckFrames[frame] = nil
	end

	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		Spring.AddTeamResource(gaiaTeamID, "metal", 1000000)
		Spring.AddTeamResource(gaiaTeamID, "energy", 1000000)
		for featureID, featureData in pairs(corpsesData) do
			local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
			if not featureX then --doesn't exist anymore
				corpsesData[featureID] = nil
			elseif featureData.spawnFrame - frame < WARNING_TIME then
				if not featureData.tamperedFrame then
					warningCEG(featureID, featureX, featureY, featureZ)
				end
			end
		end
	end

	if frame % ZOMBIE_ORDER_CHECK_INTERVAL == 1 then
		for unitID, data in pairs(zombieWatch) do
			local unitDefID = data.unitDefID
			if spGetUnitIsDead(unitID) or not spValidUnitID(unitID) then
				zombieWatch[unitID] = nil
			else
				local REFRESH_ORDERS_CHANCE = 0.01
				local refreshOrders = random() <= REFRESH_ORDERS_CHANCE
				local queueSize = spGetUnitCommandCount(unitID)
				local closestKnownEnemy = spGetUnitNearestEnemy(unitID, ENEMY_ATTACK_DISTANCE, true)
				local currentCommand = spGetUnitCurrentCommand(unitID)

				if ordersEnabled and (refreshOrders or 
				(currentCommand ~= CMD_FIGHT and currentCommand ~= CMD_GUARD and
				(closestKnownEnemy or not (queueSize) or (queueSize < ZOMBIE_MAX_ORDERS_ISSUED)))) then
					clearUnitOrders(unitID)
					updateOrders(unitID, unitDefID, closestKnownEnemy, currentCommand)
				end
			end
		end
	end
	

	if frame % STUCK_CHECK_INTERVAL == 0 then
		for unitID, data in pairs(zombieWatch) do
			if spGetUnitIsDead(unitID) or not spValidUnitID(unitID) then
				zombieWatch[unitID] = nil
			else
				local x, y, z = spGetUnitPosition(unitID)
				if x and y and z then
					if distance2dSquared(x, z, data.lastLocation.x, data.lastLocation.z) < STUCK_DISTANCE then
						local BLOCK_CHECK_STEP = 15
						local forwardDirection = getActualForwardsYaw(unitID)
						local unitX, unitY, unitZ = spGetUnitPosition(unitID)
						local test1X = unitX + BLOCK_CHECK_STEP * cos(forwardDirection)
						local test1Z = unitZ + BLOCK_CHECK_STEP * sin(forwardDirection)
						local test2X = unitX - BLOCK_CHECK_STEP * cos(forwardDirection)
						local test2Z = unitZ - BLOCK_CHECK_STEP * sin(forwardDirection)
						local unitDefID = data.unitDefID
						if not spTestMoveOrder(unitDefID, test1X, spGetGroundHeight(test1X, test1Z), test1Z) or not spTestMoveOrder(unitDefID, test2X, spGetGroundHeight(test2X, test2Z), test2Z) then
							clearUnitOrders(unitID)
							data.isStuck = true
							local alreadyPresent = false
							for _, zone in ipairs(data.noGoZones) do
								local dx = x - zone.x
								local dz = z - zone.z
								if (dx * dx + dz * dz) < (NOGO_ZONE_RADIUS * NOGO_ZONE_RADIUS) then
									alreadyPresent = true
									break
								end
							end
							if not alreadyPresent then
								if #data.noGoZones > MAX_NOGO_ZONES then
									table.remove(data.noGoZones, 1)
								end
								table.insert(data.noGoZones, { x = x, y = y, z = z })
							end
						end
					else
						data.isStuck = false
					end
					data.lastLocation = { x = x, y = y, z = z }
				end
			end
		end
	end
end

local function queueCorpseForSpawning(featureID, override)
	if not override and not autoSpawningEnabled then
		return
	end

	local featureDefID = spGetFeatureDefID(featureID)
	if zombieCorpseDefs[featureDefID] then
		local spawnDelayFrames = zombieCorpseDefs[featureDefID].spawnDelayFrames
		local spawnFrame = gameFrame + spawnDelayFrames
		corpsesData[featureID] = { featureDefID = featureDefID, spawnDelayFrames = spawnDelayFrames, creationFrame = gameFrame, spawnFrame = spawnFrame }
		corpseCheckFrames[spawnFrame] = corpseCheckFrames[spawnFrame] or {}
		corpseCheckFrames[spawnFrame][#corpseCheckFrames[spawnFrame] + 1] = featureID
	end
end

function gadget:FeatureCreated(featureID, allyTeam)
	queueCorpseForSpawning(featureID, false)
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	corpsesData[featureID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeam == gaiaTeamID and builderID and isZombie(builderID) then
		zombiesBeingBuilt[unitID] = true
		spSetUnitRulesParam(unitID, "resurrected", 0, { inlos = true })
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == gaiaTeamID then
		if isZombie(unitID) then
			initializeZombie(unitID, unitDefID)
		elseif zombiesBeingBuilt[unitID] then
			zombiesBeingBuilt[unitID] = nil
			setZombie(unitID)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	flyingUnits[unitID] = nil
	zombieWatch[unitID] = nil
	zombiesBeingBuilt[unitID] = nil
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID)
	if isZombie(unitID) then
		local health = spGetUnitHealth(unitID)
		if damage >= health then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			if unitX and unitY and unitZ then
				local defData = zombieHeapDefs[unitDefID]
				if defData then
					spDestroyUnit(unitID, false, true, attackerID)
					spSpawnExplosion(unitX, unitY, unitZ, 0, 0, 0, {weaponDef = defData.explosionDefID, owner = unitID})
					if defData.heapDefID then
						spCreateFeature(defData.heapDefID, unitX, unitY, unitZ)
					end
				end
			end
		end
	end
end

local function createZombieFromFeature(featureID)
	if isIdleMode then
		local featureDefID = spGetFeatureDefID(featureID)
		if zombieCorpseDefs[featureDefID] then
			local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
			if featureX then
				local featureDefData = zombieCorpseDefs[featureDefID]
				local healthReductionRatio = calculateHealthRatio(featureID)
				spawnZombies(featureID, featureDefData.unitDefID, healthReductionRatio, featureX, featureY, featureZ)
				return true
			end
		end
	end
	return false
end

local function queueAllCorpsesForSpawning()
	local features = Spring.GetAllFeatures()
	for _, featureID in ipairs(features) do
		queueCorpseForSpawning(featureID, true)
	end
end

local function pacifyZombies(enabled)
	local fireState
	if enabled then
		fireState = FIRE_STATE_RETURN_FIRE
		ordersEnabled = false
		clearAllOrders()
	else
		fireState = FIRE_STATE_FIRE_AT_ALL
	end
	for zombieID, _ in pairs(zombieWatch) do
		if spValidUnitID(zombieID) then
			Spring.GiveOrderToUnit(zombieID, CMD.FIRE_STATE, fireState)
		end
	end
end

local function fightNearTargets(targetUnits)
	if not targetUnits or #targetUnits == 0 then
		return false
	end

	for zombieID, _ in pairs(zombieWatch) do
		if spValidUnitID(zombieID) then
			local randomTarget = targetUnits[random(1, #targetUnits)]
			if spValidUnitID(randomTarget) then
				local targetX, targetY, targetZ = spGetUnitPosition(randomTarget)
				if targetX then
					local angle = random() * tau
					local offsetDistance = random(25, 500)
					local fightX = targetX + cos(angle) * offsetDistance
					local fightZ = targetZ + sin(angle) * offsetDistance
					local fightY = spGetGroundHeight(fightX, fightZ)

					Spring.GiveOrderToUnit(zombieID, CMD.FIGHT, { fightX, fightY, fightZ }, {})
				end
			end
		end
	end

	return true
end

local function aggroTeamID(teamID)
	clearAllOrders()

	local isDead = select(3, Spring.GetTeamInfo(teamID))

	if isDead or isDead == nil then
		return false
	end

	local targetUnits = Spring.GetTeamUnits(teamID) or {}
	return fightNearTargets(targetUnits)
end

local function aggroAllyID(allyID)
	clearAllOrders()

	local targetUnits = {}
	local allyTeams = Spring.GetTeamList(allyID)

	if not allyTeams then
		return false
	end

	for _, teamID in pairs(allyTeams) do
		local unitsToAdd = Spring.GetTeamUnits(teamID)
		for _, unitID in pairs(unitsToAdd) do
			table.insert(targetUnits, unitID)
		end
	end

	return fightNearTargets(targetUnits)
end

local function killAllZombies()
	for zombieID, zombieData in pairs(zombieWatch) do
		if spValidUnitID(zombieID) and not Spring.GetUnitIsDead(zombieID) then
			local currentHealth = spGetUnitHealth(zombieID)
			if currentHealth and currentHealth > 0 then
				Spring.AddUnitDamage(zombieID, currentHealth, 0, NULL_ATTACKER, ENVIRONMENTAL_DAMAGE_ID)
			end
		end
	end
end

local function setAutoSpawning(enabled)
	autoSpawningEnabled = enabled
	if enabled then
		queueAllCorpsesForSpawning()
	end
end

local function clearAllZombieSpawns()
	corpsesData = {}
	corpseCheckFrames = {}
end

local function isAuthorized(playerID)
	if Spring.IsCheatingEnabled() then
		return true
	else
		local playername, _, _, _, _, _, _, _, _, _, accountInfo = Spring.GetPlayerInfo(playerID)
		local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
		if (_G and _G.permissions.devhelpers[accountID]) or (SYNCED and SYNCED.permissions.devhelpers[accountID]) then
			return true
		end
	end
	return false
end

local function convertUnitsToZombies(unitIDs)
	if not unitIDs or #unitIDs == 0 then
		return 0
	end

	local convertedCount = 0
	for _, unitID in ipairs(unitIDs) do
		if spValidUnitID(unitID) then
			setZombie(unitID)
			convertedCount = convertedCount + 1
		end
	end

	return convertedCount
end

local function setAllGaiaToZombies()
	local allUnits = Spring.GetAllUnits()
	local convertedCount = 0

	for _, unitID in ipairs(allUnits) do
		local unitTeam = Spring.GetUnitTeam(unitID)
		if unitTeam == gaiaTeamID and not isZombie(unitID) then
			setZombie(unitID)
			convertedCount = convertedCount + 1
		end
	end

	return convertedCount
end

local function commandSetAllGaiaToZombies(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	local convertedCount = setAllGaiaToZombies()
	Spring.SendMessageToPlayer(playerID, "Set " .. convertedCount .. " Gaia units as zombies")
end

local function commandQueueAllCorpsesForReanimation(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	queueAllCorpsesForSpawning()
	Spring.SendMessageToPlayer(playerID, "Queued all corpses for spawning")
end

local function commandToggleAutoReanimation(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieautospawn 0|1")
		return
	end

	local enabled = tonumber(words[1])
	if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
		Spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
		return
	end

	setAutoSpawning(enabled == 1)
	Spring.SendMessageToPlayer(playerID, "Auto spawning " .. (enabled == 1 and "enabled" or "disabled"))
end

local function commandPacifyZombies(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiepacify 0|1")
		return
	end

	local enabled = tonumber(words[1])
	if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
		Spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
		return
	end

	pacifyZombies(enabled == 1)
	Spring.SendMessageToPlayer(playerID, "Zombies " .. (enabled == 1 and "pacified" or "unpacified"))
end

local function commandAggroZombiesToTeam(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieaggroteam <teamID>")
		return
	end

	local targetTeamID = tonumber(words[1])
	if not targetTeamID or targetTeamID < 0 then
		Spring.SendMessageToPlayer(playerID, "Invalid team ID")
		return
	end

	local success = aggroTeamID(targetTeamID)
	if success then
		Spring.SendMessageToPlayer(playerID, "Zombies aggroed to team " .. targetTeamID)
	else
		Spring.SendMessageToPlayer(playerID, "Team " .. targetTeamID .. " not found or has no units")
	end
end

local function commandAggroZombiesToAlly(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieaggroally <allyID>")
		return
	end

	local targetAllyID = tonumber(words[1])
	if not targetAllyID or targetAllyID < 0 then
		Spring.SendMessageToPlayer(playerID, "Invalid ally ID")
		return
	end

	local success = aggroAllyID(targetAllyID)
	if success then
		Spring.SendMessageToPlayer(playerID, "Zombies aggroed to ally team " .. targetAllyID)
	else
		Spring.SendMessageToPlayer(playerID, "Ally team " .. targetAllyID .. " not found or has no units")
	end
end

local function commandKillAllZombies(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	killAllZombies()
	Spring.SendMessageToPlayer(playerID, "Killed all zombies")
end

local function commandClearAllZombieOrders(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	clearAllOrders()
	Spring.SendMessageToPlayer(playerID, "Cleared zombie orders")
end

local function commandClearZombieSpawns(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	clearAllZombieSpawns()
	Spring.SendMessageToPlayer(playerID, "Cleared all queued zombie spawns")
end

local function commandToggleDebugMode(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiedebug 0|1")
		return
	end

	local enabled = tonumber(words[1])
	if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
		Spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
		return
	end

	debugMode = enabled == 1
	Spring.SendMessageToPlayer(playerID, "Zombie debug mode " .. (debugMode and "enabled" or "disabled"))
end

local function setZombieMode(mode)
	if mode ~= "normal" and mode ~= "hard" and mode ~= "nightmare" and mode ~= "extreme" then
		return false
	end

	currentZombieMode = mode
	applyZombieModeSettings(mode)
	return true
end

local function commandSetZombieMode(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiemode normal|hard|nightmare|extreme")
		return
	end

	local mode = string.lower(words[1])
	if mode ~= "normal" and mode ~= "hard" and mode ~= "nightmare" and mode ~= "extreme" then
		Spring.SendMessageToPlayer(playerID, "Invalid mode. Use: normal, hard, nightmare, or extreme")
		return
	end

	local success = setZombieMode(mode)
	if success then
		Spring.SendMessageToPlayer(playerID, "Zombie mode set to " .. mode)
	else
		Spring.SendMessageToPlayer(playerID, "Failed to set zombie mode to " .. mode)
	end
end

function gadget:Initialize()
	local modOptionEnabled = modOptions.zombies ~= "disabled"
	isIdleMode = modOptions.seasonal_surprise == true or (GG.Zombies and GG.Zombies.IdleMode == true) or false

	if not modOptionEnabled and not isIdleMode then
		gadgetHandler:RemoveGadget(gadget)
		return
	end

	local initialMode = modOptions.zombies or "normal"
	applyZombieModeSettings(initialMode)

	autoSpawningEnabled = modOptionEnabled and not isIdleMode

	gameFrame = spGetGameFrame()

	local units = spGetAllUnits()
	for _, unitID in ipairs(units) do
		if isZombie(unitID) then
			setZombie(unitID)
		end
	end

	if not isIdleMode then
		local features = spGetAllFeatures()
		for _, featureID in ipairs(features) do
			gadget:FeatureCreated(featureID, gaiaTeamID)
		end
	end

	GG.Zombies = {}
	GG.Zombies.SetZombie = setZombie
	GG.Zombies.ConvertUnitsToZombies = convertUnitsToZombies
	GG.Zombies.SetAllGaiaToZombies = setAllGaiaToZombies
	GG.Zombies.CreateZombieFromFeature = createZombieFromFeature
	GG.Zombies.QueueAllCorpsesForSpawning = queueAllCorpsesForSpawning
	GG.Zombies.SetAutoSpawning = setAutoSpawning
	GG.Zombies.ClearAllZombieSpawns = clearAllZombieSpawns
	GG.Zombies.PacifyZombies = pacifyZombies
	GG.Zombies.AggroTeamID = aggroTeamID
	GG.Zombies.AggroAllyID = aggroAllyID
	GG.Zombies.KillAllZombies = killAllZombies
	GG.Zombies.ClearAllOrders = clearAllOrders
	GG.Zombies.SetZombieMode = setZombieMode
	GG.Zombies.GetZombieMode = function() return currentZombieMode end

	gadgetHandler:AddChatAction('zombiesetallgaia', commandSetAllGaiaToZombies, "Set all Gaia units as zombies")
	gadgetHandler:AddChatAction('zombiequeueall', commandQueueAllCorpsesForReanimation, "Queue all corpses for spawning")
	gadgetHandler:AddChatAction('zombieautospawn', commandToggleAutoReanimation, "Enable/disable auto spawning")
	gadgetHandler:AddChatAction('zombieclearspawns', commandClearZombieSpawns, "Clear all queued zombie spawns")
	gadgetHandler:AddChatAction('zombiepacify', commandPacifyZombies, "Pacify/unpacify zombies")
	gadgetHandler:AddChatAction('zombieaggroteam', commandAggroZombiesToTeam, "Make zombies aggro to specific team")
	gadgetHandler:AddChatAction('zombieaggroally', commandAggroZombiesToAlly, "Make zombies aggro to entire ally team")
	gadgetHandler:AddChatAction('zombiekillall', commandKillAllZombies, "Kill all zombies")
	gadgetHandler:AddChatAction('zombieclearallorders', commandClearAllZombieOrders, "Clear allzombie orders")
	gadgetHandler:AddChatAction('zombiedebug', commandToggleDebugMode, "Enable/disable debug mode")
	gadgetHandler:AddChatAction('zombiemode', commandSetZombieMode, "Set zombie mode (normal/hard/nightmare/extreme)")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('zombiesetallgaia')
	gadgetHandler:RemoveChatAction('zombiequeueall')
	gadgetHandler:RemoveChatAction('zombieautospawn')
	gadgetHandler:RemoveChatAction('zombieclearspawns')
	gadgetHandler:RemoveChatAction('zombiepacify')
	gadgetHandler:RemoveChatAction('zombieaggroteam')
	gadgetHandler:RemoveChatAction('zombieaggroally')
	gadgetHandler:RemoveChatAction('zombiekillall')
	gadgetHandler:RemoveChatAction('zombieclearallorders')
	gadgetHandler:RemoveChatAction('zombiedebug')
	gadgetHandler:RemoveChatAction('zombiemode')
end

function gadget:GameStart()
	setGaiaStorage()
end