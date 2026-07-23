local widget = widget ---@type Widget

-- When performing an area command for one of the `allowedCommands` below:
-- - If enemy unit is targeted then targetAllegiance=ENEMY_UNITS otherwise targetAllegiance=targetTeamId
-- - If Ctrl is pressed and hovering over a unit, targets all units in the area. For wrecks, it targets all wrecks with the same tech level
-- - If Alt is pressed and hovering over a unit, targets all units that share the same unitDefId in the area.
-- - If Meta is pressed, orders are put in front of the order queue.
-- - If Meta and Shift are pressed, splits orders between selected units. Orders are placed at the end of the queue
function widget:GetInfo()
	return {
		name = "Area Command Filter",
		desc = "Hold Alt or Ctrl with an area command (Reclaim, Load, Attack, etc.) centered on a unit or feature to filter targets.",
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
local mathClamp = math.clamp

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

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local FEATURE = "feature"
local UNIT = "unit"
local UNIT_ID_MAX = Game.maxUnits

-- featureId is normalised to Game.maxUnits + featureId because of:
-- https://springrts.com/wiki/Lua_CMDs#CMDTYPE.ICON_UNIT_FEATURE_OR_AREA
-- "expect 1 parameter in return (unitd or Game.maxUnits+featureid)"
-- offset due to be removed in future engine version
local offsetFeatureID = not Engine.FeatureSupport.noOffsetForFeatureID

local commandLimit = 2000

local myAllyTeamID

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
			local positionA = toPositionTable(spGetFeaturePosition(targetIdA))
			local positionB = toPositionTable(spGetFeaturePosition(targetIdB))
			return distanceSq(position, positionA) < distanceSq(position, positionB)
		end
	else
		return function(targetIdA, targetIdB)
			local positionA = toPositionTable(spGetFeaturePosition(targetIdA))
			local positionB = toPositionTable(spGetFeaturePosition(targetIdB))
			return distanceSq(position, positionA) > distanceSq(position, positionB)
		end
	end
end

local function sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst)
	local avgPosition = toPositionTable(spGetUnitArrayCentroid(selectedUnits))
	if filteredTargets[1] <= UNIT_ID_MAX then
		tableSort(filteredTargets, byDistanceToUnit(avgPosition, closestFirst))
	else
		tableSort(filteredTargets, byDistanceToFeature(avgPosition, closestFirst))
	end
end

local function giveOrders(cmdId, selectedUnits, filteredTargets, options, maxCommands)
	maxCommands = maxCommands or commandLimit
	local firstTarget = true
	local selectedUnitsLen = #selectedUnits
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
		if i * selectedUnitsLen > maxCommands then
			return
		end
	end
end

local function splitTargets(selectedUnits, filteredTargets)
	local selectedCount = #selectedUnits
	local unitTargetsMap = tableNew(0, selectedCount)
	for index = 1, selectedCount do
		unitTargetsMap[selectedUnits[index]] = {}
	end
	local currentUnitIndex = 0
	for index = 1, #filteredTargets do
		currentUnitIndex = (currentUnitIndex % selectedCount) + 1
		tableInsert(unitTargetsMap[selectedUnits[currentUnitIndex]], filteredTargets[index])
	end
	return unitTargetsMap
end

--- Each unit gets a chunk of the queue
local function splitOrders(cmdId, selectedUnits, filteredTargets, options)
	local selectedUnitsLen = #selectedUnits
	local maxAllowedTargetsPerUnit = mathClamp(mathFloor(commandLimit / selectedUnitsLen), 1, commandLimit)

	local unitTargetsMap = splitTargets(selectedUnits, filteredTargets)
	local selectedUnitTable = { 0 }
	for selectedUnitId, targets in pairs(unitTargetsMap) do
		selectedUnitTable[1] = selectedUnitId
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

local function filterUnits(targetId, cmdX, cmdZ, radius, options, allegiance)
	local targetDefId = spGetUnitDefID(targetId)
	if not targetDefId then
		return
	end

	local filterTeam = options.ctrl
	local filterType = not filterTeam and options.alt

	if allegiance ~= ALLY_UNITS and spGetUnitAllyTeam(targetId) ~= myAllyTeamID then
		allegiance = ENEMY_UNITS
	elseif allegiance ~= ENEMY_UNITS and filterTeam then
		allegiance = spGetUnitTeam(targetId)
	end

	local unitsInArea = spGetUnitsInCylinder(cmdX, cmdZ, radius, allegiance)
	if not unitsInArea[1] then
		return
	end

	if filterTeam then
		return unitsInArea
	end

	if filterType then
		local targetsByType, count = {}, 0
		for i = 1, #unitsInArea do
			local unitID = unitsInArea[i]
			if spGetUnitDefID(unitID) == targetDefId then
				count = count + 1
				targetsByType[count] = unitID
			end
		end
		if count > 0 then
			return targetsByType
		end
	end
end

local function getTechLevel(unitDefName)
	local unitDef = UnitDefNames[unitDefName]
	return unitDef and unitDef.customParams.techlevel
end

local function filterFeatures(targetId, cmdX, cmdZ, radius, options)
	local featureDefId = spGetFeatureDefID(targetId)
	if not featureDefId then
		return
	end

	local targetUnitDefName = spGetFeatureResurrect(targetId)
	if (targetUnitDefName or "") == "" then
		return
	end

	local filterType = options.alt
	local filterTech = not filterType and options.ctrl

	local featuresInArea = spGetFeaturesInCylinder(cmdX, cmdZ, radius)
	if not featuresInArea[1] then
		return
	end

	local targetTechLevel = filterTech and getTechLevel(targetUnitDefName)

	local filteredTargets, count = {}, 0
	for i = 1, #featuresInArea do
		local featureId = featuresInArea[i]
		local matched = false
		if filterType then
			matched = spGetFeatureDefID(featureId) == featureDefId
		elseif filterTech then
			local unitDefName = spGetFeatureResurrect(featureId)
			matched = getTechLevel(unitDefName) == targetTechLevel
		end
		if matched then
			if offsetFeatureID then
				featureId = featureId + UNIT_ID_MAX
			end
			count = count + 1
			filteredTargets[count] = featureId
		end
	end
	if count > 0 then
		return filteredTargets
	end
end

function widget:CommandNotify(cmdId, params, options)
	if not (options.alt or options.ctrl) then
		return false
	end

	if #params ~= 4 or params[4] < 4 then
		return false
	end

	local areaCommand = allowedCommands[cmdId]
	if not areaCommand then
		return false
	end

	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 then
		return false
	end

	local cmdX, cmdY, cmdZ, radius = params[1], params[2], params[3], params[4]
	local screenX, screenY = spWorldToScreenCoords(cmdX, cmdY, cmdZ)
	local targetType, targetId = spTraceScreenRay(screenX, screenY)

	if not areaCommand.allowedTargetTypes[targetType] then
		return false
	end

	local filteredTargets
	if targetType == UNIT then
		filteredTargets = filterUnits(targetId, cmdX, cmdZ, radius, options, areaCommand.targetAllegiance)
	elseif targetType == FEATURE then
		filteredTargets = filterFeatures(targetId, cmdX, cmdZ, radius, options)
	end
	if not filteredTargets then
		return false
	end

	areaCommand.handle(cmdId, selectedUnits, filteredTargets, options)
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
