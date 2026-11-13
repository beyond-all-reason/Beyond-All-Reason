local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'SquadLeftRegion',
	parameters = {
		{ name = 'regionName', required = false, type = ParameterTypes.RegionName },
		{ name = 'squadName', required = false, type = ParameterTypes.SquadName },
		{ name = 'teamName', required = false, type = ParameterTypes.TeamName },
		requiresOneOf = { 'regionName', 'squadName', 'teamName' },
	},
	callins = {
		SquadLeftRegion = function(trigger, triggerID, context, regionName, squadName, teamID)
			local parameters = trigger.parameters
			if parameters.regionName and parameters.regionName ~= regionName then
				return
			end
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
