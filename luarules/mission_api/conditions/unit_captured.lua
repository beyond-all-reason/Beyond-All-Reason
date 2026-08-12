local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitCaptured',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'oldTeamID',   required = false, type = ParameterTypes.TeamID },
		{ name = 'newTeamID',   required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitTaken = function(trigger, triggerID, context, unitID, unitDefID, oldTeam, newTeam)
			if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				return
			end
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.oldTeamID and oldTeam ~= trigger.parameters.oldTeamID then
				return
			end
			if trigger.parameters.newTeamID and newTeam ~= trigger.parameters.newTeamID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
