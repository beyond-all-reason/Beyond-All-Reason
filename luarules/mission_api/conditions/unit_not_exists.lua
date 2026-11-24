local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitNotExists',
	parameters = {
		{ name = 'includeUnit', required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		MetaUnitRemoved = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not context.IsUnitIncluded(unitID, trigger.parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
