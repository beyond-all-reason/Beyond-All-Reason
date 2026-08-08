local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- This is very difficult to track if we mean anything outside "in-progress unit destroyed".
-- Builders can die yet construction does not "cancel" - other builders can finish the unit.
-- Builders can cancel the command, yet may resume it, or keep the command but be in a Wait.
-- The nanoframe can be captured by enemies; if in a factory, the factory keeps on building.

return {
	type = 'ConstructionCanceled',
	parameters = {
		{ name = 'unitName',       required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',    required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		{ name = 'builderName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not Spring.GetUnitIsBeingBuilt(unitID) then
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
			if not context.IsNanoframeOwner(unitID, parameters.builderDefName, parameters.builderName) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
