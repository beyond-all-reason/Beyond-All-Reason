function gadget:GetInfo()
	return {
		name = "Zombies",
		desc = "Resurrects corpses as Scavengers or hostile Gaia Zombies",
		author = "SethDGamre, code snippets/inspiration from Rafal",
		date = "March 2024",
		license = "GNU GPL, v2 or later",
		layer = 2, -- after game_team_resources.lua
		enabled = true,
	}
end

-- To customize zombie respawn time, use customParams.zombie_respawn_time (seconds):
--   < 0  never respawn as a zombie
--   0    respawn instantly
--   > 0  custom respawn delay in seconds
-- this overrides default timing based on unit power, difficulty, and gamestate.

if not gadgetHandler:IsSyncedCode() then
	return false
end

local modOptions = Spring.GetModOptions()

local ZOMBIE_GUARD_RADIUS = 500 -- Radius for zombies to guard allies
local ZOMBIE_MAX_ORDER_ATTEMPTS = 10
local ZOMBIE_MAX_ORDERS_ISSUED = 2
local ZOMBIE_FACTORY_BUILD_COUNT = 20
local ZOMBIE_GUARD_CHANCE = 0.75 -- Chance a zombie will guard allies
local REFRESH_ORDERS_CHANCE = 0.005
local WARNING_TIME = Game.gameSpeed * 15 -- Frames to start warning before reanimation
local TIMER_NEAR_MAX_THRESHOLD = Game.gameSpeed * 5 -- Frames to start warning before reanimation
local ZOMBIE_REZ_FRAME_PARAM = "zombie_rez_frame"
local WAS_ZOMBIE_PARAM = "wasZombie"
local PUBLIC_RULES_PARAM_ACCESS = { public = true }
local WAS_ZOMBIE_TIMEOUT_FRAMES = Game.gameSpeed * 3

local ZOMBIE_MAX_XP = 2 -- Maximum experience value for zombies, skewed towards median

local standardTechToRezPowerSpeeds = {
	[0.5] = 1,
	[1] = 1,
	[1.5] = 3,
	[2] = 8,
	[2.5] = 25,
	[3] = 42,
	[3.5] = 63,
	[4] = 83,
	[4.5] = 104,
}

local harderTechToRezPowerSpeeds = {
	[0.5] = 1,
	[1] = 2,
	[1.5] = 5,
	[2] = 12,
	[2.5] = 38,
	[3] = 64,
	[3.5] = 86,
	[4] = 108,
	[4.5] = 130,
}

local zombieModeConfigs = {
	normal = {
		techToRezPowerSpeeds = standardTechToRezPowerSpeeds,
		rezMin = 90,
		rezMax = 180,
		countMin = 1,
		countMax = 1,
		zombieCorpses = false,
	},
	hard = {
		techToRezPowerSpeeds = harderTechToRezPowerSpeeds,
		rezMin = 60,
		rezMax = 180,
		countMin = 1,
		countMax = 1,
		zombieCorpses = false,
	},
	nightmare = {
		techToRezPowerSpeeds = harderTechToRezPowerSpeeds,
		rezMin = 60,
		rezMax = 120,
		countMin = 2,
		countMax = 6,
		zombieCorpses = false,
	},
	akumu = {
		techToRezPowerSpeeds = harderTechToRezPowerSpeeds,
		rezMin = 60,
		rezMax = 120,
		countMin = 2,
		countMax = 8,
		zombieCorpses = true,
	},
}

local currentZombieMode = "normal"
local currentZombieConfig = zombieModeConfigs.normal

local ZOMBIE_ORDER_CHECK_INTERVAL = Game.gameSpeed * 3 -- How often (in frames) to check if zombies need new orders
local ZOMBIE_CHECK_INTERVAL = Game.gameSpeed -- How often (in frames) everything else is checked
local STUCK_CHECK_INTERVAL = Game.gameSpeed * 12 -- How often (in frames) to check if zombies are stuck
local REZ_SPEED_UPDATE_INTERVAL = Game.gameSpeed * 60

local STUCK_DISTANCE = 50 -- How far (in units) a zombie can move before being considered stuck
local MAX_NOGO_ZONES = 10 -- How many no-go zones a zombie can have before being considered stuck
local NOGO_ZONE_RADIUS = 600 -- How far (in units) a no-go zone is
local NOGO_ZONE_RADIUS_SQ = NOGO_ZONE_RADIUS * NOGO_ZONE_RADIUS
local ENEMY_ATTACK_DISTANCE = 1000 -- How far (in units) a zombie will detect and choose to attack an enemy
local ORDER_DISTANCE = 800 -- How far (in units) a zombie moves per order

local CMD_REPEAT = CMD.REPEAT
local CMD_MOVE_STATE = CMD.MOVE_STATE
local CMD_GUARD = CMD.GUARD
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_MOVE = CMD.MOVE
local CMD_CAPTURE = CMD.CAPTURE
local CMD_FIGHT = CMD.FIGHT
local CMD_OPT_SHIFT = { "shift" }

local FIRE_STATE_FIRE_AT_ALL = 3
local FIRE_STATE_RETURN_FIRE = 1
local MOVE_STATE_HOLD_POSITION = 0
local ENABLE_REPEAT = 1
local NULL_ATTACKER = -1
local ENVIRONMENTAL_DAMAGE_ID = Game.envDamageTypes.GroundCollision
local WATER_DAMAGE_DEF_ID = Game.envDamageTypes.Water
local UNAUTHORIZED_TEXT = "You are not authorized to use zombie commands" --i18n library doesn't exist in gadget space.

local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ

local spGetUnitRotation = Spring.GetUnitRotation
local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local spValidUnitID = Spring.ValidUnitID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetGameRulesParam = Spring.GetGameRulesParam
local spCreateUnit = Spring.CreateUnit
local spTransferUnit = Spring.TransferUnit
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetAllUnits = Spring.GetAllUnits
local spGetGameFrame = Spring.GetGameFrame
local spGetAllFeatures = Spring.GetAllFeatures
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spDestroyFeature = Spring.DestroyFeature
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spSetTeamResource = Spring.SetTeamResource
local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitHealth = Spring.SetUnitHealth
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetFeatureRulesParam = Spring.SetFeatureRulesParam
local spGetFeatureRulesParam = Spring.GetFeatureRulesParam
local spGetFeatureDefID = Spring.GetFeatureDefID
local spTestMoveOrder = Spring.TestMoveOrder
local spSpawnCEG = Spring.SpawnCEG
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureHealth = Spring.GetFeatureHealth
local spDestroyUnit = Spring.DestroyUnit
local spGetUnitDirection = Spring.GetUnitDirection
local spCreateFeature = Spring.CreateFeature
local spSpawnExplosion = Spring.SpawnExplosion
local spPlaySoundFile = Spring.PlaySoundFile
local spGetFeatureRadius = Spring.GetFeatureRadius
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetFactoryCommands = Spring.GetFactoryCommands
local spAddTeamResource = Spring.AddTeamResource
local spSetUnitExperience = Spring.SetUnitExperience
local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitHeight = Spring.GetUnitHeight
local random = math.random
local distance2dSquared = math.distance2dSquared
local pi = math.pi
local tau = 2 * pi
local cos = math.cos
local sin = math.sin
local floor = math.floor
local clamp = math.clamp
local ceil = math.ceil

local teams = Spring.GetTeamList()
local scavTeamID
local gaiaTeamID = Spring.GetGaiaTeamID()
local readAsGaia = { ctrl = gaiaTeamID, read = gaiaTeamID, select = gaiaTeamID }
for _, teamID in ipairs(teams) do
	local teamLuaAI = Spring.GetTeamLuaAI(teamID)
	if teamLuaAI and string.find(teamLuaAI, "ScavengersAI") then
		scavTeamID = teamID
	end
end

local ordersEnabled = true
local gameFrame = 0
local adjustedRezPowerSpeed = currentZombieConfig.techToRezPowerSpeeds[1]
local currentTechLevel = nil
local isIdleMode = false
local autoSpawningEnabled = true

local extraDefs = {}
local factoriesWithCombatOptions = {}
local zombiesBeingBuilt = {}
local zombieCorpseDefs = {}
local zombieWatch = {}
local corpseCheckFrames = {}
local corpsesData = {}
local wereZombies = {}
local pendingUnitXp = {}
local pendingZombieCaptures = {}
local heapingZombies = {}
local zombieHeapDefs = {}
local fightingDefs = {}
local unitDefWithWeaponRanges = {}
local capturingUnits = {}
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
		local corpseDefData = { unitDefID = unitDefID }
		local customRespawnTime = tonumber(unitDef.customParams and unitDef.customParams.zombie_respawn_time)
		if customRespawnTime then
			if customRespawnTime < 0 then
				corpseDefData.neverRespawn = true
			else
				corpseDefData.customRespawnTime = customRespawnTime
			end
		end
		zombieCorpseDefs[corpseDefID] = corpseDefData

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
		capturingUnits[unitDefID] = true
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
				if
					weaponDef
					and weaponDef.range
					and weaponDef.range > 0
					and not (weaponDef.customParams and weaponDef.customParams.bogus)
				then
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
	zombieWatch[unitID] = { unitDefID = unitDefID, lastX = x, lastY = y, lastZ = z, noGoZones = {}, isStuck = false }
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

local function getUnitRezPower(unitDef)
	return math.max(1, unitDef.power or 1)
end

local function calculateSpawnDelayFrames(unitPower)
	local spawnSeconds = floor(unitPower / adjustedRezPowerSpeed)
	spawnSeconds = clamp(spawnSeconds, currentZombieConfig.rezMin, currentZombieConfig.rezMax)
	return spawnSeconds * Game.gameSpeed
end

local function getRezPowerSpeedForTechLevel(config, techLevel)
	local speeds = config.techToRezPowerSpeeds
	if speeds[techLevel] then
		return speeds[techLevel]
	end
	return speeds[1]
end

local function rebuildZombieCorpseSpawnDelays()
	for _, corpseDefData in pairs(zombieCorpseDefs) do
		if corpseDefData.neverRespawn then
			corpseDefData.spawnDelayFrames = nil
		elseif corpseDefData.customRespawnTime then
			corpseDefData.spawnDelayFrames = floor(corpseDefData.customRespawnTime * Game.gameSpeed)
		else
			local unitDef = unitDefs[corpseDefData.unitDefID]
			if unitDef then
				corpseDefData.spawnDelayFrames = calculateSpawnDelayFrames(getUnitRezPower(unitDef))
			end
		end
	end
end

local function updateAdjustedRezPowerSpeed()
	local techLevel = 1
	adjustedRezPowerSpeed = getRezPowerSpeedForTechLevel(currentZombieConfig, techLevel)
	if GG.PowerLib and GG.PowerLib.HighestPlayerTeamPower and GG.PowerLib.TechGuesstimate then
		local highestPowerData = GG.PowerLib.HighestPlayerTeamPower()
		if highestPowerData and highestPowerData.power then
			techLevel = GG.PowerLib.TechGuesstimate(highestPowerData.power)
			adjustedRezPowerSpeed = getRezPowerSpeedForTechLevel(currentZombieConfig, techLevel)
		end
	end

	currentTechLevel = techLevel
end

local function updateRezSpeed()
	updateAdjustedRezPowerSpeed()
	rebuildZombieCorpseSpawnDelays()
end

local function applyZombieModeSettings(mode)
	local config = zombieModeConfigs[mode]
	if not config then
		config = zombieModeConfigs.normal
	end

	currentZombieMode = mode
	currentZombieConfig = config

	updateRezSpeed()
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
	if spGetUnitIsBeingBuilt(unitID) then
		return nil
	end

	local x, y, z = spGetUnitPosition(unitID)
	if not x or not z then
		return nil
	end

	local readAsGaia = { ctrl = gaiaTeamID, read = gaiaTeamID, select = gaiaTeamID }
	local gaiaUnits = CallAsTeam(readAsGaia, spGetUnitsInCylinder, x, z, range, Spring.ALLY_UNITS)

	for i = 1, #gaiaUnits do
		local allyID = gaiaUnits[i]
		local allyDefID = spGetUnitDefID(allyID)
		local currentCommand = spGetUnitCurrentCommand(allyID)
		if
			(allyID ~= unitID)
			and fightingDefs[allyDefID]
			and currentCommand ~= CMD_GUARD
			and extraDefs[allyDefID].isMobile
		then
			local ox, oy, oz = spGetUnitPosition(allyID)
			if ox and oy and oz then
				local currentDistanceSquared = distance2dSquared(x, z, ox, oz)
				if
					spTestMoveOrder(unitDefID, ox, oy, oz)
					and ((bestDistanceSquared == nil) or (currentDistanceSquared < bestDistanceSquared))
				then
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

	if #builds > 0 then
		spGiveOrderArrayToUnit(unitID, builds)
	end
end

local function warningCEG(featureID, x, y, z)
	local radius = spGetFeatureRadius(featureID)

	local selectedEffect = warningEffects[random(#warningEffects)]
	if selectedEffect == "scavradiation-lightning" and GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", x, y, z)
	else
		spSpawnCEG(selectedEffect, x, y, z, 0, 0, 0, radius * 0.25)
	end
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
	local nearAlly
	if not closestKnownEnemy and currentCommand ~= CMD_MOVE and not isAlreadyGuarding and fightingDefs[unitDefID] then
		nearAlly = GetUnitNearestReachableAlly(unitID, unitDefID, ZOMBIE_GUARD_RADIUS)
	end
	local weaponRange = unitDefWithWeaponRanges[unitDefID]
	local data = zombieWatch[unitID]

	if capturingUnits[unitDefID] and closestKnownEnemy and not data.isStuck then
		local enemyDefID = spGetUnitDefID(closestKnownEnemy)
		if enemyDefID and unitDefs[enemyDefID].capturable ~= false then
			spGiveOrderToUnit(unitID, CMD_CAPTURE, { closestKnownEnemy }, 0)
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
			local attemptX, attemptY, attemptZ
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

				if attemptX then
					attemptY = spGetGroundHeight(attemptX, attemptZ)
				end
			end
			if attemptX then
				for _, zone in ipairs(data.noGoZones) do
					local dx = attemptX - zone.x
					local dz = attemptZ - zone.z
					if (dx * dx + dz * dz) < NOGO_ZONE_RADIUS_SQ then
						inNoGoZone = true
						break
					end
				end
			end
			if attemptX and attemptY then
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
		local factoryCommands = spGetFactoryCommands(unitID, -1) or {}
		local currentCommandCount = #factoryCommands
		if currentCommandCount < ZOMBIE_FACTORY_BUILD_COUNT then
			issueRandomFactoryBuildOrders(unitID, unitDefID)
		end
	end
end

local function setCorpseRezRulesParam(featureID, spawnFrame)
	spSetFeatureRulesParam(featureID, ZOMBIE_REZ_FRAME_PARAM, spawnFrame, PUBLIC_RULES_PARAM_ACCESS)
end

local function clearCorpseRezRulesParam(featureID)
	spSetFeatureRulesParam(featureID, ZOMBIE_REZ_FRAME_PARAM, nil, PUBLIC_RULES_PARAM_ACCESS)
end

local function wasZombieCorpse(featureID, corpseData)
	if corpseData and corpseData.wasZombie then
		return true
	end
	local wasZombieParam = spGetFeatureRulesParam(featureID, WAS_ZOMBIE_PARAM)
	return wasZombieParam == 1
end

local function resetSpawn(featureID, featureData, featureDefData)
	local newFrame = featureData.tamperedFrame + featureData.spawnDelayFrames
	featureData.spawnFrame = newFrame
	featureData.creationFrame = featureData.tamperedFrame
	featureData.tamperedFrame = nil
	setCorpseRezRulesParam(featureID, newFrame)
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

local function rollSpawnCount()
	return random(currentZombieConfig.countMin, currentZombieConfig.countMax)
end

local function calculateSpawnCount(unitDefID)
	local countMin = currentZombieConfig.countMin
	local countMax = currentZombieConfig.countMax
	if countMin == countMax then
		return countMin
	end

	local unitDef = unitDefs[unitDefID]
	if not unitDef then
		return countMin
	end

	local rezTimeSeconds = calculateSpawnDelayFrames(getUnitRezPower(unitDef)) / Game.gameSpeed
	local rezMin = currentZombieConfig.rezMin
	local rezMax = currentZombieConfig.rezMax

	if currentTechLevel == nil or currentTechLevel <= 1 then
		return math.min(rollSpawnCount(), rollSpawnCount(), rollSpawnCount())
	end

	if rezTimeSeconds == rezMin then
		return rollSpawnCount()
	end
	if rezTimeSeconds == rezMax then
		return math.min(rollSpawnCount(), rollSpawnCount(), rollSpawnCount())
	end
	return math.min(rollSpawnCount(), rollSpawnCount())
end

local function spawnZombies(featureID, unitDefID, healthReductionRatio, x, y, z, wasZombie, pastXp)
	local unitDef = unitDefs[unitDefID]
	local spawnCount = 1
	if not wasZombie and extraDefs[unitDefID].isMobile then
		spawnCount = calculateSpawnCount(unitDefID)
	end
	local size = unitDef.xsize
	local unitDefToCreate = getScavVariantUnitDefID(unitDefID)
	local sizeCategory = ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
	local sizeName = "small"
	if sizeCategory > 4.5 then
		sizeName = "huge"
	elseif sizeCategory > 3.5 then
		sizeName = "large"
	elseif sizeCategory > 2.5 then
		sizeName = "medium"
	elseif sizeCategory > 1.5 then
		sizeName = "small"
	else
		sizeName = "tiny"
	end

	if pastXp == nil then
		local corpseData = corpsesData[featureID]
		if corpseData and corpseData.pastXp ~= nil then
			pastXp = corpseData.pastXp
		else
			pastXp = spGetFeatureRulesParam(featureID, "previous_xp") or 0
		end
	end

	spDestroyFeature(featureID)
	corpsesData[featureID] = nil
	playSpawnSound(x, y, z)

	for i = 1, spawnCount do
		local randomX = x + random(-size * spawnCount, size * spawnCount)
		local randomZ = z + random(-size * spawnCount, size * spawnCount)
		local adjustedY = spGetGroundHeight(randomX, randomZ)

		local unitID = spCreateUnit(unitDefToCreate, randomX, adjustedY, randomZ, 0, gaiaTeamID)
		if unitID then
			spSpawnCEG("scav-spawnexplo-" .. sizeName, randomX, adjustedY, randomZ, 0, 0, 0)
			local generatedXp = 0
			if modOptions.zombies ~= "normal" then
				generatedXp = (random() * ZOMBIE_MAX_XP + random() * ZOMBIE_MAX_XP) / 2
			end
			spSetUnitExperience(unitID, math.max(pastXp, generatedXp))
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
		if not featureData.tamperedFrame then
			local remainingFrames = featureData.spawnFrame - gameFrame
			if remainingFrames < featureData.spawnDelayFrames - TIMER_NEAR_MAX_THRESHOLD then
				local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
				if featureX then
					spSpawnCEG("scaspawn-trail", featureX, featureY + 15, featureZ, 0, 0, 0)
				end
			end
		end
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

	if frame % REZ_SPEED_UPDATE_INTERVAL == 0 then
		updateRezSpeed()
	end

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
				local featureDefData = zombieCorpseDefs[corpseData.featureDefID]
				if corpseData.tamperedFrame then
					resetSpawn(featureID, corpseData, featureDefData)
				else
					local healthReductionRatio = calculateHealthRatio(featureID)
					spawnZombies(
						featureID,
						featureDefData.unitDefID,
						healthReductionRatio,
						featureX,
						featureY,
						featureZ,
						corpseData.wasZombie,
						corpseData.pastXp
					)
				end
			end
		end
		corpseCheckFrames[frame] = nil
	end

	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		spAddTeamResource(gaiaTeamID, "metal", 1000000)
		spAddTeamResource(gaiaTeamID, "energy", 1000000)
		for unitID, timeoutFrame in pairs(wereZombies) do
			if timeoutFrame < frame then
				wereZombies[unitID] = nil
			end
		end
		for unitID, xpData in pairs(pendingUnitXp) do
			if xpData.timeout < frame then
				pendingUnitXp[unitID] = nil
			end
		end
		for featureID, featureData in pairs(corpsesData) do
			if featureData.spawnFrame - frame < WARNING_TIME then
				local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
				if not featureX then --doesn't exist anymore
					corpsesData[featureID] = nil
				elseif not featureData.tamperedFrame then
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
			elseif ordersEnabled then
				local currentCommand = spGetUnitCurrentCommand(unitID)
				local refreshOrders = currentCommand ~= CMD_FIGHT
					and currentCommand ~= CMD_CAPTURE
					and random() <= REFRESH_ORDERS_CHANCE

				if
					refreshOrders
					or (currentCommand ~= CMD_FIGHT and currentCommand ~= CMD_GUARD and currentCommand ~= CMD_CAPTURE)
				then
					local closestKnownEnemy
					if capturingUnits[unitDefID] or unitDefWithWeaponRanges[unitDefID] then
						closestKnownEnemy = spGetUnitNearestEnemy(unitID, ENEMY_ATTACK_DISTANCE, true)
					end

					local shouldUpdateOrders = refreshOrders or closestKnownEnemy
					if not shouldUpdateOrders then
						local queueSize = spGetUnitCommandCount(unitID)
						shouldUpdateOrders = not queueSize or queueSize < ZOMBIE_MAX_ORDERS_ISSUED
					end

					if shouldUpdateOrders then
						clearUnitOrders(unitID)
						updateOrders(unitID, unitDefID, closestKnownEnemy, currentCommand)
					end
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
					if distance2dSquared(x, z, data.lastX, data.lastZ) < STUCK_DISTANCE then
						local BLOCK_CHECK_STEP = 15
						local forwardDirection = getActualForwardsYaw(unitID)
						local unitX, unitY, unitZ = x, y, z
						local test1X = unitX + BLOCK_CHECK_STEP * cos(forwardDirection)
						local test1Z = unitZ + BLOCK_CHECK_STEP * sin(forwardDirection)
						local test2X = unitX - BLOCK_CHECK_STEP * cos(forwardDirection)
						local test2Z = unitZ - BLOCK_CHECK_STEP * sin(forwardDirection)
						local unitDefID = data.unitDefID
						if
							not spTestMoveOrder(unitDefID, test1X, spGetGroundHeight(test1X, test1Z), test1Z)
							or not spTestMoveOrder(unitDefID, test2X, spGetGroundHeight(test2X, test2Z), test2Z)
						then
							clearUnitOrders(unitID)
							data.isStuck = true
							local alreadyPresent = false
							for _, zone in ipairs(data.noGoZones) do
								local dx = x - zone.x
								local dz = z - zone.z
								if (dx * dx + dz * dz) < NOGO_ZONE_RADIUS_SQ then
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
					data.lastX = x
					data.lastY = y
					data.lastZ = z
				end
			end
		end
	end
end

local function queueCorpseForSpawning(featureID, override, wasZombie, pastXp)
	if not override and not autoSpawningEnabled then
		return
	end

	local featureDefID = spGetFeatureDefID(featureID)
	local corpseDefData = zombieCorpseDefs[featureDefID]
	if not corpseDefData or corpseDefData.neverRespawn then
		return
	end

	wasZombie = wasZombie or wasZombieCorpse(featureID)
	if pastXp == nil then
		local existingCorpseData = corpsesData[featureID]
		if existingCorpseData and existingCorpseData.pastXp ~= nil then
			pastXp = existingCorpseData.pastXp
		else
			pastXp = spGetFeatureRulesParam(featureID, "previous_xp") or 0
		end
	end

	local spawnDelayFrames = corpseDefData.spawnDelayFrames
	if spawnDelayFrames == 0 then
		local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
		if featureX then
			local healthReductionRatio = calculateHealthRatio(featureID)
			spawnZombies(
				featureID,
				corpseDefData.unitDefID,
				healthReductionRatio,
				featureX,
				featureY,
				featureZ,
				wasZombie,
				pastXp
			)
		end
		return
	end

	local spawnFrame = gameFrame + spawnDelayFrames
	corpsesData[featureID] = {
		featureDefID = featureDefID,
		spawnDelayFrames = spawnDelayFrames,
		creationFrame = gameFrame,
		spawnFrame = spawnFrame,
		wasZombie = wasZombie,
		pastXp = pastXp,
	}
	setCorpseRezRulesParam(featureID, spawnFrame)
	corpseCheckFrames[spawnFrame] = corpseCheckFrames[spawnFrame] or {}
	corpseCheckFrames[spawnFrame][#corpseCheckFrames[spawnFrame] + 1] = featureID
end

function gadget:FeatureCreated(featureID, allyTeam, sourceID)
	local wasZombie = false
	local pastXp = 0
	if sourceID and wereZombies[sourceID] then
		wasZombie = true
		wereZombies[sourceID] = nil
		spSetFeatureRulesParam(featureID, WAS_ZOMBIE_PARAM, 1, PUBLIC_RULES_PARAM_ACCESS)
	end
	if sourceID and pendingUnitXp[sourceID] then
		pastXp = pendingUnitXp[sourceID].xp
		pendingUnitXp[sourceID] = nil
	else
		pastXp = spGetFeatureRulesParam(featureID, "previous_xp") or 0
	end
	queueCorpseForSpawning(featureID, false, wasZombie, pastXp)
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	clearCorpseRezRulesParam(featureID)
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
	if zombieHeapDefs[unitDefID] then
		pendingUnitXp[unitID] =
			{ xp = spGetUnitExperience(unitID) or 0, timeout = gameFrame + WAS_ZOMBIE_TIMEOUT_FRAMES }
	end
	if isZombie(unitID) and currentZombieConfig.zombieCorpses and not heapingZombies[unitID] then
		wereZombies[unitID] = gameFrame + WAS_ZOMBIE_TIMEOUT_FRAMES
	end
	heapingZombies[unitID] = nil
	pendingZombieCaptures[unitID] = nil
	flyingUnits[unitID] = nil
	zombieWatch[unitID] = nil
	zombiesBeingBuilt[unitID] = nil
end

function gadget:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part)
	if isZombie(builderID) then
		pendingZombieCaptures[unitID] = true
	end
	return true
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if pendingZombieCaptures[unitID] then
		pendingZombieCaptures[unitID] = nil
		if not isZombie(unitID) then
			setZombie(unitID)
		end
	end
end

local function isUnitInLava(unitID)
	local _, unitY = spGetUnitBasePosition(unitID)
	if not unitY then
		return false
	end

	local lavaLevel = spGetGameRulesParam("lavaLevel")
	if lavaLevel ~= nil and unitY < lavaLevel then
		return true
	end

	local waterTypeOverlay = GG.WaterTypeOverlay
	if waterTypeOverlay and waterTypeOverlay.isActive() and waterTypeOverlay.getActiveType() == "lava" then
		local overlayLevel = waterTypeOverlay.getLevel()
		if overlayLevel and unitY < overlayLevel then
			return true
		end
	end

	return false
end

local function shouldAlwaysLeaveHeap(unitID, weaponDefID, attackerID)
	if weaponDefID == WATER_DAMAGE_DEF_ID then
		return true
	end
	if not isUnitInLava(unitID) then
		return false
	end
	if not weaponDefID or weaponDefID < 0 then
		return true
	end
	if not attackerID or attackerID < 0 or not spValidUnitID(attackerID) then
		return true
	end
	return false
end

local function leaveZombieHeap(unitID, unitDefID, attackerID)
	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end
	local defData = zombieHeapDefs[unitDefID]
	if not defData then
		return
	end
	heapingZombies[unitID] = true
	spDestroyUnit(unitID, false, true, attackerID)
	spSpawnExplosion(unitX, unitY, unitZ, 0, 0, 0, { weaponDef = defData.explosionDefID, owner = unitID })
	if defData.heapDefID then
		spCreateFeature(defData.heapDefID, unitX, unitY, unitZ)
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID)
	if not isZombie(unitID) then
		return
	end
	local leaveHeap = not currentZombieConfig.zombieCorpses or shouldAlwaysLeaveHeap(unitID, weaponDefID, attackerID)
	if not leaveHeap then
		return
	end
	local health = spGetUnitHealth(unitID)
	if damage >= health then
		leaveZombieHeap(unitID, unitDefID, attackerID)
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
				local corpseData = corpsesData[featureID]
				local wasZombie = wasZombieCorpse(featureID, corpseData)
				local pastXp = corpseData and corpseData.pastXp
				spawnZombies(
					featureID,
					featureDefData.unitDefID,
					healthReductionRatio,
					featureX,
					featureY,
					featureZ,
					wasZombie,
					pastXp
				)
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
		ordersEnabled = true
	end
	for zombieID, _ in pairs(zombieWatch) do
		if spValidUnitID(zombieID) then
			Spring.GiveOrderToUnit(zombieID, CMD.FIRE_STATE, fireState)
		end
	end
end

local function suspendAutoOrders(enabled)
	if enabled then
		ordersEnabled = false
		clearAllOrders()
	else
		ordersEnabled = true
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
	for featureID in pairs(corpsesData) do
		clearCorpseRezRulesParam(featureID)
	end
	corpsesData = {}
	corpseCheckFrames = {}
end

local function isAuthorized(playerID)
	if Spring.IsCheatingEnabled() then
		return true
	end
	local playername = Spring.GetPlayerInfo(playerID)
	local accountID = BAR.Utilities.GetAccountID(playerID)
	if
		(
			_G
			and _G.permissions.devhelpers
			and (_G.permissions.devhelpers[accountID] or (playername and _G.permissions.devhelpers[playername]))
		)
		or (
			SYNCED
			and SYNCED.permissions.devhelpers
			and (SYNCED.permissions.devhelpers[accountID] or (playername and SYNCED.permissions.devhelpers[playername]))
		)
	then
		return true
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

local function commandSuspendAutoOrders(_, line, words, playerID)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiesuspendorders 0|1")
		return
	end

	local enabled = tonumber(words[1])
	if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
		Spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
		return
	end

	suspendAutoOrders(enabled == 1)
	Spring.SendMessageToPlayer(playerID, "Zombie auto-orders " .. (enabled == 1 and "suspended" or "resumed"))
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

local function setZombieMode(mode)
	if mode ~= "normal" and mode ~= "hard" and mode ~= "nightmare" and mode ~= "akumu" then
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
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiemode normal|hard|nightmare|akumu")
		return
	end

	local mode = string.lower(words[1])
	if mode ~= "normal" and mode ~= "hard" and mode ~= "nightmare" and mode ~= "akumu" then
		Spring.SendMessageToPlayer(playerID, "Invalid mode. Use: normal, hard, nightmare, or akumu")
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
	isIdleMode = GG.Zombies and GG.Zombies.IdleMode == true or false

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
	GG.Zombies.SuspendAutoOrders = suspendAutoOrders
	GG.Zombies.AggroTeamID = aggroTeamID
	GG.Zombies.AggroAllyID = aggroAllyID
	GG.Zombies.KillAllZombies = killAllZombies
	GG.Zombies.ClearAllOrders = clearAllOrders
	GG.Zombies.SetZombieMode = setZombieMode
	GG.Zombies.GetZombieMode = function()
		return currentZombieMode
	end

	gadgetHandler:AddChatAction("zombiesetallgaia", commandSetAllGaiaToZombies, "Set all Gaia units as zombies")
	gadgetHandler:AddChatAction(
		"zombiequeueallcorpses",
		commandQueueAllCorpsesForReanimation,
		"Queue all corpses for spawning"
	)
	gadgetHandler:AddChatAction("zombieautospawn", commandToggleAutoReanimation, "Enable/disable auto spawning")
	gadgetHandler:AddChatAction("zombieclearspawns", commandClearZombieSpawns, "Clear all queued zombie spawns")
	gadgetHandler:AddChatAction("zombiepacify", commandPacifyZombies, "Pacify/unpacify zombies")
	gadgetHandler:AddChatAction("zombiesuspendorders", commandSuspendAutoOrders, "Suspend/resume zombie auto-orders")
	gadgetHandler:AddChatAction("zombieaggroteam", commandAggroZombiesToTeam, "Make zombies aggro to specific team")
	gadgetHandler:AddChatAction("zombieaggroally", commandAggroZombiesToAlly, "Make zombies aggro to entire ally team")
	gadgetHandler:AddChatAction("zombiekillall", commandKillAllZombies, "Kill all zombies")
	gadgetHandler:AddChatAction("zombieclearallorders", commandClearAllZombieOrders, "Clear allzombie orders")
	gadgetHandler:AddChatAction("zombiemode", commandSetZombieMode, "Set zombie mode (normal/hard/nightmare/akumu)")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("zombiesetallgaia")
	gadgetHandler:RemoveChatAction("zombiequeueallcorpses")
	gadgetHandler:RemoveChatAction("zombieautospawn")
	gadgetHandler:RemoveChatAction("zombieclearspawns")
	gadgetHandler:RemoveChatAction("zombiepacify")
	gadgetHandler:RemoveChatAction("zombiesuspendorders")
	gadgetHandler:RemoveChatAction("zombieaggroteam")
	gadgetHandler:RemoveChatAction("zombieaggroally")
	gadgetHandler:RemoveChatAction("zombiekillall")
	gadgetHandler:RemoveChatAction("zombieclearallorders")
	gadgetHandler:RemoveChatAction("zombiemode")
end

function gadget:GameStart()
	setGaiaStorage()
end
