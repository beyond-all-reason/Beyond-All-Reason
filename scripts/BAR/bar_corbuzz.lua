local flare1 = piece 'flare1' 
local flare2 = piece 'flare2' 
local flare3 = piece 'flare3' 
local flare4 = piece 'flare4' 
local flare5 = piece 'flare5' 
local flare6 = piece 'flare6' 
local base = piece 'base' 
local turret = piece 'turret' 
local barrel1 = piece 'barrel1' 
local barrel2 = piece 'barrel2' 
local barrel3 = piece 'barrel3' 
local barrel4 = piece 'barrel4' 
local barrel5 = piece 'barrel5' 
local barrel6 = piece 'barrel6' 
local sleeve1 = piece 'sleeve1' 
local sleeve2 = piece 'sleeve2' 
local sleeve3 = piece 'sleeve3' 
local sleeve4 = piece 'sleeve4' 
local sleeve5 = piece 'sleeve5' 
local sleeve6 = piece 'sleeve6' 
local spindle = piece 'spindle' 

local gun_1 = 0

local dmgPieces = { piece "turret" }

-- Signal definitions
local SIG_AIM = 1

-- includes
	include "dmg_smoke.lua"

function script.Create()

	Hide(flare1)
	Hide(flare2)
	Hide(flare3)
	Hide(flare4)
	Hide(flare5)
	Hide(flare6)
	--todo rotate flare in model 
	Turn( flare2 , x_axis, math.rad(-60.005495) )
	Turn( flare3 , x_axis, math.rad(-120.01099) ) 
	Turn( flare4 , x_axis, math.rad(-180.016485) )
	Turn( flare5 , x_axis, math.rad(-240.02198) )
	Turn( flare6 , x_axis, math.rad(-300.027475) )
	StartThread(dmgsmoke, dmgPieces)	 
end

function script.AimWeapon1(heading, pitch)
	Signal( SIG_AIM)
	SetSignalMask( SIG_AIM)
	Turn( turret , y_axis, heading, math.rad(15.000000) )
	Turn( spindle , x_axis,(math.rad(60.005495) * gun_1) - pitch, math.rad(200.038462) )
	--Spring.Echo(gun_1,gun_1*60)
	WaitForTurn(turret, y_axis)
	WaitForTurn(spindle, x_axis)
	return true
end

function script.FireWeapon1()
	if  gun_1 == 0  then
		Move(barrel1 , z_axis, -6.000000, 9000  )
		EmitSfx( flare1,  1024 + 0 )
		Sleep( 100)
		Move( barrel1 , z_axis, 0.000000 , 6.000000 )
	end
	if  gun_1 == 1  then
	
		Move(barrel2 , y_axis, -5.000000  )
		Move(barrel2 , z_axis, -3.000000  )
		EmitSfx( flare2,  1024 + 0 )
		Sleep( 100)
		Move( barrel2 , y_axis, 0.000000 , 5.000000 )
		Move( barrel2 , z_axis, 0.000000 , 3.000000 )
	end
	if  gun_1 == 2  then
	
		Move(barrel3 , y_axis, -5.000000  )
		Move(barrel3 , z_axis, 3.000000  )
		EmitSfx( flare3,  1024 + 0 )
		Sleep( 100)
		Move(barrel3 , y_axis, 0.000000 , 5.000000 )
		Move(barrel3 , z_axis, 0.000000 , 3.000000 )
	end
	if  gun_1 == 3  then
	
		Move(barrel4 , z_axis, 6.000000  )
		EmitSfx(flare4,  1024 + 0 )
		Sleep( 100)
		Move(barrel4 , z_axis, 0.000000 , 6.000000 )
	end
	if  gun_1 == 4  then
	
		Move( barrel5 , y_axis, 5.000000  )
		Move( barrel5 , z_axis, 3.000000  )
		EmitSfx( flare5,  1024 + 0 )
		Sleep( 100)
		Move( barrel5 , y_axis, 0.000000 , 5.000000 )
		Move( barrel5 , z_axis, 0.000000 , 3.000000 )
	end
	if  gun_1 == 5  then
	
		Move( barrel6 , y_axis, 5.000000  )
		Move( barrel6 , z_axis, -3.000000  )
		EmitSfx( flare6,  1024 + 0 )
		Sleep( 100)
		Move( barrel6 , y_axis, 0.000000 , 5.000000 )
		Move( barrel6 , z_axis, 0.000000 , 3.000000 )
	end
	gun_1 = gun_1 + 1
	if  gun_1 == 6  then
	
		gun_1 = 0
	end
end

function script.QueryWeapon1(piecenum)

	if  gun_1 == 0  then
	
		return flare1
	end
	if  gun_1 == 1  then
	
		return flare2
	end
	if  gun_1 == 2  then
	
		return flare3
	end
	if  gun_1 == 3  then
	
		return flare4
	end
	if  gun_1 == 4  then
	
		return flare5
	end
	if  gun_1 == 5  then
	
		return flare6
	end
end

function script.AimFromWeapon1()
	return spindle
end

	function script.Killed(recentDamage, maxHealth)
		local severity = recentDamage / maxHealth

		if (severity <= .25) then
			Explode(base, SFX.EXPLODE)
			Explode(barrel1, SFX.NONE)
			Explode(barrel2, SFX.NONE)
			Explode(barrel3, SFX.NONE)
			Explode(barrel4, SFX.NONE)
			Explode(barrel5, SFX.NONE)
			Explode(barrel6, SFX.NONE)
			return 1 -- corpsetype

		elseif (severity <= .5) then
			Explode(base, SFX.EXPLODE)
			Explode(barrel1,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel2,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel3,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel4,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel5,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel6,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			return 2 -- corpsetype
		else
			Explode(base, SFX.EXPLODE)
			Explode(barrel1,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel2,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel3,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel4,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel5,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			Explode(barrel6,  SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
			return 3 -- corpsetype
		end
	end