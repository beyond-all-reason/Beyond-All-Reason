local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function matchesFilters(parameters, context, unitID)
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then return false end
	if parameters.unitDefName and UnitDefs[Spring.GetUnitDefID(unitID)].name ~= parameters.unitDefName then return false end
	return true
end

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
		-- Dwell time starts the frame after entering, so a duration of 0 fires on the first frame.
		GameFrame = function(trigger, triggerID, context, frameNumber)
			local dwellingUnits = context.DwellingUnitsInAreas[triggerID]
			if not dwellingUnits then
				return
			end

			local parameters = trigger.parameters
			for unitID, enteredFrame in pairs(dwellingUnits) do
				if enteredFrame >= 0 and frameNumber > enteredFrame and frameNumber - enteredFrame >= parameters.duration
					and (not parameters.unitName or context.DoesUnitHaveName(unitID, parameters.unitName)) then
					if context.ActivateTrigger(trigger) then
						dwellingUnits[unitID] = -1 -- Prevent multiple activations for the same unit.
					end
				end
			end
		end,
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			local parameters = trigger.parameters
			local dwellingUnits = table.ensureTable(context.DwellingUnitsInAreas, triggerID)
			local frameNumber = Spring.GetGameFrame()
			for i = 1, #unitIDs do
				local unitID = unitIDs[i]
				if matchesFilters(parameters, context, unitID) then
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
