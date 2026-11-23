local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'StockpileCount',
	parameters = {
		{ name = 'count',       required = true,  type = ParameterTypes.PositiveInteger },
		{ name = 'includeUnit', required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		StockpileChanged = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
			local parameters = trigger.parameters
			if oldCount >= parameters.count or newCount < parameters.count then
				return
			end
			if not context.IsUnitIncluded(unitID, parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
