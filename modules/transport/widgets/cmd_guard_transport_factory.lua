local widget = widget ---@type Widget

local Transport = VFS.Include("modules/transport/api.lua") ---@type TransportApi

function widget:GetInfo()
	return {
		name = "Transport Factory Guard",
		desc = "Enables transports to transport units to the first rally waypoint when told to guard a factory",
		author = "Flameink",
		date = "April 24, 2025",
		version = "0.2.4",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local POLLING_RATE = 10
local TRIVIAL_WALK_TIME = 10
local PICKUP_TIME_THRESHOLD = 3
local FACTORY_CLEARANCE_DISTANCE = 50

local transport_states = {
	idle = 0,
	approaching = 1,
	picking_up = 2,
	loaded = 3,
	unloaded = 4,
}
local factoryToGuardingTransports = {}
local transportToFactory = {}
local activeTransportToUnit = {}
local transportState = {}
local unitToDestination = {}
local pendingGuardTransports = {}

local orderedUnitsBlacklist = {}
local blacklistOrderedUnits = false

local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local CMD_REMOVE = CMD.REMOVE

local function getCachedUnitDef(unitID)
	return Transport.UnitTraits(unitID)
end

local function isFactory(unitID)
	local def = getCachedUnitDef(unitID)
	return def and def.isFactory or false
end

local function isTransport(unitID)
	local def = getCachedUnitDef(unitID)
	return def and def.isTransport or false
end

local function distance(point1, point2)
	if not point1 or not point2 then
		return -1
	end

	return math.diag(point1[1] - point2[1], point1[2] - point2[2], point1[3] - point2[3])
end

local function timeToTarget(start, endpoint, speed)
	local dist = distance(start, endpoint)
	return dist / speed
end

local function getValidRallyCommandDestination(unitID)
	local cmdID, options, tag, targetX, targetY, targetZ = Spring.GetUnitCurrentCommand(unitID, 2)
	local cmdValid = cmdID == CMD.MOVE or cmdID < 0
	if cmdID == nil or not cmdValid then
		return nil
	end

	return { targetX, targetY, targetZ }
end

local function isWaiting(unitID)
	local cmdID = Spring.GetUnitCurrentCommand(unitID, 1)
	return cmdID and cmdID == CMD.WAIT
end

local function tryDeactivateWait(unitID)
	if isWaiting(unitID) then
		Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, CMD.OPT_ALT)
	end
end

local function tryActivateWait(unitID)
	if not isWaiting(unitID) then
		Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, CMD.OPT_ALT)
	end
end

local function IsUnitAlive(unitID)
	return Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function registerTransport(transportID, factoryID)
	if not factoryToGuardingTransports[factoryID] then
		factoryToGuardingTransports[factoryID] = {}
	end
	factoryToGuardingTransports[factoryID][transportID] = true
	transportToFactory[transportID] = factoryID
end

local function activateTransportGuard(transportID, factoryID)
	registerTransport(transportID, factoryID)

	local carriedUnits = Spring.GetUnitIsTransporting(transportID)
	if carriedUnits and #carriedUnits > 0 then
		local x, _, z = Spring.GetUnitPosition(transportID)
		transportState[transportID] = transport_states.picking_up
		activeTransportToUnit[transportID] = carriedUnits[1]
		unitToDestination[carriedUnits[1]] = { x, Spring.GetGroundHeight(x, z), z }
	else
		transportState[transportID] = transport_states.idle
	end
end

function widget:Initialize()
	if Spring.GetSpectatingState() or Spring.IsReplay() then
		widgetHandler:RemoveWidget()
		return
	end
	WG.transportFactoryGuard = {}
	WG.transportFactoryGuard.getBlacklistOrderedUnits = function()
		return blacklistOrderedUnits
	end
	WG.transportFactoryGuard.setBlacklistOrderedUnits = function(value)
		blacklistOrderedUnits = value
	end

	for _, unitID in ipairs(Spring.GetTeamUnits(Spring.GetLocalTeamID())) do
		local cmdID, _, _, targetUnitID = Spring.GetUnitCurrentCommand(unitID, 1)
		local isGuarding = cmdID == CMD.GUARD

		if isGuarding and isTransport(unitID) and isFactory(targetUnitID) then
			registerTransport(unitID, targetUnitID)
			transportState[unitID] = transport_states.idle
		end
	end
end

local function isTransportingUnit(transportID, unitID)
	local transported = Spring.GetUnitIsTransporting(transportID) or {}
	for _, id in ipairs(transported) do
		if unitID == id then
			return true
		end
	end
end

local function handleTransport(transportID, target)
	if not IsUnitAlive(target) then
		transportState[transportID] = transport_states.unloaded
		activeTransportToUnit[transportID] = nil
		Spring.GiveOrderToUnit(transportID, CMD.GUARD, transportToFactory[transportID], CMD.OPT_SHIFT)
		return
	else
		if transportState[transportID] == transport_states.picking_up then
			local factoryLocation = { Spring.GetUnitPosition(transportToFactory[transportID]) }
			local unitLocation = { Spring.GetUnitPosition(target) }
			local isFarFromFactory = distance(factoryLocation, unitLocation) > FACTORY_CLEARANCE_DISTANCE

			if isTransportingUnit(transportID, target) then
				transportState[transportID] = transport_states.loaded
				tryDeactivateWait(target)
				Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, unitToDestination[target], CMD.OPT_RIGHT)
				return
			end

			if isFarFromFactory then
				tryActivateWait(target)
			end

			return
		end

		if transportState[transportID] == transport_states.unloaded then
			transportState[transportID] = transport_states.idle
			activeTransportToUnit[transportID] = nil
			return
		end

		local carriedUnits = Spring.GetUnitIsTransporting(transportID)
		if carriedUnits == nil or #carriedUnits == 0 and transportState[transportID] == transport_states.loaded then
			transportState[transportID] = transport_states.unloaded
			Spring.GiveOrderToUnit(transportID, CMD.GUARD, transportToFactory[transportID], CMD.OPT_SHIFT)
			tryDeactivateWait(target)
			return
		end

		if transportState[transportID] == transport_states.approaching then
			if isWaiting(target) then
				transportState[transportID] = transport_states.picking_up
				Spring.GiveOrderToUnit(transportID, CMD.LOAD_UNITS, target, CMD.OPT_RIGHT)
			end

			local factoryLocation = { Spring.GetUnitPosition(transportToFactory[transportID]) }
			local unitLocation = { Spring.GetUnitPosition(target) }
			local isFarFromFactory = distance(factoryLocation, unitLocation) > FACTORY_CLEARANCE_DISTANCE

			if isFarFromFactory then
				tryActivateWait(target)
			end

			return
		end
	end
end

function widget:GameFrame(frame)
	if frame % POLLING_RATE ~= 0 then
		return
	end

	for transportID, target in pairs(activeTransportToUnit) do
		handleTransport(transportID, target)
	end

	for transportID, factoryID in pairs(pendingGuardTransports) do
		if not IsUnitAlive(transportID) or not IsUnitAlive(factoryID) then
			pendingGuardTransports[transportID] = nil
		else
			local cmdID, _, _, cmdTarget = spGetUnitCurrentCommand(transportID, 1)
			if cmdID == CMD.GUARD and isFactory(cmdTarget) then
				pendingGuardTransports[transportID] = nil
				activateTransportGuard(transportID, cmdTarget)
			elseif cmdID == nil then
				pendingGuardTransports[transportID] = nil
			end
		end
	end
end

local function inactivateTransport(unitID)
	local guardedFactory = transportToFactory[unitID]
	if guardedFactory then
		if factoryToGuardingTransports[guardedFactory] then
			factoryToGuardingTransports[guardedFactory][unitID] = nil
		end
	end

	local unitWaitingForPickup = activeTransportToUnit[unitID]
	if unitWaitingForPickup ~= nil then
		tryDeactivateWait(unitWaitingForPickup)
		transportToFactory[unitWaitingForPickup] = nil
		activeTransportToUnit[unitID] = nil
	end
end

local function canTransport(transportID, unitID)
	local udef = Spring.GetUnitDefID(unitID)
	local tdef = Spring.GetUnitDefID(transportID)
	if not udef or not tdef then
		return false
	end

	if not Transport.CanLoad(transportID, unitID) then
		return false
	end

	local _, y = Spring.GetUnitPosition(unitID)
	return y ~= nil
		and Transport.MayLoad({
			goalY = y,
			height = Spring.GetUnitHeight(unitID),
			carrierDef = UnitDefs[tdef],
			passengerDef = UnitDefs[udef],
			distance = 0,
			allied = true,
			passengerSpeed = 0,
		})
end

local function removePreDestinationMoveCommands(unitID, destination)
	local tags = {}
	if not destination then
		return
	end

	for i = 1, spGetUnitCommandCount(unitID), 1 do
		local cmdID, _, tag, targetX, targetY, targetZ = spGetUnitCurrentCommand(unitID, i)
		if cmdID == CMD.MOVE then
			local isSameMoveDestination = targetX == destination[1]
				and targetY == destination[2]
				and targetZ == destination[3]
			if not isSameMoveDestination then
				tags[#tags + 1] = tag
			else
				break
			end
		else
			break
		end
	end

	if tags[1] then
		spGiveOrderToUnit(unitID, CMD_REMOVE, tags)
	end
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	local createdUnitID = unitID
	if Spring.AreTeamsAllied(unitTeam, Spring.GetLocalTeamID()) then
		if isTransport(createdUnitID) then
			local cmdID, _, _, targetUnitID = Spring.GetUnitCurrentCommand(createdUnitID, 1)
			if cmdID == nil or cmdID ~= CMD.GUARD then
				return
			end

			if isFactory(targetUnitID) then
				transportState[createdUnitID] = transport_states.idle
				registerTransport(createdUnitID, targetUnitID)
			end
		elseif factoryToGuardingTransports[factID] and next(factoryToGuardingTransports[factID]) then
			local destination = getValidRallyCommandDestination(createdUnitID)
			if destination == nil then
				return
			end

			if blacklistOrderedUnits and orderedUnitsBlacklist[createdUnitID] then
				return
			end

			local bestTransportID = -1
			local bestTransportTime = math.huge
			local createdTraits = Transport.UnitTraits(createdUnitID)
			local createdSpeed = createdTraits and createdTraits.speed or 0

			for transportID, _ in pairs(factoryToGuardingTransports[factID]) do
				if
					transportState[transportID] == transport_states.idle and canTransport(transportID, createdUnitID)
				then
					local unitLocation = { Spring.GetUnitPosition(unitID) }
					local transportLocation = { Spring.GetUnitPosition(transportID) }

					local tTraits = Transport.UnitTraits(transportID)
					local tSpeed = tTraits and tTraits.speed or 0
					local pickupTime = timeToTarget(transportLocation, unitLocation, tSpeed)
					local transportTime = timeToTarget(unitLocation, destination, tSpeed)
					local walkingTime = timeToTarget(unitLocation, destination, createdSpeed)

					if
						walkingTime > TRIVIAL_WALK_TIME
						and pickupTime < PICKUP_TIME_THRESHOLD
						and pickupTime + transportTime < walkingTime
					then
						if pickupTime + transportTime < bestTransportTime then
							bestTransportID = transportID
							bestTransportTime = pickupTime + transportTime
						end
					end
				end
			end

			if bestTransportID > -1 then
				transportState[bestTransportID] = transport_states.approaching

				local unitWaitDestination = { Spring.GetUnitPosition(createdUnitID) }
				Spring.GiveOrderToUnit(bestTransportID, CMD.MOVE, unitWaitDestination, CMD.OPT_RIGHT)
				Spring.GiveOrderToUnit(bestTransportID, CMD.GUARD, factID, CMD.OPT_SHIFT)

				activeTransportToUnit[bestTransportID] = createdUnitID
				unitToDestination[createdUnitID] = getValidRallyCommandDestination(createdUnitID)
				removePreDestinationMoveCommands(createdUnitID, destination)
			end
		end
	end
end

function widget:UnitCommandNotify(unitID, cmdID, cmdParams, cmdOpts)
	if isTransport(unitID) and not cmdOpts.shift then
		inactivateTransport(unitID)
		pendingGuardTransports[unitID] = nil
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if not cmdOpts or not cmdParams then
		return
	end

	local selectedUnits = Spring.GetSelectedUnits()

	for _, orderedUnit in ipairs(selectedUnits) do
		if isTransport(orderedUnit) then
			if cmdID == CMD.GUARD and isFactory(cmdParams[1]) then
				if cmdOpts.shift then
					pendingGuardTransports[orderedUnit] = cmdParams[1]
				else
					inactivateTransport(orderedUnit)
					pendingGuardTransports[orderedUnit] = nil
					activateTransportGuard(orderedUnit, cmdParams[1])
				end
			else
				if not cmdOpts.shift then
					inactivateTransport(orderedUnit)
					pendingGuardTransports[orderedUnit] = nil
				end
			end
		end
		orderedUnitsBlacklist[orderedUnit] = true
	end
end

local function inactivateFactory(unitID)
	for _, transportID in ipairs(factoryToGuardingTransports[unitID]) do
		inactivateTransport(transportID)
	end

	factoryToGuardingTransports[unitID] = nil
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if transportToFactory[unitID] then
		inactivateTransport(unitID)
	end

	pendingGuardTransports[unitID] = nil

	if factoryToGuardingTransports[unitID] then
		for transportID, factoryID in pairs(pendingGuardTransports) do
			if factoryID == unitID then
				pendingGuardTransports[transportID] = nil
			end
		end
		inactivateFactory(unitID)
	end
	orderedUnitsBlacklist[unitID] = nil
end
