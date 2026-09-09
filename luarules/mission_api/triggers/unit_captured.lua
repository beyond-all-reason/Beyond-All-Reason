local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Gifted units go to UnitReceived.

-- The TransferUnits action marks captures between allyTeams as gifts to comply with sharing rules.
-- The `capturingUnits` fence is checked in addition to dispatch's synthesized `captured` argument.

return {
	type = 'UnitCaptured',
	parameters = {
		{ name = 'unitName',             required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',          required = false, type = ParameterTypes.UnitDefName },
		{ name = 'oldTeamID',            required = false, type = ParameterTypes.TeamID },
		{ name = 'newTeamID',            required = false, type = ParameterTypes.TeamID },
		{ name = 'ignoreMissionActions', required = false, type = ParameterTypes.Boolean },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- This additional `captured` argument is synthesized via the dispatch:
		UnitTaken = function(trigger, triggerID, context, unitID, unitDefID, oldTeam, newTeam, captured)
			local parameters = trigger.parameters
			-- By default, mission actions are ignored, so `nil` must compare as `true`:
			if parameters.ignoreMissionActions ~= false and GG['MissionAPI'].transferringUnits then
				return
			end
			-- The mission action gifts allied units even when captured=true is passed:
			if not (captured or GG['MissionAPI'].capturingUnits) then
				return
			end
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.oldTeamID and parameters.oldTeamID ~= oldTeam then
				return
			end
			if parameters.newTeamID and parameters.newTeamID ~= newTeam then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
