local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local IdleStates = GG['MissionAPI'].Modules.IdleStates

-- Fires when a matching unit regains tasks: Its order queue contains a queueing command,
-- and at least one of the queueing commands are not "idle tasks" - brief automatic tasks.

-- The engine is no help to us at all. We add a new artificial callin.

-- A unit already idle cannot fall into it again. See idle_states.lua.

local FIRES_ON_BUSY = false

local function matchesUnit(parameters, context, unitID, unitDefID)
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
		return false
	end
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if parameters.teamID and parameters.teamID ~= Spring.GetUnitTeam(unitID) then
		return false
	end
	return true
end

return {
	type = 'UnitUnidled',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- Artificial callin raised once a frame, for units whose orders were touched.
		IdleUpdate = IdleStates.CreateIdleUpdate(FIRES_ON_BUSY, matchesUnit),

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			IdleStates.Forget(triggerID, unitID)
		end,
	},
}
