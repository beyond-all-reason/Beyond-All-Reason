function gadget:GetInfo()
    return {
        name    = "Transport To Command",
        desc    = "Slim synced ferry registry for widget-driven ferry flow",
        author  = "Isajoefeat",
        layer   = 0,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local CMD_TRANSPORT_TO = 19990
local CMD_MOVE         = CMD.MOVE
local CMD_STOP         = CMD.STOP

local POLL_RATE       = 10
local ARRIVAL_DIST_SQ = 64 * 64

local jobs = {}            -- passengerID -> job
local transportState = {}  -- transportID -> state
local internalOrders = {}

-- Rules params exposed on TRANSPORTS for widget use
local RP_ACTIVE      = "ferry_job_active"
local RP_PASSENGER   = "ferry_passenger_id"
local RP_TARGET_X    = "ferry_target_x"
local RP_TARGET_Y    = "ferry_target_y"
local RP_TARGET_Z    = "ferry_target_z"
local RP_RETURN_X    = "ferry_return_x"
local RP_RETURN_Y    = "ferry_return_y"
local RP_RETURN_Z    = "ferry_return_z"

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

local function DistSq(x1, z1, x2, z2)
    local dx = x1 - x2
    local dz = z1 - z2
    return dx * dx + dz * dz
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

local function SetTransportRules(transportID, passengerID, targetPos, returnPos)
    Spring.SetUnitRulesParam(transportID, RP_ACTIVE,    1, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_PASSENGER, passengerID or 0, { allied = true, inlos = true })

    Spring.SetUnitRulesParam(transportID, RP_TARGET_X, targetPos[1] or 0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_TARGET_Y, targetPos[2] or 0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_TARGET_Z, targetPos[3] or 0, { allied = true, inlos = true })

    Spring.SetUnitRulesParam(transportID, RP_RETURN_X, returnPos[1] or 0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_RETURN_Y, returnPos[2] or 0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_RETURN_Z, returnPos[3] or 0, { allied = true, inlos = true })
end

local function ClearTransportRules(transportID)
    Spring.SetUnitRulesParam(transportID, RP_ACTIVE,    0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_PASSENGER, 0, { allied = true, inlos = true })

    Spring.SetUnitRulesParam(transportID, RP_TARGET_X,  0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_TARGET_Y,  0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_TARGET_Z,  0, { allied = true, inlos = true })

    Spring.SetUnitRulesParam(transportID, RP_RETURN_X,  0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_RETURN_Y,  0, { allied = true, inlos = true })
    Spring.SetUnitRulesParam(transportID, RP_RETURN_Z,  0, { allied = true, inlos = true })
end

local function ClearTransportState(transportID)
    local ts = transportState[transportID]
    if ts then
        local passengerID = ts.passengerID
        if passengerID and jobs[passengerID] and jobs[passengerID].transportID == transportID then
            jobs[passengerID].transportID = nil
        end
    end

    transportState[transportID] = nil
    ClearTransportRules(transportID)
end

local function CancelJob(passengerID)
    local job = jobs[passengerID]
    if not job then
        return
    end

    if job.transportID then
        ClearTransportState(job.transportID)
    end

    jobs[passengerID] = nil
end

local function FindFreeTransport(passengerID)
    local teamID = Spring.GetUnitTeam(passengerID)
    local units = Spring.GetTeamUnits(teamID)
    local px, _, pz = Spring.GetUnitPosition(passengerID)

    if not px then
        return nil
    end

    local bestID = nil
    local bestDist = math.huge

    for i = 1, #units do
        local unitID = units[i]
        if IsTransport(unitID) and not transportState[unitID] then
            local tx, _, tz = Spring.GetUnitPosition(unitID)
            if tx then
                local d = DistSq(px, pz, tx, tz)
                if d < bestDist then
                    bestDist = d
                    bestID = unitID
                end
            end
        end
    end

    return bestID
end

local function ReserveTransport(passengerID, transportID, targetPos)
    if not (IsValid(passengerID) and IsValid(transportID) and targetPos) then
        return false
    end

    local ox, oy, oz = Spring.GetUnitPosition(transportID)
    if not ox then
        return false
    end

    transportState[transportID] = {
        passengerID = passengerID,
        targetPos   = { targetPos[1], targetPos[2], targetPos[3] },
        returnPos   = { ox, oy, oz },
    }

    SetTransportRules(
        transportID,
        passengerID,
        transportState[transportID].targetPos,
        transportState[transportID].returnPos
    )

    local job = jobs[passengerID]
    if job then
        job.transportID = transportID
        job.state = "assigned"
        job.walkIssued = false
    end

    return true
end

-- ================= COMMAND GATE =================

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
    if internalOrders[unitID] and internalOrders[unitID] > 0 then
        internalOrders[unitID] = internalOrders[unitID] - 1
        return true
    end

    -- Passenger gets any non-ferry external order: cancel its ferry job.
    if jobs[unitID] and cmdID ~= CMD_TRANSPORT_TO then
        CancelJob(unitID)
    end

    -- Deliberately do NOT auto-cancel on transport commands.
    -- The widget now drives transport-side order flow, so clearing here
    -- would destroy the widget/gadget split.

    return true
end

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, params, opts, tag)
    if cmdID ~= CMD_TRANSPORT_TO then
        return false, false
    end

    local job = jobs[unitID]

    if not job then
        local targets = ParseTargets(params)
        if #targets == 0 then
            return true, true
        end

        job = {
            targets     = targets,
            index       = 1,
            state       = "walking",
            transportID = nil,
            walkIssued  = false,
            complete    = false,
        }

        jobs[unitID] = job
    end

    if job.complete then
        jobs[unitID] = nil
        return true, true
    end

    local target = job.targets[job.index]
    if not target then
        jobs[unitID] = nil
        return true, true
    end

    if job.state == "walking" then
        local transportID = FindFreeTransport(unitID)
        if transportID then
            ReserveTransport(unitID, transportID, target)
            GiveInternalOrder(unitID, CMD_STOP, {}, {})
            return true, false
        end

        if not job.walkIssued then
            GiveInternalOrder(unitID, CMD_MOVE, target, {})
            job.walkIssued = true
        end

        return true, false
    end

    if job.state == "assigned" or job.state == "loaded" then
        return true, false
    end

    return true, false
end

-- ================= POLLING / CLEANUP =================

function gadget:GameFrame(frame)
    if frame % POLL_RATE ~= 0 then
        return
    end

    -- Passenger-side job updates
    for passengerID, job in pairs(jobs) do
        if not IsValid(passengerID) then
            CancelJob(passengerID)

        else
            local target = job.targets[job.index]

            if job.state == "walking" then
                if target then
                    local px, _, pz = Spring.GetUnitPosition(passengerID)
                    if px and DistSq(px, pz, target[1], target[3]) <= ARRIVAL_DIST_SQ then
                        job.complete = true
                    else
                        local transportID = FindFreeTransport(passengerID)
                        if transportID then
                            ReserveTransport(passengerID, transportID, target)
                            GiveInternalOrder(passengerID, CMD_STOP, {}, {})
                        end
                    end
                else
                    job.complete = true
                end

            elseif job.state == "assigned" then
                local transportID = job.transportID

                if not transportID or not IsValid(transportID) or not transportState[transportID] then
                    job.transportID = nil
                    job.state = "walking"
                    job.walkIssued = false
                else
                    local transporter = Spring.GetUnitTransporter(passengerID)
                    if transporter == transportID then
                        job.state = "loaded"
                    end
                end

            elseif job.state == "loaded" then
                local transporter = Spring.GetUnitTransporter(passengerID)
                if transporter == nil then
                    job.complete = true
                end
            end
        end
    end

    -- Transport-side cleanup / return completion
    for transportID, ts in pairs(transportState) do
        if not IsValid(transportID) then
            ClearTransportState(transportID)

        else
            local passengerID = ts.passengerID

            -- If passenger died before ever loading, free the transport.
            if (not IsValid(passengerID)) and (not TransportHasPassengers(transportID)) then
                ClearTransportState(transportID)

            else
                local tx, _, tz = Spring.GetUnitPosition(transportID)
                local rx, _, rz = ts.returnPos[1], ts.returnPos[2], ts.returnPos[3]

                if tx and (not TransportHasPassengers(transportID)) then
                    if DistSq(tx, tz, rx, rz) <= ARRIVAL_DIST_SQ then
                        ClearTransportState(transportID)
                    end
                end
            end
        end
    end
end

-- ================= UI =================

function gadget:UnitCreated(unitID, unitDefID)
    if ShouldHaveFerry(unitDefID) then
        Spring.InsertUnitCmdDesc(unitID, 500, {
            id      = CMD_TRANSPORT_TO,
            type    = CMDTYPE.ICON_MAP,
            name    = "Ferry",
            action  = "ferry",
            tooltip = "Request a transport",
        })
    end

    if IsTransport(unitID) then
        ClearTransportRules(unitID)
    end
end

function gadget:UnitGiven(unitID, unitDefID)
    gadget:UnitCreated(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID)
    -- If a passenger dies, cancel its job.
    if jobs[unitID] then
        CancelJob(unitID)
    end

    -- If a transport dies, free the passenger job.
    if transportState[unitID] then
        local ts = transportState[unitID]
        local passengerID = ts and ts.passengerID
        ClearTransportState(unitID)

        if passengerID and jobs[passengerID] then
            jobs[passengerID].transportID = nil
            jobs[passengerID].state = "walking"
            jobs[passengerID].walkIssued = false
        end
    end
end