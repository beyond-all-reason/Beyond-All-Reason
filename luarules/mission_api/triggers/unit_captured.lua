local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Gifted units go to UnitReceived. The TransferUnits action marks its transfers between
-- allyTeams as captures to bypass sharing rules, so the mission fence is checked first.

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
		-- Dispatch injects this additional `captured` argument to the callin.
		UnitTaken = function(trigger, triggerID, context, unitID, unitDefID, oldTeam, newTeam, captured)
			local parameters = trigger.parameters
			if GG['MissionAPI'].transferringUnits then
				if parameters.ignoreMissionActions ~= false or not GG['MissionAPI'].capturingUnits then
					return
				end
			elseif not captured then
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
