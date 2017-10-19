local tube1, tube2, base, wake, wake2 = piece("tube1", "tube2", "base", "wake", "wake2")

SIG_AIM = 2
SIG_AIM_2 = 4
SIG_MOVE = 8
Surfaced = false
piecetable = {tube1, tube2, base, wake}
function script.Create()
		local sx,sy,sz,ox,oy,oz,vt, tt,pa, disabled = Spring.GetUnitCollisionVolumeData(unitID)
		local ix,iy,iz,impx,impy,impz,iapx,iapy,iapz = Spring.GetUnitPosition(unitID, true, true)
		mpx, mpy, mpz =  impx - ix, impy - iy, impz - iz
	apx, apy, apz = iapx - ix, iapy - iy, iapz - iz
	f = 0
	-- Spring.SetUnitMaxRange(unitID, 310)
end
function Surface()
Spring.UnitScript.SetSignalMask(1)
	while f < math.pi do
		Move(base, 2, (-math.cos(f)+1)*10)
		-- Spring.SetUnitCollisionVolumeData(unitID, sx, sy, sz, ox, oy + (-math.cos(f)+1)*1.33,oz, vt, tt, pa)
		Spring.SetUnitMidAndAimPos(unitID, mpx, mpy + (-math.cos(f)+1)*15, mpz, apx, apy + (-math.cos(f)+1)*15, apz, true)
		f = f + math.pi/125
		-- Spring.Echo(f)
		Sleep(1)
	end
Spring.SetUnitArmored(unitID, false)

Surfaced = true
end

function Drown()
Surfaced = false

Spring.UnitScript.SetSignalMask(2)
	while f > 0 do
		Move(base, 2, (-math.cos(f)+1)*10)
		-- Spring.SetUnitCollisionVolumeData(unitID, sx, sy, sz, ox, oy + (-math.cos(f)+1)*1.33,oz, vt, tt, pa)
		Spring.SetUnitMidAndAimPos(unitID, mpx, mpy + (-math.cos(f)+1)*15, mpz, apx, apy + (-math.cos(f)+1)*15, apz, true)
		f = f - math.pi/125
		-- Spring.Echo(f)
		Sleep(1)
	end
Spring.SetUnitArmored(unitID, false)
Surfaced = false
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
	StartThread(Surface)
	Signal(2)
	while Surfaced ~= true do
	Sleep(10)
	end
	if Surfaced == true then
	Signal(27)
	StartThread(Restore, 10000)
	return (true)
	else
	return (false)
	end
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
	if weapon == 2 then
	Signal(27)
	StartThread(Restore, 10000)
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
