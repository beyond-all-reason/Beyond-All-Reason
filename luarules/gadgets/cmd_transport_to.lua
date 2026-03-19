function gadget:GetInfo()
    return {
        name = "Transport To Command",
        desc = "Adds ferry command",
        author = "You",
        date = "2026",
        license = "GPL",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local CMD_TRANSPORT_TO = 19990

local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS

local cmdDesc = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Ferry",
    action = "ferry",
    tooltip = "Transport this unit to a location",
    cursor = "Attack",
    params = {},
}

local jobs = {}           -- [unitID] = {target={}, state="", transportID=nil, originalPos=nil}
local transportState = {} -- [transportID] = {state="", unitID=nil, origin=nil}
local internalOrders = {} -- guard so our own GiveOrderToUnit calls don't cancel jobs

local RETURN_RADIUS_SQ = 100 * 100

Spring.Echo("Transport gadget loaded")

local function IssueOrder(unitID, cmdID, params, opts)
    internalOrders[unitID] = (internalOrders[unitID] or 0) + 1
    Spring.GiveOrderToUnit(unitID, cmdID, params, opts)
end

local function DistSq(x1, z1, x2, z2)
    local dx = x1 - x2
    local dz = z1 - z2
    return dx * dx + dz * dz
end

local function IsValidUnit(unitID)
    return unitID and Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function IsTransport(unitID)
    if not IsValidUnit(unitID) then
        return false
    end
    local unitDefID = Spring.GetUnitDefID(unitID)
    local ud = unitDefID and UnitDefs[unitDefID]
    return ud and ud.transportCapacity and ud.transportCapacity > 0
end

local function IsIdleTransport(unitID)
    if not IsTransport(unitID) then
        return false
    end
    if transportState[unitID] then
        return false
    end

    local cmds = Spring.GetUnitCommands(unitID, 1)
    if cmds and #cmds > 0 then
        return false
    end

    return true
end

local function StartReturningTransport(transportID, origin)
    if not IsTransport(transportID) then
        transportState[transportID] = nil
        return
    end

    transportState[transportID] = {
        state = "returning",
        unitID = nil,
        origin = origin,
    }

    IssueOrder(transportID, CMD_STOP, {}, {})
    IssueOrder(transportID, CMD_MOVE, origin, {})
end

local function ClearJob(unitID)
    jobs[unitID] = nil
end

local function CancelJob(unitID, fallbackWalk)
    local job = jobs[unitID]
    if not job then
        return
    end

    local transportID = job.transportID
    local origin = job.originalPos

    if transportID and transportState[transportID] then
        local ts = transportState[transportID]

        -- If the transport was ours and is not currently carrying the unit anymore,
        -- or if it is ours and we want to cancel, send it home.
        if ts.unitID == unitID then
            StartReturningTransport(transportID, origin)
        end
    end

    -- If unit is not loaded and we want fallback, keep walking
    if fallbackWalk and IsValidUnit(unitID) and not Spring.GetUnitTransporter(unitID) then
        IssueOrder(unitID, CMD_MOVE, job.target, {})
    end

    ClearJob(unitID)
end

local function FindClosestTransport(unitID)
    if not IsValidUnit(unitID) then
        return nil
    end

    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)
    local ux, _, uz = Spring.GetUnitPosition(unitID)

    local bestID = nil
    local bestDist = math.huge

    for i = 1, #units do
        local u = units[i]
        if IsIdleTransport(u) then
            local tx, _, tz = Spring.GetUnitPosition(u)
            if tx and tz then
                local dist = DistSq(ux, uz, tx, tz)
                if dist < bestDist then
                    bestDist = dist
                    bestID = u
                end
            end
        end
    end

    return bestID
end

local function AssignTransport(unitID, job, transportID)
    local tx, ty, tz = Spring.GetUnitPosition(transportID)

    job.transportID = transportID
    job.originalPos = {tx, ty, tz}
    job.state = "assigned"

    transportState[transportID] = {
        state = "pickup",
        unitID = unitID,
        origin = {tx, ty, tz},
    }

    Spring.Echo("Assigning transport", transportID, "to unit", unitID)

    IssueOrder(unitID, CMD_STOP, {}, {})
    IssueOrder(transportID, CMD_STOP, {}, {})
    IssueOrder(transportID, CMD_LOAD_UNITS, {unitID}, {})
end

function gadget:UnitCreated(unitID, unitDefID, team)
    Spring.InsertUnitCmdDesc(unitID, 500, cmdDesc)
end

function gadget:UnitDestroyed(unitID)
    if jobs[unitID] then
        CancelJob(unitID, false)
    end

    if transportState[unitID] then
        local ts = transportState[unitID]
        transportState[unitID] = nil

        if ts.unitID and jobs[ts.unitID] then
            local job = jobs[ts.unitID]
            job.transportID = nil
            job.originalPos = nil
            job.state = "walking"

            if IsValidUnit(ts.unitID) and not Spring.GetUnitTransporter(ts.unitID) then
                IssueOrder(ts.unitID, CMD_MOVE, job.target, {})
            end
        end
    end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    -- Ignore our own commands so they don't trigger cancellation logic
    if internalOrders[unitID] and internalOrders[unitID] > 0 then
        internalOrders[unitID] = internalOrders[unitID] - 1
        return true
    end

    -- New ferry command
    if cmdID == CMD_TRANSPORT_TO then
        Spring.Echo("Ferry command received", unitID)

        -- Replace existing ferry job if one exists
        if jobs[unitID] then
            CancelJob(unitID, false)
        end

        jobs[unitID] = {
            target = {cmdParams[1], cmdParams[2], cmdParams[3]},
            state = "walking",
            transportID = nil,
            originalPos = nil,
        }

        -- fallback behavior: start moving immediately
        IssueOrder(unitID, CMD_MOVE, cmdParams, {})

        return false
    end

    -- If a unit with an active ferry job gets any other external command,
    -- cancel the ferry request completely.
    if jobs[unitID] then
        Spring.Echo("Cancelling ferry job because unit got a new command", unitID)
        CancelJob(unitID, false)
        return true
    end

    -- If a managed transport gets an external command, it becomes ineligible.
    if transportState[unitID] then
        local ts = transportState[unitID]
        Spring.Echo("Managed transport got a new command, cancelling managed state", unitID)

        transportState[unitID] = nil

        if ts.unitID and jobs[ts.unitID] then
            local job = jobs[ts.unitID]

            -- If the unit is still inside this transport, we can't force fallback walking.
            -- For now, we just cancel the ferry logic and let the player/manual orders take over.
            if Spring.GetUnitTransporter(ts.unitID) == unitID then
                ClearJob(ts.unitID)
            else
                job.transportID = nil
                job.originalPos = nil
                job.state = "walking"
                IssueOrder(ts.unitID, CMD_MOVE, job.target, {})
            end
        end

        return true
    end

    return true
end

function gadget:GameFrame(frame)
    if frame % 15 ~= 0 then
        return
    end

    -- Finish returning transports
    for transportID, ts in pairs(transportState) do
        if ts.state == "returning" then
            if not IsTransport(transportID) then
                transportState[transportID] = nil
            else
                local tx, _, tz = Spring.GetUnitPosition(transportID)
                local ox, _, oz = ts.origin[1], ts.origin[2], ts.origin[3]

                if tx and tz and DistSq(tx, tz, ox, oz) <= RETURN_RADIUS_SQ then
                    Spring.Echo("Transport returned to origin", transportID)
                    transportState[transportID] = nil
                end
            end
        end
    end

    -- Process jobs
    for unitID, job in pairs(jobs) do
        if not IsValidUnit(unitID) then
            CancelJob(unitID, false)
        else
            if job.state == "walking" then
                local transportID = FindClosestTransport(unitID)
                if transportID then
                    AssignTransport(unitID, job, transportID)
                end
            end

            if job.state == "assigned" then
                local transportID = job.transportID

                if not IsTransport(transportID) then
                    Spring.Echo("Assigned transport invalid, back to walking", unitID)
                    job.transportID = nil
                    job.originalPos = nil
                    job.state = "walking"
                    IssueOrder(unitID, CMD_MOVE, job.target, {})
                else
                    local transporter = Spring.GetUnitTransporter(unitID)

                    if transporter and transporter == transportID then
                        Spring.Echo("Unit picked up!", unitID)

                        job.state = "loaded"
                        transportState[transportID] = {
                            state = "loaded",
                            unitID = unitID,
                            origin = job.originalPos,
                        }

                        IssueOrder(transportID, CMD_STOP, {}, {})
                        IssueOrder(transportID, CMD_MOVE, job.target, {})
                        IssueOrder(transportID, CMD_UNLOAD_UNITS, job.target, {"shift"})
                    end
                end
            end

            if job.state == "loaded" then
                local transporter = Spring.GetUnitTransporter(unitID)

                if not transporter then
                    Spring.Echo("Unit unloaded!", unitID)

                    local transportID = job.transportID
                    local origin = job.originalPos

                    ClearJob(unitID)
                    StartReturningTransport(transportID, origin)
                elseif transporter ~= job.transportID then
                    Spring.Echo("Unit ended up in a different transport, cancelling ferry job", unitID)
                    ClearJob(unitID)
                end
            end
        end
    end
end