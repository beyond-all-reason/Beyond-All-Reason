local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'UnitExists',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit', required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		MetaUnitAdded = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not context.IsUnitIncluded(unitID, trigger.parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
