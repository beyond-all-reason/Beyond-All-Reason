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

if gadgetHandler:IsSyncedCode() then
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local spGetUnitCommands = Spring.GetUnitCommands
	local targetListStates = {}
	local pendingPrepends = {}
	local pendingQueueChecks = {}
	local tailGroups = {}
	local nextTailGroupID = 0
	local groupsByTail = {}
	local pendingTargetUnits = {}
	local hasUnitDeleted = Script.GetCallInList().UnitDeleted ~= nil
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

	local executionSnapshots = setmetatable({}, { __mode = "k" })
	local entriesByTarget = {}
	local function executionSnapshot(targets)
		local snapshot = executionSnapshots[targets]
		if snapshot then
			return snapshot
		end
		snapshot = {}
		for _, target in ipairs(targets) do
			local entry = { target = target.target }
			snapshot[#snapshot + 1] = entry
			local entries = entriesByTarget[entry.target]
			if not entries then
				entries = setmetatable({}, { __mode = "k" })
				entriesByTarget[entry.target] = entries
			end
			entries[entry] = true
		end
		executionSnapshots[targets] = snapshot
		return snapshot
	end

	-- Deleted and crashing units cannot supply the next Attack target.
	-- Crashing-target rejection follows RecoilEngine #3348; native 2026.07.04 queues still differ.
	local function isAttackableTarget(targetID)
		if not Spring.ValidUnitID(targetID) or Spring.GetUnitIsDead(targetID) then
			return false
		end
		local moveTypeData = Spring.GetUnitMoveTypeData(targetID)
		return not moveTypeData or moveTypeData.aircraftState ~= "crashing"
	end

	local function lastAttackableIndex(targets)
		for index = #targets, 1, -1 do
			if not targets[index].deleted and isAttackableTarget(targets[index].target) then
				return index
			end
		end
		return 0
	end

	local function unwatchTail(unitID, state)
		local group = state.tailGroup
		if not group then
			return
		end
		group.units[unitID] = nil
		state.tailGroup = nil
		if next(group.units) == nil then
			tailGroups[group.targets] = nil
			if group.targetID then
				local groups = groupsByTail[group.targetID]
				groups[group.id] = nil
				if next(groups) == nil then
					groupsByTail[group.targetID] = nil
				end
			end
		end
	end

	local function watchTail(unitID, state)
		local targets = state.targets
		if state.tailGroup and state.tailGroup.targets == targets then
			return state.tailGroup
		end
		unwatchTail(unitID, state)
		local group = tailGroups[targets]
		if not group then
			local lastIndex = lastAttackableIndex(state.targets)
			local targetID = lastIndex > 0 and state.targets[lastIndex].target or nil
			nextTailGroupID = nextTailGroupID + 1
			group = { id = nextTailGroupID, targets = targets, lastIndex = lastIndex, targetID = targetID, units = {} }
			tailGroups[targets] = group
			if targetID then
				groupsByTail[targetID] = groupsByTail[targetID] or {}
				groupsByTail[targetID][group.id] = group
			end
		end
		group.units[unitID] = state
		state.tailGroup = group
		return group
	end

	local function unwatchPendingTarget(unitID, state)
		local targetID = state.pendingTargetID
		local units = targetID and pendingTargetUnits[targetID]
		if units then
			units[unitID] = nil
			if next(units) == nil then
				pendingTargetUnits[targetID] = nil
			end
		end
		state.pendingTargetID = nil
	end

	local function watchPendingTarget(unitID, state)
		unwatchPendingTarget(unitID, state)
		for index = state.nextTargetIndex, #state.targets do
			local targetID = state.targets[index].target
			-- Native queues keep crashing/dead-but-not-yet-deleted targets.
			if not state.targets[index].deleted and Spring.ValidUnitID(targetID) then
				state.pendingTargetID = targetID
				local units = pendingTargetUnits[targetID] or {}
				pendingTargetUnits[targetID] = units
				units[unitID] = state
				return
			end
		end
	end

	local function clearState(unitID)
		pendingPrepends[unitID] = nil
		pendingQueueChecks[unitID] = nil
		rewritingQueue[unitID] = nil
		local state = targetListStates[unitID]
		if not state then
			return
		end
		unwatchTail(unitID, state)
		unwatchPendingTarget(unitID, state)
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

	-- Expose the pending native-equivalent queue head without advancing it.
	-- The reference check prevents a removed/replaced controller from supplying
	-- a target before its deferred queue cleanup has run.
	local function getPendingAttackTarget(unitID, reference)
		local state = targetListStates[unitID]
		if not state or not state.referenceID or reference ~= -state.referenceID then
			return
		end
		for index = state.nextTargetIndex, #state.targets do
			local targetID = state.targets[index].target
			if not state.targets[index].deleted and Spring.ValidUnitID(targetID) then
				return targetID
			end
		end
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

	-- Explicit list changes update the execution snapshot; the Attack commands ahead of the
	-- controller are its materialized execution state. Refresh the watchers
	-- after every explicit list change, and restart it when a prepend changes
	-- which target belongs at the front.
	local function recheckController(unitID, state, restartFromFront)
		local targets = GG.GetUnitAttackTargetList and GG.GetUnitAttackTargetList(unitID)
		if not targets then
			return false
		end
		-- Rendering/Set Target prunes crashing entries before the engine deletes
		-- them. Keep the execution snapshot: those entries still occupy native
		-- queue positions and can trigger death-dependent advancement.
		state.targets = state.targets or executionSnapshot(targets)
		watchTail(unitID, state)
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
		watchPendingTarget(unitID, state)
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
		local updated = GG.GetUnitAttackTargetList(unitID)
		local executionTargets, seen, requested = {}, {}, {}
		for _, targetID in ipairs(cmdParams) do
			requested[targetID] = true
		end
		for _, entry in ipairs(state.targets) do
			executionTargets[#executionTargets + 1] = entry
			if not entry.deleted then
				seen[entry.target] = true
			end
		end
		for _, entry in ipairs(executionSnapshot(updated or {})) do
			if requested[entry.target] and not seen[entry.target] then
				executionTargets[#executionTargets + 1] = entry
				seen[entry.target] = true
			end
		end
		state.targets = executionTargets
		if state.targets then
			watchTail(unitID, state)
			watchPendingTarget(unitID, state)
		end
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
			if
				not state.targets[index].deleted
				and type(queuedTargetID) == "number"
				and not seenTargets[queuedTargetID]
			then
				seenTargets[queuedTargetID] = true
				targetIDs[#targetIDs + 1] = queuedTargetID
			end
		end

		local listID = GG.SetUnitAttackTargetList(unitID, unitDefID, targetIDs, state)
		if not listID then
			return false
		end
		state.listID = listID
		state.targets = {}
		for _, targetID in ipairs(targetIDs) do
			state.targets[#state.targets + 1] = { target = targetID }
		end
		state.targets = executionSnapshot(state.targets)
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

	-- RecoilEngine #3344 workaround: 2026.07.04 CMD.INSERT omits target death dependencies.
	-- A throwaway object command registers the dependency so dead targets leave the queue immediately.
	-- The dependency outlives that command and covers the inserted Attack on the same target.
	-- Remove this helper and its call once the minimum supported engine includes #3344.
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
			local entry = state.targets[state.nextTargetIndex]
			local targetID = entry.target
			state.nextTargetIndex = state.nextTargetIndex + 1
			watchPendingTarget(unitID, state)
			if not entry.deleted and isAttackableTarget(targetID) then
				-- The controller remains queued directly behind this attack. The engine
				-- chooses movement and weapon targets; the stored list only supplies
				-- the next Attack when this one finishes. The Attack carries no
				-- INTERNAL flag: the engine treats internal attacks as automatic
				-- targets (weapons may swap them and Set Target overrides them),
				-- which is not how a player's queued Attack behaves.
				local queueLength = Spring.GetUnitCommandCount(unitID) or 0
				issuingControllerAttack = true
				-- Front insertion resets targetDied; the native pre-#3346 order-drop bug is not emulated for A/B parity.
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

	-- Engines without registration or deletion notifications use native Attacks.
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
			and (not Spring.RegisterCommand or not hasUnitDeleted or Spring.GetUnitIsBeingBuilt(unitID))
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
		then
			pendingQueueChecks[unitID] = true
		end
	end

	function gadget:GameFrame()
		for unitID, unitDefID in pairs(pendingPrepends) do
			prependToActiveController(unitID, unitDefID)
			pendingPrepends[unitID] = nil
		end
		for unitID in pairs(pendingQueueChecks) do
			local state = targetListStates[unitID]
			local retained = false
			if state then
				for _, command in ipairs(spGetUnitCommands(unitID, -1) or {}) do
					if isControllerReference(command, state) then
						retained = true
						break
					end
				end
			end
			if not retained then
				clearState(unitID)
			end
			pendingQueueChecks[unitID] = nil
		end
	end

	-- Only lists whose last live target died can become exhausted in this callin.
	local function dropExhaustedControllers(destroyedID)
		local groups = groupsByTail[destroyedID]
		if not groups then
			return
		end
		groupsByTail[destroyedID] = nil
		for listID, group in pairs(groups) do
			group.lastIndex = lastAttackableIndex(group.targets)
			group.targetID = group.lastIndex > 0 and group.targets[group.lastIndex].target or nil
			if group.targetID then
				groupsByTail[group.targetID] = groupsByTail[group.targetID] or {}
				groupsByTail[group.targetID][listID] = group
			end
			for unitID, state in pairs(group.units) do
				if state.nextTargetIndex > group.lastIndex then
					spGiveOrderToUnit(unitID, CMD.REMOVE, { state.cmdTag }, CMD.OPT_INTERNAL)
					clearState(unitID)
				end
			end
		end
	end

	function gadget:UnitDestroyed(unitID)
		clearState(unitID)
	end

	function gadget:UnitDeleted(targetID)
		-- A recycled engine ID must not revive an old queued target. Mark the
		-- shared execution entries before advancing any controller.
		local entries = entriesByTarget[targetID]
		if entries then
			for entry in pairs(entries) do
				entry.deleted = true
			end
			entriesByTarget[targetID] = nil
		end
		executionSnapshots = setmetatable({}, { __mode = "k" })
		local units = pendingTargetUnits[targetID]
		if units then
			-- Issuing an Attack can reenter the controller and mutate this index.
			local unitIDs = {}
			for unitID in pairs(units) do
				unitIDs[#unitIDs + 1] = unitID
			end
			table.sort(unitIDs)
			for _, unitID in ipairs(unitIDs) do
				local state = units[unitID]
				if state and targetListStates[unitID] == state then
					watchPendingTarget(unitID, state)
					local front = (spGetUnitCommands(unitID, 1) or {})[1]
					if isControllerReference(front, state) and not Spring.GetUnitIsStunned(unitID) then
						if
							not recheckController(unitID, state, false)
							or not issueNextTarget(unitID, state, front.tag)
						then
							spGiveOrderToUnit(unitID, CMD.REMOVE, { front.tag }, CMD.OPT_INTERNAL)
							clearState(unitID)
						end
					end
				end
			end
		end
		dropExhaustedControllers(targetID)
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
		GG.GetPendingAttackTarget = getPendingAttackTarget
		gadgetHandler:RegisterCMDID(CMD_ATTACK_TARGETS)
		if Spring.RegisterCommand then
			Spring.RegisterCommand(CMD_ATTACK_TARGETS, { movement = true, attack = true })
		end
		gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
		gadgetHandler:RegisterAllowCommand(CMD_ATTACK_TARGETS)
	end
	function gadget:Shutdown()
		GG.GetPendingAttackTarget = nil
	end
else
	function gadget:Initialize()
		-- Set Target owns rendering for both the active target and the remainder
		-- of this list, so generic command drawing must not interpret unit IDs as
		-- XYZ coordinates.
		Spring.SetCustomCommandDrawData(CMD_ATTACK_TARGETS, nil)
	end
end
