local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Docking drones, hats, and attached turrets raise UnitLoaded as well.
-- A transportName is checked whether it's an actual transport. A transportDefName is not.
-- A transport that dies unloads its passengers in the engine, and BAR (usually) kills them.

return {
	type = 'TransportUnloaded',
	parameters = {
		{ name = 'transportName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'transportDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',           required = false, type = ParameterTypes.TeamID },
		{ name = 'unitName',         required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',      required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'transportName', 'transportDefName' },
	},
	callins = {
		UnitUnloaded = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, transportID, transportDefID, transportTeam)
			local parameters = trigger.parameters
			if parameters.transportDefName then
				if parameters.transportDefName ~= UnitDefs[transportDefID].name then
					return
				end
			elseif not UnitDefs[transportDefID].isTransport then
				return
			end

			if parameters.transportName and not context.DoesUnitHaveName(transportID, parameters.transportName) then
				return
			end
			if parameters.teamID and parameters.teamID ~= transportTeam then
				return
			end
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
