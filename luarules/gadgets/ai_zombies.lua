function gadget:GetInfo()
	return {
		name = "Zombie AI",
		desc = "Controls autonomous Gaia zombie behavior",
		author = "SethDGamre",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = 3, -- after game_zombies.lua
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spring = Spring
local modOptions = spring.GetModOptions()
local modOptionEnabled = modOptions.zombies ~= "disabled"
local isIdleMode = GG.Zombies and GG.Zombies.IdleMode == true or false
if not modOptionEnabled and not isIdleMode then
	return false
end

local random = math.random
local distance2dSquared = math.distance2dSquared
local TAU = 2 * math.pi
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local DEGREES_TO_RADIANS = math.pi / 180

local ZOMBIE_ORDER_CHECK_INTERVAL = Game.gameSpeed * 3
local STUCK_CHECK_INTERVAL = Game.gameSpeed * 12
local STUCK_SELF_DESTRUCT_INTERVAL = Game.gameSpeed * 60 * 3
local AGGRO_CHECK_INTERVAL = Game.gameSpeed * 30
local AGGRO_DURATION = Game.gameSpeed * 60
local AGGRO_MIN_START_FRAME = Game.gameSpeed * 60 * 15
local WRAITH_ORDER_COOLDOWN = Game.gameSpeed * 5

local STUCK_DISTANCE = 50
local STUCK_DISTANCE_SQUARED = STUCK_DISTANCE ^ 2
local STUCK_SELF_DESTRUCT_DISTANCE = 300
local STUCK_SELF_DESTRUCT_DISTANCE_SQUARED = STUCK_SELF_DESTRUCT_DISTANCE ^ 2
local NOGO_ZONE_RADIUS = 600
local NOGO_ZONE_RADIUS_SQUARED = NOGO_ZONE_RADIUS ^ 2
local ENEMY_ATTACK_DISTANCE = 1000
local CONSTRUCTOR_SEARCH_DISTANCE = 400
local CONSTRUCTOR_SEARCH_DISTANCE_SQUARED = CONSTRUCTOR_SEARCH_DISTANCE ^ 2
local WRAITH_ENEMY_RADIUS = 250
local WRAITH_ENEMY_RADIUS_SQUARED = WRAITH_ENEMY_RADIUS * WRAITH_ENEMY_RADIUS
local ORDER_DISTANCE = 1600
local OBJECTIVE_REACHED_DISTANCE = 200
local OBJECTIVE_REACHED_DISTANCE_SQUARED = OBJECTIVE_REACHED_DISTANCE ^ 2
local COMBAT_TARGET_MOVE_REFRESH_DISTANCE = 250
local COMBAT_TARGET_MOVE_REFRESH_DISTANCE_SQUARED = COMBAT_TARGET_MOVE_REFRESH_DISTANCE ^ 2
local POSITION_VARIANCE = 50

local ZOMBIE_MAX_ORDER_ATTEMPTS = 10
local ZOMBIE_FACTORY_BUILD_COUNT = 20
local MAX_NOGO_ZONES = 10
local AGGRO_ZOMBIE_TO_PLAYER_POWER_RATIO = 0.1 -- the threshold of relative power where zombies stop wandering and swarm players
local COMBAT_ENGAGE_RANGE_RATIO = 0.5

local NORMAL_OBJECTIVE_ANGLE_VARIANCE = 90 * DEGREES_TO_RADIANS
local AGGRO_OBJECTIVE_ANGLE_VARIANCE = 22.5 * DEGREES_TO_RADIANS
local COMBAT_SECONDARY_ANGLE_OFFSET = 45 * DEGREES_TO_RADIANS
local COMBAT_SECONDARY_ANGLE_COS = cos(COMBAT_SECONDARY_ANGLE_OFFSET)
local COMBAT_SECONDARY_ANGLE_SIN = sin(COMBAT_SECONDARY_ANGLE_OFFSET)

local CMD_REPEAT = CMD.REPEAT
local CMD_MOVE_STATE = CMD.MOVE_STATE
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_IDLEMODE = CMD.IDLEMODE
local CMD_MOVE = CMD.MOVE
local CMD_FIGHT = CMD.FIGHT
local CMD_CAPTURE = CMD.CAPTURE
local CMD_RECLAIM = CMD.RECLAIM
local CMD_RESURRECT = CMD.RESURRECT
local CMD_STOP = CMD.STOP
local CMD_SELF_DESTRUCT = CMD.SELFD
local CMD_OPT_SHIFT = { "shift" }

local FIRE_STATE_FIRE_AT_ALL = 3
local FIRE_STATE_RETURN_FIRE = 1
local MOVE_STATE_ROAM = 2
local IDLEMODE_FLY = 0
local ENABLE_REPEAT = 1
local NULL_ATTACKER = -1
local ENVIRONMENTAL_DAMAGE_ID = Game.envDamageTypes.GroundCollision

local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ
local MAP_PERIMETER = 2 * (MAP_SIZE_X + MAP_SIZE_Z)
local WATER_IS_LAVA = BAR.Lava ~= nil and BAR.Lava.isLavaMap == true
local FEATURE_ID_OFFSET = Game.maxUnits
local OBJECTIVE_TYPE_NORMAL = 1
local OBJECTIVE_TYPE_AGGRO = 2
local ENEMY_DIRECTION_TOWARD = 1
local ENEMY_DIRECTION_AWAY = -1

local clamp = math.clamp
local spGetUnitNearestEnemy = spring.GetUnitNearestEnemy
local spValidUnitID = spring.ValidUnitID
local spGetGroundHeight = spring.GetGroundHeight
local spGetUnitPosition = spring.GetUnitPosition
local spGetUnitDefID = spring.GetUnitDefID
local spGiveOrderToUnit = spring.GiveOrderToUnit
local spGiveOrderArrayToUnit = spring.GiveOrderArrayToUnit
local spGetFactoryCommandCount = spring.GetFactoryCommandCount
local spGetUnitIsDead = spring.GetUnitIsDead
local spGetUnitIsBeingBuilt = spring.GetUnitIsBeingBuilt
local spGetUnitHealth = spring.GetUnitHealth
local spGetUnitRulesParam = spring.GetUnitRulesParam
local spTestMoveOrder = spring.TestMoveOrder
local spGetUnitCurrentCommand = spring.GetUnitCurrentCommand
local spGetUnitTeam = spring.GetUnitTeam
local spGetUnitLosState = spring.GetUnitLosState
local spGetUnitsInCylinder = spring.GetUnitsInCylinder
local spGetUnitWorkerTask = spring.GetUnitWorkerTask
local spAreTeamsAllied = spring.AreTeamsAllied
local spGetClosestEnemyUnit = spring.GetClosestEnemyUnit

local gaiaTeamID = spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, spring.GetTeamInfo(gaiaTeamID))
local readAsGaia = { ctrl = gaiaTeamID, read = gaiaTeamID, select = gaiaTeamID }
local IS_PVE_GAME = BAR.Utilities.Gametype.IsScavengers() or BAR.Utilities.Gametype.IsRaptors()
local scavTeamID
for _, teamID in ipairs(spring.GetTeamList()) do
	local teamLuaAI = spring.GetTeamLuaAI(teamID)
	if teamLuaAI and string.find(teamLuaAI, "ScavengersAI", 1, true) then
		scavTeamID = teamID
		break
	end
end

local ordersEnabled = true
local isPacified = false
local autoOrdersSuspended = false
local gameFrame = 0
local totalMobileZombiePower = 0
local aggroExpirationTimestamp = 0
local permanentlyAggro = false

local mobileUnitDefs = {}
local aircraftUnitDefs = {}
local factoriesWithWantedOptions = {}
local unitDefWeaponRanges = {}
local capturingUnits = {}
local objectifyUnitDefs = {}
local resurrectingUnits = {}
local zombieAggros = {}
local allyTeamUnits = {}
local teamAllyTeamIDs = {}
local unitAllyTeamIDs = {}
local unitAllyTeamIndices = {}
local zombieWatch = {}
local wraithWatch = {}
local flyingUnits = {}
local zombieOrderBuckets = {}
local zombieStuckBuckets = {}
local trackedUnitData = {
	canFly = {},
	height = {},
	capturableOrObjective = {},
	defIDs = {},
	teamIDs = {},
	airEngage = {},
	groundEngage = {},
}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canCapture then
		capturingUnits[unitDefID] = true
	end
	if unitDef.customParams and unitDef.customParams.objectify then
		objectifyUnitDefs[unitDefID] = true
	end
	if unitDef.canResurrect then
		resurrectingUnits[unitDefID] = true
	end

	if unitDef.weapons and #unitDef.weapons > 0 then
		local maximumGroundWeaponRange = 0
		local maximumAirWeaponRange = 0
		local maximumUnderwaterWeaponRange = 0

		for weaponIndex = 1, #unitDef.weapons do
			local weapon = unitDef.weapons[weaponIndex]
			local weaponDefID = weapon.weaponDef
			if weaponDefID then
				local weaponDef = WeaponDefs[weaponDefID]
				if
					weaponDef
					and weaponDef.range
					and weaponDef.range > 0
					and not (weaponDef.customParams and weaponDef.customParams.bogus)
				then
					local isAAWeapon = weapon.onlyTargets and weapon.onlyTargets.vtol and not weapon.onlyTargets.ground
					local isUnderwaterOnly = weaponDef.type == "TorpedoLauncher"

					if isAAWeapon then
						maximumAirWeaponRange = math.max(maximumAirWeaponRange, weaponDef.range)
					elseif isUnderwaterOnly then
						maximumUnderwaterWeaponRange = math.max(maximumUnderwaterWeaponRange, weaponDef.range)
					else
						maximumGroundWeaponRange = math.max(maximumGroundWeaponRange, weaponDef.range)
						if weapon.onlyTargets and weapon.onlyTargets.vtol then
							maximumAirWeaponRange = math.max(maximumAirWeaponRange, weaponDef.range)
						end
						if weaponDef.waterWeapon then
							maximumUnderwaterWeaponRange = math.max(maximumUnderwaterWeaponRange, weaponDef.range)
						end
					end
				end
			end
		end

		if maximumGroundWeaponRange > 0 or maximumAirWeaponRange > 0 or maximumUnderwaterWeaponRange > 0 then
			unitDefWeaponRanges[unitDefID] = {
				ground = maximumGroundWeaponRange,
				air = maximumAirWeaponRange,
				underwater = maximumUnderwaterWeaponRange,
			}
		end
	end
	local isObjective = objectifyUnitDefs[unitDefID] == true
	trackedUnitData.canFly[unitDefID] = unitDef.canFly == true
	trackedUnitData.height[unitDefID] = unitDef.height or 0
	trackedUnitData.capturableOrObjective[unitDefID] = isObjective or unitDef.capturable ~= false
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.speed > 0 then
		mobileUnitDefs[unitDefID] = true
		if unitDef.canFly then
			aircraftUnitDefs[unitDefID] = true
		end
	elseif #unitDef.buildOptions > 0 then
		local wantedOptions = {}
		for optionIndex = 1, #unitDef.buildOptions do
			local optionDefID = unitDef.buildOptions[optionIndex]
			local optionDef = UnitDefs[optionDefID]
			local isConstructor = optionDef and optionDef.isBuilder and optionDef.speed > 0
			local isResurrector = optionDef and optionDef.canResurrect
			local isExcluded = optionDef and optionDef.customParams.zombie_factory_exclude
			if not isExcluded and (unitDefWeaponRanges[optionDefID] or isConstructor or isResurrector) then
				wantedOptions[#wantedOptions + 1] = optionDefID
			end
		end
		if #wantedOptions > 0 then
			factoriesWithWantedOptions[unitDefID] = wantedOptions
		end
	end
end

for bucketIndex = 1, ZOMBIE_ORDER_CHECK_INTERVAL do
	zombieOrderBuckets[bucketIndex] = {}
end

for bucketIndex = 1, STUCK_CHECK_INTERVAL do
	zombieStuckBuckets[bucketIndex] = {}
end

local function removeZombieFromBucket(unitID, bucket, unitIndex, indexField)
	local lastIndex = #bucket
	local lastUnitID = bucket[lastIndex]
	bucket[unitIndex] = lastUnitID
	bucket[lastIndex] = nil
	if lastUnitID ~= unitID then
		zombieWatch[lastUnitID][indexField] = unitIndex
	end
end

local function unwatchZombie(unitID)
	local zombieData = zombieWatch[unitID]
	if not zombieData then
		return
	end
	if mobileUnitDefs[zombieData.unitDefID] then
		totalMobileZombiePower = totalMobileZombiePower - zombieData.power
	end
	removeZombieFromBucket(
		unitID,
		zombieOrderBuckets[unitID % ZOMBIE_ORDER_CHECK_INTERVAL + 1],
		zombieData.orderBucketIndex,
		"orderBucketIndex"
	)
	removeZombieFromBucket(
		unitID,
		zombieStuckBuckets[unitID % STUCK_CHECK_INTERVAL + 1],
		zombieData.stuckBucketIndex,
		"stuckBucketIndex"
	)
	zombieWatch[unitID] = nil
	zombieAggros[unitID] = nil
end

local function setAggroExpiration()
	aggroExpirationTimestamp = gameFrame + AGGRO_DURATION
end

local function getActiveZombieAggro(unitID)
	if not permanentlyAggro and gameFrame >= aggroExpirationTimestamp then
		return nil
	end
	return zombieAggros[unitID]
end

local function getTeamAllyTeamID(teamID)
	local allyTeamID = teamAllyTeamIDs[teamID]
	if not allyTeamID then
		allyTeamID = select(6, spring.GetTeamInfo(teamID, false))
		teamAllyTeamIDs[teamID] = allyTeamID
	end
	return allyTeamID
end

local function addAllyTeamUnit(unitID, allyTeamID)
	if not allyTeamID or unitAllyTeamIDs[unitID] then
		return
	end
	local unitList = allyTeamUnits[allyTeamID]
	if not unitList then
		unitList = {}
		allyTeamUnits[allyTeamID] = unitList
	end
	local unitIndex = #unitList + 1
	unitList[unitIndex] = unitID
	unitAllyTeamIDs[unitID] = allyTeamID
	unitAllyTeamIndices[unitID] = unitIndex
end

local function removeAllyTeamUnit(unitID)
	local allyTeamID = unitAllyTeamIDs[unitID]
	if not allyTeamID then
		return
	end
	local unitList = allyTeamUnits[allyTeamID]
	local unitIndex = unitAllyTeamIndices[unitID]
	local lastIndex = #unitList
	local lastUnitID = unitList[lastIndex]
	unitList[unitIndex] = lastUnitID
	unitList[lastIndex] = nil
	if lastUnitID ~= unitID then
		unitAllyTeamIndices[lastUnitID] = unitIndex
	end
	unitAllyTeamIDs[unitID] = nil
	unitAllyTeamIndices[unitID] = nil
end

local function rememberUnitIdentity(unitID, unitDefID, unitTeamID)
	trackedUnitData.defIDs[unitID] = unitDefID
	trackedUnitData.teamIDs[unitID] = unitTeamID
end

local function forgetUnitIdentity(unitID)
	trackedUnitData.defIDs[unitID] = nil
	trackedUnitData.teamIDs[unitID] = nil
end

local function isZombie(unitID)
	return spGetUnitRulesParam(unitID, "zombie") == 1
end

local function issueRandomFactoryBuildOrders(unitID, unitDefID, buildCount)
	local wantedOptions = factoriesWithWantedOptions[unitDefID]
	if not wantedOptions then
		return
	end
	local buildOrders = {}
	for buildIndex = 1, buildCount do
		buildOrders[#buildOrders + 1] = { -wantedOptions[random(1, #wantedOptions)], 0, 0 }
	end
	spGiveOrderArrayToUnit(unitID, buildOrders)
end

local function clearUnitOrders(unitID)
	if spValidUnitID(unitID) then
		spGiveOrderToUnit(unitID, CMD_STOP, {}, {})
	end
end

local function rememberEngage(engageByAttacker, attackerDefID, targetDefID, canEngage)
	local engageByTarget = engageByAttacker[attackerDefID]
	if not engageByTarget then
		engageByTarget = {}
		engageByAttacker[attackerDefID] = engageByTarget
	end
	engageByTarget[targetDefID] = canEngage
	return canEngage
end

local function canEngageAirTargetDef(attackerDefID, targetDefID)
	local engageByTarget = trackedUnitData.airEngage[attackerDefID]
	local cachedEngage = engageByTarget and engageByTarget[targetDefID]
	if cachedEngage ~= nil then
		return cachedEngage
	end
	local weaponRanges = unitDefWeaponRanges[attackerDefID] ---@as { ground: number, air: number, underwater: number }?
	local canEngage = weaponRanges ~= nil and weaponRanges.air > 0
	if not canEngage and capturingUnits[attackerDefID] and trackedUnitData.capturableOrObjective[targetDefID] then
		canEngage = true
	end
	return rememberEngage(trackedUnitData.airEngage, attackerDefID, targetDefID, canEngage)
end

local function canEngageGroundTargetDef(attackerDefID, targetDefID)
	local engageByTarget = trackedUnitData.groundEngage[attackerDefID]
	local cachedEngage = engageByTarget and engageByTarget[targetDefID]
	if cachedEngage ~= nil then
		return cachedEngage
	end
	local weaponRanges = unitDefWeaponRanges[attackerDefID] ---@as { ground: number, air: number, underwater: number }?
	local canEngage = weaponRanges ~= nil and (weaponRanges.ground > 0 or weaponRanges.underwater > 0)
	if not canEngage and capturingUnits[attackerDefID] and trackedUnitData.capturableOrObjective[targetDefID] then
		canEngage = true
	end
	return rememberEngage(trackedUnitData.groundEngage, attackerDefID, targetDefID, canEngage)
end

local function attackerMightEngage(attackerDefID, targetDefID, targetID)
	if not targetDefID then
		return true
	end
	if trackedUnitData.canFly[targetDefID] or flyingUnits[targetID] then
		return canEngageAirTargetDef(attackerDefID, targetDefID)
	end
	return canEngageGroundTargetDef(attackerDefID, targetDefID)
end

local function cachedUnitDefID(unitID)
	local cachedDefID = trackedUnitData.defIDs[unitID] ---@as UnitDefID?
	if cachedDefID then
		return cachedDefID
	end
	cachedDefID = spGetUnitDefID(unitID)
	if cachedDefID then
		trackedUnitData.defIDs[unitID] = cachedDefID
	end
	return cachedDefID
end

local function cachedUnitTeamID(unitID)
	local cachedTeamID = trackedUnitData.teamIDs[unitID] ---@as TeamID?
	if cachedTeamID then
		return cachedTeamID
	end
	cachedTeamID = spGetUnitTeam(unitID)
	if cachedTeamID then
		trackedUnitData.teamIDs[unitID] = cachedTeamID
	end
	return cachedTeamID
end

local function getWeaponRangeForTarget(attackerDefID, targetID, targetDefID, targetYPosition)
	local weaponRanges = unitDefWeaponRanges[attackerDefID]
	if not weaponRanges then
		return
	end
	local weaponRange
	if flyingUnits[targetID] or trackedUnitData.canFly[targetDefID] then
		weaponRange = weaponRanges.air
	elseif targetYPosition + (trackedUnitData.height[targetDefID] or 0) < 0 then
		weaponRange = weaponRanges.underwater
	else
		weaponRange = weaponRanges.ground
	end
	if weaponRange and weaponRange > 0 then
		return weaponRange
	end
	return nil
end

local function isUnitInGaiaLos(unitID)
	local losState = spGetUnitLosState(unitID, gaiaAllyTeamID, true)
	return losState and losState % 2 == 1 -- raw LOS mask: odd means currently in Gaia sight
end

local function isPositionInLava(positionY)
	return WATER_IS_LAVA and _G.lavaLevel ~= nil and positionY < _G.lavaLevel
end

local function getCombatTargetData(unitDefID, targetID)
	if not targetID or spGetUnitIsDead(targetID) ~= false then
		return
	end
	local targetTeamID = cachedUnitTeamID(targetID)
	if not targetTeamID or spAreTeamsAllied(gaiaTeamID, targetTeamID) then
		return
	end
	local targetDefID = cachedUnitDefID(targetID)
	if targetDefID and not attackerMightEngage(unitDefID, targetDefID, targetID) then
		return
	end
	local targetX, targetY, targetZ = spGetUnitPosition(targetID)
	if not targetX or not targetDefID then
		return
	end
	local isObjective = objectifyUnitDefs[targetDefID] == true
	local targetIsTakeable = capturingUnits[unitDefID]
		and trackedUnitData.capturableOrObjective[targetDefID]
		and not spGetUnitIsBeingBuilt(targetID)
		and isUnitInGaiaLos(targetID)
	local shouldReclaim = targetIsTakeable and isObjective
	local shouldCapture = targetIsTakeable and not isObjective and not isPositionInLava(targetY)
	local weaponRange = getWeaponRangeForTarget(unitDefID, targetID, targetDefID, targetY)
	if shouldReclaim or shouldCapture or (weaponRange and weaponRange > 0) then
		return targetX, targetZ, shouldCapture, weaponRange, shouldReclaim
	end
end

local function restrictCaptureToSearchDistance(
	unitID,
	unitX,
	unitZ,
	targetX,
	targetZ,
	shouldCapture,
	weaponRange,
	shouldReclaim
)
	if not targetX or not shouldCapture then
		return unitX, unitZ, targetX, targetZ, shouldCapture, weaponRange, shouldReclaim
	end
	if not unitX then
		unitX, _, unitZ = spGetUnitPosition(unitID)
	end
	if unitX and distance2dSquared(unitX, unitZ, targetX, targetZ) <= CONSTRUCTOR_SEARCH_DISTANCE_SQUARED then
		return unitX, unitZ, targetX, targetZ, shouldCapture, weaponRange, shouldReclaim
	end
	if weaponRange and weaponRange > 0 then
		return unitX, unitZ, targetX, targetZ, false, weaponRange, shouldReclaim
	end
	return unitX, unitZ
end

local function getNearestCombatTarget(unitID, unitDefID, unitX, unitZ)
	local nearestEnemyID = spGetUnitNearestEnemy(unitID, ENEMY_ATTACK_DISTANCE, true)
	if not nearestEnemyID then
		return
	end
	local targetX, targetZ, shouldCapture, weaponRange, shouldReclaim = getCombatTargetData(unitDefID, nearestEnemyID)
	if targetX then
		unitX, unitZ, targetX, targetZ, shouldCapture, weaponRange, shouldReclaim = restrictCaptureToSearchDistance(
			unitID,
			unitX,
			unitZ,
			targetX,
			targetZ,
			shouldCapture,
			weaponRange,
			shouldReclaim
		)
		if targetX then
			return nearestEnemyID, targetX, targetZ, shouldCapture, weaponRange, shouldReclaim
		end
	end

	if not unitX then
		unitX, _, unitZ = spGetUnitPosition(unitID)
	end
	if not unitX then
		return
	end
	local enemyUnits =
		CallAsTeam(readAsGaia, spGetUnitsInCylinder, unitX, unitZ, ENEMY_ATTACK_DISTANCE, spring.ENEMY_UNITS) -- nearest-enemy API can return an unshootable unit, so fall back to a cylinder scan
	local chosenTargetID
	local chosenTargetX
	local chosenTargetZ
	local chosenShouldCapture
	local chosenWeaponRange
	local chosenShouldReclaim
	local validTargetCount = 0
	for enemyIndex = 1, #enemyUnits do
		local enemyID = enemyUnits[enemyIndex]
		if enemyID ~= nearestEnemyID then
			local enemyDefID = cachedUnitDefID(enemyID)
			if attackerMightEngage(unitDefID, enemyDefID, enemyID) then
				targetX, targetZ, shouldCapture, weaponRange, shouldReclaim = getCombatTargetData(unitDefID, enemyID)
				if targetX then
					unitX, unitZ, targetX, targetZ, shouldCapture, weaponRange, shouldReclaim =
						restrictCaptureToSearchDistance(
							unitID,
							unitX,
							unitZ,
							targetX,
							targetZ,
							shouldCapture,
							weaponRange,
							shouldReclaim
						)
				end
				if targetX then
					validTargetCount = validTargetCount + 1
					if random(1, validTargetCount) == 1 then
						chosenTargetID = enemyID
						chosenTargetX = targetX
						chosenTargetZ = targetZ
						chosenShouldCapture = shouldCapture
						chosenWeaponRange = weaponRange
						chosenShouldReclaim = shouldReclaim
					end
				end
			end
		end
	end
	return chosenTargetID, chosenTargetX, chosenTargetZ, chosenShouldCapture, chosenWeaponRange, chosenShouldReclaim
end

local function clampToMap(position, mapSize)
	return clamp(position, POSITION_VARIANCE, mapSize - POSITION_VARIANCE)
end

local function mapEdgeScale(origin, delta, mapSize)
	if delta > 0 then
		return (mapSize - origin) / delta
	elseif delta < 0 then
		return -origin / delta
	end
	return math.huge
end

local function setRandomEdgeObjective(zombieData)
	local perimeterPosition = random() * MAP_PERIMETER -- map a random perimeter length onto one of the four edges
	local objectiveX
	local objectiveZ
	if perimeterPosition < MAP_SIZE_X then
		objectiveX = perimeterPosition
		objectiveZ = 0
	elseif perimeterPosition < MAP_SIZE_X + MAP_SIZE_Z then
		objectiveX = MAP_SIZE_X
		objectiveZ = perimeterPosition - MAP_SIZE_X
	elseif perimeterPosition < MAP_SIZE_X * 2 + MAP_SIZE_Z then
		objectiveX = MAP_SIZE_X * 2 + MAP_SIZE_Z - perimeterPosition
		objectiveZ = MAP_SIZE_Z
	else
		objectiveX = 0
		objectiveZ = MAP_PERIMETER - perimeterPosition
	end
	objectiveX = clampToMap(objectiveX, MAP_SIZE_X)
	objectiveZ = clampToMap(objectiveZ, MAP_SIZE_Z)
	zombieData.objective = { type = OBJECTIVE_TYPE_NORMAL, x = objectiveX, z = objectiveZ }
end

local function getRandomValidAllyTeamUnit(allyTeamID)
	local unitList = allyTeamUnits[allyTeamID]
	if not unitList or #unitList == 0 then
		return
	end
	local attemptsRemaining = #unitList
	while attemptsRemaining > 0 do
		local targetUnitID = unitList[random(1, #unitList)]
		if spValidUnitID(targetUnitID) and not spGetUnitIsDead(targetUnitID) then
			local targetX, _, targetZ = spGetUnitPosition(targetUnitID)
			if targetX then
				return targetUnitID, targetX, targetZ
			end
		end
		removeAllyTeamUnit(targetUnitID)
		attemptsRemaining = attemptsRemaining - 1
	end
end

local function setAggroObjective(zombieData, allyTeamID)
	local targetUnitID, targetX, targetZ = getRandomValidAllyTeamUnit(allyTeamID)
	if not targetUnitID then
		return false
	end
	zombieData.objective = {
		type = OBJECTIVE_TYPE_AGGRO,
		x = targetX,
		z = targetZ,
		targetUnitID = targetUnitID,
	}
	return true
end

local function getLeastAssignedAlly(eligibleAllies)
	local leastAssignedAlly = eligibleAllies[1]
	for allyIndex = 2, #eligibleAllies do
		local allyData = eligibleAllies[allyIndex]
		if
			allyData.assignedPower < leastAssignedAlly.assignedPower
			or (
				allyData.assignedPower == leastAssignedAlly.assignedPower
				and allyData.allyTeamID < leastAssignedAlly.allyTeamID
			)
		then
			leastAssignedAlly = allyData
		end
	end
	return leastAssignedAlly
end

local function compareZombiePower(firstZombie, secondZombie)
	if firstZombie.power == secondZombie.power then
		return firstZombie.unitID < secondZombie.unitID
	end
	return firstZombie.power > secondZombie.power
end

local function isObjectiveReached(unitID, objective, unitX, unitZ)
	if not unitX then
		unitX, _, unitZ = spGetUnitPosition(unitID)
	end
	if not unitX then
		return false
	end
	return distance2dSquared(unitX, unitZ, objective.x, objective.z) <= OBJECTIVE_REACHED_DISTANCE_SQUARED
end

local function isAggroObjectiveValid(unitID, objective, allyTeamID, unitX, unitZ)
	if
		not objective
		or objective.type ~= OBJECTIVE_TYPE_AGGRO
		or unitAllyTeamIDs[objective.targetUnitID] ~= allyTeamID
	then
		return false
	end
	return not isObjectiveReached(unitID, objective, unitX, unitZ)
end

local function hasLiveAggroObjective(objective, allyTeamID)
	return objective
		and objective.type == OBJECTIVE_TYPE_AGGRO
		and unitAllyTeamIDs[objective.targetUnitID] == allyTeamID
end

local function assignZombieAggroEvenly()
	local playerTeams = GG.PowerLib.PlayerTeams
	local teamPowers = GG.PowerLib.TeamPowers
	local allyPowers = {}
	for teamID in pairs(playerTeams) do
		local allyTeamID = getTeamAllyTeamID(teamID)
		local teamPower = teamPowers[teamID] or 0
		allyPowers[allyTeamID] = (allyPowers[allyTeamID] or 0) + teamPower
	end

	local eligibleAllies = {}
	local eligibleAlliesByID = {}
	for allyTeamID, allyPower in pairs(allyPowers) do
		local allyUnitList = allyTeamUnits[allyTeamID] ---@as UnitID[]?
		if allyPower > 0 and allyUnitList and #allyUnitList > 0 then
			local allyData = {
				allyTeamID = allyTeamID,
				assignedPower = 0,
			}
			eligibleAllies[#eligibleAllies + 1] = allyData
			eligibleAlliesByID[allyTeamID] = allyData
		end
	end

	local zombiesNeedingAggro = {}
	for unitID, zombieData in pairs(zombieWatch) do
		if mobileUnitDefs[zombieData.unitDefID] then
			local allyTeamID = zombieAggros[unitID]
			local allyData = allyTeamID and eligibleAlliesByID[allyTeamID]
			if
				allyData
				and hasLiveAggroObjective(zombieData.objective, allyTeamID)
				and not zombieData.aggroObjectiveReached
			then
				allyData.assignedPower = allyData.assignedPower + zombieData.power
			else
				zombieData.aggroObjectiveReached = nil
				zombieAggros[unitID] = nil
				if zombieData.objective and zombieData.objective.type == OBJECTIVE_TYPE_AGGRO then
					zombieData.objective = nil
				end
				zombiesNeedingAggro[#zombiesNeedingAggro + 1] = {
					unitID = unitID,
					power = zombieData.power,
				}
			end
		else
			zombieAggros[unitID] = nil
			if zombieData.objective and zombieData.objective.type == OBJECTIVE_TYPE_AGGRO then
				zombieData.objective = nil
			end
		end
	end

	if #eligibleAllies == 0 then
		return
	end

	table.sort(zombiesNeedingAggro, compareZombiePower) -- keep valid assignments, then give strongest leftovers to the least-pressured ally
	for zombieIndex = 1, #zombiesNeedingAggro do
		local pendingZombie = zombiesNeedingAggro[zombieIndex]
		local zombieData = zombieWatch[pendingZombie.unitID]
		local leastAssignedAlly = getLeastAssignedAlly(eligibleAllies)
		if setAggroObjective(zombieData, leastAssignedAlly.allyTeamID) then
			zombieAggros[pendingZombie.unitID] = leastAssignedAlly.allyTeamID
			leastAssignedAlly.assignedPower = leastAssignedAlly.assignedPower + pendingZombie.power
		end
	end
end

local function knownUnitXZ(unitID, knownX, knownZ)
	if knownX then
		return knownX, knownZ
	end
	local fetchedX, _, fetchedZ = spGetUnitPosition(unitID)
	return fetchedX, fetchedZ
end

local function setEnemyDirectionObjective(unitID, zombieData, targetX, targetZ, enemyDirection, unitX, unitZ)
	unitX, unitZ = knownUnitXZ(unitID, unitX, unitZ)
	if not unitX then
		return false
	end
	local deltaX = (targetX - unitX) * enemyDirection
	local deltaZ = (targetZ - unitZ) * enemyDirection
	if deltaX == 0 and deltaZ == 0 then
		return false
	end
	local boundaryScale = math.min( -- project the enemy bearing out to the map edge
		mapEdgeScale(unitX, deltaX, MAP_SIZE_X),
		mapEdgeScale(unitZ, deltaZ, MAP_SIZE_Z)
	)
	zombieData.rememberedObjectiveX = clampToMap(unitX + deltaX * boundaryScale, MAP_SIZE_X)
	zombieData.rememberedObjectiveZ = clampToMap(unitZ + deltaZ * boundaryScale, MAP_SIZE_Z)
	if zombieData.objective and zombieData.objective.type == OBJECTIVE_TYPE_AGGRO then
		return false
	end
	zombieData.objective = {
		type = OBJECTIVE_TYPE_NORMAL,
		x = zombieData.rememberedObjectiveX,
		z = zombieData.rememberedObjectiveZ,
	}
	return true
end

local function objectiveIsRememberedEdge(zombieData, objective)
	return zombieData.rememberedObjectiveX
		and objective
		and objective.type == OBJECTIVE_TYPE_NORMAL
		and objective.x == zombieData.rememberedObjectiveX
		and objective.z == zombieData.rememberedObjectiveZ
end

local function ensureMovementObjective(unitID, zombieData, allyTeamID, unitX, unitZ)
	local objective = zombieData.objective -- aggro target, else last-seen enemy edge, else a new map-edge wander
	if not unitX and (objective or zombieData.rememberedObjectiveX) then
		unitX, _, unitZ = spGetUnitPosition(unitID)
	end
	if allyTeamID then
		if isAggroObjectiveValid(unitID, objective, allyTeamID, unitX, unitZ) then
			return objective, false
		end
		if hasLiveAggroObjective(objective, allyTeamID) then
			zombieData.aggroObjectiveReached = true
		end
		if objective and objective.type == OBJECTIVE_TYPE_AGGRO then
			zombieData.objective = nil
		end
		if setAggroObjective(zombieData, allyTeamID) then
			return zombieData.objective, true
		end
		if zombieAggros[unitID] == allyTeamID then
			zombieAggros[unitID] = nil
		end
	end

	objective = zombieData.objective
	if zombieData.rememberedObjectiveX then
		if objectiveIsRememberedEdge(zombieData, objective) and isObjectiveReached(unitID, objective, unitX, unitZ) then
			zombieData.rememberedObjectiveX = nil
			zombieData.rememberedObjectiveZ = nil
			zombieData.objective = nil
			objective = nil
		elseif not objectiveIsRememberedEdge(zombieData, objective) then
			zombieData.objective = {
				type = OBJECTIVE_TYPE_NORMAL,
				x = zombieData.rememberedObjectiveX,
				z = zombieData.rememberedObjectiveZ,
			}
			return zombieData.objective, true
		else
			return objective, false
		end
	end

	if
		not objective
		or objective.type ~= OBJECTIVE_TYPE_NORMAL
		or isObjectiveReached(unitID, objective, unitX, unitZ)
	then
		setRandomEdgeObjective(zombieData)
		return zombieData.objective, true
	end
	return objective, false
end

local function isInNoGoZone(zombieData, targetX, targetZ)
	for _, zone in ipairs(zombieData.noGoZones) do
		local deltaX = targetX - zone.x
		local deltaZ = targetZ - zone.z
		if deltaX * deltaX + deltaZ * deltaZ < NOGO_ZONE_RADIUS_SQUARED then
			return true
		end
	end
	return false
end

local function isMoveTargetTraversable(unitDefID, targetX, targetY, targetZ)
	if aircraftUnitDefs[unitDefID] then
		return true
	end
	return spTestMoveOrder(unitDefID, targetX, targetY, targetZ)
end

local function getMovementCommand(unitDefID)
	if aircraftUnitDefs[unitDefID] then
		return CMD_FIGHT
	end
	return CMD_MOVE
end

local function getObjectiveMoveTarget(unitDefID, zombieData, objective, originX, originZ, attemptLimit)
	local deltaX = objective.x - originX
	local deltaZ = objective.z - originZ
	local objectiveDistance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
	local objectiveAngle = atan2(deltaZ, deltaX)
	local angleVariance = objective.type == OBJECTIVE_TYPE_AGGRO and AGGRO_OBJECTIVE_ANGLE_VARIANCE
		or NORMAL_OBJECTIVE_ANGLE_VARIANCE
	local attemptCount = attemptLimit or 4

	for attemptIndex = 1, attemptCount do
		local movementAngle
		local movementDistance = math.min(ORDER_DISTANCE, objectiveDistance)
		if attemptIndex == attemptCount then
			movementAngle = random() * TAU -- last try: ignore the objective and pick any passable heading
			movementDistance = ORDER_DISTANCE
		else
			movementAngle = objectiveAngle + (random() * 2 - 1) * angleVariance
		end
		local candidateTargetX = clampToMap(
			originX + movementDistance * cos(movementAngle) + random(-POSITION_VARIANCE, POSITION_VARIANCE),
			MAP_SIZE_X
		)
		local candidateTargetZ = clampToMap(
			originZ + movementDistance * sin(movementAngle) + random(-POSITION_VARIANCE, POSITION_VARIANCE),
			MAP_SIZE_Z
		)
		if not isInNoGoZone(zombieData, candidateTargetX, candidateTargetZ) then
			local candidateTargetY = spGetGroundHeight(candidateTargetX, candidateTargetZ)
			if isMoveTargetTraversable(unitDefID, candidateTargetX, candidateTargetY, candidateTargetZ) then
				return candidateTargetX, candidateTargetY, candidateTargetZ
			end
		end
	end
end

local function issueObjectiveMove(unitID, unitDefID, zombieData, objective, unitX, unitZ, attemptLimit)
	unitX, unitZ = knownUnitXZ(unitID, unitX, unitZ)
	if not unitX then
		return
	end

	local movementCommand = getMovementCommand(unitDefID)
	local firstTargetX, firstTargetY, firstTargetZ =
		getObjectiveMoveTarget(unitDefID, zombieData, objective, unitX, unitZ, attemptLimit)
	if firstTargetX then
		spGiveOrderToUnit(unitID, movementCommand, { firstTargetX, firstTargetY, firstTargetZ }, 0)
		zombieData.moveOrderX = firstTargetX
		zombieData.moveOrderZ = firstTargetZ
		return
	end

	clearUnitOrders(unitID)
	if objective.type == OBJECTIVE_TYPE_AGGRO or not zombieData.rememberedObjectiveX then
		zombieData.objective = nil
		ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID), unitX, unitZ)
	end
end

local function clearLastCombatTarget(zombieData)
	zombieData.lastCombatTargetX = nil
	zombieData.lastCombatTargetZ = nil
	zombieData.lastOrbitX = nil
	zombieData.lastOrbitZ = nil
end

local function clearCombatTracking(zombieData)
	zombieData.combatTargetID = nil
	clearLastCombatTarget(zombieData)
end

local function abandonCombatToObjective(unitID, unitDefID, zombieData, unitX, unitZ)
	clearCombatTracking(zombieData)
	clearUnitOrders(unitID)
	local fallbackObjective = ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID), unitX, unitZ)
	issueObjectiveMove(unitID, unitDefID, zombieData, fallbackObjective, unitX, unitZ)
end

local function isReusableCombatOrbit(zombieData, targetX, targetZ, desiredRange)
	local orbitX = zombieData.lastOrbitX
	local orbitZ = zombieData.lastOrbitZ
	if not orbitX or orbitX < 0 or orbitX > MAP_SIZE_X or orbitZ < 0 or orbitZ > MAP_SIZE_Z then
		return false
	end
	local deltaX = orbitX - targetX
	local deltaZ = orbitZ - targetZ
	local orbitDistanceSquared = deltaX * deltaX + deltaZ * deltaZ
	local minimumRange = desiredRange - COMBAT_TARGET_MOVE_REFRESH_DISTANCE
	if minimumRange < 0 then
		minimumRange = 0
	end
	local maximumRange = desiredRange + COMBAT_TARGET_MOVE_REFRESH_DISTANCE
	return orbitDistanceSquared >= minimumRange * minimumRange and orbitDistanceSquared <= maximumRange * maximumRange
end

local function issueCombatMove(unitID, unitDefID, weaponRange, targetX, targetZ, zombieData, unitX, unitZ)
	unitX, unitZ = knownUnitXZ(unitID, unitX, unitZ)
	if not unitX then
		clearLastCombatTarget(zombieData)
		clearUnitOrders(unitID)
		return
	end
	local deltaX = unitX - targetX
	local deltaZ = unitZ - targetZ
	local distance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
	if distance == 0 then
		clearUnitOrders(unitID)
		return
	end
	local desiredRange = weaponRange * COMBAT_ENGAGE_RANGE_RATIO
	local targetMoveX = targetX + deltaX / distance * desiredRange
	local targetMoveZ = targetZ + deltaZ / distance * desiredRange
	if targetMoveX < 0 or targetMoveX > MAP_SIZE_X or targetMoveZ < 0 or targetMoveZ > MAP_SIZE_Z then
		abandonCombatToObjective(unitID, unitDefID, zombieData, unitX, unitZ)
		return
	end
	local targetMoveY = spGetGroundHeight(targetMoveX, targetMoveZ)
	local isTargetMoveValid = isMoveTargetTraversable(unitDefID, targetMoveX, targetMoveY, targetMoveZ)
	if not isTargetMoveValid then
		abandonCombatToObjective(unitID, unitDefID, zombieData, unitX, unitZ)
		return
	end
	local movementCommand = getMovementCommand(unitDefID)
	spGiveOrderToUnit(unitID, movementCommand, { targetMoveX, targetMoveY, targetMoveZ }, 0)
	if isReusableCombatOrbit(zombieData, targetX, targetZ, desiredRange) then
		local orbitY = spGetGroundHeight(zombieData.lastOrbitX, zombieData.lastOrbitZ)
		spGiveOrderToUnit(
			unitID,
			movementCommand,
			{ zombieData.lastOrbitX, orbitY, zombieData.lastOrbitZ },
			CMD_OPT_SHIFT
		)
		zombieData.lastCombatTargetX = targetX
		zombieData.lastCombatTargetZ = targetZ
		return
	end
	local radialX = targetMoveX - targetX -- queue a 45° orbit around the target so they don't halt at engage range
	local radialZ = targetMoveZ - targetZ
	local rotationDirection = random() < 0.5 and -1 or 1
	local issuedSecondaryMove = false
	for attemptIndex = 1, 2 do
		local signedSin = COMBAT_SECONDARY_ANGLE_SIN * rotationDirection
		local secondaryTargetX = targetX + radialX * COMBAT_SECONDARY_ANGLE_COS - radialZ * signedSin
		local secondaryTargetZ = targetZ + radialX * signedSin + radialZ * COMBAT_SECONDARY_ANGLE_COS
		if
			secondaryTargetX >= 0
			and secondaryTargetX <= MAP_SIZE_X
			and secondaryTargetZ >= 0
			and secondaryTargetZ <= MAP_SIZE_Z
		then
			local secondaryTargetY = spGetGroundHeight(secondaryTargetX, secondaryTargetZ)
			if isMoveTargetTraversable(unitDefID, secondaryTargetX, secondaryTargetY, secondaryTargetZ) then
				spGiveOrderToUnit(
					unitID,
					movementCommand,
					{ secondaryTargetX, secondaryTargetY, secondaryTargetZ },
					CMD_OPT_SHIFT
				)
				zombieData.lastOrbitX = secondaryTargetX
				zombieData.lastOrbitZ = secondaryTargetZ
				issuedSecondaryMove = true
				break
			end
		end
		rotationDirection = -rotationDirection
	end
	if not issuedSecondaryMove then
		local secondaryTargetX = targetX + radialX * COMBAT_ENGAGE_RANGE_RATIO
		local secondaryTargetZ = targetZ + radialZ * COMBAT_ENGAGE_RANGE_RATIO
		local secondaryTargetY = spGetGroundHeight(secondaryTargetX, secondaryTargetZ)
		if isMoveTargetTraversable(unitDefID, secondaryTargetX, secondaryTargetY, secondaryTargetZ) then
			spGiveOrderToUnit(
				unitID,
				movementCommand,
				{ secondaryTargetX, secondaryTargetY, secondaryTargetZ },
				CMD_OPT_SHIFT
			)
			zombieData.lastOrbitX = secondaryTargetX
			zombieData.lastOrbitZ = secondaryTargetZ
		end
	end
	zombieData.lastCombatTargetX = targetX
	zombieData.lastCombatTargetZ = targetZ
end

local function getRandomResurrectableWreck(unitID, unitX, unitZ)
	unitX, unitZ = knownUnitXZ(unitID, unitX, unitZ)
	if not unitX then
		return
	end
	local zombieApi = GG.Zombies
	if not zombieApi or not zombieApi.GetRandomResurrectableWreck then
		return
	end
	return zombieApi.GetRandomResurrectableWreck(unitX, unitZ, CONSTRUCTOR_SEARCH_DISTANCE)
end

local function issueResurrectOrder(unitID, zombieData, currentCommand, unitX, unitZ)
	local previousTargetID = zombieData.resurrectTargetID
	local targetID = previousTargetID
	if spGetUnitWorkerTask(unitID) ~= CMD_RESURRECT then
		targetID = getRandomResurrectableWreck(unitID, unitX, unitZ)
	end
	zombieData.resurrectTargetID = targetID
	if not targetID then
		return false
	end
	if currentCommand ~= CMD_RESURRECT or previousTargetID ~= targetID then
		spGiveOrderToUnit(unitID, CMD_RESURRECT, { targetID + FEATURE_ID_OFFSET }, 0)
	end
	return true
end

local function updateOrders(unitID, unitDefID)
	local zombieData = zombieWatch[unitID]
	if mobileUnitDefs[unitDefID] then
		local previousCombatTargetID = zombieData.combatTargetID
		local currentCommand = spGetUnitCurrentCommand(unitID)
		local movementCommand = getMovementCommand(unitDefID)
		if
			(currentCommand == CMD_CAPTURE or currentCommand == CMD_RECLAIM) -- capture and reclaim need LOS, so drop the order if Gaia loses sight
			and previousCombatTargetID
			and not isUnitInGaiaLos(previousCombatTargetID)
		then
			zombieData.combatTargetID = nil
			clearUnitOrders(unitID)
		end
		local unitX
		local unitZ
		local targetX, targetZ, shouldCapture, weaponRange, shouldReclaim =
			getCombatTargetData(unitDefID, zombieData.combatTargetID)
		if targetX and shouldCapture then -- a zombie endlessly chasing a distant thing isn't a big deal. It'll shoot everything along the way. Capture though? Bad. It'll just run around never capturing anything because its target is forever unreachable.
			unitX, unitZ = knownUnitXZ(unitID, unitX, unitZ)
			if not unitX or distance2dSquared(unitX, unitZ, targetX, targetZ) > CONSTRUCTOR_SEARCH_DISTANCE_SQUARED then
				zombieData.combatTargetID = nil
				targetX = nil
			end
		end
		if not targetX then
			zombieData.combatTargetID = nil
		end
		local retargetsEveryTick = capturingUnits[unitDefID] and not unitDefWeaponRanges[unitDefID]
		if
			retargetsEveryTick
			or (not zombieData.combatTargetID and (capturingUnits[unitDefID] or unitDefWeaponRanges[unitDefID]))
		then
			unitX, unitZ = knownUnitXZ(unitID, unitX, unitZ)
			local closestKnownEnemy, nearestX, nearestZ, nearestShouldCapture, nearestWeaponRange, nearestShouldReclaim =
				getNearestCombatTarget(unitID, unitDefID, unitX, unitZ)
			if nearestX then
				zombieData.combatTargetID = closestKnownEnemy
				targetX, targetZ, shouldCapture, weaponRange, shouldReclaim =
					nearestX, nearestZ, nearestShouldCapture, nearestWeaponRange, nearestShouldReclaim
				setEnemyDirectionObjective(unitID, zombieData, targetX, targetZ, ENEMY_DIRECTION_TOWARD, unitX, unitZ)
			end
		end

		if zombieData.combatTargetID then
			if shouldReclaim then
				if currentCommand ~= CMD_RECLAIM or previousCombatTargetID ~= zombieData.combatTargetID then
					clearLastCombatTarget(zombieData)
					spGiveOrderToUnit(unitID, CMD_RECLAIM, { zombieData.combatTargetID }, 0)
				end
			elseif shouldCapture then
				if currentCommand ~= CMD_CAPTURE or previousCombatTargetID ~= zombieData.combatTargetID then
					clearLastCombatTarget(zombieData)
					spGiveOrderToUnit(unitID, CMD_CAPTURE, { zombieData.combatTargetID }, 0)
				end
			else
				local COMBAT_ORDER_REFRESH_CHANCE = 0.0005
				local commandNeedsMove = currentCommand ~= movementCommand
				local targetChanged = previousCombatTargetID ~= zombieData.combatTargetID
				local combatTargetMoved = not zombieData.lastCombatTargetX
					or distance2dSquared(
							targetX,
							targetZ,
							zombieData.lastCombatTargetX,
							zombieData.lastCombatTargetZ
						)
						>= COMBAT_TARGET_MOVE_REFRESH_DISTANCE_SQUARED
				if random() < COMBAT_ORDER_REFRESH_CHANCE or commandNeedsMove or targetChanged then
					issueCombatMove(unitID, unitDefID, weaponRange, targetX, targetZ, zombieData, unitX, unitZ)
				elseif combatTargetMoved then
					local positionX, positionY, positionZ = spGetUnitPosition(unitID)
					local engageRange = weaponRange and weaponRange * COMBAT_ENGAGE_RANGE_RATIO
					local enemyWithinEngageRange = positionX ~= nil
						and engageRange
						and engageRange > 0
						and spGetClosestEnemyUnit(
								positionX,
								positionY,
								positionZ,
								engageRange,
								gaiaAllyTeamID,
								true
							)
							~= nil
					if not enemyWithinEngageRange then
						issueCombatMove(unitID, unitDefID, weaponRange, targetX, targetZ, zombieData, unitX, unitZ)
					end
				end
			end
		else
			clearLastCombatTarget(zombieData)
			if
				resurrectingUnits[unitDefID] and issueResurrectOrder(unitID, zombieData, currentCommand, unitX, unitZ)
			then
				return
			end
			local objective, objectiveChanged =
				ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID), unitX, unitZ)
			if previousCombatTargetID or objectiveChanged or currentCommand ~= movementCommand then
				issueObjectiveMove(unitID, unitDefID, zombieData, objective, unitX, unitZ)
			end
		end
	end

	if factoriesWithWantedOptions[unitDefID] then
		local factoryCommandCount = spGetFactoryCommandCount(unitID) or 0
		if factoryCommandCount < ZOMBIE_FACTORY_BUILD_COUNT then
			issueRandomFactoryBuildOrders(unitID, unitDefID, ZOMBIE_FACTORY_BUILD_COUNT - factoryCommandCount)
		end
	end
end

local function setZombieStates(unitID, unitDefID)
	spGiveOrderToUnit(unitID, CMD_REPEAT, ENABLE_REPEAT, 0)
	spGiveOrderToUnit(unitID, CMD_MOVE_STATE, MOVE_STATE_ROAM, 0)
	if aircraftUnitDefs[unitDefID] then
		spGiveOrderToUnit(unitID, CMD_IDLEMODE, IDLEMODE_FLY, 0)
	end
	if not isPacified then
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, FIRE_STATE_FIRE_AT_ALL, 0)
	else
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, FIRE_STATE_RETURN_FIRE, 0)
	end
	spring.SetUnitRulesParam(unitID, "resurrected", 0, { inlos = true })
end

local function addZombieToBucket(buckets, interval, unitID, zombieData, indexField)
	local bucket = buckets[unitID % interval + 1]
	local unitIndex = #bucket + 1
	zombieData[indexField] = unitIndex
	bucket[unitIndex] = unitID
end

local function initializeZombie(unitID, unitDefID)
	if zombieWatch[unitID] or (scavTeamID and spring.GetUnitTeam(unitID) == scavTeamID) then
		return
	end
	local unitX, _, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end
	local unitPower = UnitDefs[unitDefID].power or 0
	zombieWatch[unitID] = {
		unitDefID = unitDefID,
		lastX = unitX,
		lastZ = unitZ,
		noGoZones = {},
		power = unitPower,
	}
	local zombieData = zombieWatch[unitID]
	addZombieToBucket(zombieOrderBuckets, ZOMBIE_ORDER_CHECK_INTERVAL, unitID, zombieData, "orderBucketIndex")
	addZombieToBucket(zombieStuckBuckets, STUCK_CHECK_INTERVAL, unitID, zombieData, "stuckBucketIndex")
	if mobileUnitDefs[unitDefID] then
		zombieData.selfDestructTimestamp = gameFrame
		zombieData.selfDestructX = unitX
		zombieData.selfDestructZ = unitZ
		setRandomEdgeObjective(zombieData)
		totalMobileZombiePower = totalMobileZombiePower + unitPower
	end
	setZombieStates(unitID, unitDefID)
	if ordersEnabled then
		updateOrders(unitID, unitDefID)
	end
end

local function clearAllOrders()
	for zombieID in pairs(zombieWatch) do
		clearUnitOrders(zombieID)
	end
end

local function pacifyZombies(enabled)
	isPacified = enabled
	ordersEnabled = not isPacified and not autoOrdersSuspended
	if isPacified then
		clearAllOrders()
	end
	local fireState = isPacified and FIRE_STATE_RETURN_FIRE or FIRE_STATE_FIRE_AT_ALL
	for zombieID in pairs(zombieWatch) do
		if spValidUnitID(zombieID) then
			spGiveOrderToUnit(zombieID, CMD_FIRE_STATE, fireState)
		end
	end
end

local function hasGameEndExplosionStarted() -- last living ally means the end-game explosion; stop attack orders
	if not GG.maxDeathFrame then
		return false
	end
	local livingAllyTeams = 0
	local allyTeamList = spring.GetAllyTeamList()
	for allyIndex = 1, #allyTeamList do
		local teamList = spring.GetTeamList(allyTeamList[allyIndex])
		local allyTeamIsAlive = false
		for teamIndex = 1, #teamList do
			local teamID = teamList[teamIndex]
			if teamID ~= gaiaTeamID then
				local teamLuaAI = spring.GetTeamLuaAI(teamID)
				if
					not (
						teamLuaAI
						and (
							string.find(teamLuaAI, "Scavengers", 1, true) or string.find(teamLuaAI, "Raptors", 1, true)
						)
					)
				then
					local _, _, isDead = spring.GetTeamInfo(teamID, false)
					if not isDead then
						allyTeamIsAlive = true
						break
					end
				end
			end
		end
		if allyTeamIsAlive then
			livingAllyTeams = livingAllyTeams + 1
			if livingAllyTeams > 1 then
				return false
			end
		end
	end
	return true
end

local function suspendAutoOrders(enabled)
	autoOrdersSuspended = enabled
	ordersEnabled = not isPacified and not autoOrdersSuspended
	if autoOrdersSuspended then
		clearAllOrders()
	end
end

local function aggroAllZombiesToAllyTeam(allyTeamID)
	local markedAny = false
	for zombieID in pairs(zombieWatch) do
		local zombieData = zombieWatch[zombieID]
		if spValidUnitID(zombieID) and mobileUnitDefs[zombieData.unitDefID] then
			clearUnitOrders(zombieID)
			zombieAggros[zombieID] = allyTeamID
			markedAny = true
		else
			zombieAggros[zombieID] = nil
			if zombieData.objective and zombieData.objective.type == OBJECTIVE_TYPE_AGGRO then
				zombieData.objective = nil
			end
		end
	end

	if markedAny then
		setAggroExpiration()
	end
	return markedAny
end

local function aggroTeamID(teamID)
	local _, _, isDead, _, _, allyTeamID = spring.GetTeamInfo(teamID)
	if isDead ~= false or not allyTeamID then
		return false
	end
	return aggroAllZombiesToAllyTeam(allyTeamID)
end

local function aggroAllyID(allyTeamID)
	local allyTeams = spring.GetTeamList(allyTeamID)
	if not allyTeams or #allyTeams == 0 then
		return false
	end
	return aggroAllZombiesToAllyTeam(allyTeamID)
end

local function killAllZombies()
	for zombieID in pairs(zombieWatch) do
		if spValidUnitID(zombieID) and not spGetUnitIsDead(zombieID) then
			local currentHealth = spGetUnitHealth(zombieID)
			if currentHealth and currentHealth > 0 then
				spring.AddUnitDamage(zombieID, currentHealth, 0, NULL_ATTACKER, ENVIRONMENTAL_DAMAGE_ID)
			end
		end
	end
end

local function enablePermanentAggro()
	permanentlyAggro = true
	assignZombieAggroEvenly()
end

local function updateAggro()
	if gameFrame % AGGRO_CHECK_INTERVAL ~= 1 then
		return
	end
	if permanentlyAggro then
		assignZombieAggroEvenly()
		return
	end
	if gameFrame < AGGRO_MIN_START_FRAME then
		return
	end
	local totalPlayerPower = GG.PowerLib.TotalPlayerTeamsPower()
	local powerCheckSucceeded = totalMobileZombiePower > totalPlayerPower * AGGRO_ZOMBIE_TO_PLAYER_POWER_RATIO
	if powerCheckSucceeded then
		assignZombieAggroEvenly()
		setAggroExpiration()
	else
		zombieAggros = {}
		aggroExpirationTimestamp = 0
	end
end

local function forEachLiveZombieInBucket(buckets, interval, visitZombie)
	local bucket = buckets[gameFrame % interval + 1]
	local bucketIndex = 1
	while bucketIndex <= #bucket do
		local unitID = bucket[bucketIndex]
		if spGetUnitIsDead(unitID) ~= false then
			unwatchZombie(unitID)
		else
			visitZombie(unitID, zombieWatch[unitID])
			bucketIndex = bucketIndex + 1
		end
	end
end

local function visitZombieOrders(unitID, zombieData)
	updateOrders(unitID, zombieData.unitDefID)
end

local function visitStuckZombie(unitID, zombieData)
	local unitX, _, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end
	local unitDefID = zombieData.unitDefID
	local isMobileUnit = mobileUnitDefs[unitDefID] ---@as true?
	local arrivedAtMoveOrder = isMobileUnit
		and zombieData.moveOrderX
		and not zombieData.combatTargetID
		and distance2dSquared(unitX, unitZ, zombieData.moveOrderX, zombieData.moveOrderZ) <= 400 * 400
	if arrivedAtMoveOrder then
		local arrivalObjective = ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID), unitX, unitZ)
		issueObjectiveMove(unitID, unitDefID, zombieData, arrivalObjective, unitX, unitZ)
	else
		local objective = zombieData.objective
		local movedDistanceSquared = distance2dSquared(unitX, unitZ, zombieData.lastX, zombieData.lastZ)
		local isAtRememberedObjective = objectiveIsRememberedEdge(zombieData, objective)
			and isObjectiveReached(unitID, objective, unitX, unitZ)
		local isStationary = isMobileUnit
			and not isAtRememberedObjective
			and movedDistanceSquared < STUCK_DISTANCE_SQUARED
		local workerTask
		if isStationary then
			workerTask = spGetUnitWorkerTask(unitID)
		end
		if isStationary and workerTask ~= CMD_RESURRECT and workerTask ~= CMD_RECLAIM then -- if they haven't moved, blacklist this spot and reroute; keep a remembered-enemy goal
			clearUnitOrders(unitID)
			clearCombatTracking(zombieData)
			zombieData.resurrectTargetID = nil
			if objective and (objective.type == OBJECTIVE_TYPE_AGGRO or not zombieData.rememberedObjectiveX) then
				zombieData.objective = nil
			end
			if not isInNoGoZone(zombieData, unitX, unitZ) then
				if #zombieData.noGoZones >= MAX_NOGO_ZONES then
					table.remove(zombieData.noGoZones, 1)
				end
				table.insert(zombieData.noGoZones, { x = unitX, z = unitZ })
			end
			local recoveryObjective =
				ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID), unitX, unitZ)
			issueObjectiveMove(
				unitID,
				unitDefID,
				zombieData,
				recoveryObjective,
				unitX,
				unitZ,
				ZOMBIE_MAX_ORDER_ATTEMPTS
			)
		end
	end
	if mobileUnitDefs[unitDefID] and gameFrame - zombieData.selfDestructTimestamp >= STUCK_SELF_DESTRUCT_INTERVAL then
		if
			distance2dSquared(unitX, unitZ, zombieData.selfDestructX, zombieData.selfDestructZ)
			<= STUCK_SELF_DESTRUCT_DISTANCE_SQUARED
		then
			spGiveOrderToUnit(unitID, CMD_SELF_DESTRUCT, {}, 0)
		end
		zombieData.selfDestructTimestamp = gameFrame
		zombieData.selfDestructX = unitX
		zombieData.selfDestructZ = unitZ
	end
	zombieData.lastX = unitX
	zombieData.lastZ = unitZ
end

local function updateZombieOrders()
	forEachLiveZombieInBucket(zombieOrderBuckets, ZOMBIE_ORDER_CHECK_INTERVAL, visitZombieOrders)
end

local function updateStuckZombies()
	forEachLiveZombieInBucket(zombieStuckBuckets, STUCK_CHECK_INTERVAL, visitStuckZombie)
end

local function getWraithData(unitID, unitDefID)
	local wraithData = wraithWatch[unitID]
	if not wraithData then
		wraithData = {
			unitDefID = unitDefID,
			noGoZones = {},
			nextOrderFrame = 0,
		}
		setRandomEdgeObjective(wraithData)
		wraithWatch[unitID] = wraithData
	end
	return wraithData
end

local function issueDirectObjectiveMove(unitID, unitDefID, objective)
	local targetY = spGetGroundHeight(objective.x, objective.z)
	spGiveOrderToUnit(unitID, getMovementCommand(unitDefID), { objective.x, targetY, objective.z }, 0)
end

local function commandWraith(unitID, unitDefID, wraithX, wraithY, wraithZ, attackerX, attackerZ)
	local wraithData = getWraithData(unitID, unitDefID)
	local nearestEnemyID =
		spGetClosestEnemyUnit(wraithX, wraithY, wraithZ, ENEMY_ATTACK_DISTANCE, gaiaAllyTeamID, false)
	local enemyX, enemyZ
	local enemyWithinRadius = false
	if nearestEnemyID then
		enemyX, _, enemyZ = spGetUnitPosition(nearestEnemyID)
		if enemyX then
			enemyWithinRadius = distance2dSquared(wraithX, wraithZ, enemyX, enemyZ) <= WRAITH_ENEMY_RADIUS_SQUARED
		end
	end
	if attackerX and attackerZ then
		setEnemyDirectionObjective(unitID, wraithData, attackerX, attackerZ, ENEMY_DIRECTION_AWAY, wraithX, wraithZ)
		local objective = wraithData.objective
		if objective then
			issueDirectObjectiveMove(unitID, unitDefID, objective)
			wraithData.nextOrderFrame = gameFrame + WRAITH_ORDER_COOLDOWN
		end
		return enemyWithinRadius
	end
	if gameFrame < wraithData.nextOrderFrame then -- delay issuing new orders so it has a chance to escape from the midst of the enemy
		return enemyWithinRadius
	end
	local objectiveRegenerated = enemyX
		and nearestEnemyID ~= wraithData.threatTargetID
		and setEnemyDirectionObjective(unitID, wraithData, enemyX, enemyZ, ENEMY_DIRECTION_AWAY, wraithX, wraithZ)
	wraithData.threatTargetID = nearestEnemyID
	local objective, objectiveChanged = ensureMovementObjective(unitID, wraithData, nil, wraithX, wraithZ)
	if objectiveRegenerated or objectiveChanged or spGetUnitCurrentCommand(unitID) ~= getMovementCommand(unitDefID) then
		issueObjectiveMove(unitID, unitDefID, wraithData, objective, wraithX, wraithZ)
		wraithData.nextOrderFrame = gameFrame + WRAITH_ORDER_COOLDOWN
	end
	return enemyWithinRadius
end

function gadget:GameFrame(frame)
	gameFrame = frame
	if not isPacified and not IS_PVE_GAME and frame % Game.gameSpeed == 0 and hasGameEndExplosionStarted() then
		pacifyZombies(true)
	end
	updateAggro()
	if ordersEnabled then
		updateZombieOrders()
		updateStuckZombies()
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	rememberUnitIdentity(unitID, unitDefID, unitTeam)
	local allyTeamID = getTeamAllyTeamID(unitTeam)
	addAllyTeamUnit(unitID, allyTeamID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == gaiaTeamID and isZombie(unitID) then
		initializeZombie(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID)
	flyingUnits[unitID] = nil
	wraithWatch[unitID] = nil
	forgetUnitIdentity(unitID)
	unwatchZombie(unitID)
	removeAllyTeamUnit(unitID)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam)
	removeAllyTeamUnit(unitID)
	if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
		forgetUnitIdentity(unitID)
		return
	end
	rememberUnitIdentity(unitID, unitDefID, newTeam)
	local newAllyTeamID = getTeamAllyTeamID(newTeam)
	addAllyTeamUnit(unitID, newAllyTeamID)
	if newTeam == gaiaTeamID and isZombie(unitID) then
		initializeZombie(unitID, unitDefID)
	else
		unwatchZombie(unitID)
	end
end

function gadget:UnitEnteredAir(unitID)
	flyingUnits[unitID] = true
end

function gadget:UnitLeftAir(unitID)
	flyingUnits[unitID] = nil
end

local RELOAD_STATE_RULES_PARAM = "zombie_ai_reload_state"

local function saveReloadState()
	local serpent = require("common/luaUtilities/serpent")
	spring.SetGameRulesParam(
		RELOAD_STATE_RULES_PARAM,
		serpent.dump({
			gameFrame = gameFrame,
			ordersEnabled = ordersEnabled,
			isPacified = isPacified,
			autoOrdersSuspended = autoOrdersSuspended,
			totalMobileZombiePower = totalMobileZombiePower,
			aggroExpirationTimestamp = aggroExpirationTimestamp,
			permanentlyAggro = permanentlyAggro,
			zombieAggros = zombieAggros,
			allyTeamUnits = allyTeamUnits,
			unitAllyTeamIDs = unitAllyTeamIDs,
			unitAllyTeamIndices = unitAllyTeamIndices,
			zombieWatch = zombieWatch,
			wraithWatch = wraithWatch,
			flyingUnits = flyingUnits,
			zombieOrderBuckets = zombieOrderBuckets,
			zombieStuckBuckets = zombieStuckBuckets,
		})
	)
end

local function restoreReloadState()
	local savedState = spring.GetGameRulesParam(RELOAD_STATE_RULES_PARAM)
	if not savedState then
		return false
	end
	local serpent = require("common/luaUtilities/serpent")
	local loaded, reloadState = serpent.load(savedState)
	if not loaded or type(reloadState) ~= "table" or reloadState.gameFrame ~= gameFrame then
		return false
	end

	ordersEnabled = reloadState.ordersEnabled
	isPacified = reloadState.isPacified
	autoOrdersSuspended = reloadState.autoOrdersSuspended
	totalMobileZombiePower = reloadState.totalMobileZombiePower
	aggroExpirationTimestamp = reloadState.aggroExpirationTimestamp
	permanentlyAggro = reloadState.permanentlyAggro
	zombieAggros = reloadState.zombieAggros
	allyTeamUnits = reloadState.allyTeamUnits
	unitAllyTeamIDs = reloadState.unitAllyTeamIDs
	unitAllyTeamIndices = reloadState.unitAllyTeamIndices
	zombieWatch = reloadState.zombieWatch
	wraithWatch = reloadState.wraithWatch
	flyingUnits = reloadState.flyingUnits
	zombieOrderBuckets = reloadState.zombieOrderBuckets
	zombieStuckBuckets = reloadState.zombieStuckBuckets

	spring.SetGameRulesParam(RELOAD_STATE_RULES_PARAM, nil)
	return true
end

function gadget:Initialize()
	gameFrame = spring.GetGameFrame()

	if not restoreReloadState() then
		for _, unitID in ipairs(spring.GetAllUnits()) do
			local unitTeam = spring.GetUnitTeam(unitID)
			local unitDefID = spGetUnitDefID(unitID)
			rememberUnitIdentity(unitID, unitDefID, unitTeam)
			local allyTeamID = getTeamAllyTeamID(unitTeam)
			addAllyTeamUnit(unitID, allyTeamID)
			if unitTeam == gaiaTeamID and isZombie(unitID) then
				initializeZombie(unitID, unitDefID)
			end
		end

		if GG.Zombies and GG.Zombies.tooLong then
			enablePermanentAggro()
		end
	else
		for _, unitID in ipairs(spring.GetAllUnits()) do
			rememberUnitIdentity(unitID, spGetUnitDefID(unitID), spring.GetUnitTeam(unitID))
		end
	end

	GG.ZombieAI = {
		InitializeZombie = initializeZombie,
		PacifyZombies = pacifyZombies,
		SuspendAutoOrders = suspendAutoOrders,
		AggroTeamID = aggroTeamID,
		AggroAllyID = aggroAllyID,
		EnablePermanentAggro = enablePermanentAggro,
		KillAllZombies = killAllZombies,
		ClearAllOrders = clearAllOrders,
		CommandWraith = commandWraith,
	}
end

function gadget:Shutdown()
	GG.ZombieAI = nil
	saveReloadState()
end
