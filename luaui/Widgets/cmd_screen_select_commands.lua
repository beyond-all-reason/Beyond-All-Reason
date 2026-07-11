local widget = widget ---@type RulesUnsyncedCallins

function widget:GetInfo()
	return {
		name = "Screen Select Commands",
		desc = "Double-click mass unit-target commands on visible screen targets. Supports Attack, Set Target, Capture, Guard, Repair, Reclaim, and Resurrect. First click issues a normal order and keeps the command active; second click on the same target within DoubleClickTime expands to all visible matches of that type. Each unit orders targets closest-to-itself first. Click a selected unit to mass-order only within the selection; click an external unit to exclude the selection. Shift queues, Space prepends, Ctrl broadens targets (all visible enemies, allied team, or same feature type; reclaim on allies is own team only), and Alt evenly distributes targets among units or unit squads among targets.",
		author = "SethDGamre",
		date = "July 11, 2026",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

local tableInsert = table.insert
local tableSort = table.sort
local mathFloor = math.floor

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitArrayCentroid = Spring.GetUnitArrayCentroid
local spGetFeatureResurrect = Spring.GetFeatureResurrect
local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetVisibleFeatures = Spring.GetVisibleFeatures
local spGetActiveCommand = Spring.GetActiveCommand
local spSetActiveCommand = Spring.SetActiveCommand
local spGetModKeyState = Spring.GetModKeyState
local spGetCmdDescIndex = Spring.GetCmdDescIndex

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local FEATURE = "feature"
local UNIT = "unit"

local COMMAND_LIMIT = 2000
local MAX_DOUBLECLICK_UNITS = 100
local DOUBLECLICK_START_RADIUS = 2000
local DOUBLECLICK_RADIUS_STEP = 500
local doubleClickTime = Spring.GetConfigInt("DoubleClickTime", 200) / 1000
local MIN_DOUBLE_CLICK_GAP = 0.03
local MIN_PENDING_DOUBLE_CLICK_TIME = 0.4 -- seconds
local osClock = os.clock

local myAllyTeamID
local myTeamID
local pendingDoubleClick = {
	targetId = nil,
	isFeature = false,
	expireTime = 0,
	cmdId = nil,
	cmdDescIndex = nil,
	alt = false,
	ctrl = false,
	meta = false,
	shift = false,
	right = false,
	targetInSelection = false,
	firstClickTime = 0,
}
local heldCommandDescIndex
local deferClearActiveCommand = false

local function distanceSq(position1, position2)
	local dx = position1.x - position2.x
	local dz = position1.z - position2.z
	return dx * dx + dz * dz
end

local function toPositionTable(x, y, z)
	return { x = x, y = y, z = z }
end

local function isQueuing(options)
	if options.shift then
		return true
	end
	local _, _, _, shift = spGetModKeyState()
	return shift
end

local function restoreActiveCommand(cmdDescIndex)
	local alt, ctrl, meta, shift = spGetModKeyState()
	spSetActiveCommand(cmdDescIndex, 1, true, false, alt, ctrl, meta, shift)
end

local function updateShiftCommandKeep()
	local _, _, _, shift = spGetModKeyState()
	if shift and heldCommandDescIndex then
		local _, activeCmdID = spGetActiveCommand()
		if not activeCmdID then
			restoreActiveCommand(heldCommandDescIndex)
		end
	elseif not shift then
		heldCommandDescIndex = nil
	end
end

local function clearDoubleClickPending()
	pendingDoubleClick.targetId = nil
	pendingDoubleClick.isFeature = false
	pendingDoubleClick.expireTime = 0
	pendingDoubleClick.cmdId = nil
	pendingDoubleClick.cmdDescIndex = nil
	pendingDoubleClick.alt = false
	pendingDoubleClick.ctrl = false
	pendingDoubleClick.meta = false
	pendingDoubleClick.shift = false
	pendingDoubleClick.right = false
	pendingDoubleClick.targetInSelection = false
	pendingDoubleClick.firstClickTime = 0
end

local function isPendingDoubleClickActive()
	return pendingDoubleClick.targetId ~= nil
		and pendingDoubleClick.cmdId ~= nil
		and osClock() < pendingDoubleClick.expireTime
end

local function isFeatureTargetId(targetId)
	return targetId > Game.maxUnits
end

local function getRawFeatureId(targetId)
	if targetId > Game.maxUnits then
		return targetId - Game.maxUnits
	end
	return targetId
end

local function normalizeFeatureTargetId(featureId)
	if Engine.FeatureSupport.noOffsetForFeatureID or featureId > Game.maxUnits then
		return featureId
	end
	return featureId + Game.maxUnits
end

local function getTargetPosition(targetId)
	if isFeatureTargetId(targetId) then
		local x, y, z = spGetFeaturePosition(getRawFeatureId(targetId))
		if x then
			return toPositionTable(x, y, z)
		end
	else
		local x, y, z = spGetUnitPosition(targetId)
		if x then
			return toPositionTable(x, y, z)
		end
	end
	return nil
end

local function sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst, refUnitID)
	local refPosition
	if refUnitID then
		refPosition = getTargetPosition(refUnitID)
	end
	if not refPosition then
		refPosition = toPositionTable(spGetUnitArrayCentroid(selectedUnits))
	end
	tableSort(filteredTargets, function(targetIdA, targetIdB)
		local positionA = getTargetPosition(targetIdA)
		local positionB = getTargetPosition(targetIdB)
		if not positionA or not positionB then
			return positionA ~= nil
		end
		if closestFirst then
			return distanceSq(refPosition, positionA) < distanceSq(refPosition, positionB)
		end
		return distanceSq(refPosition, positionA) > distanceSq(refPosition, positionB)
	end)
end

local function limitDoubleClickTargetsByRadius(filteredTargets, refTargetId, selectedUnits)
	if #filteredTargets <= MAX_DOUBLECLICK_UNITS then
		return filteredTargets
	end
	local refPosition = getTargetPosition(refTargetId)
	if not refPosition then
		sortTargetsByDistance(selectedUnits, filteredTargets, true)
		local cappedTargets = {}
		for i = 1, MAX_DOUBLECLICK_UNITS do
			cappedTargets[i] = filteredTargets[i]
		end
		return cappedTargets
	end
	sortTargetsByDistance({ refTargetId }, filteredTargets, true, refTargetId)
	local radius = DOUBLECLICK_START_RADIUS
	while radius >= 0 do
		local radiusSq = radius * radius
		local limitedTargets = {}
		for i = 1, #filteredTargets do
			local targetId = filteredTargets[i]
			local targetPosition = getTargetPosition(targetId)
			if targetPosition and distanceSq(refPosition, targetPosition) <= radiusSq then
				tableInsert(limitedTargets, targetId)
			end
		end
		if #limitedTargets <= MAX_DOUBLECLICK_UNITS then
			return limitedTargets
		end
		radius = radius - DOUBLECLICK_RADIUS_STEP
	end
	local cappedTargets = {}
	for i = 1, MAX_DOUBLECLICK_UNITS do
		cappedTargets[i] = filteredTargets[i]
	end
	return cappedTargets
end

local function giveOrders(cmdId, selectedUnits, filteredTargets, options, maxCommands)
	maxCommands = maxCommands or COMMAND_LIMIT
	local queuing = isQueuing(options)
	local firstTarget = true
	local selectedUnitsLen = #selectedUnits
	for i, targetId in ipairs(filteredTargets) do
		local cmdOpts = {}
		if not firstTarget or queuing then
			tableInsert(cmdOpts, "shift")
		end
		if options.meta and not queuing then
			spGiveOrderToUnitArray(selectedUnits, CMD.INSERT, { 0, cmdId, 0, targetId }, CMD.OPT_ALT)
		else
			spGiveOrderToUnitArray(selectedUnits, cmdId, { targetId }, cmdOpts)
		end
		firstTarget = false
		if i * selectedUnitsLen > maxCommands then
			return
		end
	end
end

local function divideWithRemainder(total, groupCount)
	local baseCount = mathFloor(total / groupCount)
	local extraCount = total % groupCount
	return baseCount, extraCount
end

local function pickClosestUnassigned(refId, candidates, unassigned, count)
	local available = {}
	for i = 1, #candidates do
		local candidateId = candidates[i]
		if unassigned[candidateId] then
			tableInsert(available, candidateId)
		end
	end
	if count <= 0 or #available == 0 then
		return {}
	end
	sortTargetsByDistance({ refId }, available, true, refId)
	local picked = {}
	local pickCount = count
	if pickCount > #available then
		pickCount = #available
	end
	for i = 1, pickCount do
		local pickedId = available[i]
		picked[i] = pickedId
		unassigned[pickedId] = nil
	end
	return picked
end

local function giveOrdersPerUnitSortedFromSelf(cmdId, selectedUnits, filteredTargets, options)
	local closestFirst = not options.meta
	for i = 1, #selectedUnits do
		local selectedUnitId = selectedUnits[i]
		local targets = {}
		for j = 1, #filteredTargets do
			targets[j] = filteredTargets[j]
		end
		sortTargetsByDistance({ selectedUnitId }, targets, closestFirst, selectedUnitId)
		giveOrders(cmdId, { selectedUnitId }, targets, options)
	end
end

local function giveAltDistributedOrders(cmdId, selectedUnits, filteredTargets, options, refTargetId)
	local closestFirst = not options.meta
	if #filteredTargets >= #selectedUnits then
		local baseCount, extraCount = divideWithRemainder(#filteredTargets, #selectedUnits)
		local unassigned = {}
		for i = 1, #filteredTargets do
			unassigned[filteredTargets[i]] = true
		end
		for i = 1, #selectedUnits do
			local selectedUnitId = selectedUnits[i]
			local count = baseCount
			if i <= extraCount then
				count = count + 1
			end
			if count > 0 then
				local assignedTargets = pickClosestUnassigned(selectedUnitId, filteredTargets, unassigned, count)
				if #assignedTargets > 0 then
					sortTargetsByDistance({ selectedUnitId }, assignedTargets, closestFirst, selectedUnitId)
					giveOrders(cmdId, { selectedUnitId }, assignedTargets, options)
				end
			end
		end
	else
		local baseCount, extraCount = divideWithRemainder(#selectedUnits, #filteredTargets)
		local unassigned = {}
		for i = 1, #selectedUnits do
			unassigned[selectedUnits[i]] = true
		end
		local sortedTargets = {}
		for i = 1, #filteredTargets do
			sortedTargets[i] = filteredTargets[i]
		end
		sortTargetsByDistance(selectedUnits, sortedTargets, true, refTargetId)
		for i = 1, #sortedTargets do
			local targetId = sortedTargets[i]
			local count = baseCount
			if i <= extraCount then
				count = count + 1
			end
			if count > 0 then
				local squad = pickClosestUnassigned(targetId, selectedUnits, unassigned, count)
				if #squad > 0 then
					giveOrders(cmdId, squad, { targetId }, options)
				end
			end
		end
	end
end

local function issueDoubleClickMassOrders(issueCmdId, selectedUnits, filteredTargets, options, refTargetId)
	if #filteredTargets == 0 then
		return
	end
	if options.alt then
		giveAltDistributedOrders(issueCmdId, selectedUnits, filteredTargets, options, refTargetId)
	else
		giveOrdersPerUnitSortedFromSelf(issueCmdId, selectedUnits, filteredTargets, options)
	end
end

local function commandRule(targetTypes, targetAllegiance)
	local allowedTargetTypes = {}
	for i = 1, #targetTypes do
		allowedTargetTypes[targetTypes[i]] = true
	end
	return {
		allowedTargetTypes = allowedTargetTypes,
		targetAllegiance = targetAllegiance,
	}
end

local allowedCommands = {
	[CMD.ATTACK] = commandRule({ UNIT }, ENEMY_UNITS),
	[CMD.CAPTURE] = commandRule({ UNIT }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET] = commandRule({ UNIT }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = commandRule({ UNIT }, ENEMY_UNITS),
	[CMD.GUARD] = commandRule({ UNIT }, ALLY_UNITS),
	[CMD.REPAIR] = commandRule({ UNIT }, ALLY_UNITS),
	[CMD.RECLAIM] = commandRule({ UNIT, FEATURE }, ALL_UNITS),
	[CMD.RESURRECT] = commandRule({ FEATURE }),
}

local doubleClickCommands = {
	[CMD.ATTACK] = true,
	[CMD.CAPTURE] = true,
	[CMD.GUARD] = true,
	[CMD.REPAIR] = true,
	[CMD.RECLAIM] = true,
	[CMD.RESURRECT] = true,
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}

local function unitMatchesAllegiance(unitID, targetAllegiance)
	local isEnemy = spGetUnitAllyTeam(unitID) ~= myAllyTeamID
	if targetAllegiance == ENEMY_UNITS and not isEnemy then
		return false
	end
	if targetAllegiance == ALLY_UNITS and isEnemy then
		return false
	end
	return true
end

local function shouldIncludeVisibleFeature(featureId, cmdId)
	if cmdId ~= CMD.RESURRECT then
		return true
	end
	local unitDefName = spGetFeatureResurrect(featureId)
	return unitDefName ~= nil and unitDefName ~= ""
end

local function getVisibleUnitsOfType(unitDefID, targetAllegiance)
	local filteredTargets = {}
	local visibleUnits = spGetVisibleUnits()
	if not visibleUnits then
		return filteredTargets
	end
	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if spGetUnitDefID(unitID) == unitDefID and unitMatchesAllegiance(unitID, targetAllegiance) then
			tableInsert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function getVisibleUnitsByAllegiance(targetAllegiance)
	local filteredTargets = {}
	local visibleUnits = spGetVisibleUnits()
	if not visibleUnits then
		return filteredTargets
	end
	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if unitMatchesAllegiance(unitID, targetAllegiance) then
			tableInsert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function getVisibleUnitsOfOwnTeam()
	local filteredTargets = {}
	local visibleUnits = spGetVisibleUnits()
	if not visibleUnits then
		return filteredTargets
	end
	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if spGetUnitTeam(unitID) == myTeamID then
			tableInsert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function getVisibleUnitsOfOwnTeamType(unitDefID)
	local filteredTargets = {}
	local visibleUnits = spGetVisibleUnits()
	if not visibleUnits then
		return filteredTargets
	end
	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if spGetUnitDefID(unitID) == unitDefID and spGetUnitTeam(unitID) == myTeamID then
			tableInsert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function getVisibleUnitsOfTeam(teamID)
	local filteredTargets = {}
	local visibleUnits = spGetVisibleUnits()
	if not visibleUnits then
		return filteredTargets
	end
	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if spGetUnitTeam(unitID) == teamID then
			tableInsert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function collectVisibleFeatures(cmdId, featureDefID)
	local filteredTargets = {}
	local visibleFeatures = spGetVisibleFeatures(-1)
	if not visibleFeatures then
		return filteredTargets
	end
	for i = 1, #visibleFeatures do
		local featureId = visibleFeatures[i]
		if (not featureDefID or spGetFeatureDefID(featureId) == featureDefID)
			and shouldIncludeVisibleFeature(featureId, cmdId)
		then
			tableInsert(filteredTargets, normalizeFeatureTargetId(featureId))
		end
	end
	return filteredTargets
end

local function isValidDoubleClickTarget(cmdId, targetId, isFeature)
	local config = allowedCommands[cmdId]
	if not config then
		return false
	end
	if isFeature then
		if not config.allowedTargetTypes[FEATURE] then
			return false
		end
		if cmdId == CMD.RESURRECT then
			local unitDefName = spGetFeatureResurrect(getRawFeatureId(targetId))
			if unitDefName == nil or unitDefName == "" then
				return false
			end
		end
		return true
	end
	if not config.allowedTargetTypes[UNIT] then
		return false
	end
	local isEnemy = spGetUnitAllyTeam(targetId) ~= myAllyTeamID
	local allegiance = config.targetAllegiance
	if isEnemy and allegiance ~= ALL_UNITS and allegiance ~= ENEMY_UNITS then
		return false
	end
	if not isEnemy and allegiance == ENEMY_UNITS then
		return false
	end
	if cmdId == CMD.RECLAIM and not isEnemy and spGetUnitTeam(targetId) ~= myTeamID then
		return false
	end
	return true
end

local function buildSelectionSet(selectedUnits)
	local selectionSet = {}
	for i = 1, #selectedUnits do
		selectionSet[selectedUnits[i]] = true
	end
	return selectionSet
end

local function isUnitInSelection(unitId, selectionSet)
	return selectionSet[unitId] or false
end

local function filterTargetsBySelectionMembership(targets, selectedUnits, targetInSelection)
	local selectionSet = buildSelectionSet(selectedUnits)
	local filtered = {}
	for i = 1, #targets do
		local targetId = targets[i]
		if isFeatureTargetId(targetId) then
			tableInsert(filtered, targetId)
		elseif targetInSelection and isUnitInSelection(targetId, selectionSet) then
			tableInsert(filtered, targetId)
		elseif not targetInSelection and not isUnitInSelection(targetId, selectionSet) then
			tableInsert(filtered, targetId)
		end
	end
	return filtered
end

local function collectDoubleClickTargets(cmdId, targetId, isFeature, options)
	if isFeature then
		local featureDefID = spGetFeatureDefID(getRawFeatureId(targetId))
		if not featureDefID then
			return {}
		end
		return collectVisibleFeatures(cmdId, featureDefID)
	end
	if options.ctrl then
		local isEnemy = spGetUnitAllyTeam(targetId) ~= myAllyTeamID
		if isEnemy then
			return getVisibleUnitsByAllegiance(ENEMY_UNITS)
		end
		if cmdId == CMD.RECLAIM then
			return getVisibleUnitsOfOwnTeam()
		end
		return getVisibleUnitsOfTeam(spGetUnitTeam(targetId))
	end
	local unitDefID = spGetUnitDefID(targetId)
	if not unitDefID then
		return {}
	end
	if cmdId == CMD.RECLAIM then
		local isEnemy = spGetUnitAllyTeam(targetId) ~= myAllyTeamID
		if isEnemy then
			return getVisibleUnitsOfType(unitDefID, ENEMY_UNITS)
		end
		return getVisibleUnitsOfOwnTeamType(unitDefID)
	end
	local config = allowedCommands[cmdId]
	return getVisibleUnitsOfType(unitDefID, config.targetAllegiance)
end

local function issuePendingDoubleClickMassOrders(options)
	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 or not isPendingDoubleClickActive() then
		return false
	end
	local issueCmdId = pendingDoubleClick.cmdId
	local refTargetId = pendingDoubleClick.targetId
	local refTargetIsFeature = pendingDoubleClick.isFeature
	local savedCmdDescIndex = pendingDoubleClick.cmdDescIndex or spGetCmdDescIndex(issueCmdId)
	local targetInSelection = pendingDoubleClick.targetInSelection
	local queuing = isQueuing(options)
	clearDoubleClickPending()
	local filteredTargets = collectDoubleClickTargets(issueCmdId, refTargetId, refTargetIsFeature, options)
	filteredTargets = filterTargetsBySelectionMembership(filteredTargets, selectedUnits, targetInSelection)
	filteredTargets = limitDoubleClickTargetsByRadius(filteredTargets, refTargetId, selectedUnits)
	issueDoubleClickMassOrders(issueCmdId, selectedUnits, filteredTargets, options, refTargetId)
	if queuing then
		heldCommandDescIndex = savedCmdDescIndex
		restoreActiveCommand(savedCmdDescIndex)
	else
		heldCommandDescIndex = nil
		deferClearActiveCommand = true
	end
	return true
end

local function resolveDoubleClickCmdId(cmdId)
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID and doubleClickCommands[activeCmdID] then
		return activeCmdID
	end
	return cmdId
end

local function tryCompletePendingDoubleClick(options, effectiveCmdId)
	local now = osClock()
	local clickAlt = options.alt or false
	local clickCtrl = options.ctrl or false
	local clickMeta = options.meta or false
	local clickShift = options.shift or false
	local clickRight = options.right or false
	if isPendingDoubleClickActive()
		and pendingDoubleClick.cmdId == effectiveCmdId
		and doubleClickCommands[pendingDoubleClick.cmdId]
		and pendingDoubleClick.alt == clickAlt
		and pendingDoubleClick.ctrl == clickCtrl
		and pendingDoubleClick.meta == clickMeta
		and pendingDoubleClick.shift == clickShift
		and pendingDoubleClick.right == clickRight
		and now >= pendingDoubleClick.firstClickTime + MIN_DOUBLE_CLICK_GAP
	then
		return issuePendingDoubleClickMassOrders(options)
	end
	return false
end

local function getPendingExpireTime(realTime)
	return realTime + math.max(doubleClickTime, MIN_PENDING_DOUBLE_CLICK_TIME)
end

local function consumePendingDoubleClickClick(options, effectiveCmdId)
	if not isPendingDoubleClickActive() then
		return false
	end
	if effectiveCmdId and pendingDoubleClick.cmdId ~= effectiveCmdId then
		return false
	end
	local clickRight = options.right or false
	if pendingDoubleClick.right ~= clickRight then
		return false
	end
	tryCompletePendingDoubleClick(options, pendingDoubleClick.cmdId)
	return true
end

local function handleDoubleClickSingleTarget(cmdId, params, options)
	local targetId = params[1]
	local isFeature = isFeatureTargetId(targetId)
	local effectiveCmdId = resolveDoubleClickCmdId(cmdId)

	if consumePendingDoubleClickClick(options, effectiveCmdId) then
		return true
	end

	if not isValidDoubleClickTarget(effectiveCmdId, targetId, isFeature) then
		return false
	end

	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 then
		return false
	end

	local realTime = osClock()
	local queuing = isQueuing(options)
	local clickAlt = options.alt or false
	local clickCtrl = options.ctrl or false
	local clickMeta = options.meta or false
	local clickShift = options.shift or false
	local clickRight = options.right or false

	if not doubleClickCommands[effectiveCmdId] then
		return false
	end

	giveOrders(effectiveCmdId, selectedUnits, { targetId }, options)

	local selectionSet = buildSelectionSet(selectedUnits)
	pendingDoubleClick.targetInSelection = not isFeature and isUnitInSelection(targetId, selectionSet)
	pendingDoubleClick.targetId = targetId
	pendingDoubleClick.isFeature = isFeature
	pendingDoubleClick.expireTime = getPendingExpireTime(realTime)
	pendingDoubleClick.cmdId = effectiveCmdId
	pendingDoubleClick.alt = clickAlt
	pendingDoubleClick.ctrl = clickCtrl
	pendingDoubleClick.meta = clickMeta
	pendingDoubleClick.shift = clickShift
	pendingDoubleClick.right = clickRight
	pendingDoubleClick.cmdDescIndex = select(4, spGetActiveCommand()) or spGetCmdDescIndex(effectiveCmdId)
	pendingDoubleClick.firstClickTime = realTime
	if queuing then
		heldCommandDescIndex = pendingDoubleClick.cmdDescIndex
	end
	return true
end

function widget:MousePress(mouseX, mouseY, button)
	if button ~= 1 and button ~= 3 then
		return false
	end
	local alt, ctrl, meta, shift = spGetModKeyState()
	local options = { alt = alt, ctrl = ctrl, meta = meta, shift = shift, right = (button == 3) }
	return consumePendingDoubleClickClick(options, pendingDoubleClick.cmdId)
end

function widget:CommandNotify(cmdId, params, options)
	local effectiveCmdId = resolveDoubleClickCmdId(cmdId)
	if #params ~= 4 and consumePendingDoubleClickClick(options, effectiveCmdId) then
		return true
	end
	if #params == 1 then
		return handleDoubleClickSingleTarget(cmdId, params, options)
	end
	return false
end

local function initialize()
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
	myAllyTeamID = spGetMyAllyTeamID()
	myTeamID = spGetMyTeamID()
end

function widget:PlayerChanged()
	initialize()
end

function widget:Initialize()
	initialize()
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

function widget:ActiveCommandChanged(cmdid)
	if cmdid then
		if pendingDoubleClick.cmdId and pendingDoubleClick.cmdId ~= cmdid then
			clearDoubleClickPending()
		end
		return
	end
	if isPendingDoubleClickActive() then
		return
	end
	if heldCommandDescIndex then
		return
	end
	clearDoubleClickPending()
end
