local tube1, tube2, base, wake = piece("tube1", "tube2", "base", "wake")

SIG_AIM = 2
SIG_AIM_2 = 4
SIG_MOVE = 8
Surfaced = false
piecetable = {tube1, tube2, base, wake}
uDef = UnitDefs[Spring.GetUnitDefID(unitID)]
wDef = WeaponDefs[WeaponDefNames["corsub_arm_torpedobig"].id]

function script.Create()
	local sx,sy,sz,ox,oy,oz,vt, tt,pa, disabled = Spring.GetUnitCollisionVolumeData(unitID)
	local ix,iy,iz,impx,impy,impz,iapx,iapy,iapz = Spring.GetUnitPosition(unitID, true, true)
	mpx, mpy, mpz =  impx - ix, impy - iy, impz - iz
	apx, apy, apz = iapx - ix, iapy - iy, iapz - iz
	f = 0
	Spring.SetUnitMaxRange(unitID, 310)
	StartThread(SpeedLimit)
	StartThread(Steam)
	-- Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, {0}, {})
	Spring.SetUnitArmored(unitID, true, 0.5)
end

function Emit(pieceName, effectName)
local x,y,z	= Spring.GetUnitPosition(unitID)
y = y + 30
ndx, ndy, ndz = 0,1,0
-- Spring.Echo(ndx, ndy, ndz)
Spring.SpawnCEG(effectName, x,y,z, ndx, ndy, ndz)
end

function Steam()
while (true) do
	if Surfaced then
		Emit(base, "steam")
	end
Sleep(1000)
end
end

function SpeedLimit()
while (true) do
	if speedlimit then
		local vx, vy, vz, vw = Spring.GetUnitVelocity(unitID)
		-- Spring.Echo(vw)
			if (vw*30) > speedlimit * uDef.speed then
				local ratio = speedlimit * uDef.speed/(vw*30)
				Spring.SetUnitVelocity(unitID, ratio*vx, ratio*vy, ratio*vz)
			end
	end
Sleep(100)
end
end

function Surface()
Spring.UnitScript.SetSignalMask(1)
	while f < math.pi do
		Move(base, 2, (-math.cos(f)+1)*10)
		Spring.SetUnitMidAndAimPos(unitID, mpx, mpy + (-math.cos(f)+1)*15, mpz, apx, apy + (-math.cos(f)+1)*15, apz, true)
		f = f + math.pi/45
		Sleep(1)
	end
Spring.SetUnitArmored(unitID, false)
Surfaced = true
Spring.SetUnitSensorRadius(unitID,"los", uDef.losRadius)
speedlimit = 0.5
end

function Drown()
Surfaced = false
Spring.UnitScript.SetSignalMask(2)
	while f > 0 do
		Move(base, 2, (-math.cos(f)+1)*10)
		Spring.SetUnitMidAndAimPos(unitID, mpx, mpy + (-math.cos(f)+1)*15, mpz, apx, apy + (-math.cos(f)+1)*15, apz, true)
		f = f - math.pi/45
		Sleep(1)
	end
Spring.SetUnitArmored(unitID, true, 0.75)
Spring.SetUnitSensorRadius(unitID,"los", 0)
speedlimit = nil
end

function script.AimFromWeapon2()
return base
end

function script.QueryWeapon2()
if gun == 1 then
	return tube1
else
	return tube2
end
end

function script.AimWeapon1(heading, pitch)	
	StartThread(Surface)
	Signal(2)
	while Surfaced ~= true do
	Sleep(10)
	end
	if Surfaced == true then
	local reloadTime = Spring.GetUnitWeaponState(unitID, 1, "reloadTime")
	-- Spring.Echo(reloadTime)
	Signal(27)
	StartThread(Restore, reloadTime * 1000)
	return (true)
	else
	return (false)
	end
end

function script.AimFromWeapon1()
return base
end

function script.QueryWeapon1()
if gun == 1 then
	return tube1
else
	return tube2
end
end

function script.AimWeapon2(heading, pitch)
	return (true)
end

function Restore(sleeptime)
		Spring.UnitScript.SetSignalMask(27)
		Sleep(sleeptime)
		Signal(1)
		StartThread(Drown)
end

function script.FireWeapon(weapon)
if gun == 1 then 
gun = 2 
else 
gun = 1 
end
	if weapon == 1 then
	local reloadTime = Spring.GetUnitWeaponState(unitID, 1, "reloadTime")
	Signal(27)
	StartThread(Restore, reloadTime * 1000)
	end
end

function script.StartMoving()
	return (0)
end

function script.StopMoving()
	return (0)
end

function script.Killed(recentDamage, maxHealth)
	severity = recentDamage*100/maxHealth
	if severity <= 25 then
		for count, piece in pairs(piecetable) do
			randomnumber = math.random(1,7)
			if randomnumber == 1 then
				if piece == base then 
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL + SFX.SHATTER) 
				else
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
				end
			elseif randomnumber == 2 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.SHATTER + SFX.NO_HEATCLOUD)
			else
				Explode(piece, SFX.SHATTER + SFX.NO_HEATCLOUD)
			end
			Hide(piece)
		end
		return 1
	elseif severity <=50 then
		for count, piece in pairs(piecetable) do
			randomnumber = math.random(1,5)
			if randomnumber == 1 then
				if piece == base then 
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL + SFX.SHATTER) 
				else
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
				end
			elseif randomnumber == 2 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.SHATTER + SFX.NO_HEATCLOUD)
			else
				Explode(piece, SFX.SHATTER + SFX.NO_HEATCLOUD)
			end
			Hide(piece)
		end
		return 2
	elseif severity <= 99 then
		randomnumber = math.random(1,2)
		for count, piece in pairs(piecetable) do

			randomnumber = math.random(1,3)
			if randomnumber == 1 then
				if piece == base then 
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL + SFX.SHATTER) 
				else
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
				end
			elseif randomnumber == 2 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.SHATTER + SFX.NO_HEATCLOUD)
			else
				Explode(piece, SFX.SHATTER + SFX.NO_HEATCLOUD)
			end
			Hide(piece)
		end
		return 3
	else
		for count, piece in pairs(piecetable) do
			randomnumber = math.random(1,2)
			if randomnumber == 1 then
				if piece == base then 
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL + SFX.SHATTER) 
				else
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
				end
			elseif randomnumber == 2 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.SHATTER + SFX.NO_HEATCLOUD)
			else
				Explode(piece, SFX.SHATTER + SFX.NO_HEATCLOUD)
			end
			Hide(piece)
		end
		return 3
	end
end
