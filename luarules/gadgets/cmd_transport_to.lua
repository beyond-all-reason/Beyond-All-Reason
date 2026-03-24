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

local jobs = {}
local transportState = {}
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
    if not IsValid(unitID) then return false end
    local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
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
        if cmdParams[i] and cmdParams[i+1] and cmdParams[i+2] then
            targets[#targets+1] = {cmdParams[i], cmdParams[i+1], cmdParams[i+2]}
        end
    end
    return targets
end

local function AppendTargets(dst, src)
    for i = 1, #src do
        dst[#dst+1] = src[i]
    end
end

local function FindTransport(unitID)
    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)

    local ux,_,uz = Spring.GetUnitPosition(unitID)
    local best, bestDist = nil, math.huge

    for i=1,#units do
        local u = units[i]
        if IsTransport(u) and not transportState[u] then
            local tx,_,tz = Spring.GetUnitPosition(u)
            if tx then
                local d = DistSq(ux,uz,tx,tz)
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
    local x,_,z = Spring.GetUnitPosition(unitID)
    if not x then return false end
    return DistSq(x,z,target[1],target[3]) <= ARRIVAL_DIST_SQ
end

local function RemoveQueuedFerryCommands(unitID, currentTag, job)
    local cmds = Spring.GetUnitCommands(unitID, 32)
    if not cmds then return end

    local found = false
    local removeTags = {}

    for i=1,#cmds do
        local c = cmds[i]

        if c.tag == currentTag then
            found = true
        elseif found then
            if c.id == CMD_TRANSPORT_TO then
                local extra = ParseTargets(c.params or {})
                AppendTargets(job.targets, extra)
                removeTags[#removeTags+1] = c.tag
            else
                break
            end
        end
    end

    if #removeTags > 0 then
        GiveInternalOrder(unitID, CMD_REMOVE, removeTags, {})
    end
end

local function CancelJob(unitID)
    local job = jobs[unitID]
    if not job then return end

    if job.transportID then
        local t = job.transportID
        local ts = transportState[t]
        if ts and ts.origin then
            GiveInternalOrder(t, CMD_MOVE, ts.origin, {})
        end
        transportState[t] = nil
    end

    jobs[unitID] = nil
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
    if internalOrders[unitID] and internalOrders[unitID] > 0 then
        internalOrders[unitID] = internalOrders[unitID] - 1
        return true
    end

    if jobs[unitID] and cmdID ~= CMD_TRANSPORT_TO then
        CancelJob(unitID)
    end

    if transportState[unitID] and cmdID ~= CMD_LOAD_UNITS and cmdID ~= CMD_UNLOAD_UNITS then
        transportState[unitID] = nil
    end

    return true
end

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag)
    if cmdID ~= CMD_TRANSPORT_TO then
        return false, false
    end

    local job = jobs[unitID]

    if not job then
        local targets = ParseTargets(cmdParams)
        if #targets == 0 then return true, true end

        job = {
            cmdTag = cmdTag,
            targets = targets,
            targetIndex = 1,
            state = "walking",
            transportID = nil,
        }
        jobs[unitID] = job

        RemoveQueuedFerryCommands(unitID, cmdTag, job)
    end

    local target = job.targets[job.targetIndex]

    if job.state == "walking" then
        if UnitReachedTarget(unitID, target) then
            if job.targetIndex < #job.targets then
                job.targetIndex = job.targetIndex + 1
                GiveInternalOrder(unitID, CMD_MOVE, job.targets[job.targetIndex], {})
                return true, false
            else
                jobs[unitID] = nil
                return true, true
            end
        end

        if not job.walkIssued then
            GiveInternalOrder(unitID, CMD_MOVE, target, {})
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
            }

            GiveInternalOrder(unitID, CMD_STOP, {}, {})
            GiveInternalOrder(t, CMD_LOAD_UNITS, {unitID}, {})
        end

        return true, false
    end

    if job.state == "pickup" then
        local t = job.transportID

        if Spring.GetUnitTransporter(unitID) == t then
            job.state = "loaded"
            job.justLoaded = true
            transportState[t].state = "loaded"
        end

        return true, false
    end

    if job.state == "loaded" then
        local t = job.transportID

        if job.justLoaded then
            job.justLoaded = false

            GiveInternalOrder(t, CMD_MOVE, job.targets[job.targetIndex], {})

            for i = job.targetIndex + 1, #job.targets do
                GiveInternalOrder(t, CMD_MOVE, job.targets[i], {"shift"})
            end

            local final = job.targets[#job.targets]
            GiveInternalOrder(t, CMD_UNLOAD_UNITS, final, {"shift"})

            return true, false
        end

        if not Spring.GetUnitTransporter(unitID) then
            local ts = transportState[t]
            if ts and ts.origin then
                GiveInternalOrder(t, CMD_MOVE, ts.origin, {})
            end

            transportState[t] = nil
            jobs[unitID] = nil
            return true, true
        end

        return true, false
    end

    return true, false
end

function gadget:GameFrame(frame)
    if frame % POLL_RATE ~= 0 then return end

    for t, ts in pairs(transportState) do
        if not IsValid(t) then
            transportState[t] = nil
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
    CancelJob(unitID)
    transportState[unitID] = nil
end