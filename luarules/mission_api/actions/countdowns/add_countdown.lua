local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addCountdown(countdownID, seconds)
	GG['MissionAPI'].Modules.Countdowns.AddCountdown(countdownID, seconds)
end

return {
	{
		type = 'AddCountdown',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
			{ name = 'seconds', required = true, type = ParameterTypes.Quantity },
		},
		actionFunction = addCountdown,
	}
}
