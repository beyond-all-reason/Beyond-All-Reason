local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local CMD_INSERT = CMD.INSERT
local CMD_ANY    = CMD.ANY
local CMD_BUILD  = CMD.BUILD

-- Units receive commands "directly" or "inserted" into the command queue by `CMD_INSERT`.

-- Some commands like `CMD.STOCKPILE` are consumed within :AllowCommand. We never see them.
-- A comprehensive list is in validation.lua, and beyond-all-reason/Beyond-All-Reason#8663.

-- In-game, the allow-consume and notify-consume patterns both trip units' "cantdo" sounds.
-- Players can experience an objective completion as a task-failed-successfully unit noise.

-- There is a technical gap with verifying the order. :UnitCommand fires before the engine
-- passes the actual command to the unit (GiveCommandReal+AllowedCommand checks are last).
-- The semantics remain correct (the unit was so-ordered), but the command may be dropped.

-- Final note on this hodgepodge: Factory build queues never satisfy the current trigger.
-- Factories-as-units still execute _some_ orders so we cannot filter them entirely here.
-- For their other behaviors, produce and rally, see ProductionOrdered and RallyOrdered.

-- Commands here use the engine commandID, including build orders, which we must convert,
-- or are matched against one of the Command qualifiers: "AnyCommand" or "AnyUnitDef".
local function matchesCommand(command, cmdID, cmdParams)
	return (command == CMD_ANY and cmdID)
		or (command == CMD_BUILD and cmdID < 0)
		or (cmdID == command)
		or (cmdID == CMD_INSERT and cmdParams and matchesCommand(command, cmdParams[2]))
end

-- A factory runs only its non-queueing commands. Build and rally orders it
-- queues or relays, so those belong to ProductionOrdered and RallyOrdered.
local function factoryLikelyExecutes(unitID, cmdID)
	local index = cmdID and Spring.FindUnitCmdDesc(unitID, cmdID)
	return index ~= nil and Spring.GetUnitCmdDescs(unitID, index, index)[1].queueing == false
end

return {
	type = 'UnitOrdered',
	parameters = {
		{ name = 'command',     required = true,  type = ParameterTypes.Command },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamName',    required = false, type = ParameterTypes.TeamName },
		{ name = 'fromMission', required = false, type = ParameterTypes.Boolean },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- The trigger wants an incoming order that is likely to be executed by the recipient unit.
		--
		-- What we get instead is a post-processing, pre-execution event indicating a sent command.
		-- The gaps are described at length above. In particular, we perfectly miss factory queues:
		--
		-- Missing normal orders is okay; these are "unlikely to be executed by the recipient unit".
		-- For orders that go to the factory queue specifically, though, we need a separate trigger.
		UnitCommand = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, cmdID, cmdParams)
			if not matchesCommand(trigger.parameters.command, cmdID, cmdParams) then
				return
			end
			if UnitDefs[unitDefID].isFactory then
				if cmdID == CMD_INSERT and cmdParams then
					cmdID = cmdParams[2]
				end
				if not factoryLikelyExecutes(unitID, cmdID) then
					return
				end
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
			if trigger.parameters.teamName and GG['MissionAPI'].Teams[trigger.parameters.teamName] ~= unitTeam then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
