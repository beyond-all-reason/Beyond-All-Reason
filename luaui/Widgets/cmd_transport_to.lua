function widget:GetInfo()
    return {
        name    = "Ferry Flow Helper",
        desc    = "Handles ferry pickup, dropoff, and return sequencing on the widget side",
        author  = "Isajoefeat",
        date    = "2026",
        license = "MIT",
        layer   = 0,
        enabled = true,
    }
end

local CMD_MOVE         = CMD.MOVE
local CMD_STOP         = CMD.STOP
local CMD_LOAD_UNITS   = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS

-- Rules params expected from the gadget on the TRANSPORT
local RP_ACTIVE      = "ferry_job_active"
local RP_PASSENGER   = "ferry_passenger_id"
local RP_TARGET_X    = "ferry_target_x"
local RP_TARGET_Y    = "ferry_target_y"
local RP_TARGET_Z    = "ferry_target_z"
local RP_RETURN_X    = "ferry_return_x"
local RP_RETURN_Y    = "ferry_return_y"
local RP_RETURN_Z    = "ferry_return_z"

local POLL_RATE                = 5
local LOAD_REISSUE_FRAMES      = 30
local UNLOAD_REISSUE_FRAMES    = 45
local RETURN_SETTLE_FRAMES     = 18
local ARRIVAL_DIST_SQ          = 64 * 64
local COMMAND_MATCH_DIST_SQ    = 48 * 48
local LOAD_DIST_SQ             = 140 * 140

local tracked = {}
local myTeamID = Spring.GetLocalTeamID()

local spValidUnitID            = Spring.ValidUnitID
local spGetUnitIsDead          = Spring.GetUnitIsDead
local spGetUnitTeam            = Spring.GetUnitTeam
local spGetTeamUnits           = Spring.GetTeamUnits
local spGetLocalTeamID         = Spring.GetLocalTeamID
local spGetUnitPosition        = Spring.GetUnitPosition
local spGetUnitTransporter     = Spring.GetUnitTransporter
local spGetUnitIsTransporting  = Spring.GetUnitIsTransporting
local spGetUnitRulesParam      = Spring.GetUnitRulesParam
local spGetCommandQueue        = Spring.GetCommandQueue
local spGiveOrderToUnit        = Spring.GiveOrderToUnit

local function IsValid(unitID)
    return unitID and spValidUnitID(unitID) and not spGetUnitIsDead(unitID)
end

local function DistSq(x1, z1, x2, z2)
    local dx = x1 - x2
    local dz = z1 - z2
    return dx * dx + dz * dz
end

local function PosFromRules(unitID, px, py, pz)
    local x = spGetUnitRulesParam(unitID, px)
    local y = spGetUnitRulesParam(unitID, py)
    local z = spGetUnitRulesParam(unitID, pz)

    if x == nil or y == nil or z == nil then
        return nil
    end

    return { x, y, z }
end

local function TransportHasPassengers(unitID)
    local carried = spGetUnitIsTransporting(unitID)
    return carried and #carried > 0
end

local function IsJobActive(transportID)
    return spGetUnitRulesParam(transportID, RP_ACTIVE) == 1
end

local function GetPassengerID(transportID)
    local v = spGetUnitRulesParam(transportID, RP_PASSENGER)
    if v == nil or v == 0 then
        return nil
    end
    return math.floor(v + 0.5)
end

local function GetTargetPos(transportID)
    return PosFromRules(transportID, RP_TARGET_X, RP_TARGET_Y, RP_TARGET_Z)
end

local function GetReturnPos(transportID)
    return PosFromRules(transportID, RP_RETURN_X, RP_RETURN_Y, RP_RETURN_Z)
end

local function GetFirstCommand(unitID)
    local q = spGetCommandQueue(unitID, 1)
    if not q or not q[1] then
        return nil
    end
    return q[1]
end

local function QueueHasCommandToPos(unitID, cmdID, pos, maxCheck)
    local q = spGetCommandQueue(unitID, maxCheck or 6)
    if not q or not pos then
        return false
    end

    for i = 1, #q do
        local cmd = q[i]
        if cmd.id == cmdID and cmd.params and #cmd.params >= 3 then
            local x, z = cmd.params[1], cmd.params[3]
            if x and z and DistSq(x, z, pos[1], pos[3]) <= COMMAND_MATCH_DIST_SQ then
                return true
            end
        end
    end

    return false
end

local function QueueHasLoadForPassenger(unitID, passengerID, maxCheck)
    local q = spGetCommandQueue(unitID, maxCheck or 6)
    if not q or not passengerID then
        return false
    end

    for i = 1, #q do
        local cmd = q[i]
        if cmd.id == CMD_LOAD_UNITS and cmd.params and cmd.params[1] == passengerID then
            return true
        end
    end

    return false
end

local function QueueHasUnloadNear(unitID, pos, maxCheck)
    local q = spGetCommandQueue(unitID, maxCheck or 8)
    if not q or not pos then
        return false
    end

    for i = 1, #q do
        local cmd = q[i]
        if cmd.id == CMD_UNLOAD_UNITS and cmd.params and #cmd.params >= 3 then
            local x, z = cmd.params[1], cmd.params[3]
            if x and z and DistSq(x, z, pos[1], pos[3]) <= COMMAND_MATCH_DIST_SQ then
                return true
            end
        end
    end

    return false
end

local function EnsureTracked(transportID, frame)
    local passengerID = GetPassengerID(transportID)
    local targetPos   = GetTargetPos(transportID)
    local returnPos   = GetReturnPos(transportID)

    if not passengerID or not targetPos or not returnPos then
        return
    end

    local state = tracked[transportID]
    if not state then
        tracked[transportID] = {
            passengerID = passengerID,
            targetPos = targetPos,
            returnPos = returnPos,
            phase = "pickup",
            lastLoadIssue = -99999,
            lastUnloadIssue = -99999,
            returnReadyFrame = nil,
            returnIssued = false,
            seenFrame = frame,
        }
        return
    end

    state.passengerID = passengerID
    state.targetPos = targetPos
    state.returnPos = returnPos
    state.seenFrame = frame
end

local function IssueLoadIfNeeded(transportID, state, frame)
    local passengerID = state.passengerID
    if not IsValid(passengerID) then
        return
    end

    if spGetUnitTransporter(passengerID) == transportID then
        state.phase = "loaded"
        return
    end

    if QueueHasLoadForPassenger(transportID, passengerID, 6) then
        return
    end

    if frame - state.lastLoadIssue < LOAD_REISSUE_FRAMES then
        return
    end

    spGiveOrderToUnit(transportID, CMD_LOAD_UNITS, { passengerID }, {})
    state.lastLoadIssue = frame
end

local function IssueUnloadChainIfNeeded(transportID, state, frame)
    local targetPos = state.targetPos
    if not targetPos then
        return
    end

    if QueueHasUnloadNear(transportID, targetPos, 8) and QueueHasCommandToPos(transportID, CMD_MOVE, targetPos, 8) then
        return
    end

    if frame - state.lastUnloadIssue < UNLOAD_REISSUE_FRAMES then
        return
    end

    -- Clear out weird leftovers gently, then rebuild the intended sequence once.
    spGiveOrderToUnit(transportID, CMD_STOP, {}, {})
    spGiveOrderToUnit(transportID, CMD_MOVE, targetPos, {})
    spGiveOrderToUnit(transportID, CMD_UNLOAD_UNITS, targetPos, { "shift" })

    state.lastUnloadIssue = frame
end

local function MaybeAdvanceLoadedPhase(transportID, state, frame)
    local passengerID = state.passengerID

    if not IsValid(passengerID) then
        -- Passenger no longer valid. Treat as done and return ferry home if empty.
        if not TransportHasPassengers(transportID) then
            state.phase = "return_wait"
            state.returnReadyFrame = frame + RETURN_SETTLE_FRAMES
        end
        return
    end

    if spGetUnitTransporter(passengerID) == transportID then
        state.phase = "loaded"
        return
    end

    -- Passenger has detached
    if not TransportHasPassengers(transportID) then
        state.phase = "return_wait"
        state.returnReadyFrame = frame + RETURN_SETTLE_FRAMES
    end
end

local function IssueReturnIfNeeded(transportID, state)
    local returnPos = state.returnPos
    if not returnPos then
        return
    end

    if QueueHasCommandToPos(transportID, CMD_MOVE, returnPos, 6) then
        state.returnIssued = true
        state.phase = "returning"
        return
    end

    spGiveOrderToUnit(transportID, CMD_MOVE, returnPos, {})
    state.returnIssued = true
    state.phase = "returning"
end

local function UpdateTransport(transportID, state, frame)
    if not IsValid(transportID) then
        tracked[transportID] = nil
        return
    end

    if spGetUnitTeam(transportID) ~= myTeamID then
        tracked[transportID] = nil
        return
    end

    if not IsJobActive(transportID) then
        tracked[transportID] = nil
        return
    end

    local passengerID = state.passengerID
    local returnPos = state.returnPos
    local tx, _, tz = spGetUnitPosition(transportID)

    if not tx then
        return
    end

    if state.phase == "pickup" then
        if IsValid(passengerID) and spGetUnitTransporter(passengerID) == transportID then
            state.phase = "loaded"
        else
            IssueLoadIfNeeded(transportID, state, frame)
        end
        return
    end

    if state.phase == "loaded" then
        if IsValid(passengerID) and spGetUnitTransporter(passengerID) == transportID then
            IssueUnloadChainIfNeeded(transportID, state, frame)
        else
            MaybeAdvanceLoadedPhase(transportID, state, frame)
        end
        return
    end

    if state.phase == "return_wait" then
        if TransportHasPassengers(transportID) then
            state.phase = "loaded"
            state.returnReadyFrame = nil
            state.returnIssued = false
            return
        end

        if frame >= (state.returnReadyFrame or 0) then
            IssueReturnIfNeeded(transportID, state)
        end
        return
    end

    if state.phase == "returning" then
        if returnPos and DistSq(tx, tz, returnPos[1], returnPos[3]) <= ARRIVAL_DIST_SQ then
            -- Do nothing else here. Gadget should clear synced job state when it sees arrival.
            return
        end

        if not state.returnIssued and returnPos then
            IssueReturnIfNeeded(transportID, state)
        end
        return
    end
end

local function ScanMyTeamTransports(frame)
    local units = spGetTeamUnits(myTeamID)
    if not units then
        return
    end

    for i = 1, #units do
        local unitID = units[i]
        if IsJobActive(unitID) then
            EnsureTracked(unitID, frame)
        end
    end
end

function widget:Initialize()
    myTeamID = spGetLocalTeamID()
end

function widget:PlayerChanged(playerID)
    myTeamID = spGetLocalTeamID()
    tracked = {}
end

function widget:UnitDestroyed(unitID)
    tracked[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
    if newTeam == myTeamID or oldTeam == myTeamID then
        tracked[unitID] = nil
    end
end

function widget:GameFrame(frame)
    if frame % POLL_RATE ~= 0 then
        return
    end

    ScanMyTeamTransports(frame)

    for transportID, state in pairs(tracked) do
        UpdateTransport(transportID, state, frame)
    end
end