local TeamTransfer = {}

-- Domain ownership - hooks this gadget completely controls
TeamTransfer.OWNED_HOOKS = {
    "NetShareTransfer",
    "TeamTransfer", 
    "BuilderCapture",
    "TeamGiveEverything",
    "TeamGiveEverythingComplete",
    "NetResourceTransfer",
    "take",
    "capture", 
    "give",
    "aishare"
}

TeamTransfer.REASON = {
    RECLAIMED            = 0, -- Unit wreckage reclaimed and converted to resources
    GIVEN                = 1, -- Player explicitly shares units via give command or team death
    CAPTURED             = 2, -- Builders capture enemy structures through construction
    IDLE_PLAYER_TAKEOVER = 3, -- Automatic takeover of units from idle/disconnected players
    TAKEN                = 4, -- Player uses /take command to claim units from allied AI teams
    SOLD                 = 5, -- Units sold through marketplace/trading systems
    SCAVENGED            = 6, -- Scavenger faction captures units during gameplay
    UPGRADED             = 7, -- Unit ownership changes during upgrade processes (mex/geo)
    DECORATION           = 8, -- Cosmetic transfers for visual effects (hats, etc.)
    DEV_TRANSFER         = 9, -- Development/debugging transfers
}

TeamTransfer.config = {
    allowResourceSharing = true,
    allowUnitSharing = true,
    allowEnemyResourceSharing = false,
    allowEnemyUnitSharing = false,
    allowBuilderSharing = false,
    shareDelaySeconds = 0,
    enabled = true,
}

TeamTransfer.devConfig = {
    noCostEnabled = false,
}

TeamTransfer.validators = {}
TeamTransfer.lastRefusals = {}
TeamTransfer.pendingReasonsByUnit = {}
TeamTransfer.lastReasonByUnit = {}
TeamTransfer._listeners = { given = {}, taken = {} }

local reasonByValue = {}
for k, v in pairs(TeamTransfer.REASON) do
    reasonByValue[v] = k
end

function TeamTransfer.RegisterValidator(name, validatorFunc)
    TeamTransfer.validators[name] = validatorFunc
end

function TeamTransfer.ValidateTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
    for name, validator in pairs(TeamTransfer.validators) do
        if not validator(unitID, unitDefID, oldTeam, newTeam, reason) then
            return false, name
        end
    end
    return true
end

function TeamTransfer.AddRefusal(team, msg)
    local frameNum = Spring.GetGameFrame()
    local lastRefusal = TeamTransfer.lastRefusals[team]
    if ((not lastRefusal) or (lastRefusal ~= frameNum)) then
        TeamTransfer.lastRefusals[team] = frameNum
        Spring.SendMessageToTeam(team, msg)
    end
end

function TeamTransfer.IsTransferReason(reason)
    return reasonByValue[reason] ~= nil
end

function TeamTransfer.IsValidTeam(teamID)
    if teamHandler and teamHandler.IsValidTeam then
        return teamHandler.IsValidTeam(teamID)
    end
    return Spring.GetTeamInfo(teamID) ~= nil
end

function TeamTransfer.RegisterUnitGivenListener(name, func)
    TeamTransfer._listeners.given[name] = func
end

function TeamTransfer.UnregisterUnitGivenListener(name)
    TeamTransfer._listeners.given[name] = nil
end

function TeamTransfer.RegisterUnitTakenListener(name, func)
    TeamTransfer._listeners.taken[name] = func
end

function TeamTransfer.UnregisterUnitTakenListener(name)
    TeamTransfer._listeners.taken[name] = nil
end

function TeamTransfer.GetLastTransferReason(unitID)
    local entry = TeamTransfer.lastReasonByUnit[unitID]
    if entry and entry.frame >= (Spring.GetGameFrame() - 2) then
        return entry.reason
    end
    return nil
end

function TeamTransfer.SetPendingReason(unitID, reason)
    TeamTransfer.pendingReasonsByUnit[unitID] = { reason = reason, seen = 0, frame = Spring.GetGameFrame() }
end

local function notify(listeners, unitID, unitDefID, oldTeam, newTeam, reason)
    TeamTransfer.lastReasonByUnit[unitID] = { reason = reason, frame = Spring.GetGameFrame() }
    for _, func in pairs(listeners) do
        func(unitID, unitDefID, oldTeam, newTeam, reason)
    end
end

function TeamTransfer.NotifyUnitGiven(unitID, unitDefID, oldTeam, newTeam, reason)
    notify(TeamTransfer._listeners.given, unitID, unitDefID, oldTeam, newTeam, reason)
end

function TeamTransfer.NotifyUnitTaken(unitID, unitDefID, oldTeam, newTeam, reason)
    notify(TeamTransfer._listeners.taken, unitID, unitDefID, oldTeam, newTeam, reason)
end

function TeamTransfer.ConsumePendingReason(unitID)
    local entry = TeamTransfer.pendingReasonsByUnit[unitID]
    local reason = entry and entry.reason or TeamTransfer.GetLastTransferReason(unitID)
    if entry then
        entry.seen = (entry.seen or 0) + 1
        if entry.seen >= 2 or (Spring.GetGameFrame() - (entry.frame or 0)) > 10 then
            TeamTransfer.pendingReasonsByUnit[unitID] = nil
        end
    end
    return reason
end

function TeamTransfer.GC()
    local gf = Spring.GetGameFrame()
    for unitID, entry in pairs(TeamTransfer.pendingReasonsByUnit) do
        if type(entry) == 'table' and (gf - (entry.frame or 0)) > 120 then
            TeamTransfer.pendingReasonsByUnit[unitID] = nil
        end
    end
end

return TeamTransfer