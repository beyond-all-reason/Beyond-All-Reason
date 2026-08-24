local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'ConstructionFinished',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamName',    required = false, type = ParameterTypes.TeamName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitFinished = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not context.WasUnderConstruction[unitID] then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.teamName and unitTeam ~= GG['MissionAPI'].Teams[trigger.parameters.teamName] then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
