local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'UnitDwellLocation',
	kind = ConditionKinds.Event,
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',        required = true,  type = ParameterTypes.Area },
		{ name = 'duration',    required = true,  type = ParameterTypes.Number },
		{ name = 'includeUnit', required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		-- Dwell time starts the frame after entering, so a duration of 0 fires on the first frame.
		GameFrame = function(trigger, triggerID, context, frameNumber)
			if trigger.triggered and not trigger.settings.repeating then
				context.DwellingUnitsInAreas[triggerID] = nil
				return
			end
			local dwellingUnits = context.DwellingUnitsInAreas[triggerID]
			if not dwellingUnits then
				return
			end

			local parameters = trigger.parameters
			for unitID, enteredFrame in pairs(dwellingUnits) do
				if enteredFrame >= 0 and frameNumber > enteredFrame and frameNumber - enteredFrame >= parameters.duration
					and context.IsUnitIncluded(unitID, parameters) then
					if context.ActivateTrigger(trigger) then
						dwellingUnits[unitID] = -1 -- Prevent multiple activations for the same unit.
					end
				end
			end
		end,
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			if trigger.triggered and not trigger.settings.repeating then
				return
			end
			local parameters = trigger.parameters
			local dwellingUnits = table.ensureTable(context.DwellingUnitsInAreas, triggerID)
			local frameNumber = Spring.GetGameFrame()
			for i = 1, #unitIDs do
				local unitID = unitIDs[i]
				if context.IsUnitIncluded(unitID, parameters) then
					dwellingUnits[unitID] = frameNumber
				end
			end
		end,
		UnitsLeftArea = function(trigger, triggerID, context, unitIDs)
			local dwellingUnits = context.DwellingUnitsInAreas[triggerID]
			if not dwellingUnits then return end

			for i = 1, #unitIDs do
				dwellingUnits[unitIDs[i]] = nil
			end
		end,
	},
}
