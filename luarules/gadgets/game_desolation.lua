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

if not gadgetHandler:IsSyncedCode() then return false end

local DESOLATION_QUOTA_RATIO = 0.2
local REDEEMABLE_CHANCE = 0.5
local TURRET_GAIA_CHANCE = 0.75
local SHOCKWAVE_DURATION = 45
local WAIT_DURATION = 30
local IMPLOSION_DURATION = 300
local KILL_VARIANCE_FRAMES = 20
local LIGHTNING_ORANGE_DELAY_FRAMES = 15
local LIGHTNING_ORANGE_FRACTION = 0.01
local LIGHTNING_ORANGE_MIN_SPAWNS = 1
local SHOCKWAVE_CEG = "tenebrium_implosion"
local IMPLOSION_CEG = "tenebrium_implosion_collapse"
local IMPLOSION_SEQUENCE_END_OFFSET = SHOCKWAVE_DURATION + WAIT_DURATION + IMPLOSION_DURATION
local CMD_FIRE_STATE = CMD.FIRE_STATE
local FIRE_STATE_RETURN_FIRE = 1
local FIRE_STATE_FIRE_AT_WILL = 2
local DESOLATION_ORANGE_LIGHTNING_CEG_PREFIX = "tenebrium_desolation_orange_arc_"
local DESOLATION_TEAL_LIGHTNING_CEG = "tenebrium_desolation_teal_arc"
local POWERFUL_TURRET_BIAS = 3
local TURRET_HOTSPOT_COUNT = 5
local DESOLATE_GAIA = 0
local DESOLATE_CORPSE = 1
local DESOLATE_HEAP = 2
local DESOLATE_ERASE = 3

local CAN_MOVE_PENALTY_MULTIPLIER = 4

local TO_HEAP_DAMAGE_RATIO = 0.5

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
local mathCeil = math.ceil
local mathSqrt = math.sqrt
local mathDistance2dSquared = math.distance2dSquared
local cascadeOrigins = {x = 0, z = 0}

local gaiaTeam = Spring.GetGaiaTeamID()

local defData = {}
local commanderDefs = {}
local actionFrames = {}
local cegActionFrames = {}
local desolatedTeams = {}
local distanceSqCache = {}
local activeSequences = {}
local fireStateLockEndFrame = 0

local function getOrangeLightningSizeName(unitDef)
	local size = mathCeil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
	if size > 4.5 then
		return "huge"
	elseif size > 3.5 then
		return "large"
	elseif size > 2.5 then
		return "medium"
	elseif size > 1.5 then
		return "small"
	else
		return "tiny"
	end
end

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
	data.orangeLightningSize = getOrangeLightningSizeName(unitDef)
	defData[unitDefID] = data
end

local function setAllUnitsFireState(fireState)
	for _, unitID in ipairs(spGetAllUnits()) do
		if spValidUnitID(unitID) then
			spGiveOrderToUnit(unitID, CMD_FIRE_STATE, fireState, 0)
		end
	end
end

local function beginImplosionFireStateLock(startFrame)
	setAllUnitsFireState(FIRE_STATE_RETURN_FIRE)
	fireStateLockEndFrame = mathMax(fireStateLockEndFrame, startFrame + IMPLOSION_SEQUENCE_END_OFFSET)
end

local function processImplosionFireStateUnlock(gameFrame)
	if fireStateLockEndFrame <= 0 or gameFrame < fireStateLockEndFrame then
		return
	end
	setAllUnitsFireState(FIRE_STATE_FIRE_AT_WILL)
	fireStateLockEndFrame = 0
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

local function outQuint(t)
	return 1 - (1 - t) ^ 5
end

local function getShockwaveRadiusSq(elapsedFrames, farthestDistanceSq)
	if SHOCKWAVE_DURATION <= 0 or farthestDistanceSq <= 0 then
		return farthestDistanceSq
	end
	local progress = mathMin(1, elapsedFrames / SHOCKWAVE_DURATION)
	return progress * progress * farthestDistanceSq
end

local function getImplosionFrameOffset(distanceSq, nearestDistanceSq, farthestDistanceSq)
	local nearestDistance = mathSqrt(nearestDistanceSq)
	local farthestDistance = mathSqrt(farthestDistanceSq)
	local distanceSpread = farthestDistance - nearestDistance
	if distanceSpread <= 0 then
		return 0
	end
	local distance = mathSqrt(distanceSq)
	local normalizedDistance = (distance - nearestDistance) / distanceSpread
	return mathFloor(outQuint(1 - normalizedDistance) * IMPLOSION_DURATION + 0.5)
end

local function applyKillVariance(frameOffset)
	if KILL_VARIANCE_FRAMES <= 0 then
		return frameOffset
	end
	return mathMax(0, frameOffset + mathRandom(0, KILL_VARIANCE_FRAMES))
end

local function getTowardOriginDirection(positionX, positionY, positionZ, originX, originY, originZ)
	local dirX = originX - positionX
	local dirY = originY - positionY
	local dirZ = originZ - positionZ
	local magnitude = mathSqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
	if magnitude <= 0.001 then
		return 0, 1, 0
	end
	return dirX / magnitude, dirY / magnitude, dirZ / magnitude
end

local function spawnTenebriumLightning(unitID, originX, originY, originZ, isWaveEdge)
	if not spValidUnitID(unitID) then
		return
	end
	local positionX, positionY, positionZ = spGetUnitPosition(unitID)
	if not positionX then
		return
	end
	local cegName
	if isWaveEdge then
		cegName = DESOLATION_TEAL_LIGHTNING_CEG
	else
		local unitDefID = spGetUnitDefID(unitID)
		local unitDefEntry = defData[unitDefID]
		local sizeName = unitDefEntry and unitDefEntry.orangeLightningSize or "small"
		cegName = DESOLATION_ORANGE_LIGHTNING_CEG_PREFIX .. sizeName
	end
	local dirX, dirY, dirZ = getTowardOriginDirection(positionX, positionY, positionZ, originX, originY, originZ)
	spSpawnCEG(cegName, positionX, positionY, positionZ, dirX, dirY, dirZ)
end

local function shufflePartialTable(tableToShuffle, entryCount)
	for shuffleIndex = entryCount, 2, -1 do
		local swapIndex = mathRandom(1, shuffleIndex)
		tableToShuffle[shuffleIndex], tableToShuffle[swapIndex] = tableToShuffle[swapIndex], tableToShuffle[shuffleIndex]
	end
end

local function removeEntrySwap(tableToMutate, removeIndex)
	local lastIndex = #tableToMutate
	tableToMutate[removeIndex] = tableToMutate[lastIndex]
	tableToMutate[lastIndex] = nil
end

local function processOrangeLightningBatch(sequence, gameFrame)
	if LIGHTNING_ORANGE_FRACTION <= 0 then
		return
	end

	local readyFrameUnits = sequence.orangeReadyFrames[gameFrame]
	if readyFrameUnits then
		sequence.orangeReadyFrames[gameFrame] = nil
		local eligibleUnits = sequence.orangeEligibleUnits
		local eligibleCount = sequence.orangeEligibleCount
		for unitIndex = 1, #readyFrameUnits do
			local unitID = readyFrameUnits[unitIndex]
			if spValidUnitID(unitID) then
				eligibleCount = eligibleCount + 1
				eligibleUnits[eligibleCount] = unitID
			end
		end
		sequence.orangeEligibleCount = eligibleCount
	end

	local eligibleUnits = sequence.orangeEligibleUnits
	local eligibleCount = sequence.orangeEligibleCount
	if eligibleCount <= 0 then
		return
	end

	local spawnCount = mathMax(LIGHTNING_ORANGE_MIN_SPAWNS, mathFloor(eligibleCount * LIGHTNING_ORANGE_FRACTION))
	if spawnCount > eligibleCount then
		spawnCount = eligibleCount
	end

	local originX = sequence.originX
	local originY = sequence.originY
	local originZ = sequence.originZ
	local remainingEligibleCount = eligibleCount
	for spawnIndex = 1, spawnCount do
		local randomIndex = mathRandom(1, remainingEligibleCount)
		eligibleUnits[randomIndex], eligibleUnits[remainingEligibleCount] = eligibleUnits[remainingEligibleCount], eligibleUnits[randomIndex]
		spawnTenebriumLightning(eligibleUnits[remainingEligibleCount], originX, originY, originZ, false)
		remainingEligibleCount = remainingEligibleCount - 1
	end
end

local function processSequenceLightning(sequence, elapsedFrames, gameFrame)
	local maxRadiusSq
	if elapsedFrames < SHOCKWAVE_DURATION then
		maxRadiusSq = getShockwaveRadiusSq(elapsedFrames, sequence.farthestDistanceSq)
	else
		maxRadiusSq = sequence.farthestDistanceSq
	end

	local unitsByDistance = sequence.unitsByDistance
	local nextWaveUnitIndex = sequence.nextWaveUnitIndex
	local unitCount = #unitsByDistance
	while nextWaveUnitIndex <= unitCount do
		local unitEntry = unitsByDistance[nextWaveUnitIndex]
		if unitEntry.distanceSq > maxRadiusSq then
			break
		end
		local unitID = unitEntry.unitID
		if spValidUnitID(unitID) then
			spawnTenebriumLightning(unitID, sequence.originX, sequence.originY, sequence.originZ, true)
			local readyFrame = gameFrame + LIGHTNING_ORANGE_DELAY_FRAMES
			local readyFrameUnits = sequence.orangeReadyFrames[readyFrame]
			if not readyFrameUnits then
				readyFrameUnits = {}
				sequence.orangeReadyFrames[readyFrame] = readyFrameUnits
			end
			readyFrameUnits[#readyFrameUnits + 1] = unitID
		end
		nextWaveUnitIndex = nextWaveUnitIndex + 1
	end
	sequence.nextWaveUnitIndex = nextWaveUnitIndex

	processOrangeLightningBatch(sequence, gameFrame)
end

local function sequenceHasLivingUnits(sequence)
	local sequenceUnits = sequence.units
	for unitIndex = 1, #sequenceUnits do
		if spValidUnitID(sequenceUnits[unitIndex].unitID) then
			return true
		end
	end
	return false
end

local function processActiveSequences(gameFrame)
	for sequenceIndex = #activeSequences, 1, -1 do
		local sequence = activeSequences[sequenceIndex]
		local elapsedFrames = gameFrame - sequence.startFrame
		processSequenceLightning(sequence, elapsedFrames, gameFrame)
		if not sequenceHasLivingUnits(sequence) then
			table.remove(activeSequences, sequenceIndex)
		end
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

local function scheduleShockwave(startFrame, originX, originZ, farthestDistanceSq, livingUnits)
	local groundY = spGetGroundHeight(originX, originZ)
	local unitsByDistance = {}
	for unitIndex = 1, #livingUnits do
		unitsByDistance[unitIndex] = livingUnits[unitIndex]
	end
	table.sort(unitsByDistance, function(unitA, unitB)
		return unitA.distanceSq < unitB.distanceSq
	end)
	local sequence = {
		startFrame = startFrame,
		originX = originX,
		originY = groundY,
		originZ = originZ,
		farthestDistanceSq = farthestDistanceSq,
		implosionStartFrame = startFrame + SHOCKWAVE_DURATION + WAIT_DURATION,
		units = livingUnits,
		unitsByDistance = unitsByDistance,
		nextWaveUnitIndex = 1,
		orangeReadyFrames = {},
		orangeEligibleUnits = {},
		orangeEligibleCount = 0,
	}
	activeSequences[#activeSequences + 1] = sequence
	spSpawnCEG(SHOCKWAVE_CEG, originX, groundY, originZ)
	queueCegSpawn(IMPLOSION_CEG, originX, groundY, originZ, startFrame + IMPLOSION_SEQUENCE_END_OFFSET)
	return sequence
end

local function scheduleWait(sequence)
	sequence.waitEndFrame = sequence.startFrame + SHOCKWAVE_DURATION + WAIT_DURATION
	return sequence.waitEndFrame
end

local function scheduleImplosion(sequence, unitActions)
	local implosionStartFrame = sequence.implosionStartFrame
	local nearestDistanceSq = math.huge
	local farthestDistanceSq = 0
	for actionIndex = 1, #unitActions do
		local distanceSq = distanceSqCache[unitActions[actionIndex].unitID] or 0
		nearestDistanceSq = mathMin(nearestDistanceSq, distanceSq)
		farthestDistanceSq = mathMax(farthestDistanceSq, distanceSq)
	end

	local distanceSpread = mathSqrt(farthestDistanceSq) - mathSqrt(nearestDistanceSq)
	if distanceSpread <= 0 and #unitActions > 1 then
		table.sort(unitActions, function(actionA, actionB)
			local distanceSqA = distanceSqCache[actionA.unitID] or 0
			local distanceSqB = distanceSqCache[actionB.unitID] or 0
			return distanceSqA > distanceSqB
		end)
		local actionCount = #unitActions
		for actionIndex = 1, actionCount do
			local rankT = (actionCount - actionIndex) / (actionCount - 1)
			local frameOffset = applyKillVariance(mathFloor(outQuint(1 - rankT) * IMPLOSION_DURATION + 0.5))
			local unitAction = unitActions[actionIndex]
			queueDesolationAction(unitAction.unitID, unitAction.fate, implosionStartFrame + frameOffset)
		end
		return
	end

	for actionIndex = 1, #unitActions do
		local unitAction = unitActions[actionIndex]
		local distanceSq = distanceSqCache[unitAction.unitID] or 0
		local frameOffset = applyKillVariance(getImplosionFrameOffset(distanceSq, nearestDistanceSq, farthestDistanceSq))
		queueDesolationAction(unitAction.unitID, unitAction.fate, implosionStartFrame + frameOffset)
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
	Spring.Echo("Team Desolated!", teamID)
	desolatedTeams[teamID] = true
	local teamUnits = spGetTeamUnits(teamID)
	local turrets = {}
	local hotspots = {}
	local currentFrame = Spring.GetGameFrame()
	local currentPower = 0
	local farthestDistanceSq = 0

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
		local distanceSq = mathDistance2dSquared(x, z, cascadeOrigins.x, cascadeOrigins.z)
		distanceSqCache[unitID] = distanceSq
		farthestDistanceSq = math.max(farthestDistanceSq, distanceSq)
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
	local livingUnits = {}

	for eraseIndex = 1, #teamUnits do
		if currentPower <= erasurePowerTargetThreshold or #teamUnits == 0 then
			break
		end
		local randomSelection = dndStyleDisadvantageBias(#teamUnits, 2)
		local unitID = teamUnits[randomSelection]
		local unitDefID = spGetUnitDefID(unitID)
		local unitPower = defData[unitDefID].power or 0
		unitActions[#unitActions + 1] = { unitID = unitID, fate = DESOLATE_ERASE }
		livingUnits[#livingUnits + 1] = {
			unitID = unitID,
			distanceSq = distanceSqCache[unitID] or 0,
		}
		currentPower = currentPower - unitPower
		removeEntrySwap(teamUnits, randomSelection)
	end

	for unitIndex = 1, #teamUnits do
		local unitID = teamUnits[unitIndex]
		local fate = chooseFate(unitID)
		unitActions[#unitActions + 1] = { unitID = unitID, fate = fate }
		livingUnits[#livingUnits + 1] = {
			unitID = unitID,
			distanceSq = distanceSqCache[unitID] or 0,
		}
	end

	local sequence = scheduleShockwave(currentFrame, cascadeOrigins.x, cascadeOrigins.z, farthestDistanceSq, livingUnits)
	beginImplosionFireStateLock(currentFrame)
	scheduleWait(sequence)
	scheduleImplosion(sequence, unitActions)
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
		cascadeOrigins.x, _, cascadeOrigins.z = spGetUnitPosition(unitID)
	end
end

function gadget:GameFrame(gameFrame)
	processActiveSequences(gameFrame)
	processImplosionFireStateUnlock(gameFrame)
	local scheduledCegActions = cegActionFrames[gameFrame]
	if scheduledCegActions then
		cegActionFrames[gameFrame] = nil
		for actionIndex = 1, #scheduledCegActions do
			local action = scheduledCegActions[actionIndex]
			spSpawnCEG(action.cegName, action.x, action.y, action.z)
		end
	end
	local frameActions = actionFrames[gameFrame]
	if not frameActions then
		return
	end
	actionFrames[gameFrame] = nil
	for actionIndex = 1, #frameActions do
		local action = frameActions[actionIndex]
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
