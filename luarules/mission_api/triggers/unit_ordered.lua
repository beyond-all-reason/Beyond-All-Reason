local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local CMD_INSERT = CMD.INSERT
local CMD_ANY    = CMD.ANY
local CMD_BUILD  = CMD.BUILD

-- Units receive commands "directly" or "inserted" into the command queue by `CMD_INSERT`.

-- Commands here use the engine commandID, including build orders, which we must convert.

-- There is a technical gap with verifying the order. :UnitCommand fires before the engine
-- passes the actual command to the unit (GiveCommandReal+AllowedCommand checks are last).
-- The semantics remain correct (the unit was so-ordered), but the command may be dropped.

local function matchesCommand(command, cmdID, cmdParams)
	return (command == CMD_ANY)
		or (command == CMD_BUILD and cmdID < 0)
		or (command == cmdID)
		or (command == CMD_INSERT and cmdParams and matchesCommand(command, cmdParams[2]))
end

return {
	type = 'UnitOrdered',
	parameters = {
		{ name = 'command',     required = true,  type = ParameterTypes.Command },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		{ name = 'fromMission', required = false, type = ParameterTypes.Boolean }, -- default := false
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitCommand = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, cmdID, cmdParams)
			if not matchesCommand(trigger.parameters.command, cmdID, cmdParams) then
				return
			end
			if trigger.parameters.fromMission ~= true and GG['MissionAPI'].issuingOrders then
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
