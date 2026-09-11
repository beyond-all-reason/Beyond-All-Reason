local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local DAMAGETYPE_CRUSHED       = Game.envDamageTypes.Crushed
local DAMAGETYPE_KILLED_BY_LUA = Game.envDamageTypes.KilledByLua -- The lowest engine-defined damage type.

-- We fail to see death and selfd damages when filtering by team because their team information is lost.

local function canHaveAttacker(weaponDefID)
	return weaponDefID >= 0 or weaponDefID == DAMAGETYPE_CRUSHED or weaponDefID < DAMAGETYPE_KILLED_BY_LUA
end

return {
	type = 'UnitAttacked',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- A dead attacker passes no attacker info. We recover attackerTeam from any projectiles when we can.
		-- Death and self-destruct explosions use real weapons but have neither an attacker nor a projectile.
		UnitDamaged = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, damage, paralyzer,
		                       weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
			if damage < 0 or not canHaveAttacker(weaponDefID) then
				return
			end
			if not attackerTeam and projectileID > -1 then
				-- Best effort is fine. We aren't going to retry with the projectile's allyTeam, for example.
				attackerTeam = Spring.GetProjectileTeamID(projectileID)
			end
			if not attackerTeam or Spring.AreTeamsAllied(attackerTeam, unitTeam) then
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
