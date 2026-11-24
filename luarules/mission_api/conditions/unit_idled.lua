local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

-- Fires when a matching unit runs out of work: Its order queue empties or all that's
-- left in the queue are "idle tasks" - non-ordered but nevertheless active commands.
-- See modules/unit_idle_states for what counts as an "idle task" or a "work task".

local ACTIVATION = true

return {
	type = 'UnitIdled',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit', required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
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
			if not context.IsUnitIncluded(unitID, parameters, unitDefID) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
