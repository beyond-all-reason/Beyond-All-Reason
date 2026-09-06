local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Attack Targets",
		desc = "Moves through a shared target list using one ordinary attack at a time",
		author = "BAR",
		date = "2026-08-26",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local CMD_ATTACK_TARGETS = GameCMD.ATTACK_TARGETS
local nonInterruptingCommands = {
	[CMD.FIRE_STATE] = true,
	[CMD.MOVE_STATE] = true,
}

if gadgetHandler:IsSyncedCode() then
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local spGetUnitCommands = Spring.GetUnitCommands
	local targetListStates = {}
	local pendingPrepends = {}

	local canAttack = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		canAttack[unitDefID] = unitDef.canAttack
	end

	local commandDescription = {
		id = CMD_ATTACK_TARGETS,
		type = CMDTYPE.ICON,
		name = "Attack Targets",
		action = "attacktargets",
		cursor = "Attack",
		tooltip = "Attack an ordered list of units",
		hidden = true,
		queueing = true,
	}

	local function clearState(unitID)
		pendingPrepends[unitID] = nil
		local state = targetListStates[unitID]
		if not state then
			return
		end
		if GG.ClearUnitTargetList then
			GG.ClearUnitTargetList(unitID, state)
		end
		targetListStates[unitID] = nil
	end

	local function isControllerReference(command, state)
		return command
			and command.id == CMD_ATTACK_TARGETS
			and #command.params == 1
			and command.params[1] == -state.referenceID
	end

	local function getControllerAttackCommands(unitID, state)
		if not state then
			return
		end
		local commands = spGetUnitCommands(unitID, -1) or {}
		if #commands < 2 or not isControllerReference(commands[#commands], state) then
			return
		end
		for index = 1, #commands - 1 do
			local command = commands[index]
			if
				not command
				or command.id ~= CMD.ATTACK
				or not command.params
				or #command.params ~= 1
				or not Spring.ValidUnitID(command.params[1])
			then
				return
			end
		end
		return commands
	end

	-- The list is authoritative; the ordinary Attack commands ahead of the
	-- controller are only its materialized execution state. Refresh that state
	-- after every explicit list change, and restart it when a prepend changes
	-- which target belongs at the front.
	local function recheckController(unitID, state, restartFromFront)
		state.targets = GG.GetUnitTargetList and GG.GetUnitTargetList(unitID)
		if not state.targets then
			return false
		end
		if restartFromFront then
			local commands = getControllerAttackCommands(unitID, state)
			if not commands then
				return false
			end
			state.nextTargetIndex = 1
			for index = 1, #commands - 1 do
				spGiveOrderToUnit(unitID, CMD.REMOVE, { commands[index].tag }, CMD.OPT_INTERNAL)
			end
		end
		return true
	end

	local function appendToActiveController(unitID, unitDefID, cmdParams)
		local state = targetListStates[unitID]
		if not state or not GG.AppendUnitTargetList then
			return false
		end

		local commands = spGetUnitCommands(unitID, -1) or {}
		if not isControllerReference(commands[#commands], state) then
			return false
		end
		local listID = GG.AppendUnitTargetList(unitID, unitDefID, cmdParams, state)
		if not listID then
			return false
		end
		state.listID = listID
		return recheckController(unitID, state, false)
	end

	local function prependToActiveController(unitID, unitDefID)
		local state = targetListStates[unitID]
		if not state or not GG.SetUnitTargetList then
			return false
		end
		local commands = getControllerAttackCommands(unitID, state)
		if not commands then
			return false
		end

		local targetIDs = {}
		local seenTargets = {}
		for index = 1, #commands - 1 do
			local queuedTargetID = commands[index].params[1]
			if not seenTargets[queuedTargetID] then
				seenTargets[queuedTargetID] = true
				targetIDs[#targetIDs + 1] = queuedTargetID
			end
		end
		for index = state.nextTargetIndex, #state.targets do
			local queuedTargetID = state.targets[index].target
			if type(queuedTargetID) == "number" and not seenTargets[queuedTargetID] then
				seenTargets[queuedTargetID] = true
				targetIDs[#targetIDs + 1] = queuedTargetID
			end
		end

		local listID = GG.SetUnitTargetList(unitID, unitDefID, targetIDs, state)
		if not listID then
			return false
		end
		state.listID = listID
		return recheckController(unitID, state, true)
	end

	local function collectAdjacentTargetCommands(unitID, cmdParams, cmdTag)
		local commands = spGetUnitCommands(unitID, -1) or {}
		local commandIndex
		for index = 1, #commands do
			if commands[index].tag == cmdTag then
				commandIndex = index
				break
			end
		end
		if not commandIndex then
			return cmdParams
		end

		local combinedTargets = {}
		local seenTargets = {}
		local function appendTargets(targetIDs)
			for index = 1, #targetIDs do
				local targetID = targetIDs[index]
				if not seenTargets[targetID] then
					seenTargets[targetID] = true
					combinedTargets[#combinedTargets + 1] = targetID
				end
			end
		end
		appendTargets(cmdParams)

		for index = commandIndex + 1, #commands do
			local command = commands[index]
			local params = command and command.params
			if
				not command
				or command.id ~= CMD_ATTACK_TARGETS
				or not command.options
				or not command.options.shift
				or not params
				or (#params == 1 and params[1] < 0)
			then
				break
			end
			appendTargets(params)
			spGiveOrderToUnit(unitID, CMD.REMOVE, { command.tag }, CMD.OPT_INTERNAL)
		end
		return combinedTargets
	end

	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		if cmdID == CMD.ATTACK then
			local targetID = #cmdParams == 1 and cmdParams[1]
			if
				cmdOptions.shift
				and not cmdOptions.internal
				and targetID
				and Spring.ValidUnitID(targetID)
				and not Spring.AreTeamsAllied(unitTeam, Spring.GetUnitTeam(targetID))
				and appendToActiveController(unitID, unitDefID, cmdParams)
			then
				return false
			end
			return true
		end
		if cmdID ~= CMD_ATTACK_TARGETS then
			return true
		end
		local isReference = #cmdParams == 1 and cmdParams[1] < 0
		if
			cmdOptions.shift
			and not cmdOptions.internal
			and not isReference
			and appendToActiveController(unitID, unitDefID, cmdParams)
		then
			return false
		end
		return canAttack[unitDefID] and cmdParams[1] ~= nil and (not isReference or cmdOptions.internal)
	end

	function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, _, cmdTag)
		if cmdID ~= CMD_ATTACK_TARGETS then
			return false
		end

		local state = targetListStates[unitID]
		local isReference = #cmdParams == 1 and cmdParams[1] < 0
		if isReference then
			local referenceID = -cmdParams[1]
			if not state or state.referenceID ~= referenceID then
				clearState(unitID)
				---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
				return true, true
			end
			state.cmdTag = cmdTag
		elseif not state or state.cmdTag ~= cmdTag then
			clearState(unitID)
			state = {
				cmdTag = cmdTag,
				nextTargetIndex = 1,
			}
			targetListStates[unitID] = state
			if not GG.SetUnitTargetList then
				clearState(unitID)
				---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
				return true, true
			end
			local targetIDs = collectAdjacentTargetCommands(unitID, cmdParams, cmdTag)
			state.listID = GG.SetUnitTargetList(unitID, unitDefID, targetIDs, state)
			if not state.listID or not recheckController(unitID, state, false) then
				clearState(unitID)
				---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
				return true, true
			end

			-- Replace the full target-ID command with a one-parameter reference.
			-- Position one is directly behind the currently executing controller;
			-- completing this command leaves the compact reference at the front.
			state.referenceID = state.listID
			spGiveOrderToUnit(
				unitID,
				CMD.INSERT,
				{ 1, CMD_ATTACK_TARGETS, CMD.OPT_INTERNAL, -state.referenceID },
				CMD.OPT_ALT
			)
			spGiveOrderToUnit(unitID, CMD.REMOVE, { cmdTag }, CMD.OPT_INTERNAL)
			---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
			return true, false
		end

		while state.nextTargetIndex <= #state.targets do
			local targetID = state.targets[state.nextTargetIndex].target
			state.nextTargetIndex = state.nextTargetIndex + 1
			local validTarget = Spring.ValidUnitID(targetID)
			local moveTypeData = validTarget and Spring.GetUnitMoveTypeData(targetID)
			if
				validTarget
				and not Spring.GetUnitIsDead(targetID)
				and (not moveTypeData or moveTypeData.aircraftState ~= "crashing")
			then
				-- The controller remains queued directly behind this attack. Marking
				-- it internal lets Set Target override weapon selection without
				-- changing the engine CommandAI movement goal.
				spGiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.ATTACK, CMD.OPT_INTERNAL, targetID }, CMD.OPT_ALT)
				---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
				return true, false
			end
		end

		clearState(unitID)
		---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
		return true, true
	end

	function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		local insertedTargetID = cmdID == CMD.INSERT
			and #cmdParams == 4
			and cmdParams[1] == 0
			and cmdParams[2] == CMD.ATTACK
			and cmdParams[3] == 0
			and cmdParams[4]
		if
			insertedTargetID
			and not cmdOptions.internal
			and Spring.ValidUnitID(insertedTargetID)
			and not Spring.AreTeamsAllied(unitTeam, Spring.GetUnitTeam(insertedTargetID))
			and getControllerAttackCommands(unitID, targetListStates[unitID])
		then
			-- Recoil exposes the embedded Attack to AllowCommand, but UnitCommand
			-- retains this outer Insert. Wait until the next sim frame, when the
			-- prepended command is visible in the queue, then fold that queue prefix
			-- back into the controller list.
			pendingPrepends[unitID] = unitDefID
		end
		if
			targetListStates[unitID]
			and not cmdOptions.shift
			and not cmdOptions.internal
			and cmdID ~= CMD_ATTACK_TARGETS
			and cmdID ~= CMD.INSERT
			and cmdID ~= CMD.REMOVE
			and not nonInterruptingCommands[cmdID]
		then
			clearState(unitID)
		end
	end

	function gadget:GameFrame()
		for unitID, unitDefID in pairs(pendingPrepends) do
			prependToActiveController(unitID, unitDefID)
			pendingPrepends[unitID] = nil
		end
	end

	function gadget:UnitDestroyed(unitID)
		clearState(unitID)
	end

	function gadget:UnitGiven(unitID)
		clearState(unitID)
	end

	function gadget:UnitTaken(unitID)
		clearState(unitID)
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if canAttack[unitDefID] then
			Spring.InsertUnitCmdDesc(unitID, commandDescription)
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_ATTACK_TARGETS)
		gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
		gadgetHandler:RegisterAllowCommand(CMD_ATTACK_TARGETS)
	end
else
	function gadget:Initialize()
		-- Set Target owns rendering for both the active target and the remainder
		-- of this list, so generic command drawing must not interpret unit IDs as
		-- XYZ coordinates.
		Spring.SetCustomCommandDrawData(CMD_ATTACK_TARGETS, nil)
	end
end
