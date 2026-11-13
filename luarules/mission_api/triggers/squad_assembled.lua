local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'SquadAssembled',
	parameters = {
		{ name = 'squadName', required = false, type = ParameterTypes.SquadName },
		{ name = 'teamName', required = false, type = ParameterTypes.TeamName },
		requiresOneOf = { 'squadName', 'teamName' },
	},
	callins = {
		SquadAssembled = function(trigger, triggerID, context, squadName, teamID)
			local parameters = trigger.parameters
			if parameters.squadName and parameters.squadName ~= squadName then
				return
			end
			if parameters.teamName and parameters.teamName ~= teamID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
