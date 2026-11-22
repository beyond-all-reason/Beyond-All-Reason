local widget = widget ---@type RulesUnsyncedCallins

function widget:GetInfo()
	return {
		name = "Screen Select Commands",
		desc = "Mass-issue unit-target commands to visible matches inside a circle around the click. Click again while pending, or use the keybind + click for mass orders.",
		author = "SethDGamre, advised by Chronographer",
		date = "July 11, 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

--[[------------------------------------------------------------------------------
How To Use:
  First click issues a normal order. Another click while pending mass-orders matches inside the circle around that click.
  Double right-click mass-orders a default command only when that option is enabled.
  Optionally, bind and hold screen_select_hold to mass-order on the first click instead.

Click modifiers:
  Shift -> add to end of queue (always additive; never toggles/removes an existing matching order)
  Space -> prepend to the queue
  Shift + Space -> insert into the nearest queued path segment
  Ctrl -> expand scope to all visible same-alignment targets (enemies: any enemy excluding neutrals; neutrals: all neutrals; allies: any ally team). For reclaim features, mass-order all reclaimable features (commander corpses still excluded).
  Alt -> split the targets evenly across every selected unit
  Shift / Shift + Space / double-click mass-order -> after the click-nearest target set is chosen, travel uses each unit's last positional queued order before the mass order, not its current position. Double-click snapshots that queue-end position on the first click; Shift double-click also removes the priming click's trailing order before appending the mass route.

  Order assignment:
  Targets and units are sorted by angle around the selection and cut into equal sweeps. Each sweep is ordered by distance from the units on it.
  Normal mass-order -> every selected unit gets every target while units × targets stays under 4000. Past that, the units are divided into the fewest sweeps that keep the issued orders under 4000.
  Alt -> one sweep per unit. When there are more units than targets, the extra units share sweeps.
  "reduced" fades out above the cursor when targets were dropped to stay under 4000 orders.

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
local mathCeil = math.ceil
local mathHuge = math.huge
local mathAtan2 = math.atan2
local mathDistance2dSquared = math.distance2dSquared
local mathCos = math.cos
local mathSin = math.sin
local mathPi = math.pi
local osClock = os.clock

local spring = Spring

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
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
local COMMAND_CIRCLE_COLORS = {
	[CMD.ATTACK] = { 1, 0.5, 0.35 },
	[CMD.CAPTURE] = { 1, 0.85, 0.22 },
	[CMD.REPAIR] = { 1, 0.95, 0.7 },
	[CMD.RECLAIM] = { 0.43, 0.5, 0.43 },
	[CMD.RESURRECT] = { 1, 0.75, 1 },
	[CMD.GUARD] = { 0.33, 0.92, 1 },
	[GameCMD.UNIT_SET_TARGET] = { 1, 0.66, 0.35 },
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = { 1, 0.66, 0.35 },
}
local CIRCLE_PREVIEW_COLOR = { 1, 1, 1 }
local DOUBLE_CLICK_RADIUS_FRACTION_DEFAULT = 0.25
local DOUBLE_CLICK_RADIUS_FRACTION_MIN = 0.125
local DOUBLE_CLICK_RADIUS_FRACTION_MAX = 1
local DOUBLE_CLICK_RADIUS_FRACTION_MAX_TOLERANCE = 0.001
local CIRCLE_FLASH_SECONDS = 0.45
local CIRCLE_PEAK_ALPHA = 0.1
local CIRCLE_SOLID_RADIUS_FRACTION = 0.85
local CIRCLE_PREVIEW_HOLD_SECONDS = 0.2
local CIRCLE_FAN_SEGMENT_COUNT = 48
local CIRCLE_FAN_RING_COUNT = 8
local RANGE_REDUCED_TEXT_SECONDS = CIRCLE_FLASH_SECONDS * 4
local RANGE_REDUCED_TEXT_PEAK_ALPHA = 1
local RANGE_REDUCED_TEXT_HOLD_FRACTION = 0.5
local RANGE_REDUCED_TEXT_SIZE_DIVISOR = 3
local RANGE_REDUCED_TEXT_SIZE_MULTIPLIER = 2
local RANGE_REDUCED_OUTLINE_SIZE = 0.03
local RANGE_REDUCED_OUTLINE_STRENGTH = 0.7
local RANGE_REDUCED_OUTLINE_ALPHA = 0.55
local RANGE_REDUCED_CURSOR_GAP_FRACTION = 16 / 1080
local RANGE_REDUCED_TEXT_PADDING_SCALE = 0.2

local MAX_QUEUE_COMMANDS = 100
local DOUBLE_CLICK_TIME = Spring.GetConfigInt("DoubleClickTime", 200) / 1000
local DOUBLE_CLICK_SNAP_HEIGHT_FRACTION = 32 / 1080

local doubleClickEnabled = true
local doubleRightClickDefaultCommandEnabled = false
local doubleClickRadiusFraction = DOUBLE_CLICK_RADIUS_FRACTION_DEFAULT
local COMMAND_LIMIT = 4000
local ORDER_BUDGET = COMMAND_LIMIT - 1

local myAllyTeamID
local myTeamID
local unitDefMetadataByID = {}
local commanderCorpseFeatureDefIDs = {}
local pendingDoubleClick = {}
local pendingArmedFromCommandNotify = false
local lastRightClickScreenX
local lastRightClickScreenY
local heldCommandDescriptionIndex
local deferClearActiveCommand = false
local screenSelectKeyHeld = false
local circleFlash
local circlePreview
local circleShader
local circleShaderCenterLocation
local circleShaderRadiusLocation
local circleShaderColorLocation
local circleShaderAlphaLocation
local rangeReducedNotice
local rangeReducedTextTexture
local rangeReducedTextWidth = 0
local rangeReducedTextHeight = 0
local rangeReducedTextBakeFailed = false
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
		queueEndByUnitID = nil,
	}
	pendingArmedFromCommandNotify = false
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
	if options.right then
		heldCommandDescriptionIndex = nil
		return
	end
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

local function getTargetScreenPosition(targetID, isFeature)
	local worldX, worldY, worldZ
	if isFeature then
		worldX, worldY, worldZ = spGetFeaturePosition(getRawFeatureID(targetID))
	else
		worldX, worldY, worldZ = spGetUnitViewPosition(targetID, true)
	end
	if not worldX then
		return nil
	end
	return spWorldToScreenCoords(worldX, worldY, worldZ)
end

local function clampDoubleClickRadiusFraction(value)
	local numericValue = tonumber(value)
	if not numericValue then
		return DOUBLE_CLICK_RADIUS_FRACTION_DEFAULT
	end
	if numericValue < DOUBLE_CLICK_RADIUS_FRACTION_MIN then
		return DOUBLE_CLICK_RADIUS_FRACTION_MIN
	end
	if numericValue > DOUBLE_CLICK_RADIUS_FRACTION_MAX - DOUBLE_CLICK_RADIUS_FRACTION_MAX_TOLERANCE then
		return DOUBLE_CLICK_RADIUS_FRACTION_MAX
	end
	return numericValue
end

local function getDoubleClickRadius()
	local viewWidth, viewHeight = spring.GetViewGeometry()
	local longestViewDimension = viewWidth
	if viewHeight > viewWidth then
		longestViewDimension = viewHeight
	end
	return doubleClickRadiusFraction * longestViewDimension
end

local function getMassOrderCircleRadius()
	if doubleClickRadiusFraction >= DOUBLE_CLICK_RADIUS_FRACTION_MAX then
		return nil
	end
	return getDoubleClickRadius()
end

local function resolveClickScreenPosition(clickScreenX, clickScreenY)
	if clickScreenX ~= nil and clickScreenY ~= nil then
		return clickScreenX, clickScreenY
	end
	return spring.GetMouseState()
end

local function showCommandCircleFlash(centerX, centerY, radius, commandID)
	local color = COMMAND_CIRCLE_COLORS[commandID] or CIRCLE_PREVIEW_COLOR
	circleFlash = {
		centerX = centerX,
		centerY = centerY,
		radius = radius,
		red = color[1],
		green = color[2],
		blue = color[3],
		startTime = osClock(),
	}
end

local function showRangeReducedNotice(commandID)
	local color = COMMAND_CIRCLE_COLORS[commandID] or CIRCLE_PREVIEW_COLOR
	rangeReducedTextBakeFailed = false
	rangeReducedNotice = {
		startTime = osClock(),
		red = color[1],
		green = color[2],
		blue = color[3],
	}
end

local function refreshCirclePreview()
	circlePreview = {
		lastSetTime = osClock(),
	}
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

local function getLastQueuedOrderPosition(unitID, positionCache)
	local commandQueue = spGetUnitCommands(unitID, MAX_QUEUE_COMMANDS)
	if not commandQueue or #commandQueue == 0 then
		return nil
	end
	for commandIndex = #commandQueue, 1, -1 do
		local commandPosition = getQueuedCommandPosition(commandQueue[commandIndex], positionCache)
		if commandPosition then
			return commandPosition
		end
	end
	return nil
end

local function collectQueueEndPositions(selectedUnits)
	local positions = {}
	local positionCache = {}
	for unitIndex = 1, #selectedUnits do
		local unitID = selectedUnits[unitIndex]
		local queueEndPosition = getLastQueuedOrderPosition(unitID, positionCache)
		if queueEndPosition then
			positions[unitID] = queueEndPosition
		end
	end
	return positions
end

local function seedUnitQueueEndPositions(selectedUnits, positionCache, queueEndByUnitID)
	local unitPositions = queueEndByUnitID or collectQueueEndPositions(selectedUnits)
	for unitIndex = 1, #selectedUnits do
		local unitID = selectedUnits[unitIndex]
		local queueEndPosition = unitPositions[unitID]
		if queueEndPosition then
			positionCache[unitID] = queueEndPosition
		end
	end
end

local function removeTrailingReferenceOrders(selectedUnits, referenceTargetID)
	local referenceOrderParamID = toFeatureOrderParamID(referenceTargetID)
	local singleUnitArray = {}
	for unitIndex = 1, #selectedUnits do
		local unitID = selectedUnits[unitIndex]
		local commandQueue = spGetUnitCommands(unitID, MAX_QUEUE_COMMANDS)
		if commandQueue and #commandQueue > 0 then
			local lastCommand = commandQueue[#commandQueue]
			local parameters = lastCommand.params
			local commandParam = parameters and parameters[1] or nil
			if lastCommand.tag
				and (commandParam == referenceTargetID or commandParam == referenceOrderParamID)
			then
				singleUnitArray[1] = unitID
				spGiveOrderToUnitArray(singleUnitArray, CMD.REMOVE, { lastCommand.tag }, 0)
			end
		end
	end
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

local function giveDistributedOrders(commandID, selectedUnits, filteredTargets, options, positionCache, reachabilityCache, distributeEvenly)
	local FULL_TURN = mathPi * 2

	local function wrapAngle(angle)
		local wrappedAngle = angle % FULL_TURN
		if wrappedAngle < 0 then
			wrappedAngle = wrappedAngle + FULL_TURN
		end
		return wrappedAngle
	end

	local function rotationRank(angle, startAngle)
		local delta = angle - startAngle
		if delta < 0 then
			delta = delta + FULL_TURN
		end
		return delta
	end

	local function collectAngledEntries(ids, center, positionCache)
		local entries = {}
		local unpositionedIDs = {}
		for index = 1, #ids do
			local id = ids[index]
			local position = getTargetPosition(id, positionCache)
			if position and center then
				entries[#entries + 1] = {
					id = id,
					angle = wrapAngle(mathAtan2(position.z - center.z, position.x - center.x)),
				}
			else
				unpositionedIDs[#unpositionedIDs + 1] = id
			end
		end
		return entries, unpositionedIDs
	end

	local function findSweepStartAngle(entryLists)
		local angles = {}
		for listIndex = 1, #entryLists do
			local entries = entryLists[listIndex]
			for index = 1, #entries do
				angles[#angles + 1] = entries[index].angle
			end
		end
		local angleCount = #angles
		if angleCount < 1 then
			return 0
		end
		tableSort(angles)
		if angleCount < 2 then
			return angles[1]
		end
		local largestGap = -1
		local seamAngle = angles[1]
		for index = 1, angleCount do
			local angle = angles[index]
			local nextAngle
			if index == angleCount then
				nextAngle = angles[1] + FULL_TURN
			else
				nextAngle = angles[index + 1]
			end
			local gap = nextAngle - angle
			if gap > largestGap then
				largestGap = gap
				seamAngle = wrapAngle(angle + (gap * 0.5))
			end
		end
		return seamAngle
	end

	local function sortEntriesByRotation(entries, startAngle)
		tableSort(entries, function(entryA, entryB)
			local rankA = rotationRank(entryA.angle, startAngle)
			local rankB = rotationRank(entryB.angle, startAngle)
			if rankA == rankB then
				return entryA.id < entryB.id
			end
			return rankA < rankB
		end)
	end

	local function idsFromEntries(entries)
		local ids = {}
		for index = 1, #entries do
			ids[index] = entries[index].id
		end
		return ids
	end

	local function buildEvenSlices(ids, sliceCount)
		local idCount = #ids
		if sliceCount > idCount then
			sliceCount = idCount
		end
		if sliceCount < 1 then
			sliceCount = 1
		end
		local baseCount = mathFloor(idCount / sliceCount)
		local extraCount = idCount % sliceCount
		local slices = {}
		local nextIndex = 1
		for sliceIndex = 1, sliceCount do
			local sliceSize = baseCount
			if sliceIndex <= extraCount then
				sliceSize = sliceSize + 1
			end
			local slice = {}
			for offset = 1, sliceSize do
				slice[offset] = ids[nextIndex]
				nextIndex = nextIndex + 1
			end
			slices[sliceIndex] = slice
		end
		return slices
	end

	local function appendToSmallestSlice(slices, id)
		local smallestIndex = 1
		for sliceIndex = 2, #slices do
			if #slices[sliceIndex] < #slices[smallestIndex] then
				smallestIndex = sliceIndex
			end
		end
		local slice = slices[smallestIndex]
		slice[#slice + 1] = id
	end

	local function sortIDsByDistance(ids, origin, positionCache)
		if not origin or #ids < 2 then
			return
		end
		local distances = {}
		for index = 1, #ids do
			local id = ids[index]
			local position = getTargetPosition(id, positionCache)
			if position then
				distances[id] = mathDistance2dSquared(origin.x, origin.z, position.x, position.z)
			else
				distances[id] = mathHuge
			end
		end
		tableSort(ids, function(idA, idB)
			local distanceA = distances[idA]
			local distanceB = distances[idB]
			if distanceA == distanceB then
				return idA < idB
			end
			return distanceA < distanceB
		end)
	end

	local function copyTargetIDs(sourceIDs)
		local copiedIDs = {}
		for index = 1, #sourceIDs do
			copiedIDs[index] = sourceIDs[index]
		end
		return copiedIDs
	end

	local function worstCaseGroupedOrderCount(unitCount, targetCount, groupCount)
		local unitBase = mathFloor(unitCount / groupCount)
		local unitRemainder = unitCount % groupCount
		local targetBase = mathFloor(targetCount / groupCount)
		local targetRemainder = targetCount % groupCount
		local orders = 0
		local largeUnitGroupsRemaining = unitRemainder
		local largeTargetGroupsRemaining = targetRemainder
		for groupIndex = 1, groupCount do
			local unitsInGroup = unitBase
			if largeUnitGroupsRemaining > 0 then
				unitsInGroup = unitsInGroup + 1
				largeUnitGroupsRemaining = largeUnitGroupsRemaining - 1
			end
			local targetsInGroup = targetBase
			if largeTargetGroupsRemaining > 0 then
				targetsInGroup = targetsInGroup + 1
				largeTargetGroupsRemaining = largeTargetGroupsRemaining - 1
			end
			orders = orders + (unitsInGroup * targetsInGroup)
		end
		return orders
	end

	local function findFewestDriverGroupCount(unitCount, targetCount)
		if unitCount < 2 or targetCount < 2 then
			return 1
		end
		if (unitCount * targetCount) < COMMAND_LIMIT then
			return 1
		end
		local maximumGroupCount = unitCount
		if targetCount < maximumGroupCount then
			maximumGroupCount = targetCount
		end
		for groupCount = 2, maximumGroupCount do
			if worstCaseGroupedOrderCount(unitCount, targetCount, groupCount) < COMMAND_LIMIT then
				return groupCount
			end
		end
		return maximumGroupCount
	end

	local function trimUnitTargetsToBudget(targetsByUnit, unitIDs, orderBudget)
		local totalOrders = 0
		local orderCounts = {}
		for unitIndex = 1, #unitIDs do
			local orderCount = #(targetsByUnit[unitIDs[unitIndex]] or {})
			orderCounts[unitIndex] = orderCount
			totalOrders = totalOrders + orderCount
		end
		if totalOrders <= orderBudget then
			return false
		end
		local excessOrders = totalOrders - orderBudget
		while excessOrders > 0 do
			local longestUnitIndex = 1
			for unitIndex = 2, #unitIDs do
				if orderCounts[unitIndex] > orderCounts[longestUnitIndex] then
					longestUnitIndex = unitIndex
				end
			end
			if orderCounts[longestUnitIndex] < 1 then
				break
			end
			orderCounts[longestUnitIndex] = orderCounts[longestUnitIndex] - 1
			excessOrders = excessOrders - 1
		end
		for unitIndex = 1, #unitIDs do
			local targetIDs = targetsByUnit[unitIDs[unitIndex]]
			if targetIDs then
				local keepCount = orderCounts[unitIndex]
				for targetIndex = keepCount + 1, #targetIDs do
					targetIDs[targetIndex] = nil
				end
			end
		end
		return true
	end

	local function issueUnitTargetOrders(commandID, unitID, orderedTargetIDs, options, positionCache)
		local targetCount = #orderedTargetIDs
		if targetCount < 1 then
			return
		end
		local orders = {}
		local setTargetCommand = commandID == GameCMD.UNIT_SET_TARGET or commandID == GameCMD.UNIT_SET_TARGET_NO_GROUND
		if setTargetCommand or not options.meta then
			local shiftedOptionBits = getCommandOptionBits(options, true)
			local baseOptionBits = getCommandOptionBits(options, false)
			for targetIndex = 1, targetCount do
				local optionBits = baseOptionBits
				if targetIndex > 1 or options.shift then
					optionBits = shiftedOptionBits
				end
				orders[targetIndex] = {
					commandID,
					{ toFeatureOrderParamID(orderedTargetIDs[targetIndex]) },
					optionBits,
				}
			end
		else
			local innerOptionBits = getCommandOptionBits(options, false)
			local insertionPosition = 0
			local reverseOrder = true
			if options.shift then
				local targetCentroid = getTargetCentroid(orderedTargetIDs, positionCache)
				local queuedInsertionPosition = findQueueInsertionPosition(unitID, targetCentroid, positionCache)
				if queuedInsertionPosition == nil then
					insertionPosition = -1
					reverseOrder = false
				else
					insertionPosition = queuedInsertionPosition
				end
			end
			if reverseOrder then
				local orderCount = 0
				for targetIndex = targetCount, 1, -1 do
					orderCount = orderCount + 1
					orders[orderCount] = {
						CMD.INSERT,
						{ insertionPosition, commandID, innerOptionBits, toFeatureOrderParamID(orderedTargetIDs[targetIndex]) },
						CMD.OPT_ALT,
					}
				end
			else
				for targetIndex = 1, targetCount do
					orders[targetIndex] = {
						CMD.INSERT,
						{ insertionPosition, commandID, innerOptionBits, toFeatureOrderParamID(orderedTargetIDs[targetIndex]) },
						CMD.OPT_ALT,
					}
				end
			end
		end
		spGiveOrderArrayToUnit(unitID, orders)
	end

	local function assignSliceTargets(targetsByUnit, unitIDs, sharedTargets, needsReachability)
		for unitIndex = 1, #unitIDs do
			local unitID = unitIDs[unitIndex]
			local unitTargets = copyTargetIDs(sharedTargets)
			if needsReachability then
				local unitDefID = spGetUnitDefID(unitID)
				unitTargets = filterTargetsReachableByUnitDef(unitDefID, unitTargets, positionCache, reachabilityCache)
			end
			targetsByUnit[unitID] = unitTargets
		end
	end

	local unitCount = #selectedUnits
	local targetCount = #filteredTargets
	if unitCount < 1 or targetCount < 1 then
		return false
	end
	local groupCount = 1
	if distributeEvenly then
		groupCount = unitCount
		if targetCount < groupCount then
			groupCount = targetCount
		end
	else
		groupCount = findFewestDriverGroupCount(unitCount, targetCount)
	end
	local needsReachability = reachabilityCache and COMMANDS_REQUIRING_CAPABILITY[commandID]
	local targetsByUnit = {}
	if groupCount < 2 then
		local sharedTargets = copyTargetIDs(filteredTargets)
		local origin = getTargetCentroid(selectedUnits, positionCache) or getTargetCentroid(filteredTargets, positionCache)
		sortIDsByDistance(sharedTargets, origin, positionCache)
		assignSliceTargets(targetsByUnit, selectedUnits, sharedTargets, needsReachability)
	else
		local center = getTargetCentroid(selectedUnits, positionCache) or getTargetCentroid(filteredTargets, positionCache)
		local targetEntries, unpositionedTargetIDs = collectAngledEntries(filteredTargets, center, positionCache)
		local unitEntries, unpositionedUnitIDs = collectAngledEntries(selectedUnits, center, positionCache)
		local targetSlices
		local unitSlices
		if not center or #targetEntries < 1 or #unitEntries < 1 then
			targetSlices = buildEvenSlices(filteredTargets, groupCount)
			unitSlices = buildEvenSlices(selectedUnits, groupCount)
		else
			if #targetEntries < groupCount then
				groupCount = #targetEntries
			end
			if #unitEntries < groupCount then
				groupCount = #unitEntries
			end
			local startAngle = findSweepStartAngle({ targetEntries, unitEntries })
			sortEntriesByRotation(targetEntries, startAngle)
			sortEntriesByRotation(unitEntries, startAngle)
			targetSlices = buildEvenSlices(idsFromEntries(targetEntries), groupCount)
			unitSlices = buildEvenSlices(idsFromEntries(unitEntries), groupCount)
			for unpositionedIndex = 1, #unpositionedTargetIDs do
				appendToSmallestSlice(targetSlices, unpositionedTargetIDs[unpositionedIndex])
			end
			for unpositionedIndex = 1, #unpositionedUnitIDs do
				appendToSmallestSlice(unitSlices, unpositionedUnitIDs[unpositionedIndex])
			end
			for sliceIndex = 1, #targetSlices do
				local origin = getTargetCentroid(unitSlices[sliceIndex], positionCache) or center
				sortIDsByDistance(targetSlices[sliceIndex], origin, positionCache)
			end
		end
		local sliceCount = #unitSlices
		if #targetSlices < sliceCount then
			sliceCount = #targetSlices
		end
		for sliceIndex = 1, sliceCount do
			assignSliceTargets(targetsByUnit, unitSlices[sliceIndex], targetSlices[sliceIndex], needsReachability)
		end
		for unitIndex = 1, unitCount do
			local unitID = selectedUnits[unitIndex]
			if not targetsByUnit[unitID] then
				targetsByUnit[unitID] = {}
			end
		end
	end
	local ordersWereTrimmed = trimUnitTargetsToBudget(targetsByUnit, selectedUnits, ORDER_BUDGET)
	for unitIndex = 1, unitCount do
		local unitID = selectedUnits[unitIndex]
		local unitTargets = targetsByUnit[unitID]
		if unitTargets and #unitTargets > 0 then
			issueUnitTargetOrders(commandID, unitID, unitTargets, options, positionCache)
		end
	end
	return ordersWereTrimmed
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

local function considerNearestCandidate(candidateID, isFeature, commandID, mouseX, mouseY, nearestState)
	if not isValidMassOrderTarget(commandID, candidateID, isFeature) then
		return
	end
	local screenX, screenY = getTargetScreenPosition(candidateID, isFeature)
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
	if allowsUnits then
		local candidateUnits = spring.GetVisibleUnits()
		if candidateUnits then
			for unitIndex = 1, #candidateUnits do
				considerNearestCandidate(candidateUnits[unitIndex], false, commandID, mouseX, mouseY, nearestState)
			end
		end
	end
	if allowsFeatures then
		local candidateFeatures = spring.GetVisibleFeatures(-1)
		if candidateFeatures then
			for featureIndex = 1, #candidateFeatures do
				considerNearestCandidate(normalizeFeatureTargetID(candidateFeatures[featureIndex]), true, commandID, mouseX, mouseY, nearestState)
			end
		end
	end
	return nearestState.targetID, nearestState.isFeature
end

local function filterTargetsInsideScreenCircle(targets, centerX, centerY, radius)
	local radiusSquared = radius and radius * radius
	local filteredTargets = {}
	for targetIndex = 1, #targets do
		local targetID = targets[targetIndex]
		local screenX, screenY = getTargetScreenPosition(targetID, isFeatureTargetID(targetID))
		if screenX then
			local screenDistanceSquared = mathDistance2dSquared(screenX, screenY, centerX, centerY)
			if not radiusSquared or screenDistanceSquared <= radiusSquared then
				tableInsert(filteredTargets, targetID)
			end
		end
	end
	return filteredTargets
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

local function issueMassOrdersFromTarget(issueCommandID, referenceTargetID, referenceTargetIsFeature, selectedUnits, options, queueEndByUnitID, clickScreenX, clickScreenY)
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
	local centerX, centerY = resolveClickScreenPosition(clickScreenX, clickScreenY)
	local circleRadius = getMassOrderCircleRadius()
	filteredTargets = filterTargetsInsideScreenCircle(filteredTargets, centerX, centerY, circleRadius)
	local positionCache = {}
	local reachabilityCache = {}
	local useQueueEndReference = options.shift == true or queueEndByUnitID ~= nil
	if useQueueEndReference then
		seedUnitQueueEndPositions(selectedUnits, positionCache, queueEndByUnitID)
	end
	if COMMANDS_REQUIRING_CAPABILITY[issueCommandID] then
		filteredTargets = filterTargetsReachableByAnyUnit(selectedUnits, filteredTargets, positionCache, reachabilityCache)
	end
	local filteredTargetCount = #filteredTargets
	if circleRadius then
		showCommandCircleFlash(centerX, centerY, circleRadius, issueCommandID)
	end
	if filteredTargetCount == 0 then
		if #builderUnits > 0 then
			finishMassOrderCommandState(issueCommandID, options)
			return true
		end
		return false
	end
	if queueEndByUnitID and options.shift then
		removeTrailingReferenceOrders(selectedUnits, referenceTargetID)
	end
	local ordersWereTrimmed = giveDistributedOrders(issueCommandID, selectedUnits, filteredTargets, options, positionCache, reachabilityCache, options.alt == true)
	if ordersWereTrimmed then
		showRangeReducedNotice(issueCommandID)
	end
	finishMassOrderCommandState(issueCommandID, options)
	return true
end

local function issuePendingDoubleClickMassOrders(options, clickScreenX, clickScreenY)
	local issueCommandID = pendingDoubleClick.commandID
	local referenceTargetID = pendingDoubleClick.targetID
	if not referenceTargetID then
		return false
	end
	local referenceTargetIsFeature = isFeatureTargetID(referenceTargetID)
	local queueEndByUnitID = pendingDoubleClick.queueEndByUnitID
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
		massIssued = issueMassOrdersFromTarget(issueCommandID, referenceTargetID, referenceTargetIsFeature, selectedUnits, options, queueEndByUnitID, clickScreenX, clickScreenY)
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

local function allowsDefaultCommandDoubleRightClick(options)
	if not options.right then
		return true
	end
	return doubleRightClickDefaultCommandEnabled
end

local function consumePendingDoubleClickClick(options, effectiveCommandID, clickScreenX, clickScreenY)
	if not doubleClickEnabled or not allowsDefaultCommandDoubleRightClick(options) or not isPendingDoubleClickActive() then
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
	return issuePendingDoubleClickMassOrders(options, clickScreenX, clickScreenY)
end

local function armPendingDoubleClick(commandID, targetID, options, armedFromCommandNotify)
	local refreshQueueEnd = not isPendingDoubleClickActive()
	if refreshQueueEnd then
		clearDoubleClickPending()
	end
	pendingDoubleClick.targetID = targetID
	pendingDoubleClick.expireTime = osClock() + DOUBLE_CLICK_TIME
	pendingDoubleClick.commandID = commandID
	pendingDoubleClick.right = options.right
	pendingArmedFromCommandNotify = armedFromCommandNotify == true
	if refreshQueueEnd then
		pendingDoubleClick.queueEndByUnitID = collectQueueEndPositions(spring.GetSelectedUnits())
	end
	if options.right then
		heldCommandDescriptionIndex = nil
	elseif options.shift then
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
		return issueMassOrdersFromTarget(effectiveCommandID, targetID, isFeature, selectedUnits, options, nil, nil, nil)
	end

	if doubleClickEnabled then
		if not allowsDefaultCommandDoubleRightClick(options) then
			if isPendingDoubleClickActive() then
				clearDoubleClickPending()
			end
			return false
		end
		if not isPendingDoubleClickActive() then
			armPendingDoubleClick(effectiveCommandID, targetID, options, true)
		elseif options.right and pendingDoubleClick.right and pendingArmedFromCommandNotify then
			if pendingDoubleClick.commandID == effectiveCommandID and pendingDoubleClick.targetID then
				return issuePendingDoubleClickMassOrders(options, lastRightClickScreenX, lastRightClickScreenY)
			end
			armPendingDoubleClick(effectiveCommandID, targetID, options, true)
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
	if options.right then
		heldCommandDescriptionIndex = nil
	elseif options.shift then
		heldCommandDescriptionIndex = captureHeldCommandDescriptionIndex(effectiveCommandID)
	else
		clearActiveCommandUnlessShift(options)
	end
	return true
end

local function isSetTargetCommand(commandID)
	return commandID == GameCMD.UNIT_SET_TARGET or commandID == GameCMD.UNIT_SET_TARGET_NO_GROUND
end

-- Left-click double-clicks arm here. Right-click default commands arm from CommandNotify:
-- the engine queues that order until a later update, and selecting the command makes the
-- next right-click cancel it instead of queueing another one.
function widget:MousePress(mouseX, mouseY, button)
	if button ~= LEFT_MOUSE_BUTTON and button ~= RIGHT_MOUSE_BUTTON then
		return false
	end
	if button == RIGHT_MOUSE_BUTTON then
		lastRightClickScreenX = mouseX
		lastRightClickScreenY = mouseY
	end
	local options = fillCommandOptionModifiers({ right = (button == RIGHT_MOUSE_BUTTON) })
	local effectiveCommandID = resolveScreenSelectCommandID(nil)
	local pendingClickActive = isPendingDoubleClickActive()
	-- Alt+Set Target belongs to unit_alt_set_target_type; yield and drop any pending double-click
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
		if not allowsDefaultCommandDoubleRightClick(options) then
			return false
		end
		if options.right and not screenSelectKeyHeld then
			return false
		end
		--snap to closest because tiny units are hard to click, and a double click reasonably means you're trying to click a unit
		local targetID, targetIsFeature = resolveNearestValidTargetNearCursor(effectiveCommandID, mouseX, mouseY)
		if screenSelectKeyHeld then
			if not targetID then
				return false
			end
			local selectedUnits = spring.GetSelectedUnits()
			if #selectedUnits == 0 then
				return false
			end
			return issueMassOrdersFromTarget(effectiveCommandID, targetID, targetIsFeature, selectedUnits, options, nil, mouseX, mouseY)
		end
		armPendingDoubleClick(effectiveCommandID, targetID, options, false)
		return false
	end
	if not allowsDefaultCommandDoubleRightClick(options) then
		clearDoubleClickPending()
		return false
	end
	local consumed = consumePendingDoubleClickClick(options, effectiveCommandID, mouseX, mouseY)
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

local function setDoubleRightClickDefaultCommandEnabled(value)
	doubleRightClickDefaultCommandEnabled = value == true
	if not doubleRightClickDefaultCommandEnabled and pendingDoubleClick.right then
		clearDoubleClickPending()
	end
end

local function setDoubleClickRadiusFraction(value, showPreview)
	doubleClickRadiusFraction = clampDoubleClickRadiusFraction(value)
	if showPreview ~= false then
		refreshCirclePreview()
	end
end

local function registerScreenSelectCommandsApi()
	WG["screenSelectCommands"] = {
		getDoubleClickEnabled = function()
			return doubleClickEnabled
		end,
		setDoubleClickEnabled = setDoubleClickEnabled,
		getDoubleRightClickDefaultCommandEnabled = function()
			return doubleRightClickDefaultCommandEnabled
		end,
		setDoubleRightClickDefaultCommandEnabled = setDoubleRightClickDefaultCommandEnabled,
		getDoubleClickRadiusFraction = function()
			return doubleClickRadiusFraction
		end,
		setDoubleClickRadiusFraction = setDoubleClickRadiusFraction,
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

local CIRCLE_SHADER_VERTEX = [[
varying vec2 screenPosition;
void main() {
	screenPosition = gl_Vertex.xy;
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
]]

local CIRCLE_SHADER_FRAGMENT = [[
varying vec2 screenPosition;
uniform vec2 center;
uniform float radius;
uniform vec3 circleColor;
uniform float circleAlpha;
void main() {
	float distanceFromCenter = length(screenPosition - center);
	float featherStart = radius * ]] .. CIRCLE_SOLID_RADIUS_FRACTION .. [[;
	float falloff = smoothstep(radius, featherStart, distanceFromCenter);
	if (falloff <= 0.0) {
		discard;
	}
	gl_FragColor = vec4(circleColor, falloff * circleAlpha);
}
]]

local function createCircleShader()
	if circleShader or not gl.CreateShader then
		return
	end
	circleShader = gl.CreateShader({
		vertex = CIRCLE_SHADER_VERTEX,
		fragment = CIRCLE_SHADER_FRAGMENT,
	})
	if not circleShader then
		spring.Echo("Screen Select Commands: circle shader failed to compile: " .. tostring(gl.GetShaderLog()))
		return
	end
	circleShaderCenterLocation = gl.GetUniformLocation(circleShader, "center")
	circleShaderRadiusLocation = gl.GetUniformLocation(circleShader, "radius")
	circleShaderColorLocation = gl.GetUniformLocation(circleShader, "circleColor")
	circleShaderAlphaLocation = gl.GetUniformLocation(circleShader, "circleAlpha")
end

local function deleteCircleShader()
	if circleShader then
		gl.DeleteShader(circleShader)
		circleShader = nil
	end
end

local circleRender = {}

function circleRender.quadraticFadeAlpha(elapsedSeconds, durationSeconds, peakAlpha)
	if elapsedSeconds < 0 then
		return peakAlpha
	end
	if elapsedSeconds >= durationSeconds then
		return 0
	end
	local remainingFraction = 1 - (elapsedSeconds / durationSeconds)
	return remainingFraction * remainingFraction * peakAlpha
end

function circleRender.circleFadeAlpha(elapsedSeconds)
	return circleRender.quadraticFadeAlpha(elapsedSeconds, CIRCLE_FLASH_SECONDS, CIRCLE_PEAK_ALPHA)
end

function circleRender.rangeReducedTextAlpha(elapsedSeconds)
	if elapsedSeconds <= 0 then
		return RANGE_REDUCED_TEXT_PEAK_ALPHA
	end
	if elapsedSeconds >= RANGE_REDUCED_TEXT_SECONDS then
		return 0
	end
	local holdSeconds = RANGE_REDUCED_TEXT_SECONDS * RANGE_REDUCED_TEXT_HOLD_FRACTION
	if elapsedSeconds <= holdSeconds then
		return RANGE_REDUCED_TEXT_PEAK_ALPHA
	end
	local fadeProgress = (elapsedSeconds - holdSeconds) / (RANGE_REDUCED_TEXT_SECONDS - holdSeconds)
	local fade = fadeProgress * fadeProgress * (3 - (2 * fadeProgress))
	return (1 - fade) * RANGE_REDUCED_TEXT_PEAK_ALPHA
end

function circleRender.smoothstepFalloff(distanceFromCenter, radius)
	local featherStart = radius * CIRCLE_SOLID_RADIUS_FRACTION
	if distanceFromCenter >= radius then
		return 0
	end
	if distanceFromCenter <= featherStart then
		return 1
	end
	local blend = 1 - ((distanceFromCenter - featherStart) / (radius - featherStart))
	return blend * blend * (3 - (2 * blend))
end

function circleRender.drawCircleFallback(centerX, centerY, radius, red, green, blue, alpha)
	local fullTurn = mathPi * 2
	for ringIndex = 0, CIRCLE_FAN_RING_COUNT - 1 do
		local innerDistance = radius * ringIndex / CIRCLE_FAN_RING_COUNT
		local outerDistance = radius * (ringIndex + 1) / CIRCLE_FAN_RING_COUNT
		local innerFalloff = circleRender.smoothstepFalloff(innerDistance, radius)
		local outerFalloff = circleRender.smoothstepFalloff(outerDistance, radius)
		gl.BeginEnd(GL.TRIANGLE_STRIP, function()
			for segmentIndex = 0, CIRCLE_FAN_SEGMENT_COUNT do
				local angle = (segmentIndex / CIRCLE_FAN_SEGMENT_COUNT) * fullTurn
				local cosine = mathCos(angle)
				local sine = mathSin(angle)
				gl.Color(red, green, blue, innerFalloff * alpha)
				gl.Vertex(centerX + (cosine * innerDistance), centerY + (sine * innerDistance))
				gl.Color(red, green, blue, outerFalloff * alpha)
				gl.Vertex(centerX + (cosine * outerDistance), centerY + (sine * outerDistance))
			end
		end)
	end
	gl.Color(1, 1, 1, 1)
end

function circleRender.drawCircle(centerX, centerY, radius, red, green, blue, alpha)
	if alpha <= 0 or radius <= 0 then
		return
	end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(false)
	if circleShader then
		gl.UseShader(circleShader)
		gl.Uniform(circleShaderCenterLocation, centerX, centerY)
		gl.Uniform(circleShaderRadiusLocation, radius)
		gl.Uniform(circleShaderColorLocation, red, green, blue)
		gl.Uniform(circleShaderAlphaLocation, alpha)
		gl.BeginEnd(GL.QUADS, function()
			gl.Vertex(centerX - radius, centerY - radius)
			gl.Vertex(centerX + radius, centerY - radius)
			gl.Vertex(centerX + radius, centerY + radius)
			gl.Vertex(centerX - radius, centerY + radius)
		end)
		gl.UseShader(0)
	else
		circleRender.drawCircleFallback(centerX, centerY, radius, red, green, blue, alpha)
	end
	gl.DepthTest(true)
end

function circleRender.drawCircleInViewPixels(centerX, centerY, radius, red, green, blue, alpha)
	local viewWidth, viewHeight = spring.GetViewGeometry()
	gl.DepthMask(false)
	gl.Culling(false)
	gl.MatrixMode(GL.PROJECTION)
	gl.PushMatrix()
	gl.LoadIdentity()
	gl.Ortho(0, viewWidth, 0, viewHeight, -1, 1)
	gl.MatrixMode(GL.MODELVIEW)
	gl.PushMatrix()
	gl.LoadIdentity()
	circleRender.drawCircle(centerX, centerY, radius, red, green, blue, alpha)
	gl.PopMatrix()
	gl.MatrixMode(GL.PROJECTION)
	gl.PopMatrix()
	gl.MatrixMode(GL.MODELVIEW)
	gl.Culling(true)
	gl.DepthMask(true)
end

function circleRender.drawCommandCircleFlash()
	if not circleFlash then
		return
	end
	local alpha = circleRender.circleFadeAlpha(osClock() - circleFlash.startTime)
	if alpha <= 0 then
		circleFlash = nil
		return
	end
	circleRender.drawCircleInViewPixels(circleFlash.centerX, circleFlash.centerY, circleFlash.radius, circleFlash.red, circleFlash.green, circleFlash.blue, alpha)
end

function circleRender.drawCirclePreview()
	if not circlePreview then
		return
	end
	local alpha = circleRender.circleFadeAlpha(osClock() - circlePreview.lastSetTime - CIRCLE_PREVIEW_HOLD_SECONDS)
	if alpha <= 0 then
		circlePreview = nil
		return
	end
	local viewWidth, viewHeight = spring.GetViewGeometry()
	local radius = getDoubleClickRadius()
	circleRender.drawCircle(viewWidth * 0.5, viewHeight * 0.5, radius, CIRCLE_PREVIEW_COLOR[1], CIRCLE_PREVIEW_COLOR[2], CIRCLE_PREVIEW_COLOR[3], alpha)
end

function circleRender.deleteRangeReducedTextTexture()
	if rangeReducedTextTexture then
		gl.DeleteTexture(rangeReducedTextTexture)
		rangeReducedTextTexture = nil
	end
end

function circleRender.drawRangeReducedTextIntoTexture(font, text, fontSize, padding, textureWidth, textureHeight)
	gl.Translate(-1, -1, 0)
	gl.Scale(2 / textureWidth, 2 / textureHeight, 0)
	font:Begin()
	font:SetAutoOutlineColor(false)
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, RANGE_REDUCED_OUTLINE_ALPHA)
	font:Print(text, padding, textureHeight * 0.5, fontSize, "vo")
	font:End()
end

function circleRender.bakeRangeReducedText()
	circleRender.deleteRangeReducedTextTexture()
	rangeReducedTextBakeFailed = true
	if not WG.fonts or not gl.CreateTexture or not gl.RenderToTexture then
		return false
	end
	local _, fullFontSize = WG.fonts.getFont(2)
	if not fullFontSize or fullFontSize <= 0 then
		return false
	end
	local fontSize = mathFloor(fullFontSize / RANGE_REDUCED_TEXT_SIZE_DIVISOR) * RANGE_REDUCED_TEXT_SIZE_MULTIPLIER
	if fontSize < 1 then
		fontSize = 1
	end
	local font = WG.fonts.getFont(2, fontSize / fullFontSize, RANGE_REDUCED_OUTLINE_SIZE, RANGE_REDUCED_OUTLINE_STRENGTH)
	if not font then
		return false
	end
	local text = BAR.I18N("ui.screenSelectCommands.rangeReduced")
	local textWidth = mathCeil(font:GetTextWidth(text) * fontSize)
	local textHeight, textDescender = font:GetTextHeight(text)
	local padding = mathCeil(fontSize * RANGE_REDUCED_TEXT_PADDING_SCALE)
	local textureWidth = textWidth + (padding * 2)
	local textureHeight = mathCeil((math.abs(textHeight) + math.abs(textDescender or 0)) * fontSize) + (padding * 2)
	if textureWidth <= 0 or textureHeight <= 0 then
		return false
	end
	local texture = gl.CreateTexture(textureWidth, textureHeight, {
		target = GL.TEXTURE_2D,
		format = GL.RGBA8,
		fbo = true,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
	if not texture then
		return false
	end
	local function drawText()
		circleRender.drawRangeReducedTextIntoTexture(font, text, fontSize, padding, textureWidth, textureHeight)
	end
	if gl.R2tHelper then
		gl.R2tHelper.RenderToTexture(texture, drawText, false)
	else
		gl.RenderToTexture(texture, function()
			gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
			drawText()
		end)
	end
	rangeReducedTextTexture = texture
	rangeReducedTextWidth = textureWidth
	rangeReducedTextHeight = textureHeight
	rangeReducedTextBakeFailed = false
	return true
end

function circleRender.drawRangeReducedNotice()
	if not rangeReducedNotice then
		return
	end
	local alpha = circleRender.rangeReducedTextAlpha(osClock() - rangeReducedNotice.startTime)
	if alpha <= 0 then
		rangeReducedNotice = nil
		return
	end
	if not rangeReducedTextTexture and not rangeReducedTextBakeFailed then
		circleRender.bakeRangeReducedText()
	end
	if not rangeReducedTextTexture then
		return
	end
	local mouseX, mouseY = spring.GetMouseState()
	local left = mouseX - (rangeReducedTextWidth * 0.5)
	local bottom = mouseY + (vsy * RANGE_REDUCED_CURSOR_GAP_FRACTION)
	gl.DepthTest(false)
	gl.DepthMask(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Texture(rangeReducedTextTexture)
	gl.Color(rangeReducedNotice.red, rangeReducedNotice.green, rangeReducedNotice.blue, alpha)
	gl.TexRect(left, bottom, left + rangeReducedTextWidth, bottom + rangeReducedTextHeight, false, true)
	gl.Texture(false)
	gl.Color(1, 1, 1, 1)
	gl.DepthMask(true)
	gl.DepthTest(true)
end

function widget:DrawWorldPreUnit()
	circleRender.drawCommandCircleFlash()
end

function widget:DrawScreenPost()
	circleRender.drawCirclePreview()
	circleRender.drawRangeReducedNotice()
end

function widget:ViewResize()
	updateDoubleClickSnapRadius()
	circleRender.bakeRangeReducedText()
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
	createCircleShader()
end

function widget:Shutdown()
	widgetHandler:RemoveAction("screen_select_hold", "p")
	widgetHandler:RemoveAction("screen_select_hold", "r")
	WG["screenSelectCommands"] = nil
	screenSelectKeyHeld = false
	deleteCircleShader()
	circleRender.deleteRangeReducedTextTexture()
end

function widget:LanguageChanged()
	circleRender.bakeRangeReducedText()
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
		doubleRightClickDefaultCommandEnabled = doubleRightClickDefaultCommandEnabled,
		doubleClickRadiusFraction = doubleClickRadiusFraction,
	}
end

function widget:SetConfigData(data)
	if data.doubleClickEnabled ~= nil then
		setDoubleClickEnabled(data.doubleClickEnabled)
	end
	if data.doubleRightClickDefaultCommandEnabled ~= nil then
		setDoubleRightClickDefaultCommandEnabled(data.doubleRightClickDefaultCommandEnabled)
	end
	if data.doubleClickRadiusFraction ~= nil then
		setDoubleClickRadiusFraction(data.doubleClickRadiusFraction, false)
	end
end
