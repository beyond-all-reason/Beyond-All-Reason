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

local jobs = {}
local reserved = {}

Spring.Echo("Transport gadget loaded")

function gadget:UnitCreated(unitID, unitDefID, team)
    Spring.InsertUnitCmdDesc(unitID, 500, cmdDesc)
end

local function IsValidTransport(transportID)
    if not transportID or not Spring.ValidUnitID(transportID) then
        return false
    end
    if Spring.GetUnitIsDead(transportID) then
        return false
    end

    local unitDefID = Spring.GetUnitDefID(transportID)
    local ud = unitDefID and UnitDefs[unitDefID]
    return ud and ud.transportCapacity and ud.transportCapacity > 0
end

local function FindClosestTransport(unitID)
    if not Spring.ValidUnitID(unitID) or Spring.GetUnitIsDead(unitID) then
        return nil
    end

    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)
    local ux, _, uz = Spring.GetUnitPosition(unitID)

    local bestID = nil
    local bestDist = math.huge

    for i = 1, #units do
        local u = units[i]

        if not reserved[u] and IsValidTransport(u) then
            local tx, _, tz = Spring.GetUnitPosition(u)
            if tx and tz then
                local dx = ux - tx
                local dz = uz - tz
                local dist = dx * dx + dz * dz

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
    job.state = "assigned"
    job.originalPos = {tx, ty, tz}

    reserved[transportID] = unitID

    Spring.Echo("Assigning transport", transportID, "to unit", unitID)

    Spring.GiveOrderToUnit(unitID, CMD_STOP, {}, {})
    Spring.GiveOrderToUnit(transportID, CMD_LOAD_UNITS, {unitID}, {})
end

local function ClearJob(unitID, job)
    if job and job.transportID then
        reserved[job.transportID] = nil
    end
    jobs[unitID] = nil
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID == CMD_TRANSPORT_TO then
        Spring.Echo("Ferry command received", unitID)

        jobs[unitID] = {
            target = {cmdParams[1], cmdParams[2], cmdParams[3]},
            state = "walking",
            transportID = nil,
            originalPos = nil,
        }

        -- fallback behavior: start moving immediately
        Spring.GiveOrderToUnit(unitID, CMD_MOVE, cmdParams, {})

        return false
    end

    return true
end

function gadget:UnitDestroyed(unitID)
    local job = jobs[unitID]
    if job then
        ClearJob(unitID, job)
    end

    if reserved[unitID] then
        reserved[unitID] = nil
    end
end

function gadget:GameFrame(frame)
    if frame % 15 ~= 0 then
        return
    end

    for unitID, job in pairs(jobs) do
        if not Spring.ValidUnitID(unitID) or Spring.GetUnitIsDead(unitID) then
            ClearJob(unitID, job)
        else
            -- Phase 1: walking, try to assign nearest idle transport
            if job.state == "walking" then
                local transportID = FindClosestTransport(unitID)
                if transportID then
                    AssignTransport(unitID, job, transportID)
                end
            end

            -- Phase 2: assigned, wait until loaded
            if job.state == "assigned" then
                local transporter = Spring.GetUnitTransporter(unitID)

                if transporter and transporter == job.transportID then
                    Spring.Echo("Unit picked up!", unitID)

                    job.state = "loaded"

                    local t = job.transportID
                    local target = job.target

                    Spring.GiveOrderToUnit(t, CMD_MOVE, target, {})
                    Spring.GiveOrderToUnit(t, CMD_UNLOAD_UNITS, target, {"shift"})
                elseif not IsValidTransport(job.transportID) then
                    Spring.Echo("Assigned transport became invalid, falling back to walking", unitID)

                    if job.transportID then
                        reserved[job.transportID] = nil
                    end

                    job.transportID = nil
                    job.originalPos = nil
                    job.state = "walking"

                    Spring.GiveOrderToUnit(unitID, CMD_MOVE, job.target, {})
                end
            end

            -- Phase 3: loaded, wait until unloaded
            if job.state == "loaded" then
                local transporter = Spring.GetUnitTransporter(unitID)

                if not transporter then
                    Spring.Echo("Unit unloaded!", unitID)

                    local t = job.transportID
                    local origin = job.originalPos

                    reserved[t] = nil

                    if IsValidTransport(t) and origin then
                        Spring.GiveOrderToUnit(t, CMD_MOVE, origin, {})
                    end

                    jobs[unitID] = nil
                elseif transporter ~= job.transportID then
                    -- strange edge case safety
                    reserved[job.transportID] = nil
                    jobs[unitID] = nil
                end
            end
        end
    end
end