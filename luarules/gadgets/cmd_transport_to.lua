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
local transportState = {}
local internalOrders = {}

Spring.Echo("Transport gadget loaded")

-- ========================
-- Utility
-- ========================

local function IssueOrder(unitID, cmdID, params, opts)
    internalOrders[unitID] = (internalOrders[unitID] or 0) + 1
    Spring.GiveOrderToUnit(unitID, cmdID, params or {}, opts or 0)
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
    if not IsValidUnit(unitID) then return false end
    local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
    return ud and ud.transportCapacity and ud.transportCapacity > 0
end

local function IsIdleTransport(unitID)
    if not IsTransport(unitID) then return false end
    if transportState[unitID] then return false end

    local cmds = Spring.GetUnitCommands(unitID, 1)
    return not (cmds and #cmds > 0)
end

-- ========================
-- Transport Logic
-- ========================

local function FindClosestTransport(unitID)
    local team = Spring.GetUnitTeam(unitID)
    local units = Spring.GetTeamUnits(team)

    local ux, _, uz = Spring.GetUnitPosition(unitID)

    local bestID, bestDist = nil, math.huge

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

    Spring.Echo("Assign transport", transportID, "->", unitID)

    IssueOrder(unitID, CMD_STOP, {}, 0)
    IssueOrder(transportID, CMD_STOP, {}, 0)
    IssueOrder(transportID, CMD_LOAD_UNITS, {unitID}, 0)
end

-- ========================
-- Command Handling
-- ========================

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)

    -- Ignore our own commands
    if internalOrders[unitID] and internalOrders[unitID] > 0 then
        internalOrders[unitID] = internalOrders[unitID] - 1
        return true
    end

    -- Ferry command
    if cmdID == CMD_TRANSPORT_TO then
        local target = {cmdParams[1], cmdParams[2], cmdParams[3]}

        if jobs[unitID] and cmdOptions.shift then
            table.insert(jobs[unitID].targets, target)
        else
            jobs[unitID] = {
                targets = {target},
                state = "walking",
                transportID = nil,
                originalPos = nil,
            }

            IssueOrder(unitID, CMD_MOVE, target, 0)
        end

        return false
    end

    -- STOP cancels ferry
    if jobs[unitID] and cmdID == CMD_STOP then
        Spring.Echo("Ferry cancelled by STOP", unitID)
        jobs[unitID] = nil
        return true
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
    if frame % 15 ~= 0 then return end

    -- Return logic
    for transportID, ts in pairs(transportState) do
        if ts.state == "returning" then
            local tx, _, tz = Spring.GetUnitPosition(transportID)
            local ox, _, oz = ts.origin[1], ts.origin[2], ts.origin[3]

            if tx and tz and DistSq(tx, tz, ox, oz) < 2000 then
                Spring.Echo("Transport released", transportID)
                transportState[transportID] = nil
            end
        end
    end

    for unitID, job in pairs(jobs) do
        if not IsValidUnit(unitID) then
            jobs[unitID] = nil

        elseif job.state == "walking" then
            local transportID = FindClosestTransport(unitID)
            if transportID then
                AssignTransport(unitID, job, transportID)
            end

        elseif job.state == "assigned" then
            local transporter = Spring.GetUnitTransporter(unitID)

            if transporter == job.transportID then
                Spring.Echo("Picked up", unitID)

                job.state = "loaded"

                IssueOrder(job.transportID, CMD_STOP, {}, 0)

                for i = 1, #job.targets do
                    local pos = job.targets[i]
                    if i == 1 then
                        IssueOrder(job.transportID, CMD_MOVE, pos, 0)
                    else
                        IssueOrder(job.transportID, CMD_MOVE, pos, CMD.OPT_SHIFT)
                    end
                end

                local final = job.targets[#job.targets]
                IssueOrder(job.transportID, CMD_UNLOAD_UNITS, final, CMD.OPT_SHIFT)
            end

        elseif job.state == "loaded" then
            if not Spring.GetUnitTransporter(unitID) then
                Spring.Echo("Dropped", unitID)

                local t = job.transportID
                local origin = job.originalPos

                if IsTransport(t) then
                    transportState[t] = {
                        state = "returning",
                        origin = origin,
                    }

                    IssueOrder(t, CMD_STOP, {}, 0)
                    IssueOrder(t, CMD_MOVE, origin, 0)
                end

                jobs[unitID] = nil
            end
        end
    end
end