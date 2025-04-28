local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name    = "Transport Factory Guard",
        desc    = "Enables transports to transport units to the first rally waypoint when told to guard a factory",
        author  = "Flameink",
        date    = "April 24, 2025",
        version = "0.2.4",
        license = "GNU GPL, v3 or later",
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

-- =================GLOBAL VARIABLES==============
local factories = {}
local allUnits = {}
local myTeam = Spring.GetLocalTeamID()
local transports = {}
local watchedTransports = {}
local watchedUnits = {}
local frameIndex = 0
local transport_states = {
    idle = 0,
    approaching = 1,
    picking_up = 2,
    loaded = 3,
    unloaded = 4
}

local cachedUnitDefs = {}
function Log(Message, debugLog)
    if debugLog then
        Spring.Echo(Message)
    end
end

for id, def in pairs(UnitDefs) do
    cachedUnitDefs[id]= 
                       {translatedHumanName   = def.translatedHumanName,
                        isTransport           = def.isTransport,
                        isFactory             = def.isFactory,
                        mass                  = def.mass,
                        transportMass         = def.transportMass,
                        speed                 = def.speed,
                        transportCapacity     = def.transportCapacity,
                        cantBeTransported     = def.cantBeTransported,
                        transportSize         = def.transportSize,
                        xsize                 = def.xsize
                    }
end

local function unitName(unitID)
    return cachedUnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName
end

local function IsFab(unitID)
    return cachedUnitDefs[Spring.GetUnitDefID(unitID)].isFactory
end

local function Distance(Point1, Point2)
    local Distance = -1
    if Point1 ~= nil and Point2 ~= nil then
        local ResultX = Point1[1] - Point2[1]
        local ResultY = Point1[2] - Point2[2]
        local ResultZ = Point1[3] - Point2[3]

        local SqaureSum = math.pow(ResultX, 2) + math.pow(ResultY, 2) + math.pow(ResultZ, 2)
        Distance = math.sqrt(SqaureSum)
    end
    return Distance
end

local function timeToTarget(start, endpoint, speed)
    local distance = Distance(start, endpoint)
    return distance / speed
end

local function getFirstMoveCommandDestination(unitID)
    local unitCommands = Spring.GetUnitCommands(unitID, -1)
    if unitCommands == nil then
        Log("Nil commands!\n", debugLog)
        return nil
    end
    if unitCommands[1].id ~= CMD.MOVE then
        Log("First command is not a move!\n", debugLog)
        return nil;
    end
    local destination = unitCommands[1].params
    return destination
end

local function getFirstCommand(unitID)
    local unitCommands = Spring.GetUnitCommands(unitID, -1)
    if unitCommands == nil then
        return nil
    end
    if next(unitCommands) == nil then
        return nil
    end
    return unitCommands[1]
end

local function getSecondMoveCommandDestination(unitID)
    local unitCommands = Spring.GetUnitCommands(unitID, -1)
    if unitCommands == nil then
        Log("Nil commands!\n", debugLog)
        return nil
    end
    if #unitCommands < 2 then
        Log("Unit only has one command!", debugLog)
        return nil
    end
    if unitCommands[2].id ~= CMD.MOVE then
        Log("Second command is not a move!\n", debugLog)
        return nil;
    end
    local cmd = unitCommands[2]
    local dest = { cmd.params[1], cmd.params[2], cmd.params[3] }
    return dest
end

local function getUnitPositionTuple(unitID)
    local x1, y1, z1 = Spring.GetUnitPosition(unitID)
    local unitLocation = { x1, y1, z1 }
    return unitLocation
end

-- =================Unit Class Def==============
Unit =
{
    firstOrderCompleted = false,
}
function Unit:new(unitid)
    local o = {}
    setmetatable(o, { __index = self })
    o.unitID = unitid
    return o
end

-- =================Transporter Class Def==============
Transporter =
{
    guardedFactoryID = 0,
    previousEngagement = false
}

function Transporter:new(unitid)
    o = {}
    setmetatable(o, { __index = self })
    o.state = transport_states.idle
    o.unitID = unitid
    return o
end

-- =================Factory Class Def==============

Factory =
{
    guardingTransports = {},
}

function Factory:new(unitid)
    o = {}
    setmetatable(o, { __index = self })
    o.guardingTransports = {}
    o.unitID = unitid
    return o
end

function Factory:registerTransport(unitID)
    self.guardingTransports[unitID] = true
    transports[unitID].guardedFactoryID = self.unitID
end

local function registerUnit(unitID)
    local unitDefID = Spring.GetUnitDefID(unitID)
    local createdUnitDefs = cachedUnitDefs[unitDefID]

    if createdUnitDefs.isTransport then
        if transports[unitID] == nil then
            transports[unitID] = Transporter:new(unitID)
        end
    elseif IsFab(unitID) == true then
        if factories[unitID] == nil then
            factories[unitID] = Factory:new(unitID)
        end
    else
        if allUnits[unitID] == nil then
            allUnits[unitID] = Unit:new(unitID)
        end
    end
end

function widget:Initialize()
    if Spring.GetSpectatingState() or Spring.IsReplay() then
        widgetHandler:RemoveWidget()
    end
    for _, unitID in ipairs(Spring.GetTeamUnits(myTeam)) do
        registerUnit(unitID)
    end

    for _, unitID in ipairs(Spring.GetTeamUnits(myTeam)) do
        local unitCommands = Spring.GetUnitCommands(unitID, -1)
        local isGuarding = false
        if unitCommands ~= nil and #unitCommands > 0 then
            if unitCommands[1].id == CMD.GUARD then
                isGuarding = true
            end
        end
        local orderedUnitDefs = cachedUnitDefs[Spring.GetUnitDefID(unitID)]

        if isGuarding and orderedUnitDefs.isTransport then
            local targetUnitID = unitCommands[1].params[1]
            registerUnit(targetUnitID)
            registerUnit(unitID)
            Log("Transport " .. unitID .. " IDLE after registering", debugLog)
            factories[targetUnitID]:registerTransport(unitID)
            transports[unitID].state = transport_states.idle
        end
    end
end

function widget:UnitFinished(unitID, unitDefID, teamId, builderID)
    local TeamID = Spring.GetUnitTeam(unitID)
    if TeamID == myTeam then
        registerUnit(unitID)
    end
end

local function isWaiting(unitID)
    local cmds = Spring.GetUnitCommands(unitID, 1)

    if cmds ~= nil and cmds[1] ~= nil and cmds[1].id == CMD.WAIT then
        return true
    end
    return false
end

function widget:GameFrame(frame)
    frameIndex = frameIndex + 1
    if frameIndex % POLLING_RATE ~= 0 then
        return
    end

    for transportID, target in pairs(watchedTransports) do
        -- Check if transport has loaded unit
        if allUnits[target] == nil and transports[transportID].state ~= transport_states.unloaded and transports[transportID].previousEngagement == false then
            -- unit has been blown up, reset to unloaded
            Log("Transport " .. transportID .. " UNLOADED", debugLog)
            transports[transportID].state = transport_states.unloaded
            Spring.GiveOrderToUnit(transportID, CMD.GUARD, transports[transportID].guardedFactoryID, { "shift" })  -- go back to base
        else
            local targetUnit = allUnits[target]

            -- The first move command is generated by the factory to make sure the unit clears it
            -- Once it's done, we can go to the rally point
            if allUnits[target] ~= nil and allUnits[target].initialCommandTag ~= nil then
                local firstCommand = getFirstCommand(target)
                if firstCommand ~= nil and allUnits[target].initialCommandTag ~= firstCommand.tag then
                    allUnits[target].firstOrderCompleted = true
                end
            end        

            -- Order the built unit to stop if it's out of the factory
            local transported = Spring.GetUnitIsTransporting(transportID) or {}
            if transports[transportID].state == transport_states.picking_up then
                local factoryLocation  = getUnitPositionTuple(transports[transportID].guardedFactoryID)
                local unitLocation     = getUnitPositionTuple(target)
                local isFarFromFactory = Distance(factoryLocation, unitLocation) > 300
                local readyForPickup   = isFarFromFactory or targetUnit.firstOrderCompleted

                if readyForPickup then
                    if isWaiting(target) == false then
                        Log("Issuing wait " .. watchedTransports[transportID], debugLog)
                        Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT, {}, { "alt" })
                    end
                end
                -- Check if we picked up the unit already
                for _, id in ipairs(transported) do
                    if watchedTransports[transportID] == id then
                        Log("Transport " .. transportID .. " LOADED", debugLog)
                        transports[transportID].state = transport_states.loaded
                        if isWaiting(target) then
                            Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT, {}, { "alt" })
                        end
                        Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, transports[transportID].destination,
                            CMD.OPT_RIGHT)
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
                Spring.GiveOrderToUnit(transportID, CMD.STOP, {}, { "alt" })
                Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, { x, Spring.GetGroundHeight(x, z), z }, {})
            end

            -- Check if unit has left transport
            local carriedUnits = Spring.GetUnitIsTransporting(transportID)
            if carriedUnits == nil or #carriedUnits == 0 and transports[transportID].state == transport_states.loaded then
                Log("Transport " .. transportID .. " UNLOADED", debugLog)
                transports[transportID].state = transport_states.unloaded
                Spring.GiveOrderToUnit(transportID, CMD.GUARD, transports[transportID].guardedFactoryID, { "shift" })  -- go back to base
            end

            -- The transport wants to pick up the unit. If the unit is waiting, go ahead and pick it up.
            if transports[transportID].state == transport_states.approaching then
                if isWaiting(target) then
                    Log("Transport " .. transportID .. " PICKING_UP", debugLog)
                    transports[transportID].state = transport_states.picking_up
                    Spring.GiveOrderToUnit(transportID, CMD.LOAD_UNITS, target, { "right" }) --Load Unit
                end
                local factoryLocation  = getUnitPositionTuple(transports[transportID].guardedFactoryID)
                local unitLocation     = getUnitPositionTuple(target)
                local isFarFromFactory = Distance(factoryLocation, unitLocation) > 300
                local readyForPickup   = isFarFromFactory or targetUnit.firstOrderCompleted

                if readyForPickup then
                    if isWaiting(target) == false then
                        Log("Issuing wait " .. watchedTransports[transportID], debugLog)
                        Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT, {}, { "alt" })
                    end
                end
            end
        end
    end
end

local function inactivateUnit(unitID)
    Log("Inactivated unit", debugLog)
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
            Log("Issuing wait " .. watchedTransports[unitID], debugLog)
            Spring.GiveOrderToUnit(watchedTransports[unitID], CMD.WAIT, {}, { "alt" })
        end
        watchedUnits[watchedTransports[unitID]] = nil
        table.remove(watchedTransports, unitID)
        watchedTransports[unitID] = nil
    end
end

function CanTransport(transportID, unitID)
    local udef = Spring.GetUnitDefID(unitID)
    local tdef = Spring.GetUnitDefID(transportID)

    local uDefObj = cachedUnitDefs[udef]
    local tDefObj = cachedUnitDefs[tdef]

    if not udef or not tdef then
        return false
    end
    if uDefObj.xsize > tDefObj.transportSize * 2 then
        Log("Size failed", debugLog)
        return false
    end

    local trans = Spring.GetUnitIsTransporting(transportID) -- capacity check
    if tDefObj.transportCapacity <= #trans then
        Log("Count failed. Capacity " .. tDefObj.transportCapacity .. " count:" .. #trans, debugLog)
        return false
    end
    if uDefObj.cantBeTransported then
        Log("Can't be transported", debugLog)
        return false
    end

    local mass = 0 -- mass check
    for _, a in ipairs(trans) do
        mass = mass + cachedUnitDefs[Spring.GetUnitDefID(a)].mass
    end
    mass = mass + uDefObj.mass
    if mass > tDefObj.transportMass then
        Log("Mass: " .. mass .. " vs capacity " .. tDefObj.transportMass .. " for " .. unitName(unitID), debugLog)
        return false
    end
    return true
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
    local createdUnitDefs = cachedUnitDefs[unitDefID]
    local createdUnitID = unitID
    local factory = factories[factID]
    if unitTeam == myTeam then
        -- TODO Make this more efficient
        if createdUnitDefs.isTransport then
            registerUnit(createdUnitID)
            -- Handle case where transport is rallied to another lab
            local unitCommands = Spring.GetUnitCommands(createdUnitID, -1)
            if unitCommands == nil then
                return
            end
            if unitCommands[1].id ~= CMD.GUARD then
                return
            end
            local cmdParams = unitCommands[1].params
            local targetUnitID = cmdParams[1]
            if IsFab(targetUnitID) then
                registerUnit(targetUnitID)
                transports[createdUnitID].state = transport_states.unloaded
                factories[targetUnitID]:registerTransport(createdUnitID)
                Log("Transport " .. createdUnitID .. " UNLOADED after registering", debugLog)
                watchedTransports[createdUnitID] = 9999
            end
            return
        elseif factory.guardingTransports then
            registerUnit(createdUnitID)
            -- Add initial command tag. Doing it in the constructor doesn't work.
            -- The fab issues an inital move command to every unit to make sure it clears the factory.
            -- We want to pick up the unit once it's done doing that. Otherwise, it'll get picked up
            -- and dropped off, and then proceed to walk back to the factory and then to the rally.
            local commands = Spring.GetUnitCommands(createdUnitID, -1)
            if commands ~= nil and next(commands) ~= nil then
                allUnits[createdUnitID].initialCommandTag = commands[1].tag
            end
            local destination = getSecondMoveCommandDestination(createdUnitID)
            if destination == nil then
                Log("Second destination not a move command", debugLog)
                return
            end
            local bestTransportID = -1
            local bestTransportTime = math.huge
            for transportID, _ in pairs(factory.guardingTransports) do
                if transports[transportID].state == transport_states.idle and CanTransport(transportID, createdUnitID) then
                    local Transport = transports[transportID]
                    local unitCommands = Spring.GetUnitCommands(unitID, -1)
                    local destination = getSecondMoveCommandDestination(unitID)
                    if Transport ~= nil and unitCommands ~= nil and unitCommands[1].id == CMD.MOVE and destination ~= nil then
                        local x1, y1, z1        = Spring.GetUnitPosition(unitID)
                        local unitLocation      = { x1, y1, z1 }
                        local x2, y2, z2        = Spring.GetUnitPosition(transportID)
                        local transportLocation = { x2, y2, z2 }
                        
                        local pickupTime        = timeToTarget(transportLocation, unitLocation, cachedUnitDefs[Spring.GetUnitDefID(transportID)].speed)
                        local transportTime     = timeToTarget(unitLocation,      destination,  cachedUnitDefs[Spring.GetUnitDefID(transportID)].speed)
                        local walkingTime       = timeToTarget(unitLocation,      destination,  cachedUnitDefs[Spring.GetUnitDefID(unitID)].speed)
                        -- This also covers the case of builders guarding their factory
                        if walkingTime > 10 and pickupTime < 3 and pickupTime + transportTime < walkingTime then
                            if pickupTime + transportTime < bestTransportTime then
                                bestTransportID   = transportID
                                bestTransportTime = pickupTime + transportTime
                            end
                        end
                    end
                end
            end
            if bestTransportID > -1 then
                Log("Transport " .. bestTransportID .. " APPROACHING " .. createdUnitID, debugLog)
                transports[bestTransportID].state       = transport_states.approaching
                transports[bestTransportID].destination = destination

                local unitWaitDestination               = getFirstMoveCommandDestination(createdUnitID)
                Spring.GiveOrderToUnit(bestTransportID, CMD.MOVE, unitWaitDestination, { "right" }) --Load Unit
                Spring.GiveOrderToUnit(bestTransportID, CMD.GUARD, factID, { "shift" })             --Load Unit

                watchedTransports[bestTransportID] = createdUnitID
                watchedUnits[createdUnitID] = bestTransportID
            end
        end
    end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
    local selectedUnits = Spring.GetSelectedUnits()

    for _, orderedUnit in ipairs(selectedUnits) do
        local orderedUnitDefs = cachedUnitDefs[Spring.GetUnitDefID(orderedUnit)]
        if orderedUnitDefs.isTransport then
            if cmdID == CMD.GUARD and IsFab(cmdParams[1]) then
                inactivateTransport(orderedUnit)
                registerUnit(orderedUnit)
                local targetUnitID = cmdParams[1]
                registerUnit(targetUnitID)
                factories[targetUnitID]:registerTransport(orderedUnit)

                -- Unload anything you have when you go guard
                local carriedUnits = Spring.GetUnitIsTransporting(orderedUnit)
                if carriedUnits and #carriedUnits > 0 then
                    Log("Transport " .. orderedUnit .. " LOADED after registering", debugLog)
                    transports[orderedUnit].previousEngagement = true
                    transports[orderedUnit].state = transport_states.loaded
                    watchedTransports[orderedUnit] = 9999
                else
                    Log("Transport " .. orderedUnit .. " IDLE after registering with " .. targetUnitID, debugLog)
                    transports[orderedUnit].state = transport_states.idle
                end
            else
                inactivateTransport(orderedUnit)
            end
        end
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if transports[unitID] then
        Log("Transporter destroyed", debugLog)
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
