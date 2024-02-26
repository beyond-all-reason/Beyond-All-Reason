include("include/util.lua");
--------------------------------------------------------------------------------
-- pieces
--------------------------------------------------------------------------------
local pelvis, torso = piece("pelvis", "torso")
local rthigh, rleg, rfoot, lthigh, lleg, lfoot = piece("rthigh", "rleg", "rfoot", "lthigh", "lleg", "lfoot")
local lbturret, lbbarrel1, lbbarrel2, rbturret, rbbarrel1, rbbarrel2 = piece("lbturret", "lbbarrel1", "lbbarrel2", "rbturret", "rbbarrel1", "rbbarrel2")
local lbbarrel1, lbbarrel2, rbbarrel1, rbbarrel2 = piece("lbbarrel1", "lbbarrel2", "rbbarrel1", "rbbarrel2")
local luparm, llarm, lfbarrel1, lfbarrel2, lfbarrel1, lfbarrel2 = piece("luparm", "llarm", "lfbarrel1", "lfbarrel2", "lfbarrel1", "lfbarrel2")
local ruparm, rlarm, rfbarrel1, rfbarrel2, rfbarrel1, rfbarrel2 = piece("ruparm", "rlarm", "rfbarrel1", "rfbarrel2", "rfbarrel1", "rfbarrel2")
local lfflare1, lfflare2, rfflare1, rfflare2 =piece("lfflare1", "lfflare2", "rfflare1", "rfflare2")
local lbflare, rbflare = piece ("lbflare", "rbflare")
local gunIndex = {1,1,1}
local flares = {
    {lfflare1, lfflare2, rfflare1, rfflare2},
    {lbflare, rbflare},
}

smokePiece = {torso}

--------------------------------------------------------------------------------
-- constants
local sfxNone=SFX.NONE
local sfxShatter=SFX.SHATTER
local sfxSmoke=SFX.SMOKE
local sfxFire=SFX.FIRE
local sfxFall = SFX.FALL
local sfxExplode = SFX.EXPLODE
--------------------------------------------------------------------------------
-- Signal definitions
local SIG_WALK = 1
local SIG_RESTORE = 8
local SIG_AIM = 2

local TORSO_SPEED_YAW = math.rad(240)
local ARM_SPEED_PITCH = math.rad(120)

local PACE = 2

local THIGH_FRONT_ANGLE = -math.rad(50)
local THIGH_FRONT_SPEED = math.rad(60) * PACE
local THIGH_BACK_ANGLE = math.rad(30)
local THIGH_BACK_SPEED = math.rad(60) * PACE
local SHIN_FRONT_ANGLE = math.rad(45)
local SHIN_FRONT_SPEED = math.rad(90) * PACE
local SHIN_BACK_ANGLE = math.rad(10)
local SHIN_BACK_SPEED = math.rad(90) * PACE

local ARM_FRONT_ANGLE = -math.rad(20)
local ARM_FRONT_SPEED = math.rad(22.5) * PACE
local ARM_BACK_ANGLE = math.rad(10)
local ARM_BACK_SPEED = math.rad(22.5) * PACE
--[[
local FOREARM_FRONT_ANGLE = -math.rad(15)
local FOREARM_FRONT_SPEED = math.rad(40) * PACE
local FOREARM_BACK_ANGLE = -math.rad(10)
local FOREARM_BACK_SPEED = math.rad(40) * PACE
]]--

local TORSO_ANGLE_MOTION = math.rad(10)
local TORSO_SPEED_MOTION = math.rad(15)*PACE

local LEG_JUMP_COIL_ANGLE = math.rad(15)
local LEG_JUMP_COIL_SPEED = math.rad(90)
local LEG_JUMP_RELEASE_ANGLE = math.rad(18)
local LEG_JUMP_RELEASE_SPEED = math.rad(420)

local UPARM_JUMP_COIL_ANGLE = math.rad(15)
local UPARM_JUMP_COIL_SPEED = math.rad(60)
local LARM_JUMP_COIL_ANGLE = math.rad(30)
local LARM_JUMP_COIL_SPEED = math.rad(90)
local UPARM_JUMP_RELEASE_ANGLE = math.rad(80)
local UPARM_JUMP_RELEASE_SPEED = math.rad(240)
local LARM_JUMP_RELEASE_ANGLE = math.rad(90)
local LARM_JUMP_RELEASE_SPEED = math.rad(360)

local RESTORE_DELAY = 6000


--------------------------------------------------------------------------------
-- vars
--------------------------------------------------------------------------------
local armsFree = true
local jumpDir = 1
local bJumping = false
local bSomersault = false

--------------------------------------------------------------------------------
-- funcs
--------------------------------------------------------------------------------
local function RestorePose()
        Turn(pelvis, x_axis, 0, math.rad(60))
        Move(pelvis , y_axis, 0 , 1 )
        Turn(rthigh , x_axis, 0, math.rad(200) )
        Turn(rleg , x_axis, 0, math.rad(200) )
        Turn(lthigh , x_axis, 0, math.rad(200) )
        Turn(lleg , x_axis, 0, math.rad(200) )
        Turn(luparm, x_axis, 0, math.rad(120))
        Turn(ruparm, x_axis, 0, math.rad(120))
        
        Turn(llarm, x_axis, 0, math.rad(180))
        Turn(rlarm, x_axis, 0, math.rad(180))
        Turn(luparm, z_axis, math.rad(45))
        Turn(ruparm, z_axis, math.rad(-45))
end


local function Walk()
        Signal(SIG_WALK)
        SetSignalMask(SIG_WALK)
        Turn(pelvis, x_axis, math.rad(10), math.rad(30))
        while true do
                --left leg up, right leg back
                Turn(lthigh, x_axis, THIGH_FRONT_ANGLE, THIGH_FRONT_SPEED)
                Turn(lleg, x_axis, SHIN_FRONT_ANGLE, SHIN_FRONT_SPEED)
                Turn(rthigh, x_axis, THIGH_BACK_ANGLE, THIGH_BACK_SPEED)
                Turn(rleg, x_axis, SHIN_BACK_ANGLE, SHIN_BACK_SPEED)
                if (armsFree) then
                        --left arm back, right arm front
                        Turn(torso, y_axis, TORSO_ANGLE_MOTION, TORSO_SPEED_MOTION)
                        Turn(luparm, x_axis, ARM_BACK_ANGLE, ARM_BACK_SPEED)
                        Turn(ruparm, x_axis, ARM_FRONT_ANGLE, ARM_FRONT_SPEED)
                end
                WaitForTurn(lthigh, x_axis)
                Sleep(0)
                
                --right leg up, left leg back
                Turn(lthigh, x_axis,  THIGH_BACK_ANGLE, THIGH_BACK_SPEED)
                Turn(lleg, x_axis, SHIN_BACK_ANGLE, SHIN_BACK_SPEED)
                Turn(rthigh, x_axis, THIGH_FRONT_ANGLE, THIGH_FRONT_SPEED)
                Turn(rleg, x_axis, SHIN_FRONT_ANGLE, SHIN_FRONT_SPEED)
                if (armsFree) then
                        --left arm front, right arm back
                        Turn(torso, y_axis, -TORSO_ANGLE_MOTION, TORSO_SPEED_MOTION)
                        Turn(luparm, x_axis, ARM_FRONT_ANGLE, ARM_FRONT_SPEED)
                        Turn(ruparm, x_axis, ARM_BACK_ANGLE, ARM_BACK_SPEED)
                end
                WaitForTurn(rthigh, x_axis)             
                Sleep(0)
        end
end

function script.Create()
        Turn(luparm, z_axis, math.rad(45))
        Turn(ruparm, z_axis, math.rad(-45))
       -- Turn(rbarrel1, x_axis, math.rad(-105))
       -- Turn(rbarrel2, x_axis, math.rad(-105))
        --Turn(rbbarrel1, x_axis, math.rad(-105))
        -- Turn(rbbarrel2, x_axis, math.rad(-105))
        -- Turn(rbarrel1, z_axis, math.rad(-30))
        -- Turn(rbarrel2, z_axis, math.rad(-30))
        -- Turn(rbbarrel1, z_axis, math.rad(30))
        -- Turn(rbbarrel2, z_axis, math.rad(30))       
        
        --StartThread(SmokeUnit)
       -- StartThread(SomersaultLoop)
end

function script.StartMoving() 
        StartThread(Walk)
end

function script.StopMoving() 
        Signal(SIG_WALK)
        StartThread(RestorePose)
end

local function RestoreAfterDelay()
        Signal(SIG_RESTORE)
        SetSignalMask(SIG_RESTORE)
        Sleep(RESTORE_DELAY)
        armsFree = true
        Turn(torso, y_axis, 0,  TORSO_SPEED_YAW)
        Turn(luparm, x_axis, 0, ARM_SPEED_PITCH)
        Turn(ruparm, x_axis, 0, ARM_SPEED_PITCH)
end


function script.AimWeapon(num, heading, pitch)
        if num == 1 then
                if bJumping then return false end
                Signal(SIG_AIM)
                SetSignalMask(SIG_AIM)
                armsFree = false
                Turn(torso, y_axis, heading,  TORSO_SPEED_YAW)
                Turn(luparm, x_axis, -pitch, ARM_SPEED_PITCH)
                Turn(ruparm, x_axis, -pitch, ARM_SPEED_PITCH)
                WaitForTurn(torso, y_axis)
                WaitForTurn(luparm, x_axis)
                WaitForTurn(ruparm, x_axis)
        end
        return true
end

function script.FireWeapon(num)
end

function script.Shot(num)
        gunIndex[num] = gunIndex[num] + 1
        if gunIndex[num] > 4 then gunIndex[num] = 1 end
     --   if num == 1 then
     --           EmitSfx(barrels[num][gunIndex[num]], 1024)
      --          EmitSfx(barrels[num][gunIndex[num]], 1026)
      --  else
      --          EmitSfx(barrels[num][gunIndex[num]], 1027)
        --end
end

function script.QueryWeapon(num)
        return(flares[1][gunIndex[num]])
end

function script.AimFromWeapon(num)
        return torso
end

function script.Killed(recentDamage, maxHealth)
        local severity = recentDamage/maxHealth
        if severity < 0.25 then
                Explode(torso, sfxNone + SFX.NO_HEATCLOUD)
                Explode(luparm, sfxNone + SFX.NO_HEATCLOUD)
                Explode(ruparm, sfxNone + SFX.NO_HEATCLOUD)
                Explode(pelvis, sfxNone + SFX.NO_HEATCLOUD)
                Explode(lthigh, sfxNone + SFX.NO_HEATCLOUD)
                Explode(rthigh, sfxNone + SFX.NO_HEATCLOUD)
                Explode(rleg, sfxNone + SFX.NO_HEATCLOUD)
                Explode(lleg, sfxNone + SFX.NO_HEATCLOUD)
                return 1
        elseif severity < 0.5 then
                Explode(torso, sfxNone + SFX.NO_HEATCLOUD)
                Explode(luparm, sfxNone + SFX.NO_HEATCLOUD)
                Explode(ruparm, sfxNone + SFX.NO_HEATCLOUD)
                Explode(pelvis, sfxNone + SFX.NO_HEATCLOUD)
                Explode(lthigh, sfxNone + SFX.NO_HEATCLOUD)
                Explode(rthigh, sfxNone + SFX.NO_HEATCLOUD)
                Explode(rleg, sfxNone + SFX.NO_HEATCLOUD)
                Explode(lleg, sfxNone + SFX.NO_HEATCLOUD)
                return 2
        else
                Explode(torso, sfxShatter + SFX.NO_HEATCLOUD)
                Explode(luparm, sfxSmoke + sfxFire + sfxExplode + SFX.NO_HEATCLOUD)
                Explode(ruparm, sfxSmoke + sfxFire + sfxExplode + SFX.NO_HEATCLOUD)
                Explode(pelvis, sfxShatter + SFX.NO_HEATCLOUD)
                Explode(lthigh, sfxShatter + SFX.NO_HEATCLOUD)
                Explode(rthigh, sfxShatter + SFX.NO_HEATCLOUD)
                Explode(rleg, sfxShatter + SFX.NO_HEATCLOUD)
                Explode(lleg, sfxShatter + SFX.NO_HEATCLOUD)
                return 3
        end
end
