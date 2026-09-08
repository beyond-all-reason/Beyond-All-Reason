-- Pauses the game through GG.ScriptedPause (api_scripted_pause.lua): players
-- cannot undo the pause, and the pause screen does not show for it.
local function pause()
	GG.ScriptedPause.Pause()
end

return {
	{
		type = 'Pause',
		parameters = {},
		actionFunction = pause,
	}
}
