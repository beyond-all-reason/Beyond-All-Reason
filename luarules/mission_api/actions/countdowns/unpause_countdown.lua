local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function unpauseCountdown(countdownID)
	GG['MissionAPI'].Modules.Countdowns.UnpauseCountdown(countdownID)
end

return {
	{
		type = 'UnpauseCountdown',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
		},
		actionFunction = unpauseCountdown,
	}
}
