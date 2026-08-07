local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'ConstructionProgress',
	parameters = {
		{ name = 'teamID',      required = true,  type = ParameterTypes.TeamID },
		{ name = 'progress',    required = true,  type = ParameterTypes.Fraction },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- The trigger activation wants a build progress as a continuous quantity that crosses a threshold.
		-- 
		-- We poll this rather than allow an event-driven trigger but this could be improved with a callin
		-- from the engine. The design that follows from polling requires carefully setting the before and
		-- after states of the targeted units: ignoring preexisting units, not refiring on lost progress.
		-- 
		-- Because we need to latch against early activation, the teamID is required (a unique constraint),
		-- though this is a performance concern. This aligns with total_units_built so seemed unsurprising.
		GameFrame = function(trigger, triggerID, context)
			local parameters = trigger.parameters
			local threshold = parameters.progress
			local unitName = parameters.unitName
			local unitDefName = parameters.unitDefName

			-- Units can be "renamed" so our most (only) narrow category is `unitDefName`.
			local candidates = unitDefName
				and Spring.GetTeamUnitsByDefs(parameters.teamID, UnitDefNames[unitDefName].id)
				or Spring.GetTeamUnits(parameters.teamID)

			local constructionState = context.ConstructionState
			local previousState = constructionState[triggerID] or {}
			local currentState = {}

			local getUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

			for _, unitID in ipairs(candidates) do
				local beingBuilt, buildProgress = getUnitIsBeingBuilt(unitID)
				local previous = previousState[unitID]

				-- Handle pre-existing units and units gaining and losing unitName.
				if (beingBuilt or previous) and buildProgress then
					local state = previous or 'building'
					if state ~= 'done' and buildProgress >= threshold then
						if not unitName or context.DoesUnitHaveName(unitID, unitName) then
							context.ActivateTrigger(trigger)
						end
						state = 'done' -- Decay and reclaim must not rearm on the unit.
					end
					currentState[unitID] = state
				end
			end

			constructionState[triggerID] = currentState
		end,
	},
}
