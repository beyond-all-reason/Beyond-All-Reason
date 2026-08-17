local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitLeftLocation',
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',        required = true,  type = ParameterTypes.Area },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
		provides = { 'positionLeft' },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			local previousUnitsInAreas = context.PreviousUnitsInAreas
			local unitsInArea = context.GetUnitsInArea(trigger)

			local unitsLeftArea = table.filterArray(previousUnitsInAreas[triggerID] or {}, function(unitID)
				return not table.contains(unitsInArea, unitID)
					and (not trigger.parameters.unitName or context.DoesUnitHaveName(unitID, trigger.parameters.unitName))
					and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName)
			end)
			previousUnitsInAreas[triggerID] = unitsInArea

			for _, unitID in ipairs(unitsLeftArea) do
				local x, y, z = Spring.GetUnitBasePosition(unitID)
				context.ActivateTrigger(trigger, { positionLeft = { x = x, y = y, z = z } })
			end
		end,
	},
}
