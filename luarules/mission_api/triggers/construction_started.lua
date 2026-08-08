local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'ConstructionStarted',
	parameters = {
		{ name = 'unitDefName',    required = true,  type = ParameterTypes.UnitDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		{ name = 'builderName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
	},
	callins = {
		UnitCreated = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, builderID)
			-- Catch for spawned units and resurrected units:
			if not builderID or not Spring.GetUnitIsBeingBuilt(unitID) then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.teamID and unitTeam ~= parameters.teamID then
				return
			end
			-- The builder is known directly - unlike in ConstructionFinished and ConstructionCanceled - so we can check:
			if parameters.builderDefName and parameters.builderDefName ~= UnitDefs[Spring.GetUnitDefID(builderID)].name then
				return
			end
			if parameters.builderName and not context.DoesUnitHaveName(builderID, parameters.builderName) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
