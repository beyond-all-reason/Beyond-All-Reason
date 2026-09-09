local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Docking drones, hats, and attached turrets raise :UnitLoaded as well, but only transports count.
-- If a unit is force-attached to the transport, then we have no way of knowing, so this activates.

return {
	type = 'UnitLoaded',
	parameters = {
		{ name = 'passengerName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'passengerDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',           required = false, type = ParameterTypes.TeamID },
		{ name = 'transportName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'transportDefName', required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'passengerName', 'passengerDefName' },
	},
	callins = {
		UnitLoaded = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, transportID, transportDefID)
			if not UnitDefs[transportDefID].isTransport then
				return
			end

			local parameters = trigger.parameters
			if parameters.passengerName and not context.DoesUnitHaveName(unitID, parameters.passengerName) then
				return
			end
			if parameters.passengerDefName and parameters.passengerDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.teamID and parameters.teamID ~= unitTeam then
				return
			end
			if parameters.transportName and not context.DoesUnitHaveName(transportID, parameters.transportName) then
				return
			end
			if parameters.transportDefName and parameters.transportDefName ~= UnitDefs[transportDefID].name then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
