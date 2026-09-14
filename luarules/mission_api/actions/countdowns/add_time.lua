local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addTime(countdownID, seconds)
	GG['MissionAPI'].Modules.Countdowns.AddTime(countdownID, seconds)
end

return {
	{
		type = 'AddTime',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
			{ name = 'seconds', required = true, type = ParameterTypes.Quantity },
		},
		actionFunction = addTime,
	}
}
