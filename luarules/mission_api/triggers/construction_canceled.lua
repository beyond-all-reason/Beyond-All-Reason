local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- This is very difficult to track if we mean anything outside "in-progress unit destroyed":
-- Builders can die yet construction does not "cancel" - other builders can finish the unit.
-- Builders can cancel the command, yet may resume it, or keep the command but be in a Wait.
-- The nanoframe can be captured by enemies; if in a factory, the factory keeps on building.

-- Units canceled while in production at a factory belong to `ProductionCanceled`, instead.

local function matchesUnit(trigger, context, unitID, unitDefID, unitTeam)
	local parameters = trigger.parameters
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
		return
	end
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	-- TODO: Need to decide when allyTeam is acceptable to check vs teamID:
	if parameters.teamID and not Spring.AreTeamsAllied(parameters.teamID, unitTeam) then
		return
	end
	if not context.isBuildFrameOwner(unitID, parameters.builderDefName, parameters.builderName) then
		return
	end
end

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
			if not Spring.GetUnitIsBeingBuilt(unitID) or context.InFactory(unitID) then
				return
			end

			if matchesUnit(trigger, context, unitID, unitDefID, unitTeam) then
				context.ActivateTrigger(trigger)
			end
		end,

		-- Construction doesn't have the ambiguous decision-making between factory/buildee capture
		-- but we copy the behavior of ProductionCanceled anyway so that this remains unsurprising.
		UnitTaken = function(trigger, triggerID, context, unitID, unitDefID, oldTeam, newTeam)
			if Spring.AreTeamsAllied(oldTeam, newTeam) then
				return
			end
			if not Spring.GetUnitIsBeingBuilt(unitID) or context.InFactory(unitID) then
				return
			end

			if matchesUnit(trigger, context, unitID, unitDefID, oldTeam) then
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
