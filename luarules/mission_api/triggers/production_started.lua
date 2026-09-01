local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- For buildings or units placed by constructors, see ConstructionStarted.

return {
	type = 'ProductionStarted',
	parameters = {
		{ name = 'unitDefName',    required = true,  type = ParameterTypes.UnitDefName },
		{ name = 'teamName',       required = false, type = ParameterTypes.TeamName },
		{ name = 'factoryName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'factoryDefName', required = false, type = ParameterTypes.UnitDefName },
	},
	callins = {
		UnitCreated = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, builderID)
			-- Spawning in-factory and completed seems possible, so this catches any odd scenarios:
			if not builderID or not Spring.GetUnitIsBeingBuilt(unitID) then
				return
			end

			local builderDef = UnitDefs[Spring.GetUnitDefID(builderID)]
			if not builderDef.isFactory then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.teamName and GG['MissionAPI'].Teams[parameters.teamName] ~= unitTeam then
				return
			end
			if parameters.factoryName and not context.DoesUnitHaveName(builderID, parameters.factoryName) then
				return
			end
			if parameters.factoryDefName and parameters.factoryDefName ~= builderDef.name then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
