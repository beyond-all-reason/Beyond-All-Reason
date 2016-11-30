base, patch, wing4, wing3, link, jet2, jet1, leg6, leg5, leg4, leg3, leg2, leg1, wing2, wing1, flare = piece('base', 'patch', 'wing4', 'wing3', 'link', 'jet2', 'jet1', 'leg6', 'leg5', 'leg4', 'leg3', 'leg2', 'leg1', 'wing2', 'wing1', 'flare')
local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, patch, wing4, wing3, link, wing2, wing1})
	Hide(flare)
	Move(link, y_axis, 0, 5000)
	script.CloseWings()
end

common = include("headers/common_includes_lus.lua")

function script.CloseWings()
	Turn(wing3, y_axis, -20, 1)
	Turn(wing4, y_axis, 20, 1)
end

function script.OpenWings()
	Turn(wing3, y_axis, 0, 1)
	Turn(wing4, y_axis, -0, 1)
end


function script.StartMoving()
   isMoving = true
   script.OpenWings()
end

function script.StopMoving()
   isMoving = false
   script.CloseWings()
end   

function script.TransportPickup ( passengerID )
	UnitScript.AttachUnit ( link, passengerID )
end

local function RestoreAfterDelay()
	Sleep(2000)
end		

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return base
end

function script.QueryWeapon(weaponID)
	--Spring.Echo("QueryWeapon: FireWeapon")
	return flare
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.FireWeapon(weaponID)
	--Spring.Echo("FireWeapon: FireWeapon")
	--EmitSfx (firepoint1, 1024)
end

function script.Killed()
		Explode(base, SFX.EXPLODE_ON_HIT)
		Explode(wing3, SFX.EXPLODE_ON_HIT)
		Explode(wing4, SFX.EXPLODE_ON_HIT)
		Explode(patch, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end