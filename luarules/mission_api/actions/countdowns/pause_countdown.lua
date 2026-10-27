local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function pauseCountdown(countdownID)
	GG['MissionAPI'].Modules.Countdowns.PauseCountdown(countdownID)
end

return {
	{
		type = 'PauseCountdown',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
		},
		actionFunction = pauseCountdown,
	}
}
