local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Area Attack",
		desc = "Give area attack commands to ground units",
		author = "KDR_11k (David Becker)",
		date = "2008-01-20",
		license = "Public domain",
		layer = 1,
		enabled = true
	}
end

-- Custom counterpart to the engine's `CMD.AREA_ATTACK`, used by air units.
-- FIXME: See https://github.com/beyond-all-reason/RecoilEngine/issues/1032
local CMD_AREA_ATTACK_GROUND = GameCMD.AREA_ATTACK_GROUND

if gadgetHandler:IsSyncedCode() then

	local attackList = {}
	local closeList = {}
	local range = {}

	local math_random = math.random
	local math_pi = math.pi
	local math_sqrt = math.sqrt
	local math_cos = math.cos
	local math_sin = math.sin

	local canAreaAttack = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if #unitDef.weapons > 0 and unitDef.customParams.canareaattack then
			canAreaAttack[unitDefID] = WeaponDefs[unitDef.weapons[1].weaponDef].range
		end
	end

	local aadesc = {
		name = "Area Attack",
		action = "areaattack",
		id = CMD_AREA_ATTACK_GROUND,
		type = CMDTYPE.ICON_AREA,
		tooltip = "attack an area randomly",
		cursor = "cursorattack",
	}

	function gadget:GameFrame(f)
		for i,o in pairs(attackList) do
			attackList[i] = nil
			local phase = math_random(200*math_pi)/100.0
			if o.radius > 0 then
				local amp = math_random(o.radius)
				Spring.GiveOrderToUnit(o.unit, CMD.INSERT, {0, CMD.ATTACK, 0, o.x + math_cos(phase)*amp, o.y, o.z + math_sin(phase)*amp}, {"alt"})
			end
		end
		for i,o in pairs(closeList) do
			closeList[i] = nil
			Spring.SetUnitMoveGoal(o.unit,o.x,o.y,o.z,o.radius)
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		-- accepts: CMD_AREA_ATTACK_GROUND
		if canAreaAttack[unitDefID] then
			return true
		else
			return false
		end
	end

	function gadget:CommandFallback(u,ud,team,cmd,param,opt)
		if cmd == CMD_AREA_ATTACK_GROUND then
			local x,_,z = Spring.GetUnitPosition(u)
			local dist = math_sqrt((x-param[1])*(x-param[1]) + (z-param[3])*(z-param[3]))
			if dist <= range[ud] - param[4] then
				attackList[#attackList+1] = {unit = u, x=param[1], y=param[2], z=param[3], radius=param[4]}
			else
				closeList[#closeList+1] ={unit = u, x=param[1], y=param[2], z=param[3], radius=range[ud]-param[4]}
			end
			return true, false
		end
		return false
	end

	function gadget:UnitCreated(u, ud, team)
		if canAreaAttack[ud] then
			range[ud] = canAreaAttack[ud]	-- put the range inside canAreaAttack[ud]
			Spring.InsertUnitCmdDesc(u,aadesc)
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_AREA_ATTACK_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_AREA_ATTACK_GROUND)
	end

else	-- UNSYNCED

	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_AREA_ATTACK_GROUND, CMDTYPE.ICON_UNIT_OR_AREA, {1,0,0,.8},true)
	end

end
