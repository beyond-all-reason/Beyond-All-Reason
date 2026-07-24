local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function enableTrigger(triggerID)
	GG['MissionAPI'].Triggers[triggerID].settings.active = true
end

return {
	{
		type = 'EnableTrigger',
		parameters = {
			{
				name = 'triggerID',
				required = true,
				type = ParameterTypes.TriggerID
			}
		},
		actionFunction = enableTrigger
	}
}
