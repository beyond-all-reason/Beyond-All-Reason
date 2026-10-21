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
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			local previousUnitsInAreasAll = context.PreviousUnitsInAreas
			local previousUnitsInAreas = previousUnitsInAreasAll[triggerID]

			local unitsInArea = context.GetUnitsInArea(trigger)
			previousUnitsInAreasAll[triggerID] = unitsInArea

			if previousUnitsInAreas == nil or next(previousUnitsInAreas) == nil then
				return
			end

			local unitName = trigger.parameters.unitName
			local unitDefName = trigger.parameters.unitDefName
			local unitsLeftArea = table.filterArray(previousUnitsInAreas, function(unitID)
				if table.contains(unitsInArea, unitID) then
					return false
				end
				if unitName and not context.DoesUnitHaveName(unitID, unitName) then
					return false
				end
				if unitDefName then
					local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
					if unitDef == nil or unitDef.name ~= unitDefName then
						return false
					end
				end
				return Spring.GetUnitIsDead(unitID) == false
			end)

			for _, unitID in ipairs(unitsLeftArea) do
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
