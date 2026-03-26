function gadget:GetInfo()
    return {
        name = "Transport To Command",
        desc = "Ferry system",
        author = "Isajoefeat",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO
local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS

local POLL_RATE = 10
local ARRIVAL_DIST_SQ = 64 * 64

local jobs = {}            -- passengerID -> job
local transportState = {}  -- transportID -> state
local internalOrders = {}
local loadedUnits = {}     -- passengerID -> true while ferry commands are being popped after load

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
    local defID = Spring.GetUnitDefID(unitID)
    if not defID then
        return false
    end
    local ud = UnitDefs[defID]
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

local function ParseTargets(params)
    local t = {}
    for i = 1, #params, 3 do
        if params[i + 2] then
            t[#t + 1] = { params[i], params[i + 1], params[i + 2] }
        end
    end
    return t
end

local function TransportHasPassengers(unitID)
    local carried = Spring.GetUnitIsTransporting(unitID)
    return carried and #carried > 0
end

local function FindTransport(unitID)
    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)

    local ux, _, uz = Spring.GetUnitPosition(unitID)
    if not ux then
        return nil
    end

    local best, bestDist = nil, math.huge

    for i = 1, #units do
        local u = units[i]
        if IsTransport(u) and not transportState[u] then
            local tx, _, tz = Spring.GetUnitPosition(u)
            if tx then
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

local function GetJobTarget(job)
    if not job then
        return nil
    end
    return job.targets[job.index]
end

local function CollectConsecutiveFerryTargets(unitID, fallbackTarget)
    local chain = {}
    local queue = Spring.GetUnitCommands(unitID, -1) or {}

    for i = 1, #queue do
        local cmd = queue[i]
        if cmd.id == CMD_TRANSPORT_TO and cmd.params and cmd.params[3] then
            chain[#chain + 1] = { cmd.params[1], cmd.params[2], cmd.params[3] }
        else
            break
        end
    end

    if #chain == 0 and fallbackTarget then
        chain[1] = { fallbackTarget[1], fallbackTarget[2], fallbackTarget[3] }
    end

    return chain
end

local function QueueTransportTrip(transportID, targets, origin)
    if not targets or #targets == 0 then
        return
    end

    for i = 1, #targets do
        local opts = (i == 1) and {} or { "shift" }
        GiveInternalOrder(transportID, CMD_MOVE, targets[i], opts)
    end

    GiveInternalOrder(transportID, CMD_UNLOAD_UNITS, targets[#targets], { "shift" })

    if origin then
        GiveInternalOrder(transportID, CMD_MOVE, origin, { "shift" })
    end
end

local function CancelJob(unitID)
    local job = jobs[unitID]
    if not job then
        loadedUnits[unitID] = nil
        return
    end

    if job.transportID then
        local ts = transportState[job.transportID]
        if ts and ts.unitID == unitID then
            if IsValid(job.transportID) and not TransportHasPassengers(job.transportID) then
                GiveInternalOrder(job.transportID, CMD_STOP, {}, {})
            end
            transportState[job.transportID] = nil
        end
    end

    jobs[unitID] = nil
    loadedUnits[unitID] = nil
end

local function ReserveTransport(unitID, transportID)
    local job = jobs[unitID]
    if not job then
        return false
    end

    local ox, oy, oz = Spring.GetUnitPosition(transportID)
    if not ox then
        return false
    end

    job.transportID = transportID
    job.state = "reserved"

    transportState[transportID] = {
        unitID = unitID,
        origin = { ox, oy, oz },
        state = "reserved",
        tripQueued = false,
    }

    GiveInternalOrder(unitID, CMD_STOP, {}, {})
    GiveInternalOrder(transportID, CMD_LOAD_UNITS, { unitID }, {})
    return true
end

-- ================= COMMAND =================

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
    if internalOrders[unitID] and internalOrders[unitID] > 0 then
        internalOrders[unitID] = internalOrders[unitID] - 1
        return true
    end

    if jobs[unitID] and cmdID ~= CMD_TRANSPORT_TO then
        CancelJob(unitID)
    end

    if transportState[unitID] then
        local ts = transportState[unitID]
        if ts and ts.unitID and jobs[ts.unitID] then
            jobs[ts.unitID].transportID = nil
            jobs[ts.unitID].state = "walking"
            jobs[ts.unitID].walkIssued = false
        end
        transportState[unitID] = nil
    end

    return true
end

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, params, opts, tag)
    if cmdID ~= CMD_TRANSPORT_TO then
        return false, false
    end

    local target = { params[1], params[2], params[3] }

    -- PR-style behavior:
    -- once the unit is loaded, ferry commands are considered complete and get popped
    -- from the passenger queue while the transport carries the whole chain.
    if loadedUnits[unitID] then
        return true, true
    end

    if not jobs[unitID] then
        local targets = ParseTargets(params)
        if #targets == 0 then
            targets = { target }
        end

        jobs[unitID] = {
            targets = targets,
            index = 1,
            state = "walking",
            transportID = nil,
            walkIssued = false,
        }
    end

    local job = jobs[unitID]
    local currentTarget = GetJobTarget(job) or target

    -- If the unit reached the target on foot, complete this ferry command like a move fallback.
    local ux, _, uz = Spring.GetUnitPosition(unitID)
    if ux and DistSq(ux, uz, currentTarget[1], currentTarget[3]) < ARRIVAL_DIST_SQ then
        jobs[unitID] = nil
        loadedUnits[unitID] = nil
        return true, true
    end

    if job.state == "walking" then
        local transportID = FindTransport(unitID)
        if transportID then
            ReserveTransport(unitID, transportID)
            return true, false
        end

        if not job.walkIssued then
            GiveInternalOrder(unitID, CMD_MOVE, currentTarget, {})
            job.walkIssued = true
        end

        return true, false
    end

    if job.state == "reserved" or job.state == "loaded" then
        return true, false
    end

    return true, false
end

-- ================= STATE MACHINE =================

function gadget:GameFrame(frame)
    if frame % POLL_RATE ~= 0 then
        return
    end

    for unitID, job in pairs(jobs) do
        if not IsValid(unitID) then
            CancelJob(unitID)

        elseif loadedUnits[unitID] then
            jobs[unitID] = nil

        elseif job.state == "walking" then
            local currentTarget = GetJobTarget(job)
            if currentTarget then
                local ux, _, uz = Spring.GetUnitPosition(unitID)
                if ux and DistSq(ux, uz, currentTarget[1], currentTarget[3]) < ARRIVAL_DIST_SQ then
                    jobs[unitID] = nil
                else
                    local transportID = FindTransport(unitID)
                    if transportID then
                        ReserveTransport(unitID, transportID)
                    end
                end
            else
                jobs[unitID] = nil
            end

        elseif job.state == "reserved" then
            local transportID = job.transportID
            if not transportID or not transportState[transportID] then
                job.transportID = nil
                job.state = "walking"
                job.walkIssued = false
            end
        end
    end

    for transportID, ts in pairs(transportState) do
        if not IsValid(transportID) then
            local unitID = ts.unitID
            transportState[transportID] = nil

            if unitID and jobs[unitID] then
                jobs[unitID].transportID = nil
                jobs[unitID].state = "walking"
                jobs[unitID].walkIssued = false
            end

        elseif ts.state == "reserved" then
            local unitID = ts.unitID

            if not IsValid(unitID) then
                transportState[transportID] = nil

            elseif Spring.GetUnitTransporter(unitID) == transportID then
                ts.state = "loaded"

                local job = jobs[unitID]
                local fallbackTarget = job and GetJobTarget(job) or nil
                local chainTargets = CollectConsecutiveFerryTargets(unitID, fallbackTarget)

                QueueTransportTrip(transportID, chainTargets, ts.origin)

                loadedUnits[unitID] = true
                if job then
                    job.state = "loaded"
                end
            end

        elseif ts.state == "loaded" then
            local unitID = ts.unitID

            if not IsValid(unitID) or Spring.GetUnitTransporter(unitID) ~= transportID then
                ts.state = "returning"
                jobs[unitID] = nil
                loadedUnits[unitID] = nil
            end

        elseif ts.state == "returning" then
            local x, _, z = Spring.GetUnitPosition(transportID)
            local ox, _, oz = unpack(ts.origin)

            if x and DistSq(x, z, ox, oz) < ARRIVAL_DIST_SQ and not TransportHasPassengers(transportID) then
                transportState[transportID] = nil
            end
        end
    end
end

-- ================= LOAD / UNLOAD =================

function gadget:UnitLoaded(unitID, unitDefID, teamID, transportID)
    local ts = transportState[transportID]
    if ts and ts.unitID == unitID then
        loadedUnits[unitID] = true
    end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
    loadedUnits[unitID] = nil
end

-- ================= UI =================

function gadget:UnitCreated(unitID, unitDefID)
    if ShouldHaveFerry(unitDefID) then
        Spring.InsertUnitCmdDesc(unitID, 500, {
            id = CMD_TRANSPORT_TO,
            type = CMDTYPE.ICON_MAP,
            name = "Ferry",
            action = "transport_to",
            tooltip = "Request a transport",
        })
    end
end

function gadget:UnitGiven(unitID, unitDefID)
    gadget:UnitCreated(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID)
    CancelJob(unitID)

    if transportState[unitID] then
        local ts = transportState[unitID]
        local passengerID = ts and ts.unitID
        transportState[unitID] = nil

        if passengerID and jobs[passengerID] then
            jobs[passengerID].transportID = nil
            jobs[passengerID].state = "walking"
            jobs[passengerID].walkIssued = false
        end
    end

    loadedUnits[unitID] = nil
end
