-- juggernaut --
-- a unit script for BA remake --
-- by FireStorm --

-- s3o Pieces

local base = piece "base"
local torso = piece "torso"
local tail = piece "tail"

local turret = piece "turret"
local lbarrel = piece "lbarrel"
local rbarrel = piece "rbarrel"

local lbarrelflare = piece "lbarrelflare"
local rbarrelflare = piece "rbarrelflare"

local lbleg = piece "lbleg"
local lbfoot = piece "lbfoot"
local lfleg = piece "lfleg"
local lffoot = piece "lffoot"

local rbleg = piece "rbleg"
local rbfoot = piece "rbfoot"
local rfleg = piece "rfleg"
local rffoot = piece "rffoot"

local llaser = piece "llaser"
local rlaser = piece "rlaser"

local llaserflare = piece "llaserflare"
local rlaserflare = piece "rlaserflare"

local topturret = piece "topturret"
local toplaser = piece "toplaser"

local toplaserflare = piece "toplaserflare"

-- Signals
local SIG_stop = 2
local SIG_walk = 4
local SIG_aim1 = 8
local SIG_aim2 = 16
local SIG_aim3 = 32
local SIG_aim4 = 64

-- Variables And Speed-ups
local VAR_speed_turn_turret_y = math.rad(90)
local VAR_speed_turn_barrel_x = math.rad(50)
local VAR_speed_bump_torso = 9
local currBarrel = 1

-- Walk Animation
local function walk()
	SetSignalMask( SIG_walk )
	local VAR_sleep = 250
	local VAR_speed = 1
	while true do
		Spin(tail, x_axis, -2, 2)
        Turn(lfleg, y_axis, math.rad(0), 0.2)
        Turn(rfleg, y_axis, math.rad(0), 0.2)

		--frame1 (first of right back leg cycle)
		Move(torso, y_axis, 18, VAR_speed_bump_torso)
		Move(torso, z_axis, 12, VAR_speed_bump_torso)
		Turn(torso, x_axis, math.rad(6), VAR_speed)
		
		-- (1/2 cycle) 6 frames ahead of normal cycle
		Turn(lbleg, x_axis, math.rad(105), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-80), VAR_speed)
		-- (1/4 cycle) 3 frames ahead of normal cycle
		Turn(lfleg, x_axis, math.rad(10), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-30), VAR_speed)
		-- normal cycle
		Turn(rbleg, x_axis, math.rad(60), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-60), VAR_speed)
        -- (3/4 cycle) 9 frames ahead of normal cycle
		Turn(rfleg, x_axis, math.rad(10), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-10), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame2
		Turn(lbleg, x_axis, math.rad(120), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-70), VAR_speed)
		 
		Turn(lfleg, x_axis, math.rad(0), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-30), VAR_speed)
		
		Turn(rbleg, x_axis, math.rad(30), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-30), VAR_speed)

		Turn(rfleg, x_axis, math.rad(20), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-20), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame3
  		Turn(lbleg, x_axis, math.rad(135), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-60), VAR_speed)

		Turn(lfleg, x_axis, math.rad(-10), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-30), VAR_speed)
		
		Turn(rbleg, x_axis, math.rad(0), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-0), VAR_speed)

		Turn(rfleg, x_axis, math.rad(30), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-30), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame4 (first of left front leg cycle)
		Move(torso, y_axis, 12, VAR_speed_bump_torso)
		Move(torso, z_axis, 0, VAR_speed_bump_torso)

		Turn(lbleg, x_axis, math.rad(120), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-70), VAR_speed)

		Turn(lfleg, x_axis, math.rad(-10), VAR_speed) --or -20
		Turn(lffoot, x_axis, math.rad(-20), VAR_speed)

        Turn(rbleg, x_axis, math.rad(30), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-30), VAR_speed)

		Turn(rfleg, x_axis, math.rad(40), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-30), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame5
		Turn(lbleg, x_axis, math.rad(105), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-80), VAR_speed)

		Turn(lfleg, x_axis, math.rad(-10), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-10), VAR_speed)

		Turn(rbleg, x_axis, math.rad(60), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-60), VAR_speed)

		Turn(rfleg, x_axis, math.rad(30), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-30), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame6
  		Turn(lbleg, x_axis, math.rad(90), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-90), VAR_speed)

		Turn(lfleg, x_axis, math.rad(0), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-0), VAR_speed)

		Turn(rbleg, x_axis, math.rad(90), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-90), VAR_speed)

		Turn(rfleg, x_axis, math.rad(20), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-30), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame7 (first of left back leg cycle)
        Move(torso, y_axis, 18, VAR_speed_bump_torso)
		Move(torso, z_axis, 12, VAR_speed_bump_torso)
		
        Turn(lbleg, x_axis, math.rad(60), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-60), VAR_speed)

  		Turn(lfleg, x_axis, math.rad(10), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-10), VAR_speed)
		
		Turn(rbleg, x_axis, math.rad(105), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-80), VAR_speed)

		Turn(rfleg, x_axis, math.rad(10), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-30), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame8
        Turn(lbleg, x_axis, math.rad(30), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-30), VAR_speed)
		
  		Turn(lfleg, x_axis, math.rad(20), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-20), VAR_speed)
		
		Turn(rbleg, x_axis, math.rad(120), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-70), VAR_speed)

		Turn(rfleg, x_axis, math.rad(0), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-30), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame9
        Turn(lbleg, x_axis, math.rad(0), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-0), VAR_speed)

  		Turn(lfleg, x_axis, math.rad(30), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-30), VAR_speed)

		Turn(rbleg, x_axis, math.rad(135), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-60), VAR_speed)

		Turn(rfleg, x_axis, math.rad(-10), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-30), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame10 (first of right front leg cycle)
		Move(torso, y_axis, 12, VAR_speed_bump_torso)
		Move(torso, z_axis, 0, VAR_speed_bump_torso)

        Turn(lbleg, x_axis, math.rad(30), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-30), VAR_speed)

  		Turn(lfleg, x_axis, math.rad(40), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-30), VAR_speed)

		Turn(rbleg, x_axis, math.rad(120), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-70), VAR_speed)

		Turn(rfleg, x_axis, math.rad(-10), VAR_speed) --or -20
		Turn(rffoot, x_axis, math.rad(-20), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame11
        Turn(lbleg, x_axis, math.rad(60), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-60), VAR_speed)

  		Turn(lfleg, x_axis, math.rad(30), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-30), VAR_speed)

		Turn(rbleg, x_axis, math.rad(105), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-80), VAR_speed)

		Turn(rfleg, x_axis, math.rad(-10), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-10), VAR_speed)
		Sleep(VAR_sleep)
		
		--frame12
		Turn(lbleg, x_axis, math.rad(90), VAR_speed)
		Turn(lbfoot, x_axis, math.rad(-90), VAR_speed)

  		Turn(lfleg, x_axis, math.rad(20), VAR_speed)
		Turn(lffoot, x_axis, math.rad(-30), VAR_speed)

		Turn(rbleg, x_axis, math.rad(90), VAR_speed)
		Turn(rbfoot, x_axis, math.rad(-90), VAR_speed)

		Turn(rfleg, x_axis, math.rad(0), VAR_speed)
		Turn(rffoot, x_axis, math.rad(-0), VAR_speed)
		Sleep(VAR_sleep)

		end
end

-- Stop Animation
local function stop()
	SetSignalMask( SIG_stop )
	Signal( SIG_stop )
	Signal( SIG_walk )
	local VAR_speed= 1		

    Move(torso, y_axis, 0, 20)
    Move(torso, z_axis, 0, VAR_speed_bump_torso)
	Turn(torso, x_axis, math.rad(0), 0.5)
    
    Turn(lfleg, x_axis, math.rad(0), VAR_speed)
    Turn(lffoot, x_axis, math.rad(0), VAR_speed)
	
	Turn(rfleg, x_axis, math.rad(0), VAR_speed)
    Turn(rffoot, x_axis, math.rad(0), VAR_speed)

    Turn(lbleg, x_axis, math.rad(0), 2)
    Turn(lbfoot, x_axis, math.rad(0), VAR_speed)
	
	Turn(rbleg, x_axis, math.rad(0), 2)
    Turn(rbfoot, x_axis, math.rad(0), VAR_speed)

    Turn(lfleg, y_axis, math.rad(6), 0.2)
    Turn(rfleg, y_axis, math.rad(-6), 0.2)

	StopSpin(tail, x_axis, -1, 1)
	Signal( SIG_stop )
end

local function RestoreAfterDelay(unitID)
	local VAR_speed = 1
	Sleep(3000)
    Move(torso, y_axis, 0, VAR_speed)
	WaitForMove(torso, y_axis)

    Turn(turret, y_axis, math.rad(0), VAR_speed_turn_turret_y)
   	WaitForTurn(turret, x_axis)

	Turn(lbarrel, x_axis, math.rad(0), VAR_speed)
    Turn(rbarrel, x_axis, math.rad(0), VAR_speed)
   	WaitForTurn(rbarrel, x_axis)

	Turn(topturret, y_axis, math.rad(0), VAR_speed)
    Turn(toplaser, x_axis, math.rad(0), VAR_speed)
	Turn(llaser, y_axis, math.rad(0), VAR_speed)
	Turn(rlaser, y_axis, math.rad(0), VAR_speed)
end

-- Shooting Animation
local function fire1()
  if (currBarrel == 1) then
	EmitSfx(lbarrelflare,1024)
  else
    	EmitSfx(rbarrelflare,1024)
  end
	Sleep(1)
end	

local function fire2()
	Sleep(1)
end

local function fire3()
	Sleep(1)
end

local function fire4()
	Sleep(1)
end

-- Call-Ins 

------

function script.Create(unitID)

end

------

function script.StartMoving()
	StartThread( walk )
end

function script.StopMoving()
	StartThread( stop )
end

------

function script.AimFromWeapon1() return turret end

function script.AimWeapon1( heading, pitch )
	Signal( SIG_aim1 )
	SetSignalMask( SIG_aim1 )
	-- turn turret to target
	Turn(turret, y_axis, heading, VAR_speed_turn_turret_y)
	WaitForTurn(turret, y_axis)
	Turn(lbarrel, x_axis, -pitch, VAR_speed_turn_barrel_x)
    Turn(rbarrel, x_axis, -pitch, VAR_speed_turn_barrel_x)
	WaitForTurn(lbarrel, x_axis)
	WaitForTurn(rbarrel, x_axis)
	StartThread( RestoreAfterDelay )
	return true
end

function script.QueryWeapon1()
	if (currBarrel == 1) then
    return lbarrelflare
    else
    return rbarrelflare
    end
end

function script.AimFromWeapon2() return topturret end
function script.AimWeapon2( heading, pitch )
    Signal( SIG_aim2 )
	SetSignalMask( SIG_aim2 )
	Turn(topturret, y_axis, heading, 2)
	WaitForTurn(topturret, y_axis)
	Turn(toplaser, x_axis, -pitch, VAR_speed_turn_barrel_x)
	WaitForTurn(toplaser, x_axis)
	StartThread( RestoreAfterDelay )
	return true
end
function script.QueryWeapon2() return toplaserflare end

function script.AimFromWeapon3() return llaser end
function script.AimWeapon3( heading )
    Signal( SIG_aim3 )
	SetSignalMask( SIG_aim3 )
	Turn(llaser, y_axis, heading, 1, 1)
	WaitForTurn(llaser, y_axis)
	StartThread( RestoreAfterDelay )
	return true
end
function script.QueryWeapon3() return llaserflare end

function script.AimFromWeapon4() return rlaser end
function script.AimWeapon4( heading )
    Signal( SIG_aim4 )
	SetSignalMask( SIG_aim4 )
	Turn(rlaser, y_axis, heading, 1, 1)
	WaitForTurn(rlaser, y_axis)
	StartThread( RestoreAfterDelay )
	return true
end
function script.QueryWeapon4() return rlaserflare end

------

function script.FireWeapon1()
	if currBarrel == 1 then
   	fire1()
	end

	if currBarrel == 2 then
	fire1()
	end

	currBarrel = currBarrel + 1
	if currBarrel == 3 then currBarrel = 1
	end
end

function script.FireWeapon2()
	fire2()
end

function script.FireWeapon3()
	fire3()
end

function script.FireWeapon4()
	fire4()
end

------

function script.Killed(recentDamage, maxHealth)
		local severity = recentDamage/maxHealth
	if severity < 0.25 then

		Explode(torso, SFX.NONE)
        Explode(tail, SFX.NONE)

		Explode(turret, SFX.NONE)
        Explode(lbarrel, SFX.NONE)
		Explode(rbarrel, SFX.NONE)

		Explode(llaser, SFX.NONE)
        Explode(rlaser, SFX.NONE)
        Explode(toplaser, SFX.NONE)

        Explode(lbleg, SFX.NONE)
        Explode(lbfoot, SFX.NONE)
        Explode(lfleg, SFX.NONE)
        Explode(lffoot, SFX.NONE)
        
        Explode(rbleg, SFX.NONE)
        Explode(rbfoot, SFX.NONE)
        Explode(rfleg, SFX.NONE)
        Explode(rffoot, SFX.NONE)
        
		return 1
	elseif severity<0.5 then

		Explode(torso, SFX.SHATTER)
		Explode(tail, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)

		Explode(turret, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
        Explode(lbarrel, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
        Explode(rbarrel, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)

		Explode(llaser, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
        Explode(rlaser, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)
        Explode(toplaser, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE)

        Explode(lbleg, SFX.SHATTER)
        Explode(lbfoot, SFX.SHATTER)
        Explode(lfleg, SFX.SHATTER)
        Explode(lffoot, SFX.SHATTER)

        Explode(rbleg, SFX.SHATTER)
        Explode(rbfoot, SFX.SHATTER)
        Explode(rfleg, SFX.SHATTER)
        Explode(rffoot, SFX.SHATTER)

		return 2
	else

		Explode(torso, SFX.SHATTER)
		Explode(tail, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE + SFX.NO_HEATCLOUD)

		Explode(turret, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE + SFX.NO_HEATCLOUD)
        Explode(lbarrel, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE + SFX.NO_HEATCLOUD)
        Explode(rbarrel, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE + SFX.NO_HEATCLOUD)

		Explode(llaser, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE + SFX.NO_HEATCLOUD)
        Explode(rlaser, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE + SFX.NO_HEATCLOUD)
        Explode(toplaser, SFX.SMOKE + SFX.FIRE + SFX.EXPLODE + SFX.NO_HEATCLOUD)

        Explode(lbleg, SFX.SHATTER + SFX.NO_HEATCLOUD)
        Explode(lbfoot, SFX.SHATTER + SFX.NO_HEATCLOUD)
        Explode(lfleg, SFX.SHATTER + SFX.NO_HEATCLOUD)
        Explode(lffoot, SFX.SHATTER + SFX.NO_HEATCLOUD)

        Explode(rbleg, SFX.SHATTER + SFX.NO_HEATCLOUD)
        Explode(rbfoot, SFX.SHATTER + SFX.NO_HEATCLOUD)
        Explode(rfleg, SFX.SHATTER + SFX.NO_HEATCLOUD)
        Explode(rffoot, SFX.SHATTER + SFX.NO_HEATCLOUD)

		return 3
	end
end

	