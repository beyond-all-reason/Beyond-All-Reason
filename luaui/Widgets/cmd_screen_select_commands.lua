local widget = widget ---@type RulesUnsyncedCallins

function widget:GetInfo()
	return {
		name = "Screen Select Commands",
		desc = "Mass-issue unit-target commands to all visible on-screen matches. Double-click the same target, or keybind + click for mass orders.",
		author = "SethDGamre, advised by Chronographer",
		date = "July 11, 2026",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

--[[------------------------------------------------------------------------------
How To Use:
  First click issues a normal order. Second click the same target mass-orders all on-screen matches.
  Optionally, keybind and hold down screen_select_hold to mass-order on the first click instead.

Click modifiers:
  Shift -> add to end of queue
  Space -> prepend to beginning of queue
  Ctrl -> expand scope - apply to all visible targets of the same allignment. Own TeamID, Ally's teamID, all enemy TeamID's. For reclaim features, broaden by yield (metal vs energy-only).
  Alt -> distribute evenly among selected units

  There's a filter also. If you screen-command selected units, it will include selected units only.
  If you screen-command an external unit, it will exclude the selected units.

Keybind (uikeys.txt or luaui/configs/hotkeys/grid_keys.txt):
  bind sc_v screen_select_hold
--]]------------------------------------------------------------------------------

include("keysym.h.lua")

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
local spGetKeyState = Spring.GetKeyState
local spValidFeatureID = Spring.ValidFeatureID
local spValidUnitID = Spring.ValidUnitID
local spGetFeatureResources = Spring.GetFeatureResources
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local FEATURE = "feature"
local UNIT = "unit"

local COMMAND_LIMIT = 2000
local DEFAULT_MAX_DOUBLECLICK_UNITS = 100
local DOUBLECLICK_START_RADIUS = 2000
local DOUBLECLICK_RADIUS_STEP = 500
local doubleClickTime = Spring.GetConfigInt("DoubleClickTime", 200) / 1000
local MIN_DOUBLE_CLICK_GAP = 0.03
local DEFAULT_DOUBLE_CLICK_ENABLED = true
local osClock = os.clock

local doubleClickEnabled = DEFAULT_DOUBLE_CLICK_ENABLED
local maxDoubleClickUnits = DEFAULT_MAX_DOUBLECLICK_UNITS

local myAllyTeamID
local myTeamID
local pendingDoubleClick = {
	targetId = nil,
	isFeature = false,
	expireTime = 0,
	cmdId = nil,
	alt = false,
	ctrl = false,
	meta = false,
	shift = false,
	right = false,
	firstClickTime = 0,
}
local heldCommandDescIndex
local deferClearActiveCommand = false
local screenSelectHeld = false
local screenSelectHoldActionHeld = false

local function enrichCommandOptions(options)
	options = options or {}
	local modAlt, modCtrl, modMeta, modShift = spGetModKeyState()
	return {
		alt = options.alt or modAlt,
		ctrl = options.ctrl or modCtrl,
		meta = options.meta or modMeta,
		shift = options.shift or modShift,
		right = options.right or false,
	}
end

local function refreshScreenSelectHeld()
	screenSelectHeld = spGetKeyState(KEYSYMS.V)
		or spGetKeyState(KEYSYMS.O)
		or screenSelectHoldActionHeld
end

local function distanceSq(position1, position2)
	local dx = position1.x - position2.x
	local dz = position1.z - position2.z
	return dx * dx + dz * dz
end

local function toPositionTable(x, y, z)
	return { x = x, y = y, z = z }
end

local function isQueuing(options)
	return options.shift
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
	pendingDoubleClick.alt = false
	pendingDoubleClick.ctrl = false
	pendingDoubleClick.meta = false
	pendingDoubleClick.shift = false
	pendingDoubleClick.right = false
	pendingDoubleClick.firstClickTime = 0
end

local function isPendingDoubleClickActive()
	return pendingDoubleClick.targetId ~= nil
		and pendingDoubleClick.cmdId ~= nil
		and osClock() < pendingDoubleClick.expireTime
end

local function isFeatureTargetId(targetId)
	if targetId > Game.maxUnits then
		return spValidFeatureID(targetId - Game.maxUnits)
	end
	if spValidFeatureID(targetId) and not spValidUnitID(targetId) then
		return true
	end
	return false
end

local function getRawFeatureId(targetId)
	if targetId > Game.maxUnits then
		return targetId - Game.maxUnits
	end
	return targetId
end

local function normalizeFeatureTargetId(featureId)
	if Engine.FeatureSupport.noOffsetForFeatureID then
		if featureId > Game.maxUnits then
			return featureId - Game.maxUnits
		end
		return featureId
	end
	if featureId > Game.maxUnits then
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
	if targetId > Game.maxUnits then
		return targetId
	end
	return targetId + Game.maxUnits
end

local function filterUnitsForCommand(selectedUnits, cmdId)
	if cmdId ~= CMD.RECLAIM and cmdId ~= CMD.RESURRECT and cmdId ~= CMD.REPAIR and cmdId ~= CMD.CAPTURE then
		return selectedUnits
	end
	local filteredUnits = {}
	for i = 1, #selectedUnits do
		local unitId = selectedUnits[i]
		local unitDefId = spGetUnitDefID(unitId)
		local unitDef = unitDefId and UnitDefs[unitDefId]
		if unitDef then
			if cmdId == CMD.RECLAIM and unitDef.canReclaim and unitDef.reclaimSpeed > 0 then
				tableInsert(filteredUnits, unitId)
			elseif cmdId == CMD.RESURRECT and unitDef.canResurrect and unitDef.resurrectSpeed > 0 then
				tableInsert(filteredUnits, unitId)
			elseif cmdId == CMD.REPAIR and unitDef.canRepair and unitDef.repairSpeed > 0 then
				tableInsert(filteredUnits, unitId)
			elseif cmdId == CMD.CAPTURE and unitDef.canCapture and unitDef.captureSpeed > 0 then
				tableInsert(filteredUnits, unitId)
			end
		end
	end
	return filteredUnits
end

local function isCapturableTargetUnit(unitId)
	local unitDefId = spGetUnitDefID(unitId)
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

local function filterCaptureTargets(targets)
	local filteredTargets = {}
	for i = 1, #targets do
		local unitId = targets[i]
		if isCapturableTargetUnit(unitId) then
			tableInsert(filteredTargets, unitId)
		end
	end
	return filteredTargets
end

local function finalizeUnitTargets(cmdId, targets)
	if cmdId == CMD.CAPTURE then
		return filterCaptureTargets(targets)
	end
	return targets
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
	if #filteredTargets <= maxDoubleClickUnits then
		return filteredTargets
	end
	local refPosition = getTargetPosition(refTargetId)
	if not refPosition then
		sortTargetsByDistance(selectedUnits, filteredTargets, true)
		local cappedTargets = {}
		for i = 1, maxDoubleClickUnits do
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
		if #limitedTargets <= maxDoubleClickUnits then
			return limitedTargets
		end
		radius = radius - DOUBLECLICK_RADIUS_STEP
	end
	local cappedTargets = {}
	for i = 1, maxDoubleClickUnits do
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
			spGiveOrderToUnitArray(selectedUnits, CMD.INSERT, { 0, cmdId, 0, toFeatureOrderParamId(targetId) }, CMD.OPT_ALT)
		else
			spGiveOrderToUnitArray(selectedUnits, cmdId, { toFeatureOrderParamId(targetId) }, cmdOpts)
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

local function getReclaimFeatureCategory(rawFeatureId)
	local featureDefId = spGetFeatureDefID(rawFeatureId)
	if not featureDefId then
		return nil
	end
	local featureDef = FeatureDefs[featureDefId]
	if not featureDef or not featureDef.customParams then
		return nil
	end
	return featureDef.customParams.category
end

local function isReclaimCorpse(rawFeatureId)
	return getReclaimFeatureCategory(rawFeatureId) == "corpses"
end

local function isReclaimHeap(rawFeatureId)
	return getReclaimFeatureCategory(rawFeatureId) == "heaps"
end

local function featureHasMetalYield(rawFeatureId)
	local featureDefId = spGetFeatureDefID(rawFeatureId)
	if featureDefId then
		local featureDef = FeatureDefs[featureDefId]
		if featureDef and featureDef.metal and featureDef.metal > 0 then
			return true
		end
	end
	local metal = select(1, spGetFeatureResources(rawFeatureId))
	return metal and metal > 0
end

local function featureIsEnergyOnlyYield(rawFeatureId)
	if featureHasMetalYield(rawFeatureId) then
		return false
	end
	local featureDefId = spGetFeatureDefID(rawFeatureId)
	if featureDefId then
		local featureDef = FeatureDefs[featureDefId]
		if featureDef and featureDef.energy and featureDef.energy > 0 then
			return true
		end
	end
	local _, _, energy = spGetFeatureResources(rawFeatureId)
	return energy and energy > 0
end

local function getReclaimCtrlYieldClass(rawFeatureId)
	if featureHasMetalYield(rawFeatureId) then
		return "metal"
	end
	if featureIsEnergyOnlyYield(rawFeatureId) then
		return "energyOnly"
	end
	return nil
end

local function featureMatchesReclaimReference(rawFeatureId, refRawFeatureId, useCtrl)
	if useCtrl then
		local refYieldClass = getReclaimCtrlYieldClass(refRawFeatureId)
		if not refYieldClass then
			return false
		end
		return getReclaimCtrlYieldClass(rawFeatureId) == refYieldClass
	end
	if isReclaimCorpse(refRawFeatureId) then
		return isReclaimCorpse(rawFeatureId)
			and spGetFeatureDefID(rawFeatureId) == spGetFeatureDefID(refRawFeatureId)
	end
	if isReclaimHeap(refRawFeatureId) then
		return isReclaimHeap(rawFeatureId)
	end
	if featureIsEnergyOnlyYield(refRawFeatureId) then
		return featureIsEnergyOnlyYield(rawFeatureId)
	end
	if featureHasMetalYield(refRawFeatureId) then
		return featureHasMetalYield(rawFeatureId)
			and spGetFeatureDefID(rawFeatureId) == spGetFeatureDefID(refRawFeatureId)
	end
	return false
end

local function shouldIncludeVisibleFeature(featureId, cmdId)
	if cmdId == CMD.RESURRECT then
		local unitDefName = spGetFeatureResurrect(featureId)
		return unitDefName ~= nil and unitDefName ~= ""
	end
	if cmdId == CMD.RECLAIM then
		local featureDefId = spGetFeatureDefID(featureId)
		if not featureDefId then
			return false
		end
		local featureDef = FeatureDefs[featureDefId]
		if featureDef and featureDef.reclaimable == false then
			return false
		end
		local metal, _, energy = spGetFeatureResources(featureId)
		if (metal and metal > 0) or (energy and energy > 0) then
			return true
		end
		return featureDef and featureDef.reclaimable == true
	end
	return true
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

local function collectVisibleReclaimFeatures(refRawFeatureId, useCtrl)
	local filteredTargets = {}
	local visibleFeatures = spGetVisibleFeatures(-1)
	if not visibleFeatures then
		return filteredTargets
	end
	for i = 1, #visibleFeatures do
		local featureId = visibleFeatures[i]
		if shouldIncludeVisibleFeature(featureId, CMD.RECLAIM)
			and featureMatchesReclaimReference(featureId, refRawFeatureId, useCtrl)
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
	if cmdId == CMD.CAPTURE and not isCapturableTargetUnit(targetId) then
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
		local rawFeatureId = getRawFeatureId(targetId)
		if cmdId == CMD.RECLAIM then
			return collectVisibleReclaimFeatures(rawFeatureId, options.ctrl)
		end
		local featureDefID = spGetFeatureDefID(rawFeatureId)
		if not featureDefID then
			return {}
		end
		local typeFilter = featureDefID
		if options.ctrl then
			typeFilter = nil
		end
		return collectVisibleFeatures(cmdId, typeFilter)
	end
	if options.ctrl then
		local isEnemy = spGetUnitAllyTeam(targetId) ~= myAllyTeamID
		if isEnemy then
			return finalizeUnitTargets(cmdId, getVisibleUnitsByAllegiance(ENEMY_UNITS))
		end
		if cmdId == CMD.RECLAIM then
			return getVisibleUnitsOfOwnTeam()
		end
		return finalizeUnitTargets(cmdId, getVisibleUnitsOfTeam(spGetUnitTeam(targetId)))
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
	return finalizeUnitTargets(cmdId, getVisibleUnitsOfType(unitDefID, config.targetAllegiance))
end

local function issueMassOrdersFromTarget(issueCmdId, refTargetId, refTargetIsFeature, selectedUnits, options)
	options = enrichCommandOptions(options)
	refTargetIsFeature = isFeatureTargetId(refTargetId)
	selectedUnits = filterUnitsForCommand(selectedUnits, issueCmdId)
	if #selectedUnits == 0 then
		return false
	end
	local selectionSet = buildSelectionSet(selectedUnits)
	local targetInSelection = not refTargetIsFeature and isUnitInSelection(refTargetId, selectionSet)
	local savedCmdDescIndex = select(4, spGetActiveCommand()) or spGetCmdDescIndex(issueCmdId)
	local queuing = isQueuing(options)
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

local function issuePendingDoubleClickMassOrders(options)
	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 or not isPendingDoubleClickActive() then
		return false
	end
	local issueCmdId = pendingDoubleClick.cmdId
	local refTargetId = pendingDoubleClick.targetId
	local refTargetIsFeature = isFeatureTargetId(refTargetId)
	local massOptions = enrichCommandOptions({
		alt = options.alt or pendingDoubleClick.alt,
		ctrl = options.ctrl or pendingDoubleClick.ctrl,
		meta = options.meta or pendingDoubleClick.meta,
		shift = options.shift or pendingDoubleClick.shift,
		right = options.right ~= nil and options.right or pendingDoubleClick.right,
	})
	clearDoubleClickPending()
	return issueMassOrdersFromTarget(issueCmdId, refTargetId, refTargetIsFeature, selectedUnits, massOptions)
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
	local clickRight = options.right or false
	if isPendingDoubleClickActive()
		and pendingDoubleClick.cmdId == effectiveCmdId
		and doubleClickCommands[pendingDoubleClick.cmdId]
		and pendingDoubleClick.right == clickRight
		and now >= pendingDoubleClick.firstClickTime + MIN_DOUBLE_CLICK_GAP
	then
		return issuePendingDoubleClickMassOrders(options)
	end
	return false
end

local function getPendingExpireTime(realTime)
	return realTime + doubleClickTime
end

local function consumePendingDoubleClickClick(options, effectiveCmdId)
	if not doubleClickEnabled or not isPendingDoubleClickActive() then
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
	options = enrichCommandOptions(options)
	local targetId = params[1]
	local isFeature = isFeatureTargetId(targetId)
	local effectiveCmdId = resolveDoubleClickCmdId(cmdId)

	if not screenSelectHeld and consumePendingDoubleClickClick(options, effectiveCmdId) then
		return true
	end

	if not isValidDoubleClickTarget(effectiveCmdId, targetId, isFeature) then
		return false
	end

	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 then
		return false
	end
	selectedUnits = filterUnitsForCommand(selectedUnits, effectiveCmdId)
	if #selectedUnits == 0 then
		return false
	end

	if not doubleClickCommands[effectiveCmdId] then
		return false
	end

	if screenSelectHeld then
		return issueMassOrdersFromTarget(effectiveCmdId, targetId, isFeature, selectedUnits, options)
	end

	if not doubleClickEnabled then
		giveOrders(effectiveCmdId, selectedUnits, { targetId }, options)
		local queuingDisabled = isQueuing(options)
		if queuingDisabled then
			heldCommandDescIndex = select(4, spGetActiveCommand()) or spGetCmdDescIndex(effectiveCmdId)
		else
			heldCommandDescIndex = nil
			deferClearActiveCommand = true
		end
		return true
	end

	local realTime = osClock()
	local queuing = isQueuing(options)
	local clickAlt = options.alt or false
	local clickCtrl = options.ctrl or false
	local clickMeta = options.meta or false
	local clickShift = options.shift or false
	local clickRight = options.right or false

	giveOrders(effectiveCmdId, selectedUnits, { targetId }, options)

	pendingDoubleClick.targetId = targetId
	pendingDoubleClick.isFeature = isFeature
	pendingDoubleClick.expireTime = getPendingExpireTime(realTime)
	pendingDoubleClick.cmdId = effectiveCmdId
	pendingDoubleClick.alt = clickAlt
	pendingDoubleClick.ctrl = clickCtrl
	pendingDoubleClick.meta = clickMeta
	pendingDoubleClick.shift = clickShift
	pendingDoubleClick.right = clickRight
	pendingDoubleClick.firstClickTime = realTime
	if queuing then
		heldCommandDescIndex = select(4, spGetActiveCommand()) or spGetCmdDescIndex(effectiveCmdId)
	end
	return true
end

function widget:MousePress(_mouseX, _mouseY, button)
	if button ~= 1 and button ~= 3 then
		return false
	end
	local options = enrichCommandOptions({ right = (button == 3) })
	return consumePendingDoubleClickClick(options, pendingDoubleClick.cmdId)
end

function widget:CommandNotify(cmdId, params, options)
	options = enrichCommandOptions(options)
	local effectiveCmdId = resolveDoubleClickCmdId(cmdId)
	if #params ~= 4 and consumePendingDoubleClickClick(options, effectiveCmdId) then
		return true
	end
	if #params == 1 then
		return handleDoubleClickSingleTarget(cmdId, params, options)
	end
	return false
end

local function onScreenSelectHoldPress()
	screenSelectHoldActionHeld = true
end

local function onScreenSelectHoldRelease()
	screenSelectHoldActionHeld = false
end

local function setDoubleClickEnabled(value)
	doubleClickEnabled = value
	if not value then
		clearDoubleClickPending()
	end
end

local function registerScreenSelectCommandsApi()
	WG['screenSelectCommands'] = {
		getDoubleClickEnabled = function()
			return doubleClickEnabled
		end,
		setDoubleClickEnabled = setDoubleClickEnabled,
		getMaxDoubleClickUnits = function()
			return maxDoubleClickUnits
		end,
		setMaxDoubleClickUnits = function(value)
			maxDoubleClickUnits = mathFloor(value)
		end,
	}
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
	WG['screenSelectCommands'] = nil
	screenSelectHoldActionHeld = false
	screenSelectHeld = false
end

function widget:Update()
	refreshScreenSelectHeld()
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

function widget:GetConfigData()
	return {
		doubleClickEnabled = doubleClickEnabled,
		maxDoubleClickUnits = maxDoubleClickUnits,
	}
end

function widget:SetConfigData(data)
	if data.doubleClickEnabled ~= nil then
		doubleClickEnabled = data.doubleClickEnabled
	end
	if data.maxDoubleClickUnits ~= nil then
		maxDoubleClickUnits = mathFloor(data.maxDoubleClickUnits)
	end
end
