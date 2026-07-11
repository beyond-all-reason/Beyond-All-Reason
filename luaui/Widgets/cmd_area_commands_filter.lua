local widget = widget ---@type RulesUnsyncedCallins

-- When performing an area command for one of the `allowedCommands` below:
-- - If enemy unit is targeted then targetAllegiance=ENEMY_UNITS otherwise targetAllegiance=targetTeamId
-- - If Ctrl is pressed and hovering over a unit, targets all units in the area. For wrecks, it targets all wrecks with the same tech level
-- - If Alt is pressed and hovering over a unit, targets all units that share the same unitDefId in the area.
-- - If Meta is pressed, orders are put in front of the order queue.
-- - If Meta and Shift are pressed, splits orders between selected units. Orders are placed at the end of the queue
function widget:GetInfo()
	return {
		name = "Area Command Filter",
		desc = "Hold Alt or Ctrl with an area command (Reclaim, Load, Attack, etc.) centered on a unit or feature to filter targets. Double-click a unit or feature with Attack, Set Target, Capture, Guard, Repair, Reclaim, or Resurrect to order all visible targets of that type. Alt+double-click orders all applicable targets on screen (enemies, allies, or features by context). Ctrl+double-click queues all same-type targets per unit sorted by self-distance. Alt+Ctrl+double-click does the same with all on-screen targets.",
		author = "SuperKitowiec. Based on Specific Unit Reclaimer and Loader by Google Frog",
		date = "October 16, 2025",
		license = "GNU GPL, v2 or later",
		layer = -1, -- Has to be run before Smart Area Reclaim widget
		enabled = true
	}
end


-- Localized functions for performance
local tableInsert = table.insert
local tableSort = table.sort
local mathFloor = math.floor
local mathMax = math.max

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
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
local spGetGameFrame = Spring.GetGameFrame

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local FEATURE = "feature"
local UNIT = "unit"

local commandLimit = 2000
local MAX_DOUBLECLICK_UNITS = 100
local DOUBLECLICK_START_RADIUS = 2000
local DOUBLECLICK_RADIUS_STEP = 500
local doubleClickTime = Spring.GetConfigInt("DoubleClickTime", 200) / 1000
local osClock = os.clock

local myAllyTeamID
local pendingTargetId
local pendingTargetIsFeature = false
local pendingExpireTime = 0
local pendingCmdID
local pendingCmdDescIndex
local pendingAlt = false
local pendingCtrl = false
local heldCommandDescIndex
local lastFirstClickFrame = -1
local deferClearActiveCommand = false

---------------------------------------------------------------------------------------
--- Target sorting logic (pick the closest first)
---------------------------------------------------------------------------------------

---@field position1 table {x, y, z}
---@field position2 table {x, y, z}
local function distanceSq(position1, position2)
	local dx = position1.x - position2.x
	local dz = position1.z - position2.z
	return dx * dx + dz * dz
end

---@return table {x, y, z}
local function toPositionTable(x, y, z)
	return { x = x, y = y, z = z }
end

----------------------------------------------------------------------------------------------------------
--- Logic which distributes targets between transports. Should be split and extracted to separate widget
--- Preferably after https://github.com/beyond-all-reason/Beyond-All-Reason/pull/5738 will be merged
----------------------------------------------------------------------------------------------------------

-- Multiplier to convert footprints sizes
-- see SPRING_FOOTPRINT_SCALE in GlobalConstants.h in recoil engine repo for details
-- https://github.com/beyond-all-reason/RecoilEngine/blob/master/rts%2FSim%2FMisc%2FGlobalConstants.h
local springFootprintScale = Game.footprintScale

---@type table<number, TransportDef>
local transportDefs = {}
local cantBeTransported = {}
local unitMass = {}
local unitXSize = {}

for defId, def in pairs(UnitDefs) do
	if def.transportSize and def.transportSize > 0 then
		---@class TransportDef
		transportDefs[defId] = {
			massLimit = def.transportMass,
			maxCapacity = def.transportCapacity,
			sizeLimit = def.transportSize,
			health = def.health,
		}
	end
	unitMass[defId] = def.mass
	unitXSize[defId] = def.xsize
	cantBeTransported[defId] = def.cantBeTransported
end

--- @return table<number,table<number>> Map of transportId -> array of passengerIds
local function distributeTargetsToTransports(transports, targets)
	---@type table<number,TransportData>
	local transportTypeDataMap = {}
	local validTransportsForUnitTypeMap = {}
	local passengerPriorities = {}
	local passengerPositions = {}

	-- 1. Find transports with capacity
	for _, transportUnitId in ipairs(transports) do
		local transportDefId = spGetUnitDefID(transportUnitId)
		if transportDefId then
			local transportDef = transportDefs[transportDefId]
			if transportDef then
				local transportedUnits = spGetUnitIsTransporting(transportUnitId)
				local maxCapacity = transportDef.maxCapacity
				local remainingCapacity = maxCapacity - (transportedUnits and #transportedUnits or 0)

				if remainingCapacity > 0 then
					if not transportTypeDataMap[transportDefId] then
						---@class TransportData
						---@field transportsInfo table<number,TransportInfo>
						transportTypeDataMap[transportDefId] = {
							transportsInfo = {},
							transportIdsList = {},
							allValidPassengers = {},
							passengersByPriority = {},
							maxPriority = -1,
							transportHealth = transportDef.health
						}
					end
					local position = toPositionTable(spGetUnitPosition(transportUnitId))
					---@class TransportInfo
					local transportInfo = { capacity = remainingCapacity, position = position }
					transportTypeDataMap[transportDefId].transportsInfo[transportUnitId] = transportInfo
					tableInsert(transportTypeDataMap[transportDefId].transportIdsList, transportUnitId)
				end
			end
		end
	end

	-- 2. Match passengers to transport types
	for transDefId, transportTypeData in pairs(transportTypeDataMap) do
		local transportDef = transportDefs[transDefId]
		local transportMassLimit = transportDef.massLimit
		local transportSizeLimit = transportDef.sizeLimit

		for _, targetId in ipairs(targets) do
			local passengerDefId = spGetUnitDefID(targetId)
			local isValid = false
			local position = toPositionTable(spGetUnitPosition(targetId))
			passengerPositions[targetId] = position
			validTransportsForUnitTypeMap[passengerDefId] = validTransportsForUnitTypeMap[passengerDefId] or {}

			if validTransportsForUnitTypeMap[passengerDefId][transDefId] then
				isValid = true
			elseif not cantBeTransported[passengerDefId] then
				local passengerFootprintX = unitXSize[passengerDefId] / springFootprintScale
				if unitMass[passengerDefId] <= transportMassLimit and passengerFootprintX <= transportSizeLimit then
					isValid = true
					validTransportsForUnitTypeMap[passengerDefId][transDefId] = true
				end
			end
			if isValid then
				passengerPriorities[targetId] = (passengerPriorities[targetId] or 0) + 1
				tableInsert(transportTypeData.allValidPassengers, targetId)
			end
		end
		if #transportTypeData.allValidPassengers == 0 then
			transportTypeDataMap[transDefId] = nil
		end
	end

	local orderedTransportDefs = {}

	for transDefId, transportTypeData in pairs(transportTypeDataMap) do
		local maxPriority = -1

		-- 3. Sort passengers (hardest to transport first)
		tableSort(transportTypeData.allValidPassengers, function(a, b)
			return passengerPriorities[a] < passengerPriorities[b]
		end)

		-- 4. Group passengers by priority
		for _, passengerId in ipairs(transportTypeData.allValidPassengers) do
			local priority = passengerPriorities[passengerId]
			if priority > maxPriority then
				maxPriority = priority
			end
			if not transportTypeData.passengersByPriority[priority] then
				transportTypeData.passengersByPriority[priority] = {}
			end
			tableInsert(transportTypeData.passengersByPriority[priority], passengerId)
		end
		transportTypeData.maxPriority = maxPriority

		tableInsert(orderedTransportDefs, transDefId)
	end

	-- 5. Sort transport types
	tableSort(orderedTransportDefs, function(a, b)
		local passengerA = transportTypeDataMap[a].allValidPassengers[1]
		local passengerB = transportTypeDataMap[b].allValidPassengers[1]

		-- Transports with lowest capabilities are chosen first.
		if passengerPriorities[passengerA] ~= passengerPriorities[passengerB] then
			return passengerPriorities[passengerA] > passengerPriorities[passengerB]
		end

		-- In case of tie, we want the sturdier transport first as it will be the first to pick up bigger units
		return transportTypeDataMap[a].transportHealth > transportTypeDataMap[b].transportHealth
	end)

	-- 6. Distribute passengers.
	local alreadyAssignedPassengers = {}
	local passengerAssignments = {}

	--- We want to fill 'smallest' transports first to avoid situation where "bigger" transports get filled
	--- with small units and "small" transports remain empty. After picking transport we search for passengers.
	--- Passengers are grouped by priority - the smaller the number, the harder they are to transport.
	--- We start with the hardest passengers and pick the one which is the closest to the transport. We look at lower
	--- priority passengers only when there are noone left in the higher bracket.
	for _, transDefId in ipairs(orderedTransportDefs) do
		local transportTypeData = transportTypeDataMap[transDefId]
		local passengersByPriority = transportTypeData.passengersByPriority
		local transportIds = transportTypeData.transportIdsList
		local transportsInfo = transportTypeData.transportsInfo

		for _, transportId in ipairs(transportIds) do
			local transportInfo = transportsInfo[transportId]
			local transportPos = transportInfo.position

			while transportInfo.capacity > 0 do

				local bestPassengerId
				local passengerFound = false

				for priority = 1, transportTypeData.maxPriority do
					local passengers = passengersByPriority[priority]
					if passengers then

						local closestPassengerId
						local closestDistSq

						for _, passengerId in ipairs(passengers) do
							if not alreadyAssignedPassengers[passengerId] then
								local passengerPos = passengerPositions[passengerId]
								local distSq = distanceSq(transportPos, passengerPos)

								if closestDistSq == nil or distSq < closestDistSq then
									closestDistSq = distSq
									closestPassengerId = passengerId
								end
							end
						end

						if closestPassengerId then
							bestPassengerId = closestPassengerId

							if not passengerAssignments[transportId] then
								passengerAssignments[transportId] = {}
							end
							tableInsert(passengerAssignments[transportId], bestPassengerId)

							alreadyAssignedPassengers[bestPassengerId] = true
							transportInfo.capacity = transportInfo.capacity - 1
							passengerFound = true
							break
						end
					end
				end

				if not passengerFound then
					break
				end

			end
		end
	end

	return passengerAssignments
end

---------------------------------------------------------------------------------------
--- End of transport logic
---------------------------------------------------------------------------------------

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
	pendingTargetId = nil
	pendingTargetIsFeature = false
	pendingExpireTime = 0
	pendingCmdID = nil
	pendingCmdDescIndex = nil
	pendingAlt = false
	pendingCtrl = false
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
		return toPositionTable(spGetFeaturePosition(getRawFeatureId(targetId)))
	end
	return toPositionTable(spGetUnitPosition(targetId))
end

local function sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst, refUnitID)
	local refPosition
	if refUnitID then
		refPosition = getTargetPosition(refUnitID)
	else
		refPosition = toPositionTable(spGetUnitArrayCentroid(selectedUnits))
	end
	tableSort(filteredTargets, function(targetIdA, targetIdB)
		local positionA = getTargetPosition(targetIdA)
		local positionB = getTargetPosition(targetIdB)

		if closestFirst then
			return distanceSq(refPosition, positionA) < distanceSq(refPosition, positionB)
		else
			return distanceSq(refPosition, positionA) > distanceSq(refPosition, positionB)
		end
	end)
end

local function limitDoubleClickTargetsByRadius(filteredTargets, refTargetId)
	if #filteredTargets <= MAX_DOUBLECLICK_UNITS then
		return filteredTargets
	end
	local refPosition = getTargetPosition(refTargetId)
	sortTargetsByDistance({ refTargetId }, filteredTargets, true, refTargetId)
	local radius = DOUBLECLICK_START_RADIUS
	while radius >= 0 do
		local radiusSq = radius * radius
		local limitedTargets = {}
		for i = 1, #filteredTargets do
			local targetId = filteredTargets[i]
			local targetPosition = getTargetPosition(targetId)
			if distanceSq(refPosition, targetPosition) <= radiusSq then
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
	maxCommands = maxCommands or commandLimit
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

local function issueDoubleClickMassOrders(issueCmdId, selectedUnits, filteredTargets, options, refUnitID)
	if #filteredTargets == 0 then
		return
	end
	if options.ctrl then
		giveOrdersPerUnitSortedFromSelf(issueCmdId, selectedUnits, filteredTargets, options)
	else
		local closestFirst = not options.meta
		sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst, refUnitID)
		giveOrders(issueCmdId, selectedUnits, filteredTargets, options)
	end
end

local function splitTargets(selectedUnits, filteredTargets)
	local unitTargetsMap = {}
	for unitIdx, selectedUnitId in ipairs(selectedUnits) do
		unitTargetsMap[selectedUnitId] = {}
		for targetIdx, targetUnitId in ipairs(filteredTargets) do
			if targetIdx % #filteredTargets == unitIdx % #filteredTargets or unitIdx % #selectedUnits == targetIdx % #selectedUnits then
				tableInsert(unitTargetsMap[selectedUnitId], targetUnitId)
			end
		end
	end
	return unitTargetsMap
end

--- Each unit gets a chunk of the queue
local function splitOrders(cmdId, selectedUnits, filteredTargets, options)
	local selectedUnitsLen = #selectedUnits
	local maxAllowedTargetsPerUnit = mathMax(mathFloor(commandLimit / selectedUnitsLen), 1)

	local unitTargetsMap = splitTargets(selectedUnits, filteredTargets)
	for selectedUnitId, targets in pairs(unitTargetsMap) do
		local selectedUnitTable = { selectedUnitId }
		sortTargetsByDistance(selectedUnitTable, targets, true)
		giveOrders(cmdId, selectedUnitTable, targets, options, maxAllowedTargetsPerUnit)
	end
end

--- All units share the same order queue. Queue can be distributed with shift+meta
local function defaultHandler(cmdId, selectedUnits, filteredTargets, options)
	if options.shift and options.meta then
		splitOrders(cmdId, selectedUnits, filteredTargets, options)
	else
		-- when meta is held it puts orders at the front of the queue so it reverses their order.
		-- sorting has to be reversed to fix that
		local closestFirst = not options.meta
		sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst)
		giveOrders(cmdId, selectedUnits, filteredTargets, options)
	end
end

--- Each transport picks one target
local function loadUnitsHandler(cmdId, selectedUnits, filteredTargets, options)
	local transports = {}
	for _, unitId in ipairs(selectedUnits) do
		local unitDefId = spGetUnitDefID(unitId)
		if unitDefId and transportDefs[unitDefId] then
			transports[#transports + 1] = unitId
		end
	end
	if #transports == 0 then
		return
	end
	local passengerAssignments = distributeTargetsToTransports(transports, filteredTargets)
	-- distributeTargetsToTransports already sorted the targets so no sortTargetsByDistance call here
	for transportId, targetIds in pairs(passengerAssignments) do
		giveOrders(cmdId, { transportId }, targetIds, options)
	end
end

---@class CommandConfig
---@field handle function
---@field allowedTargetTypes table
---@field targetAllegiance number AllUnits = -1, MyUnits = -2, AllyUnits = -3, EnemyUnits = -4

local function commandConfig(targetTypes, targetAllegiance, handler)
	local allowedTargetTypes = {}
	for _, targetType in ipairs(targetTypes) do
		allowedTargetTypes[targetType] = true
	end
	local config = {} --- @type CommandConfig
	config.handle = handler or defaultHandler
	config.allowedTargetTypes = allowedTargetTypes
	config.targetAllegiance = targetAllegiance
	return config
end

---@type table<number, CommandConfig>
local allowedCommands = {
	[CMD.ATTACK] = commandConfig({ UNIT }, ENEMY_UNITS),
	[CMD.CAPTURE] = commandConfig({ UNIT }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET] = commandConfig({ UNIT }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = commandConfig({ UNIT }, ENEMY_UNITS),
	[CMD.GUARD] = commandConfig({ UNIT }, ALLY_UNITS),
	[CMD.REPAIR] = commandConfig({ UNIT }, ALLY_UNITS),
	[CMD.RECLAIM] = commandConfig({ UNIT, FEATURE }, ALL_UNITS),
	[CMD.LOAD_UNITS] = commandConfig({ UNIT }, ALL_UNITS, loadUnitsHandler),
	[CMD.RESURRECT] = commandConfig({ FEATURE }),
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

local function getVisibleUnitsOfType(unitDefID, targetAllegiance)
	local filteredTargets = {}
	local visibleUnits = spGetVisibleUnits()
	if not visibleUnits then
		return filteredTargets
	end
	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if spGetUnitDefID(unitID) == unitDefID then
			local isEnemy = spGetUnitAllyTeam(unitID) ~= myAllyTeamID
			if targetAllegiance == ENEMY_UNITS and not isEnemy then
			elseif targetAllegiance == ALLY_UNITS and isEnemy then
			else
				tableInsert(filteredTargets, unitID)
			end
		end
	end
	return filteredTargets
end

local function getVisibleFeaturesOfType(featureDefID, cmdId)
	local filteredTargets = {}
	local visibleFeatures = spGetVisibleFeatures(-1)
	if not visibleFeatures then
		return filteredTargets
	end
	for i = 1, #visibleFeatures do
		local featureId = visibleFeatures[i]
		if spGetFeatureDefID(featureId) == featureDefID then
			if cmdId == CMD.RESURRECT then
				local unitDefName = spGetFeatureResurrect(featureId)
				if unitDefName and unitDefName ~= "" then
					tableInsert(filteredTargets, normalizeFeatureTargetId(featureId))
				end
			else
				tableInsert(filteredTargets, normalizeFeatureTargetId(featureId))
			end
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
		local isEnemy = spGetUnitAllyTeam(unitID) ~= myAllyTeamID
		if targetAllegiance == ENEMY_UNITS and not isEnemy then
		elseif targetAllegiance == ALLY_UNITS and isEnemy then
		else
			tableInsert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function getAllVisibleFeatures(cmdId)
	local filteredTargets = {}
	local visibleFeatures = spGetVisibleFeatures(-1)
	if not visibleFeatures then
		return filteredTargets
	end
	for i = 1, #visibleFeatures do
		local featureId = visibleFeatures[i]
		if cmdId == CMD.RESURRECT then
			local unitDefName = spGetFeatureResurrect(featureId)
			if unitDefName and unitDefName ~= "" then
				tableInsert(filteredTargets, normalizeFeatureTargetId(featureId))
			end
		else
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
	return true
end

local function collectDoubleClickTargets(cmdId, targetId, isFeature, altMode)
	if altMode then
		if isFeature then
			return getAllVisibleFeatures(cmdId)
		end
		local isEnemy = spGetUnitAllyTeam(targetId) ~= myAllyTeamID
		local targetAllegiance = isEnemy and ENEMY_UNITS or ALLY_UNITS
		return getVisibleUnitsByAllegiance(targetAllegiance)
	end
	if isFeature then
		local featureDefID = spGetFeatureDefID(getRawFeatureId(targetId))
		if not featureDefID then
			return {}
		end
		return getVisibleFeaturesOfType(featureDefID, cmdId)
	end
	local unitDefID = spGetUnitDefID(targetId)
	if not unitDefID then
		return {}
	end
	local config = allowedCommands[cmdId]
	return getVisibleUnitsOfType(unitDefID, config.targetAllegiance)
end

local function issuePendingDoubleClickMassOrders(options)
	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 or not pendingCmdID or not pendingTargetId then
		return false
	end
	local issueCmdId = pendingCmdID
	local refTargetId = pendingTargetId
	local refTargetIsFeature = pendingTargetIsFeature
	local savedCmdDescIndex = pendingCmdDescIndex or spGetCmdDescIndex(issueCmdId)
	local queuing = isQueuing(options)
	clearDoubleClickPending()
	local filteredTargets = collectDoubleClickTargets(issueCmdId, refTargetId, refTargetIsFeature, options.alt)
	filteredTargets = limitDoubleClickTargetsByRadius(filteredTargets, refTargetId)
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
	local realTime = osClock()
	local clickAlt = options.alt or false
	local clickCtrl = options.ctrl or false
	if pendingTargetId
		and pendingCmdID
		and realTime < pendingExpireTime
		and pendingCmdID == effectiveCmdId
		and doubleClickCommands[pendingCmdID]
		and pendingAlt == clickAlt
		and pendingCtrl == clickCtrl
		and spGetGameFrame() ~= lastFirstClickFrame
	then
		issuePendingDoubleClickMassOrders(options)
		return true
	end
	return false
end

local function handleDoubleClickSingleTarget(cmdId, params, options)
	local targetId = params[1]
	local isFeature = isFeatureTargetId(targetId)
	local effectiveCmdId = resolveDoubleClickCmdId(cmdId)

	if tryCompletePendingDoubleClick(options, effectiveCmdId) then
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

	if not doubleClickCommands[effectiveCmdId] then
		return false
	end

	giveOrders(effectiveCmdId, selectedUnits, { targetId }, options)

	pendingTargetId = targetId
	pendingTargetIsFeature = isFeature
	pendingExpireTime = realTime + doubleClickTime
	pendingCmdID = effectiveCmdId
	pendingAlt = clickAlt
	pendingCtrl = clickCtrl
	pendingCmdDescIndex = select(4, spGetActiveCommand()) or spGetCmdDescIndex(effectiveCmdId)
	lastFirstClickFrame = spGetGameFrame()
	if queuing then
		heldCommandDescIndex = pendingCmdDescIndex
	end
	return true
end

function widget:MousePress(mouseX, mouseY, button)
	if button ~= 1 then
		return false
	end
	if not pendingTargetId or not pendingCmdID or osClock() >= pendingExpireTime then
		return false
	end
	if spGetGameFrame() == lastFirstClickFrame then
		return false
	end
	local alt, ctrl, meta, shift = spGetModKeyState()
	local options = { alt = alt, ctrl = ctrl, meta = meta, shift = shift }
	return tryCompletePendingDoubleClick(options, pendingCmdID)
end

local function filterUnits(targetId, cmdX, cmdZ, radius, options, targetAllegiance)
	local alt = options.alt
	local ctrl = options.ctrl
	local filteredTargets = {}
	local unitDefId = spGetUnitDefID(targetId)
	if not unitDefId then
		return nil
	end

	local isEnemyTarget = spGetUnitAllyTeam(targetId) ~= myAllyTeamID
	if isEnemyTarget and targetAllegiance ~= ALL_UNITS and targetAllegiance ~= ENEMY_UNITS then
		-- targeting enemy when only allies are allowed
		return nil
	end

	if isEnemyTarget then
		targetAllegiance = ENEMY_UNITS
	else
		targetAllegiance = spGetUnitTeam(targetId)
	end

	local unitsInArea = spGetUnitsInCylinder(cmdX, cmdZ, radius, targetAllegiance)

	if not unitsInArea then
		return nil
	end

	if ctrl then
		return unitsInArea
	end

	for i = 1, #unitsInArea do
		local unitID = unitsInArea[i]
		if spGetUnitDefID(unitID) == unitDefId then
			tableInsert(filteredTargets, unitID)
		end
	end

	return filteredTargets
end

local function getTechLevel(unitDefName)
	local unitDef = UnitDefNames[unitDefName]
	return unitDef and unitDef.customParams.techlevel
end

local function filterFeatures(targetId, cmdX, cmdZ, radius, options, targetUnitDefName)
	local alt = options.alt
	local ctrl = options.ctrl
	local filteredTargets = {}
	local featureDefId = spGetFeatureDefID(targetId)
	if not featureDefId then
		return nil
	end

	local featuresInArea = spGetFeaturesInCylinder(cmdX, cmdZ, radius)
	if not featuresInArea then
		return nil
	end

	local targetTechLevel
	if ctrl then
		targetTechLevel = getTechLevel(targetUnitDefName)
	end

	for i = 1, #featuresInArea do
		local featureId = featuresInArea[i]
		local shouldInsert = alt and spGetFeatureDefID(featureId) == featureDefId
		if ctrl then
			local unitDefName = spGetFeatureResurrect(featureId)
			local unitTechLevel = getTechLevel(unitDefName)
			if unitTechLevel == targetTechLevel then
				shouldInsert = true
			end
		end
		if shouldInsert then
			if not Engine.FeatureSupport.noOffsetForFeatureID then
				-- featureId is normalised to Game.maxUnits + featureId because of:
				-- https://springrts.com/wiki/Lua_CMDs#CMDTYPE.ICON_UNIT_FEATURE_OR_AREA
				-- "expect 1 parameter in return (unitd or Game.maxUnits+featureid)"
				-- offset due to be removed in future engine version
				featureId = featureId + Game.maxUnits
			end
			tableInsert(filteredTargets, featureId)
		end
	end
	return filteredTargets
end

function widget:CommandNotify(cmdId, params, options)
	if tryCompletePendingDoubleClick(options, resolveDoubleClickCmdId(cmdId)) then
		return true
	end
	if #params == 1 then
		return handleDoubleClickSingleTarget(cmdId, params, options)
	end

	if not (options.alt or options.ctrl) then
		return false
	end

	if #params ~= 4 then
		return false
	end

	local currentCommand = allowedCommands[cmdId]
	if not currentCommand then
		return false
	end

	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 then
		return false
	end

	local cmdX, cmdY, cmdZ, radius = params[1], params[2], params[3], params[4]
	local mouseX, mouseY = spWorldToScreenCoords(cmdX, cmdY, cmdZ)
	local targetType, targetId = spTraceScreenRay(mouseX, mouseY)

	if not currentCommand.allowedTargetTypes[targetType] then
		return false
	end

	local filteredTargets

	if targetType == UNIT then
		filteredTargets = filterUnits(targetId, cmdX, cmdZ, radius, options, currentCommand.targetAllegiance)
	elseif targetType == FEATURE then
		local unitDefName = spGetFeatureResurrect(targetId)
		-- filter only wrecks which can be resurrected
		if unitDefName == nil or unitDefName == "" then
			return false
		end
		filteredTargets = filterFeatures(targetId, cmdX, cmdZ, radius, options, unitDefName)
	end

	if not filteredTargets or #filteredTargets == 0 then
		return false
	end

	currentCommand.handle(cmdId, selectedUnits, filteredTargets, options)
	return true
end

local function initialize()
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
	myAllyTeamID = spGetMyAllyTeamID()
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
	if pendingTargetId and osClock() >= pendingExpireTime then
		clearDoubleClickPending()
	end
	updateShiftCommandKeep()
end

function widget:ActiveCommandChanged(cmdid)
	if cmdid then
		if pendingCmdID and pendingCmdID ~= cmdid then
			clearDoubleClickPending()
		end
		return
	end
	if pendingTargetId and osClock() < pendingExpireTime then
		return
	end
	if heldCommandDescIndex then
		return
	end
	clearDoubleClickPending()
end
