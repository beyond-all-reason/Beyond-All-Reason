local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitUnspotted',
	parameters = {
		{ name = 'unitName',             required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',          required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamName',       required = false, type = ParameterTypes.TeamName },
		{ name = 'spottingAllyTeamName', required = false, type = ParameterTypes.AllyTeamName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitLeftLos = function(trigger, triggerID, context, unitID, unitTeam, losAllyTeamID, unitDefID)
			local owningTeamID = trigger.parameters.owningTeamName and GG['MissionAPI'].Teams[trigger.parameters.owningTeamName]

			if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				return
			end
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if owningTeamID and unitTeam ~= owningTeamID then
				return
			end
			if trigger.parameters.spottingAllyTeamName and losAllyTeamID ~= GG['MissionAPI'].AllyTeams[trigger.parameters.spottingAllyTeamName] then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
