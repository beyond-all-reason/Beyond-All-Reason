local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Docking drones, hats, and attached turrets raise :UnitLoaded as well, but only transports count.
-- If a unit is force-attached to the transport, then we have no way of knowing, so this activates.

return {
	type = 'UnitLoaded',
	parameters = {
		{ name = 'unitName',         required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',      required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',           required = false, type = ParameterTypes.TeamID },
		{ name = 'transportName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'transportDefName', required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitLoaded = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, transportID, transportDefID)
			if not UnitDefs[transportDefID].isTransport then
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
