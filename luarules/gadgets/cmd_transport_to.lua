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

-- 🔴 SYNCED ONLY
if not gadgetHandler:IsSyncedCode() then
    return
end

-- 🔧 Command IDs
local CMD_TRANSPORT_TO = 19990

-- 🔧 Engine command constants
local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS

-- 🔧 Command Description
local cmdDesc = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Ferry",
    action = "ferry",
    tooltip = "Transport this unit to a location",
    cursor = "Attack",
    params = {},
}

-- 🔧 Data
local jobs = {}
local reserved = {}

-- ✅ Debug
Spring.Echo("Transport gadget loaded")

-- ✅ Add command to all units (we refine later)
function gadget:UnitCreated(unitID, unitDefID, team)
    Spring.InsertUnitCmdDesc(unitID, 500, cmdDesc)
end

-- ✅ Handle command
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID == CMD_TRANSPORT_TO then
        Spring.Echo("Ferry command received", unitID)

        jobs[unitID] = {
            target = {cmdParams[1], cmdParams[2], cmdParams[3]},
            state = "walking",
            transportID = nil
        }

        -- start walking immediately
        Spring.GiveOrderToUnit(unitID, CMD_MOVE, cmdParams, {})

        return false
    end
    return true
end

-- 🔍 Find closest available transport
function FindClosestTransport(unitID)
    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)

    local ux, _, uz = Spring.GetUnitPosition(unitID)

    local bestID = nil
    local bestDist = math.huge

    for i = 1, #units do
        local u = units[i]

        if Spring.GetUnitIsTransport(u) and not reserved[u] then
            local tx, _, tz = Spring.GetUnitPosition(u)
            local dist = (ux - tx)^2 + (uz - tz)^2

            if dist < bestDist then
                bestDist = dist
                bestID = u
            end
        end
    end

    return bestID
end

-- 🚛 Assign transport
function AssignTransport(unitID, job, transportID)
    job.transportID = transportID
    job.state = "assigned"

    reserved[transportID] = unitID

    Spring.Echo("Assigning transport", transportID, "to unit", unitID)

    -- stop unit so it waits
    Spring.GiveOrderToUnit(unitID, CMD_STOP, {}, {})

    -- tell transport to pick it up
    Spring.GiveOrderToUnit(transportID, CMD_LOAD_UNITS, {unitID}, {})
end

-- 🔄 Main loop
function gadget:GameFrame(frame)
    if frame % 15 ~= 0 then return end

    for unitID, job in pairs(jobs) do

        -- 🔹 Try to assign transport
        if job.state == "walking" then
            local transportID = FindClosestTransport(unitID)

            if transportID then
                AssignTransport(unitID, job, transportID)
            end
        end

        -- 🔹 Check if picked up
        if job.state == "assigned" then
            if Spring.GetUnitTransporter(unitID) then
                Spring.Echo("Unit picked up!", unitID)

                job.state = "loaded"

                local t = job.transportID
                local target = job.target

                Spring.GiveOrderToUnit(t, CMD_MOVE, target, {"shift"})
                Spring.GiveOrderToUnit(t, CMD_UNLOAD_UNITS, target, {"shift"})
            end
        end

    end
end