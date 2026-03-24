local widget = widget

function widget:GetInfo()
    return {
        name    = "Transport To Command",
        desc    = "Enables transports to transport units to a clicked location",
        author  = "Isajoefeat",
        date    = "2026",
        version = "1.0",
        license = "GPL",
        layer   = 0,
        enabled = true
    }
end

-- Polling rate and constants
local POLLING_RATE = 10
local transport_states = {
    idle = 0,
    moving_to_pickup = 1,
    picking_up = 2,
    moving_to_destination = 3,
    unloading = 4,
    returning_home = 5
}

-- State tracking
local activeTransports = {}  -- { [transportID] = { unitID, destination, homeLocation, state } }
local transportState = {}
local unitToTransport = {}   -- Which transport is carrying which unit

-- Localized Spring functions
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead

local CMD_TRANSPORT_TO = 19990

local function distance(p1, p2)
    if not p1 or not p2 then return -1 end
    local dx = p1[1] - p2[1]
    local dy = p1[2] - p2[2]
    local dz = p1[3] - p2[3]
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function IsUnitAlive(unitID)
    return spValidUnitID(unitID) and not spGetUnitIsDead(unitID)
end

function widget:Initialize()
    if Spring.GetSpectatingState() or Spring.IsReplay() then
        widgetHandler:RemoveWidget()
        return
    end
end

function widget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID == CMD_TRANSPORT_TO then
        -- User issued transport-to command
        if cmdParams[1] and cmdParams[2] and cmdParams[3] then
            local destination = { cmdParams[1], cmdParams[2], cmdParams[3] }
            local homeLocation = { spGetUnitPosition(unitID) }
            
            activeTransports[unitID] = {
                unitID = unitID,
                destination = destination,
                homeLocation = homeLocation,
                state = transport_states.moving_to_pickup,
                targetUnit = nil  -- Will be set when we pick a unit
            }
            transportState[unitID] = transport_states.moving_to_pickup
        end
        return false  -- Block the command from being processed further
    end
    return true
end

function widget:GameFrame(frame)
    if frame % POLLING_RATE ~= 0 then
        return
    end

    for transportID, data in pairs(activeTransports) do
        if not IsUnitAlive(transportID) then
            activeTransports[transportID] = nil
            transportState[transportID] = nil
        else
            local state = data.state
            local currentPos = { spGetUnitPosition(transportID) }

            -- State: idle - wait for new orders
            if state == transport_states.idle then
                -- Do nothing, waiting for next command
            end

            -- State: returning home after dropoff
            if state == transport_states.returning_home then
                local distToHome = distance(currentPos, data.homeLocation)
                if distToHome < 100 then  -- Close enough to home
                    data.state = transport_states.idle
                    transportState[transportID] = transport_states.idle
                end
            end

            -- State: moving to destination (after pickup)
            if state == transport_states.moving_to_destination then
                local carried = spGetUnitIsTransporting(transportID) or {}
                if #carried == 0 then
                    -- Unit dropped off, return home
                    data.state = transport_states.returning_home
                    transportState[transportID] = transport_states.returning_home
                    spGiveOrderToUnit(transportID, CMD.MOVE, data.homeLocation, CMD.OPT_RIGHT)
                else
                    -- Still have unit, continue to destination
                    local distToDest = distance(currentPos, data.destination)
                    if distToDest < 50 then
                        -- Close to destination, unload
                        spGiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, {}, CMD.OPT_RIGHT)
                    end
                end
            end

            -- State: picking up unit
            if state == transport_states.picking_up then
                local carried = spGetUnitIsTransporting(transportID) or {}
                if #carried > 0 then
                    -- Successfully picked up unit, move to destination
                    data.state = transport_states.moving_to_destination
                    transportState[transportID] = transport_states.moving_to_destination
                    spGiveOrderToUnit(transportID, CMD.MOVE, data.destination, CMD.OPT_RIGHT)
                end
            end
        end
    end
end

function widget:UnitCommandNotify(unitID, cmdID, cmdParams, cmdOpts)
    -- If user issues any other command to the transport, abort
    if activeTransports[unitID] and cmdID ~= CMD_TRANSPORT_TO then
        activeTransports[unitID] = nil
        transportState[unitID] = nil
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    activeTransports[unitID] = nil
    transportState[unitID] = nil
end
