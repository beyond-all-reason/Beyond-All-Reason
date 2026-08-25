local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local DAMAGETYPE_RECLAIMED = Game.envDamageTypes.Reclaimed

-- Unit reclaims end in `KillUnit(builder, ..., -DAMAGE_RECLAIMED)` in both methods in the engine.
-- However, the `ReclaimUnits` action does not take this path, but goes through `KilledByLua`.

return {
	type = 'UnitReclaimed',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam,
		                         attackerID, attackerDefID, attackerTeam, weaponDefID)
			if weaponDefID ~= DAMAGETYPE_RECLAIMED then
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
			context.ActivateTrigger(trigger)
		end,
	},
}
