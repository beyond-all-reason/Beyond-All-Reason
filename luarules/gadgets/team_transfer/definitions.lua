local TeamTransfer = {}

-- Transfer reasons (authoritative enum)
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
    CARRIER_SPAWN        = 10, -- Carrier units transferring their sub-units
}

-- Reverse lookup for reason names
local reasonByValue = {}
for k, v in pairs(TeamTransfer.REASON) do
    reasonByValue[v] = k
end

-- Pure utility functions (no state)
function TeamTransfer.IsTransferReason(reason)
    return reasonByValue[reason] ~= nil
end

function TeamTransfer.GetReasonName(reason)
    return reasonByValue[reason] or "UNKNOWN"
end

function TeamTransfer.IsValidTeam(teamID)
    if teamHandler and teamHandler.IsValidTeam then
        return teamHandler.IsValidTeam(teamID)
    end
    return Spring.GetTeamInfo(teamID) ~= nil
end

return TeamTransfer
