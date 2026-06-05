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

-- cascade and kill timing spread
-- Cubic ease-out wave expansion; kill time uses the inverse curve on normalized radius. Higher = faster core burst, slower rim (3= strong ease).
local EXPLOSION_CUBIC_EASE_BIAS = 3

-- cookoff sequence (top COOKOFF_TOP_UNIT_FRACTION by power survive the first cascade, cook off, then die in the second cascade)
-- Length of one desolation_cookoff CEG playthrough in frames; must match COOKOFF_DELAY_WINDOW in effects/desolation_cookoff.lua (30 = ~1s at 30fps).
local COOKOFF_DURATION_FRAMES = 30
-- Fraction of alive team units (by count, sorted by power) that cook off through the first cascade instead of dying in it: 0.2 = top 20% strongest at desolation start.
local COOKOFF_TOP_UNIT_FRACTION = 0.2
-- Frames over which the second cascade kills the cooking-off units; sorted by distance with power bias (higher = stronger units die later in the wave).
local COOKOFF_CASCADE_DURATION = 300
-- Cookoff sort: multiplies distance² by (1 + COOKOFF_POWER_BIAS * normalizedPower) so high-power units skew later in the cookoff kill wave.
local COOKOFF_POWER_BIAS = 2

local CASCADE_DURATION = 150
local MAX_RANDOM_KILL_FRAMES = 30
local SECOND_CASCADE_START_OFFSET = CASCADE_DURATION + MAX_RANDOM_KILL_FRAMES
local EXPLOSION_SEQUENCE_END_OFFSET = SECOND_CASCADE_START_OFFSET + COOKOFF_CASCADE_DURATION + COOKOFF_DURATION_FRAMES
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

local spSpawnExplosion = Spring.SpawnExplosion
local spCreateFeature = Spring.CreateFeature
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spDestroyUnit = Spring.DestroyUnit
local spGetTeamUnits = Spring.GetTeamUnits
local spTransferUnit = Spring.TransferUnit
local spValidUnitID = Spring.ValidUnitID
local spSpawnCEG = Spring.SpawnCEG
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetAllUnits = Spring.GetAllUnits
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
local allyTeamOrigins = {}
local desolatedTeams = {}
local distanceSqCache = {}
local cookoffEligibleUnitIDs = {}
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

local function cascadeTimeFromRadiusT(radiusT)
	return 1 - (1 - radiusT) ^ (1 / EXPLOSION_CUBIC_EASE_BIAS)
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

local function getCookoffWeightedDistanceSq(unitID, minPower, maxPower)
	local distanceSq = distanceSqCache[unitID] or 0
	if COOKOFF_POWER_BIAS <= 0 or maxPower <= minPower then
		return distanceSq
	end
	local unitPower = defData[spGetUnitDefID(unitID)].power or 0
	local powerT = (unitPower - minPower) / (maxPower - minPower)
	return distanceSq * (1 + COOKOFF_POWER_BIAS * powerT)
end

local function getSortDistanceSq(unitID, minPower, maxPower, useCookoffWeighting)
	if useCookoffWeighting then
		return getCookoffWeightedDistanceSq(unitID, minPower, maxPower)
	end
	return distanceSqCache[unitID] or 0
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

local function queueRepeatingCookoffs(unitID, startFrame, killFrame)
	local cookoffFrame = startFrame
	while cookoffFrame < killFrame do
		queueCookoff(unitID, cookoffFrame)
		cookoffFrame = cookoffFrame + COOKOFF_DURATION_FRAMES
	end
end

local function assignCascadeOffsets(unitActions, cascadeDuration, minPower, maxPower, useCookoffWeighting, allowKillVariance, offsetField)
	local actionCount = #unitActions
	if actionCount == 0 then
		return
	end

	if actionCount > 1 then
		table.sort(unitActions, function(actionA, actionB)
			return getSortDistanceSq(actionA.unitID, minPower, maxPower, useCookoffWeighting)
				< getSortDistanceSq(actionB.unitID, minPower, maxPower, useCookoffWeighting)
		end)
	end

	local maxSortDistanceSq = 0
	for actionIndex = 1, actionCount do
		local sortDistanceSq = getSortDistanceSq(unitActions[actionIndex].unitID, minPower, maxPower, useCookoffWeighting)
		if sortDistanceSq > maxSortDistanceSq then
			maxSortDistanceSq = sortDistanceSq
		end
	end

	for actionIndex = 1, actionCount do
		local unitAction = unitActions[actionIndex]
		local sortDistanceSq = getSortDistanceSq(unitAction.unitID, minPower, maxPower, useCookoffWeighting)
		local radiusT = maxSortDistanceSq > 0 and mathSqrt(sortDistanceSq / maxSortDistanceSq) or 0
		local cascadeT = cascadeTimeFromRadiusT(radiusT)
		local baseFrameOffset = mathFloor(cascadeT * cascadeDuration + 0.5)
		unitAction[offsetField] = allowKillVariance and getKillVarianceFrames(baseFrameOffset, cascadeT) or baseFrameOffset
	end
end

local function scheduleEvents(startFrame, originX, originZ, allUnitActions, cookoffUnitActions, minPower, maxPower, allyTeamID)
	suspendViolence(true)

	allyTeamOrigins[allyTeamID] = { x = originX, z = originZ }

	local cookoffStartFrameByUnit = {}

	local nonCookoffActions = {}
	for actionIndex = 1, #allUnitActions do
		local unitAction = allUnitActions[actionIndex]
		if not (cookoffEligibleUnitIDs[unitAction.unitID]
			and unitAction.fate ~= DESOLATE_GAIA
			and unitAction.fate ~= DESOLATE_ERASE) then
			nonCookoffActions[#nonCookoffActions + 1] = unitAction
		end
	end

	assignCascadeOffsets(allUnitActions, CASCADE_DURATION, minPower, maxPower, false, false, "cookoffStartOffset")
	assignCascadeOffsets(nonCookoffActions, CASCADE_DURATION, minPower, maxPower, false, true, "frameOffset")
	for actionIndex = 1, #allUnitActions do
		local unitAction = allUnitActions[actionIndex]
		if cookoffEligibleUnitIDs[unitAction.unitID]
			and unitAction.fate ~= DESOLATE_GAIA
			and unitAction.fate ~= DESOLATE_ERASE then
			cookoffStartFrameByUnit[unitAction.unitID] = startFrame + unitAction.cookoffStartOffset
		else
			queueDesolationAction(unitAction.unitID, unitAction.fate, startFrame + unitAction.frameOffset)
		end
	end

	assignCascadeOffsets(cookoffUnitActions, COOKOFF_CASCADE_DURATION, minPower, maxPower, true, false, "frameOffset")
	for actionIndex = 1, #cookoffUnitActions do
		local unitAction = cookoffUnitActions[actionIndex]
		local killFrame = startFrame + SECOND_CASCADE_START_OFFSET + unitAction.frameOffset
		local cookoffStartFrame = cookoffStartFrameByUnit[unitAction.unitID]
		if cookoffStartFrame then
			queueRepeatingCookoffs(unitAction.unitID, cookoffStartFrame, killFrame)
		end
		queueDesolationAction(unitAction.unitID, unitAction.fate, killFrame)
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
		return
	end
	local powerSortedUnits = sortUnitsByPower(teamUnits)
	local cookoffCount = mathCeil(teamUnitCount * COOKOFF_TOP_UNIT_FRACTION)
	for unitIndex = 1, cookoffCount do
		cookoffEligibleUnitIDs[powerSortedUnits[unitIndex]] = true
	end
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
	buildCookoffEligibleUnitIDs(teamUnits)
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

	local cookoffUnitActions = {}
	for actionIndex = 1, #unitActions do
		local unitAction = unitActions[actionIndex]
		if cookoffEligibleUnitIDs[unitAction.unitID]
			and unitAction.fate ~= DESOLATE_GAIA
			and unitAction.fate ~= DESOLATE_ERASE then
			cookoffUnitActions[#cookoffUnitActions + 1] = unitAction
		end
	end

	scheduleEvents(currentFrame, originX, originZ, unitActions, cookoffUnitActions, minPower, maxPower, allyTeamID)
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
			allyTeamOrigins[allyTeamID] = { x = originX, z = originZ }
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