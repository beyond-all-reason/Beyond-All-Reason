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
				areaAttackWeapons[weaponDefID] = weaponDef.salvoSize
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
		-- Removing a command from ProjectileCreated can invalidate the engine's
		-- active weapon-command state, so defer it until the next game frame.
		for unitID, attack in pairs(finishedAttacks) do
			finishedAttacks[unitID] = nil
			local commandID, _, commandTag = Spring.GetUnitCurrentCommand(unitID)
			if commandID == CMD_ATTACK and commandTag == attack.commandTag then
				-- Preserve the engine's normal Repeat and UnitCmdDone handling. Generated
				-- area-attack shots are internal, so the engine will not repeat them.
				Spring.UnitFinishCommand(unitID)
			else
				-- A command can be inserted ahead of the attack before this deferred
				-- callback runs. Remove only the completed attack in that case.
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

	function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
		local salvoSize = areaAttackWeapons[weaponDefID]
		local unitDefID = Spring.GetUnitDefID(ownerID)
		if not salvoSize or areaAttackWeaponByUnitDef[unitDefID] ~= weaponDefID then
			return
		end

		local commands = Spring.GetUnitCommands(ownerID, 2)
		local currentCommand = commands and commands[1]
		if
			not currentCommand
			or currentCommand.id ~= CMD_ATTACK
			or not currentCommand.params
			or #currentCommand.params < 3
			or not currentCommand.options
		then
			return
		end

		local advanceAfterSalvos = groundAttackAfterSalvos[unitDefID]
		local internalAreaAttack = currentCommand.options.internal and canAreaAttack[unitDefID]
		if not internalAreaAttack and advanceAfterSalvos <= 0 then
			return
		end

		local attack = activeAttacks[ownerID]
		if not attack or attack.commandTag ~= currentCommand.tag then
			if not commands[2] then
				return
			end
			attack = {
				commandTag = currentCommand.tag,
				weaponDefID = weaponDefID,
				projectilesLeft = salvoSize,
				salvosLeft = math.max(advanceAfterSalvos, 1),
				params = currentCommand.params,
				options = currentCommand.options,
			}
			activeAttacks[ownerID] = attack
		elseif attack.weaponDefID ~= weaponDefID then
			return
		end

		attack.projectilesLeft = attack.projectilesLeft - 1
		if attack.projectilesLeft > 0 then
			return
		end

		attack.salvosLeft = attack.salvosLeft - 1
		if attack.salvosLeft > 0 then
			attack.projectilesLeft = salvoSize
			return
		end

		activeAttacks[ownerID] = nil
		-- Ground attacks are persistent when they are the last command. If
		-- another command follows, advance after the configured number of salvos.
		if commands[2] then
			finishedAttacks[ownerID] = attack
		end
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
		for weaponDefID in pairs(areaAttackWeapons) do
			Script.SetWatchProjectile(weaponDefID, true)
		end
	end
else -- UNSYNCED
	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_AREA_ATTACK_GROUND, CMDTYPE.ICON_UNIT_OR_AREA, { 1, 0, 0, 0.8 }, true)
	end
end
