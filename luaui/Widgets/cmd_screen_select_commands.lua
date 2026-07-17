local widget = widget ---@type RulesUnsyncedCallins

function widget:GetInfo()
	return {
		name = "Screen Select Commands",
		desc = "Mass-issue unit-target commands to all visible on-screen matches. Click again while pending, or use the keybind + click for mass orders.",
		author = "SethDGamre, advised by Chronographer",
		date = "July 11, 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

--[[------------------------------------------------------------------------------
How To Use:
  First click issues a normal order. Another click while pending mass-orders all on-screen matches.
  Optionally, bind and hold screen_select_hold to mass-order on the first click instead.

Click modifiers:
  Shift -> add to end of queue (always additive; never toggles/removes an existing matching order)
  Space -> prepend to the queue
  Shift + Space -> insert into the nearest queued path segment
  Ctrl -> expand scope to all visible same-alignment targets (enemies: any enemy excluding neutrals; neutrals: all neutrals; allies: any ally team). For reclaim features, mass-order all reclaimable features (commander corpses still excluded).
  Alt -> partition targets among selected units (see Order assignment below)
  If units × targets would exceed commandLimit, auto-partition and shrink per-unit assignments to fit the budget. maxMassOrderTargets is the max targets each unit may receive. If more targets exist than the budget, the selection radius shrinks from MASS_ORDER_START_RADIUS by MASS_ORDER_RADIUS_STEP until the count fits.

  Order assignment:
  Normal mass-order -> every selected unit gets the same targets; each unit's queue is a nearest-neighbor travel route from that unit (closest next hop first; Space alone reverses that route).
  Alt (or auto-partition when over commandLimit) -> when targets >= units, units and targets are sorted by angle around the selection centroid and targets are split into contiguous wedges so each unit works a nearby cluster (then nearest-neighbor route within its share). When targets < units, units are divided evenly across targets, assigning the closest free units to each.

  Team categories (most nested first): own teamID, allies, enemies, neutrals (Gaia ruins via GetUnitNeutral).
  Command-Specific behavior:
  Attack / Capture / Set Target -> neutrals are their own team category, separate from other enemies
  Capture -> only finished, capturable targets; only capturers issue; skips targets the unit cannot move onto
  Repair -> only damaged targets; scopes to clicked unit's team (not all allies); Ctrl = any damaged unit on that team; skips targets the unit cannot move onto
  Reclaim -> enemies, allies, and features; reclaiming another ally's unit is single-target only (no mass spread); features match by category (same corpse featureDefID; all non-corpse metal including heaps/rocks/ferns; all energy-only); Ctrl = all reclaimable features; commander corpses are never mass-ordered (individual reclaim only); skips targets the unit cannot move onto; neutral targets follow the neutral team category above
  Resurrect -> Corpses only, must be resurrectable; Ctrl = all visible resurrectable wrecks; skips targets the unit cannot move onto
  Guard -> builders only guard the clicked target; non-builders use normal mass targeting
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
local mathDistance2dSquared = math.distance2dSquared
local osClock = os.clock

local spring = Spring

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitNeutral = Spring.GetUnitNeutral
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureResurrect = Spring.GetFeatureResurrect
local spGetFeatureResources = Spring.GetFeatureResources
local spValidFeatureID = Spring.ValidFeatureID
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitHealth = Spring.GetUnitHealth
local spTestMoveOrder = Spring.TestMoveOrder
local spWorldToScreenCoords = Spring.WorldToScreenCoords

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local NEUTRAL_UNITS = "neutral_units"
local LEFT_MOUSE_BUTTON = 1
local RIGHT_MOUSE_BUTTON = 3
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
local COMMANDS_REQUIRING_CAPABILITY = {
	[CMD.RECLAIM] = true,
	[CMD.RESURRECT] = true,
	[CMD.REPAIR] = true,
	[CMD.CAPTURE] = true,
}

local MAX_QUEUE_COMMANDS = 100
local MASS_ORDER_START_RADIUS = 2000
local MASS_ORDER_RADIUS_STEP = 500
local DOUBLE_CLICK_TIME = Spring.GetConfigInt("DoubleClickTime", 200) / 1000
local DOUBLE_CLICK_SNAP_HEIGHT_FRACTION = 32 / 1080

local doubleClickEnabled = true
local maxMassOrderTargets = 150
local commandLimit = 4000

local myAllyTeamID
local myTeamID
local unitDefMetadataByID = {}
local commanderCorpseFeatureDefIDs = {}
local pendingDoubleClick = {}
local heldCommandDescriptionIndex
local deferClearActiveCommand = false
local screenSelectKeyHeld = false
local vsy = select(2, spring.GetViewGeometry())
local doubleClickSnapRadius = vsy * DOUBLE_CLICK_SNAP_HEIGHT_FRACTION
local doubleClickSnapRadiusSq = doubleClickSnapRadius * doubleClickSnapRadius

local function updateDoubleClickSnapRadius()
	vsy = select(2, spring.GetViewGeometry())
	doubleClickSnapRadius = vsy * DOUBLE_CLICK_SNAP_HEIGHT_FRACTION
	doubleClickSnapRadiusSq = doubleClickSnapRadius * doubleClickSnapRadius
end

local function clearDoubleClickPending()
	pendingDoubleClick = {
		targetID = nil,
		expireTime = 0,
		commandID = nil,
		right = false,
	}
end

local function fillCommandOptionModifiers(options)
	options = options or {}
	local modifierAlt, modifierControl, modifierMeta, modifierShift = spring.GetModKeyState()
	return {
		alt = options.alt or modifierAlt,
		ctrl = options.ctrl or modifierControl,
		meta = options.meta or modifierMeta,
		shift = options.shift or modifierShift,
		right = options.right or false,
	}
end

local function toPositionTable(x, y, z)
	if not x then
		return nil
	end
	return { x = x, y = y, z = z }
end

local function updateShiftCommandKeep()
	if not heldCommandDescriptionIndex then
		return
	end
	local modifierAlt, modifierControl, modifierMeta, modifierShift = spring.GetModKeyState()
	if modifierShift then
		local _, activeCommandID = spring.GetActiveCommand()
		if not activeCommandID then
			spring.SetActiveCommand(heldCommandDescriptionIndex, 1, true, false, modifierAlt, modifierControl, modifierMeta, modifierShift)
		end
	else
		heldCommandDescriptionIndex = nil
	end
end

local function isPendingDoubleClickActive()
	return pendingDoubleClick.commandID ~= nil
		and osClock() < pendingDoubleClick.expireTime
end

local function isFeatureTargetID(targetID)
	-- Anything in the feature range is a feature; verify against the de-offset ID.
	if targetID >= Game.maxUnits then
		return spValidFeatureID(targetID - Game.maxUnits)
	end
	-- Below the range it could still be a feature, so check explicitly.
	if spValidFeatureID(targetID) and not spValidUnitID(targetID) then
		return true
	end
	return false
end

local function getRawFeatureID(targetID)
	-- Strip Game.maxUnits to recover the ID feature APIs expect.
	if targetID >= Game.maxUnits then
		return targetID - Game.maxUnits
	end
	return targetID
end

local function normalizeFeatureTargetID(featureID)
	-- Inverse of getRawFeatureID: re-apply the offset so the ID is valid as a command parameter.
	return featureID + Game.maxUnits
end

local function toFeatureOrderParamID(targetID)
	-- Unit targets pass through untouched; feature targets always carry the offset ID.
	if not isFeatureTargetID(targetID) then
		return targetID
	end
	return getRawFeatureID(targetID) + Game.maxUnits
end

local function filterUnitsForCommand(selectedUnits, commandID)
	if not COMMANDS_REQUIRING_CAPABILITY[commandID] then
		return selectedUnits
	end
	local filteredUnits = {}
	for unitIndex = 1, #selectedUnits do
		local unitID = selectedUnits[unitIndex]
		local unitDefID = spGetUnitDefID(unitID)
		local metadata = unitDefID and unitDefMetadataByID[unitDefID]
		if metadata and metadata.commandCapabilities[commandID] then
			tableInsert(filteredUnits, unitID)
		end
	end
	return filteredUnits
end

local function splitBuilderUnits(selectedUnits)
	local builderUnits = {}
	local nonBuilderUnits = {}
	for unitIndex = 1, #selectedUnits do
		local unitID = selectedUnits[unitIndex]
		local unitDefID = spGetUnitDefID(unitID)
		local metadata = unitDefID and unitDefMetadataByID[unitDefID]
		if metadata and metadata.isScreenSelectBuilder then
			tableInsert(builderUnits, unitID)
		else
			tableInsert(nonBuilderUnits, unitID)
		end
	end
	return builderUnits, nonBuilderUnits
end

local function captureHeldCommandDescriptionIndex(commandID)
	return select(1, spring.GetActiveCommand()) or spring.GetCmdDescIndex(commandID)
end

local function clearActiveCommandUnlessShift(options)
	if options.shift then
		return
	end
	heldCommandDescriptionIndex = nil
	deferClearActiveCommand = true
end

local function finishMassOrderCommandState(issueCommandID, options)
	local savedCommandDescriptionIndex = captureHeldCommandDescriptionIndex(issueCommandID)
	if options.shift then
		heldCommandDescriptionIndex = savedCommandDescriptionIndex
		local modifierAlt, modifierControl, modifierMeta, modifierShift = spring.GetModKeyState()
		spring.SetActiveCommand(savedCommandDescriptionIndex, 1, true, false, modifierAlt, modifierControl, modifierMeta, modifierShift)
	else
		clearActiveCommandUnlessShift(options)
	end
end

local function isCapturableTargetUnit(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	local metadata = unitDefID and unitDefMetadataByID[unitDefID]
	if not metadata or not metadata.capturable then
		return false
	end
	if spGetUnitIsBeingBuilt(unitID) then
		return false
	end
	return true
end

local function isRepairableTargetUnit(unitID)
	if spGetUnitIsBeingBuilt(unitID) then
		return false
	end
	local health, maxHealth = spGetUnitHealth(unitID)
	if not health or not maxHealth then
		return false
	end
	return health < maxHealth
end

local function filterTargetsByPredicate(targets, predicate)
	local filteredTargets = {}
	for targetIndex = 1, #targets do
		local targetID = targets[targetIndex]
		if predicate(targetID) then
			tableInsert(filteredTargets, targetID)
		end
	end
	return filteredTargets
end

local function finalizeUnitTargets(commandID, targets)
	if commandID == CMD.CAPTURE then
		return filterTargetsByPredicate(targets, isCapturableTargetUnit)
	end
	if commandID == CMD.REPAIR then
		return filterTargetsByPredicate(targets, isRepairableTargetUnit)
	end
	return targets
end

local function getTargetPosition(targetID, positionCache)
	if positionCache and positionCache[targetID] ~= nil then
		return positionCache[targetID] or nil
	end
	local position
	if isFeatureTargetID(targetID) then
		local x, y, z = spGetFeaturePosition(getRawFeatureID(targetID))
		if x then
			position = toPositionTable(x, y, z)
		end
	else
		local x, y, z = spGetUnitPosition(targetID)
		if x then
			position = toPositionTable(x, y, z)
		end
	end
	if positionCache then
		positionCache[targetID] = position or false
	end
	return position
end

local function canUnitDefReachPosition(unitDefID, targetID, position, reachabilityCache)
	if not unitDefID or not position then
		return false
	end
	local metadata = unitDefMetadataByID[unitDefID]
	if metadata and metadata.canFly then
		return true
	end
	local unitDefCache = reachabilityCache[unitDefID]
	if not unitDefCache then
		unitDefCache = {}
		reachabilityCache[unitDefID] = unitDefCache
	end
	local cachedResult = unitDefCache[targetID]
	if cachedResult ~= nil then
		return cachedResult
	end
	local canReach = spTestMoveOrder(unitDefID, position.x, position.y, position.z, nil, nil, nil, true, false)
	unitDefCache[targetID] = canReach
	return canReach
end

local function filterTargetsReachableByUnitDef(unitDefID, targets, positionCache, reachabilityCache)
	local filteredTargets = {}
	for targetIndex = 1, #targets do
		local targetID = targets[targetIndex]
		local position = getTargetPosition(targetID, positionCache)
		if position and canUnitDefReachPosition(unitDefID, targetID, position, reachabilityCache) then
			tableInsert(filteredTargets, targetID)
		end
	end
	return filteredTargets
end

local function filterTargetsReachableByAnyUnit(selectedUnits, targets, positionCache, reachabilityCache)
	local unitDefIDs = {}
	local seenUnitDefIDs = {}
	for unitIndex = 1, #selectedUnits do
		local unitDefID = spGetUnitDefID(selectedUnits[unitIndex])
		if unitDefID and not seenUnitDefIDs[unitDefID] then
			seenUnitDefIDs[unitDefID] = true
			tableInsert(unitDefIDs, unitDefID)
		end
	end
	if #unitDefIDs == 0 then
		return {}
	end
	local filteredTargets = {}
	for targetIndex = 1, #targets do
		local targetID = targets[targetIndex]
		local position = getTargetPosition(targetID, positionCache)
		if position then
			for unitDefIndex = 1, #unitDefIDs do
				if canUnitDefReachPosition(unitDefIDs[unitDefIndex], targetID, position, reachabilityCache) then
					tableInsert(filteredTargets, targetID)
					break
				end
			end
		end
	end
	return filteredTargets
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

local function compareNullablePrimary(primaryA, primaryB, indexA, indexB, primaryLess)
	local missingA = primaryA == nil or primaryA == false
	local missingB = primaryB == nil or primaryB == false
	if missingA or missingB then
		if missingA == missingB then
			return indexA < indexB
		end
		return not missingA
	end
	if primaryA == primaryB then
		return indexA < indexB
	end
	return primaryLess(primaryA, primaryB)
end

local function sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst, referenceUnitID, positionCache)
	positionCache = positionCache or {}
	local referencePosition = referenceUnitID and getTargetPosition(referenceUnitID, positionCache)
		or toPositionTable(spring.GetUnitArrayCentroid(selectedUnits))
	if not referencePosition then
		return nil
	end
	local targetDistances = {}
	local originalIndices = {}
	for targetIndex = 1, #filteredTargets do
		local targetID = filteredTargets[targetIndex]
		local targetPosition = getTargetPosition(targetID, positionCache)
		targetDistances[targetID] = targetPosition and mathDistance2dSquared(referencePosition.x, referencePosition.z, targetPosition.x, targetPosition.z) or false
		originalIndices[targetID] = targetIndex
	end
	local primaryLess = closestFirst and function(distanceA, distanceB)
		return distanceA < distanceB
	end or function(distanceA, distanceB)
		return distanceA > distanceB
	end
	tableSort(filteredTargets, function(targetIDA, targetIDB)
		return compareNullablePrimary(targetDistances[targetIDA], targetDistances[targetIDB], originalIndices[targetIDA], originalIndices[targetIDB], primaryLess)
	end)
	return targetDistances
end

local function buildNearestNeighborRoute(referencePosition, targets, positionCache)
	local targetPositions = {}
	local remainingTargets = {}
	local route = {}
	local hasTargetPosition = false
	for targetIndex = 1, #targets do
		local targetID = targets[targetIndex]
		local targetPosition = getTargetPosition(targetID, positionCache)
		targetPositions[targetID] = targetPosition or false
		remainingTargets[targetIndex] = targetID
		if targetPosition then
			hasTargetPosition = true
		end
	end
	if not hasTargetPosition then
		return route, false
	end
	local currentPosition = referencePosition
	local routeCount = 0
	while #remainingTargets > 0 do
		local nearestIndex
		local nearestDistance
		for targetIndex = 1, #remainingTargets do
			local targetID = remainingTargets[targetIndex]
			local targetPosition = targetPositions[targetID]
			if targetPosition then
				local targetDistance = mathDistance2dSquared(currentPosition.x, currentPosition.z, targetPosition.x, targetPosition.z)
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
		local nearestTargetID = remainingTargets[nearestIndex]
		routeCount = routeCount + 1
		route[routeCount] = nearestTargetID
		currentPosition = targetPositions[nearestTargetID]
		remainingTargets[nearestIndex] = remainingTargets[#remainingTargets]
		remainingTargets[#remainingTargets] = nil
	end
	return route, hasTargetPosition
end

local function sortTargetsByTravelRoute(referenceUnitID, targets, closestFirst, positionCache)
	local referencePosition = getTargetPosition(referenceUnitID, positionCache)
	if not referencePosition then
		return
	end
	local route, hasTargetPosition = buildNearestNeighborRoute(referencePosition, targets, positionCache)
	if not hasTargetPosition then
		return
	end
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

local function copyArray(source, maxCount)
	local result = {}
	local count = maxCount or #source
	if count > #source then
		count = #source
	end
	for index = 1, count do
		result[index] = source[index]
	end
	return result
end

local function limitTargetsByRadius(filteredTargets, referenceTargetID, selectedUnits, maximumTargetCount, positionCache)
	if maximumTargetCount <= 0 then
		return {}
	end
	if #filteredTargets == 0 then
		return filteredTargets
	end
	local referencePosition = getTargetPosition(referenceTargetID, positionCache)
	if not referencePosition then
		sortTargetsByDistance(selectedUnits, filteredTargets, true, nil, positionCache)
		return copyArray(filteredTargets, maximumTargetCount)
	end
	local targetDistances = sortTargetsByDistance({ referenceTargetID }, filteredTargets, true, referenceTargetID, positionCache)
	local radius
	while true do
		local limitedTargets
		if radius == nil then
			limitedTargets = copyArray(filteredTargets)
		else
			limitedTargets = {}
			local radiusSq = radius * radius
			for targetIndex = 1, #filteredTargets do
				local targetID = filteredTargets[targetIndex]
				local targetDistance = targetDistances and targetDistances[targetID]
				if targetDistance and targetDistance <= radiusSq then
					tableInsert(limitedTargets, targetID)
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
	return copyArray(filteredTargets, maximumTargetCount)
end

local function pointToSegmentDistanceSq(point, segmentStart, segmentEnd)
	local segmentX = segmentEnd.x - segmentStart.x
	local segmentZ = segmentEnd.z - segmentStart.z
	local segmentLengthSq = segmentX * segmentX + segmentZ * segmentZ
	if segmentLengthSq == 0 then
		return mathDistance2dSquared(point.x, point.z, segmentStart.x, segmentStart.z)
	end
	local projection = ((point.x - segmentStart.x) * segmentX + (point.z - segmentStart.z) * segmentZ) / segmentLengthSq
	if projection < 0 then
		projection = 0
	elseif projection > 1 then
		projection = 1
	end
	local nearestX = segmentStart.x + projection * segmentX
	local nearestZ = segmentStart.z + projection * segmentZ
	return mathDistance2dSquared(point.x, point.z, nearestX, nearestZ)
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

local function findQueueInsertionPosition(unitID, targetCentroid, positionCache)
	local unitPosition = getTargetPosition(unitID, positionCache)
	if not unitPosition or not targetCentroid then
		return nil
	end
	local commandQueue = spGetUnitCommands(unitID, MAX_QUEUE_COMMANDS)
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

local function insertOrdersByQueueProximity(commandID, selectedUnits, filteredTargets, options)
	local positionCache = {}
	local targetCentroid = getTargetCentroid(filteredTargets, positionCache)
	local singleUnitArray = {}
	local insertParameters = { 0, commandID, 0, 0 }
	local innerOptionBits = getCommandOptionBits(options, false)
	insertParameters[3] = innerOptionBits
	for unitIndex = 1, #selectedUnits do
		local unitID = selectedUnits[unitIndex]
		singleUnitArray[1] = unitID
		local insertionPosition = findQueueInsertionPosition(unitID, targetCentroid, positionCache)
		if insertionPosition == nil then
			for targetIndex = 1, #filteredTargets do
				local targetID = filteredTargets[targetIndex]
				insertParameters[1] = -1
				insertParameters[4] = toFeatureOrderParamID(targetID)
				spGiveOrderToUnitArray(singleUnitArray, CMD.INSERT, insertParameters, CMD.OPT_ALT)
			end
		else
			insertParameters[1] = insertionPosition
			for targetIndex = #filteredTargets, 1, -1 do
				local targetID = filteredTargets[targetIndex]
				insertParameters[4] = toFeatureOrderParamID(targetID)
				spGiveOrderToUnitArray(singleUnitArray, CMD.INSERT, insertParameters, CMD.OPT_ALT)
			end
		end
	end
end

local function giveOrders(commandID, selectedUnits, filteredTargets, options)
	if commandID == GameCMD.UNIT_SET_TARGET or commandID == GameCMD.UNIT_SET_TARGET_NO_GROUND then
		local setTargetOptionBits = getCommandOptionBits(options, false)
		local setTargetParameters = { 0 }
		for targetIndex = 1, #filteredTargets do
			setTargetParameters[1] = toFeatureOrderParamID(filteredTargets[targetIndex])
			local optionBits = setTargetOptionBits
			if targetIndex > 1 or options.shift then
				optionBits = optionBits + CMD.OPT_SHIFT
			end
			spGiveOrderToUnitArray(selectedUnits, commandID, setTargetParameters, optionBits)
		end
		return
	end
	if options.meta and options.shift then
		insertOrdersByQueueProximity(commandID, selectedUnits, filteredTargets, options)
		return
	end
	local baseOptionBits = getCommandOptionBits(options, false)
	local orderParameters = { 0 }
	local insertParameters = { 0, commandID, baseOptionBits, 0 }
	for targetIndex = 1, #filteredTargets do
		local targetID = filteredTargets[targetIndex]
		local orderTargetID = toFeatureOrderParamID(targetID)
		if options.meta then
			insertParameters[1] = 0
			insertParameters[4] = orderTargetID
			spGiveOrderToUnitArray(selectedUnits, CMD.INSERT, insertParameters, CMD.OPT_ALT)
		else
			local includeShift = targetIndex > 1 or options.shift
			if includeShift then
				insertParameters[1] = -1
				insertParameters[4] = orderTargetID
				spGiveOrderToUnitArray(selectedUnits, CMD.INSERT, insertParameters, CMD.OPT_ALT)
			else
				orderParameters[1] = orderTargetID
				spGiveOrderToUnitArray(selectedUnits, commandID, orderParameters, baseOptionBits)
			end
		end
	end
end

local function pickClosestUnitsForTarget(targetID, selectedUnits, unassignedUnits, requestedCount, positionCache, reachabilityCache)
	local available = {}
	local targetPosition = reachabilityCache and getTargetPosition(targetID, positionCache)
	for unitIndex = 1, #selectedUnits do
		local unitID = selectedUnits[unitIndex]
		if unassignedUnits[unitID] then
			local canReach = true
			if reachabilityCache then
				if not targetPosition then
					canReach = false
				else
					local unitDefID = spGetUnitDefID(unitID)
					canReach = unitDefID
						and canUnitDefReachPosition(unitDefID, targetID, targetPosition, reachabilityCache)
				end
			end
			if canReach then
				tableInsert(available, unitID)
			end
		end
	end
	sortTargetsByDistance({ targetID }, available, true, targetID, positionCache)
	local picked = {}
	local pickCount = mathMin(requestedCount, #available)
	for pickedIndex = 1, pickCount do
		local unitID = available[pickedIndex]
		picked[pickedIndex] = unitID
		unassignedUnits[unitID] = nil
	end
	return picked
end

local function sortIDsByAngle(ids, center, positionCache)
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
	local primaryLess = function(angleA, angleB)
		return angleA < angleB
	end
	tableSort(ids, function(idA, idB)
		return compareNullablePrimary(angles[idA], angles[idB], originalIndices[idA], originalIndices[idB], primaryLess)
	end)
end

local function buildContiguousChunks(sortedIDs, chunkCount)
	local chunks = {}
	local minimumCount = mathFloor(#sortedIDs / chunkCount)
	local remainderCount = #sortedIDs % chunkCount
	local nextIndex = 1
	for chunkIndex = 1, chunkCount do
		local count = minimumCount
		if chunkIndex <= remainderCount then
			count = count + 1
		end
		local chunk = {}
		for itemIndex = 1, count do
			chunk[itemIndex] = sortedIDs[nextIndex]
			nextIndex = nextIndex + 1
		end
		chunks[chunkIndex] = chunk
	end
	return chunks
end

local function resolvePartitionCenter(selectedUnits, filteredTargets, referenceTargetID, positionCache)
	local center = toPositionTable(spring.GetUnitArrayCentroid(selectedUnits))
	if center then
		return center
	end
	center = getTargetPosition(referenceTargetID, positionCache)
	if center then
		return center
	end
	return getTargetCentroid(filteredTargets, positionCache)
end

local function resolveMassOrderBudget(selectedUnitCount, availableTargetCount, forcePartition)
	local desiredPerUnit = maxMassOrderTargets
	local targetsPerUnit = mathMin(availableTargetCount, desiredPerUnit)
	local fullQueueCost = selectedUnitCount * targetsPerUnit
	local usePartitionedDispatch = forcePartition or fullQueueCost > commandLimit
	local maxTargetsPerUnit = desiredPerUnit
	if usePartitionedDispatch and fullQueueCost > commandLimit then
		maxTargetsPerUnit = mathFloor(commandLimit / selectedUnitCount)
	end
	local maxTargetsToCollect
	if usePartitionedDispatch then
		maxTargetsToCollect = mathMin(availableTargetCount, selectedUnitCount * maxTargetsPerUnit)
	else
		maxTargetsToCollect = targetsPerUnit
	end
	return usePartitionedDispatch, maxTargetsPerUnit, maxTargetsToCollect
end

local function giveUnitTravelRouteOrders(commandID, unitID, sourceTargets, options, positionCache, reachabilityCache, targets, singleUnitArray)
	local unitTargets = sourceTargets
	if reachabilityCache then
		local unitDefID = spGetUnitDefID(unitID)
		unitTargets = filterTargetsReachableByUnitDef(unitDefID, sourceTargets, positionCache, reachabilityCache)
	end
	if #unitTargets == 0 then
		return
	end
	for targetIndex = 1, #unitTargets do
		targets[targetIndex] = unitTargets[targetIndex]
	end
	for targetIndex = #unitTargets + 1, #targets do
		targets[targetIndex] = nil
	end
	sortTargetsByTravelRoute(unitID, targets, not options.meta or options.shift, positionCache)
	singleUnitArray[1] = unitID
	giveOrders(commandID, singleUnitArray, targets, options)
end

local function giveOrdersPerUnitByTravelRoute(commandID, selectedUnits, filteredTargets, options, positionCache, reachabilityCache)
	local singleUnitArray = {}
	local targets = {}
	for unitIndex = 1, #selectedUnits do
		giveUnitTravelRouteOrders(commandID, selectedUnits[unitIndex], filteredTargets, options, positionCache, COMMANDS_REQUIRING_CAPABILITY[commandID] and reachabilityCache or nil, targets, singleUnitArray)
	end
end

local function givePartitionedOrders(commandID, selectedUnits, filteredTargets, options, referenceTargetID, positionCache, reachabilityCache)
	local needsReachability = COMMANDS_REQUIRING_CAPABILITY[commandID]
	if #filteredTargets >= #selectedUnits then
		local center = resolvePartitionCenter(selectedUnits, filteredTargets, referenceTargetID, positionCache)
		local sortedTargets = copyArray(filteredTargets)
		local sortedUnits = copyArray(selectedUnits)
		if center then
			sortIDsByAngle(sortedTargets, center, positionCache)
			sortIDsByAngle(sortedUnits, center, positionCache)
		end
		local chunks = buildContiguousChunks(sortedTargets, #sortedUnits)
		local singleUnitArray = {}
		local targets = {}
		for unitIndex = 1, #sortedUnits do
			giveUnitTravelRouteOrders(commandID, sortedUnits[unitIndex], chunks[unitIndex], options, positionCache, needsReachability and reachabilityCache or nil, targets, singleUnitArray)
		end
	else
		local minimumCount = mathFloor(#selectedUnits / #filteredTargets)
		local remainderCount = #selectedUnits % #filteredTargets
		local unassignedUnits = {}
		for unitIndex = 1, #selectedUnits do
			unassignedUnits[selectedUnits[unitIndex]] = true
		end
		local sortedTargets = copyArray(filteredTargets)
		sortTargetsByDistance(selectedUnits, sortedTargets, true, referenceTargetID, positionCache)
		for targetIndex = 1, #sortedTargets do
			local targetID = sortedTargets[targetIndex]
			local count = minimumCount
			if targetIndex <= remainderCount then
				count = count + 1
			end
			local assignedUnits = pickClosestUnitsForTarget(targetID, selectedUnits, unassignedUnits, count, positionCache, needsReachability and reachabilityCache or nil)
			if #assignedUnits > 0 then
				giveOrders(commandID, assignedUnits, { targetID }, options)
			end
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
	[CMD.ATTACK] = commandRule({ "unit" }, ENEMY_UNITS),
	[CMD.CAPTURE] = commandRule({ "unit" }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET] = commandRule({ "unit" }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = commandRule({ "unit" }, ENEMY_UNITS),
	[CMD.GUARD] = commandRule({ "unit" }, ALLY_UNITS),
	[CMD.REPAIR] = commandRule({ "unit" }, ALLY_UNITS),
	[CMD.RECLAIM] = commandRule({ "unit", "feature" }, ALL_UNITS),
	[CMD.RESURRECT] = commandRule({ "feature" }),
}

local function unitMatchesAllegiance(unitID, targetAllegiance)
	local isNeutral = spGetUnitNeutral(unitID)
	if targetAllegiance == NEUTRAL_UNITS then
		return isNeutral
	end
	if isNeutral then
		return false
	end
	local isEnemy = spGetUnitAllyTeam(unitID) ~= myAllyTeamID
	if targetAllegiance == ENEMY_UNITS and not isEnemy then
		return false
	end
	if targetAllegiance == ALLY_UNITS and isEnemy then
		return false
	end
	return true
end

local function buildUnitDefMetadata()
	unitDefMetadataByID = {}
	commanderCorpseFeatureDefIDs = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local commandCapabilities = {}
		commandCapabilities[CMD.RECLAIM] = unitDef.canReclaim and unitDef.reclaimSpeed > 0 or nil
		commandCapabilities[CMD.RESURRECT] = unitDef.canResurrect and unitDef.resurrectSpeed > 0 or nil
		commandCapabilities[CMD.REPAIR] = unitDef.canRepair and unitDef.repairSpeed > 0 or nil
		commandCapabilities[CMD.CAPTURE] = unitDef.canCapture and unitDef.captureSpeed > 0 or nil
		unitDefMetadataByID[unitDefID] = {
			commandCapabilities = commandCapabilities,
			canFly = unitDef.canFly == true,
			capturable = unitDef.capturable == true,
			isScreenSelectBuilder = unitDef.isBuilder and unitDef.canRepair and not unitDef.isFactory,
		}
		local customParams = unitDef.customParams
		if customParams and (customParams.iscommander or customParams.isscavcommander) and unitDef.corpse then
			local corpseDef = FeatureDefNames[unitDef.corpse]
			if corpseDef and corpseDef.customParams and corpseDef.customParams.category == "corpses" then
				commanderCorpseFeatureDefIDs[corpseDef.id] = true
			end
		end
	end
end

local function getFeatureMetadata(rawFeatureID, metadataCache)
	local cachedMetadata = metadataCache[rawFeatureID]
	if cachedMetadata then
		return cachedMetadata
	end
	local featureDefID = spGetFeatureDefID(rawFeatureID)
	local featureDef = featureDefID and FeatureDefs[featureDefID]
	local metal, _, energy = spGetFeatureResources(rawFeatureID)
	local hasMetal = (featureDef and featureDef.metal and featureDef.metal > 0)
		or (metal and metal > 0)
		or false
	local hasEnergy = (featureDef and featureDef.energy and featureDef.energy > 0)
		or (energy and energy > 0)
		or false
	local category = featureDef and featureDef.customParams and featureDef.customParams.category
	local metadata = {
		featureDefID = featureDefID,
		category = category,
		hasMetal = hasMetal,
		isEnergyOnly = not hasMetal and hasEnergy,
		reclaimable = featureDef and featureDef.reclaimable,
		hasCurrentYield = (metal and metal > 0) or (energy and energy > 0) or false,
		isCommanderCorpse = featureDefID and commanderCorpseFeatureDefIDs[featureDefID] or false,
	}
	metadataCache[rawFeatureID] = metadata
	return metadata
end

local function featureMatchesReclaimReference(featureMetadata, referenceMetadata)
	if referenceMetadata.isCommanderCorpse or featureMetadata.isCommanderCorpse then
		return false
	end
	if referenceMetadata.category == "corpses" then
		return featureMetadata.category == "corpses"
			and featureMetadata.featureDefID == referenceMetadata.featureDefID
	end
	if referenceMetadata.isEnergyOnly then
		return featureMetadata.isEnergyOnly
	end
	if referenceMetadata.hasMetal then
		return featureMetadata.hasMetal
			and featureMetadata.category ~= "corpses"
	end
	return false
end

local function shouldIncludeVisibleFeature(featureID, commandID, metadataCache)
	if commandID == CMD.RESURRECT then
		local featureMetadata = getFeatureMetadata(featureID, metadataCache)
		if featureMetadata.resurrectable == nil then
			local unitDefName = spGetFeatureResurrect(featureID)
			featureMetadata.resurrectable = unitDefName ~= nil and unitDefName ~= ""
		end
		return featureMetadata.resurrectable
	end
	if commandID == CMD.RECLAIM then
		local featureMetadata = getFeatureMetadata(featureID, metadataCache)
		if not featureMetadata.featureDefID or featureMetadata.reclaimable == false then
			return false
		end
		if featureMetadata.hasCurrentYield then
			return true
		end
		return featureMetadata.reclaimable == true
	end
	return false
end

local function collectVisibleUnits(unitDefID, targetAllegiance, teamID)
	local filteredTargets = {}
	local visibleUnits = spring.GetVisibleUnits()
	if not visibleUnits then
		return filteredTargets
	end
	for unitIndex = 1, #visibleUnits do
		local unitID = visibleUnits[unitIndex]
		if (not unitDefID or spGetUnitDefID(unitID) == unitDefID)
			and (not targetAllegiance or unitMatchesAllegiance(unitID, targetAllegiance))
			and (not teamID or spGetUnitTeam(unitID) == teamID)
		then
			tableInsert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function collectVisibleFeaturesByPredicate(shouldIncludeFeature)
	local filteredTargets = {}
	local visibleFeatures = spring.GetVisibleFeatures(-1)
	if not visibleFeatures then
		return filteredTargets
	end
	for featureIndex = 1, #visibleFeatures do
		local featureID = visibleFeatures[featureIndex]
		if shouldIncludeFeature(featureID) then
			tableInsert(filteredTargets, normalizeFeatureTargetID(featureID))
		end
	end
	return filteredTargets
end

local function collectVisibleFeatures(commandID, featureDefID)
	local metadataCache = {}
	return collectVisibleFeaturesByPredicate(function(featureID)
		return (not featureDefID or spGetFeatureDefID(featureID) == featureDefID)
			and shouldIncludeVisibleFeature(featureID, commandID, metadataCache)
	end)
end

local function collectVisibleReclaimFeatures(referenceRawFeatureID, matchAllFeatures)
	local metadataCache = {}
	local referenceMetadata = getFeatureMetadata(referenceRawFeatureID, metadataCache)
	if referenceMetadata.isCommanderCorpse then
		return {}
	end
	return collectVisibleFeaturesByPredicate(function(featureID)
		local featureMetadata = getFeatureMetadata(featureID, metadataCache)
		if featureMetadata.isCommanderCorpse then
			return false
		end
		local matchesReference = matchAllFeatures
			or featureMatchesReclaimReference(featureMetadata, referenceMetadata)
		return shouldIncludeVisibleFeature(featureID, CMD.RECLAIM, metadataCache)
			and matchesReference
	end)
end

local function isValidMassOrderTarget(commandID, targetID, isFeature)
	local commandConfig = ALLOWED_COMMANDS[commandID]
	if not commandConfig then
		return false
	end
	if isFeature then
		if not commandConfig.allowedTargetTypes["feature"] then
			return false
		end
		if commandID == CMD.RESURRECT then
			local unitDefName = spGetFeatureResurrect(getRawFeatureID(targetID))
			if unitDefName == nil or unitDefName == "" then
				return false
			end
		end
		return true
	end
	if not commandConfig.allowedTargetTypes["unit"] then
		return false
	end
	local isEnemy = spGetUnitAllyTeam(targetID) ~= myAllyTeamID
	local allegiance = commandConfig.targetAllegiance
	if isEnemy and allegiance ~= ALL_UNITS and allegiance ~= ENEMY_UNITS then
		return false
	end
	if not isEnemy and allegiance == ENEMY_UNITS then
		return false
	end
	if commandID == CMD.CAPTURE and not isCapturableTargetUnit(targetID) then
		return false
	end
	return true
end

local function considerNearestCandidate(candidateID, isFeature, commandID, mouseX, mouseY, getScreenXY, nearestState)
	if not isValidMassOrderTarget(commandID, candidateID, isFeature) then
		return
	end
	local screenX, screenY = getScreenXY(candidateID)
	if not screenX then
		return
	end
	local candidateDistanceSq = mathDistance2dSquared(screenX, screenY, mouseX, mouseY)
	if candidateDistanceSq > doubleClickSnapRadiusSq then
		return
	end
	if nearestState.distanceSq == nil or candidateDistanceSq < nearestState.distanceSq then
		nearestState.targetID = candidateID
		nearestState.distanceSq = candidateDistanceSq
		nearestState.isFeature = isFeature
	end
end

local function resolveNearestValidTargetNearCursor(commandID, mouseX, mouseY)
	local commandConfig = ALLOWED_COMMANDS[commandID]
	if not commandConfig then
		return nil
	end
	local allowsUnits = commandConfig.allowedTargetTypes["unit"] == true
	local allowsFeatures = commandConfig.allowedTargetTypes["feature"] == true
	if not allowsUnits and not allowsFeatures then
		return nil
	end
	local nearestState = {}
	local getUnitScreenXY = function(unitID)
		local unitX, unitY, unitZ = spGetUnitViewPosition(unitID, true)
		if not unitX then
			return nil
		end
		return spWorldToScreenCoords(unitX, unitY, unitZ)
	end
	local getFeatureScreenXY = function(featureTargetID)
		local featureX, featureY, featureZ = spGetFeaturePosition(getRawFeatureID(featureTargetID))
		if not featureX then
			return nil
		end
		return spWorldToScreenCoords(featureX, featureY, featureZ)
	end
	if allowsUnits then
		local candidateUnits = spring.GetVisibleUnits()
		if candidateUnits then
			for unitIndex = 1, #candidateUnits do
				considerNearestCandidate(candidateUnits[unitIndex], false, commandID, mouseX, mouseY, getUnitScreenXY, nearestState)
			end
		end
	end
	if allowsFeatures then
		local candidateFeatures = spring.GetVisibleFeatures(-1)
		if candidateFeatures then
			for featureIndex = 1, #candidateFeatures do
				considerNearestCandidate(normalizeFeatureTargetID(candidateFeatures[featureIndex]), true, commandID, mouseX, mouseY, getFeatureScreenXY, nearestState)
			end
		end
	end
	return nearestState.targetID, nearestState.isFeature
end

local function filterTargetsBySelectionMembership(targets, selectionSet, targetInSelection)
	local filteredTargets = {}
	for targetIndex = 1, #targets do
		local targetID = targets[targetIndex]
		if isFeatureTargetID(targetID) then
			tableInsert(filteredTargets, targetID)
		elseif targetInSelection and selectionSet[targetID] then
			tableInsert(filteredTargets, targetID)
		elseif not targetInSelection and not selectionSet[targetID] then
			tableInsert(filteredTargets, targetID)
		end
	end
	return filteredTargets
end

local function collectScopedUnitTargets(commandID, targetID, targetAllegiance, teamID, options, applyFinalize)
	local unitDefIDFilter = nil
	if not options.ctrl then
		unitDefIDFilter = spGetUnitDefID(targetID)
		if not unitDefIDFilter then
			return {}
		end
	end
	local targets = collectVisibleUnits(unitDefIDFilter, targetAllegiance, teamID)
	if applyFinalize then
		return finalizeUnitTargets(commandID, targets)
	end
	return targets
end

local function collectMassOrderTargets(commandID, targetID, isFeature, options)
	if isFeature then
		local rawFeatureID = getRawFeatureID(targetID)
		if commandID == CMD.RECLAIM then
			return collectVisibleReclaimFeatures(rawFeatureID, options.ctrl)
		end
		local featureDefID = spGetFeatureDefID(rawFeatureID)
		if not featureDefID then
			return {}
		end
		local featureDefIDFilter = featureDefID
		if options.ctrl then
			featureDefIDFilter = nil
		end
		return collectVisibleFeatures(commandID, featureDefIDFilter)
	end
	local commandConfig = ALLOWED_COMMANDS[commandID]
	local isNeutral = spGetUnitNeutral(targetID)
	local isEnemy = spGetUnitAllyTeam(targetID) ~= myAllyTeamID
	if isNeutral and (commandConfig.targetAllegiance == ENEMY_UNITS or commandID == CMD.RECLAIM) then
		return collectScopedUnitTargets(commandID, targetID, NEUTRAL_UNITS, nil, options, true)
	end
	if commandConfig.targetAllegiance == ENEMY_UNITS or (commandID == CMD.RECLAIM and isEnemy) then
		return collectScopedUnitTargets(commandID, targetID, ENEMY_UNITS, nil, options, true)
	end
	if not isEnemy and (commandID == CMD.REPAIR or commandID == CMD.RECLAIM) then
		local targetTeamID = spGetUnitTeam(targetID)
		if not targetTeamID then
			return {}
		end
		if commandID == CMD.REPAIR then
			return collectScopedUnitTargets(commandID, targetID, ALLY_UNITS, targetTeamID, options, true)
		end
		if targetTeamID ~= myTeamID then
			return { targetID }
		end
		return collectScopedUnitTargets(commandID, targetID, ALLY_UNITS, myTeamID, options, false)
	end
	local fallbackAllegiance = options.ctrl and ALLY_UNITS or commandConfig.targetAllegiance
	return collectScopedUnitTargets(commandID, targetID, fallbackAllegiance, nil, options, true)
end

local function issueMassOrdersFromTarget(issueCommandID, referenceTargetID, referenceTargetIsFeature, selectedUnits, options)
	selectedUnits = filterUnitsForCommand(selectedUnits, issueCommandID)
	if #selectedUnits == 0 then
		return false
	end
	local builderUnits = {}
	if issueCommandID == CMD.GUARD then
		local nonBuilderUnits
		builderUnits, nonBuilderUnits = splitBuilderUnits(selectedUnits)
		if #builderUnits > 0 then
			giveOrders(issueCommandID, builderUnits, { referenceTargetID }, options)
		end
		if #nonBuilderUnits == 0 then
			finishMassOrderCommandState(issueCommandID, options)
			return true
		end
		selectedUnits = nonBuilderUnits
	end
	local selectionSet = {}
	for unitIndex = 1, #selectedUnits do
		selectionSet[selectedUnits[unitIndex]] = true
	end
	local targetInSelection = not referenceTargetIsFeature and selectionSet[referenceTargetID] == true
	local filteredTargets = collectMassOrderTargets(issueCommandID, referenceTargetID, referenceTargetIsFeature, options)
	filteredTargets = filterTargetsBySelectionMembership(filteredTargets, selectionSet, targetInSelection)
	local positionCache = {}
	local reachabilityCache = {}
	if COMMANDS_REQUIRING_CAPABILITY[issueCommandID] then
		filteredTargets = filterTargetsReachableByAnyUnit(selectedUnits, filteredTargets, positionCache, reachabilityCache)
	end
	local usePartitionedDispatch, maxTargetsPerUnit, maxTargetsToCollect = resolveMassOrderBudget(#selectedUnits, #filteredTargets, options.alt)
	filteredTargets = limitTargetsByRadius(filteredTargets, referenceTargetID, selectedUnits, maxTargetsToCollect, positionCache)
	if #filteredTargets == 0 or maxTargetsPerUnit <= 0 then
		if #builderUnits > 0 then
			finishMassOrderCommandState(issueCommandID, options)
			return true
		end
		return false
	end
	if usePartitionedDispatch then
		givePartitionedOrders(issueCommandID, selectedUnits, filteredTargets, options, referenceTargetID, positionCache, reachabilityCache)
	else
		giveOrdersPerUnitByTravelRoute(issueCommandID, selectedUnits, filteredTargets, options, positionCache, reachabilityCache)
	end
	finishMassOrderCommandState(issueCommandID, options)
	return true
end

local function issuePendingDoubleClickMassOrders(options)
	local issueCommandID = pendingDoubleClick.commandID
	local referenceTargetID = pendingDoubleClick.targetID
	if not referenceTargetID then
		return false
	end
	local referenceTargetIsFeature = isFeatureTargetID(referenceTargetID)
	clearDoubleClickPending()
	local selectedUnits = spring.GetSelectedUnits()
	local massIssued = false
	local skipMassReissue = false
	if issueCommandID == CMD.RECLAIM and not referenceTargetIsFeature then
		local isEnemy = spGetUnitAllyTeam(referenceTargetID) ~= myAllyTeamID
		local targetTeamID = spGetUnitTeam(referenceTargetID)
		if not isEnemy and targetTeamID and targetTeamID ~= myTeamID then
			skipMassReissue = true
		end
	end
	if not skipMassReissue and #selectedUnits > 0 then
		massIssued = issueMassOrdersFromTarget(issueCommandID, referenceTargetID, referenceTargetIsFeature, selectedUnits, options)
	end
	if not massIssued then
		clearActiveCommandUnlessShift(options)
	end
	return true
end

local function resolveScreenSelectCommandID(commandID)
	if commandID ~= nil then
		return commandID
	end
	local _, activeCommandID = spring.GetActiveCommand()
	if activeCommandID and ALLOWED_COMMANDS[activeCommandID] then
		return activeCommandID
	end
	return nil
end

local function consumePendingDoubleClickClick(options, effectiveCommandID)
	if not doubleClickEnabled or not isPendingDoubleClickActive() then
		return false
	end
	if pendingDoubleClick.right ~= options.right then
		return false
	end
	if effectiveCommandID and pendingDoubleClick.commandID ~= effectiveCommandID then
		return false
	end
	if not pendingDoubleClick.targetID then
		clearDoubleClickPending()
		return true
	end
	return issuePendingDoubleClickMassOrders(options)
end

local function armPendingDoubleClick(commandID, targetID, options)
	pendingDoubleClick.targetID = targetID
	pendingDoubleClick.expireTime = osClock() + DOUBLE_CLICK_TIME
	pendingDoubleClick.commandID = commandID
	pendingDoubleClick.right = options.right
	if options.shift then
		heldCommandDescriptionIndex = captureHeldCommandDescriptionIndex(commandID)
	end
end

local function handleScreenSelectCommand(effectiveCommandID, parameters, options)
	local targetID = parameters[1]
	local isFeature = isFeatureTargetID(targetID)

	if not isValidMassOrderTarget(effectiveCommandID, targetID, isFeature) then
		return false
	end

	local selectedUnits = spring.GetSelectedUnits()
	if #selectedUnits == 0 then
		return false
	end
	if screenSelectKeyHeld then
		return issueMassOrdersFromTarget(effectiveCommandID, targetID, isFeature, selectedUnits, options)
	end

	if doubleClickEnabled then
		if not isPendingDoubleClickActive() then
			armPendingDoubleClick(effectiveCommandID, targetID, options)
		elseif not pendingDoubleClick.targetID then
			pendingDoubleClick.targetID = targetID
		end
		return false
	end

	selectedUnits = filterUnitsForCommand(selectedUnits, effectiveCommandID)
	if #selectedUnits == 0 then
		return false
	end
	giveOrders(effectiveCommandID, selectedUnits, { targetID }, options)
	if options.shift then
		heldCommandDescriptionIndex = captureHeldCommandDescriptionIndex(effectiveCommandID)
	else
		clearActiveCommandUnlessShift(options)
	end
	return true
end

local function isSetTargetCommand(commandID)
	return commandID == GameCMD.UNIT_SET_TARGET or commandID == GameCMD.UNIT_SET_TARGET_NO_GROUND
end

function widget:MousePress(mouseX, mouseY, button)
	if button ~= LEFT_MOUSE_BUTTON and button ~= RIGHT_MOUSE_BUTTON then
		return false
	end
	local options = fillCommandOptionModifiers({ right = (button == RIGHT_MOUSE_BUTTON) })
	local effectiveCommandID = resolveScreenSelectCommandID(nil)
	local pendingClickActive = isPendingDoubleClickActive()
	if isSetTargetCommand(effectiveCommandID) and options.alt then
		clearDoubleClickPending()
		return false
	end
	if not doubleClickEnabled then
		return false
	end
	if not pendingClickActive then
		if not effectiveCommandID or not ALLOWED_COMMANDS[effectiveCommandID] then
			return false
		end
		local targetID, targetIsFeature = resolveNearestValidTargetNearCursor(effectiveCommandID, mouseX, mouseY)
		if screenSelectKeyHeld then
			if not targetID then
				return false
			end
			local selectedUnits = spring.GetSelectedUnits()
			if #selectedUnits == 0 then
				return false
			end
			return issueMassOrdersFromTarget(effectiveCommandID, targetID, targetIsFeature, selectedUnits, options)
		end
		armPendingDoubleClick(effectiveCommandID, targetID, options)
		return false
	end
	local consumed = consumePendingDoubleClickClick(options, effectiveCommandID)
	if consumed then
		return true
	end
	if not effectiveCommandID then
		clearDoubleClickPending()
		return true
	end
	return false
end

function widget:CommandNotify(commandID, parameters, options)
	local effectiveCommandID = resolveScreenSelectCommandID(commandID)
	if #parameters ~= 1 and not isSetTargetCommand(effectiveCommandID) then
		return false
	end
	options = fillCommandOptionModifiers(options)
	if isSetTargetCommand(effectiveCommandID) and options.alt then
		clearDoubleClickPending()
		return false
	end
	if #parameters == 1 then
		return handleScreenSelectCommand(effectiveCommandID, parameters, options)
	end
	return false
end

local function setDoubleClickEnabled(value)
	doubleClickEnabled = value == true
	if not doubleClickEnabled then
		clearDoubleClickPending()
	end
end

local function coercePositiveInt(value)
	local numericValue = tonumber(value)
	if not numericValue then
		return nil
	end
	return mathMax(1, mathFloor(numericValue))
end

local function setMaxMassOrderTargets(value)
	local numericValue = coercePositiveInt(value)
	if numericValue then
		maxMassOrderTargets = numericValue
	end
end

local function setCommandLimit(value)
	local numericValue = coercePositiveInt(value)
	if numericValue then
		commandLimit = numericValue
	end
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
	clearDoubleClickPending()
	if spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
	myAllyTeamID = spring.GetMyAllyTeamID()
	myTeamID = spring.GetMyTeamID()
	buildUnitDefMetadata()
end

function widget:PlayerChanged()
	heldCommandDescriptionIndex = nil
	initialize()
end

function widget:ViewResize()
	updateDoubleClickSnapRadius()
end

function widget:Initialize()
	updateDoubleClickSnapRadius()
	initialize()
	if spring.GetSpectatingState() then
		return
	end
	widgetHandler:AddAction("screen_select_hold", function() screenSelectKeyHeld = true end, nil, "p")
	widgetHandler:AddAction("screen_select_hold", function() screenSelectKeyHeld = false end, nil, "r")
	registerScreenSelectCommandsApi()
end

function widget:Shutdown()
	widgetHandler:RemoveAction("screen_select_hold", "p")
	widgetHandler:RemoveAction("screen_select_hold", "r")
	WG["screenSelectCommands"] = nil
	screenSelectKeyHeld = false
end

function widget:Update()
	if deferClearActiveCommand then
		deferClearActiveCommand = false
		spring.SetActiveCommand(0)
	end
	updateShiftCommandKeep()
end

function widget:ActiveCommandChanged(commandID)
	if commandID then
		if pendingDoubleClick.commandID and pendingDoubleClick.commandID ~= commandID then
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
