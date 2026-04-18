local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name    = "Replay - Game end info",
        desc    = "Logs the info of game end in replay metadata",
        author  = "uBdead",
        date    = "February 2026",
        license = "GNU GPL, v2 or later",
        layer   = 0,
        enabled = true
    }
end

if gadgetHandler:IsSyncedCode() then
    -- SYNCED --
    return
end

-- UNSYNCED --
local data = {}

function gadget:Initialize()
end

function gadget:GameOver(winningTeams)
    data.winningTeams = winningTeams
    data.frame = Spring.GetGameFrame()
    data.duration = Spring.GetGameSeconds()
    data.dateTime = os.time() -- epoch
    
    GG.ReplayMetadata.SetReplayMetadata("gameover", data)
end
