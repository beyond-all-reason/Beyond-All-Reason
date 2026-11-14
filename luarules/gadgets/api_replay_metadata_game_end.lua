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
    if not os then
        Spring.Echo("[ReplayMetadata]",  "os library is not (yet) available, won't log game end time")
        -- remove the gadget since it won't be able to save anything
        gadgetHandler:RemoveGadget(self)
        return
    end
end

function gadget:GameOver(winningTeams)
    data.winningTeams = winningTeams
    data.frame = Spring.GetGameFrame()
    data.duration = Spring.GetGameSeconds()
    data.dateTime = os.time() -- epoch
    
    GG.ReplayMetadata.SetReplayMetadata("gameover", data)
end
