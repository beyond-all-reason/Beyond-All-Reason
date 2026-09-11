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
	-- Set while the controller inserts its own Attack so the command callins can
	-- tell it apart from a player's prepended Attack.
	local issuingControllerAttack = false
	-- Units whose first target-list command is being rewritten into a reference.
	-- Inserting the reference triggers a nested CommandFallback for the original
	-- command; that call must not issue anything.
	local rewritingQueue = {}

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

	-- A native queued Attack disappears when its target is deleted (death
	-- dependence). A crashing aircraft is no longer an available target either:
	-- weapons refuse it (fireAtCrashing) and the engine finishes an Attack on it
	-- once it notices (RecoilEngine PR: skip it when the order starts). Skip both
	-- when handing out the next target.
	local function isAttackableTarget(targetID)
		if not Spring.ValidUnitID(targetID) or Spring.GetUnitIsDead(targetID) then
			return false
		end
		local moveTypeData = Spring.GetUnitMoveTypeData(targetID)
		return not moveTypeData or moveTypeData.aircraftState ~= "crashing"
	end

	local function lastAttackableIndex(targets)
		for index = #targets, 1, -1 do
			if isAttackableTarget(targets[index].target) then
				return index
			end
		end
		return 0
	end

	local function clearState(unitID)
		pendingPrepends[unitID] = nil
		rewritingQueue[unitID] = nil
		local state = targetListStates[unitID]
		if not state then
			return
		end
		if GG.ClearUnitAttackTargetList then
			GG.ClearUnitAttackTargetList(unitID, state)
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
		local targets = GG.GetUnitAttackTargetList and GG.GetUnitAttackTargetList(unitID)
		if targets and state.targets and targets ~= state.targets and not restartFromFront then
			local remaining = {}
			for index = state.nextTargetIndex, #state.targets do
				remaining[state.targets[index].target] = true
			end
			state.nextTargetIndex = #targets + 1
			for index, entry in ipairs(targets) do
				if remaining[entry.target] then
					state.nextTargetIndex = index
					break
				end
			end
		end
		state.targets = targets
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
		if not state or not GG.AppendUnitAttackTargetList then
			return false
		end

		local commands = spGetUnitCommands(unitID, -1) or {}
		if not isControllerReference(commands[#commands], state) then
			return false
		end
		if not recheckController(unitID, state, false) then
			return false
		end
		local listID = GG.AppendUnitAttackTargetList(unitID, unitDefID, cmdParams, state)
		if not listID then
			return false
		end
		state.listID = listID
		state.targets = GG.GetUnitAttackTargetList(unitID)
		return state.targets ~= nil
	end

	local function prependToActiveController(unitID, unitDefID)
		local state = targetListStates[unitID]
		if not state or not GG.SetUnitAttackTargetList then
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

		local listID = GG.SetUnitAttackTargetList(unitID, unitDefID, targetIDs, state)
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

	-- ExecuteInsert does not register a death dependence for the inserted Attack,
	-- unlike commands given the normal way. Without it the engine only notices
	-- the target's death on the unit's next SlowUpdate, up to 16 frames later,
	-- whereas a native queued Attack is removed the moment its target is
	-- deleted. Give and immediately remove a throwaway object command on the
	-- same target: the dependence outlives the removed command and covers every
	-- queued command that references the target.
	local dependencyCommands = { CMD.FIGHT, CMD.GUARD }
	local function registerTargetDependency(unitID, targetID)
		local before = Spring.GetUnitCommandCount(unitID) or 0
		for index = 1, #dependencyCommands do
			local cmdID = dependencyCommands[index]
			spGiveOrderToUnit(unitID, cmdID, { targetID }, CMD.OPT_SHIFT)
			if (Spring.GetUnitCommandCount(unitID) or 0) > before then
				local queue = spGetUnitCommands(unitID, -1) or {}
				local last = queue[#queue]
				if last and last.id == cmdID and #last.params == 1 and last.params[1] == targetID then
					spGiveOrderToUnit(unitID, CMD.REMOVE, { last.tag }, CMD.OPT_INTERNAL)
				end
				return
			end
		end
	end

	-- Insert one ordinary Attack for the next attackable target. Returns false
	-- when the list is exhausted. When nothing remains after the issued target,
	-- the reference is removed right away: a native queue would then hold only
	-- this Attack, and ground units brake for their goal only when at most one
	-- command is queued.
	local function issueNextTarget(unitID, state, referenceTag)
		while state.nextTargetIndex <= #state.targets do
			local targetID = state.targets[state.nextTargetIndex].target
			state.nextTargetIndex = state.nextTargetIndex + 1
			if isAttackableTarget(targetID) then
				-- The controller remains queued directly behind this attack. The engine
				-- chooses movement and weapon targets; the stored list only supplies
				-- the next Attack when this one finishes. The Attack carries no
				-- INTERNAL flag: the engine treats internal attacks as automatic
				-- targets (weapons may swap them and Set Target overrides them),
				-- which is not how a player's queued Attack behaves.
				local queueLength = Spring.GetUnitCommandCount(unitID) or 0
				issuingControllerAttack = true
				spGiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.ATTACK, 0, targetID }, CMD.OPT_ALT)
				issuingControllerAttack = false
				if targetListStates[unitID] ~= state then
					-- The Attack ended in the same call and a nested CommandFallback
					-- already moved on or removed the controller.
					return true
				end
				if (Spring.GetUnitCommandCount(unitID) or 0) > queueLength then
					registerTargetDependency(unitID, targetID)
					if state.nextTargetIndex > lastAttackableIndex(state.targets) then
						spGiveOrderToUnit(unitID, CMD.REMOVE, { referenceTag }, CMD.OPT_INTERNAL)
						clearState(unitID)
					end
					return true
				end
				-- AllowCommand rejected the Attack (for example the only-target-category
				-- gadget). A native queue never held that order, so continue with the
				-- next entry now instead of at the unit's next SlowUpdate.
			end
		end
		return false
	end

	-- A unit under construction runs no command SlowUpdate, so a target list given
	-- to it would only be converted after roll-out. Native queued Attacks on such a
	-- unit carry death dependences and advance the queue the moment a target is
	-- deleted, even before the unit is finished. Give the list as native Attacks
	-- so the unit behaves exactly like one without the controller.
	local function giveNativeAttacks(unitID, targetIDs, cmdOptions)
		local coded = cmdOptions.coded or 0
		if cmdOptions.meta and not cmdOptions.shift then
			for index = #targetIDs, 1, -1 do
				spGiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.ATTACK, coded, targetIDs[index] }, CMD.OPT_ALT)
			end
			return
		end
		for index = 1, #targetIDs do
			local options = coded
			if index > 1 then
				options = math.bit_or(coded, CMD.OPT_SHIFT)
			end
			spGiveOrderToUnit(unitID, CMD.ATTACK, { targetIDs[index] }, options)
		end
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
			not isReference
			and not cmdOptions.internal
			and canAttack[unitDefID]
			and Spring.GetUnitIsBeingBuilt(unitID)
		then
			giveNativeAttacks(unitID, cmdParams, cmdOptions)
			return false
		end
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

		if rewritingQueue[unitID] then
			---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
			return true, false
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
			if not GG.SetUnitAttackTargetList then
				clearState(unitID)
				---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
				return true, true
			end
			local targetIDs = collectAdjacentTargetCommands(unitID, cmdParams, cmdTag)
			state.listID = GG.SetUnitAttackTargetList(unitID, unitDefID, targetIDs, state)
			if not state.listID or not recheckController(unitID, state, false) then
				clearState(unitID)
				---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
				return true, true
			end

			-- Replace the full target-ID command with a one-parameter reference,
			-- then start on the first target immediately, like a native Attack does.
			state.referenceID = state.listID
			rewritingQueue[unitID] = true
			spGiveOrderToUnit(
				unitID,
				CMD.INSERT,
				{ 1, CMD_ATTACK_TARGETS, CMD.OPT_INTERNAL, -state.referenceID },
				CMD.OPT_ALT
			)
			spGiveOrderToUnit(unitID, CMD.REMOVE, { cmdTag }, CMD.OPT_INTERNAL)
			rewritingQueue[unitID] = nil
			local front = (spGetUnitCommands(unitID, 1) or {})[1]
			if not isControllerReference(front, state) then
				clearState(unitID)
				---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
				return true, false
			end
			state.cmdTag = front.tag
			if not issueNextTarget(unitID, state, front.tag) then
				spGiveOrderToUnit(unitID, CMD.REMOVE, { front.tag }, CMD.OPT_INTERNAL)
				clearState(unitID)
			end
			---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
			return true, false
		end

		if not recheckController(unitID, state, false) then
			clearState(unitID)
			---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
			return true, true
		end

		if issueNextTarget(unitID, state, cmdTag) then
			---@diagnostic disable-next-line: redundant-return-value -- Recoil consumes handled and remove.
			return true, false
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
			and not issuingControllerAttack
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

	-- A queued native Attack disappears with its target. Drop controllers whose
	-- remaining list just lost its last attackable target, so their queue length
	-- matches the native queue that the movement code inspects.
	local function dropExhaustedControllers(destroyedID)
		local lastIndexByList = {}
		for unitID, state in pairs(targetListStates) do
			local targets = state.targets
			if targets then
				local lastIndex = lastIndexByList[targets]
				if lastIndex == nil then
					lastIndex = false
					for index = 1, #targets do
						if targets[index].target == destroyedID then
							lastIndex = lastAttackableIndex(targets)
							break
						end
					end
					lastIndexByList[targets] = lastIndex
				end
				if lastIndex and state.nextTargetIndex > lastIndex then
					local commands = getControllerAttackCommands(unitID, state)
					if commands then
						spGiveOrderToUnit(unitID, CMD.REMOVE, { commands[#commands].tag }, CMD.OPT_INTERNAL)
						clearState(unitID)
					end
				end
			end
		end
	end

	function gadget:UnitDestroyed(unitID)
		clearState(unitID)
		dropExhaustedControllers(unitID)
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
