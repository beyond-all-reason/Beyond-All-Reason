local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'ConstructionFinished',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit', required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		UnitFinished = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not context.WasUnderConstruction[unitID] then
				return
			end

			local parameters = trigger.parameters
			if not context.IsUnitIncluded(unitID, parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
