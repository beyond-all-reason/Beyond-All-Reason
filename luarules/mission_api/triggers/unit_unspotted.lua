local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitUnspotted',
	parameters = {
		{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',        required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamID',       required = false, type = ParameterTypes.TeamID },
		{ name = 'spottingAllyTeamID', required = false, type = ParameterTypes.AllyTeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitLeftLos = function(trigger, triggerID, context, unitID, unitTeam, losAllyTeamID, unitDefID)
			if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				return
			end
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.owningTeamID and unitTeam ~= trigger.parameters.owningTeamID then
				return
			end
			if trigger.parameters.spottingAllyTeamID and losAllyTeamID ~= trigger.parameters.spottingAllyTeamID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
