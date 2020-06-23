include("include/util.lua");

local torso, turret = piece('torso', 'turret')
local rbarrel, lbarrel, rflare, lflare = piece('rbarrel','lbarrel', 'rflare', 'lflare')
local rfleg, rffoot, lfleg, lffoot, rbleg, rbfoot, lbleg, lbfoot =  piece('rfleg', 'rffoot', 'lfleg', 'lffoot', 'rbleg', 'rbfoot', 'lbleg', 'lbfoot')

local SIG_WALK = 1
local SIG_AIM = 2
local SIG_RESTORE = 4

--------------------------------------------------------------------------------------
local sfxNone=SFX.NONE
local sfxShatter=SFX.SHATTER
local sfxSmoke=SFX.SMOKE
local sfxFire=SFX.FIRE
local sfxFall = SFX.FALL
local sfxExplode = SFX.EXPLODE
--------------------------------------------------------------------------------------

local gunPieces = {
    [0] = {flare = lflare, recoil = lbarrel},
    [1] = {flare = rflare, recoil = rbarrel},
}
local gun_1 = 0

local SPEED = 1.9

local function Walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)

	--Turn(torso, x_axis, 0, math.rad(20))
	--Turn(torso, z_axis, 0, math.rad(20))
	Move(torso, y_axis, 0, 10)

	while true do

		local speedmult = (1 - (Spring.GetUnitRulesParam(unitID,"slowState") or 0))*SPEED

		-- right
		Turn( rfleg, x_axis, math.rad(40),math.rad(40)*speedmult)
		Turn( rffoot, x_axis, math.rad(-40),math.rad(40)*speedmult)

		Turn( rbleg, x_axis, math.rad(5),math.rad(10)*speedmult)
		Turn( rbfoot, x_axis, math.rad(-40),math.rad(80)*speedmult)

		Move( rfleg, y_axis, 0.6,1.2*speedmult)
		Move( rbleg, y_axis, 0.6,1.2*speedmult)

		-- left
		Turn( lfleg, x_axis, math.rad(-20),math.rad(120)*speedmult)
		Turn( lffoot, x_axis, math.rad(35),math.rad(150)*speedmult)

		Turn( lbleg, x_axis, math.rad(0),math.rad(45)*speedmult)
		Turn( lbfoot, x_axis, math.rad(0),math.rad(46)*speedmult)

		Move( lfleg, y_axis, 1,4.4*speedmult)
		Move( lbleg, y_axis, 1,2*speedmult)

		Move( torso, y_axis, 1.5,1*speedmult)
		Sleep(500/speedmult) -- ****************

		-- right
		Turn( rbleg, x_axis, math.rad(-50),math.rad(110)*speedmult)
		Turn( rbfoot, x_axis, math.rad(50),math.rad(180)*speedmult)

		Move( rfleg, y_axis, 3.2,5.2*speedmult)
		Move( rbleg, y_axis, 2,2.8*speedmult)

		-- left
		Turn( lfleg, x_axis, math.rad(0),math.rad(40)*speedmult)
		Turn( lffoot, x_axis, math.rad(0),math.rad(80)*speedmult)

		Move( lfleg, y_axis, 0,2*speedmult)
		Move( lbleg, y_axis, 0,2*speedmult)

		Move( torso, y_axis, 1,1*speedmult)
		Sleep(500/speedmult) -- ****************

		-- right
		Turn( rfleg, x_axis, math.rad(-20),math.rad(120)*speedmult)
		Turn( rffoot, x_axis, math.rad(35),math.rad(150)*speedmult)

		Turn( rbleg, x_axis, math.rad(0),math.rad(45)*speedmult)
		Turn( rbfoot, x_axis, math.rad(0),math.rad(46)*speedmult)

		Move( rfleg, y_axis, 1,4.4*speedmult)
		Move( rbleg, y_axis, 1,2*speedmult)


		-- left
		Turn( lfleg, x_axis, math.rad(40),math.rad(40)*speedmult)
		Turn( lffoot, x_axis, math.rad(-40),math.rad(40)*speedmult)

		Turn( lbleg, x_axis, math.rad(5),math.rad(10)*speedmult)
		Turn( lbfoot, x_axis, math.rad(-40),math.rad(80)*speedmult)

		Move( lfleg, y_axis, 0.6,1.2*speedmult)
		Move( lbleg, y_axis, 0.6,1.2*speedmult)

		Move( torso, y_axis, 3,2*speedmult)
		Sleep(500/speedmult) -- ****************

		-- right
		Turn( rfleg, x_axis, math.rad(0),math.rad(40)*speedmult)
		Turn( rffoot, x_axis, math.rad(0),math.rad(80)*speedmult)

		Move( rfleg, y_axis, 0,2)
		Move( rbleg, y_axis, 0,2)

		-- left
		Turn( lbleg, x_axis, math.rad(-50),math.rad(110)*speedmult)
		Turn( lbfoot, x_axis, math.rad(50),math.rad(180)*speedmult)

		Move( lfleg, y_axis, 3.2,5.2*speedmult)
		Move( lbleg, y_axis, 2,2.8*speedmult)

		Move( torso, y_axis, 1,1*speedmult)
		Sleep(500/speedmult) -- ****************
	end
end

function script.StartMoving()
	StartThread(Walk)
end

function script.StopMoving()
	Signal(SIG_WALK)

	Turn( rfleg, x_axis, math.rad(0),math.rad(60))
	Turn( rffoot, x_axis, math.rad(0),math.rad(60))

	Turn( rbleg, x_axis, math.rad(0),math.rad(60))
	Turn( rbfoot, x_axis, math.rad(0),math.rad(60))

	Move( rfleg, y_axis, 0,1)
	Move( rbleg, y_axis, 0,1)

	Turn( lfleg, x_axis, math.rad(0),math.rad(60))
	Turn( lffoot, x_axis, math.rad(0),math.rad(60))

	Turn( lbleg, x_axis, math.rad(0),math.rad(60))
	Turn( lbfoot, x_axis, math.rad(0),math.rad(60))

	Move( lfleg, y_axis, 0,1)
	Move( lbleg, y_axis, 0,1)

end

function script.Create()
	Turn( rfleg, x_axis, math.rad(0))
	Turn( rffoot, x_axis, math.rad(0))

	Turn( rbleg, x_axis, math.rad(0))
	Turn( rbfoot, x_axis, math.rad(0))
end

function script.QueryWeapon(num)
	if num == 1 then
		return gunPieces[gun_1].flare
	end
end

function script.AimFromWeapon(num)
	if num == 1 then
		return turret
	end
end

local function RestoreAfterDelay()
    Signal(SIG_RESTORE)
    SetSignalMask(SIG_RESTORE)
    Sleep(6000)
    Turn(turret, y_axis, 0, math.rad(90))
end

function script.AimWeapon(num, heading, pitch)
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(turret, y_axis, heading, math.rad(180))
		WaitForTurn(turret, y_axis)
		StartThread(RestoreAfterDelay)
		return true
end

function script.Shot(num)

	gun_1 = 1 - gun_1
	Move(gunPieces[gun_1].recoil, z_axis, -3)
	Move(gunPieces[gun_1].recoil, z_axis, 0, 3)

	--Sleep(250)
end

-- should also explode the leg pieces but I really cba...
function script.Killed(recentDamage, maxHealth)
    local severity = recentDamage/maxHealth
    if severity <= .25 then
        Explode(turret, sfxNone + SFX.NO_HEATCLOUD)
        Explode(torso, sfxNone + SFX.NO_HEATCLOUD)
        return 1
    elseif severity <= .5 then
        Explode(torso, sfxShatter + SFX.NO_HEATCLOUD)
        Explode(turret, sfxShatter + SFX.NO_HEATCLOUD)
        Explode(lbarrel, sfxFall + sfxSmoke + SFX.NO_HEATCLOUD)
        Explode(rbarrel, sfxFall + sfxSmoke + SFX.NO_HEATCLOUD)
        return 2
    else
        Explode(torso, sfxShatter + SFX.NO_HEATCLOUD)
        Explode(turret, sfxShatter + SFX.NO_HEATCLOUD)
        Explode(lbarrel, sfxFall + sfxSmoke + sfxFire + sfxExplode + SFX.NO_HEATCLOUD)
        Explode(rbarrel, sfxFall + sfxSmoke + sfxFire + sfxExplode + SFX.NO_HEATCLOUD)
        return 3
    end
end
