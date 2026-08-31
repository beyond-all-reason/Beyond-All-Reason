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

	local math_random = math.random
	local math_pi = math.pi
	local math_sqrt = math.sqrt
	local math_cos = math.cos
	local math_sin = math.sin
	local math_max = math.max
	local math_bit_and = math.bit_and

	local CMD_ATTACK = CMD.ATTACK
	local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
	local reissueOrder = Game.Commands.ReissueOrder

	local canAreaAttack = {}
	local areaAttackWeaponDefs = {}
	local areaAttackWeaponDefByUnitDef = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if #unitDef.weapons > 0 and unitDef.customParams.canareaattack then
			local weaponDefID = unitDef.weapons[1].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if weaponDef then
				canAreaAttack[unitDefID] = weaponDef.range
				areaAttackWeaponDefs[weaponDefID] = true
				areaAttackWeaponDefByUnitDef[unitDefID] = weaponDefID
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

	function gadget:GameFramePost(frame)
		for unitID, attack in pairs(activeAttacks) do
			if frame >= attack.checkFrame then
				local salvoLeft = Spring.GetUnitWeaponState(unitID, 1, "salvoLeft")
				if not salvoLeft then
					activeAttacks[unitID] = nil
				elseif salvoLeft > 0 then
					local nextSalvo = Spring.GetUnitWeaponState(unitID, 1, "nextSalvo")
					attack.checkFrame = math_max(nextSalvo or 0, frame + 1)
				else
					activeAttacks[unitID] = nil
					local commandID, _, commandTag = Spring.GetUnitCurrentCommand(unitID)
					if commandID == CMD_ATTACK and commandTag == attack.commandTag then
						-- Internal commands are not requeued by normal command completion.
						Spring.UnitFinishCommand(unitID)
					else
						-- A command can move ahead while the burst is active. Remove only
						-- the generated attack in that case.
						Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { attack.commandTag }, 0)
					end
				end
			end
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
		if not areaAttackWeaponDefs[weaponDefID] or activeAttacks[ownerID] then
			return
		end

		local unitDefID = Spring.GetUnitDefID(ownerID)
		if areaAttackWeaponDefByUnitDef[unitDefID] ~= weaponDefID then
			return
		end

		local commandID, commandOptions, commandTag, _, _, targetZ = Spring.GetUnitCurrentCommand(ownerID)
		if commandID ~= CMD_ATTACK or targetZ == nil or math_bit_and(commandOptions, CMD_OPT_INTERNAL) == 0 then
			return
		end
		if not Spring.GetUnitCurrentCommand(ownerID, 2) then
			return
		end

		-- Poll weapon state after simulation instead of counting every projectile.
		activeAttacks[ownerID] = {
			commandTag = commandTag,
			checkFrame = Spring.GetGameFrame(),
		}
	end

	function gadget:UnitCreated(u, ud, team)
		if canAreaAttack[ud] then
			Spring.InsertUnitCmdDesc(u, aadesc)
		end
	end

	function gadget:UnitDestroyed(unitID)
		activeAttacks[unitID] = nil
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_AREA_ATTACK_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_AREA_ATTACK_GROUND)
		for weaponDefID in pairs(areaAttackWeaponDefs) do
			Script.SetWatchProjectile(weaponDefID, true)
		end
	end
else -- UNSYNCED
	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_AREA_ATTACK_GROUND, CMDTYPE.ICON_UNIT_OR_AREA, { 1, 0, 0, 0.8 }, true)
	end
end
