local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local CMD_INSERT = CMD.INSERT

-- ! Has no engine event. Cannot be determined reliably through lua code. Needs resolving.

-- Production orders are received by a factory and become build orders in a factory queue.
-- For any other types of orders, unit and rally orders, see UnitOrdered and RallyOrdered.
-- For detailed notes on what this all means, see the comments at the top of unit_ordered.

return {
	type = 'ProductionOrdered',
	parameters = {
		{ name = 'buildDefName',         required = true,  type = ParameterTypes.UnitDefName },
		{ name = 'unitName',             required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',          required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',               required = false, type = ParameterTypes.TeamID },
		{ name = 'ignoreMissionActions', required = false, type = ParameterTypes.Boolean },
	},
	callins = {
		UnitCommand = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, cmdID, cmdParams)
			if not UnitDefs[unitDefID].isFactory then
				return
			end
			local orderedCommandID
			if cmdID == CMD_INSERT and cmdParams then
				orderedCommandID = cmdParams[2]
			else
				orderedCommandID = cmdID
			end
			if not orderedCommandID or orderedCommandID >= 0 then
				return
			end
			local buildDef = UnitDefs[-orderedCommandID]
			if not buildDef then
				return
			end
			if trigger.parameters.ignoreMissionActions ~= false and GG['MissionAPI'].issuingOrders then
				return
			end

			if trigger.parameters.buildDefName and trigger.parameters.buildDefName ~= buildDef.name then
				return
			end
			if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				return
			end
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.teamID and trigger.parameters.teamID ~= unitTeam then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
