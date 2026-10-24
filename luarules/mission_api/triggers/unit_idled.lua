local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires when a matching unit runs out of work: Its order queue empties or all that's
-- left in the queue are "idle tasks" - non-ordered but nevertheless active commands.
-- See modules/unit_idle_states for what counts as an "idle task" or a "work task".

local ACTIVATION = true

return {
	type = 'UnitIdled',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- Synthetic callin raised once post-frame, per unit whose idle state changed.
		UnitIdlePost = function(trigger, triggerID, context, unitID, idled)
			if idled ~= ACTIVATION then
				return
			end
			-- The unit can be destroyed with prejudice between the mark and the sweep.
			local unitDefID = Spring.GetUnitDefID(unitID)
			if not unitDefID then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.teamID and parameters.teamID ~= Spring.GetUnitTeam(unitID) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
