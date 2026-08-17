local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- This tracks units removed from a factory's build queue while they are in production.
-- We do not track the queue itself, so the unit must exist to be canceled: the trigger
-- fires for the item under production, and not for the items still waiting behind it.

-- Cancels of everything else, including a factory built by a construction unit, belong
-- to ConstructionCanceled. See its comments for the difficulties of general build cancels.

return {
	type = 'ProductionCanceled',
	parameters = {
		{ name = 'unitName',       required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',    required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		{ name = 'factoryName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'factoryDefName', required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not Spring.GetUnitIsBeingBuilt(unitID) then
				return
			end
			if not context.InFactory(unitID) then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.teamID and parameters.teamID ~= unitTeam then
				return
			end
			if not context.IsNanoframeOwner(unitID, parameters.factoryDefName, parameters.factoryName) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
