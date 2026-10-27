local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitExists',
	parameters = {
		{ name = 'unitDefName', required = true,  type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
	},
	callins = {
		MetaUnitAdded = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
