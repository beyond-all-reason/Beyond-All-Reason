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
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- Unit build steps include build, repair, and reclaim, so this sees finished units.
		UnitBuildStepPost = function(trigger, triggerID, context, unitID)
			local beingBuilt, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
			if not buildProgress then
				return
			end

			local parameters = trigger.parameters
			if parameters.teamID and parameters.teamID ~= Spring.GetUnitTeam(unitID) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[Spring.GetUnitDefID(unitID)].name then
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

			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
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
