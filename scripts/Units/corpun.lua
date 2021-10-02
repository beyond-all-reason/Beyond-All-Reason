--pieces
local base = piece "base"
local turret = piece "turret"
local barrel1 = piece "barrel1"
local barrel2 = piece "barrel2"
local sleeves = piece "sleeves"
local flare1 = piece "flare1"
local flare2 = piece "flare2"
local currBarrel = 1
local dmgPieces = { piece "base", piece "flare1", piece "flare2" }

-- includes
include "dmg_smoke.lua"

--signals
local SIG_AIM = 1

function script.Create()
	Hide(flare1)
	Hide(flare2)
	StartThread(dmgsmoke, dmgPieces)
end

local function RestoreAfterDelay(unitID)
	Sleep(2500)
	Turn(turret, x_axis, 0, math.rad(50))
	Turn(sleeves, x_axis, 0, math.rad(50))
end


function script.QueryWeapon1()
	if (currBarrel == 1) then 
		return flare1
	else 
		return flare2
	end
end

function script.AimFromWeapon1()
	return turret
end

function script.AimWeapon1( heading, pitch )
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(turret, y_axis, heading, math.rad(30.005495))
		Turn(sleeves, x_axis, -pitch, math.rad(45.005495))
		WaitForTurn(turret, y_axis)
		WaitForTurn(sleeves, x_axis)
		return true
end

function script.FireWeapon1()
	if currBarrel == 1 then
		EmitSfx(flare1, 1024+0)
		Move (barrel1, z_axis, -1.500000)
		Sleep (150)
		Move (barrel1, z_axis, 0.000000, 1.000000)
	end
	
	if currBarrel == 2 then
		EmitSfx(flare2, 1024+0)
		Move (barrel2, z_axis, -1.500000)
		Sleep (150)
		Move (barrel2, z_axis, 0.000000, 1.000000)
	end

	currBarrel = currBarrel + 1

	if currBarrel == 3 then
		currBarrel = 1
	end
end

function script.QueryWeapon2()
	if (currBarrel == 1) then 
		return flare1
	else 
		return flare2
	end
end
	
function script.AimFromWeapon2()
	return turret
end
	
function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage / maxHealth

	if severity <= .25 then
		Explode(turret, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(sleeves, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(barrel1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(barrel2, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		return 1 -- corpsetype
	elseif severity <= .5 then
		Explode(turret, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(sleeves, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(barrel1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(barrel2, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		return 2 -- corpsetype
	else
		Explode(turret, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(sleeves, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(barrel1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(barrel2, SFX.EXPLODE + SFX.NO_HEATCLOUD)
		return 3 -- corpsetype
	end
end
