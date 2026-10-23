local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function matchesFilters(parameters, context, unitID)
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then return false end
	if parameters.unitDefName and UnitDefs[Spring.GetUnitDefID(unitID)].name ~= parameters.unitDefName then return false end
	return true
end

return {
	type = 'UnitEnteredLocation',
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
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			local parameters = trigger.parameters
			local matchCount = 0
			for i = 1, #unitIDs do
				if matchesFilters(parameters, context, unitIDs[i]) then
					matchCount = matchCount + 1
				end
			end

			for _ = 1, matchCount do
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
