local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'UnitLeftLocation',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'area',        required = true,  type = ParameterTypes.Area },
		{ name = 'includeUnit', required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		-- Every unit is checked before any activation, since an action may change what the next one matches.
		UnitsLeftArea = function(trigger, triggerID, context, unitIDs)
			local parameters = trigger.parameters
			local matchCount = 0
			for i = 1, #unitIDs do
				local unitID = unitIDs[i]
				if context.IsUnitIncluded(unitID, parameters) and Spring.GetUnitIsDead(unitID) == false then
					matchCount = matchCount + 1
				end
			end

			for _ = 1, matchCount do
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
