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

if not gadgetHandler:IsSyncedCode() then return end

local CMD_TRANSPORT_TO = 19990

local CMD_MOVE = CMD.MOVE
local CMD_LOAD_UNITS = CMD.LOAD_UNITS

local cmdDesc = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Ferry",
    action = "ferry",
    tooltip = "Transport this unit to a location",
    cursor = "Attack",
}

local jobs = {}
local transportState = {}

Spring.Echo("Transport gadget loaded")

-- ========================
-- Utility
-- ========================

local function IsValidUnit(unitID)
    return unitID and Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function IsTransport(unitID)
    local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
    return ud and ud.transportCapacity and ud.transportCapacity > 0
end

local function DistSq(x1,z1,x2,z2)
    local dx = x1-x2
    local dz = z1-z2
    return dx*dx + dz*dz
end

-- ========================
-- Transport Selection
-- ========================

local function FindClosestTransport(unitID)
    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)

    local ux,_,uz = Spring.GetUnitPosition(unitID)

    local best, bestDist = nil, math.huge

    for i=1,#units do
        local u = units[i]

        if IsTransport(u) and not transportState[u] then
            local tx,_,tz = Spring.GetUnitPosition(u)
            local d = DistSq(ux,uz,tx,tz)

            if d < bestDist then
                bestDist = d
                best = u
            end
        end
    end

    return best
end

-- ========================
-- Command Handling
-- ========================

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)

    if cmdID == CMD_TRANSPORT_TO then
        local target = {cmdParams[1], cmdParams[2], cmdParams[3]}

        jobs[unitID] = {
            target = target,
            state = "waiting",
            transportID = nil,
        }

        return false
    end

    return true
end

-- ========================
-- Lifecycle
-- ========================

function gadget:UnitCreated(unitID)
    Spring.InsertUnitCmdDesc(unitID, 500, cmdDesc)
end

function gadget:UnitDestroyed(unitID)
    jobs[unitID] = nil
    transportState[unitID] = nil
end

-- ========================
-- Main Loop
-- ========================

function gadget:GameFrame(frame)
    if frame % 10 ~= 0 then return end

    for unitID, job in pairs(jobs) do

        if not IsValidUnit(unitID) then
            jobs[unitID] = nil

        elseif job.state == "waiting" then
            local t = FindClosestTransport(unitID)

            if t then
                job.transportID = t
                job.state = "pickup"

                transportState[t] = true

                Spring.Echo("Assign", t, "->", unitID)

                Spring.GiveOrderToUnit(t, CMD_LOAD_UNITS, {unitID}, {})
            end

        elseif job.state == "pickup" then
            if Spring.GetUnitTransporter(unitID) == job.transportID then
                Spring.Echo("Picked up", unitID)

                job.state = "moving"

                local t = job.transportID

                -- 🔥 ONLY MOVE, NO UNLOAD
                Spring.GiveOrderToUnit(t, CMD_MOVE, job.target, {})
            end

        elseif job.state == "moving" then
            if not Spring.GetUnitTransporter(unitID) then
                Spring.Echo("Dropped", unitID)

                transportState[job.transportID] = nil
                jobs[unitID] = nil
            end
        end
    end
end