local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setTime(countdownID, seconds)
	GG['MissionAPI'].Modules.Countdowns.SetTime(countdownID, seconds)
end

return {
	{
		type = 'SetTime',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
			{ name = 'seconds', required = true, type = ParameterTypes.Quantity },
		},
		actionFunction = setTime,
	}
}
