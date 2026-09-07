local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'TeamDestroyed',
	parameters = {
		{ name = 'teamName', required = true, type = ParameterTypes.TeamName },
	},
	callins = {
		TeamDied = function(trigger, triggerID, context, teamID)
			if teamID == trigger.parameters.teamID then
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
