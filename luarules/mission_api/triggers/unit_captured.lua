local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitCaptured',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'oldTeamName', required = false, type = ParameterTypes.TeamName },
		{ name = 'newTeamName', required = false, type = ParameterTypes.TeamName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitTaken = function(trigger, triggerID, context, unitID, unitDefID, oldTeam, newTeam)
			local oldTeamID = trigger.parameters.oldTeamName and GG['MissionAPI'].Teams[trigger.parameters.oldTeamName]
			local newTeamID = trigger.parameters.newTeamName and GG['MissionAPI'].Teams[trigger.parameters.newTeamName]

			if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				return
			end
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if oldTeamID and oldTeam ~= oldTeamID then
				return
			end
			if newTeamID and newTeam ~= newTeamID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
