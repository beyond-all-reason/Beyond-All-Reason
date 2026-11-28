local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

-- For buildings or units placed by constructors, see ConstructionStarted.

return {
	type = 'ProductionStarted',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit',    required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit',    required = false, type = ParameterTypes.UnitFilters },
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
			if not context.IsUnitIncluded(unitID, parameters, unitDefID, unitTeam) then
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
