local widget = widget ---@type RulesUnsyncedCallins

function widget:GetInfo()
	return {
		name = "Area Command Filter",
		desc = "Hold Alt or Ctrl with an area command (Reclaim, Load, Attack, etc.) centered on a unit or feature to filter targets.",
		author = "SuperKitowiec. Based on Specific Unit Reclaimer and Loader by Google Frog",
		date = "October 16, 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
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
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spIsReplay = Spring.IsReplay
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local log = Spring.Echo

local myTeamID
local myAllyTeamID
local gameStarted

----------------------------------------------------------------------------------------------------------
--- Logic which distributes targets between transports. Should be split and extracted to separate widget
----------------------------------------------------------------------------------------------------------

-- Multiplier to convert footprints sizes
-- see SPRING_FOOTPRINT_SCALE in GlobalConstants.h in recoil engine repo for details
-- https://github.com/beyond-all-reason/RecoilEngine/blob/master/rts%2FSim%2FMisc%2FGlobalConstants.h
local springFootprintScale = 2

local transportDefs = {}
local cantBeTransported = {}
local unitMass = {}
local unitXSize = {}

for defId, def in pairs(UnitDefs) do
	if def.transportSize and def.transportSize > 0 then
		transportDefs[defId] = { def.transportMass, def.transportCapacity, def.transportSize, def.health }
	end
	unitMass[defId] = def.mass
	unitXSize[defId] = def.xsize
	cantBeTransported[defId] = def.cantBeTransported
end

local function distributeTargetsToTransports(transports, targets)
	---@type table<number,TransportData>
	local transportsDataMap = {}
	local validTransportsForUnitTypeMap = {}
	local passengerPriority = {}

	-- 1. Find transports with capacity
	for _, transportUnitId in ipairs(transports) do
		local transportDefId = spGetUnitDefID(transportUnitId)
		local transportedUnits = spGetUnitIsTransporting(transportUnitId)
		local transCapacity = transportDefs[transportDefId][2]
		local remainingCapacity = transCapacity - (transportedUnits and #transportedUnits or 0)

		if remainingCapacity > 0 then
			if not transportsDataMap[transportDefId] then
				---@class TransportData
				transportsDataMap[transportDefId] = {
					transportCapacity = {},
					transportList = {},
					validPassengers = {},
					transportHealth = transportDefs[transportDefId][4]
				}
			end
			transportsDataMap[transportDefId].transportCapacity[transportUnitId] = remainingCapacity
			table.insert(transportsDataMap[transportDefId].transportList, transportUnitId)
		end
	end

	-- 2. Match passengers to transport types
	for transDefId, transportTypeData in pairs(transportsDataMap) do
		local transportDef = transportDefs[transDefId]
		local transMassLimit = transportDef[1]
		local transportSizeLimit = transportDef[3]

		for _, targetId in ipairs(targets) do
			local passengerDefId = spGetUnitDefID(targetId)
			local isValid = false
			validTransportsForUnitTypeMap[passengerDefId] = validTransportsForUnitTypeMap[passengerDefId] or {}

			if validTransportsForUnitTypeMap[passengerDefId][transDefId] then
				isValid = true
			elseif not cantBeTransported[passengerDefId] then
				local passengerFootprintX = unitXSize[passengerDefId] / springFootprintScale
				if unitMass[passengerDefId] <= transMassLimit and passengerFootprintX <= transportSizeLimit then
					isValid = true
					validTransportsForUnitTypeMap[passengerDefId][transDefId] = true
				end
			end
			if isValid then
				passengerPriority[targetId] = (passengerPriority[targetId] or 0) + 1
				table.insert(transportTypeData.validPassengers, targetId)
			end
		end
		if #transportTypeData.validPassengers == 0 then
			transportsDataMap[transDefId] = nil
		end
	end

	local orderedTransportDefs = {}

	for transDefId, transportData in pairs(transportsDataMap) do
		-- 3. Sort passengers (hardest to transport first)
		table.sort(transportData.validPassengers, function(a, b)
			return passengerPriority[a] < passengerPriority[b]
		end)

		table.insert(orderedTransportDefs, transDefId)
	end

	-- 4. Sort transports
	table.sort(orderedTransportDefs, function(a, b)
		local passengerA = transportsDataMap[a].validPassengers[1]
		local passengerB = transportsDataMap[b].validPassengers[1]

		-- Transports with lowest capabilities are chosen first.
		if passengerPriority[passengerA] ~= passengerPriority[passengerB] then
			return passengerPriority[passengerA] > passengerPriority[passengerB]
		end

		-- In case of tie, we want the sturdier transport first as it will be the first to pick up bigger units
		return transportsDataMap[a].transportHealth > transportsDataMap[b].transportHealth
	end)

	-- 5. Distribute passengers
	local alreadyAssignedPassengers = {}
	local passengerAssignments = {}

	for _, transDefId in ipairs(orderedTransportDefs) do
		local transportsData = transportsDataMap[transDefId]
		local validPassengers = transportsData.validPassengers

		local transportIds = transportsData.transportList
		local transportCapacities = transportsData.transportCapacity

		for _, passengerId in ipairs(validPassengers) do
			if not alreadyAssignedPassengers[passengerId] then
				for _, transportId in ipairs(transportIds) do
					if transportCapacities[transportId] > 0 then
						if not passengerAssignments[transportId] then
							passengerAssignments[transportId] = {}
						end
						table.insert(passengerAssignments[transportId], passengerId)
						alreadyAssignedPassengers[passengerId] = true
						transportCapacities[transportId] = transportCapacities[transportId] - 1
						break
					end
				end
			end
		end
	end

	return passengerAssignments
end

---------------------------------------------------------------------------------------
--- End of transport logic
---------------------------------------------------------------------------------------

local function giveOrders(cmdId, selectedUnits, filteredTargets, options)
	local count = 0
	for _, targetId in ipairs(filteredTargets) do
		local cmdOpts = {}
		if count > 0 or (options.shift and not options.meta) then
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
	for targetId, targets in pairs(unitTargetsMap) do
		giveOrders(cmdId, { targetId }, targets, options)
	end
end

--- All units share the same order queue. Queue can be distributed with shift+meta
local function defaultHandler(cmdId, selectedUnits, filteredTargets, options)
	if options.shift and options.meta then
		splitOrders(cmdId, selectedUnits, filteredTargets, options)
	else
		giveOrders(cmdId, selectedUnits, filteredTargets, options)
	end
end

--- Each transport picks one target
local function loadUnitsHandler(cmdId, selectedUnits, filteredTargets, options)
	local passengerAssignments = distributeTargetsToTransports(selectedUnits, filteredTargets)
	for transportId, targetIds in pairs(passengerAssignments) do
		giveOrders(cmdId, { transportId }, targetIds, options)
	end
end

local TargetType = {
	Feature = "feature",
	Unit = "unit",
}

---@class CommandConfig
---@field handle function
---@field targetType "feature" | "unit"
---@field skipAlliedUnits? boolean

---@type table<number, CommandConfig>
local allowedCommands = {
	[CMD.ATTACK] = { handle = defaultHandler, targetType = TargetType.Unit, skipAlliedUnits = true },
	[CMD.GUARD] = { handle = defaultHandler, targetType = TargetType.Unit },
	[CMD.RECLAIM] = { handle = defaultHandler, targetType = TargetType.Unit },
	[CMD.REPAIR] = { handle = defaultHandler, targetType = TargetType.Unit },
	[CMD.CAPTURE] = { handle = defaultHandler, targetType = TargetType.Unit },
	[GameCMD.UNIT_SET_TARGET] = { handle = defaultHandler, targetType = TargetType.Unit },
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = { handle = defaultHandler, targetType = TargetType.Unit },
	[CMD.RESURRECT] = { handle = defaultHandler, targetType = TargetType.Feature },
	[CMD.LOAD_UNITS] = { handle = loadUnitsHandler, targetType = TargetType.Unit },
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
		unitsInArea = spGetUnitsInCylinder(cmdX, cmdZ, radius, myTeamID)
	end
	if not unitsInArea then
		return nil
	end

	for i = 1, #unitsInArea do
		local unitID = unitsInArea[i]
		if options.ctrl or (options.alt and spGetUnitDefID(unitID) == unitDefId) then
			table.insert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function filterFeatures(targetId, cmdX, cmdZ, radius, options)
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
		if options.alt and spGetFeatureDefID(featureId) == featureDefId then
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

	if targetType ~= currentCommand.targetType then
		return false
	end

	local filteredTargets

	if currentCommand.targetType == TargetType.Unit then
		filteredTargets = filterUnits(targetId, cmdX, cmdZ, radius, options, currentCommand.skipAlliedUnits)
	elseif currentCommand.targetType == TargetType.Feature then
		filteredTargets = filterFeatures(targetId, cmdX, cmdZ, radius, options)
	end

	if not filteredTargets or #filteredTargets == 0 then
		return false
	end

	currentCommand.handle(cmdId, selectedUnits, filteredTargets, options)
	return true
end

local function maybeRemoveSelf()
	if spGetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()
end

function widget:Initialize()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()

	if spIsReplay() or spGetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end
