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
		-- Every unit is checked before any activation, since an action may change what the next one matches.
		UnitsLeftArea = function(trigger, triggerID, context, unitIDs)
			local parameters = trigger.parameters
			local matchCount = 0
			for i = 1, #unitIDs do
				if context.DoesUnitMatch(unitID, parameters.unitName, parameters.unitDefName) and Spring.GetUnitIsDead(unitID) == false then
					matchCount = matchCount + 1
				end
			end

			for _ = 1, matchCount do
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
