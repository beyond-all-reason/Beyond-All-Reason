local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Area Attack",
		desc = "Give area attack commands to ground units",
		author = "KDR_11k (David Becker)",
		date = "2008-01-20",
		license = "Public domain",
		layer = 1,
		enabled = true,
	}
end

-- Custom counterpart to the engine's `CMD.AREA_ATTACK`, used by air units.
-- FIXME: See https://github.com/beyond-all-reason/RecoilEngine/issues/1032
local CMD_AREA_ATTACK_GROUND = GameCMD.AREA_ATTACK_GROUND

if gadgetHandler:IsSyncedCode() then
	local attackList = {}
	local closeList = {}
	local activeAttacks = {}
	local finishedAttacks = {}

	local math_random = math.random
	local math_pi = math.pi
	local math_sqrt = math.sqrt
	local math_cos = math.cos
	local math_sin = math.sin

	local CMD_ATTACK = CMD.ATTACK
	local reissueOrder = Game.Commands.ReissueOrder
	local giveInsertOrderToUnit = Game.Commands.GiveInsertOrderToUnit

	local canAreaAttack = {}
	local areaAttackWeapons = {}
	local areaAttackWeaponByUnitDef = {}
	local groundAttackAfterSalvos = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local advanceAfterSalvos = math.max(tonumber(unitDef.customParams.groundattackaftersalvos) or 0, 0)
		if #unitDef.weapons > 0 and (unitDef.customParams.canareaattack or advanceAfterSalvos > 0) then
			local weaponDefID = unitDef.weapons[1].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if weaponDef then
				areaAttackWeapons[weaponDefID] = true
				areaAttackWeaponByUnitDef[unitDefID] = weaponDefID
				groundAttackAfterSalvos[unitDefID] = advanceAfterSalvos
				if unitDef.customParams.canareaattack then
					canAreaAttack[unitDefID] = weaponDef.range
				end
			end
		end
	end
	local range = canAreaAttack -- range per unitDefID, same data

	local aadesc = {
		name = "Area Attack",
		action = "areaattack",
		id = CMD_AREA_ATTACK_GROUND,
		type = CMDTYPE.ICON_AREA,
		tooltip = "attack an area randomly",
		cursor = "cursorattack",
	}

	function gadget:GameFrame(f)
		-- UnitWeaponBurstEnd runs during weapon simulation. Defer command-queue
		-- mutations so they cannot re-enter weapon or command-AI update code.
		for unitID, attack in pairs(finishedAttacks) do
			finishedAttacks[unitID] = nil
			local commandID, _, commandTag = Spring.GetUnitCurrentCommand(unitID)
			if commandID == CMD_ATTACK and commandTag == attack.commandTag then
				-- Preserve the engine's normal Repeat and UnitCmdDone handling. Generated
				-- area-attack shots are internal, so the engine will not repeat them.
				Spring.UnitFinishCommand(unitID)
			else
				-- A command can be inserted ahead of the completed attack before the
				-- deferred mutation runs. Remove only that attack in this case.
				local states = Spring.GetUnitStates(unitID)
				if states and states["repeat"] and not attack.options.internal then
					giveInsertOrderToUnit(unitID, CMD_ATTACK, attack.params, attack.options, -1, CMD.OPT_ALT)
				end
				Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { attack.commandTag }, 0)
			end
		end

		for i, o in pairs(attackList) do
			attackList[i] = nil
			local phase = math_random(200 * math_pi) / 100.0
			if o.radius > 0 then
				local amp = math_random(o.radius)
				Spring.GiveOrderToUnit(o.unit, CMD.INSERT, {
					0,
					CMD.ATTACK,
					CMD.OPT_INTERNAL,
					o.x + math_cos(phase) * amp,
					o.y,
					o.z + math_sin(phase) * amp,
				}, { "alt" })
			end
		end
		for i, o in pairs(closeList) do
			closeList[i] = nil
			Spring.SetUnitMoveGoal(o.unit, o.x, o.y, o.z, o.radius)
		end
	end

	function gadget:AllowCommand(
		unitID,
		unitDefID,
		teamID,
		cmdID,
		cmdParams,
		cmdOptions,
		cmdTag,
		playerID,
		fromSynced,
		fromLua,
		fromInsert
	)
		-- accepts: CMD_AREA_ATTACK_GROUND
		if canAreaAttack[unitDefID] and #cmdParams == 4 then
			if cmdParams[4] > 1 then
				return true
			end
			cmdParams[4] = nil
			reissueOrder(unitID, CMD_ATTACK, cmdParams, cmdOptions, cmdTag, fromInsert)
		end
		return false
	end

	function gadget:CommandFallback(u, ud, team, cmd, param, opt)
		if cmd == CMD_AREA_ATTACK_GROUND then
			local x, _, z = Spring.GetUnitPosition(u)
			if not x then
				return true, true
			end
			local dist = math_sqrt((x - param[1]) * (x - param[1]) + (z - param[3]) * (z - param[3]))
			if dist <= range[ud] - param[4] then
				attackList[#attackList + 1] = {
					unit = u,
					x = param[1],
					y = param[2],
					z = param[3],
					radius = param[4],
				}
			else
				closeList[#closeList + 1] =
					{ unit = u, x = param[1], y = param[2], z = param[3], radius = range[ud] - param[4] }
			end
			return true, false
		end
		return false
	end

	function gadget:UnitWeaponBurstEnd(unitID, unitDefID, unitTeam, weaponNum)
		local unitDefWeapon = UnitDefs[unitDefID].weapons[weaponNum]
		local weaponDefID = unitDefWeapon and unitDefWeapon.weaponDef
		if areaAttackWeaponByUnitDef[unitDefID] ~= weaponDefID then
			return
		end

		local commands = Spring.GetUnitCommands(unitID, -1)
		local attackCommand = commands and commands[1]
		if not attackCommand or not attackCommand.params or #attackCommand.params < 3 or not attackCommand.options then
			return
		end
		local commandTag = attackCommand.tag
		if attackCommand.id ~= CMD_ATTACK or not commandTag then
			return
		end

		local pendingAttack = finishedAttacks[unitID]
		if pendingAttack and pendingAttack.commandTag == commandTag then
			return
		end

		local advanceAfterSalvos = groundAttackAfterSalvos[unitDefID]
		local internalAreaAttack = attackCommand.options.internal and canAreaAttack[unitDefID]
		if not internalAreaAttack and advanceAfterSalvos <= 0 then
			return
		end

		local attack = activeAttacks[unitID]
		if not attack or attack.commandTag ~= commandTag then
			if not commands[2] then
				return
			end
			attack = {
				commandTag = commandTag,
				weaponDefID = weaponDefID,
				salvosLeft = math.max(advanceAfterSalvos, 1),
				params = attackCommand.params,
				options = attackCommand.options,
			}
			activeAttacks[unitID] = attack
		elseif attack.weaponDefID ~= weaponDefID then
			return
		end

		attack.salvosLeft = attack.salvosLeft - 1
		if attack.salvosLeft > 0 then
			return
		end

		activeAttacks[unitID] = nil
		-- Ground attacks are persistent when they are the last command. If
		-- another command follows, advance after the configured number of salvos.
		if not commands[2] then
			return
		end
		finishedAttacks[unitID] = attack
	end

	function gadget:UnitCreated(u, ud, team)
		if canAreaAttack[ud] then
			Spring.InsertUnitCmdDesc(u, aadesc)
		end
	end

	function gadget:UnitDestroyed(unitID)
		activeAttacks[unitID] = nil
		finishedAttacks[unitID] = nil
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_AREA_ATTACK_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_AREA_ATTACK_GROUND)
		if Script.SetWatchWeaponBurst then
			for weaponDefID in pairs(areaAttackWeapons) do
				Script.SetWatchWeaponBurst(weaponDefID, true)
			end
		end
	end
else -- UNSYNCED
	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_AREA_ATTACK_GROUND, CMDTYPE.ICON_UNIT_OR_AREA, { 1, 0, 0, 0.8 }, true)
	end
end
