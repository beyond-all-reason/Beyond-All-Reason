-- Pauses the game through GG.GamePause (api_game_pause.lua): players
-- cannot undo the pause, and the pause screen does not show for it.
-- With seconds, play goes on by itself after that much real time.
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

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
