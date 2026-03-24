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
    local unitDefID = Spring.GetUnitDefID(unitID)
    if not unitDefID then return false end
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

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if internalOrders[unitID] and internalOrders[unitID] > 0 then
        internalOrders[unitID] = internalOrders[unitID] - 1
        return true
    end

    if jobs[unitID] and cmdID ~= CMD_TRANSPORT_TO then
        if cmdID ~= CMD_LOAD_UNITS and cmdID ~= CMD_UNLOAD_UNITS then
            jobs[unitID] = nil
        end
    end

    if transportState[unitID] then
        if cmdID ~= CMD_LOAD_UNITS and cmdID ~= CMD_UNLOAD_UNITS then
            transportState[unitID] = nil
        end
    end

    if cmdID == CMD_TRANSPORT_TO then
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

        if #targets == 0 then
            return false
        end

        if jobs[unitID] and cmdOptions and cmdOptions.shift then
            for i = 1, #targets do
                table.insert(jobs[unitID].targets, targets[i])
            end
        else
            jobs[unitID] = {
                targets = targets,
                state = "queued",
                transportID = nil,
            }
        end

        return false
    end

    return true
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
    jobs[unitID] = nil
    transportState[unitID] = nil
    internalOrders[unitID] = nil
end

function gadget:GameFrame(frame)
    if frame % 10 ~= 0 then return end

    for unitID, job in pairs(jobs) do
        if not IsValid(unitID) then
            jobs[unitID] = nil

        elseif job.state == "queued" then
            local cmds = Spring.GetUnitCommands(unitID, 1)

            if not cmds or #cmds == 0 or cmds[1].id == CMD_STOP then
                job.state = "walking"
                GiveInternalOrder(unitID, CMD_MOVE, job.targets[1], {})
            end

        elseif job.state == "walking" then
            local t = FindTransport(unitID)

            if t then
                job.transportID = t
                job.state = "pickup"

                transportState[t] = {
                    unit = unitID,
                    origin = {Spring.GetUnitPosition(t)},
                }

                GiveInternalOrder(unitID, CMD_STOP, {}, {})
                GiveInternalOrder(t, CMD_LOAD_UNITS, {unitID}, {})
            end

        elseif job.state == "pickup" then
            if Spring.GetUnitTransporter(unitID) == job.transportID then
                job.state = "loaded"

                local t = job.transportID
                local targets = job.targets

                GiveInternalOrder(t, CMD_MOVE, targets[1], {})

                for i = 2, #targets do
                    GiveInternalOrder(t, CMD_MOVE, targets[i], {"shift"})
                end

                local final = targets[#targets]
                GiveInternalOrder(t, CMD_UNLOAD_UNITS, final, {"shift"})
            end

        elseif job.state == "loaded" then
            if not Spring.GetUnitTransporter(unitID) then
                local t = job.transportID
                local ts = transportState[t]

                if ts and ts.origin then
                    GiveInternalOrder(t, CMD_MOVE, ts.origin, {})
                end

                transportState[t] = nil
                jobs[unitID] = nil
            end
        end
    end
end