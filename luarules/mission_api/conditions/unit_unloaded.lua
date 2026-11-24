local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

-- Undocking drones and detached turrets raise UnitUnloaded as well, so only transports count.
-- A transport that dies unloads its passengers in the engine and BAR (usually) destroys them.

return {
	type = 'UnitUnloaded',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit',      required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit',      required = false, type = ParameterTypes.UnitFilters },
		{ name = 'transportName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'transportDefName', required = false, type = ParameterTypes.UnitDefName },
	},
	callins = {
		UnitUnloaded = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, transportID, transportDefID)
			if not UnitDefs[transportDefID].isTransport then
				return
			end

			local parameters = trigger.parameters
			if not context.IsUnitIncluded(unitID, parameters, unitDefID, unitTeam) then
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
