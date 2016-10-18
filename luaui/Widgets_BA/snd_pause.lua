function widget:GetInfo()
    return {
        name      = "Pause/Unpause sounds",
        desc      = "Plays a sound when a game is paused/unpaused",
        author    = "[teh]decay",
        date      = "26 oct 2015",
        license   = "public domain",
        layer     = 0,
        enabled   = false
    }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local PAUSED = LUAUI_DIRNAME .. 'sounds/pause/paused.wav'
local UNPAUSED = LUAUI_DIRNAME .. 'sounds/pause/unpaused.wav'

function widget:GamePaused(playerID, paused)
    if paused then
        Spring.PlaySoundFile(PAUSED, 1.0, 3)
    else
        Spring.PlaySoundFile(UNPAUSED, 1.0, 3)
    end
end
