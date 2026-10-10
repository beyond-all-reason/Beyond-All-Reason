local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Captures belong to UnitCaptured.

-- The TransferUnits action marks its transfers between allyTeams as captures as a lazy hack;
-- this bypasses potential modoption sharing limits but leads to the fence around the action.

return {
	type = 'UnitReceived',
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
		UnitGiven = function(trigger, triggerID, context, unitID, unitDefID, newTeam, oldTeam, captured)
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
			if isCapture then
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
