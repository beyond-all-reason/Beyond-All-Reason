local widget = widget ---@type Widget

-- This widget intercepts area commands with modifiers (shift+space, or ctrl, or alt) and reissues them as targeted orders.
--
-- (1) The hovered target when the command is issued is used to determine filtering.
-- (2) Alt and Ctrl are your target filter modifiers:
--     => units: Alt selects by unit type (unitDefID) and Ctrl selects by unit team (see allegiance notes).
--     => features: Alt selects by type (rezzAsDefID) and Ctrl selects by tech level (feature must be resurrectable).
-- (3) You can filter by unit type and unit team together or separately.
--     But feature type "beats" feature tech since it is more specific.
-- (4) Hovering an enemy unit and using the Ctrl "team" filter instead checks for neutrality or hostility:
--     => hover an enemy wall with Ctrl: Filtering will keep neutral targets.
--     => hover an enemy wall w/no Ctrl: Filtering will keep hostile targets.
--     => hover an enemy Pawn with Ctrl: Filtering will keep hostile targets.
--     => hover an enemy Pawn w/no Ctrl: Filtering will keep hostile targets.
-- (5) Shift + Space divide orders between your selected units rather than issue the same orders to all of them.
-- (6) Shift and Space separately queue-last and queue-first as they normally would.
-- (7) Splitting orders and filtering targets can be combined. Just mix and match the modifiers.
--
-- See the `areaToTargetCommands` table for configuration and information on each command's behaviors, which may be unique.
-- In particular, Reclaim orders skip allied units when you hover your own units, while Guard, Repair, and Load do not.

function widget:GetInfo()
	return {
		name = "Area Command Filter",
		desc = "Resend area commands as targeted orders. Space+Shift split orders across units. Alt/Ctrl filter per the hovered target.",
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
local tableNew = table.new
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitNeutral = Spring.GetUnitNeutral
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitArrayCentroid = Spring.GetUnitArrayCentroid
local spGetFeatureResurrect = Spring.GetFeatureResurrect

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local MY_UNITS = Spring.MY_UNITS
local FEATURE = "feature"
local UNIT = "unit"
local UNIT_ID_MAX = Game.maxUnits

-- featureId is normalised to Game.maxUnits + featureId because of:
-- https://springrts.com/wiki/Lua_CMDs#CMDTYPE.ICON_UNIT_FEATURE_OR_AREA
-- "expect 1 parameter in return (unitd or Game.maxUnits+featureid)"
-- offset due to be removed in future engine version
local offsetFeatureID = not Engine.FeatureSupport.noOffsetForFeatureID

local commandLimit = 2000

local myTeamID, myAllyTeamID

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

local canAttack, canCapture, canReclaim = {}, {}, {}
local canGuard, canRepair, canResurrect = {}, {}, {}

for unitDefID, unitDef in pairs(UnitDefs) do
	canAttack[unitDefID]    = unitDef.canAttack and unitDef.maxWeaponRange > 0 or nil
	canCapture[unitDefID]   = unitDef.canCapture or nil
	canGuard[unitDefID]     = unitDef.canGuard or nil
	canRepair[unitDefID]    = unitDef.canRepair or unitDef.canAssist or nil -- assist without repair is nanoframes only, decided per target
	canReclaim[unitDefID]   = unitDef.canReclaim or nil
	canResurrect[unitDefID] = unitDef.canResurrect or nil
end

---------------------------------------------------------------------------------------
--- Target sorting logic (pick the closest first)
---------------------------------------------------------------------------------------

---@param position1 table {x, y, z}
---@param position2 table {x, y, z}
local function distanceSq(position1, position2)
	local dx = position1.x - position2.x
	local dz = position1.z - position2.z
	return dx * dx + dz * dz
end

---@return table {x, y, z}
local function toPositionTable(x, y, z)
	return { x = x, y = y, z = z }
end

local getFeaturePosition, toFeatureTargetIDs; do
	local function getFeaturePositionFromObjectID(targetID)
		return spGetFeaturePosition(targetID)
	end
	local function getFeaturePositionFromOffsetID(targetID)
		return spGetFeaturePosition(targetID - UNIT_ID_MAX)
	end
	getFeaturePosition = offsetFeatureID and getFeaturePositionFromOffsetID or getFeaturePositionFromObjectID

	local function asObjectIDs(featureIDs)
		return featureIDs
	end
	local function toOffsetIDs(featureIDs)
		for index = 1, #featureIDs do
			featureIDs[index] = featureIDs[index] + UNIT_ID_MAX
		end
		return featureIDs
	end
	toFeatureTargetIDs = offsetFeatureID and toOffsetIDs or asObjectIDs
end

----------------------------------------------------------------------------------------------------------
--- Logic which distributes targets between transports. Should be split and extracted to separate widget
--- Preferably after https://github.com/beyond-all-reason/Beyond-All-Reason/pull/5738 will be merged
----------------------------------------------------------------------------------------------------------

-- Multiplier to convert footprints sizes
-- see SPRING_FOOTPRINT_SCALE in GlobalConstants.h in recoil engine repo for details
-- https://github.com/beyond-all-reason/RecoilEngine/blob/master/rts%2FSim%2FMisc%2FGlobalConstants.h
local springFootprintScale = Game.footprintScale

--- @return table<number,table<number>> Map of transportId -> array of passengerIds
local function distributeTargetsToTransports(transports, targets)
	local transportTypeDataMap = {} ---@type table<number,TransportData>
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
					local transportInfo = { capacity = remainingCapacity, position = position } ---@class TransportInfo
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
			-- Radar blips have no readable def, so treat as cantBeTransported.
			local passengerDefId = spGetUnitDefID(targetId)
			if passengerDefId then
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

local function byDistanceToUnit(position, closestFirst)
	if closestFirst ~= false then
		return function(targetIdA, targetIdB)
			local positionA = toPositionTable(spGetUnitPosition(targetIdA))
			local positionB = toPositionTable(spGetUnitPosition(targetIdB))
			return distanceSq(position, positionA) < distanceSq(position, positionB)
		end
	else
		return function(targetIdA, targetIdB)
			local positionA = toPositionTable(spGetUnitPosition(targetIdA))
			local positionB = toPositionTable(spGetUnitPosition(targetIdB))
			return distanceSq(position, positionA) > distanceSq(position, positionB)
		end
	end
end

local function byDistanceToFeature(position, closestFirst)
	if closestFirst ~= false then
		return function(targetIdA, targetIdB)
			local positionA = toPositionTable(getFeaturePosition(targetIdA))
			local positionB = toPositionTable(getFeaturePosition(targetIdB))
			return distanceSq(position, positionA) < distanceSq(position, positionB)
		end
	else
		return function(targetIdA, targetIdB)
			local positionA = toPositionTable(getFeaturePosition(targetIdA))
			local positionB = toPositionTable(getFeaturePosition(targetIdB))
			return distanceSq(position, positionA) > distanceSq(position, positionB)
		end
	end
end

local function sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst)
	local avgPosition = toPositionTable(spGetUnitArrayCentroid(selectedUnits))
	if not filteredTargets[1] then
		return
	elseif filteredTargets[1] <= UNIT_ID_MAX then
		tableSort(filteredTargets, byDistanceToUnit(avgPosition, closestFirst))
	else
		tableSort(filteredTargets, byDistanceToFeature(avgPosition, closestFirst))
	end
end

local function giveOrders(cmdId, selectedUnits, filteredTargets, options, maxCommands)
	maxCommands = maxCommands or commandLimit
	local firstTarget = true
	local selectedUnitsLen = #selectedUnits
	local ordersIssued = 0
	for i, targetId in ipairs(filteredTargets) do
		local cmdOpts = {}
		if not firstTarget or options.shift then
			tableInsert(cmdOpts, "shift")
		end
		if options.meta and not options.shift then
			spGiveOrderToUnitArray(selectedUnits, CMD.INSERT, { 0, cmdId, 0, targetId }, CMD.OPT_ALT)
		else
			spGiveOrderToUnitArray(selectedUnits, cmdId, { targetId }, cmdOpts)
		end
		firstTarget = false
		ordersIssued = ordersIssued + 1
		if i * selectedUnitsLen > maxCommands then
			return ordersIssued
		end
	end
	return ordersIssued
end

local function splitTargets(selectedUnits, filteredTargets)
	local selectedCount = #selectedUnits
	local targetCount = #filteredTargets
	local unitTargetsMap = tableNew(0, selectedCount)
	for index = 1, selectedCount do
		unitTargetsMap[selectedUnits[index]] = {}
	end
	if selectedCount == 0 or targetCount == 0 then
		return unitTargetsMap
	end

	-- We save microseconds by diagonalizing on the index.
	for index = 1, mathMin(selectedCount, targetCount) do
		local targetID = filteredTargets[index]
		local unitID = selectedUnits[index]
		if targetID == unitID then
			-- Never hand a unit its own unitID. Just advance.
			unitID = selectedUnits[index % selectedCount + 1]
		end
		local list = unitTargetsMap[unitID]
		list[#list + 1] = targetID
	end

	-- So the more expensive loop runs on a smaller range.
	if selectedCount < targetCount then
		local unitIndex = 0
		for index = selectedCount + 1, targetCount do
			unitIndex = unitIndex % selectedCount + 1
			local targetID = filteredTargets[index]
			local unitID = selectedUnits[unitIndex]
			if targetID == unitID then
				unitID = selectedUnits[unitIndex % selectedCount + 1]
			end
			local list = unitTargetsMap[unitID]
			list[#list + 1] = targetID
		end
	elseif targetCount < selectedCount then
		local targetIndex = 0
		for index = targetCount + 1, selectedCount do
			targetIndex = targetIndex % targetCount + 1
			local targetID = filteredTargets[targetIndex]
			local unitID = selectedUnits[index]
			if targetID == unitID then
				unitID = selectedUnits[index % selectedCount + 1]
			end
			local list = unitTargetsMap[unitID]
			list[#list + 1] = targetID
		end
	end

	return unitTargetsMap
end

--- Each unit gets a chunk of the queue
local function splitOrders(cmdId, selectedUnits, filteredTargets, options)
	local selectedUnitsLen = #selectedUnits
	local maxAllowedTargetsPerUnit = mathMax(mathFloor(commandLimit / selectedUnitsLen), 1)

	local unitTargetsMap = splitTargets(selectedUnits, filteredTargets)
	local selectedUnitTable = { 0 }
	local ordersIssued = 0
	for selectedUnitId, targets in pairs(unitTargetsMap) do
		selectedUnitTable[1] = selectedUnitId
		sortTargetsByDistance(selectedUnitTable, targets, true)
		ordersIssued = ordersIssued + giveOrders(cmdId, selectedUnitTable, targets, options, maxAllowedTargetsPerUnit)
	end
	return ordersIssued
end

--- All units share the same order queue. Queue can be distributed with shift+meta
local function defaultHandler(cmdId, selectedUnits, filteredTargets, options)
	if options.shift and options.meta then
		return splitOrders(cmdId, selectedUnits, filteredTargets, options)
	else
		-- when meta is held it puts orders at the front of the queue so it reverses their order.
		-- sorting has to be reversed to fix that
		local closestFirst = not options.meta
		sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst)
		return giveOrders(cmdId, selectedUnits, filteredTargets, options)
	end
end

--- Each transport picks one target. Every selected unit is a transport by this point.
local function loadUnitsHandler(cmdId, selectedUnits, filteredTargets, options)
	local passengerAssignments = distributeTargetsToTransports(selectedUnits, filteredTargets)
	-- distributeTargetsToTransports already sorted the targets so no sortTargetsByDistance call here
	local ordersIssued = 0
	for transportId, targetIds in pairs(passengerAssignments) do
		ordersIssued = ordersIssued + giveOrders(cmdId, { transportId }, targetIds, options)
	end
	return ordersIssued
end

local function isResurrectable(featureID)
	return (spGetFeatureResurrect(featureID) or "") ~= ""
end

---@class CommandConfig
---@field handle function
---@field allowedTargetTypes table
---@field targetAllegiance number AllUnits = -1, MyUnits = -2, AllyUnits = -3, EnemyUnits = -4
---@field capableDefs table<number, true> The defs that can ever perform the command.
---@field canTarget function? Whether the command can act on an object at all.
---@field protectAllies boolean? Unfiltered commands target your own units instead of allies.

local function commandConfig(targetTypes, targetAllegiance, capableDefs, canTarget, handler, protectAllies)
	local allowedTargetTypes = {}
	for _, targetType in ipairs(targetTypes) do
		allowedTargetTypes[targetType] = true
	end
	--- @type CommandConfig
	local config = {
		handle             = handler or defaultHandler,
		allowedTargetTypes = allowedTargetTypes,
		targetAllegiance   = targetAllegiance,
		capableDefs        = capableDefs,
		canTarget          = canTarget,
		protectAllies      = protectAllies,
	}
	return config
end

---@type table<number, CommandConfig>
local areaToTargetCommands = {
	[CMD.ATTACK]                        = commandConfig({ UNIT },          ENEMY_UNITS, canAttack),
	[CMD.CAPTURE]                       = commandConfig({ UNIT },          ENEMY_UNITS, canCapture),
	[GameCMD.UNIT_SET_TARGET]           = commandConfig({ UNIT },          ENEMY_UNITS, canAttack),
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = commandConfig({ UNIT },          ENEMY_UNITS, canAttack),
	[CMD.GUARD]                         = commandConfig({ UNIT },          ALLY_UNITS,  canGuard),
	[CMD.REPAIR]                        = commandConfig({ UNIT },          ALLY_UNITS,  canRepair),
	[CMD.RECLAIM]                       = commandConfig({ UNIT, FEATURE }, ALL_UNITS,   canReclaim, nil, nil, true),
	[CMD.LOAD_UNITS]                    = commandConfig({ UNIT },          ALL_UNITS,   transportDefs, nil, loadUnitsHandler),
	[CMD.RESURRECT]                     = commandConfig({ FEATURE },       nil,         canResurrect, isResurrectable),
}

--- The selected units that can perform the command at all.
local function getCapableUnits(selectedUnits, capableDefs)
	local firstDrop
	for index = 1, #selectedUnits do
		if not capableDefs[spGetUnitDefID(selectedUnits[index])] then
			firstDrop = index
			break
		end
	end

	if not firstDrop then
		return selectedUnits[1] and selectedUnits or nil
	end

	local keep, count = {}, firstDrop - 1
	for index = 1, count do
		keep[index] = selectedUnits[index]
	end
	for index = firstDrop + 1, #selectedUnits do
		local unitID = selectedUnits[index]
		if capableDefs[spGetUnitDefID(unitID)] then
			count = count + 1
			keep[count] = unitID
		end
	end
	return count > 0 and keep or nil
end

---Everything in the area that the command can target.
local function gatherUnits(cmdX, cmdZ, radius, allegiance)
	---@diagnostic disable-next-line: redundant-parameter -- FIXME: GetUnitsInXYZ do not document their allegiance/team param.
	local unitsInArea = spGetUnitsInCylinder(cmdX, cmdZ, radius, allegiance)
	return unitsInArea[1] and unitsInArea or nil
end

---The narrower target list based on the hovered unit.
local function narrowUnits(unitsInArea, targetDefId, filterType, filterHostile, filterNeutral)
	if filterType then
		local targetsByType, count = {}, 0
		for i = 1, #unitsInArea do
			local unitID = unitsInArea[i]
			if spGetUnitDefID(unitID) == targetDefId then
				count = count + 1
				targetsByType[count] = unitID
			end
		end
		if count == 0 then
			return
		end
		unitsInArea = targetsByType
	end

	if filterHostile or filterNeutral then
		local dropNeutrality = filterHostile
		local firstDrop
		for index = 1, #unitsInArea do
			local unitID = unitsInArea[index]
			if spGetUnitNeutral(unitID) == dropNeutrality then
				firstDrop = index
				break
			end
		end

		if firstDrop then
			local keep, count = {}, firstDrop - 1
			for index = 1, count do
				keep[index] = unitsInArea[index]
			end
			for index = firstDrop + 1, #unitsInArea do
				local unitID = unitsInArea[index]
				if spGetUnitNeutral(unitID) ~= dropNeutrality then
					count = count + 1
					keep[count] = unitID
				end
			end
			if count == 0 then
				return
			end
			unitsInArea = keep
		end
	end

	return unitsInArea
end

local function filterUnits(targetId, cmdX, cmdZ, radius, options, allegiance, protectAllies)
	local targetDefId = spGetUnitDefID(targetId)
	local targetTeam = spGetUnitTeam(targetId) or -1
	local isEnemyTarget = spGetUnitAllyTeam(targetId) ~= myAllyTeamID -- Unit can be a ceasefired enemy.
	local isAlliedTarget = spAreTeamsAllied(targetTeam, myTeamID) -- So prefer to check on alliance.

	local filterTeam = options.ctrl
	local filterType = targetDefId and options.alt
	if not filterTeam and not protectAllies and isAlliedTarget and isEnemyTarget then
		filterTeam = true -- ALLY_UNITS excludes ceasefired allyTeams.
	end

	local filterHostile, filterNeutral = false, false

	if isAlliedTarget then
		if allegiance == ENEMY_UNITS then
			return nil, true
		end
		allegiance = filterTeam and targetTeam
			or (protectAllies and targetTeam == myTeamID and MY_UNITS or ALLY_UNITS)
	else
		if allegiance == ALLY_UNITS then
			return nil, true
		end
		allegiance = ENEMY_UNITS -- Enemy teams cannot be distinguished, but neutral vs hostile can.
		if filterTeam and spGetUnitNeutral(targetId) then
			filterNeutral = true -- Strange case: Targeting neutrals with Ctrl filters for neutrals.
		else
			filterHostile = true -- We want to replicate the behavior of exclude_walls_area_attacks.
		end
	end

	local unitsInArea = gatherUnits(cmdX, cmdZ, radius, allegiance)
	if not unitsInArea then
		return
	end

	return narrowUnits(unitsInArea, targetDefId, filterType, filterHostile, filterNeutral)
end

local function getTechLevel(unitDefName)
	local unitDef = UnitDefNames[unitDefName]
	return unitDef and unitDef.customParams.techlevel
end

local function hasSplitModifiers(options)
	return options.shift and options.meta
end

local function hasFilterModifiers(options)
	return options.alt or options.ctrl
end

---Everything in the area that the command can target.
local function gatherFeatures(cmdX, cmdZ, radius, canTarget)
	local featuresInArea = spGetFeaturesInCylinder(cmdX, cmdZ, radius)
	if not featuresInArea[1] then
		return
	end
	if not canTarget then
		return featuresInArea
	end

	local targetable, count = {}, 0
	for index = 1, #featuresInArea do
		local featureId = featuresInArea[index]
		if canTarget(featureId) then
			count = count + 1
			targetable[count] = featureId
		end
	end
	if count > 0 then
		return targetable
	end
end

---The narrower target list based on the hovered feature.
local function narrowFeatures(featuresInArea, targetId, options)
	local targetUnitDefName = spGetFeatureResurrect(targetId)
	local hasUnitDefName = (targetUnitDefName or "") ~= ""

	local filterType = hasUnitDefName and options.alt
	local filterTech = hasUnitDefName and not filterType and options.ctrl

	if not filterType and not filterTech then
		return nil, true
	end

	local featureDefId = spGetFeatureDefID(targetId)
	local targetTechLevel = filterTech and getTechLevel(targetUnitDefName)

	local filteredTargets, count = {}, 0
	for index = 1, #featuresInArea do
		local featureId = featuresInArea[index]
		local matched
		if filterType then
			-- Type out-specifies tech level, so do not check it.
			matched = spGetFeatureDefID(featureId) == featureDefId
		else
			matched = getTechLevel(spGetFeatureResurrect(featureId)) == targetTechLevel
		end
		if matched then
			count = count + 1
			filteredTargets[count] = featureId
		end
	end
	if count > 0 then
		return filteredTargets
	end
end

local function filterFeatures(targetId, cmdX, cmdZ, radius, options, canTarget)
	local featuresInArea = gatherFeatures(cmdX, cmdZ, radius, canTarget)
	if not featuresInArea then
		return
	end
	local filteredTargets, seedUnusable = narrowFeatures(featuresInArea, targetId, options)
	if seedUnusable then
		return nil, true
	end
	return filteredTargets and toFeatureTargetIDs(filteredTargets)
end

---Everything the command can act on when both features and units are targetable.
---With no (valid) hovered object, we no longer know which object type to target.
local function gatherTargets(command, cmdX, cmdZ, radius)
	-- TODO: It's not clear that features should be prioritized.
	if command.allowedTargetTypes[FEATURE] then
		local featuresInArea = gatherFeatures(cmdX, cmdZ, radius, command.canTarget)
		if featuresInArea then
			return toFeatureTargetIDs(featuresInArea)
		end
	end
	if command.allowedTargetTypes[UNIT] then
		-- TODO: It's not clear that ENEMY_UNITS instead of MY_UNITS should be the selection.
		local allegiance = command.protectAllies and ENEMY_UNITS or command.targetAllegiance
		return gatherUnits(cmdX, cmdZ, radius, allegiance)
	end
end

function widget:CommandNotify(cmdId, params, options)
	local command = areaToTargetCommands[cmdId]
	if not command then
		return false
	end

	if not (#params == 4 and params[4] >= 1) then
		return false
	end

	local split = hasSplitModifiers(options)
	if not split and not hasFilterModifiers(options) then
		return false
	end

	local cmdX, cmdY, cmdZ, radius = params[1], params[2], params[3], params[4]
	local targetType, targetId = spTraceScreenRay(spWorldToScreenCoords(cmdX, cmdY, cmdZ))
	local seedType = command.allowedTargetTypes[targetType] and targetType
	if not seedType and not split then
		return false
	end

	local selectedUnits = getCapableUnits(spGetSelectedUnits(), command.capableDefs)
	if not selectedUnits then
		return false
	end

	local filteredTargets, seedUnusable
	if seedType == FEATURE then
		filteredTargets, seedUnusable = filterFeatures(targetId, cmdX, cmdZ, radius, options, command.canTarget)
	elseif seedType == UNIT then
		filteredTargets, seedUnusable = filterUnits(targetId, cmdX, cmdZ, radius, options, command.targetAllegiance, command.protectAllies)
	else
		seedUnusable = true
	end

	if seedUnusable then
		if not split then
			return false
		end
		filteredTargets = gatherTargets(command, cmdX, cmdZ, radius)
		if not filteredTargets then
			return false
		end
	elseif not filteredTargets then
		return true
	end

	-- The handle can decide to place no orders, e.g. when no passenger fits any transport.
	return command.handle(cmdId, selectedUnits, filteredTargets, options) > 0
end

local function initialize()
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
end

function widget:PlayerChanged()
	initialize()
end

function widget:Initialize()
	initialize()
end
