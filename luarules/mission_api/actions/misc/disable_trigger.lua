local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function disableTrigger(triggerID)
	GG['MissionAPI'].Triggers[triggerID].settings.active = false
end

return {
	{
		type = 'DisableTrigger',
		parameters = {
			{ name = 'triggerID', required = true, type = ParameterTypes.TriggerID },
		},
		actionFunction = disableTrigger,
	}
}
