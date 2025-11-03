local widget = widget ---@type RulesUnsyncedCallins

-- When performing an area command for one of the `allowedCommands` below:
-- - If Ctrl is pressed and hovering over a unit, targets all units with the same alliance (enemy/allied) in the area.
-- - If Alt is pressed and hovering over a unit, targets all units that share the same unitdefid in the area.
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

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitArrayCentroid = Spring.GetUnitArrayCentroid
local spGetFeatureResurrect = Spring.GetFeatureResurrect
local spGetUnitTeam = Spring.GetUnitTeam
local spAreTeamsAllied = Spring.AreTeamsAllied

local myTeamID
local myAllyTeamID

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
		local transportedUnits = spGetUnitIsTransporting(transportUnitId)
		local maxCapacity = transportDefs[transportDefId].maxCapacity
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
					transportHealth = transportDefs[transportDefId].health
				}
			end
			local position = toPositionTable(spGetUnitPosition(transportUnitId))
			---@class TransportInfo
			local transportInfo = { capacity = remainingCapacity, position = position }
			transportTypeDataMap[transportDefId].transportsInfo[transportUnitId] = transportInfo
			table.insert(transportTypeDataMap[transportDefId].transportIdsList, transportUnitId)
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
				table.insert(transportTypeData.allValidPassengers, targetId)
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
		table.sort(transportTypeData.allValidPassengers, function(a, b)
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
			table.insert(transportTypeData.passengersByPriority[priority], passengerId)
		end
		transportTypeData.maxPriority = maxPriority

		table.insert(orderedTransportDefs, transDefId)
	end

	-- 5. Sort transport types
	table.sort(orderedTransportDefs, function(a, b)
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
							table.insert(passengerAssignments[transportId], bestPassengerId)

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

local function sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst)
	local avgPosition = toPositionTable(spGetUnitArrayCentroid(selectedUnits))
	table.sort(filteredTargets, function(targetIdA, targetIdB)
		local positionA, positionB

		-- Have to convert back to featureId
		if targetIdA > Game.maxUnits then
			positionA = toPositionTable(spGetFeaturePosition(targetIdA - Game.maxUnits))
			positionB = toPositionTable(spGetFeaturePosition(targetIdB - Game.maxUnits))
		else
			positionA = toPositionTable(spGetUnitPosition(targetIdA))
			positionB = toPositionTable(spGetUnitPosition(targetIdB))
		end

		if closestFirst then
			return distanceSq(avgPosition, positionA) < distanceSq(avgPosition, positionB)
		else
			return distanceSq(avgPosition, positionA) > distanceSq(avgPosition, positionB)
		end
	end)
end

local function giveOrders(cmdId, selectedUnits, filteredTargets, options)
	local count = 0
	for _, targetId in ipairs(filteredTargets) do
		local cmdOpts = {}
		if count > 0 or options.shift then
			table.insert(cmdOpts, "shift")
		end
		if options.meta and not options.shift then
			spGiveOrderToUnitArray(selectedUnits, CMD.INSERT, { 0, cmdId, 0, targetId }, CMD.OPT_ALT)
		else
			spGiveOrderToUnitArray(selectedUnits, cmdId, { targetId }, cmdOpts)
		end
		count = count + 1
	end
end

local function splitTargets(selectedUnits, filteredTargets)
	local unitTargetsMap = {}
	for unitIdx, selectedUnitId in ipairs(selectedUnits) do
		unitTargetsMap[selectedUnitId] = {}
		for targetIdx, targetUnitId in ipairs(filteredTargets) do
			if targetIdx % #filteredTargets == unitIdx % #filteredTargets or unitIdx % #selectedUnits == targetIdx % #selectedUnits then
				table.insert(unitTargetsMap[selectedUnitId], targetUnitId)
			end
		end
	end
	return unitTargetsMap
end

--- Each unit gets a chunk of the queue
local function splitOrders(cmdId, selectedUnits, filteredTargets, options)
	local unitTargetsMap = splitTargets(selectedUnits, filteredTargets)
	for selectedUnitId, targets in pairs(unitTargetsMap) do
		local selectedUnitTable = { selectedUnitId }
		sortTargetsByDistance(selectedUnitTable, targets, true)
		giveOrders(cmdId, selectedUnitTable, targets, options)
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
	local passengerAssignments = distributeTargetsToTransports(selectedUnits, filteredTargets)
	-- distributeTargetsToTransports already sorted the targets so no sortTargetsByDistance call here
	for transportId, targetIds in pairs(passengerAssignments) do
		giveOrders(cmdId, { transportId }, targetIds, options)
	end
end

local FEATURE = "feature"
local UNIT = "unit"

---@class CommandConfig
---@field handle function
---@field allowedTargetTypes table
---@field skipAlliedUnits? boolean

---@type table<number, CommandConfig>
local allowedCommands = {
	[CMD.ATTACK] = { handle = defaultHandler, allowedTargetTypes = { [UNIT] = true }, skipAlliedUnits = true },
	[CMD.GUARD] = { handle = defaultHandler, allowedTargetTypes = { [UNIT] = true } },
	[CMD.RECLAIM] = { handle = defaultHandler, allowedTargetTypes = { [UNIT] = true, [FEATURE] = true } },
	[CMD.REPAIR] = { handle = defaultHandler, allowedTargetTypes = { [UNIT] = true } },
	[CMD.CAPTURE] = { handle = defaultHandler, allowedTargetTypes = { [UNIT] = true } },
	[GameCMD.UNIT_SET_TARGET] = { handle = defaultHandler, allowedTargetTypes = { [UNIT] = true } },
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = { handle = defaultHandler, allowedTargetTypes = { [UNIT] = true } },
	[CMD.RESURRECT] = { handle = defaultHandler, allowedTargetTypes = { [FEATURE] = true } },
	[CMD.LOAD_UNITS] = { handle = loadUnitsHandler, allowedTargetTypes = { [UNIT] = true } },
}

local function filterUnits(targetId, cmdX, cmdZ, radius, options, skipAlliedUnits)
	local filteredTargets = {}
	local unitDefId = spGetUnitDefID(targetId)
	if not unitDefId then
		return nil
	end

	local isEnemyTarget = (spGetUnitAllyTeam(targetId) ~= myAllyTeamID)

	local unitsInArea
	if isEnemyTarget then
		unitsInArea = spGetUnitsInCylinder(cmdX, cmdZ, radius, Spring.ENEMY_UNITS)
	elseif not skipAlliedUnits then
		local nearbyUnits = spGetUnitsInCylinder(cmdX, cmdZ, radius)
		if not nearbyUnits then
			return nil
		end

		unitsInArea = {}
		for i = 1, #nearbyUnits do
			local unitID = nearbyUnits[i]
			if spAreTeamsAllied(spGetUnitTeam(unitID), myTeamID) then
				unitsInArea[#unitsInArea + 1] = unitID
			end
		end

		if #unitsInArea == 0 then
			return nil
		end
	end
	if not unitsInArea then
		return nil
	end

	if options.ctrl then
		return unitsInArea
	end

	for i = 1, #unitsInArea do
		local unitID = unitsInArea[i]
		if spGetUnitDefID(unitID) == unitDefId then
			table.insert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function filterFeatures(targetId, cmdX, cmdZ, radius, options)
	if not options.alt then
		return nil
	end

	local filteredTargets = {}
	local featureDefId = spGetFeatureDefID(targetId)
	if not featureDefId then
		return nil
	end

	local featuresInArea = spGetFeaturesInCylinder(cmdX, cmdZ, radius)
	if not featuresInArea then
		return nil
	end

	for i = 1, #featuresInArea do
		local featureId = featuresInArea[i]
		if spGetFeatureDefID(featureId) == featureDefId then
			-- featureId is normalised to Game.maxUnits + featureId because of:
			-- https://springrts.com/wiki/Lua_CMDs#CMDTYPE.ICON_UNIT_FEATURE_OR_AREA
			-- "expect 1 parameter in return (unitid or Game.maxUnits+featureid)"
			featureId = Game.maxUnits + featureId
			table.insert(filteredTargets, featureId)
		end
	end
	return filteredTargets
end

function widget:CommandNotify(cmdId, params, options)
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
		filteredTargets = filterUnits(targetId, cmdX, cmdZ, radius, options, currentCommand.skipAlliedUnits)
	elseif targetType == FEATURE then
		local featureDefName = spGetFeatureResurrect(targetId)
		-- filter only wrecks which can be resurrected
		if featureDefName == nil or featureDefName == "" then
			return false
		end
		filteredTargets = filterFeatures(targetId, cmdX, cmdZ, radius, options)
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
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()
end

function widget:PlayerChanged()
	initialize()
end

function widget:Initialize()
	initialize()
end
