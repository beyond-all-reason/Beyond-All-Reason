local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Pauses the game through GG.GamePause (api_game_pause.lua): the pause key
-- cannot undo it, and the pause screen does not show for it.
-- With seconds, play goes on by itself after that much real time.
local function pause(seconds)
	GG.GamePause.Pause("mission", false, seconds)
end

return {
	{
		type = 'Pause',
		parameters = {
			{ name = 'seconds', required = false, type = ParameterTypes.Quantity },
		},
		actionFunction = pause,
	}
}
