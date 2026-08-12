local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setTimer(name)
	local timers = GG['MissionAPI'].Modules.Timers
	timers.SetTimer(name)
end

local function pauseTimer(name, paused)
	local timers = GG['MissionAPI'].Modules.Timers
	timers.PauseTimer(name, paused)
end

local function removeTimer(name)
	local timers = GG['MissionAPI'].Modules.Timers
	timers.RemoveTimer(name)
end

return {
	{
		type = 'SetTimer',
		parameters = {
			{ name = 'name', required = true, type = ParameterTypes.String },
		},
		actionFunction = setTimer,
	},
	{
		type = 'PauseTimer',
		parameters = {
			{ name = 'name', required = true, type = ParameterTypes.String },
			{ name = 'paused', required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = pauseTimer,
	},
	{
		type = 'RemoveTimer',
		parameters = {
			{ name = 'name', required = true, type = ParameterTypes.String },
		},
		actionFunction = removeTimer,
	}
}
