-- Pauses the game through GG.GamePause (api_game_pause.lua): players
-- cannot undo the pause, and the pause screen does not show for it.
local function pause()
	GG.GamePause.Pause("mission")
end

return {
	{
		type = 'Pause',
		parameters = {},
		actionFunction = pause,
	}
}
