local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

local CMD_INSERT = CMD.INSERT
local CMD_ANY    = CMD.ANY
local CMD_BUILD  = CMD.BUILD

-- Rally orders are received by a factory and relayed to the units build by them.

-- RallyOrdered fires, then, when a factory receives an order it does not execute -
-- the "rally order" - which the engine relays to units when built from the factory.

-- For orders to produce units, see ProductionOrdered.
-- For state commands the factory consumes, see UnitOrdered.

local function matchesCommand(command, cmdID, cmdParams)
	return (command == CMD_ANY and cmdID)
		or (command == CMD_BUILD and cmdID < 0)
		or (cmdID == command)
		or (cmdID == CMD_INSERT and cmdParams and matchesCommand(command, cmdParams[2]))
end

local function factoryExecutes(unitID, cmdID)
	local index = cmdID and Spring.FindUnitCmdDesc(unitID, cmdID)
	return index ~= nil and Spring.GetUnitCmdDescs(unitID, index, index)[1].queueing == false
end

return {
	type = 'RallyOrdered',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'command',              required = true,  type = ParameterTypes.Command },
		{ name = 'includeUnit',          required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit',          required = false, type = ParameterTypes.UnitFilters },
		{ name = 'ignoreMissionActions', required = false, type = ParameterTypes.Boolean },
	},
	callins = {
		UnitCommand = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, cmdID, cmdParams)
			if not UnitDefs[unitDefID].isFactory then
				return
			end
			-- TODO: Validation warning on `command` that is unlikely a rally order.
			if not matchesCommand(trigger.parameters.command, cmdID, cmdParams) then
				return
			end
			-- If we're doing this anyway, fold it into matchesCommand?
			-- I guess the mission script could watch for a CMD_INSERT?
			local orderedCommandID
			if cmdID == CMD_INSERT and cmdParams then
				orderedCommandID = cmdParams[2]
			else
				orderedCommandID = cmdID
			end
			if not orderedCommandID or orderedCommandID < 0 or factoryExecutes(unitID, orderedCommandID) then
				return
			end
			if trigger.parameters.ignoreMissionActions ~= false and GG['MissionAPI'].issuingOrders then
				return
			end

			if not context.IsUnitIncluded(unitID, trigger.parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
