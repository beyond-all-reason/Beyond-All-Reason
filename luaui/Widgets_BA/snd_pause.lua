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

local PAUSED = 'LuaUI/sounds/pause/paused.wav'
local UNPAUSED = 'LuaUI/sounds/pause/unpaused.wav'

function widget:GamePaused(playerID, paused)
    if paused then
        Spring.PlaySoundFile(PAUSED, 1.0, 'ui')
    else
        Spring.PlaySoundFile(UNPAUSED, 1.0, 'ui')
    end
end
