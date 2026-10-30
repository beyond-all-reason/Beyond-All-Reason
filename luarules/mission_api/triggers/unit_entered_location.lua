local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local matchingUnits = GG['MissionAPI'].Modules.UnitQuery.MatchingUnits

-- Units under construction are not waited for, since they cannot walk in.
local function areAllNamedUnitsInside(parameters, unitsInArea)
	local anyCounted = false
	for _, unitID in ipairs(matchingUnits(parameters.unitName, parameters.unitDefName, parameters.teamID)) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			if not table.contains(unitsInArea, unitID) then
				return false
			end
			anyCounted = true
		end
	end
	return anyCounted
end

return {
	type = 'UnitEnteredLocation',
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',          required = true,  type = ParameterTypes.Area },
		{ name = 'unitName',      required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',   required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',        required = false, type = ParameterTypes.TeamID },
		-- Fire once, when every unit named unitName is inside, instead of once per unit.
		-- Without teamID, a named unit that was captured or given away is still waited for.
		{ name = 'allNamedUnits', required = false, type = ParameterTypes.Boolean },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- allNamedUnits asks who is inside now, not who just entered, so it reads the area every frame.
		GameFrame = function(trigger, triggerID, context)
			local parameters = trigger.parameters
			if not parameters.allNamedUnits then
				return
			end

			local unitsInArea = GG['MissionAPI'].Modules.AreaTracking.GetUnitsInArea(parameters.area, parameters.teamID)
			local allNamedUnitsInAreas = context.AllNamedUnitsInAreas
			if not areAllNamedUnitsInside(parameters, unitsInArea) then
				allNamedUnitsInAreas[triggerID] = nil
			elseif not allNamedUnitsInAreas[triggerID] then
				-- Latch only on a fire, so a trigger that becomes active later still fires.
				allNamedUnitsInAreas[triggerID] = context.ActivateTrigger(trigger)
			end
		end,
		-- Every unit is checked before any activation, since an action may change what the next one matches.
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			local parameters = trigger.parameters
			if parameters.allNamedUnits then
				return
			end

			local matchCount = 0
			for i = 1, #unitIDs do
				if context.DoesUnitMatch(unitIDs[i], parameters.unitName, parameters.unitDefName) then
					matchCount = matchCount + 1
				end
			end

			for _ = 1, matchCount do
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
