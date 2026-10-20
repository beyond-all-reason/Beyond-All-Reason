local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'StockpileCount',
	parameters = {
		{ name = 'count',       required = true,  type = ParameterTypes.PositiveInteger },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		StockpileChanged = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
			local parameters = trigger.parameters
			if oldCount >= parameters.count or newCount < parameters.count then
				return
			end
			if parameters.teamID and parameters.teamID ~= unitTeam then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
