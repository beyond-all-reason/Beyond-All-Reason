local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitDwellLocation',
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',        required = true,  type = ParameterTypes.Area },
		{ name = 'duration',    required = true,  type = ParameterTypes.Number },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			local dwellingUnitsInAreas = context.DwellingUnitsInAreas
			local unitsInArea = context.GetUnitsInArea(trigger)

			for _, unitID in pairs(unitsInArea) do
				-- If unit already dwelling in area, increase dwelling time:
				if dwellingUnitsInAreas[triggerID] and dwellingUnitsInAreas[triggerID][unitID] ~= nil and dwellingUnitsInAreas[triggerID][unitID] >= 0 then
					dwellingUnitsInAreas[triggerID][unitID] = dwellingUnitsInAreas[triggerID][unitID] + 1

					-- Check duration, and if unit still has required name:
					if dwellingUnitsInAreas[triggerID][unitID] >= trigger.parameters.duration and
						(not trigger.parameters.unitName or context.DoesUnitHaveName(unitID, trigger.parameters.unitName)) then
						local wasInvoked = context.ActivateTrigger(trigger)
						if wasInvoked then
							dwellingUnitsInAreas[triggerID][unitID] = -1 -- Prevent multiple activations for the same unit
						end
					end

				-- If unit just entered area (and hasn't already triggered), start counting:
				elseif (dwellingUnitsInAreas[triggerID] == nil or dwellingUnitsInAreas[triggerID][unitID] == nil)
					and (not trigger.parameters.unitName or context.DoesUnitHaveName(unitID, trigger.parameters.unitName))
					and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName) then
					table.ensureTable(dwellingUnitsInAreas, triggerID)
					dwellingUnitsInAreas[triggerID][unitID] = 0
				end
			end

			-- Remove units that left area:
			for unitID, _ in pairs(dwellingUnitsInAreas[triggerID] or {}) do
				if not table.contains(unitsInArea, unitID) then
					dwellingUnitsInAreas[triggerID][unitID] = nil
				end
			end
		end,
	},
}
