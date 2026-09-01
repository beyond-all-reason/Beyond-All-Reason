local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Units canceled while in production at a factory belong to `ProductionCanceled`, instead.

-- This is very difficult to track if we mean anything outside "in-progress unit destroyed";
-- nevertheless, this cancels on unit capture to match the behavior of `ProductionCanceled`.

-- Builders can die yet construction does not "cancel" - other builders can finish the unit.
-- Builders can cancel the command, yet may resume it, or keep the command but be in a Wait.

return {
	type = 'ConstructionCanceled',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamName',    required = false, type = ParameterTypes.TeamName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- Construction doesn't have the ambiguous decision-making between factory/buildee capture
		-- but we copy the behavior of ProductionCanceled anyway so that this remains unsurprising.
		MetaUnitRemoved = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not Spring.GetUnitIsBeingBuilt(unitID) or context.InFactory(unitID) then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.teamName and unitTeam ~= GG['MissionAPI'].Teams[parameters.teamName] then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
