local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'StockpileCount',
	kind = ConditionKinds.Event,
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
