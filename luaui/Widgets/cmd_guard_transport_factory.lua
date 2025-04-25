local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "Transport Factory Guard",
        desc      = "Enables transports to transport units to the first rally waypoint when told to guard a factory",
        author    = "Flameink",
        date      = "April 24, 2025",
        version   = "0.2.4",
        license   = "GNU GPL, v3 or later",
        layer     = 0,
        enabled   = true  --  loaded by default?
    }
end

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

function Log(Message, debugLog)
    if debugLog then
        Spring.Echo(Message)
    end
end

local transport_states = {
	idle=0,
	approaching=1,
	picking_up=2,
	loaded=3, 
	arrived=4,
	move_to_retreatpoint=5,
	unloaded=6
}

function unitName(unitID)
	local unitDefID=Spring.GetUnitDefID(unitID)
    local createdUnitDefs = UnitDefs[unitDefID]
    return createdUnitDefs.translatedHumanName
end

function IsFab(unitID)
	local Index=Spring.GetUnitDefID(unitID)
	local IsFactory=false
	
	if Index~=nil then
		local UnitDEFS=UnitDefs[Index]
		IsFactory=UnitDEFS.isFactory
	end
	return IsFactory
end

function IsTransport(unitID)
    local Index=Spring.GetUnitDefID(unitID)
    if Index~=nil then
        return UnitDefs[Index].isTransport
    else
        return false
    end
end

function Distance(Point1,Point2)
	local Distance=-1
	if Point1~=nil and Point2~=nil then
        local ResultX=Point1[1]-Point2[1]
        local ResultY=Point1[2]-Point2[2]
        local ResultZ=Point1[3]-Point2[3]

        local SqaureSum=math.pow(ResultX,2)+math.pow(ResultY,2)+math.pow(ResultZ,2)
        Distance=math.sqrt (SqaureSum)
	end
	return Distance
end

function timeToTarget(start, endpoint, speed)
    local distance = Distance(start, endpoint)
    return distance/speed
end

function getFirstMoveCommandDestination(unitID)
	local unitCommands = Spring.GetUnitCommands(unitID,-1)
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


function getFirstGuardCommand(unitID)
	local unitCommands = Spring.GetUnitCommands(unitID,-1)
    if unitCommands == nil then
        Log("Nil commands!\n", debugLog)
        return nil
    end
    if unitCommands[1].id ~= CMD.GUARD then
        Log("First command is not a move!\n", debugLog)
        return nil;
    end
    return unitCommands[1]
end


function getSecondMoveCommandDestination(unitID)
	local unitCommands = Spring.GetUnitCommands(unitID,-1)
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
    local cmd =unitCommands[2]
    local dest = {cmd.params[1], cmd.params[2], cmd.params[3]}
    return dest
end

function getUnitPositionTuple(unitID)
    local x1, y1, z1 = Spring.GetUnitPosition(unitID)
    local unitLocation = {x1, y1, z1}
    return unitLocation
end

function worthTransporting(unitID, transportID)
	local Unit = allUnits[unitID]
	local Transport = transports[transportID]
    if Transport == nil then
        Log("Nil transport!\n", debugLog)
        return false
    end
	local unitCommands = Spring.GetUnitCommands(unitID,-1)
    if unitCommands == nil then
        Log("Nil commands!\n", debugLog)
        return false
    end
    if unitCommands[1].id ~= CMD.MOVE then
        Log("First command is not a move!\n", debugLog)
        return false
    end
	local destination = getSecondMoveCommandDestination(unitID)
    if destination == nil then
        Log("First command is nonmove", debugLog)
        return false
    end
    local x1, y1, z1 = Spring.GetUnitPosition(unitID)
    local unitLocation = {x1, y1, z1}

    local x2, y2, z2 = Spring.GetUnitPosition(transportID)
    local transportLocation = {x2, y2, z2}
	local pickupTime = timeToTarget(transportLocation, unitLocation, Transport.UnitDEFS.speed)
    local transportTime = timeToTarget(unitLocation, destination, Transport.UnitDEFS.speed)
    local walkingTime = timeToTarget(unitLocation, destination, Unit.UnitDEFS.speed)
    -- This also covers the case of builders guarding their factory
    if walkingTime < 10 then
        Log("Trivial distance " .. unitName(unitID), debugLog)
        return false
    end
    if pickupTime + transportTime < walkingTime then
        return true
    else
        Log("Transport time: " .. pickupTime + transportTime .. " Walk time: " .. timeToTarget(unitLocation, destination, Unit.UnitDEFS.speed) .. "unit: " .. unitName(unitID), debugLog)
    end

    return false

end

-- =================Unit Class Def==============
Unit=
{
    firstOrderCompleted=false,
    waiting=false,
    hasInsertedCmd=false
}
function Unit:new(unitid)
	o = {}
	setmetatable(o, {__index=self})
    o.UnitDEFS=UnitDefs[Spring.GetUnitDefID(unitid)]
	o.Mass=o.UnitDEFS.mass
    o.unitID = unitid
	return o
end
-- =================Transporter Class Def==============
Transporter=
{
	guardedFactoryID=0,
    previousEngagement=false
}

function Transporter:new(unitid)

	o = {}
	setmetatable(o, {__index=self})
    o.UnitDEFS=UnitDefs[Spring.GetUnitDefID(unitid)]
    o.state = transport_states.idle
    o.unitID = unitid
	return o
end

-- =================Factory Class Def==============

Factory=
{
	guardingTransports = {},
}

function Factory:new(unitid)

	o = {}
	setmetatable(o, {__index=self})
    o.guardingTransports = {}
    o.unitID = unitid
    return o
end

function Factory:registerTransport(unitID)
    table.insert(self.guardingTransports, unitID)
    transports[unitID].guardedFactoryID = self.unitID
end

function registerUnit(unitID)
    local unitDefID = Spring.GetUnitDefID(unitID)
    local createdUnitDefs = UnitDefs[unitDefID]

    if createdUnitDefs.isTransport then
        if transports[unitID] == nil then
            Log("Transporter finished " .. unitID, debugLog)
            transports[unitID] = Transporter:new(unitID)
        end
    elseif IsFab(unitID) == true then
        Log("Factory finished " .. unitID, debugLog)
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
        local unitCommands = Spring.GetUnitCommands(unitID,-1)
        local isGuarding = false
        if unitCommands ~= nil and #unitCommands > 0 then
            if unitCommands[1].id == CMD.GUARD then
                isGuarding = true
            end
        end
        local unitDefID = Spring.GetUnitDefID(unitID)
        local orderedUnitDefs = UnitDefs[unitDefID]
        
        if  isGuarding and orderedUnitDefs.isTransport then
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
	local TeamID= Spring.GetUnitTeam(unitID)
	if TeamID == myTeam then
        registerUnit(unitID)
	end
end

  
function isWaiting(unitID)
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
            Spring.GiveOrderToUnit(transportID, CMD.GUARD ,transports[transportID].guardedFactoryID, { "shift" } )-- go back to base
        else
            targetUnit = allUnits[target]

            -- Order the built unit to stop if it's out of the factory
            local transported = Spring.GetUnitIsTransporting(transportID) or {}
            if transports[transportID].state == transport_states.picking_up then    
                local factoryLocation = getUnitPositionTuple(transports[transportID].guardedFactoryID)
                local unitLocation = getUnitPositionTuple(target)
                local isFarFromFactory = Distance(factoryLocation, unitLocation) > 300

                local readyForPickup = isFarFromFactory or targetUnit.firstOrderCompleted

                if readyForPickup then
                    if isWaiting(target) == false then
                            Log("Issuing wait " .. watchedTransports[transportID], debugLog)
                            Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT , {}, { "alt" } )
                    end
                end
                -- Check if we picked up the unit already
                for _, id in ipairs(transported) do
                    if watchedTransports[transportID] == id then
                        Log("Transport " .. transportID .. " LOADED", debugLog)
                        transports[transportID].state = transport_states.loaded
                        if isWaiting(target) then
                            Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT , {}, { "alt" } )
                        end
                        local unitID = watchedTransports[transportID]
                        if allUnits[unitID].hasInsertedCmd then
                            Spring.GiveOrderToUnit(unitID, CMD.REMOVE, 1, CMD.OPT_ALT) 
                            allUnits[unitID].hasInsertedCmd = false
                        end                        
                        Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT , transports[transportID].destination, CMD.OPT_RIGHT )
                    end
                end
            end
    
            -- Check if transport has returned to the factory
            if transports[transportID].state == transport_states.unloaded then 
                boundFactoryLocation = getUnitPositionTuple(transports[transportID].guardedFactoryID)
                boundFactoryDistance = Distance(getUnitPositionTuple(transportID), boundFactoryLocation)
                if boundFactoryDistance < 400 and transports[transportID].state == transport_states.unloaded then
                    Log("Transport " .. transportID .. " IDLE with distance " .. boundFactoryDistance, debugLog)
                    transports[transportID].state = transport_states.idle 
                    watchedUnits[target] = nil
                    watchedTransports[transportID] = nil
                end            
            end
    
            -- If trans was carrying a unit when told to guard, unload it right on the ground
            if transports[transportID].state == transport_states.loaded and transports[transportID].previousEngagement then
                local x, y, z = Spring.GetUnitPosition(transportID)
                transports[transportID].previousEngagement = false
                Spring.GiveOrderToUnit(transportID, CMD.STOP, {}, {"alt"})
                Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, {x, Spring.GetGroundHeight(x, z), z}, { })
            end
    
            -- Check if unit has left transport
            local carriedUnits = Spring.GetUnitIsTransporting(transportID)
            if carriedUnits == nil or #carriedUnits == 0 and transports[transportID].state == transport_states.loaded then
                Log(carriedUnits, debugLog)
                Log("Transport " .. transportID .. " UNLOADED", debugLog)
                transports[transportID].state = transport_states.unloaded
                factoryLocation = getUnitPositionTuple(transports[transportID].guardedFactoryID)
                Spring.GiveOrderToUnit(transportID, CMD.GUARD ,transports[transportID].guardedFactoryID, { "shift" } )-- go back to base
            end

            if transports[transportID].state == transport_states.approaching then 
                local vx, vy, vz = Spring.GetUnitVelocity(target)
                local speed = math.sqrt(vx^2 + vy^2 + vz^2)
                if isWaiting(target) then
                    -- if isWaiting(target) and speed <= 0.1 then
                    Log("Transport " .. transportID .. " PICKING_UP", debugLog)
                    transports[transportID].state = transport_states.picking_up
                    Spring.GiveOrderToUnit(transportID, CMD.LOAD_UNITS ,target,{ "right" } )--Load Unit
                end
                local factoryLocation = getUnitPositionTuple(transports[transportID].guardedFactoryID)
                local unitLocation = getUnitPositionTuple(target)
                local isFarFromFactory = Distance(factoryLocation, unitLocation) > 300

                local readyForPickup = isFarFromFactory or targetUnit.firstOrderCompleted

                if readyForPickup then
                    if isWaiting(target) == false then
                        Log("Issuing wait " .. watchedTransports[transportID], debugLog)
                        Spring.GiveOrderToUnit(watchedTransports[transportID], CMD.WAIT , {}, { "alt" } )
                    end
                end
            end
        end
    end
end

function commandName(id)
    local cmdName = "other"
    if id==CMD.GUARD then
        cmdName = "GUARD"
    end
    if id==CMD.MOVE then
        cmdName = "MOVE"
    end
    if id==CMD.WAIT then
        cmdName = "WAIT"
    end
    if id==CMD.UNLOAD_UNIT then
        cmdName = "UNLOAD_UNIT"
    end
    if id==CMD.LOAD_UNITS then
        cmdName = "LOAD_UNITS"
    end
    return cmdName
end

function inactivateUnit(unitID)
    Log("Inactivated unit", debugLog)
    if allUnits[unitID] ~= nil then
        return
    end
    local responsibleTransport = watchedUnits[unitID]
    if responsibleTransport ~= nil then
        transports[responsibleTransport].state = transport_states.unloaded
    end
end

function inactivateTransport(unitID)
    if transports[unitID] == nil then
        return
    end
    local transport = transports[unitID]
    local guardedFactoryID = transport.guardedFactoryID
    if guardedFactoryID ~= nil  and factories[guardedFactoryID] ~= nil then
        -- Awful awful awful
        for i, v in ipairs(factories[guardedFactoryID].guardingTransports) do
            if v == unitID then
                table.remove(factories[guardedFactoryID].guardingTransports, i)
                break
            end
        end

    end
    transports[unitID] = nil
    if watchedTransports[unitID] ~= nil then
        local unitWaitingForPickup = watchedTransports[unitID]
        if unitWaitingForPickup ~= nil and isWaiting(unitWaitingForPickup) then
            Log("Issuing wait " .. watchedTransports[unitID], debugLog)
            Spring.GiveOrderToUnit(watchedTransports[unitID], CMD.WAIT , {}, { "alt" } )
        end
        watchedUnits[watchedTransports[unitID]] = nil
        table.remove(watchedTransports, unitID)
        watchedTransports[unitID] = nil
    end   
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, options, cmdTag)
    if allUnits[unitID] ~= nil and allUnits[unitID].initialCommandTag ~= nil then
        if cmdID == CMD.MOVE and allUnits[unitID].initialCommandTag == cmdTag then
            allUnits[unitID].firstOrderCompleted = true
        end
    end
end

function CanTransport(transportID, unitID)
	local udef = Spring.GetUnitDefID(unitID)
	local tdef = Spring.GetUnitDefID(transportID)

    local uDefObj = UnitDefs[udef]
    local tDefObj = UnitDefs[tdef]

	if not udef or not tdef then
		return false
	end
	if uDefObj.xsize > tDefObj.transportSize * 2 then
        Log("Size failed", debugLog)
		return false
	end

	local trans = Spring.GetUnitIsTransporting(transportID) -- capacity check
	if tDefObj.transportCapacity <= #trans then
        Log("Count failed. Capacity ".. tDefObj.transportCapacity .. " count:" .. #trans, debugLog)
		return false
	end
    if uDefObj.cantBeTransported then
        Log("Can't be transported", debugLog)
        return false
    end

	local mass = 0 -- mass check
	for _, a in ipairs(trans) do
		mass = mass + UnitDefs[Spring.GetUnitDefID(a)].mass
	end
    mass = mass + uDefObj.mass
	if mass > tDefObj.transportMass then
        Log("Mass: " .. mass .. " vs capacity " .. tDefObj.transportMass .. " for " .. unitName(unitID), debugLog)
		return false
	end
	return true
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	local createdUnitDefs = UnitDefs[unitDefID]
    local createdUnitID = unitID
    local factory = factories[factID]
    if unitTeam == myTeam then
        -- TODO Make this more efficient

        if createdUnitDefs.isTransport then
            registerUnit(createdUnitID)
            -- Handle case where transport is rallied to another lab
            local unitCommands = Spring.GetUnitCommands(createdUnitID,-1)
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
            for _, transportID in ipairs(factory.guardingTransports) do
                if worthTransporting(createdUnitID, transportID) then
                    local destination = getSecondMoveCommandDestination(createdUnitID)
                    if destination == nil then
                        Log("Second destination not a move command", debugLog)
                        return
                    end
                    if transports[transportID].state == transport_states.idle and CanTransport(transportID, createdUnitID) then                   
                        Log("Transport " .. transportID .. " APPROACHING " .. createdUnitID, debugLog)
                        transports[transportID].state = transport_states.approaching
                        transports[transportID].destination = destination

                        transportLocation           = getUnitPositionTuple(transportID)
                        unitLocation                = getUnitPositionTuple(createdUnitID)
                        local unitWaitDestination   = getFirstMoveCommandDestination(createdUnitID)
                        transportDestination        = unitLocation
                        Spring.GiveOrderToUnit(transportID, CMD.MOVE ,unitWaitDestination,{ "right" } )--Load Unit
                        Spring.GiveOrderToUnit(transportID, CMD.GUARD ,factID,{ "shift" } )--Load Unit

                        watchedTransports[transportID] = createdUnitID
                        watchedUnits[createdUnitID] = transportID
                        return
                    end
                else
                    Log("Not worth transporting", debugLog)
                end
            end            
        end
    end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts) 
    selectedUnits = Spring.GetSelectedUnits()
    for _,orderedUnit in ipairs(selectedUnits) do
        local unitDefID = Spring.GetUnitDefID(orderedUnit)
        local orderedUnitDefs = UnitDefs[unitDefID]
        if orderedUnitDefs.isTransport then
            if cmdID==CMD.GUARD and IsFab(cmdParams[1]) then
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
