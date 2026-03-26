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
    local defID = Spring.GetUnitDefID(unitID)
    if not defID then return false end
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

local function ClearTransportAssignment(transportID, stopTransport)
    if not transportID then return end

    if stopTransport and IsValid(transportID) and not TransportHasPassengers(transportID) then
        GiveInternalOrder(transportID, CMD_STOP, {}, {})
    end

    transportState[transportID] = nil
end

local function FindTransport(unitID)
    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)

    local ux, _, uz = Spring.GetUnitPosition(unitID)
    if not ux then return nil end

    local best, bestDist = nil, math.huge

    for i = 1, #units do
        local u = units[i]
        local ts = transportState[u]

        -- Returning ferries are empty and reusable.
        local available = (not ts) or ts.state == "return"

        if IsTransport(u) and available then
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

local function CancelJob(unitID)
    local job = jobs[unitID]
    if not job then return end

    if job.transportID then
        local ts = transportState[job.transportID]

        if ts and ts.unitID == unitID then
            -- If the passenger cancels, stop the assigned ferry too
            -- so it does not keep flying in for pickup.
            ClearTransportAssignment(job.transportID, true)
        end
    end

    jobs[unitID] = nil
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
        transportState[unitID] = nil
    end

    return true
end

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, params, opts, tag)
    if cmdID ~= CMD_TRANSPORT_TO then
        return false, false
    end

    if not jobs[unitID] then
        local targets = ParseTargets(params)
        if #targets == 0 then
            return true, true
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
    local target = job.targets[job.index]

    if job.state == "walking" then
        local t = FindTransport(unitID)
        if t then
            local ox, oy, oz = Spring.GetUnitPosition(t)
            if not ox then
                return true, false
            end

            job.transportID = t
            job.state = "pickup"

            transportState[t] = {
                unitID = unitID,
                origin = { ox, oy, oz },
                state = "pickup",
                returnQueued = false,
            }

            GiveInternalOrder(unitID, CMD_STOP, {}, {})

            -- If this ferry was returning, break that return immediately
            -- so it can respond to the new ferry request right away.
            GiveInternalOrder(t, CMD_STOP, {}, {})
            GiveInternalOrder(t, CMD_LOAD_UNITS, { unitID }, {})

            return true, false
        end

        if not job.walkIssued then
            GiveInternalOrder(unitID, CMD_MOVE, target, {})
            job.walkIssued = true
        end

        return true, false
    end

    return true, false
end

-- ================= STATE MACHINE =================

function gadget:GameFrame(frame)
    if frame % POLL_RATE ~= 0 then
        return
    end

    for t, ts in pairs(transportState) do
        if not IsValid(t) then
            transportState[t] = nil

        elseif ts.state == "pickup" then
            local unitID = ts.unitID

            if not IsValid(unitID) then
                transportState[t] = nil

            elseif Spring.GetUnitTransporter(unitID) == t then
                ts.state = "loaded"

                local job = jobs[unitID]
                if job then
                    local target = job.targets[#job.targets]

                    -- Queue the full trip at load time:
                    -- go there, unload, go home.
                    GiveInternalOrder(t, CMD_MOVE, target, {})
                    GiveInternalOrder(t, CMD_UNLOAD_UNITS, target, { "shift" })

                    if ts.origin and not ts.returnQueued then
                        GiveInternalOrder(t, CMD_MOVE, ts.origin, { "shift" })
                        ts.returnQueued = true
                    end
                end
            end

        elseif ts.state == "loaded" then
            local unitID = ts.unitID

            if not IsValid(unitID) or Spring.GetUnitTransporter(unitID) ~= t then
                ts.state = "return"

                -- Delivery is complete once the passenger detaches.
                jobs[unitID] = nil
            end

        elseif ts.state == "return" then
            local x, _, z = Spring.GetUnitPosition(t)
            local ox, _, oz = unpack(ts.origin)

            if x and DistSq(x, z, ox, oz) < ARRIVAL_DIST_SQ and not TransportHasPassengers(t) then
                transportState[t] = nil
            end
        end
    end
end

-- ================= UI =================

function gadget:UnitCreated(unitID, unitDefID)
    if ShouldHaveFerry(unitDefID) then
        Spring.InsertUnitCmdDesc(unitID, 500, {
            id = CMD_TRANSPORT_TO,
            type = CMDTYPE.ICON_MAP,
            name = "Ferry",
            action = "ferry",
            tooltip = "Request a transport",
        })
    end
end

function gadget:UnitGiven(unitID, unitDefID)
    gadget:UnitCreated(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID)
    CancelJob(unitID)
    transportState[unitID] = nil
end