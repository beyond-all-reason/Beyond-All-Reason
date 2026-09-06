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
		desc = "Hold Alt or Ctrl with an area command (Reclaim, Load, Attack, etc.) centered on a unit or feature to filter targets.",
		author = "SuperKitowiec. Based on Specific Unit Reclaimer and Loader by Google Frog",
		date = "October 16, 2025",
		license = "GNU GPL, v2 or later",
		layer = -1, -- Has to be run before Smart Area Reclaim widget
		enabled = true,
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
local spGetUnitNeutral = Spring.GetUnitNeutral
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitArrayCentroid = Spring.GetUnitArrayCentroid
local spGetFeatureResurrect = Spring.GetFeatureResurrect

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local FEATURE = "feature"
local UNIT = "unit"
local CMD_ATTACK_TARGETS = GameCMD.ATTACK_TARGETS
local CMD_UNIT_SET_TARGETS = GameCMD.UNIT_SET_TARGETS

local objectifiedUnitDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.objectify then
		objectifiedUnitDefs[unitDefID] = true
	end
end

local commandLimit = 2000

-- Spring.GiveOrderToUnitArray uses NETMSG_AICOMMANDS. Its current wire format
-- has 17 bytes of fixed data, two bytes per source unit ID, and four bytes per
-- command parameter, and the engine drops packets larger than 8192 bytes.
local targetListPacketSizeLimit = 8192
local targetListPacketFixedSize = 17
local targetListSourceIDSize = 2
local targetListParamSize = 4
local targetListPreferredSourceBatchSize = 256
local insertCommandParamCount = 3

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
							transportHealth = transportDef.health,
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
	--- priority passengers only when there are no one left in the higher bracket.
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

local function sortTargetsByDistance(selectedUnits, filteredTargets, closestFirst)
	local avgPosition = toPositionTable(spGetUnitArrayCentroid(selectedUnits))
	tableSort(filteredTargets, function(targetIdA, targetIdB)
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

local function giveTargetList(listCommandID, selectedUnits, targetIDs, options)
	if not listCommandID or #targetIDs == 0 then
		return false
	end

	local baseCommandOptions = 0
	if options.shift then
		baseCommandOptions = baseCommandOptions + CMD.OPT_SHIFT
	end
	if options.ctrl then
		baseCommandOptions = baseCommandOptions + CMD.OPT_CTRL
	end
	if options.meta and listCommandID == CMD_UNIT_SET_TARGETS then
		baseCommandOptions = baseCommandOptions + CMD.OPT_META
	end

	local prepend = options.meta and not options.shift
	local extraParamCount = prepend and insertCommandParamCount or 0
	local maxTargetsPerPacket = mathFloor(
		(
			targetListPacketSizeLimit
			- targetListPacketFixedSize
			- targetListPreferredSourceBatchSize * targetListSourceIDSize
		) / targetListParamSize
	) - extraParamCount

	local targetChunks = {}
	for firstTargetIndex = 1, #targetIDs, maxTargetsPerPacket do
		local lastTargetIndex = math.min(firstTargetIndex + maxTargetsPerPacket - 1, #targetIDs)
		local targetChunk = {}
		for targetIndex = firstTargetIndex, lastTargetIndex do
			targetChunk[#targetChunk + 1] = targetIDs[targetIndex]
		end
		targetChunks[#targetChunks + 1] = targetChunk
	end

	local function giveTargetChunk(targetChunk, chunkIndex)
		local commandOptions = baseCommandOptions
		if chunkIndex > 1 and not options.shift and (not prepend or listCommandID == CMD_ATTACK_TARGETS) then
			commandOptions = commandOptions + CMD.OPT_SHIFT
		end

		local commandID = listCommandID
		local params = targetChunk
		local outerOptions = commandOptions
		if prepend then
			params = { 0, listCommandID, commandOptions }
			for targetIndex = 1, #targetChunk do
				params[targetIndex + insertCommandParamCount] = targetChunk[targetIndex]
			end
			commandID = CMD.INSERT
			outerOptions = CMD.OPT_ALT
		end

		local packetParamCount = #targetChunk + extraParamCount
		local sourceBatchSize = mathFloor(
			(targetListPacketSizeLimit - targetListPacketFixedSize - packetParamCount * targetListParamSize)
				/ targetListSourceIDSize
		)
		sourceBatchSize = mathMax(1, math.min(sourceBatchSize, targetListPreferredSourceBatchSize))

		for firstSourceIndex = 1, #selectedUnits, sourceBatchSize do
			local lastSourceIndex = math.min(firstSourceIndex + sourceBatchSize - 1, #selectedUnits)
			local sourceBatch = {}
			for sourceIndex = firstSourceIndex, lastSourceIndex do
				sourceBatch[#sourceBatch + 1] = selectedUnits[sourceIndex]
			end
			spGiveOrderToUnitArray(sourceBatch, commandID, params, outerOptions)
		end
	end

	if prepend then
		-- Every insert is placed at queue position zero. Send chunks backwards so
		-- they end up in their original order. Set Target consumes each inserted
		-- command immediately and prepends it; Attack keeps shifted later chunks
		-- adjacent so its controller can combine them.
		for chunkIndex = #targetChunks, 1, -1 do
			giveTargetChunk(targetChunks[chunkIndex], chunkIndex)
		end
	else
		for chunkIndex = 1, #targetChunks do
			giveTargetChunk(targetChunks[chunkIndex], chunkIndex)
		end
	end
	return true
end

local function splitTargets(selectedUnits, filteredTargets)
	local unitTargetsMap = {}
	for unitIdx, selectedUnitId in ipairs(selectedUnits) do
		unitTargetsMap[selectedUnitId] = {}
		for targetIdx, targetUnitId in ipairs(filteredTargets) do
			if
				targetIdx % #filteredTargets == unitIdx % #filteredTargets
				or unitIdx % #selectedUnits == targetIdx % #selectedUnits
			then
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

local function attackTargetListHandler(cmdId, selectedUnits, filteredTargets, options)
	if options.shift and options.meta then
		local unitTargetsMap = splitTargets(selectedUnits, filteredTargets)
		for selectedUnitID, targetIDs in pairs(unitTargetsMap) do
			sortTargetsByDistance({ selectedUnitID }, targetIDs, true)
			giveTargetList(CMD_ATTACK_TARGETS, { selectedUnitID }, targetIDs, options)
		end
	else
		sortTargetsByDistance(selectedUnits, filteredTargets, true)
		giveTargetList(CMD_ATTACK_TARGETS, selectedUnits, filteredTargets, options)
	end
end

local function setTargetListHandler(cmdId, selectedUnits, filteredTargets, options)
	if options.shift and options.meta then
		local unitTargetsMap = splitTargets(selectedUnits, filteredTargets)
		for selectedUnitID, targetIDs in pairs(unitTargetsMap) do
			sortTargetsByDistance({ selectedUnitID }, targetIDs, true)
			giveTargetList(CMD_UNIT_SET_TARGETS, { selectedUnitID }, targetIDs, options)
		end
	else
		sortTargetsByDistance(selectedUnits, filteredTargets, true)
		giveTargetList(CMD_UNIT_SET_TARGETS, selectedUnits, filteredTargets, options)
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
	[CMD.ATTACK] = commandConfig({ UNIT }, ENEMY_UNITS, attackTargetListHandler),
	[CMD.CAPTURE] = commandConfig({ UNIT }, ENEMY_UNITS),
	[GameCMD.UNIT_SET_TARGET] = commandConfig({ UNIT }, ENEMY_UNITS, setTargetListHandler),
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = commandConfig({ UNIT }, ENEMY_UNITS, setTargetListHandler),
	[CMD.GUARD] = commandConfig({ UNIT }, ALLY_UNITS),
	[CMD.REPAIR] = commandConfig({ UNIT }, ALLY_UNITS),
	[CMD.RECLAIM] = commandConfig({ UNIT, FEATURE }, ALL_UNITS),
	[CMD.LOAD_UNITS] = commandConfig({ UNIT }, ALL_UNITS, loadUnitsHandler),
	[CMD.RESURRECT] = commandConfig({ FEATURE }),
}

local function filterUnits(targetId, cmdX, cmdZ, radius, options, targetAllegiance)
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

---@return integer?
local function getUnitNearestAreaCenter(cmdX, cmdY, cmdZ, radius, targetAllegiance)
	local centerUnits = spGetUnitsInCylinder(cmdX, cmdZ, radius, targetAllegiance)
	if not centerUnits or not centerUnits[1] then
		return
	end

	local centerScreenX, centerScreenY = spWorldToScreenCoords(cmdX, cmdY, cmdZ)
	local closestUnitID
	local closestDistanceSq
	for index = 1, #centerUnits do
		local unitID = centerUnits[index]
		local unitX, unitY, unitZ = spGetUnitViewPosition(unitID)
		if unitX then
			local unitScreenX, unitScreenY = spWorldToScreenCoords(unitX, unitY, unitZ)
			local dx = unitScreenX - centerScreenX
			local dy = unitScreenY - centerScreenY
			local screenDistanceSq = dx * dx + dy * dy
			if not closestDistanceSq or screenDistanceSq < closestDistanceSq then
				closestDistanceSq = screenDistanceSq
				closestUnitID = unitID
			end
		end
	end
	return closestUnitID
end

local function getPlainAttackTargets(cmdX, cmdZ, radius)
	local targets = spGetUnitsInCylinder(cmdX, cmdZ, radius, ENEMY_UNITS)
	if not targets or not targets[1] then
		return
	end

	local targetsWithoutNeutralWalls = {}
	for index = 1, #targets do
		local targetID = targets[index]
		---@cast targetID integer
		if not objectifiedUnitDefs[spGetUnitDefID(targetID)] or not spGetUnitNeutral(targetID) then
			targetsWithoutNeutralWalls[#targetsWithoutNeutralWalls + 1] = targetID
		end
	end
	return targetsWithoutNeutralWalls[1] and targetsWithoutNeutralWalls or targets
end

local function getPlainSetTargetTargets(cmdX, cmdZ, radius)
	local targets = spGetUnitsInCylinder(cmdX, cmdZ, radius, ENEMY_UNITS)
	return targets and targets[1] and targets or nil
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
		---@cast featureId integer
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
	if not (options.alt or options.ctrl) then
		local listCommandID
		local targets
		if cmdId == CMD.ATTACK then
			listCommandID = CMD_ATTACK_TARGETS
			targets = getPlainAttackTargets(cmdX, cmdZ, radius)
		elseif cmdId == GameCMD.UNIT_SET_TARGET or cmdId == GameCMD.UNIT_SET_TARGET_NO_GROUND then
			listCommandID = CMD_UNIT_SET_TARGETS
			targets = getPlainSetTargetTargets(cmdX, cmdZ, radius)
		else
			return false
		end
		if not targets then
			-- Preserve ground/empty-area behavior for the original command.
			return false
		end
		sortTargetsByDistance(selectedUnits, targets, true)
		return giveTargetList(listCommandID, selectedUnits, targets, options)
	end

	local mouseX, mouseY = spWorldToScreenCoords(cmdX, cmdY, cmdZ)
	local targetType, targetId = spTraceScreenRay(mouseX, mouseY)
	if targetType ~= UNIT and currentCommand.allowedTargetTypes[UNIT] then
		-- Area-command Y commonly lies on the ground even when the command was
		-- centered on an aircraft. The screen ray can therefore miss that unit;
		-- recover the intended filter type from the unit nearest the area center
		-- in screen space.
		targetId = getUnitNearestAreaCenter(cmdX, cmdY, cmdZ, radius, currentCommand.targetAllegiance)
		if targetId then
			targetType = UNIT
		end
	end

	if not currentCommand.allowedTargetTypes[targetType] then
		return false
	end

	local filteredTargets

	if targetType == UNIT then
		---@cast targetId integer
		filteredTargets = filterUnits(targetId, cmdX, cmdZ, radius, options, currentCommand.targetAllegiance)
	elseif targetType == FEATURE then
		---@cast targetId integer
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
