local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Captures belong to UnitCaptured. The TransferUnits action marks its transfers between
-- allyTeams as captures to bypass sharing rules, so the mission fence is checked first.

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
		UnitGiven = function(trigger, triggerID, context, unitID, unitDefID, newTeam, oldTeam, captured)
			local parameters = trigger.parameters
			if GG['MissionAPI'].transferringUnits then
				if parameters.ignoreMissionActions ~= false or GG['MissionAPI'].capturingUnits then
					return
				end
			elseif captured then
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
