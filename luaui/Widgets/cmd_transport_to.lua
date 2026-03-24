function widget:GetInfo()
    return {
        name    = "Ferry Flow Helper",
        desc    = "Handles ferry pickup, dropoff, and return sequencing on the widget side",
        author  = "Isajoefeat + ChatGPT",
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

local RP_ACTIVE      = "ferry_job_active"
local RP_PASSENGER   = "ferry_passenger_id"
local RP_TARGET_X    = "ferry_target_x"
local RP_TARGET_Y    = "ferry_target_y"
local RP_TARGET_Z    = "ferry_target_z"
local RP_RETURN_X    = "ferry_return_x"
local RP_RETURN_Y    = "ferry_return_y"
local RP_RETURN_Z    = "ferry_return_z"

local POLL_RATE            = 5
local RETURN_SETTLE_FRAMES = 18
local ARRIVAL_DIST_SQ      = 64 * 64

local tracked = {}
local myTeamID = Spring.GetLocalTeamID()

local spValidUnitID           = Spring.ValidUnitID
local spGetUnitIsDead         = Spring.GetUnitIsDead
local spGetUnitTeam           = Spring.GetUnitTeam
local spGetTeamUnits          = Spring.GetTeamUnits
local spGetLocalTeamID        = Spring.GetLocalTeamID
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitTransporter    = Spring.GetUnitTransporter
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGetUnitRulesParam     = Spring.GetUnitRulesParam
local spGiveOrderToUnit       = Spring.GiveOrderToUnit

local function IsValid(unitID)
    return unitID and spValidUnitID(unitID) and not spGetUnitIsDead(unitID)
end

local function DistSq(x1, z1, x2, z2)
    local dx = x1 - x2
    local dz = z1 - z2
    return dx * dx + dz * dz
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

local function GetPosFromRules(unitID, px, py, pz)
    local x = spGetUnitRulesParam(unitID, px)
    local y = spGetUnitRulesParam(unitID, py)
    local z = spGetUnitRulesParam(unitID, pz)

    if x == nil or y == nil or z == nil then
        return nil
    end

    return { x, y, z }
end

local function GetTargetPos(transportID)
    return GetPosFromRules(transportID, RP_TARGET_X, RP_TARGET_Y, RP_TARGET_Z)
end

local function GetReturnPos(transportID)
    return GetPosFromRules(transportID, RP_RETURN_X, RP_RETURN_Y, RP_RETURN_Z)
end

local function ResetTrackingFromRules(transportID, frame)
    local passengerID = GetPassengerID(transportID)
    local targetPos = GetTargetPos(transportID)
    local returnPos = GetReturnPos(transportID)

    if not passengerID or not targetPos or not returnPos then
        return
    end

    tracked[transportID] = {
        passengerID = passengerID,
        targetPos = targetPos,
        returnPos = returnPos,
        phase = "pickup",
        pickupIssued = false,
        unloadIssued = false,
        returnReadyFrame = nil,
        returnIssued = false,
        lastSeenFrame = frame,
    }
end

local function EnsureTracked(transportID, frame)
    local state = tracked[transportID]
    local passengerID = GetPassengerID(transportID)
    local targetPos = GetTargetPos(transportID)
    local returnPos = GetReturnPos(transportID)

    if not passengerID or not targetPos or not returnPos then
        return
    end

    if not state then
        ResetTrackingFromRules(transportID, frame)
        return
    end

    state.passengerID = passengerID
    state.targetPos = targetPos
    state.returnPos = returnPos
    state.lastSeenFrame = frame
end

local function ScanMyTeamUnits(frame)
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

local function IssuePickup(transportID, state)
    local passengerID = state.passengerID
    if not IsValid(passengerID) then
        return
    end

    spGiveOrderToUnit(passengerID, CMD_STOP, {}, {})
    spGiveOrderToUnit(transportID, CMD_LOAD_UNITS, { passengerID }, {})
    state.pickupIssued = true
end

local function IssueUnload(transportID, state)
    local targetPos = state.targetPos
    if not targetPos then
        return
    end

    spGiveOrderToUnit(transportID, CMD_MOVE, targetPos, {})
    spGiveOrderToUnit(transportID, CMD_UNLOAD_UNITS, targetPos, { "shift" })
    state.unloadIssued = true
end

local function IssueReturn(transportID, state)
    local returnPos = state.returnPos
    if not returnPos then
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

    if state.phase == "pickup" then
        if IsValid(passengerID) and spGetUnitTransporter(passengerID) == transportID then
            state.phase = "loaded"
            return
        end

        if not state.pickupIssued then
            IssuePickup(transportID, state)
        end
        return
    end

    if state.phase == "loaded" then
        if IsValid(passengerID) and spGetUnitTransporter(passengerID) == transportID then
            if not state.unloadIssued then
                IssueUnload(transportID, state)
            end
            return
        end

        if not TransportHasPassengers(transportID) then
            state.phase = "return_wait"
            state.returnReadyFrame = frame + RETURN_SETTLE_FRAMES
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
            if not state.returnIssued then
                IssueReturn(transportID, state)
            end
        end
        return
    end

    if state.phase == "returning" then
        local x, _, z = spGetUnitPosition(transportID)
        local returnPos = state.returnPos

        if not x or not returnPos then
            return
        end

        if DistSq(x, z, returnPos[1], returnPos[3]) <= ARRIVAL_DIST_SQ then
            return
        end
        return
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

    ScanMyTeamUnits(frame)

    for transportID, state in pairs(tracked) do
        UpdateTransport(transportID, state, frame)
    end
end