-- Lua unit script for Military Vehicles (Main Battle Tank & MRAP 4x4)
local base = piece("base")
local hull = piece("hull")
local turret = piece("turret")
local barrel = piece("barrel")
local flare = piece("flare")

local SIG_AIM = 2

local function RestoreAfterDelay()
	Sleep(4000)
	Turn(turret, y_axis, 0, math.rad(90))
	Turn(barrel, x_axis, 0, math.rad(45))
end

function script.Create()
	Hide(flare)
end

function script.AimFromWeapon1()
	return turret
end

function script.QueryWeapon1()
	return flare
end

function script.AimWeapon1(heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Turn(turret, y_axis, heading, math.rad(160))
	Turn(barrel, x_axis, -pitch, math.rad(90))
	WaitForTurn(turret, y_axis)
	WaitForTurn(barrel, x_axis)
	StartThread(RestoreAfterDelay)
	return true
end

function script.FireWeapon1()
	EmitSfx(flare, 1024)
	Move(barrel, z_axis, -2.5, 25.0)
	Sleep(120)
	Move(barrel, z_axis, 0.0, 6.0)
end

function script.Killed(recentDamage, maxHealth)
	Explode(turret, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE)
	Explode(barrel, SFX.FALL + SFX.SMOKE)
	return 1
end
