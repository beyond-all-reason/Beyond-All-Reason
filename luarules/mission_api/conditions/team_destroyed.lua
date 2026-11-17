local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'TeamDestroyed',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'teamName', required = true, type = ParameterTypes.TeamName },
	},
	callins = {
		TeamDied = function(trigger, triggerID, context, teamID)
			if teamID == trigger.parameters.teamName then
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
