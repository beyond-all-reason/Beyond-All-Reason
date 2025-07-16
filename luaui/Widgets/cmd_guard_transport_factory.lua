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
local FACTORY_CLEARANCE_DISTANCE = 300 -- Distance considered "far from factory" for pickup readiness

-- =================GLOBAL VARIABLES==============
local factories         = {}
local allUnits          = {}
local myTeam            = Spring.GetLocalTeamID()
local transports        = {}
local watchedTransports = {}
local watchedUnits      = {}
local transport_states = {
	idle = 0,
	approaching = 1,
	picking_up = 2,
	loaded = 3,
	unloaded = 4
}

local cachedUnitDefs = {}

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

local function getFirstMoveCommandDestination(unitID)
    local cmdID, options, tag, targetX, targetY, targetZ = Spring.GetUnitCurrentCommand(unitID, 1)
    if cmdID == nil or cmdID ~= CMD.MOVE then
        return nil
    end
    return { targetX, targetY, targetZ }
end

local function getSecondMoveCommandDestination(unitID)
    local cmdID, options, tag, targetX, targetY, targetZ = Spring.GetUnitCurrentCommand(unitID, 2)
    if cmdID == nil or cmdID ~= CMD.MOVE then
        return nil
    end
    return { targetX, targetY, targetZ }
end

local function Unit()
    return {
        firstOrderCompleted = false,
    }
end

local function Transporter()
    return {
        guardedFactoryID = 0,
        previousEngagement = false,
        state = transport_states.idle
    }
end

local function Factory()
    return {
        guardingTransports = {}
    }
end

local function registerTransport(transportID, factoryID)
    factories[factoryID].guardingTransports[transportID] = true
    transports[transportID].guardedFactoryID = factoryID
end

local function registerUnit(unitID)
    local unitDefID = Spring.GetUnitDefID(unitID)
    local createdUnitDefs = cachedUnitDefs[unitDefID]

    if isTransport(unitID) then
        if transports[unitID] == nil then
            transports[unitID] = Transporter()
        end
    elseif isFactory(unitID) then
        if factories[unitID] == nil then
            factories[unitID] = Factory()
        end
    else
        if allUnits[unitID] == nil then
            allUnits[unitID] = Unit()
        end
    end
end

function widget:Initialize()
	if Spring.GetSpectatingState() or Spring.IsReplay() then
		widgetHandler:RemoveWidget()
		return
	end
	
	for _, unitID in ipairs(Spring.GetTeamUnits(myTeam)) do
		registerUnit(unitID)
	end

	-- If we do it in one pass, we may encounter guarded units that haven't been registered yet.
	for _, unitID in ipairs(Spring.GetTeamUnits(myTeam)) do
		local cmdID, _, _, targetUnitID = Spring.GetUnitCurrentCommand(unitID, 1)
		local isGuarding = cmdID and cmdID == CMD.GUARD

		if isGuarding and isTransport(unitID) and isFactory(targetUnitID) then
			log("Transport " .. unitID .. " IDLE after registering")
			registerUnit(targetUnitID)
			registerUnit(unitID)
			registerTransport(unitID, targetUnitID)
			transports[unitID].state = transport_states.idle
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, teamId, builderID)
	local teamID = Spring.GetUnitTeam(unitID)
	if teamID == myTeam then
		registerUnit(unitID)
	end
end

local function isWaiting(unitID)
	local cmdID = Spring.GetUnitCurrentCommand(unitID, 1)
	return cmdID and cmdID == CMD.WAIT
end

function widget:GameFrame(frame)
    if frame % POLLING_RATE ~= 0 then
        return
    end

    for transportID, target in pairs(watchedTransports) do
        -- Check if transport has loaded unit
        if not allUnits[target] and transports[transportID].state ~= transport_states.unloaded and not transports[transportID].previousEngagement then
            -- unit has been blown up, reset to unloaded
            log("Transport " .. transportID .. " UNLOADED")
            transports[transportID].state = transport_states.unloaded
            Spring.GiveOrderToUnit(transportID, CMD.GUARD, transports[transportID].guardedFactoryID, CMD.OPT_SHIFT)  -- go back to base
        else
        local targetUnit = allUnits[target]

            -- The first move command is generated by the factory to make sure the unit clears it
            -- Once it's done, we can go to the rally point
            if allUnits[target] and allUnits[target].initialCommandTag then
                local cmdID, _, tag = Spring.GetUnitCurrentCommand(target, 1)
                if cmdID and allUnits[target].initialCommandTag ~= tag then
                    allUnits[target].firstOrderCompleted = true
                end
            end

            -- Order the built unit to stop if it's out of the factory
            local transported = Spring.GetUnitIsTransporting(transportID) or {}
            if transports[transportID].state == transport_states.picking_up then
                local factoryLocation  = {Spring.GetUnitPosition(transports[transportID].guardedFactoryID)}
                local unitLocation     = {Spring.GetUnitPosition(target)}
                local isFarFromFactory = distance(factoryLocation, unitLocation) > FACTORY_CLEARANCE_DISTANCE
                local readyForPickup   = isFarFromFactory or targetUnit.firstOrderCompleted

                if readyForPickup and not isWaiting(target) then
                    log("Issuing wait " .. watchedTransports[transportID])
                    Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT, {}, CMD.OPT_ALT)
                end
                -- Check if we picked up the unit already
                for _, id in ipairs(transported) do
                    if watchedTransports[transportID] == id then
                        log("Transport " .. transportID .. " LOADED")
                        transports[transportID].state = transport_states.loaded
                        if isWaiting(target) then
                            Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT, {}, CMD.OPT_ALT)
                        end
                        Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, transports[transportID].destination, CMD.OPT_RIGHT)
                    end
                end
            end

            -- Become available once unloaded
            if transports[transportID].state == transport_states.unloaded then
                transports[transportID].state  = transport_states.idle
                watchedUnits[target]           = nil
                watchedTransports[transportID] = nil
            end

            -- If trans was carrying a unit when told to guard, unload it right on the ground
            if transports[transportID].state == transport_states.loaded and transports[transportID].previousEngagement then
                local x, y, z = Spring.GetUnitPosition(transportID)
                transports[transportID].previousEngagement = false
                Spring.GiveOrderToUnit(transportID, CMD.STOP,        {},                                     CMD.OPT_ALT)
                Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, { x, Spring.GetGroundHeight(x, z), z }, {})
            end

            -- Check if unit has left transport
            local carriedUnits = Spring.GetUnitIsTransporting(transportID)
            if carriedUnits == nil or #carriedUnits == 0 and transports[transportID].state == transport_states.loaded then
                log("Transport " .. transportID .. " UNLOADED")
                transports[transportID].state = transport_states.unloaded
                Spring.GiveOrderToUnit(transportID, CMD.GUARD, transports[transportID].guardedFactoryID,  CMD.OPT_SHIFT)  -- go back to base
            end

            -- The transport wants to pick up the unit. If the unit is waiting, go ahead and pick it up.
            if transports[transportID].state == transport_states.approaching then
                if isWaiting(target) then
                    log("Transport " .. transportID .. " PICKING_UP")
                    transports[transportID].state = transport_states.picking_up
                    Spring.GiveOrderToUnit(transportID, CMD.LOAD_UNITS, target,  CMD.OPT_RIGHT) --Load Unit
                end

                local factoryLocation  = {Spring.GetUnitPosition(transports[transportID].guardedFactoryID)}
                local unitLocation     = {Spring.GetUnitPosition(target)}
                local isFarFromFactory = distance(factoryLocation, unitLocation) > FACTORY_CLEARANCE_DISTANCE
                local readyForPickup   = isFarFromFactory or targetUnit.firstOrderCompleted

                if readyForPickup and not isWaiting(target) then
                    log("Issuing wait " .. watchedTransports[transportID])
                    Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT, {}, CMD.OPT_ALT)
                end
            end
        end
    end
end

local function inactivateUnit(unitID)
 log("Inactivated unit")
    if allUnits[unitID] ~= nil then
        return
    end
    local responsibleTransport = watchedUnits[unitID]
    if responsibleTransport ~= nil then
        transports[responsibleTransport].state = transport_states.unloaded
    end
end

local function inactivateTransport(unitID)
    if transports[unitID] == nil then
        return
    end
    local guardedFactoryID = transports[unitID].guardedFactoryID
    if guardedFactoryID ~= nil and factories[guardedFactoryID] ~= nil then
        factories[guardedFactoryID].guardingTransports[unitID] = nil
    end
    transports[unitID] = nil
    if watchedTransports[unitID] ~= nil then
        local unitWaitingForPickup = watchedTransports[unitID]
        if unitWaitingForPickup ~= nil and isWaiting(unitWaitingForPickup) then
   log("Issuing wait " .. watchedTransports[unitID])
            Spring.GiveOrderToUnit(watchedTransports[unitID], CMD.WAIT, {}, CMD.OPT_ALT)
        end
        watchedUnits[watchedTransports[unitID]] = nil
        watchedTransports[unitID] = nil
    end
end

function canTransport(transportID, unitID)
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

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
    local createdUnitID = unitID
    registerUnit(factID)
    local factory = factories[factID]
    if unitTeam == myTeam then
        if isTransport(createdUnitID) then
            registerUnit(createdUnitID)
            -- Handle case where transport is rallied to another lab
            local cmdID, options, tag, targetUnitID = Spring.GetUnitCurrentCommand(createdUnitID, 1)
            if cmdID == nil or cmdID ~= CMD.GUARD then
                return
            end
            if isFactory(targetUnitID) then
                registerUnit(targetUnitID)
                log("Transport " .. createdUnitID .. " UNLOADED after registering")
                transports[createdUnitID].state  = transport_states.unloaded
                watchedTransports[createdUnitID] = math.huge
                registerTransport(createdUnitID, targetUnitID)
            end
            return
        elseif factory.guardingTransports then
            registerUnit(createdUnitID)
            -- Add initial command tag. Doing it in the constructor doesn't work.
            -- The fab issues an inital move command to every unit to make sure it clears the factory.
            -- We want to pick up the unit once it's done doing that. Otherwise, it'll get picked up
            -- and dropped off, and then proceed to walk back to the factory and then to the rally.
            local cmdID, options, tag = Spring.GetUnitCurrentCommand(createdUnitID, 1)
            if cmdID ~= nil then
                allUnits[createdUnitID].initialCommandTag = tag
            end
            local destination = getSecondMoveCommandDestination(createdUnitID)
            if destination == nil then
                log("Second destination not a move command")
                return
            end
            local bestTransportID   = -1
            local bestTransportTime = math.huge
            
            for transportID in pairs(factory.guardingTransports) do
                if transports[transportID].state == transport_states.idle and canTransport(transportID, createdUnitID) then
                    local destination = getSecondMoveCommandDestination(unitID)

                    if transports[transportID] and destination then
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
            end
            if bestTransportID > -1 then
                log("Transport " .. bestTransportID .. " APPROACHING " .. createdUnitID)
                transports[bestTransportID].state       = transport_states.approaching
                transports[bestTransportID].destination = destination

                local unitWaitDestination               = getFirstMoveCommandDestination(createdUnitID)
                Spring.GiveOrderToUnit(bestTransportID, CMD.MOVE,  unitWaitDestination, CMD.OPT_RIGHT)
                Spring.GiveOrderToUnit(bestTransportID, CMD.GUARD, factID,              CMD.OPT_SHIFT)

                watchedTransports[bestTransportID] = createdUnitID
                watchedUnits[createdUnitID]        = bestTransportID
            end
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
                registerUnit(orderedUnit)
                registerUnit(targetUnitID)
                registerTransport(orderedUnit, targetUnitID)

                -- Unload anything you have when you go guard
                local carriedUnits = Spring.GetUnitIsTransporting(orderedUnit)
                if carriedUnits and #carriedUnits > 0 then
                    log("Transport " .. orderedUnit .. " LOADED after registering")
                    transports[orderedUnit].previousEngagement = true
                    transports[orderedUnit].state              = transport_states.loaded
                    watchedTransports[orderedUnit]             = math.huge
                else
                    log("Transport " .. orderedUnit .. " IDLE after registering with " .. targetUnitID)
                    transports[orderedUnit].state = transport_states.idle
                end
            end
        end
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if transports[unitID] then
        log("Transporter destroyed")
        inactivateTransport(unitID)
    end
    if factories[unitID] then
        factories[unitID] = nil
    end
    if allUnits[unitID] then
        inactivateUnit(unitID)
        allUnits[unitID] = nil
    end
end
