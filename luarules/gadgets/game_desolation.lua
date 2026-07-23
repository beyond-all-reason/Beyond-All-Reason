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
--zzz need to change the timing on the new explosion cascade
--[[ TODO:
get decisions from gdt as to what should be leftover and how they should be left over
remove the old now supplanted code related to end game sequencing
nest the logic that exists in the old explosion sequence into this
integrate into mission API somehow?
get approval from icexuick/protar for aesthetics
reduce tenebrium implosion timing
rename all instances of "implosion" -> "explosion" or "core" if it's refering the core
]]

if not gadgetHandler:IsSyncedCode() then return false end

-- biases and chances

-- desolation power quota
-- Stop power-erasing units once remaining team power is at or below this fraction of pre-desolation power (0.2 = 20% floor).
local DESOLATION_QUOTA_RATIO = 0.2

-- erasure and hotspot selection
-- Hotspot turret picks: count of disadvantage rolls (take minimum index); higher = stronger bias toward high-power turrets in the power-sorted list.
local POWERFUL_TURRET_BIAS = 3
-- Erasure sort only: multiplies distance from hotspots for mobile units so they are treated as farther and erased earlier (4 = 4x effective distance).
local CAN_MOVE_PENALTY_MULTIPLIER = 4

-- unit fate after quota
-- Per surviving unit: chance to avoid default heap fate and roll corpse or gaia instead (1 = always redeemable).
local REDEEMABLE_CHANCE = 0.5
-- Of redeemable turrets only: chance to become gaia rather than a corpse (1 = all redeemable turrets go gaia).
local TURRET_GAIA_CHANCE = 0.75
-- Reserved; not referenced yet (intended heap damage fraction if wired in).
local TO_HEAP_DAMAGE_RATIO = 0.5

local GAME_SPEED = Game.gameSpeed
local SHOCKWAVE_SPEED_ELMOS_PER_SEC = 150
local SHOCKWAVE_SPEED = SHOCKWAVE_SPEED_ELMOS_PER_SEC / GAME_SPEED
local SHOCKWAVE_DURATION_SECONDS = 10
local SHOCKWAVE_DURATION_FRAMES = SHOCKWAVE_DURATION_SECONDS * GAME_SPEED
local SHOCKWAVE_REACH_DISTANCE = SHOCKWAVE_SPEED_ELMOS_PER_SEC * SHOCKWAVE_DURATION_SECONDS
local SHOCKWAVE_REACH_DISTANCE_SQ = SHOCKWAVE_REACH_DISTANCE * SHOCKWAVE_REACH_DISTANCE

-- cascade and kill timing spread
local MAX_RANDOM_KILL_FRAMES = 30

-- cookoff sequence (top COOKOFF_TOP_UNIT_FRACTION by power survive the first cascade, cook off, then die in the second cascade)
-- Length of one desolation_cookoff CEG playthrough in frames; must match COOKOFF_DELAY_WINDOW in effects/desolation_cookoff.lua (30 = ~1s at 30fps).
local COOKOFF_CEG_DURATION_FRAMES = 30
local COOKOFF_CEG_COUNT = 2
local COOKOFF_DURATION_FRAMES = SHOCKWAVE_DURATION_FRAMES
-- Fraction of alive team units (by count, sorted by power) that cook off through the first cascade instead of dying in it: 0.2 = top 20% strongest at desolation start.
local COOKOFF_TOP_UNIT_FRACTION = 0.1
-- Cookoff kill spread within COOKOFF_DURATION_FRAMES; weakest first, strongest last (Penner easeOutBounce).
local COOKOFF_BOUNCE_SCALE = 12.25
-- Ease-out bounce segment count/spacing; higher = more tighter bounces, lower = fewer wider bounces.
-- Segment offsets in timeFromCookoffRankT are calibrated for 3.5; change only with Penner easeOutBounce math.
local COOKOFF_BOUNCE_DIVISOR = 3.5
-- Max extra kill-delay frames added at the farthest cookoff unit; scales linearly with normalized distance for tie-break jitter.
local COOKOFF_DISTANCE_JITTER_FRAMES = 5
local HEAP_ARC_BURST = 410
local HEAP_ARC_DELAY_FRAMES = 15
local RANDOM_ARC_CHANCE = 0.75
local CMD_FIRE_STATE = CMD.FIRE_STATE
local FIRE_STATE_RETURN_FIRE = 1
local FIRE_STATE_FIRE_AT_WILL = 2
local TURRET_HOTSPOT_COUNT = 5
local DESOLATE_GAIA = 0
local DESOLATE_CORPSE = 1
local DESOLATE_HEAP = 2
local DESOLATE_ERASE = 3
local COOKOFF_CEGS = {
	tiny = { "desolation_cookoff_tiny" },
	small = { "desolation_cookoff_small" },
	medium = { "desolation_cookoff_medium" },
	large = { "desolation_cookoff_large" },
	huge = { "desolation_cookoff_huge" },
}
local TENEBRIUM_IMPLOSION_CEG = "tenebrium_implosion"
local TENEBRIUM_IMPLOSION_Y_OFFSET = 30
local HEAP_LIGHTNING_CEG = "tenebrium_desolation_heap_arc"
local HEAP_EXPLOSION_CEGS = {
	tiny = "desolation_heap_explosion_tiny",
	small = "desolation_heap_explosion_small",
	medium = "desolation_heap_explosion_medium",
	large = "desolation_heap_explosion_large",
	huge = "desolation_heap_explosion_huge",
}

local spSpawnExplosion = Spring.SpawnExplosion
local spCreateFeature = Spring.CreateFeature
local spDestroyFeature = Spring.DestroyFeature
local spValidFeatureID = Spring.ValidFeatureID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spDestroyUnit = Spring.DestroyUnit
local spGetTeamUnits = Spring.GetTeamUnits
local spTransferUnit = Spring.TransferUnit
local spValidUnitID = Spring.ValidUnitID
local spSpawnCEG = Spring.SpawnCEG
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetAllUnits = Spring.GetAllUnits
local spGetGroundHeight = Spring.GetGroundHeight
local mathRandom = math.random
local mathMax = math.max
local mathMin = math.min
local mathFloor = math.floor
local mathCeil = math.ceil
local mathSqrt = math.sqrt
local mathDistance2dSquared = math.distance2dSquared

local gaiaTeam = Spring.GetGaiaTeamID()

local defData = {}
local actionFrames = {}
local cegActionFrames = {}
local heapActionFrames = {}
local allyTeamOrigins = {}
local desolatedTeams = {}
local distanceSqCache = {}
local cookoffEligibleUnitIDs = {}
local pendingHeapByUnitID = {}
local implosionSpawnedAllyTeams = {}
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

local function getCookoffSize(unitDef)
	local footprintMetric = math.ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
	if footprintMetric > 4.5 then
		return "huge"
	elseif footprintMetric > 3.5 then
		return "large"
	elseif footprintMetric > 2.5 then
		return "medium"
	elseif footprintMetric > 1.5 then
		return "small"
	end
	return "tiny"
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	local data = {}
	
	data.power = unitDef.power
	data.cookoffSize = getCookoffSize(unitDef)

	local corpseDefName = unitDef.corpse
	if FeatureDefNames[corpseDefName] then
		local corpseDefID = FeatureDefNames[corpseDefName].id
		data.corpseDefID = corpseDefID
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

local function suspendViolence(suspended, sequenceEndOffset)
	local fireState = suspended and FIRE_STATE_RETURN_FIRE or FIRE_STATE_FIRE_AT_WILL
	for _, unitID in ipairs(spGetAllUnits()) do
		if spValidUnitID(unitID) then
			spGiveOrderToUnit(unitID, CMD_FIRE_STATE, fireState, 0)
		end
	end
	if suspended then
		fireStateLockEndFrame = mathMax(fireStateLockEndFrame, Spring.GetGameFrame() + sequenceEndOffset)
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

local function getUnitArcTargetPosition(unitID)
	local _, _, _, aimX, aimY, aimZ = spGetUnitPosition(unitID, false, true)
	return aimX, aimY, aimZ
end

local function resolveHeapTargetPosition(entry)
	if entry.targetX then
		return entry.targetX, entry.targetY, entry.targetZ
	end
	local featureID = entry.featureID
	if featureID and spValidFeatureID(featureID) then
		local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
		if featureX then
			return featureX, featureY, featureZ
		end
	end
end

local function spawnHeapLightning(entry, targetX, targetY, targetZ)
	local directionX = targetX - entry.originX
	local directionY = targetY - entry.originY
	local directionZ = targetZ - entry.originZ
	local distance = mathSqrt(directionX * directionX + directionY * directionY + directionZ * directionZ)
	if distance <= 0 then
		return
	end
	spSpawnCEG(HEAP_LIGHTNING_CEG, entry.originX, entry.originY, entry.originZ, directionX / distance, directionY / distance, directionZ / distance, 0, distance)
end

local function spawnCorpseExplosionCeg(cegName, x, y, z)
	if cegName then
		spSpawnCEG(cegName, x, y, z)
	end
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

	if fate == DESOLATE_HEAP then
		local unitTeam = spGetUnitTeam(unitID)
		local heading = spGetUnitHeading(unitID)
		local entry = pendingHeapByUnitID[unitID]
		spDestroyUnit(unitID, false, true, -1)
		if entry and entry.corpseDefID then
			entry.featureID = spCreateFeature(entry.corpseDefID, x, y, z, heading, unitTeam)
			entry.targetX = x
			entry.targetY = y
			entry.targetZ = z
			entry.unitTeam = unitTeam
		end
		return
	end

	if fate == DESOLATE_ERASE then
		spDestroyUnit(unitID, false, true, -1)
		spSpawnExplosion(x, y, z, 0, 0, 0, {weaponDef = data.explosionDefID, owner = unitID})
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

local function timeFromCookoffRankT(rankT)
	if rankT < 1 / COOKOFF_BOUNCE_DIVISOR then
		return COOKOFF_BOUNCE_SCALE * rankT * rankT
	end
	if rankT < 2 / COOKOFF_BOUNCE_DIVISOR then
		local adjustedRankT = rankT - 1.5 / COOKOFF_BOUNCE_DIVISOR
		return COOKOFF_BOUNCE_SCALE * adjustedRankT * adjustedRankT + 0.75
	end
	if rankT < 2.5 / COOKOFF_BOUNCE_DIVISOR then
		local adjustedRankT = rankT - 2.25 / COOKOFF_BOUNCE_DIVISOR
		return COOKOFF_BOUNCE_SCALE * adjustedRankT * adjustedRankT + 0.9375
	end
	local adjustedRankT = rankT - 2.625 / COOKOFF_BOUNCE_DIVISOR
	return COOKOFF_BOUNCE_SCALE * adjustedRankT * adjustedRankT + 0.984375
end

local function computeShockwaveFrameAtDistance(distance)
	if distance <= 0 then
		return 0
	end
	local traveled = 0
	local frames = 0
	while traveled < distance do
		traveled = traveled + SHOCKWAVE_SPEED
		frames = frames + 1
	end
	return frames
end

local function buildShockwaveProfile(maxDistance)
	return {
		maxDistance = maxDistance,
		targetFrames = SHOCKWAVE_DURATION_FRAMES,
	}
end

local function getMaxDistanceSqFromUnitActions(unitActions)
	local maxDistanceSq = 0
	for actionIndex = 1, #unitActions do
		local distanceSq = distanceSqCache[unitActions[actionIndex].unitID] or 0
		if distanceSq > maxDistanceSq then
			maxDistanceSq = distanceSq
		end
	end
	return maxDistanceSq
end

local function getKillVarianceFrames(frameOffset, cascadeT)
	if MAX_RANDOM_KILL_FRAMES <= 0 then
		return frameOffset
	end
	local varianceMax = mathFloor(cascadeT * MAX_RANDOM_KILL_FRAMES + 0.5)
	if varianceMax <= 0 then
		return frameOffset
	end
	return mathMax(0, frameOffset + mathRandom(0, varianceMax))
end

local function removeEntrySwap(tableToMutate, removeIndex)
	local lastIndex = #tableToMutate
	tableToMutate[removeIndex] = tableToMutate[lastIndex]
	tableToMutate[lastIndex] = nil
end

local function queueDesolationAction(unitID, fate, frame)
	local frameActions = actionFrames[frame]
	if not frameActions then
		frameActions = {}
		actionFrames[frame] = frameActions
	end
	frameActions[#frameActions + 1] = { unitID = unitID, fate = fate }
end

local function queueUnitCookoff(unitID, cegName, frame)
	local frameActions = cegActionFrames[frame]
	if not frameActions then
		frameActions = {}
		cegActionFrames[frame] = frameActions
	end
	frameActions[#frameActions + 1] = { cegName = cegName, unitID = unitID }
end

local function queueCookoff(unitID, frame)
	local cookoffList = COOKOFF_CEGS[defData[spGetUnitDefID(unitID)].cookoffSize]
	if not cookoffList then
		return
	end
	if not spValidUnitID(unitID) then
		return
	end
	local cegName = cookoffList[mathRandom(1, #cookoffList)]
	queueUnitCookoff(unitID, cegName, frame)
end

local function queueCookoffBurst(unitID, startFrame)
	for cookoffIndex = 0, COOKOFF_CEG_COUNT - 1 do
		queueCookoff(unitID, startFrame + cookoffIndex * COOKOFF_CEG_DURATION_FRAMES)
	end
end

local function isBeyondShockwaveReach(unitID)
	return (distanceSqCache[unitID] or 0) > SHOCKWAVE_REACH_DISTANCE_SQ
end

local function assignBeyondReachRandomOffsets(unitActions, durationFrames, offsetField)
	if durationFrames <= 0 then
		return
	end
	for actionIndex = 1, #unitActions do
		local unitAction = unitActions[actionIndex]
		if isBeyondShockwaveReach(unitAction.unitID) then
			unitAction[offsetField] = mathRandom(0, durationFrames)
		end
	end
end

local function assignShockwaveOffsets(unitActions, shockwaveDuration, shockwaveProfile, allowKillVariance, offsetField)
	local targetFrames = shockwaveProfile.targetFrames
	for actionIndex = 1, #unitActions do
		local unitAction = unitActions[actionIndex]
		local distance = mathSqrt(distanceSqCache[unitAction.unitID] or 0)
		local integrateFrame = computeShockwaveFrameAtDistance(distance)
		local cascadeT = targetFrames > 0 and mathMin(integrateFrame / targetFrames, 1) or 0
		local baseFrameOffset = mathFloor(cascadeT * shockwaveDuration + 0.5)
		unitAction[offsetField] = allowKillVariance and getKillVarianceFrames(baseFrameOffset, cascadeT) or baseFrameOffset
	end
end

local function assignCookoffCascadeOffsets(unitActions, cascadeDuration)
	local actionCount = #unitActions
	if actionCount == 0 then
		return
	end

	local powerByUnit = {}
	local distanceSqByUnit = {}
	local maxDistanceSq = 0
	for actionIndex = 1, actionCount do
		local unitID = unitActions[actionIndex].unitID
		local unitDefID = spGetUnitDefID(unitID)
		powerByUnit[unitID] = defData[unitDefID].power or 0
		local distanceSq = distanceSqCache[unitID] or 0
		distanceSqByUnit[unitID] = distanceSq
		if distanceSq > maxDistanceSq then
			maxDistanceSq = distanceSq
		end
	end

	if actionCount > 1 then
		table.sort(unitActions, function(actionA, actionB)
			local unitIDA = actionA.unitID
			local unitIDB = actionB.unitID
			local powerA = powerByUnit[unitIDA]
			local powerB = powerByUnit[unitIDB]
			if powerA ~= powerB then
				return powerA < powerB
			end
			local distanceSqA = distanceSqByUnit[unitIDA]
			local distanceSqB = distanceSqByUnit[unitIDB]
			if distanceSqA ~= distanceSqB then
				return distanceSqA < distanceSqB
			end
			return unitIDA < unitIDB
		end)
	end

	for actionIndex = 1, actionCount do
		local unitAction = unitActions[actionIndex]
		local unitID = unitAction.unitID
		local rankT = actionCount > 1 and (actionIndex - 1) / (actionCount - 1) or 1
		local cascadeT = timeFromCookoffRankT(rankT)
		local baseFrameOffset = mathFloor(cascadeT * cascadeDuration + 0.5)
		local normalizedDistanceT = maxDistanceSq > 0 and distanceSqByUnit[unitID] / maxDistanceSq or 0
		local distanceJitter = mathFloor(COOKOFF_DISTANCE_JITTER_FRAMES * normalizedDistanceT + 0.5)
		local frameOffset = mathMin(cascadeDuration, baseFrameOffset + distanceJitter)
		unitAction.frameOffset = mathMax(0, frameOffset)
	end
end

local function getHeapArcOffset(killOffset)
	return mathMax(killOffset, HEAP_ARC_BURST + mathRandom(0, MAX_RANDOM_KILL_FRAMES))
end

local function queueHeapAction(frame, entry, isHeap)
	local frameActions = heapActionFrames[frame]
	if not frameActions then
		frameActions = {}
		heapActionFrames[frame] = frameActions
	end
	frameActions[#frameActions + 1] = { entry = entry, isHeap = isHeap }
end

local function scheduleEraseArc(unitID, originX, originY, originZ, arcFrame, targetX, targetY, targetZ)
	local entry = {
		unitID = unitID,
		originX = originX,
		originY = originY,
		originZ = originZ,
		targetX = targetX,
		targetY = targetY,
		targetZ = targetZ,
	}
	queueHeapAction(arcFrame, entry, false)
end

local function scheduleHeapConversion(unitID, originX, originY, originZ, arcFrame, heapFrame)
	local data = defData[spGetUnitDefID(unitID)]
	if not data.heap then
		return
	end
	local targetX, targetY, targetZ = getUnitArcTargetPosition(unitID)
	local entry = {
		unitID = unitID,
		corpseDefID = data.corpseDefID,
		heapExplosionCeg = HEAP_EXPLOSION_CEGS[data.cookoffSize],
		heapDefID = data.heap,
		originX = originX,
		originY = originY,
		originZ = originZ,
		targetX = targetX,
		targetY = targetY,
		targetZ = targetZ,
		beyondShockwaveReach = isBeyondShockwaveReach(unitID),
	}
	pendingHeapByUnitID[unitID] = entry
	if not entry.beyondShockwaveReach then
		queueHeapAction(arcFrame, entry, false)
	end
	queueHeapAction(heapFrame, entry, true)
end

local function scheduleEvents(startFrame, originX, originZ, allUnitActions, cookoffUnitActions, allyTeamID)
	local maxDistanceSq = getMaxDistanceSqFromUnitActions(allUnitActions)
	local maxDistance = mathSqrt(maxDistanceSq)
	local shockwaveProfile = buildShockwaveProfile(maxDistance)
	local shockwaveFramesToFarthestUnit = shockwaveProfile.targetFrames
	Spring.Echo("Desolate shockwave: maxDistance=" .. mathFloor(maxDistance + 0.5) .. " speed=" .. SHOCKWAVE_SPEED_ELMOS_PER_SEC .. " elmos/s targetFrames=" .. shockwaveFramesToFarthestUnit)
	local cookoffEndOffset = COOKOFF_DURATION_FRAMES + COOKOFF_CEG_DURATION_FRAMES + HEAP_ARC_DELAY_FRAMES
	local sequenceEndOffset = mathMax(HEAP_ARC_BURST + MAX_RANDOM_KILL_FRAMES + HEAP_ARC_DELAY_FRAMES, cookoffEndOffset)

	suspendViolence(true, sequenceEndOffset)

	local existingOrigin = allyTeamOrigins[allyTeamID]
	local originY = existingOrigin and existingOrigin.y or spGetGroundHeight(originX, originZ)
	local implosionOriginY = originY + TENEBRIUM_IMPLOSION_Y_OFFSET
	allyTeamOrigins[allyTeamID] = { x = originX, y = originY, z = originZ }

	if not implosionSpawnedAllyTeams[allyTeamID] then
		implosionSpawnedAllyTeams[allyTeamID] = true
		spSpawnCEG(TENEBRIUM_IMPLOSION_CEG, originX, implosionOriginY, originZ)
	end

	local cookoffStartFrameByUnit = {}

	local nonCookoffActions = {}
	for actionIndex = 1, #allUnitActions do
		local unitAction = allUnitActions[actionIndex]
		if not cookoffEligibleUnitIDs[unitAction.unitID] or unitAction.fate == DESOLATE_GAIA then
			nonCookoffActions[#nonCookoffActions + 1] = unitAction
		end
	end

	assignShockwaveOffsets(nonCookoffActions, shockwaveFramesToFarthestUnit, shockwaveProfile, true, "frameOffset")
	assignBeyondReachRandomOffsets(nonCookoffActions, shockwaveFramesToFarthestUnit, "frameOffset")
	for actionIndex = 1, #allUnitActions do
		local unitAction = allUnitActions[actionIndex]
		if cookoffEligibleUnitIDs[unitAction.unitID] and unitAction.fate ~= DESOLATE_GAIA then
			cookoffStartFrameByUnit[unitAction.unitID] = startFrame
		else
			queueDesolationAction(unitAction.unitID, unitAction.fate, startFrame + unitAction.frameOffset)
			if unitAction.fate == DESOLATE_ERASE and not isBeyondShockwaveReach(unitAction.unitID) and mathRandom() <= RANDOM_ARC_CHANCE then
				local targetX, targetY, targetZ = getUnitArcTargetPosition(unitAction.unitID)
				if targetX then
					scheduleEraseArc(unitAction.unitID, originX, implosionOriginY, originZ, startFrame + unitAction.frameOffset, targetX, targetY, targetZ)
				end
			end
		end
	end

	local heapUnitActions = {}
	for actionIndex = 1, #nonCookoffActions do
		local unitAction = nonCookoffActions[actionIndex]
		if unitAction.fate == DESOLATE_HEAP then
			unitAction.heapKillOffset = unitAction.frameOffset
			heapUnitActions[#heapUnitActions + 1] = unitAction
		end
	end
	for actionIndex = 1, #heapUnitActions do
		local unitAction = heapUnitActions[actionIndex]
		local arcFrame = startFrame + getHeapArcOffset(unitAction.heapKillOffset)
		scheduleHeapConversion(unitAction.unitID, originX, implosionOriginY, originZ, arcFrame, arcFrame + HEAP_ARC_DELAY_FRAMES)
	end

	assignCookoffCascadeOffsets(cookoffUnitActions, COOKOFF_DURATION_FRAMES)
	local cookoffHeapUnitActions = {}
	for actionIndex = 1, #cookoffUnitActions do
		local unitAction = cookoffUnitActions[actionIndex]
		local killFrame = startFrame + unitAction.frameOffset
		local cookoffStartFrame = cookoffStartFrameByUnit[unitAction.unitID]
		if cookoffStartFrame then
			queueCookoffBurst(unitAction.unitID, cookoffStartFrame)
		end
		queueDesolationAction(unitAction.unitID, unitAction.fate, killFrame)
		if unitAction.fate == DESOLATE_ERASE and not isBeyondShockwaveReach(unitAction.unitID) and mathRandom() <= RANDOM_ARC_CHANCE then
			local targetX, targetY, targetZ = getUnitArcTargetPosition(unitAction.unitID)
			if targetX then
				scheduleEraseArc(unitAction.unitID, originX, implosionOriginY, originZ, killFrame, targetX, targetY, targetZ)
			end
		elseif unitAction.fate == DESOLATE_HEAP then
			unitAction.heapKillOffset = unitAction.frameOffset
			cookoffHeapUnitActions[#cookoffHeapUnitActions + 1] = unitAction
		end
	end
	for actionIndex = 1, #cookoffHeapUnitActions do
		local unitAction = cookoffHeapUnitActions[actionIndex]
		local arcFrame = startFrame + getHeapArcOffset(unitAction.heapKillOffset)
		scheduleHeapConversion(unitAction.unitID, originX, implosionOriginY, originZ, arcFrame, arcFrame + HEAP_ARC_DELAY_FRAMES)
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

local function buildCookoffEligibleUnitIDs(teamUnits)
	for unitID in pairs(cookoffEligibleUnitIDs) do
		cookoffEligibleUnitIDs[unitID] = nil
	end
	local teamUnitCount = #teamUnits
	if teamUnitCount == 0 or COOKOFF_TOP_UNIT_FRACTION <= 0 then
		return 0
	end
	local powerSortedUnits = sortUnitsByPower(teamUnits)
	local cookoffCount = mathCeil(teamUnitCount * COOKOFF_TOP_UNIT_FRACTION)
	cookoffCount = mathMin(cookoffCount, teamUnitCount)
	for unitIndex = 1, cookoffCount do
		cookoffEligibleUnitIDs[powerSortedUnits[unitIndex]] = true
	end
	return cookoffCount
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
	local cookoffTargetCount = buildCookoffEligibleUnitIDs(teamUnits)
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

	for eraseIndex = 1, #teamUnits do
		if currentPower <= erasurePowerTargetThreshold or #teamUnits == 0 then
			break
		end
		local randomSelection = dndStyleDisadvantageBias(#teamUnits, 2)
		local unitID = teamUnits[randomSelection]
		local unitPower = defData[spGetUnitDefID(unitID)].power or 0
		unitActions[#unitActions + 1] = { unitID = unitID, fate = DESOLATE_ERASE }
		currentPower = currentPower - unitPower
		removeEntrySwap(teamUnits, randomSelection)
	end

	for unitIndex = 1, #teamUnits do
		local unitID = teamUnits[unitIndex]
		local fate = chooseFate(unitID)
		unitActions[#unitActions + 1] = { unitID = unitID, fate = fate }
	end

	local cookoffUnitActions = {}
	for actionIndex = 1, #unitActions do
		local unitAction = unitActions[actionIndex]
		if cookoffEligibleUnitIDs[unitAction.unitID] and unitAction.fate ~= DESOLATE_GAIA then
			cookoffUnitActions[#cookoffUnitActions + 1] = unitAction
		end
	end

	local cookoffCount = #cookoffUnitActions
	local nonCookoffCount = #unitActions - cookoffCount
	Spring.Echo("Desolate: " .. cookoffCount .. " units cooking off (" .. cookoffTargetCount .. " targeted), " .. nonCookoffCount .. " units not cooking off")

	scheduleEvents(currentFrame, originX, originZ, unitActions, cookoffUnitActions, allyTeamID)
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
		local originX, originY, originZ = spGetUnitPosition(unitID)
		if originX then
			local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(unitTeam)
			allyTeamOrigins[allyTeamID] = { x = originX, y = originY, z = originZ }
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
			local cegAction = scheduledCegActions[actionIndex]
			if spValidUnitID(cegAction.unitID) then
				local unitX, unitY, unitZ = spGetUnitPosition(cegAction.unitID)
				if unitX then
					spSpawnCEG(cegAction.cegName, unitX, unitY, unitZ)
				end
			end
		end
	end
	local frameActions = actionFrames[gameFrame]
	if frameActions then
		actionFrames[gameFrame] = nil
		for actionIndex = 1, #frameActions do
			local action = frameActions[actionIndex]
			desolateUnit(action.unitID, action.fate)
		end
	end
	local scheduledHeapActions = heapActionFrames[gameFrame]
	if scheduledHeapActions then
		heapActionFrames[gameFrame] = nil
		for actionIndex = 1, #scheduledHeapActions do
			local heapAction = scheduledHeapActions[actionIndex]
			local entry = heapAction.entry
			local targetX, targetY, targetZ = resolveHeapTargetPosition(entry)
			if targetX then
				if heapAction.isHeap then
					if entry.beyondShockwaveReach then
						spawnCorpseExplosionCeg(entry.heapExplosionCeg, targetX, targetY, targetZ)
					end
					local featureID = entry.featureID
					if featureID and spValidFeatureID(featureID) then
						spDestroyFeature(featureID)
					end
					if entry.heapDefID then
						spCreateFeature(entry.heapDefID, targetX, targetY, targetZ, 0, entry.unitTeam)
					end
					pendingHeapByUnitID[entry.unitID] = nil
				else
					spawnHeapLightning(entry, targetX, targetY, targetZ)
				end
			elseif heapAction.isHeap then
				pendingHeapByUnitID[entry.unitID] = nil
			end
		end
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