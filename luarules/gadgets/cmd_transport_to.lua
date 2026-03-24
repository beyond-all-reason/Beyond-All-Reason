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

local RP_ACTIVE = "ferry_return_active"
local RP_X = "ferry_return_x"
local RP_Y = "ferry_return_y"
local RP_Z = "ferry_return_z"

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

local function TransportHasPassengers(unitID)
    local carried = Spring.GetUnitIsTransporting(unitID)
    return carried and #carried > 0
end

local function SetReturnParams(transportID, origin)
    if not transportID or not origin then
        return
    end

    Spring.SetUnitRulesParam(transportID, RP_ACTIVE, 1, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_X, origin[1], { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_Y, origin[2], { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_Z, origin[3], { allied = true, inlos = true })
end

local function ClearReturnParams(transportID)
    if not transportID then
        return
    end

    Spring.SetUnitRulesParam(transportID, RP_ACTIVE, 0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_X, 0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_Y, 0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_Z, 0, { allied = true, inlos = true })
end

local function ClearTransportState(transportID)
    if not transportID then
        return
    end
    transportState[transportID] = nil
    ClearReturnParams(transportID)
end

local function CancelJob(unitID)
    local job = jobs[unitID]
    if not job then
        return
    end

    if job.transportID then
        ClearTransportState(job.transportID)
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
        ClearTransportState(unitID)
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
            }

            ClearReturnParams(t)

            GiveInternalOrder(unitID, CMD_STOP, {}, {})
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

    for transportID, ts in pairs(transportState) do
        if not IsValid(transportID) then
            ClearTransportState(transportID)

        elseif ts.state == "pickup" then
            local unitID = ts.unitID

            if not IsValid(unitID) then
                ClearTransportState(transportID)

            elseif Spring.GetUnitTransporter(unitID) == transportID then
                ts.state = "loaded"

                local job = jobs[unitID]
                if job then
                    local target = job.targets[#job.targets]
                    GiveInternalOrder(transportID, CMD_MOVE, target, {})
                    GiveInternalOrder(transportID, CMD_UNLOAD_UNITS, target, { "shift" })
                else
                    ts.state = "await_return"
                    SetReturnParams(transportID, ts.origin)
                end
            end

        elseif ts.state == "loaded" then
            local unitID = ts.unitID
            local passengerDetached = (not IsValid(unitID)) or (Spring.GetUnitTransporter(unitID) ~= transportID)

            if passengerDetached and not TransportHasPassengers(transportID) then
                ts.state = "await_return"
                SetReturnParams(transportID, ts.origin)
                jobs[unitID] = nil
            end

        elseif ts.state == "await_return" or ts.state == "returning" then
            local x, _, z = Spring.GetUnitPosition(transportID)
            local ox, _, oz = unpack(ts.origin)

            if x and DistSq(x, z, ox, oz) < ARRIVAL_DIST_SQ then
                ClearTransportState(transportID)
            else
                ts.state = "returning"
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
    ClearTransportState(unitID)
end