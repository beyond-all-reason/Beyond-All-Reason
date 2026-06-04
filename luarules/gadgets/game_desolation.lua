local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Desolation",
		desc = "Kills units when a allyteam is eliminated",
		author = "SethDGamre",
		date = "2026-05-21",
		layer = 0,
		enabled = true,
	}
end

--[[ TODO:
have slices of pies also have a chance to take something from the neighboring slice
]]

if not gadgetHandler:IsSyncedCode() then return false end

-- biases and chances

-- desolation power quota
-- Stop power-erasing units once remaining team power is at or below this fraction of pre-desolation power (0.2 = 20% floor).
local DESOLATION_QUOTA_RATIO = 0.2

-- erasure and hotspot selection
-- Hotspot turret picks: count of disadvantage rolls (take minimum index); higher = stronger bias toward high-power turrets in the power-sorted list.
local POWERFUL_TURRET_BIAS = 34
-- Erasure sort only: multiplies distance from hotspots for mobile units so they are treated as farther and erased earlier (4 = 4x effective distance).
local CAN_MOVE_PENALTY_MULTIPLIER = 4

-- unit fate after quota
-- Per surviving unit: chance to avoid default heap fate and roll corpse or gaia instead (1 = always redeemable).
local REDEEMABLE_CHANCE = 0.5
-- Of redeemable turrets only: chance to become gaia rather than a corpse (1 = all redeemable turrets go gaia).
local TURRET_GAIA_CHANCE = 0.75
-- Reserved; not referenced yet (intended heap damage fraction if wired in).
local TO_HEAP_DAMAGE_RATIO = 0.5

-- cascade and kill timing spread
-- Cascade timing curve sharpness for arc-dance and kill scheduling; higher = longer linger near start/end, steeper middle (3 = strong ease).
local EXPLOSION_CUBIC_EASE_BIAS = 3

-- arc dance pairing
-- Within each angular slice, sort order blend for arc partners: 0 = bearing only, 1 = distance from origin only, 0.3 = 70% angle / 30% radius.
local RADIAL_DANCE_PAIRING_BIAS = 0.3
-- Per unit after sorting: chance to pair with a random unit in the dance pool instead of the next unit in the slice chain (1 = fully random partners).
local DANCE_PAIRING_RANDOM_BIAS = 0.6

-- arc dance spawn
-- Each arc-dance tick: chance to target the allyteam origin instead of the paired unit (uses the same roll as SKIP_DANCE_CHANCE below).
local ARC_DANCE_ORIGIN_CHANCE = 0.03
-- When an origin arc is eligible, skip spawning if this roll threshold is met; must be below ARC_DANCE_ORIGIN_CHANCE or every origin attempt is skipped (0.8 > 0.03 skips all).
local SKIP_DANCE_CHANCE = 0.8

local SHOCKWAVE_DURATION = 45
local WAIT_DURATION = 30
local CASCADE_DURATION = 360
local MAX_POWER_KILL_FRAMES = 90
local MAX_RANDOM_KILL_FRAMES = 30
local TENEBRIUM_CORE_CEG = "tenebrium_implosion"
local EXPLOSION_SEQUENCE_END_OFFSET = SHOCKWAVE_DURATION + WAIT_DURATION + CASCADE_DURATION + MAX_POWER_KILL_FRAMES + MAX_RANDOM_KILL_FRAMES
local ARC_DANCE_SLICE_COUNT = 12
local ARC_DANCE_RESCHEDULE_MIN_FRAMES = 45
local ARC_DANCE_RESCHEDULE_MAX_FRAMES = 120
local ORIGIN_ARC_HEIGHT_ABOVE_GROUND = 20
local CMD_FIRE_STATE = CMD.FIRE_STATE
local FIRE_STATE_RETURN_FIRE = 1
local FIRE_STATE_FIRE_AT_WILL = 2
local TURRET_HOTSPOT_COUNT = 5
local DESOLATE_GAIA = 0
local DESOLATE_CORPSE = 1
local DESOLATE_HEAP = 2
local DESOLATE_ERASE = 3
local ARC_CEGS = {
	SMALL = "tenebrium_desolation_orange_arc_small",
	MEDIUM = "tenebrium_desolation_orange_arc_medium",
	LARGE = "tenebrium_desolation_orange_arc_large",
}

local spSpawnExplosion = Spring.SpawnExplosion
local spCreateFeature = Spring.CreateFeature
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spDestroyUnit = Spring.DestroyUnit
local spGetTeamUnits = Spring.GetTeamUnits
local spTransferUnit = Spring.TransferUnit
local spValidUnitID = Spring.ValidUnitID
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spSpawnCEG = Spring.SpawnCEG
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetAllUnits = Spring.GetAllUnits
local mathRandom = math.random
local mathMax = math.max
local mathMin = math.min
local mathFloor = math.floor
local mathSqrt = math.sqrt
local mathAtan2 = math.atan2
local mathPi = math.pi
local mathDistance2dSquared = math.distance2dSquared
local TWO_PI = mathPi * 2

local gaiaTeam = Spring.GetGaiaTeamID()

local defData = {}
local commanderDefs = {}
local actionFrames = {}
local cegActionFrames = {}
local arcDanceFrames = {}
local unitPairs = {}
local unitAllyTeams = {}
local allyTeamOrigins = {}
local desolatedTeams = {}
local distanceSqCache = {}
local fireStateLockEndFrame = 0

--populate def types
local function isTurretDef(unitDef)
	if unitDef.canMove then
		return false
	end
	if not unitDef.weapons or #unitDef.weapons == 0 then
		return false
	end
	if unitDef.buildOptions and #unitDef.buildOptions > 0 then
		return false
	end
	return true
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	local data = {}
	
	data.power = unitDef.power

	local corpseDefName = unitDef.corpse
	if FeatureDefNames[corpseDefName] then
		local corpseDefID = FeatureDefNames[corpseDefName].id
		data.heap = FeatureDefs[corpseDefID].deathFeatureID
	end

	local deathExplosionName = unitDef.deathExplosion
	local explosionDefID = WeaponDefNames[deathExplosionName].id
	data.explosionDefID = explosionDefID

	if isTurretDef(unitDef) then
		data.isTurret = true
	end
	if unitDef.customParams and unitDef.customParams.iscommander then
		data.isCommander = true
	end
	if unitDef.canMove then
		data.canMove = true
	end
	defData[unitDefID] = data
end

local function suspendViolence(suspended)
	local fireState = suspended and FIRE_STATE_RETURN_FIRE or FIRE_STATE_FIRE_AT_WILL
	for _, unitID in ipairs(spGetAllUnits()) do
		if spValidUnitID(unitID) then
			spGiveOrderToUnit(unitID, CMD_FIRE_STATE, fireState, 0)
		end
	end
	if suspended then
		fireStateLockEndFrame = mathMax(fireStateLockEndFrame, Spring.GetGameFrame() + EXPLOSION_SEQUENCE_END_OFFSET)
	else
		fireStateLockEndFrame = 0
	end
end

local function chooseFate(unitID)
	local fate = DESOLATE_HEAP

	if mathRandom() <= REDEEMABLE_CHANCE then
		if defData[spGetUnitDefID(unitID)].isTurret then
			if mathRandom() <= TURRET_GAIA_CHANCE then
				fate = DESOLATE_GAIA
			else
				fate = DESOLATE_CORPSE
			end
		else
			fate = DESOLATE_CORPSE
		end
	end
	return fate
end

local function desolateUnit(unitID, fate)
	if not spValidUnitID(unitID) then
		return
	end

	if fate == DESOLATE_GAIA then
		spTransferUnit(unitID, gaiaTeam, false)
		return
	end

	local unitDefID = spGetUnitDefID(unitID)
	local data = defData[unitDefID]
	local x, y, z = spGetUnitPosition(unitID)

	if fate == DESOLATE_CORPSE then
		spDestroyUnit(unitID, false, false, -1)
		return
	end	
	
	if fate == DESOLATE_HEAP or fate == DESOLATE_ERASE then
		spDestroyUnit(unitID, false, true, -1)
		spSpawnExplosion(x, y, z, 0, 0, 0, {weaponDef = data.explosionDefID, owner = unitID})
	end
	if fate == DESOLATE_HEAP then
		spCreateFeature(data.heap, x, y, z)
	end
end

local function dndStyleDisadvantageBias(rangeCount, degree)
	local selection
	for rollIndex = 1, degree do
		local randomWholeNumber = mathRandom(1, rangeCount)
		if not selection or randomWholeNumber < selection then
			selection = randomWholeNumber
		end
	end
	return selection
end

local function inCubic(t)
	return t ^ EXPLOSION_CUBIC_EASE_BIAS
end

local function outCubic(t)
	return 1 - (1 - t) ^ EXPLOSION_CUBIC_EASE_BIAS
end

local function getKillVarianceFrames(frameOffset, unitPower, minPower, maxPower)
	local randomFrames = 0
	local powerVarianceMax = 0
	if MAX_POWER_KILL_FRAMES > 0 then
		if maxPower <= minPower then
			powerVarianceMax = MAX_POWER_KILL_FRAMES
		else
			local powerT = (unitPower - minPower) / (maxPower - minPower)
			powerVarianceMax = mathFloor(powerT * MAX_POWER_KILL_FRAMES + 0.5)
		end
	end
	if powerVarianceMax > 0 then
		randomFrames = randomFrames + mathRandom(0, powerVarianceMax)
	end
	if MAX_RANDOM_KILL_FRAMES > 0 then
		randomFrames = randomFrames + mathRandom(0, MAX_RANDOM_KILL_FRAMES)
	end
	if randomFrames <= 0 then
		return frameOffset
	end
	return mathMax(0, frameOffset + randomFrames)
end

local function removeEntrySwap(tableToMutate, removeIndex)
	local lastIndex = #tableToMutate
	tableToMutate[removeIndex] = tableToMutate[lastIndex]
	tableToMutate[lastIndex] = nil
end

local function getArcCegName(distance)
	
	if distance <= 50 then
		return nil
	end
	if distance <= 200 then
		return ARC_CEGS.SMALL
	end
	if distance <= 500 then
		return ARC_CEGS.MEDIUM
	end
	if distance <= 1000 then
		return ARC_CEGS.LARGE
	end
	return nil
end

local function getRadialDancePairingSortKey(unitID, originX, originZ, maxDistanceSq)
	local unitX, _, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return math.huge
	end
	local angle = mathAtan2(unitX - originX, unitZ - originZ) % TWO_PI
	local distanceSq = distanceSqCache[unitID] or mathDistance2dSquared(unitX, unitZ, originX, originZ)
	local angleSort = angle / TWO_PI
	local radialSort = maxDistanceSq > 0 and (distanceSq / maxDistanceSq) or 0
	return (1 - RADIAL_DANCE_PAIRING_BIAS) * angleSort + RADIAL_DANCE_PAIRING_BIAS * radialSort
end

local function pickRandomDancePartner(sourceUnitID, candidateUnitIDs)
	local candidateCount = #candidateUnitIDs
	if candidateCount < 2 then
		return nil
	end
	local partnerUnitID = candidateUnitIDs[mathRandom(1, candidateCount)]
	while partnerUnitID == sourceUnitID do
		partnerUnitID = candidateUnitIDs[mathRandom(1, candidateCount)]
	end
	return partnerUnitID
end

local function pickDancePartner(sourceUnitID, structuredPartnerUnitID, candidateUnitIDs)
	if DANCE_PAIRING_RANDOM_BIAS <= 0 or mathRandom() >= DANCE_PAIRING_RANDOM_BIAS then
		return structuredPartnerUnitID
	end
	return pickRandomDancePartner(sourceUnitID, candidateUnitIDs) or structuredPartnerUnitID
end

local function removeUnitPair(unitID)
	unitPairs[unitID] = nil
	unitAllyTeams[unitID] = nil
end

local function buildUnitPairs(unitActions, originX, originZ)
	local actionCount = #unitActions
	if actionCount < 2 then
		return
	end

	local maxDistanceSq = 0
	for actionIndex = 1, actionCount do
		local distanceSq = distanceSqCache[unitActions[actionIndex].unitID] or 0
		if distanceSq > maxDistanceSq then
			maxDistanceSq = distanceSq
		end
	end

	local unitIDsBySlice = {}
	local sliceAngle = TWO_PI / ARC_DANCE_SLICE_COUNT

	for sliceIndex = 1, ARC_DANCE_SLICE_COUNT do
		unitIDsBySlice[sliceIndex] = {}
	end

	for actionIndex = 1, actionCount do
		local unitID = unitActions[actionIndex].unitID
		local unitX, unitY, unitZ = spGetUnitPosition(unitID)
		if unitX then
			local angle = mathAtan2(unitX - originX, unitZ - originZ) % TWO_PI
			local sliceIndex = mathFloor(angle / sliceAngle) + 1
			local sliceUnitIDs = unitIDsBySlice[sliceIndex]
			sliceUnitIDs[#sliceUnitIDs + 1] = unitID
		end
	end

	local orderedUnitIDs = {}
	for sliceIndex = 1, ARC_DANCE_SLICE_COUNT do
		local sliceUnitIDs = unitIDsBySlice[sliceIndex]
		if #sliceUnitIDs > 0 then
			table.sort(sliceUnitIDs, function(unitA, unitB)
				return getRadialDancePairingSortKey(unitA, originX, originZ, maxDistanceSq)
					< getRadialDancePairingSortKey(unitB, originX, originZ, maxDistanceSq)
			end)
			for unitIndex = 1, #sliceUnitIDs do
				orderedUnitIDs[#orderedUnitIDs + 1] = sliceUnitIDs[unitIndex]
			end
		end
	end

	local orderedCount = #orderedUnitIDs
	if orderedCount < 2 then
		return
	end

	for pairIndex = 1, orderedCount do
		local sourceUnitID = orderedUnitIDs[pairIndex]
		local structuredPartnerUnitID = orderedUnitIDs[pairIndex == orderedCount and 1 or pairIndex + 1]
		unitPairs[sourceUnitID] = pickDancePartner(sourceUnitID, structuredPartnerUnitID, orderedUnitIDs)
	end
end

local function queueDesolationAction(unitID, fate, frame)
	local frameActions = actionFrames[frame]
	if not frameActions then
		frameActions = {}
		actionFrames[frame] = frameActions
	end
	frameActions[#frameActions + 1] = { unitID = unitID, fate = fate }
end

local function queueCegSpawn(cegName, positionX, positionY, positionZ, frame)
	local frameActions = cegActionFrames[frame]
	if not frameActions then
		frameActions = {}
		cegActionFrames[frame] = frameActions
	end
	frameActions[#frameActions + 1] = { cegName = cegName, x = positionX, y = positionY, z = positionZ }
end

local function queueArcDanceFrame(unitID, frame)
	if not unitPairs[unitID] then
		return
	end
	local frameActions = arcDanceFrames[frame]
	if not frameActions then
		frameActions = {}
		arcDanceFrames[frame] = frameActions
	end
	frameActions[#frameActions + 1] = unitID
end

local function getOriginArcY(originX, originZ)
	return spGetGroundHeight(originX, originZ) + ORIGIN_ARC_HEIGHT_ABOVE_GROUND
end

local function getUnitArcPosition(unitID)
	local _, _, _, arcX, arcY, arcZ = spGetUnitPosition(unitID, false, true)
	return arcX, arcY, arcZ
end

local function spawnArcBetween(fromX, fromY, fromZ, toX, toY, toZ)
	local directionX = toX - fromX
	local directionY = toY - fromY
	local directionZ = toZ - fromZ
	local distance = mathSqrt(directionX * directionX + directionY * directionY + directionZ * directionZ)
	if distance <= 0 then
		return false
	end
	local cegName = getArcCegName(distance)
	if not cegName then
		return false
	end
	spSpawnCEG(cegName, fromX, fromY, fromZ, directionX / distance, directionY / distance, directionZ / distance, 0, distance)
	return true
end

local function spawnArcDance(unitID)
	if not spValidUnitID(unitID) then
		removeUnitPair(unitID)
		return
	end

	local unitX, unitY, unitZ = getUnitArcPosition(unitID)
	if not unitX then
		removeUnitPair(unitID)
		return
	end

	local danceRoll = mathRandom()
	if danceRoll <= ARC_DANCE_ORIGIN_CHANCE then
		local allyTeamID = unitAllyTeams[unitID]
		local origin = allyTeamID and allyTeamOrigins[allyTeamID]
		if origin then
			if danceRoll <= SKIP_DANCE_CHANCE then
				return
			end
			if not spawnArcBetween(origin.x, origin.y, origin.z, unitX, unitY, unitZ) then
				removeUnitPair(unitID)
			end
			return
		end
	end

	local pairedUnitID = unitPairs[unitID]
	if not pairedUnitID or not spValidUnitID(pairedUnitID) then
		removeUnitPair(unitID)
		return
	end

	local pairedUnitX, pairedUnitY, pairedUnitZ = getUnitArcPosition(pairedUnitID)
	if not pairedUnitX then
		removeUnitPair(unitID)
		return
	end

	if not spawnArcBetween(unitX, unitY, unitZ, pairedUnitX, pairedUnitY, pairedUnitZ) then
		removeUnitPair(unitID)
	end
end

local function processArcDance(gameFrame)
	local scheduledUnitIDs = arcDanceFrames[gameFrame]
	if not scheduledUnitIDs then
		return
	end
	arcDanceFrames[gameFrame] = nil
	for unitIndex = 1, #scheduledUnitIDs do
		local unitID = scheduledUnitIDs[unitIndex]
		if unitPairs[unitID] then
			spawnArcDance(unitID)
			if unitPairs[unitID] and spValidUnitID(unitID) then
				queueArcDanceFrame(unitID, gameFrame + mathRandom(ARC_DANCE_RESCHEDULE_MIN_FRAMES, ARC_DANCE_RESCHEDULE_MAX_FRAMES))
			end
		end
	end
end

local function scheduleEvents(startFrame, originX, originZ, unitActions, minPower, maxPower, allyTeamID)
	suspendViolence(true)

	local groundY = spGetGroundHeight(originX, originZ)
	allyTeamOrigins[allyTeamID] = { x = originX, y = getOriginArcY(originX, originZ), z = originZ }
	spSpawnCEG(TENEBRIUM_CORE_CEG, originX, groundY, originZ)

	local explosionStartFrame = startFrame + SHOCKWAVE_DURATION + WAIT_DURATION
	local actionCount = #unitActions
	if actionCount == 0 then
		return
	end

	if actionCount > 1 then
		table.sort(unitActions, function(actionA, actionB)
			return (distanceSqCache[actionA.unitID] or 0) < (distanceSqCache[actionB.unitID] or 0)
		end)
	end
	buildUnitPairs(unitActions, originX, originZ)

	for actionIndex = 1, actionCount do
		local cascadeRankT = actionCount == 1 and 1 or (actionCount - actionIndex) / (actionCount - 1)
		local unitAction = unitActions[actionIndex]
		local unitPower = defData[spGetUnitDefID(unitAction.unitID)].power or 0
		local danceFrameOffset = getKillVarianceFrames(
			mathFloor(inCubic(1 - cascadeRankT) * SHOCKWAVE_DURATION + 0.5),
			unitPower,
			minPower,
			maxPower
		)
		local desolationFrameOffset = getKillVarianceFrames(
			mathFloor(outCubic(1 - cascadeRankT) * CASCADE_DURATION + 0.5),
			unitPower,
			minPower,
			maxPower
		)

		unitAllyTeams[unitAction.unitID] = allyTeamID
		queueArcDanceFrame(unitAction.unitID, startFrame + danceFrameOffset)
		queueDesolationAction(unitAction.unitID, unitAction.fate, explosionStartFrame + desolationFrameOffset)
	end
end

local function sortUnitsByPower(unitTable)
	local sortedUnits = {}
	local powerByUnit = {}
	for unitIndex = 1, #unitTable do
		local unitID = unitTable[unitIndex]
		local unitDefID = spGetUnitDefID(unitID)
		sortedUnits[unitIndex] = unitID
		powerByUnit[unitID] = defData[unitDefID].power or 0
	end
	table.sort(sortedUnits, function(unitA, unitB)
		return powerByUnit[unitA] > powerByUnit[unitB]
	end)
	return sortedUnits
end

local function sortUnitsByDesirabilityAndDistance(unitsTable, positionTable)
	local sortedUnits = {}
	local closestDistanceByUnit = {}

	for unitIndex = 1, #unitsTable do
		local unitID = unitsTable[unitIndex]
		sortedUnits[unitIndex] = unitID
		local unitX, unitY, unitZ = spGetUnitPosition(unitID)
		local closestDistance = math.huge
		if unitX then
			for positionIndex = 1, #positionTable do
				local position = positionTable[positionIndex]
				local distance = mathDistance2dSquared(position.x, position.z, unitX, unitZ)
				closestDistance = mathMin(distance, closestDistance)
			end
		end

		local canMove = defData[spGetUnitDefID(unitID)].canMove
		closestDistanceByUnit[unitID] = canMove and closestDistance * CAN_MOVE_PENALTY_MULTIPLIER or closestDistance
	end

	table.sort(sortedUnits, function(unitA, unitB)
		return closestDistanceByUnit[unitA] > closestDistanceByUnit[unitB] --longer distances first
	end)

	return sortedUnits
end

local function desolateTeam(teamID)
	desolatedTeams[teamID] = true
	local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID)
	local origin = allyTeamOrigins[allyTeamID]
	local originX = origin and origin.x or 0
	local originZ = origin and origin.z or 0
	local teamUnits = spGetTeamUnits(teamID)
	local turrets = {}
	local hotspots = {}
	local currentFrame = Spring.GetGameFrame()
	local currentPower = 0

	--got turrets??
	--Collect Distances
	for unitIndex = 1, #teamUnits do
		local unitID = teamUnits[unitIndex]
		local unitDefID = spGetUnitDefID(unitID)
		local unitDefEntry = defData[unitDefID]
		if unitDefEntry and unitDefEntry.isTurret then
			turrets[#turrets + 1] = unitID
		end
		currentPower = currentPower + unitDefEntry.power

		local x, y, z = spGetUnitPosition(unitID)
		distanceSqCache[unitID] = mathDistance2dSquared(x, z, originX, originZ)
	end
	turrets = sortUnitsByPower(turrets)

	--pick some turrets to preserve and positions
	for hotspotIndex = 1, mathMin(TURRET_HOTSPOT_COUNT, #turrets) do
		local randomSelection = dndStyleDisadvantageBias(#turrets, POWERFUL_TURRET_BIAS)
		local unitID = turrets[randomSelection]
		local x, y, z = spGetUnitPosition(unitID)
		hotspots[#hotspots + 1] = { x = x, z = z }
		desolateUnit(unitID, DESOLATE_GAIA) --set to neutral immediately to ensure they exist later
		removeEntrySwap(turrets, randomSelection)
	end

	--sort by desirability
	teamUnits = spGetTeamUnits(teamID) --refresh to exclude turrets
	teamUnits = sortUnitsByDesirabilityAndDistance(teamUnits, hotspots)

	local erasurePowerTargetThreshold = currentPower * DESOLATION_QUOTA_RATIO
	local unitActions = {}
	local minPower = math.huge
	local maxPower = -math.huge

	local function rememberUnitPower(unitID)
		local unitPower = defData[spGetUnitDefID(unitID)].power or 0
		if unitPower < minPower then
			minPower = unitPower
		end
		if unitPower > maxPower then
			maxPower = unitPower
		end
		return unitPower
	end

	for eraseIndex = 1, #teamUnits do
		if currentPower <= erasurePowerTargetThreshold or #teamUnits == 0 then
			break
		end
		local randomSelection = dndStyleDisadvantageBias(#teamUnits, 2)
		local unitID = teamUnits[randomSelection]
		local unitPower = rememberUnitPower(unitID)
		unitActions[#unitActions + 1] = { unitID = unitID, fate = DESOLATE_ERASE }
		currentPower = currentPower - unitPower
		removeEntrySwap(teamUnits, randomSelection)
	end

	for unitIndex = 1, #teamUnits do
		local unitID = teamUnits[unitIndex]
		rememberUnitPower(unitID)
		local fate = chooseFate(unitID)
		unitActions[#unitActions + 1] = { unitID = unitID, fate = fate }
	end

	scheduleEvents(currentFrame, originX, originZ, unitActions, minPower, maxPower, allyTeamID)
end

local function desolateCommand(cmd, line, words, playerID)
	if not Spring.IsCheatingEnabled() then
		return
	end
	local teamID = tonumber(words[1])
	if not teamID then
		Spring.Echo("Desolate: usage /luarules desolate <teamID>")
		return
	end
	if not Spring.GetTeamInfo(teamID) then
		Spring.Echo("Desolate: invalid team ID " .. tostring(teamID))
		return
	end
	desolateTeam(teamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if defData[unitDefID].isCommander then
		local originX, _, originZ = spGetUnitPosition(unitID)
		if originX then
			local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(unitTeam)
			allyTeamOrigins[allyTeamID] = { x = originX, y = getOriginArcY(originX, originZ), z = originZ }
		end
	end
end

function gadget:GameFrame(gameFrame)
	if fireStateLockEndFrame > 0 and gameFrame >= fireStateLockEndFrame then
		suspendViolence(false)
	end
	local scheduledCegActions = cegActionFrames[gameFrame]
	if scheduledCegActions then
		cegActionFrames[gameFrame] = nil
		for actionIndex = 1, #scheduledCegActions do
			local action = scheduledCegActions[actionIndex]
			spSpawnCEG(action.cegName, action.x, action.y, action.z)
		end
	end
	processArcDance(gameFrame)
	local frameActions = actionFrames[gameFrame]
	if not frameActions then
		return
	end
	actionFrames[gameFrame] = nil
	for actionIndex = 1, #frameActions do
		local action = frameActions[actionIndex]
		removeUnitPair(action.unitID)
		desolateUnit(action.unitID, action.fate)
	end
end

function gadget:Initialize()
	gadgetHandler:AddChatAction("desolate", desolateCommand, "Wipes a team to 20% of highest player peak power. Usage: /luarules desolate <teamID>. Requires /cheat")
	GG.Desolation = {}
	GG.Desolation['DesolateTeam'] = desolateTeam
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("desolate")
end