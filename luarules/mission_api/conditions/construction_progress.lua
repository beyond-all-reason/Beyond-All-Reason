local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function getUnitStates(context, triggerID)
	local constructionState = context.ConstructionState
	local unitStates = constructionState[triggerID]
	if not unitStates then
		unitStates = {}
		constructionState[triggerID] = unitStates
	end
	return unitStates
end

return {
	type = 'ConstructionProgress',
	parameters = {
		{ name = 'progress',    required = true,  type = ParameterTypes.Fraction },
		{ name = 'filter',      required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'exclude',     required = false, type = ParameterTypes.UnitFilters },
	},
	callins = {
		-- Unit build steps include build, repair, and reclaim, so this sees finished units.
		UnitBuildStepPost = function(trigger, triggerID, context, unitID)
			local beingBuilt, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
			if not buildProgress then
				return
			end

			local parameters = trigger.parameters
			local filter = parameters.filter
			if filter.teamName and filter.teamName ~= Spring.GetUnitTeam(unitID) then
				return
			end
			if filter.unitDefName and not filter.unitDefName[Spring.GetUnitDefID(unitID)] then
				return
			end

			-- To handle naming/renaming/unnaming, a unit can cross the threshold only once per trigger.
			local unitStates = getUnitStates(context, triggerID)
			local state = unitStates[unitID]
			if state == 'done' then
				return
			end
			if not beingBuilt and not state then
				return
			end
			if buildProgress < parameters.progress then
				unitStates[unitID] = 'building'
				return
			end
			unitStates[unitID] = 'done'

			if not context.DoesUnitMatchCondition(unitID, parameters) then
				return
			end

			context.ActivateTrigger(trigger)
		end,

		MetaUnitRemoved = function(trigger, triggerID, context, unitID)
			local unitStates = context.ConstructionState[triggerID]
			if unitStates then
				unitStates[unitID] = nil
			end
		end,
	},
}
