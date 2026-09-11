local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addCountdown(countdownID, seconds, displayed)
	GG['MissionAPI'].Modules.Countdowns.AddCountdown(countdownID, seconds, displayed)
end

return {
	{
		type = 'AddCountdown',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
			{ name = 'seconds', required = true, type = ParameterTypes.Quantity },
			{ name = 'displayed', required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = addCountdown,
	}
}
