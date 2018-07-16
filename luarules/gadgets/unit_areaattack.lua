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

local CMD_AREAATTACK = 39954

if (gadgetHandler:IsSyncedCode()) then

--SYNCED


----------- Following bugs fixed by anonymous person ----------------
-- FIXED bug: when o.radius was zero it caused a crash
-- FIXED bug: now checks which units can area-attack = no more crashing via CTRL+A + area attack ;)
---------------------------------------------------------------------------



local attackList={}
local closeList={}
local range={}

local aadesc= {
	name = "Area Attack",
	action="areaattack",
	id=CMD_AREAATTACK,
	type=CMDTYPE.ICON_AREA,
	tooltip="Attack an area randomly",
	cursor="cursorattack",
}

function gadget:GameFrame(f)
	for i,o in pairs(attackList) do
		attackList[i] = nil
		local phase = math.random(200*math.pi)/100.0
		if o.radius > 0 then
			local amp = math.random(o.radius)
			Spring.GiveOrderToUnit(o.unit, CMD.INSERT, {0, CMD.ATTACK, 0, o.x + math.cos(phase)*amp, o.y, o.z + math.sin(phase)*amp}, {"alt"})
		end
	end
	for i,o in pairs(closeList) do
		closeList[i] = nil
		Spring.SetUnitMoveGoal(o.unit,o.x,o.y,o.z,o.radius)
	end
end

function gadget:AllowCommand(u, ud, team, cmd, param, opt)
	if cmd == CMD_AREAATTACK then
		if UnitDefs[ud].customParams.canareaattack=="1" then
			return true
		else 
			return false
		end
	else
		return true
	end
end

function gadget:CommandFallback(u,ud,team,cmd,param,opt)
	if cmd == CMD_AREAATTACK then
		local x,_,z = Spring.GetUnitPosition(u)
		local dist = math.sqrt((x-param[1])*(x-param[1]) + (z-param[3])*(z-param[3]))
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
	if UnitDefs[ud].customParams.canareaattack=="1" then
		range[ud] = WeaponDefs[UnitDefs[ud].weapons[1].weaponDef].range
		Spring.InsertUnitCmdDesc(u,aadesc)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(CMD_AREAATTACK)
end

else

-- no UNSYNCED code

function gadget:Initialize()
	Spring.SetCustomCommandDrawData(CMD_AREAATTACK, CMDTYPE.ICON_AREA, {1,0,0,.8},true)
end

--return false

end
