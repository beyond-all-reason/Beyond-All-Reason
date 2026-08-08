local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'ConstructionFinished',
	parameters = {
		{ name = 'unitName',       required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',    required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitFinished = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not context.WasUnderConstruction(unitID) then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			-- We likely must guard against unusual cases like in-progress capture by enemy teams.
			-- When a factory is captured while building, instead, it calls StopBuild immediately.
			if parameters.teamID and not parameters.teamID ~= unitTeam then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
