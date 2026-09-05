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
local AGGRO_CHECK_INTERVAL = Game.gameSpeed * 30
local AGGRO_DURATION = Game.gameSpeed * 60
local AGGRO_MIN_START_FRAME = Game.gameSpeed * 60 * 15

local STUCK_DISTANCE = 50
local STUCK_DISTANCE_SQUARED = STUCK_DISTANCE ^ 2
local NOGO_ZONE_RADIUS = 600
local NOGO_ZONE_RADIUS_SQUARED = NOGO_ZONE_RADIUS ^ 2
local ENEMY_ATTACK_DISTANCE = 1000
local ORDER_DISTANCE = 1600
local OBJECTIVE_REACHED_DISTANCE = 200
local OBJECTIVE_REACHED_DISTANCE_SQUARED = OBJECTIVE_REACHED_DISTANCE ^ 2
local COMBAT_TARGET_MOVE_REFRESH_DISTANCE = 100
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
local CMD_MOVE = CMD.MOVE
local CMD_CAPTURE = CMD.CAPTURE
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = { "shift" }

local FIRE_STATE_FIRE_AT_ALL = 3
local FIRE_STATE_RETURN_FIRE = 1
local MOVE_STATE_HOLD_POSITION = 0
local ENABLE_REPEAT = 1
local NULL_ATTACKER = -1
local ENVIRONMENTAL_DAMAGE_ID = Game.envDamageTypes.GroundCollision

local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ
local MAP_PERIMETER = 2 * (MAP_SIZE_X + MAP_SIZE_Z)
local OBJECTIVE_TYPE_NORMAL = 1
local OBJECTIVE_TYPE_AGGRO = 2

local spGetUnitNearestEnemy = spring.GetUnitNearestEnemy
local spValidUnitID = spring.ValidUnitID
local spGetGroundHeight = spring.GetGroundHeight
local spGetUnitPosition = spring.GetUnitPosition
local spGetUnitDefID = spring.GetUnitDefID
local spGiveOrderToUnit = spring.GiveOrderToUnit
local spGiveOrderArrayToUnit = spring.GiveOrderArrayToUnit
local spGetFactoryCommandCount = spring.GetFactoryCommandCount
local spGetUnitIsDead = spring.GetUnitIsDead
local spGetUnitHealth = spring.GetUnitHealth
local spGetUnitRulesParam = spring.GetUnitRulesParam
local spTestMoveOrder = spring.TestMoveOrder
local spGetUnitCurrentCommand = spring.GetUnitCurrentCommand
local spGetUnitHeight = spring.GetUnitHeight
local spGetUnitTeam = spring.GetUnitTeam
local spGetUnitLosState = spring.GetUnitLosState
local spGetUnitsInCylinder = spring.GetUnitsInCylinder
local spAreTeamsAllied = spring.AreTeamsAllied

local gaiaTeamID = spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, spring.GetTeamInfo(gaiaTeamID))
local readAsGaia = { ctrl = gaiaTeamID, read = gaiaTeamID, select = gaiaTeamID }
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

local mobileUnitDefs = {}
local factoriesWithCombatOptions = {}
local unitDefWeaponRanges = {}
local capturingUnits = {}
local zombieAggros = {}
local allyTeamUnits = {}
local unitAllyTeamIDs = {}
local unitAllyTeamIndices = {}
local zombieWatch = {}
local flyingUnits = {}
local zombieOrderBuckets = {}
local zombieStuckBuckets = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canCapture then
		capturingUnits[unitDefID] = true
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
					local isAAWeapon = weapon.onlyTargets
						and weapon.onlyTargets.vtol
						and not weapon.onlyTargets.ground
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
							maximumUnderwaterWeaponRange =
								math.max(maximumUnderwaterWeaponRange, weaponDef.range)
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
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.speed > 0 then
		mobileUnitDefs[unitDefID] = true
	elseif #unitDef.buildOptions > 0 then
		local combatOptions = {}
		for optionIndex = 1, #unitDef.buildOptions do
			local optionDefID = unitDef.buildOptions[optionIndex]
			if unitDefWeaponRanges[optionDefID] then
				combatOptions[#combatOptions + 1] = optionDefID
			end
		end
		if #combatOptions > 0 then
			factoriesWithCombatOptions[unitDefID] = combatOptions
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
	removeZombieFromBucket(unitID, zombieOrderBuckets[unitID % ZOMBIE_ORDER_CHECK_INTERVAL + 1], zombieData.orderBucketIndex, "orderBucketIndex")
	removeZombieFromBucket(unitID, zombieStuckBuckets[unitID % STUCK_CHECK_INTERVAL + 1], zombieData.stuckBucketIndex, "stuckBucketIndex")
	zombieWatch[unitID] = nil
	zombieAggros[unitID] = nil
end

local function setAggroExpiration()
	aggroExpirationTimestamp = gameFrame + AGGRO_DURATION
end

local function getActiveZombieAggro(unitID)
	if gameFrame >= aggroExpirationTimestamp then
		return nil
	end
	return zombieAggros[unitID]
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

local function isZombie(unitID)
	return spGetUnitRulesParam(unitID, "zombie") == 1
end

local function issueRandomFactoryBuildOrders(unitID, unitDefID, buildCount)
	local combatOptions = factoriesWithCombatOptions[unitDefID]
	local buildOrders = {}
	for buildIndex = 1, buildCount do
		buildOrders[#buildOrders + 1] = { -combatOptions[random(1, #combatOptions)], 0, 0 }
	end
	spGiveOrderArrayToUnit(unitID, buildOrders)
end

local function clearUnitOrders(unitID)
	if spValidUnitID(unitID) then
		spGiveOrderToUnit(unitID, CMD_STOP, {}, {})
	end
end

local function getWeaponRangeForTarget(attackerDefID, targetID, targetYPosition)
	local weaponRanges = unitDefWeaponRanges[attackerDefID]
	if not weaponRanges then
		return
	end
	local targetDef = UnitDefs[spGetUnitDefID(targetID)]
	local weaponRange
	if flyingUnits[targetID] or targetDef.canFly then
		weaponRange = weaponRanges.air
	elseif targetYPosition + (spGetUnitHeight(targetID) or 0) < 0 then
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

local function getCombatTargetData(unitDefID, targetID)
	if not targetID or not spValidUnitID(targetID) or spGetUnitIsDead(targetID) then
		return
	end
	local targetTeamID = spGetUnitTeam(targetID)
	if not targetTeamID or spAreTeamsAllied(gaiaTeamID, targetTeamID) then
		return
	end
	local targetX, targetY, targetZ = spGetUnitPosition(targetID)
	if not targetX then
		return
	end
	local targetDefID = spGetUnitDefID(targetID)
	local shouldCapture = capturingUnits[unitDefID]
		and UnitDefs[targetDefID].capturable ~= false
		and isUnitInGaiaLos(targetID)
	local weaponRange = getWeaponRangeForTarget(unitDefID, targetID, targetY)
	if shouldCapture or (weaponRange and weaponRange > 0) then
		return targetX, targetZ, shouldCapture, weaponRange
	end
end

local function getNearestCombatTarget(unitID, unitDefID)
	local nearestEnemyID = spGetUnitNearestEnemy(unitID, ENEMY_ATTACK_DISTANCE, true)
	local targetX, targetZ, shouldCapture, weaponRange = getCombatTargetData(unitDefID, nearestEnemyID)
	if targetX then
		return nearestEnemyID, targetX, targetZ, shouldCapture, weaponRange
	end

	local unitX, _, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end
	local enemyUnits = CallAsTeam(readAsGaia, spGetUnitsInCylinder, unitX, unitZ, ENEMY_ATTACK_DISTANCE, spring.ENEMY_UNITS) -- nearest-enemy API can return an unshootable unit, so fall back to a cylinder scan
	local bestTargetID
	local bestTargetX
	local bestTargetZ
	local bestShouldCapture
	local bestWeaponRange
	local bestDistanceSquared
	for enemyIndex = 1, #enemyUnits do
		local enemyID = enemyUnits[enemyIndex]
		targetX, targetZ, shouldCapture, weaponRange = getCombatTargetData(unitDefID, enemyID)
		if targetX then
			local targetDistanceSquared = distance2dSquared(unitX, unitZ, targetX, targetZ)
			if not bestDistanceSquared or targetDistanceSquared < bestDistanceSquared then
				bestTargetID = enemyID
				bestTargetX = targetX
				bestTargetZ = targetZ
				bestShouldCapture = shouldCapture
				bestWeaponRange = weaponRange
				bestDistanceSquared = targetDistanceSquared
			end
		end
	end
	return bestTargetID, bestTargetX, bestTargetZ, bestShouldCapture, bestWeaponRange
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
	objectiveX = math.max(POSITION_VARIANCE, math.min(MAP_SIZE_X - POSITION_VARIANCE, objectiveX))
	objectiveZ = math.max(POSITION_VARIANCE, math.min(MAP_SIZE_Z - POSITION_VARIANCE, objectiveZ))
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

local function isAggroObjectiveValid(unitID, objective, allyTeamID)
	if
		not objective
		or objective.type ~= OBJECTIVE_TYPE_AGGRO
		or not spValidUnitID(objective.targetUnitID)
		or spGetUnitIsDead(objective.targetUnitID)
		or unitAllyTeamIDs[objective.targetUnitID] ~= allyTeamID
	then
		return false
	end
	return not isObjectiveReached(unitID, objective)
end

local function assignZombieAggroEvenly()
	local playerTeams = GG.PowerLib.PlayerTeams
	local teamPowers = GG.PowerLib.TeamPowers
	local allyPowers = {}
	for teamID in pairs(playerTeams) do
		local allyTeamID = select(6, spring.GetTeamInfo(teamID))
		local teamPower = teamPowers[teamID] or 0
		allyPowers[allyTeamID] = (allyPowers[allyTeamID] or 0) + teamPower
	end

	local eligibleAllies = {}
	local eligibleAlliesByID = {}
	for allyTeamID, allyPower in pairs(allyPowers) do
		if allyPower > 0 and getRandomValidAllyTeamUnit(allyTeamID) then
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
			if allyData and isAggroObjectiveValid(unitID, zombieData.objective, allyTeamID) then
				allyData.assignedPower = allyData.assignedPower + zombieData.power
			else
				zombieAggros[unitID] = nil
				if zombieData.objective and zombieData.objective.type == OBJECTIVE_TYPE_AGGRO then
					zombieData.objective = nil
				end
				clearUnitOrders(unitID)
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

local function rememberEnemyDirection(unitID, zombieData, targetX, targetZ)
	local unitX, _, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end
	local deltaX = targetX - unitX
	local deltaZ = targetZ - unitZ
	if deltaX == 0 and deltaZ == 0 then
		return
	end
	local xScale = math.huge -- project the enemy bearing out to the map edge for later pursuit
	if deltaX > 0 then
		xScale = (MAP_SIZE_X - unitX) / deltaX
	elseif deltaX < 0 then
		xScale = -unitX / deltaX
	end
	local zScale = math.huge
	if deltaZ > 0 then
		zScale = (MAP_SIZE_Z - unitZ) / deltaZ
	elseif deltaZ < 0 then
		zScale = -unitZ / deltaZ
	end
	local boundaryScale = math.min(xScale, zScale)
	zombieData.rememberedObjectiveX = math.max(POSITION_VARIANCE, math.min(MAP_SIZE_X - POSITION_VARIANCE, unitX + deltaX * boundaryScale))
	zombieData.rememberedObjectiveZ = math.max(POSITION_VARIANCE, math.min(MAP_SIZE_Z - POSITION_VARIANCE, unitZ + deltaZ * boundaryScale))
end

local function ensureMovementObjective(unitID, zombieData, allyTeamID)
	local objective = zombieData.objective -- aggro target, else last-seen enemy edge, else a new map-edge wander
	if allyTeamID then
		if isAggroObjectiveValid(unitID, objective, allyTeamID) then
			return objective, false
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
		local isRememberedObjective =
			objective
			and objective.type == OBJECTIVE_TYPE_NORMAL
			and objective.x == zombieData.rememberedObjectiveX
			and objective.z == zombieData.rememberedObjectiveZ
		if isRememberedObjective and isObjectiveReached(unitID, objective) then
			zombieData.rememberedObjectiveX = nil
			zombieData.rememberedObjectiveZ = nil
			zombieData.objective = nil
			objective = nil
		elseif
			not objective
			or objective.type ~= OBJECTIVE_TYPE_NORMAL
			or objective.x ~= zombieData.rememberedObjectiveX
			or objective.z ~= zombieData.rememberedObjectiveZ
		then
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

	if not objective or objective.type ~= OBJECTIVE_TYPE_NORMAL or isObjectiveReached(unitID, objective) then
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

local function getObjectiveMoveTarget(unitDefID, zombieData, objective, originX, originZ)
	local deltaX = objective.x - originX
	local deltaZ = objective.z - originZ
	local objectiveDistance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
	local objectiveAngle = atan2(deltaZ, deltaX)
	local angleVariance = objective.type == OBJECTIVE_TYPE_AGGRO and AGGRO_OBJECTIVE_ANGLE_VARIANCE or NORMAL_OBJECTIVE_ANGLE_VARIANCE

	for attemptIndex = 1, ZOMBIE_MAX_ORDER_ATTEMPTS do
		local movementAngle
		local movementDistance = math.min(ORDER_DISTANCE, objectiveDistance)
		if attemptIndex == ZOMBIE_MAX_ORDER_ATTEMPTS then
			movementAngle = random() * TAU -- last try: ignore the objective and pick any passable heading
			movementDistance = ORDER_DISTANCE
		else
			movementAngle = objectiveAngle + (random() * 2 - 1) * angleVariance
		end
		local candidateTargetX = math.max(POSITION_VARIANCE, math.min(MAP_SIZE_X - POSITION_VARIANCE, originX + movementDistance * cos(movementAngle) + random(-POSITION_VARIANCE, POSITION_VARIANCE)))
		local candidateTargetZ = math.max(POSITION_VARIANCE, math.min(MAP_SIZE_Z - POSITION_VARIANCE, originZ + movementDistance * sin(movementAngle) + random(-POSITION_VARIANCE, POSITION_VARIANCE)))
		if not isInNoGoZone(zombieData, candidateTargetX, candidateTargetZ) then
			local candidateTargetY = spGetGroundHeight(candidateTargetX, candidateTargetZ)
			if spTestMoveOrder(unitDefID, candidateTargetX, candidateTargetY, candidateTargetZ) then
				return candidateTargetX, candidateTargetY, candidateTargetZ
			end
		end
	end
end

local function issueObjectiveMove(unitID, unitDefID, zombieData, objective)
	local unitX, _, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end
	if
		zombieData.rememberedObjectiveX
		and objective.type == OBJECTIVE_TYPE_NORMAL
		and objective.x == zombieData.rememberedObjectiveX
		and objective.z == zombieData.rememberedObjectiveZ
		and isObjectiveReached(unitID, objective, unitX, unitZ)
	then
		zombieData.rememberedObjectiveX = nil
		zombieData.rememberedObjectiveZ = nil
		zombieData.objective = nil
		setRandomEdgeObjective(zombieData)
		objective = zombieData.objective
	end

	local firstTargetX, firstTargetY, firstTargetZ =
		getObjectiveMoveTarget(unitDefID, zombieData, objective, unitX, unitZ)
	if firstTargetX then
		spGiveOrderToUnit(unitID, CMD_MOVE, { firstTargetX, firstTargetY, firstTargetZ }, 0)
		local secondTargetX, secondTargetY, secondTargetZ =
			getObjectiveMoveTarget(unitDefID, zombieData, objective, firstTargetX, firstTargetZ) -- pre-queue the next hop so they don't stall between order ticks
		if secondTargetX then
			spGiveOrderToUnit(
				unitID,
				CMD_MOVE,
				{ secondTargetX, secondTargetY, secondTargetZ },
				CMD_OPT_SHIFT
			)
		end
		return
	end

	clearUnitOrders(unitID)
	if objective.type == OBJECTIVE_TYPE_AGGRO or not zombieData.rememberedObjectiveX then
		zombieData.objective = nil
		ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID))
	end
end

local function issueCombatMove(unitID, unitDefID, weaponRange, targetX, targetZ, zombieData)
	local unitX, _, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		zombieData.lastCombatTargetX = nil
		zombieData.lastCombatTargetZ = nil
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
		zombieData.combatTargetID = nil
		zombieData.lastCombatTargetX = nil
		zombieData.lastCombatTargetZ = nil
		clearUnitOrders(unitID)
		local fallbackObjective = ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID))
		issueObjectiveMove(unitID, unitDefID, zombieData, fallbackObjective)
		return
	end
	local targetMoveY = spGetGroundHeight(targetMoveX, targetMoveZ)
	local isTargetMoveValid = spTestMoveOrder(unitDefID, targetMoveX, targetMoveY, targetMoveZ)
	if not isTargetMoveValid then
		zombieData.combatTargetID = nil
		zombieData.lastCombatTargetX = nil
		zombieData.lastCombatTargetZ = nil
		clearUnitOrders(unitID)
		local fallbackObjective = ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID))
		issueObjectiveMove(unitID, unitDefID, zombieData, fallbackObjective)
		return
	end
	spGiveOrderToUnit(unitID, CMD_MOVE, { targetMoveX, targetMoveY, targetMoveZ }, 0)
	local radialX = targetMoveX - targetX -- queue a 45° orbit around the target so they don't halt at engage range
	local radialZ = targetMoveZ - targetZ
	local rotationDirection = random() < 0.5 and -1 or 1
	local issuedSecondaryMove = false
	for attemptIndex = 1, 2 do
		local signedSin = COMBAT_SECONDARY_ANGLE_SIN * rotationDirection
		local secondaryTargetX =
			targetX + radialX * COMBAT_SECONDARY_ANGLE_COS - radialZ * signedSin
		local secondaryTargetZ =
			targetZ + radialX * signedSin + radialZ * COMBAT_SECONDARY_ANGLE_COS
		if
			secondaryTargetX >= 0
			and secondaryTargetX <= MAP_SIZE_X
			and secondaryTargetZ >= 0
			and secondaryTargetZ <= MAP_SIZE_Z
		then
			local secondaryTargetY = spGetGroundHeight(secondaryTargetX, secondaryTargetZ)
			if spTestMoveOrder(unitDefID, secondaryTargetX, secondaryTargetY, secondaryTargetZ) then
				spGiveOrderToUnit(
					unitID,
					CMD_MOVE,
					{ secondaryTargetX, secondaryTargetY, secondaryTargetZ },
					CMD_OPT_SHIFT
				)
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
		if spTestMoveOrder(unitDefID, secondaryTargetX, secondaryTargetY, secondaryTargetZ) then
			spGiveOrderToUnit(
				unitID,
				CMD_MOVE,
				{ secondaryTargetX, secondaryTargetY, secondaryTargetZ },
				CMD_OPT_SHIFT
			)
		end
	end
	zombieData.lastCombatTargetX = targetX
	zombieData.lastCombatTargetZ = targetZ
end

local function updateOrders(unitID, unitDefID)
	local zombieData = zombieWatch[unitID]
	if mobileUnitDefs[unitDefID] then
		local previousCombatTargetID = zombieData.combatTargetID
		local currentCommand = spGetUnitCurrentCommand(unitID)
		if
			currentCommand == CMD_CAPTURE -- capture needs LOS, so drop the order if Gaia loses sight
			and previousCombatTargetID
			and not isUnitInGaiaLos(previousCombatTargetID)
		then
			zombieData.combatTargetID = nil
			clearUnitOrders(unitID)
		end
		local targetX, targetZ, shouldCapture, weaponRange =
			getCombatTargetData(unitDefID, zombieData.combatTargetID)
		if not targetX then
			zombieData.combatTargetID = nil
		end
		if not zombieData.combatTargetID and (capturingUnits[unitDefID] or unitDefWeaponRanges[unitDefID]) then
			local closestKnownEnemy
			closestKnownEnemy, targetX, targetZ, shouldCapture, weaponRange =
				getNearestCombatTarget(unitID, unitDefID)
			if targetX then
				zombieData.combatTargetID = closestKnownEnemy
				rememberEnemyDirection(unitID, zombieData, targetX, targetZ)
			end
		end

		if zombieData.combatTargetID then
			if shouldCapture then
				if currentCommand ~= CMD_CAPTURE or previousCombatTargetID ~= zombieData.combatTargetID then
					zombieData.lastCombatTargetX = nil
					zombieData.lastCombatTargetZ = nil
					spGiveOrderToUnit(unitID, CMD_CAPTURE, { zombieData.combatTargetID }, 0)
				end
			else
				local combatTargetMoved = not zombieData.lastCombatTargetX
					or distance2dSquared(
							targetX,
							targetZ,
							zombieData.lastCombatTargetX,
							zombieData.lastCombatTargetZ
						)
						>= COMBAT_TARGET_MOVE_REFRESH_DISTANCE_SQUARED
				if
					currentCommand ~= CMD_MOVE
					or previousCombatTargetID ~= zombieData.combatTargetID
					or combatTargetMoved
				then
					issueCombatMove(unitID, unitDefID, weaponRange, targetX, targetZ, zombieData)
				end
			end
		else
			zombieData.lastCombatTargetX = nil
			zombieData.lastCombatTargetZ = nil
			local objective, objectiveChanged = ensureMovementObjective(
				unitID,
				zombieData,
				getActiveZombieAggro(unitID)
			)
			if
				previousCombatTargetID
				or objectiveChanged
				or currentCommand ~= CMD_MOVE
			then
				issueObjectiveMove(unitID, unitDefID, zombieData, objective)
			end
		end
	end

	if factoriesWithCombatOptions[unitDefID] then
		local factoryCommandCount = spGetFactoryCommandCount(unitID) or 0
		if factoryCommandCount < ZOMBIE_FACTORY_BUILD_COUNT then
			issueRandomFactoryBuildOrders(
				unitID,
				unitDefID,
				ZOMBIE_FACTORY_BUILD_COUNT - factoryCommandCount
			)
		end
	end
end

local function setZombieStates(unitID, unitDefID)
	if factoriesWithCombatOptions[unitDefID] then
		spGiveOrderToUnit(unitID, CMD_REPEAT, ENABLE_REPEAT, 0)
	end
	spGiveOrderToUnit(unitID, CMD_MOVE_STATE, MOVE_STATE_HOLD_POSITION, 0)
	if not isPacified then
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, FIRE_STATE_FIRE_AT_ALL, 0)
	else
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, FIRE_STATE_RETURN_FIRE, 0)
	end
	spring.SetUnitRulesParam(unitID, "resurrected", 0, { inlos = true })
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
	local orderBucket = zombieOrderBuckets[unitID % ZOMBIE_ORDER_CHECK_INTERVAL + 1]
	zombieData.orderBucketIndex = #orderBucket + 1
	orderBucket[zombieData.orderBucketIndex] = unitID
	local stuckBucket = zombieStuckBuckets[unitID % STUCK_CHECK_INTERVAL + 1]
	zombieData.stuckBucketIndex = #stuckBucket + 1
	stuckBucket[zombieData.stuckBucketIndex] = unitID
	if mobileUnitDefs[unitDefID] then
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
				if not (teamLuaAI and (string.find(teamLuaAI, "Scavengers", 1, true) or string.find(teamLuaAI, "Raptors", 1, true))) then
					local _, _, isDead = spring.GetTeamInfo(teamID)
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

local function updateAggro()
	if gameFrame % AGGRO_CHECK_INTERVAL ~= 1 or gameFrame < AGGRO_MIN_START_FRAME then
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

local function updateZombieOrders()
	local orderBucket = zombieOrderBuckets[gameFrame % ZOMBIE_ORDER_CHECK_INTERVAL + 1]
	local bucketIndex = 1
	while bucketIndex <= #orderBucket do
		local unitID = orderBucket[bucketIndex]
		local zombieData = zombieWatch[unitID]
		local unitDefID = zombieData.unitDefID
		if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
			unwatchZombie(unitID)
		else
			updateOrders(unitID, unitDefID)
			bucketIndex = bucketIndex + 1
		end
	end
end

local function updateStuckZombies()
	local stuckBucket = zombieStuckBuckets[gameFrame % STUCK_CHECK_INTERVAL + 1]
	local bucketIndex = 1
	while bucketIndex <= #stuckBucket do
		local unitID = stuckBucket[bucketIndex]
		local zombieData = zombieWatch[unitID]
		if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
			unwatchZombie(unitID)
		else
			local unitX, _, unitZ = spGetUnitPosition(unitID)
			if unitX then
				local unitDefID = zombieData.unitDefID
				local objective = zombieData.objective
				local movedDistanceSquared = distance2dSquared(unitX, unitZ, zombieData.lastX, zombieData.lastZ)
				local isAtRememberedObjective = zombieData.rememberedObjectiveX
					and objective
					and objective.type == OBJECTIVE_TYPE_NORMAL
					and objective.x == zombieData.rememberedObjectiveX
					and objective.z == zombieData.rememberedObjectiveZ
					and isObjectiveReached(unitID, objective, unitX, unitZ)
				if
					mobileUnitDefs[unitDefID] -- if they haven't moved, blacklist this spot and reroute; keep a remembered-enemy goal
					and not isAtRememberedObjective
					and movedDistanceSquared < STUCK_DISTANCE_SQUARED
				then
					clearUnitOrders(unitID)
					zombieData.combatTargetID = nil
					zombieData.lastCombatTargetX = nil
					zombieData.lastCombatTargetZ = nil
					if
						objective
						and (objective.type == OBJECTIVE_TYPE_AGGRO or not zombieData.rememberedObjectiveX)
					then
						zombieData.objective = nil
					end
					if not isInNoGoZone(zombieData, unitX, unitZ) then
						if #zombieData.noGoZones >= MAX_NOGO_ZONES then
							table.remove(zombieData.noGoZones, 1)
						end
						table.insert(zombieData.noGoZones, { x = unitX, z = unitZ })
					end
					local recoveryObjective = ensureMovementObjective(unitID, zombieData, getActiveZombieAggro(unitID))
					issueObjectiveMove(unitID, unitDefID, zombieData, recoveryObjective)
				end
				zombieData.lastX = unitX
				zombieData.lastZ = unitZ
			end
			bucketIndex = bucketIndex + 1
		end
	end
end

function gadget:Initialize()
	gameFrame = spring.GetGameFrame()
	for _, unitID in ipairs(spring.GetAllUnits()) do
		local unitTeam = spring.GetUnitTeam(unitID)
		local allyTeamID = select(6, spring.GetTeamInfo(unitTeam))
		addAllyTeamUnit(unitID, allyTeamID)
		if unitTeam == gaiaTeamID and isZombie(unitID) then
			initializeZombie(unitID, spGetUnitDefID(unitID))
		end
	end

	GG.ZombieAI = {
		InitializeZombie = initializeZombie,
		PacifyZombies = pacifyZombies,
		SuspendAutoOrders = suspendAutoOrders,
		AggroTeamID = aggroTeamID,
		AggroAllyID = aggroAllyID,
		KillAllZombies = killAllZombies,
		ClearAllOrders = clearAllOrders,
	}
end

function gadget:Shutdown()
	GG.ZombieAI = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame
	if not isPacified and hasGameEndExplosionStarted() then
		pacifyZombies(true)
	end
	updateAggro()
	if ordersEnabled then
		updateZombieOrders()
		updateStuckZombies()
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local allyTeamID = select(6, spring.GetTeamInfo(unitTeam))
	addAllyTeamUnit(unitID, allyTeamID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == gaiaTeamID and isZombie(unitID) then
		initializeZombie(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID)
	flyingUnits[unitID] = nil
	unwatchZombie(unitID)
	removeAllyTeamUnit(unitID)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam)
	removeAllyTeamUnit(unitID)
	if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
		return
	end
	local newAllyTeamID = select(6, spring.GetTeamInfo(newTeam))
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
