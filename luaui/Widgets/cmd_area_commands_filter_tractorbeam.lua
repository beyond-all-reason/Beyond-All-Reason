local widget = widget ---@type RulesUnsyncedCallins

-- When performing an area command for one of the `allowedCommands` below:
-- - If enemy unit is targeted then targetAllegiance=ENEMY_UNITS otherwise targetAllegiance=targetTeamId
-- - If Ctrl is pressed and hovering over a unit, targets all units in the area. For wrecks, it targets all wrecks with the same tech level
-- - If Alt is pressed and hovering over a unit, targets all units that share the same unitDefId in the area.
-- - If Meta is pressed, orders are put in front of the order queue.
-- - If Meta and Shift are pressed, splits orders between selected units. Orders are placed at the end of the queue
function widget:GetInfo()
	return {
		name = "Area Command Filter, tractor beam rdy",
		desc = "Hold Alt or Ctrl with an area command (Reclaim, Load, Attack, etc.) centered on a unit or feature to filter targets.",
		author = "SuperKitowiec. Based on Specific Unit Reclaimer and Loader by Google Frog",
		date = "October 16, 2025",
		license = "GNU GPL, v2 or later",
		layer = -1, -- Has to be run before Smart Area Reclaim widget
		enabled = true
	}
end


-- Localized functions for performance
local TransportAPI = WG.TransportAPI

if not TransportAPI then
	Spring.Echo("Transport API not found, disabling " .. widget:GetInfo().name)
	return false
end

if not Spring.GetModOptions or Spring.GetModOptions().beta_tractorbeam == false then
	Spring.Echo("Custom transports disabled via modoption, disabling " .. widget:GetInfo().name)
	return false
end

local tableInsert = table.insert
local tableSort = table.sort
local mathFloor = math.floor
local mathMax = math.max

local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
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
local spGetMyTeamID = Spring.GetMyTeamID

local ENEMY_UNITS = Spring.ENEMY_UNITS
local ALLY_UNITS = Spring.ALLY_UNITS
local ALL_UNITS = Spring.ALL_UNITS
local FEATURE = "feature"
local UNIT = "unit"

local commandLimit = 2000

local myAllyTeamID

-- Radius in elmos to search for the unit/feature the user clicked on at the
-- command center.  This replaces the old spWorldToScreenCoords → spTraceScreenRay
-- pipeline which was unreliable at oblique camera angles and under multiplayer
-- frame-interpolation conditions.
local CLICK_SEARCH_RADIUS = 60

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

local function createEmptyValidTransportsTable()
	local tab = {}
	for i = 0, 5 do
		tab[2^(i)] = {}
	end
	return tab
end
--> tab[slotSize1] = { transportID1, transportID2,... }
--> tab[slotSize2] = { transportID2, transportID5,... }
-- this table holds possible transport IDs per slot size)

local queuedSizePerTransport = {} -- transportID -> queuedSize, used to keep track of how many passengers are already assigned to each transport when distributing targets

--- @return table<number,table<number>> Map of transportId -> array of passengerIds
local function distributeTargetsToTransports(transports, targets, shifted)
	local validTransports = createEmptyValidTransportsTable()

	-- 1: exclude already full transports
	-- 2: sort transports into seat sizes categories
	for _, transportUnitId in ipairs(transports) do
		if not TransportAPI.IsTransportFull(transportUnitId) then
			for i = 0, 5 do
				validTransports[2^(i)] = validTransports[2^(i)] or {}
				local slotSize = 2^(i)
				local rulesParamString = "transporterHasSlotOfSize" .. slotSize
				if Spring.GetUnitRulesParam(transportUnitId, rulesParamString) then
					tableInsert(validTransports[slotSize], transportUnitId)
				end
			end
		end
	end
	-- 3. Match passengers to transport types
	local passengersData = {}
	for _, targetId in ipairs(targets) do
		local passengerSize = TransportAPI.GetPassengerSize(targetId)
		local data = {
			id = targetId,
			size = passengerSize,
			matchingTransports = validTransports[passengerSize] or {},
		}
		tableInsert(passengersData, data)
	end
	tableSort(passengersData, function(a, b)
		return a.size > b.size
	end)

	-- 4. Distribute passengers between transports, starting with the biggest ones
	local passengerAssignments = {}
	queuedSizePerTransport = shifted and queuedSizePerTransport or {} -- if shift is held we want to keep the same queued size 
	for i = 1, #passengersData do
		local passengerData = passengersData[i]
		local passengerID = passengerData.id
		local assigned = false
		for index, transportID in ipairs(passengerData.matchingTransports) do
			local queuedSize = queuedSizePerTransport[transportID] or 0
			if TransportAPI.IsTransportFull(transportID, queuedSize) then
				table.remove(passengerData.matchingTransports, index)
			elseif TransportAPI.CanPassengerFitInTransporter(transportID, passengerID, nil, passengerData.size, queuedSize) then
				passengerAssignments[transportID] = passengerAssignments[transportID] or {}
				tableInsert(passengerAssignments[transportID], passengerID)
				queuedSizePerTransport[transportID] = queuedSize + passengerData.size
				assigned = true
				break
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
	local passengerAssignments = distributeTargetsToTransports(transports, filteredTargets, options.shift)
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

	-- Find the unit or feature the user clicked on by searching the world near the
	-- command center instead of round-tripping through screen-space.  The old
	-- spWorldToScreenCoords → spTraceScreenRay approach projected the *ground*
	-- position (cmdY = ground height) to screen, which at non-overhead camera
	-- angles gives a shifted screen position that can hit the wrong unit—especially
	-- in dense fights or under multiplayer frame interpolation.
	local targetType, targetId

	if currentCommand.allowedTargetTypes[UNIT] then
		if currentCommand.targetAllegiance == ENEMY_UNITS and WG.FindNearestEnemyUnit then
			targetId = WG.FindNearestEnemyUnit(cmdX, cmdY, cmdZ, CLICK_SEARCH_RADIUS, spGetMyTeamID())
		else
			local nearbyUnits = spGetUnitsInCylinder(cmdX, cmdZ, CLICK_SEARCH_RADIUS, currentCommand.targetAllegiance)
			if nearbyUnits then
				local bestDistSq = math.huge
				for _, uid in ipairs(nearbyUnits) do
					local ux, _, uz = spGetUnitPosition(uid)
					if ux then
						local dx, dz = ux - cmdX, uz - cmdZ
						local distSq = dx * dx + dz * dz
						if distSq < bestDistSq then
							bestDistSq = distSq
							targetId = uid
						end
					end
				end
			end
		end
		if targetId then
			targetType = UNIT
		end
	end

	if not targetId and currentCommand.allowedTargetTypes[FEATURE] then
		local nearbyFeatures = spGetFeaturesInCylinder(cmdX, cmdZ, CLICK_SEARCH_RADIUS)
		if nearbyFeatures then
			local bestDistSq = math.huge
			for _, fid in ipairs(nearbyFeatures) do
				local fx, _, fz = spGetFeaturePosition(fid)
				if fx then
					local dx, dz = fx - cmdX, fz - cmdZ
					local distSq = dx * dx + dz * dz
					if distSq < bestDistSq then
						bestDistSq = distSq
						targetId = fid
					end
				end
			end
			if targetId then
				targetType = FEATURE
			end
		end
	end

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
