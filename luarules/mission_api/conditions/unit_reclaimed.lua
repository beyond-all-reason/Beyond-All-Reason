local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local DAMAGETYPE_RECLAIMED     = Game.envDamageTypes.Reclaimed
local DAMAGETYPE_KILLED_BY_LUA = Game.envDamageTypes.KilledByLua

-- Unit reclaims end in `KillUnit(builder, ..., -DAMAGE_RECLAIMED)` in both methods in the engine.
-- The `ReclaimUnits` action cannot take that path: `Spring.DestroyUnit` hardcodes `KilledByLua`.

---Pending an engine action for destroying a unit with a specific weaponDefID + matching behaviors.
local function isReclaim(weaponDefID, ignoreMissionActions)
	return weaponDefID == DAMAGETYPE_RECLAIMED
		or (
			ignoreMissionActions == false
			and weaponDefID == DAMAGETYPE_KILLED_BY_LUA
			and GG["MissionAPI"].reclaimingUnits
		)
end

return {
	type = 'UnitReclaimed',
	parameters = {
		{ name = 'filter',               required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'exclude',              required = false, type = ParameterTypes.UnitFilters },
		{ name = 'ignoreMissionActions', required = false, type = ParameterTypes.Boolean },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam,
		                         attackerID, attackerDefID, attackerTeam, weaponDefID)
			local parameters = trigger.parameters
			if not isReclaim(weaponDefID, parameters.ignoreMissionActions) then
				return
			end

			if not context.DoesUnitMatchCondition(unitID, parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
