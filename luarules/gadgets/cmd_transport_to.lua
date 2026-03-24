function gadget:GetInfo()
    return {
        name = "Transport To Command",
        desc = "Ferry system",
        author = "Isajoefeat",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return end

local CMD_TRANSPORT_TO = 19990
local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_REMOVE = CMD.REMOVE

local POLL_RATE = 10
local ARRIVAL_DIST_SQ = 64 * 64

local jobs = {}            -- [unitID] = {cmdTag, targets, targetIndex, state, transportID, walkIssued, mergedQueue, complete}
local transportState = {}  -- [transportID] = {unitID, origin={x,y,z}, state="pickup"/"loaded"/"returning"}
local internalOrders = {}

local function MarkInternal(unitID)
    internalOrders[unitID] = (internalOrders[unitID] or 0) + 1
end

local function GiveInternalOrder(unitID, cmdID, params, opts)
    MarkInternal(unitID)
    Spring.GiveOrderToUnit(unitID, cmdID, params or {}, opts or {})
end

local function IsValid(unitID)
    return unitID and Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function IsTransport(unitID)
    if not IsValid(unitID) then
        return false
    end
    local unitDefID = Spring.GetUnitDefID(unitID)
    if not unitDefID then
        return false
    end
    local ud = UnitDefs[unitDefID]
    return ud and ud.transportCapacity and ud.transportCapacity > 0
end

local function ShouldHaveFerry(unitDefID)
    local ud = UnitDefs[unitDefID]
    if not ud then return false end
    if ud.isBuilding then return false end
    if ud.isImmobile then return false end
    if ud.canFly then return false end
    if ud.transportCapacity and ud.transportCapacity > 0 then return false end
    if not ud.canMove then return false end
    return true
end

local function DistSq(x1, z1, x2, z2)
    local dx = x1 - x2
    local dz = z1 - z2
    return dx * dx + dz * dz
end

local function ParseTargets(cmdParams)
    local targets = {}
    for i = 1, #cmdParams, 3 do
        if cmdParams[i] and cmdParams[i + 1] and cmdParams[i + 2] then
            targets[#targets + 1] = {
                cmdParams[i],
                cmdParams[i + 1],
                cmdParams[i + 2]
            }
        end
    end
    return targets
end

local function AppendTargets(dst, src)
    for i = 1, #src do
        dst[#dst + 1] = src[i]
    end
end

local function FindTransport(unitID)
    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)

    local ux, _, uz = Spring.GetUnitPosition(unitID)
    local best, bestDist = nil, math.huge

    for i = 1, #units do
        local u = units[i]
        if IsTransport(u) and not transportState[u] then
            local tx, _, tz = Spring.GetUnitPosition(u)
            if tx and tz then
                local d = DistSq(ux, uz, tx, tz)
                if d < bestDist then
                    bestDist = d
                    best = u
                end
            end
        end
    end

    return best
end

local function UnitReachedTarget(unitID, target)
    local x, _, z = Spring.GetUnitPosition(unitID)
    if not x or not target then
        return false
    end
    return DistSq(x, z, target[1], target[3]) <= ARRIVAL_DIST_SQ
end

local function RemoveQueuedFerryCommands(unitID, currentTag, job)
    local cmds = Spring.GetUnitCommands(unitID, 32)
    if not cmds then
        return
    end

    local foundCurrent = false
    local removeTags = {}

    for i = 1, #cmds do
        local c = cmds[i]

        if c.tag == currentTag then
            foundCurrent = true
        elseif foundCurrent then
            if c.id == CMD_TRANSPORT_TO then
                local extraTargets = ParseTargets(c.params or {})
                AppendTargets(job.targets, extraTargets)
                removeTags[#removeTags + 1] = c.tag
            else
                break
            end
        end
    end

    if #removeTags > 0 then
        GiveInternalOrder(unitID, CMD_REMOVE, removeTags, {})
    end
end

local function CancelJob(unitID, returnTransport)
    local job = jobs[unitID]
    if not job then
        return
    end

    local t = job.transportID
    if t and transportState[t] then
        local ts = transportState[t]
        if returnTransport and ts.origin and IsValid(t) then
            transportState[t].state = "returning"
            GiveInternalOrder(t, CMD_MOVE, ts.origin, {})
        else
            transportState[t] = nil
        end
    end

    jobs[unitID] = nil
end

function gadget:Initialize()
    Spring.Echo("[Ferry] state machine loaded")
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if internalOrders[unitID] and internalOrders[unitID] > 0 then
        internalOrders[unitID] = internalOrders[unitID] - 1
        return true
    end

    -- If the unit has an active ferry job and gets any other command, cancel ferry
    if jobs[unitID] and cmdID ~= CMD_TRANSPORT_TO then
        CancelJob(unitID, true)
    end

    -- If a managed transport gets manually ordered, release it and recover the unit job
    if transportState[unitID] and cmdID ~= CMD_LOAD_UNITS and cmdID ~= CMD_UNLOAD_UNITS then
        local ts = transportState[unitID]
        transportState[unitID] = nil

        if ts.unitID and jobs[ts.unitID] then
            local job = jobs[ts.unitID]

            if Spring.GetUnitTransporter(ts.unitID) == unitID then
                -- already loaded: let player take over transport, cancel ferry job
                jobs[ts.unitID] = nil
            else
                -- before pickup: go back to walking fallback
                job.transportID = nil
                job.state = "walking"
                job.walkIssued = false
                local target = job.targets[job.targetIndex or 1]
                if target and IsValid(ts.unitID) then
                    GiveInternalOrder(ts.unitID, CMD_MOVE, target, {})
                end
            end
        end
    end

    return true
end

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag)
    if cmdID ~= CMD_TRANSPORT_TO then
        return false, false
    end

    if not IsValid(unitID) then
        jobs[unitID] = nil
        return true, true
    end

    local job = jobs[unitID]

    if not job or job.cmdTag ~= cmdTag then
        local targets = ParseTargets(cmdParams or {})
        if #targets == 0 then
            return true, true
        end

        job = {
            cmdTag = cmdTag,
            targets = targets,
            targetIndex = 1,
            state = "walking",
            transportID = nil,
            walkIssued = false,
            mergedQueue = false,
            complete = false,
        }
        jobs[unitID] = job
    end

    if not job.mergedQueue then
        RemoveQueuedFerryCommands(unitID, cmdTag, job)
        job.mergedQueue = true
    end

    if job.complete then
        jobs[unitID] = nil
        return true, true
    end

    local currentTarget = job.targets[job.targetIndex]
    if not currentTarget then
        jobs[unitID] = nil
        return true, true
    end

    if job.state == "walking" then
        if UnitReachedTarget(unitID, currentTarget) then
            if job.targetIndex < #job.targets then
                job.targetIndex = job.targetIndex + 1
                currentTarget = job.targets[job.targetIndex]
                GiveInternalOrder(unitID, CMD_MOVE, currentTarget, {})
                job.walkIssued = true
                return true, false
            else
                job.complete = true
                return true, false
            end
        end

        if not job.walkIssued then
            GiveInternalOrder(unitID, CMD_MOVE, currentTarget, {})
            job.walkIssued = true
        end

        local t = FindTransport(unitID)
        if t then
            job.transportID = t
            job.state = "pickup"
            job.walkIssued = false

            transportState[t] = {
                unitID = unitID,
                origin = {Spring.GetUnitPosition(t)},
                state = "pickup",
                ordersIssued = false,
            }

            GiveInternalOrder(unitID, CMD_STOP, {}, {})
            GiveInternalOrder(t, CMD_LOAD_UNITS, {unitID}, {})
        end

        return true, false
    end

    if job.state == "pickup" or job.state == "loaded" then
        return true, false
    end

    return true, false
end

function gadget:GameFrame(frame)
    if frame % POLL_RATE ~= 0 then return end

    for transportID, ts in pairs(transportState) do
        if not IsValid(transportID) then
            transportState[transportID] = nil

            if ts.unitID and jobs[ts.unitID] then
                local job = jobs[ts.unitID]
                job.transportID = nil
                job.state = "walking"
                job.walkIssued = false

                local target = job.targets[job.targetIndex or 1]
                if target and IsValid(ts.unitID) then
                    GiveInternalOrder(ts.unitID, CMD_MOVE, target, {})
                end
            end

        elseif ts.state == "pickup" then
            local unitID = ts.unitID
            local job = jobs[unitID]

            if not job or not IsValid(unitID) then
                transportState[transportID] = nil
            elseif Spring.GetUnitTransporter(unitID) == transportID then
                ts.state = "loaded"

                if not ts.ordersIssued then
                    ts.ordersIssued = true
                    job.state = "loaded"

                    local currentTarget = job.targets[job.targetIndex]
                    GiveInternalOrder(transportID, CMD_MOVE, currentTarget, {})

                    for i = job.targetIndex + 1, #job.targets do
                        GiveInternalOrder(transportID, CMD_MOVE, job.targets[i], {"shift"})
                    end

                    local final = job.targets[#job.targets]
                    GiveInternalOrder(transportID, CMD_UNLOAD_UNITS, final, {"shift"})
                end
            end

        elseif ts.state == "loaded" then
            local unitID = ts.unitID
            local job = jobs[unitID]

            if not job then
                transportState[transportID] = nil
            elseif not Spring.GetUnitTransporter(unitID) then
                if ts.origin and IsValid(transportID) then
                    ts.state = "returning"
                    GiveInternalOrder(transportID, CMD_MOVE, ts.origin, {})
                else
                    transportState[transportID] = nil
                end

                job.complete = true
            end

        elseif ts.state == "returning" then
            local x, _, z = Spring.GetUnitPosition(transportID)
            if x and ts.origin and DistSq(x, z, ts.origin[1], ts.origin[3]) <= ARRIVAL_DIST_SQ then
                transportState[transportID] = nil
            end
        end
    end
end

function gadget:UnitCreated(unitID, unitDefID)
    if ShouldHaveFerry(unitDefID) then
        Spring.InsertUnitCmdDesc(unitID, 500, {
            id = CMD_TRANSPORT_TO,
            type = CMDTYPE.ICON_MAP,
            name = "Ferry",
            action = "ferry",
            tooltip = "Request the closest eligible transport to transport this unit to the target location",
        })
    end
end

function gadget:UnitGiven(unitID, unitDefID)
    if ShouldHaveFerry(unitDefID) then
        Spring.InsertUnitCmdDesc(unitID, 500, {
            id = CMD_TRANSPORT_TO,
            type = CMDTYPE.ICON_MAP,
            name = "Ferry",
            action = "ferry",
            tooltip = "Request the closest eligible transport to transport this unit to the target location",
        })
    end
end

function gadget:UnitDestroyed(unitID)
    if jobs[unitID] then
        CancelJob(unitID, true)
    end

    if transportState[unitID] then
        local ts = transportState[unitID]
        transportState[unitID] = nil

        if ts.unitID and jobs[ts.unitID] then
            local job = jobs[ts.unitID]
            job.transportID = nil
            job.state = "walking"
            job.walkIssued = false

            local target = job.targets[job.targetIndex or 1]
            if target and IsValid(ts.unitID) then
                GiveInternalOrder(ts.unitID, CMD_MOVE, target, {})
            end
        end
    end

    internalOrders[unitID] = nil
end