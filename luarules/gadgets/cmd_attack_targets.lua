local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Attack Targets",
		desc = "Steps through an ordered target list using ordinary attack commands",
		author = "BAR",
		date = "2026-08-17",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local CMD_ATTACK_TARGETS = GameCMD.ATTACK_TARGETS

if gadgetHandler:IsSyncedCode() then
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local targetListStates = {}

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

	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams)
		if cmdID ~= CMD_ATTACK_TARGETS then
			return true
		end

		return canAttack[unitDefID] and cmdParams[1] ~= nil
	end

	function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, _, cmdTag)
		if cmdID ~= CMD_ATTACK_TARGETS then
			return false
		end

		local state = targetListStates[unitID]
		if state == nil or state.cmdTag ~= cmdTag then
			state = {
				cmdTag = cmdTag,
				nextTargetIndex = 1,
			}
			targetListStates[unitID] = state
		end

		while state.nextTargetIndex <= #cmdParams do
			local targetID = cmdParams[state.nextTargetIndex]
			state.nextTargetIndex = state.nextTargetIndex + 1

			if Spring.ValidUnitID(targetID) and not Spring.GetUnitIsDead(targetID) then
				spGiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.ATTACK, 0, targetID }, CMD.OPT_ALT)
				return true, false
			end
		end

		targetListStates[unitID] = nil
		return true, true
	end

	function gadget:UnitDestroyed(unitID)
		targetListStates[unitID] = nil
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if canAttack[unitDefID] then
			Spring.InsertUnitCmdDesc(unitID, commandDescription)
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_ATTACK_TARGETS)
		gadgetHandler:RegisterAllowCommand(CMD_ATTACK_TARGETS)
	end
else
	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_ATTACK_TARGETS, nil)
	end
end
