local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

-- Gifted units go to UnitReceived.

-- The TransferUnits action marks captures between allyTeams as gifts to comply with sharing rules.
-- The `capturingUnits` fence is checked in addition to dispatch's synthesized `captured` argument.

return {
	type = 'UnitCaptured',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit',          required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit',          required = false, type = ParameterTypes.UnitFilters },
		{ name = 'oldTeamName',          required = false, type = ParameterTypes.TeamName },
		{ name = 'newTeamName',          required = false, type = ParameterTypes.TeamName },
		{ name = 'ignoreMissionActions', required = false, type = ParameterTypes.Boolean },
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
			local isCapture = captured
			if GG['MissionAPI'].transferringUnits then
				isCapture = GG['MissionAPI'].capturingUnits
			end
			if not isCapture then
				return
			end
			if not context.IsUnitIncluded(unitID, parameters, unitDefID) then
				return
			end
			if parameters.oldTeamName and parameters.oldTeamName ~= oldTeam then
				return
			end
			if parameters.newTeamName and parameters.newTeamName ~= newTeam then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
