local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'TeamDestroyed',
	kind = 'event',
	parameters = {
		{ name = 'teamID', required = true, type = ParameterTypes.Number },
	},
	callins = {
		TeamDied = function(trigger, triggerID, context, teamID)
			if teamID == trigger.parameters.teamID then
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
