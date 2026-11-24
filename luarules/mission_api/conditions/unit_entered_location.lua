local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'UnitEnteredLocation',
	kind = ConditionKinds.Event,
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',        required = true,  type = ParameterTypes.Area },
		{ name = 'includeUnit', required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		-- Every unit is checked before any activation, since an action may change what the next one matches.
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			local parameters = trigger.parameters
			local matchCount = 0
			for i = 1, #unitIDs do
				if context.IsUnitIncluded(unitIDs[i], parameters) then
					matchCount = matchCount + 1
				end
			end

			for _ = 1, matchCount do
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
