local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitKilled',
	parameters = {
		{ name = 'filter',      required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'exclude',     required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not context.DoesUnitMatchCondition(unitID, trigger.parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
