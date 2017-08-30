base, patch, wing4, wing3, link, jet2, jet1, leg6, leg5, leg4, leg3, leg2, leg1, wing2, wing1, flare = piece('base', 'patch', 'wing4', 'wing3', 'link', 'jet2', 'jet1', 'leg6', 'leg5', 'leg4', 'leg3', 'leg2', 'leg1', 'wing2', 'wing1', 'flare')
local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, patch, wing4, wing3, link, wing2, wing1})
	Hide(flare)
	Move(link, y_axis, 0, 5000)
	script.CloseWingsInstantly()
end

common = include("headers/common_includes_lus.lua")

--This is unfortunately necessary due to the fact that the model is a 3do
function script.CloseWingsInstantly()
	Turn(wing3, y_axis, -20, 20)
	Turn(wing4, y_axis, 20, 20)
end

function script.CloseWings()
	Turn(wing3, y_axis, -20, 1)
	Turn(wing4, y_axis, 20, 1)
end

function script.OpenWingsPartially()
	Turn(wing3, y_axis, 0, 1)
	Turn(wing4, y_axis, -0, 1)
	
end

function script.OpenWings()
	Turn(wing3, y_axis, -0.7, 1)
	Turn(wing4, y_axis, 0.7, 1)
end


function script.StartMoving()
   isMoving = true
end

function script.StopMoving()
   isMoving = false
end   

function script.MoveRate(moveRate)
	if moveRate == 0 then
		script.CloseWings()
	end
	if moveRate == 1 then
		script.OpenWingsPartially()
	end
	if moveRate == 2 then
		script.OpenWings()
	end
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
		Explode(base, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(wing3, SFX.SHATTER + SFX.NO_HEATCLOUD)
		Explode(wing4, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(patch, SFX.SHATTER + SFX.NO_HEATCLOUD)
		Explode(leg1, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(leg3, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end