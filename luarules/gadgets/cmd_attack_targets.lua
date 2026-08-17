local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Attack Targets",
		desc = "Expands one ordered target-list command into queued attack commands",
		author = "BAR",
		date = "2026-08-17",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local CMD_ATTACK_TARGETS = GameCMD.ATTACK_TARGETS

if gadgetHandler:IsSyncedCode() then
	local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
	local expandedCommandTags = {}

	local canAttack = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		canAttack[unitDefID] = unitDef.canAttack
	end

	local commandDescription = {
		id = CMD_ATTACK_TARGETS,
		type = CMDTYPE.ICON_UNIT,
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

		if expandedCommandTags[unitID] == cmdTag then
			expandedCommandTags[unitID] = nil
			return true, true
		end

		local orders = {}
		for i = #cmdParams, 1, -1 do
			orders[#orders + 1] = { CMD.INSERT, { 0, CMD.ATTACK, 0, cmdParams[i] }, CMD.OPT_ALT }
		end

		expandedCommandTags[unitID] = cmdTag
		spGiveOrderArrayToUnit(unitID, orders)
		return true, false
	end

	function gadget:UnitDestroyed(unitID)
		expandedCommandTags[unitID] = nil
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
		Spring.SetCustomCommandDrawData(CMD_ATTACK_TARGETS, CMDTYPE.ICON_UNIT, { 1, 0, 0, 0.8 }, true)
	end
end
