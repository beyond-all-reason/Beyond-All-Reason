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

local CMD_OPT_SHIFT   = CMD.OPT_SHIFT   or 32
local CMD_OPT_ALT     = CMD.OPT_ALT     or 128
local CMD_OPT_CTRL    = CMD.OPT_CTRL    or 64
local CMD_OPT_RIGHT   = CMD.OPT_RIGHT   or 16
local CMD_OPT_INTERNAL= CMD.OPT_INTERNAL or 8

local cmdDesc = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Ferry",
    action = "ferry",
    tooltip = "Transport this unit to a location",
    cursor = "Attack",
    params = {},
}

local jobs = {}           -- [unitID] = {targets={}, state="", transportID=nil, originalPos=nil, postCommands={}}
local transportState = {} -- [transportID] = {state="", unitID=nil, origin=nil}
local internalOrders = {}

local RETURN_RADIUS_SQ = 100 * 100

Spring.Echo("Transport gadget loaded")

local function EncodeCmdOptions(cmdOptions)
    if type(cmdOptions) == "number" then
        return cmdOptions
    end
    if type(cmdOptions) ~= "table" then
        return 0
    end

    local opt = 0
    if cmdOptions.shift then opt = opt + CMD_OPT_SHIFT end
    if cmdOptions.alt then opt = opt + CMD_OPT_ALT end
    if cmdOptions.ctrl then opt = opt + CMD_OPT_CTRL end
    if cmdOptions.right then opt = opt + CMD_OPT_RIGHT end
    if cmdOptions.internal then opt = opt + CMD_OPT_INTERNAL end
    return opt
end

local function HasShift(cmdOptions)
    if type(cmdOptions) == "number" then
        return (cmdOptions % (CMD_OPT_SHIFT * 2)) >= CMD_OPT_SHIFT
    end
    return type(cmdOptions) == "table" and cmdOptions.shift
end

local function IssueOrder(unitID, cmdID, params, opts)
    internalOrders[unitID] = (internalOrders[unitID] or 0) + 1
    Spring.GiveOrderToUnit(unitID, cmdID, params or {}, EncodeCmdOptions(opts))
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

local function ReplayPostCommands(unitID, postCommands)
    if not IsValidUnit(unitID) or not postCommands then
        return
    end

    Spring.Echo("Replaying post-ferry commands for", unitID, "#", #postCommands)

    for i = 1, #postCommands do
        local c = postCommands[i]
        Spring.Echo("Replay cmd", c.cmdID, "for unit", unitID)
        IssueOrder(unitID, c.cmdID, c.params or {}, c.options or 0)
    end
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

    IssueOrder(transportID, CMD_STOP, {}, 0)
    IssueOrder(transportID, CMD_MOVE, origin, 0)
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
        if ts.unitID == unitID then
            StartReturningTransport(transportID, origin)
        end
    end

    if fallbackWalk and IsValidUnit(unitID) and not Spring.GetUnitTransporter(unitID) then
        local firstTarget = job.targets and job.targets[1]
        if firstTarget then
            IssueOrder(unitID, CMD_MOVE, firstTarget, 0)
        end
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

    IssueOrder(unitID, CMD_STOP, {}, 0)
    IssueOrder(transportID, CMD_STOP, {}, 0)
    IssueOrder(transportID, CMD_LOAD_UNITS, {unitID}, 0)
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
                local firstTarget = job.targets and job.targets[1]
                if firstTarget then
                    IssueOrder(ts.unitID, CMD_MOVE, firstTarget, 0)
                end
            end
        end
    end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if internalOrders[unitID] and internalOrders[unitID] > 0 then
        internalOrders[unitID] = internalOrders[unitID] - 1
        return true
    end

    if cmdID == CMD_TRANSPORT_TO then
        Spring.Echo("Ferry command received", unitID)

        local target = {cmdParams[1], cmdParams[2], cmdParams[3]}

        if jobs[unitID] and HasShift(cmdOptions) then
            table.insert(jobs[unitID].targets, target)
        else
            if jobs[unitID] then
                CancelJob(unitID, false)
            end

            jobs[unitID] = {
                targets = {target},
                state = "walking",
                transportID = nil,
                originalPos = nil,
                postCommands = {},
            }

            IssueOrder(unitID, CMD_MOVE, target, 0)
        end

        return false
    end

    -- STOP is a clean cancel
    if jobs[unitID] and cmdID == CMD_STOP then
        Spring.Echo("STOP received, cancelling ferry job for", unitID)
        CancelJob(unitID, false)
        return true
    end

    -- Any other unit command gets stored for after unload
    if jobs[unitID] then
        local job = jobs[unitID]

        job.postCommands[#job.postCommands + 1] = {
            cmdID = cmdID,
            params = cmdParams,
            options = EncodeCmdOptions(cmdOptions),
        }

        Spring.Echo("Stored post-ferry command for unit", unitID, cmdID)
        return false
    end

    -- Manual command to a managed transport breaks ferry management
    if transportState[unitID] then
        local ts = transportState[unitID]
        Spring.Echo("Managed transport got a new command, cancelling managed state", unitID)

        transportState[unitID] = nil

        if ts.unitID and jobs[ts.unitID] then
            local job = jobs[ts.unitID]

            if Spring.GetUnitTransporter(ts.unitID) == unitID then
                ClearJob(ts.unitID)
            else
                job.transportID = nil
                job.originalPos = nil
                job.state = "walking"

                local firstTarget = job.targets and job.targets[1]
                if firstTarget then
                    IssueOrder(ts.unitID, CMD_MOVE, firstTarget, 0)
                end
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

                    local firstTarget = job.targets and job.targets[1]
                    if firstTarget then
                        IssueOrder(unitID, CMD_MOVE, firstTarget, 0)
                    end
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

                        IssueOrder(transportID, CMD_STOP, {}, 0)

                        for i = 1, #job.targets do
                            local pos = job.targets[i]
                            if i == 1 then
                                IssueOrder(transportID, CMD_MOVE, pos, 0)
                            else
                                IssueOrder(transportID, CMD_MOVE, pos, CMD_OPT_SHIFT)
                            end
                        end

                        local final = job.targets[#job.targets]
                        IssueOrder(transportID, CMD_UNLOAD_UNITS, final, CMD_OPT_SHIFT)
                    end
                end
            end

            if job.state == "loaded" then
                local transporter = Spring.GetUnitTransporter(unitID)

                if not transporter then
                    Spring.Echo("Unit unloaded!", unitID)

                    local transportID = job.transportID
                    local origin = job.originalPos
                    local postCommands = job.postCommands

                    ClearJob(unitID)

                    if transportID and origin then
                        StartReturningTransport(transportID, origin)
                    end

                    ReplayPostCommands(unitID, postCommands)
                elseif transporter ~= job.transportID then
                    Spring.Echo("Unit ended up in a different transport, cancelling ferry job", unitID)
                    ClearJob(unitID)
                end
            end
        end
    end
end