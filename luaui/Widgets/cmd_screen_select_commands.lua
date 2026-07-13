local widget = widget ---@type RulesUnsyncedCallins

function widget:GetInfo()
	return {
		name = "Screen Select Commands",
		desc = "Mass-issue unit-target commands to all visible on-screen matches. Click again while pending, or use the keybind + click for mass orders.",
		author = "SethDGamre, advised by Chronographer",
		date = "July 11, 2026",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

--[[------------------------------------------------------------------------------
How To Use:
  First click issues a normal order. Another click while pending mass-orders all on-screen matches.
  Optionally, bind and hold screen_select_hold to mass-order on the first click instead.

Click modifiers:
  Shift -> add to end of queue
  Space -> prepend to the queue
  Shift + Space -> insert into the nearest queued path segment
  Ctrl -> expand scope to all visible same-alignment targets (enemies: any enemy team; allies: any ally team). For reclaim features, broaden by yield (metal vs energy-only).
  Alt -> distribute evenly among selected units
  If units × targets would exceed COMMAND_LIMIT, auto-partition and shrink per-unit assignments to fit the budget. maxMassOrderTargets is the max targets each unit may receive. If more targets exist than the budget, the selection radius shrinks from MASS_ORDER_START_RADIUS by MASS_ORDER_RADIUS_STEP until the count fits.

  Command-Specific behavior:
  Capture -> only finished, capturable targets; only capturers issue
  Repair -> only damaged targets; scopes to clicked unit's team (not all allies); Ctrl = any damaged unit on that team
  Reclaim -> enemies, allies, and features; reclaiming another ally's unit is single-target only (no mass spread); features match wreck category (corpse/heap/metal/energy-only); Ctrl broadens feature matches by yield
  Resurrect -> Corpses only, must be resurrectable; Ctrl = all visible resurrectable wrecks
  Set Target -> Alt isn't used here, it's left for another widget that handles persistent target type setting as of 7/12/26

  There's a filter also. If you screen-command selected units, it will include selected units only.
  If you screen-command an external unit, it will exclude the selected units.
--]]------------------------------------------------------------------------------

local tableInsert = table.insert
local tableSort = table.sort
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathAtan2 = math.atan2

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefId = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetFeatureDefId = Spring.GetFeatureDefID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamId = Spring.GetMyAllyTeamID
local spGetMyTeamId = Spring.GetMyTeamID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitArrayCentroid = Spring.GetUnitArrayCentroid
local spGetFeatureResurrect = Spring.GetFeatureResurrect
local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetVisibleFeatures = Spring.GetVisibleFeatures
local spGetActiveCommand = Spring.GetActiveCommand
local spSetActiveCommand = Spring.SetActiveCommand
local spGetModKeyState = Spring.GetModKeyState
local spGetCommandDescriptionIndex = Spring.GetCmdDescIndex
local spValidFeatureId = Spring.ValidFeatureID
local spValidUnitId = Spring.ValidUnitID
local spGetFeatureResources = Spring.GetFeatureResources
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitHealth = Spring.GetUnitHealth
local spTraceScreenRay = Spring.TraceScreenRay

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local FEATURE = "feature"
local UNIT = "unit"
local POSITIONAL_TARGET_COMMANDS = {
	[CMD.ATTACK] = true,
	[CMD.CAPTURE] = true,
	[CMD.DGUN] = true,
	[CMD.GUARD] = true,
	[CMD.REPAIR] = true,
	[CMD.RECLAIM] = true,
	[CMD.RESURRECT] = true,
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}
local COMMAND_CAPABILITY_FIELDS = {
	[CMD.RECLAIM] = { "canReclaim", "reclaimSpeed" },
	[CMD.RESURRECT] = { "canResurrect", "resurrectSpeed" },
	[CMD.REPAIR] = { "canRepair", "repairSpeed" },
	[CMD.CAPTURE] = { "canCapture", "captureSpeed" },
}

local MAX_QUEUE_COMMANDS = 100
local MASS_ORDER_START_RADIUS = 2000
local MASS_ORDER_RADIUS_STEP = 500
local DOUBLE_CLICK_TIME = Spring.GetConfigInt("DoubleClickTime", 200) / 1000
local MIN_DOUBLE_CLICK_GAP = 0.03
local osClock = os.clock

local doubleClickEnabled = true
local maxMassOrderTargets = 150
local commandLimit = 4000

local myAllyTeamId
local myTeamId
local pendingDoubleClick = {
	targetId = nil,
	expireTime = 0,
	commandId = nil,
	alt = false,
	ctrl = false,
	meta = false,
	shift = false,
	right = false,
	firstClickTime = 0,
}
local heldCommandDescriptionIndex
local deferClearActiveCommand = false
local screenSelectHeld = false

local function enrichCommandOptions(options)
	options = options or {}
	local modifierAlt, modifierControl, modifierMeta, modifierShift = spGetModKeyState()
	return {
		alt = options.alt or modifierAlt,
		ctrl = options.ctrl or modifierControl,
		meta = options.meta or modifierMeta,
		shift = options.shift or modifierShift,
		right = options.right or false,
	}
end

local function distanceSq(position1, position2)
	local deltaX = position1.x - position2.x
	local deltaZ = position1.z - position2.z
	return deltaX * deltaX + deltaZ * deltaZ
end

local function toPositionTable(x, y, z)
	if not x then
		return nil
	end
	return { x = x, y = y, z = z }
end

local function restoreActiveCommand(commandDescriptionIndex)
	local modifierAlt, modifierControl, modifierMeta, modifierShift = spGetModKeyState()
	spSetActiveCommand(commandDescriptionIndex, 1, true, false, modifierAlt, modifierControl, modifierMeta, modifierShift)
end

local function updateShiftCommandKeep()
	local _, _, _, modifierShift = spGetModKeyState()
	if modifierShift and heldCommandDescriptionIndex then
		local _, activeCommandId = spGetActiveCommand()
		if not activeCommandId then
			restoreActiveCommand(heldCommandDescriptionIndex)
		end
	elseif not modifierShift then
		heldCommandDescriptionIndex = nil
	end
end

local function clearDoubleClickPending()
	pendingDoubleClick.targetId = nil
	pendingDoubleClick.expireTime = 0
	pendingDoubleClick.commandId = nil
	pendingDoubleClick.alt = false
	pendingDoubleClick.ctrl = false
	pendingDoubleClick.meta = false
	pendingDoubleClick.shift = false
	pendingDoubleClick.right = false
	pendingDoubleClick.firstClickTime = 0
end

local function isPendingDoubleClickActive()
	return pendingDoubleClick.targetId ~= nil
		and pendingDoubleClick.commandId ~= nil
		and osClock() < pendingDoubleClick.expireTime
end

local function isFeatureTargetId(targetId)
	if Engine.FeatureSupport.noOffsetForFeatureID then
		return spValidFeatureId(targetId) and not spValidUnitId(targetId)
	end
	if targetId >= Game.maxUnits then
		return spValidFeatureId(targetId - Game.maxUnits)
	end
	if spValidFeatureId(targetId) and not spValidUnitId(targetId) then
		return true
	end
	return false
end

local function getRawFeatureId(targetId)
	if Engine.FeatureSupport.noOffsetForFeatureID then
		return targetId
	end
	if targetId >= Game.maxUnits then
		return targetId - Game.maxUnits
	end
	return targetId
end

local function normalizeFeatureTargetId(featureId)
	if Engine.FeatureSupport.noOffsetForFeatureID then
		return featureId
	end
	return featureId + Game.maxUnits
end

local function toFeatureOrderParamId(targetId)
	if not isFeatureTargetId(targetId) then
		return targetId
	end
	if Engine.FeatureSupport.noOffsetForFeatureID then
		return getRawFeatureId(targetId)
	end
	if targetId >= Game.maxUnits then
		return targetId
	end
	return targetId + Game.maxUnits
end

local function filterUnitsForCommand(selectedUnits, commandId)
	local capabilityFields = COMMAND_CAPABILITY_FIELDS[commandId]
	if not capabilityFields then
		return selectedUnits
	end
	local filteredUnits = {}
	for unitIndex = 1, #selectedUnits do
		local unitId = selectedUnits[unitIndex]
		local unitDefId = spGetUnitDefId(unitId)
		local unitDef = unitDefId and UnitDefs[unitDefId]
		if unitDef and unitDef[capabilityFields[1]] and unitDef[capabilityFields[2]] > 0 then
			tableInsert(filteredUnits, unitId)
		end
	end
	return filteredUnits
end

local function isCapturableTargetUnit(unitId)
	local unitDefId = spGetUnitDefId(unitId)
	if not unitDefId then
		return false
	end
	local unitDef = UnitDefs[unitDefId]
	if not unitDef or not unitDef.capturable then
		return false
	end
	if spGetUnitIsBeingBuilt(unitId) then
		return false
	end
	return true
end

local function isRepairableTargetUnit(unitId)
	if spGetUnitIsBeingBuilt(unitId) then
		return false
	end
	local health, maxHealth = spGetUnitHealth(unitId)
	if not health or not maxHealth then
		return false
	end
	return health < maxHealth
end

local function filterTargetsByPredicate(targets, predicate)
	local filteredTargets = {}
	for targetIndex = 1, #targets do
		local unitId = targets[targetIndex]
		if predicate(unitId) then
			tableInsert(filteredTargets, unitId)
		end
	end
	return filteredTargets
end

local function finalizeUnitTargets(commandId, targets)
	if commandId == CMD.CAPTURE then
		return filterTargetsByPredicate(targets, isCapturableTargetUnit)
	end
	if commandId == CMD.REPAIR then
		return filterTargetsByPredicate(targets, isRepairableTargetUnit)
	end
	return targets
end

local function getTargetPosition(targetId, positionCache)
	if positionCache and positionCache[targetId] ~= nil then
		return positionCache[targetId] or nil
	end
	local position
	if isFeatureTargetId(targetId) then
		local x, y, z = spGetFeaturePosition(getRawFeatureId(targetId))
		if x then
			position = toPositionTable(x, y, z)
		end
	else
		local x, y, z = spGetUnitPosition(targetId)
		if x then
			position = toPositionTable(x, y, z)
		end
	end
	if positionCache then
		positionCache[targetId] = position or false
	end
	return position
end

local function getUnitCentroid(selectedUnits)
	local x, y, z = spGetUnitArrayCentroid(selectedUnits)
	return toPositionTable(x, y, z)
end

local function getTargetCentroid(targets, positionCache)
	local totalX = 0
	local totalY = 0
	local totalZ = 0
	local positionCount = 0
	for targetIndex = 1, #targets do
		local position = getTargetPosition(targets[targetIndex], positionCache)
		if position then
			totalX = totalX + position.x
			totalY = totalY + position.y
			totalZ = totalZ + position.z
			positionCount = positionCount + 1
		end
	end
	if positionCount == 0 then
		return nil
	end
	return toPositionTable(totalX / positionCount, totalY / positionCount, totalZ / positionCount)
end

local function sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst, referenceUnitId, positionCache)
	positionCache = positionCache or {}
	local referencePosition = referenceUnitId and getTargetPosition(referenceUnitId, positionCache)
		or getUnitCentroid(selectedUnits)
	if not referencePosition then
		return
	end
	local targetDistances = {}
	local originalIndices = {}
	for targetIndex = 1, #filteredTargets do
		local targetId = filteredTargets[targetIndex]
		local targetPosition = getTargetPosition(targetId, positionCache)
		targetDistances[targetId] = targetPosition and distanceSq(referencePosition, targetPosition) or false
		originalIndices[targetId] = targetIndex
	end
	tableSort(filteredTargets, function(targetIdA, targetIdB)
		local distanceA = targetDistances[targetIdA]
		local distanceB = targetDistances[targetIdB]
		if distanceA == false or distanceB == false then
			if distanceA == distanceB then
				return originalIndices[targetIdA] < originalIndices[targetIdB]
			end
			return distanceA ~= false
		end
		if distanceA == distanceB then
			return originalIndices[targetIdA] < originalIndices[targetIdB]
		end
		if closestFirst then
			return distanceA < distanceB
		end
		return distanceA > distanceB
	end)
end

local function buildNearestNeighborRoute(referencePosition, targets, positionCache)
	local targetPositions = {}
	local remainingTargets = {}
	local route = {}
	for targetIndex = 1, #targets do
		local targetId = targets[targetIndex]
		local targetPosition = getTargetPosition(targetId, positionCache)
		targetPositions[targetId] = targetPosition or false
		remainingTargets[targetIndex] = targetId
	end
	local currentPosition = referencePosition
	local routeCount = 0
	while #remainingTargets > 0 do
		local nearestIndex
		local nearestDistance
		for targetIndex = 1, #remainingTargets do
			local targetId = remainingTargets[targetIndex]
			local targetPosition = targetPositions[targetId]
			if targetPosition then
				local targetDistance = distanceSq(currentPosition, targetPosition)
				if nearestDistance == nil or targetDistance < nearestDistance then
					nearestIndex = targetIndex
					nearestDistance = targetDistance
				end
			end
		end
		if not nearestIndex then
			for targetIndex = 1, #remainingTargets do
				routeCount = routeCount + 1
				route[routeCount] = remainingTargets[targetIndex]
			end
			break
		end
		local nearestTargetId = remainingTargets[nearestIndex]
		routeCount = routeCount + 1
		route[routeCount] = nearestTargetId
		currentPosition = targetPositions[nearestTargetId]
		remainingTargets[nearestIndex] = remainingTargets[#remainingTargets]
		remainingTargets[#remainingTargets] = nil
	end
	return route
end

local function sortTargetsByTravelRoute(referenceUnitId, targets, closestFirst, positionCache)
	local referencePosition = getTargetPosition(referenceUnitId, positionCache)
	if not referencePosition then
		return
	end
	local hasTargetPosition = false
	for targetIndex = 1, #targets do
		if getTargetPosition(targets[targetIndex], positionCache) then
			hasTargetPosition = true
			break
		end
	end
	if not hasTargetPosition then
		return
	end
	local route = buildNearestNeighborRoute(referencePosition, targets, positionCache)
	if closestFirst then
		for targetIndex = 1, #route do
			targets[targetIndex] = route[targetIndex]
		end
	else
		local targetCount = #route
		for targetIndex = 1, targetCount do
			targets[targetIndex] = route[targetCount - targetIndex + 1]
		end
	end
end

local function limitTargetsByRadius(filteredTargets, referenceTargetId, selectedUnits, maximumTargetCount)
	if maximumTargetCount <= 0 then
		return {}
	end
	if #filteredTargets == 0 then
		return filteredTargets
	end
	local positionCache = {}
	local referencePosition = getTargetPosition(referenceTargetId, positionCache)
	if not referencePosition then
		sortTargetsByDistance(selectedUnits, filteredTargets, true, nil, positionCache)
		local cappedTargets = {}
		local cappedCount = maximumTargetCount
		if cappedCount > #filteredTargets then
			cappedCount = #filteredTargets
		end
		for targetIndex = 1, cappedCount do
			cappedTargets[targetIndex] = filteredTargets[targetIndex]
		end
		return cappedTargets
	end
	sortTargetsByDistance({ referenceTargetId }, filteredTargets, true, referenceTargetId, positionCache)
	local radius
	while true do
		local limitedTargets = {}
		if radius == nil then
			for targetIndex = 1, #filteredTargets do
				limitedTargets[targetIndex] = filteredTargets[targetIndex]
			end
		else
			local radiusSq = radius * radius
			for targetIndex = 1, #filteredTargets do
				local targetId = filteredTargets[targetIndex]
				local targetPosition = getTargetPosition(targetId, positionCache)
				if targetPosition and distanceSq(referencePosition, targetPosition) <= radiusSq then
					tableInsert(limitedTargets, targetId)
				end
			end
		end
		if #limitedTargets <= maximumTargetCount then
			return limitedTargets
		end
		if radius == nil then
			radius = MASS_ORDER_START_RADIUS
		elseif radius > 0 then
			radius = radius - MASS_ORDER_RADIUS_STEP
		else
			break
		end
	end
	local cappedTargets = {}
	for targetIndex = 1, maximumTargetCount do
		cappedTargets[targetIndex] = filteredTargets[targetIndex]
	end
	return cappedTargets
end

local function pointToSegmentDistanceSq(point, segmentStart, segmentEnd)
	local segmentX = segmentEnd.x - segmentStart.x
	local segmentZ = segmentEnd.z - segmentStart.z
	local segmentLengthSq = segmentX * segmentX + segmentZ * segmentZ
	if segmentLengthSq == 0 then
		return distanceSq(point, segmentStart)
	end
	local projection = ((point.x - segmentStart.x) * segmentX + (point.z - segmentStart.z) * segmentZ) / segmentLengthSq
	if projection < 0 then
		projection = 0
	elseif projection > 1 then
		projection = 1
	end
	local nearestX = segmentStart.x + projection * segmentX
	local nearestZ = segmentStart.z + projection * segmentZ
	local deltaX = point.x - nearestX
	local deltaZ = point.z - nearestZ
	return deltaX * deltaX + deltaZ * deltaZ
end

local function getQueuedCommandPosition(command, positionCache)
	local parameters = command.params
	if not parameters then
		return nil
	end
	if #parameters == 1 and POSITIONAL_TARGET_COMMANDS[command.id] and type(parameters[1]) == "number" then
		return getTargetPosition(parameters[1], positionCache)
	end
	if #parameters >= 3
		and type(parameters[1]) == "number"
		and type(parameters[2]) == "number"
		and type(parameters[3]) == "number"
	then
		return toPositionTable(parameters[1], parameters[2], parameters[3])
	end
	return nil
end

local function findQueueInsertionPosition(unitId, targetCentroid, positionCache)
	local unitPosition = getTargetPosition(unitId, positionCache)
	if not unitPosition or not targetCentroid then
		return nil
	end
	local commandQueue = spGetUnitCommands(unitId, MAX_QUEUE_COMMANDS)
	if not commandQueue or #commandQueue == 0 then
		return nil
	end
	local previousPosition = unitPosition
	local nearestDistance
	local insertionPosition
	for commandIndex = 1, #commandQueue do
		local commandPosition = getQueuedCommandPosition(commandQueue[commandIndex], positionCache)
		if commandPosition then
			local commandDistance = pointToSegmentDistanceSq(targetCentroid, previousPosition, commandPosition)
			if nearestDistance == nil or commandDistance < nearestDistance then
				nearestDistance = commandDistance
				insertionPosition = commandIndex - 1
			end
			previousPosition = commandPosition
		end
	end
	return insertionPosition
end

local function getCommandOptionBits(options, includeShift)
	local optionBits = options.right and CMD.OPT_RIGHT or 0
	if includeShift then
		optionBits = optionBits + CMD.OPT_SHIFT
	end
	return optionBits
end

local function insertOrdersByQueueProximity(commandId, selectedUnits, filteredTargets, options)
	local positionCache = {}
	local targetCentroid = getTargetCentroid(filteredTargets, positionCache)
	local singleUnitArray = {}
	local queuedOptionBits = getCommandOptionBits(options, true)
	local innerOptionBits = getCommandOptionBits(options, false)
	for unitIndex = 1, #selectedUnits do
		local unitId = selectedUnits[unitIndex]
		singleUnitArray[1] = unitId
		local insertionPosition = findQueueInsertionPosition(unitId, targetCentroid, positionCache)
		if insertionPosition == nil then
			for targetIndex = 1, #filteredTargets do
				local targetId = filteredTargets[targetIndex]
				spGiveOrderToUnitArray(singleUnitArray, commandId, { toFeatureOrderParamId(targetId) }, queuedOptionBits)
			end
		else
			for targetIndex = #filteredTargets, 1, -1 do
				local targetId = filteredTargets[targetIndex]
				spGiveOrderToUnitArray(
					singleUnitArray,
					CMD.INSERT,
					{ insertionPosition, commandId, innerOptionBits, toFeatureOrderParamId(targetId) },
					CMD.OPT_ALT
				)
			end
		end
	end
end

local function giveOrders(commandId, selectedUnits, filteredTargets, options)
	if options.meta and options.shift then
		insertOrdersByQueueProximity(commandId, selectedUnits, filteredTargets, options)
		return
	end
	local baseOptionBits = getCommandOptionBits(options, false)
	local queuedOptionBits = getCommandOptionBits(options, true)
	for targetIndex = 1, #filteredTargets do
		local targetId = filteredTargets[targetIndex]
		if options.meta then
			spGiveOrderToUnitArray(
				selectedUnits,
				CMD.INSERT,
				{ 0, commandId, baseOptionBits, toFeatureOrderParamId(targetId) },
				CMD.OPT_ALT
			)
		else
			local includeShift = targetIndex > 1 or options.shift
			spGiveOrderToUnitArray(
				selectedUnits,
				commandId,
				{ toFeatureOrderParamId(targetId) },
				includeShift and queuedOptionBits or baseOptionBits
			)
		end
	end
end

local function divideWithRemainder(total, groupCount)
	local minimumCount = mathFloor(total / groupCount)
	local remainderCount = total % groupCount
	return minimumCount, remainderCount
end

local function pickClosestUnassigned(referenceId, candidates, unassigned, count, positionCache)
	local available = {}
	for candidateIndex = 1, #candidates do
		local candidateId = candidates[candidateIndex]
		if unassigned[candidateId] then
			tableInsert(available, candidateId)
		end
	end
	sortTargetsByDistance({ referenceId }, available, true, referenceId, positionCache)
	local picked = {}
	for pickedIndex = 1, count do
		local pickedId = available[pickedIndex]
		picked[pickedIndex] = pickedId
		unassigned[pickedId] = nil
	end
	return picked
end

local function sortIdsByAngle(ids, center, positionCache)
	local angles = {}
	local originalIndices = {}
	for idIndex = 1, #ids do
		local id = ids[idIndex]
		local position = getTargetPosition(id, positionCache)
		if position then
			angles[id] = mathAtan2(position.z - center.z, position.x - center.x)
		end
		originalIndices[id] = idIndex
	end
	tableSort(ids, function(idA, idB)
		local angleA = angles[idA]
		local angleB = angles[idB]
		if angleA == nil or angleB == nil then
			if angleA == angleB then
				return originalIndices[idA] < originalIndices[idB]
			end
			return angleA ~= nil
		end
		if angleA == angleB then
			return originalIndices[idA] < originalIndices[idB]
		end
		return angleA < angleB
	end)
end

local function buildContiguousChunks(sortedIds, chunkCount)
	local chunks = {}
	local minimumCount, remainderCount = divideWithRemainder(#sortedIds, chunkCount)
	local nextIndex = 1
	for chunkIndex = 1, chunkCount do
		local count = minimumCount
		if chunkIndex <= remainderCount then
			count = count + 1
		end
		local chunk = {}
		for itemIndex = 1, count do
			chunk[itemIndex] = sortedIds[nextIndex]
			nextIndex = nextIndex + 1
		end
		chunks[chunkIndex] = chunk
	end
	return chunks
end

local function resolvePartitionCenter(selectedUnits, filteredTargets, referenceTargetId, positionCache)
	local center = getUnitCentroid(selectedUnits)
	if center then
		return center
	end
	center = getTargetPosition(referenceTargetId, positionCache)
	if center then
		return center
	end
	return getTargetCentroid(filteredTargets, positionCache)
end

local function resolveMassOrderBudget(selectedUnitCount, availableTargetCount, forcePartition)
	local desiredPerUnit = maxMassOrderTargets
	local targetsPerUnit = mathMin(availableTargetCount, desiredPerUnit)
	local fullQueueCost = selectedUnitCount * targetsPerUnit
	local partition = forcePartition or fullQueueCost > commandLimit
	local perUnitLimit = desiredPerUnit
	if partition and fullQueueCost > commandLimit then
		perUnitLimit = mathFloor(commandLimit / selectedUnitCount)
	end
	local targetPoolLimit
	if partition then
		targetPoolLimit = mathMin(availableTargetCount, selectedUnitCount * perUnitLimit)
	else
		targetPoolLimit = targetsPerUnit
	end
	return partition, perUnitLimit, targetPoolLimit
end

local function giveOrdersPerUnitByTravelRoute(commandId, selectedUnits, filteredTargets, options)
	local closestFirst = not options.meta or options.shift
	local positionCache = {}
	local singleUnitArray = {}
	local targets = {}
	for unitIndex = 1, #selectedUnits do
		local selectedUnitId = selectedUnits[unitIndex]
		singleUnitArray[1] = selectedUnitId
		for targetIndex = 1, #filteredTargets do
			targets[targetIndex] = filteredTargets[targetIndex]
		end
		for targetIndex = #filteredTargets + 1, #targets do
			targets[targetIndex] = nil
		end
		sortTargetsByTravelRoute(selectedUnitId, targets, closestFirst, positionCache)
		giveOrders(commandId, singleUnitArray, targets, options)
	end
end

local function givePartitionedOrders(commandId, selectedUnits, filteredTargets, options, referenceTargetId)
	local closestFirst = not options.meta or options.shift
	local positionCache = {}
	if #filteredTargets >= #selectedUnits then
		local center = resolvePartitionCenter(selectedUnits, filteredTargets, referenceTargetId, positionCache)
		local sortedTargets = {}
		for targetIndex = 1, #filteredTargets do
			sortedTargets[targetIndex] = filteredTargets[targetIndex]
		end
		local sortedUnits = {}
		for unitIndex = 1, #selectedUnits do
			sortedUnits[unitIndex] = selectedUnits[unitIndex]
		end
		if center then
			sortIdsByAngle(sortedTargets, center, positionCache)
			sortIdsByAngle(sortedUnits, center, positionCache)
		end
		local chunks = buildContiguousChunks(sortedTargets, #sortedUnits)
		local singleUnitArray = {}
		for unitIndex = 1, #sortedUnits do
			local assignedTargets = chunks[unitIndex]
			local selectedUnitId = sortedUnits[unitIndex]
			singleUnitArray[1] = selectedUnitId
			sortTargetsByTravelRoute(selectedUnitId, assignedTargets, closestFirst, positionCache)
			giveOrders(commandId, singleUnitArray, assignedTargets, options)
		end
	else
		local minimumCount, remainderCount = divideWithRemainder(#selectedUnits, #filteredTargets)
		local unassigned = {}
		for unitIndex = 1, #selectedUnits do
			unassigned[selectedUnits[unitIndex]] = true
		end
		local sortedTargets = {}
		for targetIndex = 1, #filteredTargets do
			sortedTargets[targetIndex] = filteredTargets[targetIndex]
		end
		sortTargetsByDistance(selectedUnits, sortedTargets, true, referenceTargetId, positionCache)
		for targetIndex = 1, #sortedTargets do
			local targetId = sortedTargets[targetIndex]
			local count = minimumCount
			if targetIndex <= remainderCount then
				count = count + 1
			end
			local squad = pickClosestUnassigned(targetId, selectedUnits, unassigned, count, positionCache)
			giveOrders(commandId, squad, { targetId }, options)
		end
	end
end

local function commandRule(targetTypes, targetAllegiance)
	local allowedTargetTypes = {}
	for targetTypeIndex = 1, #targetTypes do
		allowedTargetTypes[targetTypes[targetTypeIndex]] = true
	end
	return {
		allowedTargetTypes = allowedTargetTypes,
		targetAllegiance = targetAllegiance,
	}
end

local ALLOWED_COMMANDS = {
	[CMD.ATTACK] = commandRule({ UNIT }, ENEMY_UNITS),
	[CMD.CAPTURE] = commandRule({ UNIT }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET] = commandRule({ UNIT }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = commandRule({ UNIT }, ENEMY_UNITS),
	[CMD.GUARD] = commandRule({ UNIT }, ALLY_UNITS),
	[CMD.REPAIR] = commandRule({ UNIT }, ALLY_UNITS),
	[CMD.RECLAIM] = commandRule({ UNIT, FEATURE }, ALL_UNITS),
	[CMD.RESURRECT] = commandRule({ FEATURE }),
}

local function unitMatchesAllegiance(unitId, targetAllegiance)
	local isEnemy = spGetUnitAllyTeam(unitId) ~= myAllyTeamId
	if targetAllegiance == ENEMY_UNITS and not isEnemy then
		return false
	end
	if targetAllegiance == ALLY_UNITS and isEnemy then
		return false
	end
	return true
end

local function getFeatureMetadata(rawFeatureId, metadataCache)
	local cachedMetadata = metadataCache[rawFeatureId]
	if cachedMetadata then
		return cachedMetadata
	end
	local featureDefId = spGetFeatureDefId(rawFeatureId)
	local featureDef = featureDefId and FeatureDefs[featureDefId]
	local metal, _, energy = spGetFeatureResources(rawFeatureId)
	local hasMetal = (featureDef and featureDef.metal and featureDef.metal > 0)
		or (metal and metal > 0)
		or false
	local hasEnergy = (featureDef and featureDef.energy and featureDef.energy > 0)
		or (energy and energy > 0)
		or false
	local metadata = {
		featureDefId = featureDefId,
		category = featureDef and featureDef.customParams and featureDef.customParams.category,
		hasMetal = hasMetal,
		isEnergyOnly = not hasMetal and hasEnergy,
		reclaimable = featureDef and featureDef.reclaimable,
		hasCurrentYield = (metal and metal > 0) or (energy and energy > 0) or false,
	}
	metadataCache[rawFeatureId] = metadata
	return metadata
end

local function featureMatchesReclaimReference(featureMetadata, referenceMetadata)
	if referenceMetadata.category == "corpses" then
		return featureMetadata.category == "corpses"
			and featureMetadata.featureDefId == referenceMetadata.featureDefId
	end
	if referenceMetadata.category == "heaps" then
		return featureMetadata.category == "heaps"
	end
	if referenceMetadata.isEnergyOnly then
		return featureMetadata.isEnergyOnly
	end
	if referenceMetadata.hasMetal then
		return featureMetadata.hasMetal
			and featureMetadata.featureDefId == referenceMetadata.featureDefId
	end
	return false
end

local function featureMatchesReclaimYield(featureMetadata, referenceMetadata)
	if referenceMetadata.hasMetal then
		return featureMetadata.hasMetal
	end
	if referenceMetadata.isEnergyOnly then
		return featureMetadata.isEnergyOnly
	end
	return false
end

local function shouldIncludeVisibleFeature(featureId, commandId, metadataCache)
	if commandId == CMD.RESURRECT then
		local unitDefName = spGetFeatureResurrect(featureId)
		return unitDefName ~= nil and unitDefName ~= ""
	end
	if commandId == CMD.RECLAIM then
		local featureMetadata = getFeatureMetadata(featureId, metadataCache)
		if not featureMetadata.featureDefId or featureMetadata.reclaimable == false then
			return false
		end
		if featureMetadata.hasCurrentYield then
			return true
		end
		return featureMetadata.reclaimable == true
	end
	return false
end

local function collectVisibleUnits(unitDefId, targetAllegiance, teamId)
	local filteredTargets = {}
	local visibleUnits = spGetVisibleUnits()
	if not visibleUnits then
		return filteredTargets
	end
	for unitIndex = 1, #visibleUnits do
		local unitId = visibleUnits[unitIndex]
		local matchesUnitDef = not unitDefId or spGetUnitDefId(unitId) == unitDefId
		local matchesAllegiance = not targetAllegiance or unitMatchesAllegiance(unitId, targetAllegiance)
		local matchesTeam = not teamId or spGetUnitTeam(unitId) == teamId
		if matchesUnitDef and matchesAllegiance and matchesTeam then
			tableInsert(filteredTargets, unitId)
		end
	end
	return filteredTargets
end

local function collectVisibleFeatures(commandId, featureDefId)
	local filteredTargets = {}
	local visibleFeatures = spGetVisibleFeatures(-1)
	local metadataCache = {}
	if not visibleFeatures then
		return filteredTargets
	end
	for featureIndex = 1, #visibleFeatures do
		local featureId = visibleFeatures[featureIndex]
		if (not featureDefId or spGetFeatureDefId(featureId) == featureDefId)
			and shouldIncludeVisibleFeature(featureId, commandId, metadataCache)
		then
			tableInsert(filteredTargets, normalizeFeatureTargetId(featureId))
		end
	end
	return filteredTargets
end

local function collectVisibleReclaimFeatures(referenceRawFeatureId, broadenByYield)
	local filteredTargets = {}
	local visibleFeatures = spGetVisibleFeatures(-1)
	if not visibleFeatures then
		return filteredTargets
	end
	local metadataCache = {}
	local referenceMetadata = getFeatureMetadata(referenceRawFeatureId, metadataCache)
	for featureIndex = 1, #visibleFeatures do
		local featureId = visibleFeatures[featureIndex]
		local featureMetadata = getFeatureMetadata(featureId, metadataCache)
		local matchesReference
		if broadenByYield then
			matchesReference = featureMatchesReclaimYield(featureMetadata, referenceMetadata)
		else
			matchesReference = featureMatchesReclaimReference(featureMetadata, referenceMetadata)
		end
		if shouldIncludeVisibleFeature(featureId, CMD.RECLAIM, metadataCache)
			and matchesReference
		then
			tableInsert(filteredTargets, normalizeFeatureTargetId(featureId))
		end
	end
	return filteredTargets
end

local function isValidMassOrderTarget(commandId, targetId, isFeature)
	local commandConfig = ALLOWED_COMMANDS[commandId]
	if not commandConfig then
		return false
	end
	if isFeature then
		if not commandConfig.allowedTargetTypes[FEATURE] then
			return false
		end
		if commandId == CMD.RESURRECT then
			local unitDefName = spGetFeatureResurrect(getRawFeatureId(targetId))
			if unitDefName == nil or unitDefName == "" then
				return false
			end
		end
		return true
	end
	if not commandConfig.allowedTargetTypes[UNIT] then
		return false
	end
	local isEnemy = spGetUnitAllyTeam(targetId) ~= myAllyTeamId
	local allegiance = commandConfig.targetAllegiance
	if isEnemy and allegiance ~= ALL_UNITS and allegiance ~= ENEMY_UNITS then
		return false
	end
	if not isEnemy and allegiance == ENEMY_UNITS then
		return false
	end
	if commandId == CMD.CAPTURE and not isCapturableTargetUnit(targetId) then
		return false
	end
	return true
end

local function resolveCursorTargetId(mouseX, mouseY)
	local targetType, targetId = spTraceScreenRay(mouseX, mouseY)
	if targetType == UNIT then
		return targetId
	end
	if targetType == FEATURE then
		return normalizeFeatureTargetId(targetId)
	end
	return nil
end

local function resolveMassOrderReferenceTarget(commandId, firstClickTargetId, secondClickTargetId)
	if secondClickTargetId then
		local secondClickTargetIsFeature = isFeatureTargetId(secondClickTargetId)
		if isValidMassOrderTarget(commandId, secondClickTargetId, secondClickTargetIsFeature) then
			return secondClickTargetId, secondClickTargetIsFeature
		end
	end
	return firstClickTargetId, isFeatureTargetId(firstClickTargetId)
end

local function buildSelectionSet(selectedUnits)
	local selectionSet = {}
	for unitIndex = 1, #selectedUnits do
		selectionSet[selectedUnits[unitIndex]] = true
	end
	return selectionSet
end

local function filterTargetsBySelectionMembership(targets, selectionSet, targetInSelection)
	local filteredTargets = {}
	for targetIndex = 1, #targets do
		local targetId = targets[targetIndex]
		if isFeatureTargetId(targetId) then
			tableInsert(filteredTargets, targetId)
		elseif targetInSelection and selectionSet[targetId] then
			tableInsert(filteredTargets, targetId)
		elseif not targetInSelection and not selectionSet[targetId] then
			tableInsert(filteredTargets, targetId)
		end
	end
	return filteredTargets
end

local function collectMassOrderTargets(commandId, targetId, isFeature, options)
	if isFeature then
		local rawFeatureId = getRawFeatureId(targetId)
		if commandId == CMD.RECLAIM then
			return collectVisibleReclaimFeatures(rawFeatureId, options.ctrl)
		end
		local featureDefId = spGetFeatureDefId(rawFeatureId)
		if not featureDefId then
			return {}
		end
		local typeFilter = featureDefId
		if options.ctrl then
			typeFilter = nil
		end
		return collectVisibleFeatures(commandId, typeFilter)
	end
	local commandConfig = ALLOWED_COMMANDS[commandId]
	local isEnemy = spGetUnitAllyTeam(targetId) ~= myAllyTeamId
	if commandConfig.targetAllegiance == ENEMY_UNITS or (commandId == CMD.RECLAIM and isEnemy) then
		if options.ctrl then
			return finalizeUnitTargets(commandId, collectVisibleUnits(nil, ENEMY_UNITS, nil))
		end
		local unitDefId = spGetUnitDefId(targetId)
		if not unitDefId then
			return {}
		end
		return finalizeUnitTargets(commandId, collectVisibleUnits(unitDefId, ENEMY_UNITS, nil))
	end
	if commandId == CMD.REPAIR and not isEnemy then
		local targetTeamId = spGetUnitTeam(targetId)
		if not targetTeamId then
			return {}
		end
		if options.ctrl then
			return finalizeUnitTargets(commandId, collectVisibleUnits(nil, ALLY_UNITS, targetTeamId))
		end
		local unitDefId = spGetUnitDefId(targetId)
		if not unitDefId then
			return {}
		end
		return finalizeUnitTargets(commandId, collectVisibleUnits(unitDefId, ALLY_UNITS, targetTeamId))
	end
	if commandId == CMD.RECLAIM and not isEnemy then
		local targetTeamId = spGetUnitTeam(targetId)
		if not targetTeamId then
			return {}
		end
		if targetTeamId ~= myTeamId then
			return { targetId }
		end
		if options.ctrl then
			return collectVisibleUnits(nil, nil, myTeamId)
		end
		local unitDefId = spGetUnitDefId(targetId)
		if not unitDefId then
			return {}
		end
		return collectVisibleUnits(unitDefId, nil, myTeamId)
	end
	if options.ctrl then
		return finalizeUnitTargets(commandId, collectVisibleUnits(nil, ALLY_UNITS, nil))
	end
	local unitDefId = spGetUnitDefId(targetId)
	if not unitDefId then
		return {}
	end
	return finalizeUnitTargets(commandId, collectVisibleUnits(unitDefId, commandConfig.targetAllegiance, nil))
end

local function issueMassOrdersFromTarget(issueCommandId, referenceTargetId, referenceTargetIsFeature, selectedUnits, options)
	local selectionSet = buildSelectionSet(selectedUnits)
	local targetInSelection = not referenceTargetIsFeature and selectionSet[referenceTargetId] == true
	selectedUnits = filterUnitsForCommand(selectedUnits, issueCommandId)
	if #selectedUnits == 0 then
		return false
	end
	local filteredTargets = collectMassOrderTargets(issueCommandId, referenceTargetId, referenceTargetIsFeature, options)
	filteredTargets = filterTargetsBySelectionMembership(filteredTargets, selectionSet, targetInSelection)
	local partition, perUnitLimit, targetPoolLimit = resolveMassOrderBudget(#selectedUnits, #filteredTargets, options.alt)
	filteredTargets = limitTargetsByRadius(filteredTargets, referenceTargetId, selectedUnits, targetPoolLimit)
	if #filteredTargets == 0 or perUnitLimit <= 0 then
		return false
	end
	if partition then
		givePartitionedOrders(issueCommandId, selectedUnits, filteredTargets, options, referenceTargetId)
	else
		giveOrdersPerUnitByTravelRoute(issueCommandId, selectedUnits, filteredTargets, options)
	end
	local savedCommandDescriptionIndex = select(1, spGetActiveCommand()) or spGetCommandDescriptionIndex(issueCommandId)
	if options.shift then
		heldCommandDescriptionIndex = savedCommandDescriptionIndex
		restoreActiveCommand(savedCommandDescriptionIndex)
	else
		heldCommandDescriptionIndex = nil
		deferClearActiveCommand = true
	end
	return true
end

local function issuePendingDoubleClickMassOrders(options, secondClickTargetId)
	if not isPendingDoubleClickActive() then
		return false
	end
	local issueCommandId = pendingDoubleClick.commandId
	local firstClickTargetId = pendingDoubleClick.targetId
	local referenceTargetId, referenceTargetIsFeature = resolveMassOrderReferenceTarget(
		issueCommandId,
		firstClickTargetId,
		secondClickTargetId
	)
	local massCommandOptions = {
		alt = options.alt or pendingDoubleClick.alt,
		ctrl = options.ctrl or pendingDoubleClick.ctrl,
		meta = options.meta or pendingDoubleClick.meta,
		shift = options.shift or pendingDoubleClick.shift,
		right = options.right,
	}
	clearDoubleClickPending()
	local selectedUnits = spGetSelectedUnits()
	local massIssued = false
	local skipMassReissue = false
	if issueCommandId == CMD.RECLAIM and not referenceTargetIsFeature then
		local isEnemy = spGetUnitAllyTeam(referenceTargetId) ~= myAllyTeamId
		local targetTeamId = spGetUnitTeam(referenceTargetId)
		if not isEnemy and targetTeamId and targetTeamId ~= myTeamId then
			skipMassReissue = true
		end
	end
	if not skipMassReissue and #selectedUnits > 0 then
		massIssued = issueMassOrdersFromTarget(issueCommandId, referenceTargetId, referenceTargetIsFeature, selectedUnits, massCommandOptions)
	end
	if not massIssued and not massCommandOptions.shift then
		heldCommandDescriptionIndex = nil
		deferClearActiveCommand = true
	end
	return true
end

local function resolveScreenSelectCommandId(commandId)
	if commandId ~= nil then
		return commandId
	end
	local _, activeCommandId = spGetActiveCommand()
	if activeCommandId and ALLOWED_COMMANDS[activeCommandId] then
		return activeCommandId
	end
	return nil
end

local function consumePendingDoubleClickClick(options, effectiveCommandId, secondClickTargetId)
	if not doubleClickEnabled or not isPendingDoubleClickActive() then
		return false
	end
	if effectiveCommandId and pendingDoubleClick.commandId ~= effectiveCommandId then
		return false
	end
	if pendingDoubleClick.right ~= options.right then
		return false
	end
	if osClock() < pendingDoubleClick.firstClickTime + MIN_DOUBLE_CLICK_GAP then
		clearDoubleClickPending()
		if not options.shift then
			heldCommandDescriptionIndex = nil
			deferClearActiveCommand = true
		end
		return true
	end
	return issuePendingDoubleClickMassOrders(options, secondClickTargetId)
end

local function handleScreenSelectCommand(effectiveCommandId, parameters, options)
	local targetId = parameters[1]
	local isFeature = isFeatureTargetId(targetId)

	if not screenSelectHeld and consumePendingDoubleClickClick(options, effectiveCommandId, targetId) then
		return true
	end

	if not isValidMassOrderTarget(effectiveCommandId, targetId, isFeature) then
		return false
	end

	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 then
		return false
	end
	if screenSelectHeld then
		return issueMassOrdersFromTarget(effectiveCommandId, targetId, isFeature, selectedUnits, options)
	end

	selectedUnits = filterUnitsForCommand(selectedUnits, effectiveCommandId)
	if #selectedUnits == 0 then
		return false
	end

	if not doubleClickEnabled then
		giveOrders(effectiveCommandId, selectedUnits, { targetId }, options)
		if options.shift then
			heldCommandDescriptionIndex = select(1, spGetActiveCommand()) or spGetCommandDescriptionIndex(effectiveCommandId)
		else
			heldCommandDescriptionIndex = nil
			deferClearActiveCommand = true
		end
		return true
	end

	local currentTime = osClock()

	giveOrders(effectiveCommandId, selectedUnits, { targetId }, options)

	pendingDoubleClick.targetId = targetId
	pendingDoubleClick.expireTime = currentTime + DOUBLE_CLICK_TIME
	pendingDoubleClick.commandId = effectiveCommandId
	pendingDoubleClick.alt = options.alt
	pendingDoubleClick.ctrl = options.ctrl
	pendingDoubleClick.meta = options.meta
	pendingDoubleClick.shift = options.shift
	pendingDoubleClick.right = options.right
	pendingDoubleClick.firstClickTime = currentTime
	if options.shift then
		heldCommandDescriptionIndex = select(1, spGetActiveCommand()) or spGetCommandDescriptionIndex(effectiveCommandId)
	end
	return true
end

local function isSetTargetCommand(commandId)
	return commandId == GameCMD.UNIT_SET_TARGET or commandId == GameCMD.UNIT_SET_TARGET_NO_GROUND
end

function widget:MousePress(mouseX, mouseY, button)
	if button ~= 1 and button ~= 3 then
		return false
	end
	local options = enrichCommandOptions({ right = (button == 3) })
	local effectiveCommandId = resolveScreenSelectCommandId(nil)
	if isSetTargetCommand(effectiveCommandId) and options.alt then
		clearDoubleClickPending()
		return false
	end
	if not doubleClickEnabled or not isPendingDoubleClickActive() then
		return false
	end
	local cursorTargetId = resolveCursorTargetId(mouseX, mouseY)
	if not cursorTargetId then
		return false
	end
	return consumePendingDoubleClickClick(options, effectiveCommandId, cursorTargetId)
end

function widget:CommandNotify(commandId, parameters, options)
	options = enrichCommandOptions(options)
	local effectiveCommandId = resolveScreenSelectCommandId(commandId)
	if isSetTargetCommand(effectiveCommandId) and options.alt then
		clearDoubleClickPending()
		return false
	end
	if #parameters == 1 then
		return handleScreenSelectCommand(effectiveCommandId, parameters, options)
	end
	return false
end

local function onScreenSelectHoldPress()
	screenSelectHeld = true
end

local function onScreenSelectHoldRelease()
	screenSelectHeld = false
end

local function setDoubleClickEnabled(value)
	doubleClickEnabled = value == true
	if not doubleClickEnabled then
		clearDoubleClickPending()
	end
end

local function setMaxMassOrderTargets(value)
	local numericValue = tonumber(value)
	if not numericValue then
		return
	end
	maxMassOrderTargets = mathMax(1, mathFloor(numericValue))
end

local function setCommandLimit(value)
	local numericValue = tonumber(value)
	if not numericValue then
		return
	end
	commandLimit = mathMax(1, mathFloor(numericValue))
end

local function registerScreenSelectCommandsApi()
	WG["screenSelectCommands"] = {
		getDoubleClickEnabled = function()
			return doubleClickEnabled
		end,
		setDoubleClickEnabled = setDoubleClickEnabled,
		getMaxMassOrderTargets = function()
			return maxMassOrderTargets
		end,
		setMaxMassOrderTargets = setMaxMassOrderTargets,
		getCommandLimit = function()
			return commandLimit
		end,
		setCommandLimit = setCommandLimit,
	}
end

local function initialize()
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
	myAllyTeamId = spGetMyAllyTeamId()
	myTeamId = spGetMyTeamId()
end

function widget:PlayerChanged()
	clearDoubleClickPending()
	heldCommandDescriptionIndex = nil
	initialize()
end

function widget:Initialize()
	initialize()
	if spGetSpectatingState() then
		return
	end
	widgetHandler:AddAction("screen_select_hold", onScreenSelectHoldPress, nil, "p")
	widgetHandler:AddAction("screen_select_hold", onScreenSelectHoldRelease, nil, "r")
	registerScreenSelectCommandsApi()
end

function widget:Shutdown()
	widgetHandler:RemoveAction("screen_select_hold", "p")
	widgetHandler:RemoveAction("screen_select_hold", "r")
	WG["screenSelectCommands"] = nil
	screenSelectHeld = false
end

function widget:Update()
	if deferClearActiveCommand then
		deferClearActiveCommand = false
		spSetActiveCommand(0)
	end
	if pendingDoubleClick.targetId and osClock() >= pendingDoubleClick.expireTime then
		clearDoubleClickPending()
	end
	updateShiftCommandKeep()
end

function widget:ActiveCommandChanged(commandId)
	if commandId then
		if pendingDoubleClick.commandId and pendingDoubleClick.commandId ~= commandId then
			clearDoubleClickPending()
		end
		return
	end
	if isPendingDoubleClickActive() then
		return
	end
	if heldCommandDescriptionIndex then
		return
	end
	clearDoubleClickPending()
end

function widget:GetConfigData()
	return {
		doubleClickEnabled = doubleClickEnabled,
		maxMassOrderTargets = maxMassOrderTargets,
		commandLimit = commandLimit,
	}
end

function widget:SetConfigData(data)
	if data.doubleClickEnabled ~= nil then
		setDoubleClickEnabled(data.doubleClickEnabled)
	end
	if data.maxMassOrderTargets ~= nil then
		setMaxMassOrderTargets(data.maxMassOrderTargets)
	elseif data.maxDoubleClickUnits ~= nil then
		setMaxMassOrderTargets(data.maxDoubleClickUnits)
	end
	if data.commandLimit ~= nil then
		setCommandLimit(data.commandLimit)
	end
end
