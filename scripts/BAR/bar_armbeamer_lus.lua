base, turret, sleeve, barrel, flare = piece('base', 'turret', 'sleeve', 'barrel', 'flare')

local SIG_AIM = {}

function script.Create()

end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(turret, y_axis, 0, 8.72)
	Turn(sleeve, x_axis, 0, 4.36)
end		

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return turret
end

function script.QueryWeapon(weaponID)
	--Spring.Echo("QueryWeapon: FireWeapon")
	return flare
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Turn(turret, y_axis, heading, 8.72)
	Turn(sleeve, x_axis, -pitch, 4.36)
	WaitForTurn(turret, y_axis)
	WaitForTurn(sleeve, x_axis)
	--StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.FireWeapon(weaponID)
	--Spring.Echo("FireWeapon: FireWeapon")
	--EmitSfx (flare, 1024)
end

function script.Killed()
		--Explode(base, SFX.SHATTER + SFX.NO_HEATCLOUD)
		Explode(barrel, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(turret, SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(sleeve, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		return 3   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end
