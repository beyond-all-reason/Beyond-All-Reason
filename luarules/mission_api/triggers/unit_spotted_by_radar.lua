local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires every time a matching enemy unit moves within an allyTeam's radar coverage.
-- Also fires whenever an enemy unit enters line of sight _with no_ radar coverage.

return {
	type = 'UnitSpottedByRadar',
	parameters = {
		{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',        required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamID',       required = false, type = ParameterTypes.TeamID },
		{ name = 'spottingAllyTeamID', required = false, type = ParameterTypes.AllyTeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitEnteredRadar = function(trigger, triggerID, context, unitID, unitTeam, radarAllyTeamID, unitDefID)
			if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				return
			end
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.owningTeamID and unitTeam ~= trigger.parameters.owningTeamID then
				return
			end
			if trigger.parameters.spottingAllyTeamID and radarAllyTeamID ~= trigger.parameters.spottingAllyTeamID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
