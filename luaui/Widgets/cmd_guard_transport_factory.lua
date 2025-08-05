local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Transport Factory Guard",
		desc    = "Enables transports to transport units to the first rally waypoint when told to guard a factory",
		author  = "Flameink",
		date    = "April 24, 2025",
		version = "0.2.4",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true   --  loaded by default?
	}
end

-- Specification
-- When a transport is told to guard a factory the behavior should be:
--      When a unit is produced at the factory, the transport picks it up and delivers it to the first move waypoint set.
--      If the first waypoint set from the factory is not a move, do nothing.
--      If there are several queued commands from the factory, deliver only to the destination of the first move command
--      If the transport is holding a unit when it is told to guard the factory, it unloads it on the ground where it is before going to guard.
--      If the user issues any order to the transport, the guard operation aborts and the transport won't pick up more units from the factory
--      Units already en route to the rally point when the transport is told to guard will be ignored. The transport will 
--      only pick up newly produced units.
--      If the unit is killed before pickup, the transport will go back to guarding the factory.

-- For transports that can hold multiple units(this isn't implemented yet since there is no multi-unit transports in the game yet):
--     The guarding transport picks up a produced unit. If it's full, it goes to its destination.
--     If a transport picks up a unit and is partially filled, it will wait for more arrivals from the factory.
--     If a partially filled transport sees a unit produced from the factory that it cannot load, it leaves immediately.

-- Technical notes
-- Each transport operates as a state machine. There is a loop in GameFrame that polls each transport for changes in state. The polling rate
-- is adjustable, and transports not actively ferrying a unit don't get polled. 
-- The game generates a move command to just in front of the factory when the unit gets created. Once that command is done, the unit is told to wait.
-- If you don't wait until that command is done and pick up right away, then the unit will run back to the factory after getting dropped off
-- and then run to its second waypoint.

-- Toggle this for debug printing
local debugLog = false

-- Polls every 10 frames. Set to a different number to poll more/less often.
local POLLING_RATE = 10
local TRIVIAL_WALK_TIME = 10    -- If the unit is going somewhere close, don't bother. This also covers the case of builders assisting the factory that built them.
local PICKUP_TIME_THRESHOLD = 3 -- If the transport is far away from the unit to pick up, don't bother.
local FACTORY_CLEARANCE_DISTANCE = 50 -- Distance considered "far from factory" for pickup readiness

-- =================GLOBAL VARIABLES==============
local myTeam            = Spring.GetLocalTeamID()
local transport_states = {
	idle = 0,
	approaching = 1,
	picking_up = 2,
	loaded = 3,
	unloaded = 4
}
local factoryToGuardingTransports = {}
local transportToFactory = {}
local activeTransportToUnit = {}
local transportState = {}
local unitToDestination = {}

local cachedUnitDefs = {}
local debugLog = true
local function log(message)
	if debugLog then
		Spring.Echo(message)
	end
end

for id, def in pairs(UnitDefs) do
	cachedUnitDefs[id] = {
		translatedHumanName = def.translatedHumanName,
		isTransport         = def.isTransport,
		isFactory           = def.isFactory,
		mass                = def.mass,
		transportMass       = def.transportMass,
		speed               = def.speed,
		transportCapacity   = def.transportCapacity,
		cantBeTransported   = def.cantBeTransported,
		transportSize       = def.transportSize,
		xsize               = def.xsize
	}
end

local function unitName(unitID)
	return cachedUnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName
end

local function isFactory(unitID)
	return cachedUnitDefs[Spring.GetUnitDefID(unitID)].isFactory
end

local function isTransport(unitID)
	return cachedUnitDefs[Spring.GetUnitDefID(unitID)].isTransport
end

local function distance(point1, point2)
	if not point1 or not point2 then
		return -1
	end
	
	return math.diag(point1[1] - point2[1],
	                 point1[2] - point2[2],
	                 point1[3] - point2[3])
end

local function timeToTarget(start, endpoint, speed)
	local dist = distance(start, endpoint)
	return dist / speed
end

local function getSecondMoveCommandDestination(unitID)
    local cmdID, options, tag, targetX, targetY, targetZ = Spring.GetUnitCurrentCommand(unitID, 2)
    if cmdID == nil or cmdID ~= CMD.MOVE then
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
        log("Issuing wait " .. unitID)
        Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, CMD.OPT_ALT)
    end
end

local function tryActivateWait(unitID)
    if not isWaiting(unitID) then
        log("Issuing wait " .. unitID)
        Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, CMD.OPT_ALT)
    end
end

local function IsUnitAlive(unitID)
    return Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function registerTransport(transportID, factoryID)
    if not factoryToGuardingTransports[factoryID] then factoryToGuardingTransports[factoryID] = {} end
    factoryToGuardingTransports[factoryID][transportID] = true
    transportToFactory[transportID] = factoryID
end

function widget:Initialize()
	if Spring.GetSpectatingState() or Spring.IsReplay() then
		widgetHandler:RemoveWidget()
		return
	end
	
	for _, unitID in ipairs(Spring.GetTeamUnits(myTeam)) do
		local cmdID, _, _, targetUnitID = Spring.GetUnitCurrentCommand(unitID, 1)
		local isGuarding = cmdID and cmdID == CMD.GUARD

		if isGuarding and isTransport(unitID) and isFactory(targetUnitID) then
			log("Transport " .. unitID .. " IDLE after registering")
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

function widget:GameFrame(frame)
    if frame % POLLING_RATE ~= 0 then
        return
    end

    for transportID, target in pairs(activeTransportToUnit) do
        -- Check if transport has loaded unit
        if not IsUnitAlive(target) and transportState[transportID] ~= transport_states.unloaded and not isTransportingUnit(transportID, target) then
            -- unit has been blown up, reset to unloaded
            log("Transport " .. transportID .. " UNLOADED")
            transportState[transportID] = transport_states.unloaded
            activeTransportToUnit[transportID] = nil
            Spring.GiveOrderToUnit(transportID, CMD.GUARD, transportToFactory[transportID], CMD.OPT_SHIFT)  -- go back to base
        else
            -- Order the built unit to stop if it's out of the factory
            if transportState[transportID] == transport_states.picking_up then
                local factoryLocation  = {Spring.GetUnitPosition(transportToFactory[transportID])}
                local unitLocation     = {Spring.GetUnitPosition(target)}
                local isFarFromFactory = distance(factoryLocation, unitLocation) > FACTORY_CLEARANCE_DISTANCE

                if isFarFromFactory then
                    tryActivateWait(target)
                end

                -- Check if we picked up the unit already
                if isTransportingUnit(transportID, target) then                    
                    transportState[transportID] = transport_states.loaded
                    tryDeactivateWait(target)
                    log("Transport " .. transportID .. " LOADED")
                    Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, unitToDestination[target], CMD.OPT_RIGHT)
                end
            end

            -- Become available once unloaded
            if transportState[transportID] == transport_states.unloaded then
                transportState[transportID]  = transport_states.idle
                activeTransportToUnit[transportID] = nil
            end

            -- Check if unit has left transport
            local carriedUnits = Spring.GetUnitIsTransporting(transportID)
            if carriedUnits == nil or #carriedUnits == 0 and transportState[transportID] == transport_states.loaded then
                log("Transport " .. transportID .. " UNLOADED")
                transportState[transportID] = transport_states.unloaded
                Spring.GiveOrderToUnit(transportID, CMD.GUARD, transportToFactory[transportID],  CMD.OPT_SHIFT)  -- go back to base
                tryDeactivateWait(target)
            end

            -- The transport wants to pick up the unit. If the unit is waiting, go ahead and pick it up.
            if transportState[transportID] == transport_states.approaching then
                if isWaiting(target) then
                    log("Transport " .. transportID .. " PICKING_UP")
                    transportState[transportID] = transport_states.picking_up
                    Spring.GiveOrderToUnit(transportID, CMD.LOAD_UNITS, target,  CMD.OPT_RIGHT) --Load Unit
                end

                local factoryLocation  = {Spring.GetUnitPosition(transportToFactory[transportID])}
                local unitLocation     = {Spring.GetUnitPosition(target)}
                local isFarFromFactory = distance(factoryLocation, unitLocation) > FACTORY_CLEARANCE_DISTANCE

                if isFarFromFactory then
                    tryActivateWait(target)
                end
            end
        end
    end
end

local function inactivateTransport(unitID)
    local guardedFactory = transportToFactory[unitID]
    if guardedFactory then
        factoryToGuardingTransports[guardedFactory][unitID] = nil
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

	local uDefObj = cachedUnitDefs[udef]
	local tDefObj = cachedUnitDefs[tdef]

	if not udef or not tdef then
		return false
	end
	
	if uDefObj.xsize > tDefObj.transportSize * Game.footprintScale then
		log("Size failed")
		return false
	end

	local trans = Spring.GetUnitIsTransporting(transportID) -- capacity check
	if tDefObj.transportCapacity <= #trans then
		log("Count failed. Capacity " .. tDefObj.transportCapacity .. " count:" .. #trans)
		return false
	end
	
	if uDefObj.cantBeTransported then
		log("Can't be transported")
		return false
	end

	local mass = 0 -- mass check
	for _, a in ipairs(trans) do
		mass = mass + cachedUnitDefs[Spring.GetUnitDefID(a)].mass
	end
	mass = mass + uDefObj.mass
	
	if mass > tDefObj.transportMass then
		log("Mass: " .. mass .. " vs capacity " .. tDefObj.transportMass .. " for " .. unitName(unitID))
		return false
	end
	
	return true
end

local function RemoveFirstCommand(unitID)
    local cmdQueue = Spring.GetUnitCommands(unitID, 1)
    if #cmdQueue > 0 then
        Spring.GiveOrderToUnit(unitID, cmdQueue[1].id, cmdQueue[1].params, {"shift"})
    end
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
    local createdUnitID = unitID
    if unitTeam == myTeam then
        if isTransport(createdUnitID) then
            -- Handle case where transport is rallied to another lab
            local cmdID, options, tag, targetUnitID = Spring.GetUnitCurrentCommand(createdUnitID, 1)
            if cmdID == nil or cmdID ~= CMD.GUARD then
                return
            end

            if isFactory(targetUnitID) then
                log("Transport " .. createdUnitID .. " UNLOADED after registering")
                transportState[createdUnitID]  = transport_states.unloaded
                activeTransportToUnit[createdUnitID] = math.huge
                registerTransport(createdUnitID, targetUnitID)
            end

            return
        elseif factoryToGuardingTransports[factID] and next(factoryToGuardingTransports[factID]) then
            local destination = getSecondMoveCommandDestination(createdUnitID)
            if destination == nil then
                log("Second destination not a move command")
                return
            end

            local bestTransportID   = -1
            local bestTransportTime = math.huge
            
            for transportID, _ in pairs(factoryToGuardingTransports[factID]) do
                if transportState[transportID] == transport_states.idle and canTransport(transportID, createdUnitID) then
                    local unitLocation      = {Spring.GetUnitPosition(unitID)}
                    local transportLocation = {Spring.GetUnitPosition(transportID)}
                    
                    local pickupTime        = timeToTarget(transportLocation, unitLocation, cachedUnitDefs[Spring.GetUnitDefID(transportID)].speed)
                    local transportTime     = timeToTarget(unitLocation,      destination,  cachedUnitDefs[Spring.GetUnitDefID(transportID)].speed)
                    local walkingTime       = timeToTarget(unitLocation,      destination,  cachedUnitDefs[Spring.GetUnitDefID(unitID)].speed)
                
                    -- This also covers the case of builders guarding their factory
                    if walkingTime > TRIVIAL_WALK_TIME and pickupTime < PICKUP_TIME_THRESHOLD and pickupTime + transportTime < walkingTime then
                        if pickupTime + transportTime < bestTransportTime then
                            bestTransportID   = transportID
                            bestTransportTime = pickupTime + transportTime
                        end
                    end
                end
            end

            if bestTransportID > -1 then
                log("Transport " .. bestTransportID .. " APPROACHING " .. createdUnitID)
                transportState[bestTransportID]       = transport_states.approaching

                local unitWaitDestination               = {Spring.GetUnitPosition(createdUnitID)}
                -- local unitWaitDestination               = getFirstMoveCommandDestination(createdUnitID)
                Spring.GiveOrderToUnit(bestTransportID, CMD.MOVE,  unitWaitDestination, CMD.OPT_RIGHT)
                Spring.GiveOrderToUnit(bestTransportID, CMD.GUARD, factID,              CMD.OPT_SHIFT)

                activeTransportToUnit[bestTransportID] = createdUnitID
                unitToDestination[createdUnitID] = getSecondMoveCommandDestination(createdUnitID)
            end

            -- The fab issues an inital move command to every unit to make sure it clears the factory.
            -- We want get rid of that command before picking up. Otherwise, it'll get picked up
            -- and dropped off, and then proceed to walk back to the factory and then to the rally.
            RemoveFirstCommand(createdUnitID)
        end
    end
end

function widget:UnitCommandNotify(unitID, cmdID, cmdParams, cmdOpts)
    -- Callin from formations widget. If we're ordering in formation, it's definitely not a guard order.
    if isTransport(unitID) then
        inactivateTransport(unitID)
    end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
    local selectedUnits = Spring.GetSelectedUnits()

    for _, orderedUnit in ipairs(selectedUnits) do
        if isTransport(orderedUnit) then
            inactivateTransport(orderedUnit)
            if cmdID == CMD.GUARD and isFactory(cmdParams[1]) then
                local targetUnitID = cmdParams[1]
                registerTransport(orderedUnit, targetUnitID)

                -- Unload anything you have when you go guard
                -- We board the state machine as a trans picking up a passenger bound for current location
                -- This is because of timing issues with CommandNotify/UnitCommand
                local carriedUnits = Spring.GetUnitIsTransporting(orderedUnit)
                if carriedUnits and #carriedUnits > 0 then
                    log("Transport " .. orderedUnit .. " PICKING_UP after registering")
                    local x, y, z = Spring.GetUnitPosition(orderedUnit)

                    transportState[orderedUnit]        = transport_states.picking_up
                    activeTransportToUnit[orderedUnit] = carriedUnits[1]
                    unitToDestination[carriedUnits[1]] = {x, Spring.GetGroundHeight(x, z), z}
                else
                    log("Transport " .. orderedUnit .. " IDLE after registering with " .. targetUnitID)
                    transportState[orderedUnit] = transport_states.idle
                end
            end
        end
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

    if factoryToGuardingTransports[unitID] then
        inactivateFactory(unitID)
    end
end
