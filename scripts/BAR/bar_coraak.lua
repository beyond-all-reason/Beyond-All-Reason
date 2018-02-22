include("include/util.lua");
--------------------------------------------------------------------------------
-- pieces
--------------------------------------------------------------------------------
local pelvis, torso = piece('pelvis', 'torso')
local lfleg, rfleg, lbleg, rbleg = piece('lfleg', 'rfleg', 'lbleg', 'rbleg')
local lffoot, rffoot, lbfoot, rbfoot = piece('lffoot', 'rffoot', 'lbfoot', 'rbfoot')
local flakgun, barrel1, barrel2, barrel3, barrel4 = piece('flakgun',"barrel1", "barrel2", "barrel3","barrel4")
local flareflak, flare1, flare2, flare3, flare4 = piece('flareflak', 'flare1', 'flare2', 'flare3', 'flare4')

local flares = {flare1, flare2, flare3, flare4}

smokePiece = {pelvis, torso}

--------------------------------------------------------------------------------
-- constants
local sfxNone=SFX.NONE
local sfxShatter=SFX.SHATTER
local sfxSmoke=SFX.SMOKE
local sfxFire=SFX.FIRE
local sfxFall = SFX.FALL
local sfxExplode = SFX.EXPLODE
--------------------------------------------------------------------------------

local restore_delay = 3000
local pelvis_speed = 100

local SIG_WALK = 1
local SIG_AIM1 = 2
local SIG_AIM2 = 4
local SIG_RESTORE = 8

local SPEED = 1.9

local SPEED = 2

--------------------------------------------------------------------------------
-- vars
--------------------------------------------------------------------------------
local gun_1 = 1

-- four-stroke tetrapedal walkscript
local function Walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)
	while true do

		local speedmult = (1 - (Spring.GetUnitRulesParam(unitID,"slowState") or 0))*SPEED

		-- extend left
		Turn(lfleg, x_axis, math.rad(-50), math.rad(25)*speedmult)
		Turn(lffoot, x_axis, math.rad(0), math.rad(150)*speedmult)

		Turn(rfleg, x_axis, math.rad(-40), math.rad(80)*speedmult)
		Turn(rffoot, x_axis, math.rad(60), math.rad(120)*speedmult)

		Turn(rbleg, x_axis, math.rad(20), math.rad(100)*speedmult)
		Turn(rbfoot, x_axis, math.rad(30), math.rad(50)*speedmult)

		Turn(lbleg, x_axis, math.rad(-40), math.rad(80)*speedmult)
		Turn(lbfoot, x_axis, math.rad(60), math.rad(120)*speedmult)

		Sleep(400/speedmult)

		Turn(lfleg, x_axis, math.rad(40), math.rad(150)*speedmult)
		Turn(lffoot, x_axis, math.rad(-60), math.rad(100)*speedmult)

		Sleep(200/speedmult)

		Turn(rbleg, x_axis, math.rad(40), math.rad(50)*speedmult)
		Turn(rbfoot, x_axis, math.rad(-60), math.rad(225)*speedmult)

		Sleep(400/speedmult)

		-- extend right
		Turn(lfleg, x_axis, math.rad(-40), math.rad(80)*speedmult)
		Turn(lffoot, x_axis, math.rad(60), math.rad(120)*speedmult)

		Turn(rfleg, x_axis, math.rad(-50), math.rad(25)*speedmult)
		Turn(rffoot, x_axis, math.rad(0), math.rad(150)*speedmult)

		Turn(rbleg, x_axis, math.rad(-40), math.rad(80)*speedmult)
		Turn(rbfoot, x_axis, math.rad(60), math.rad(120)*speedmult)

		Turn(lbleg, x_axis, math.rad(20), math.rad(100)*speedmult)
		Turn(lbfoot, x_axis, math.rad(30), math.rad(50)*speedmult)

		Sleep(400/speedmult)

		Turn(rfleg, x_axis, math.rad(40), math.rad(150)*speedmult)
		Turn(rffoot, x_axis, math.rad(-60), math.rad(100)*speedmult)

		Sleep(200/speedmult)

		Turn(lbleg, x_axis, math.rad(40), math.rad(50)*speedmult)
		Turn(lbfoot, x_axis, math.rad(-60), math.rad(225)*speedmult)

		Sleep(400/speedmult)
	end
end

local function ResetLegs()
	Turn(lfleg, x_axis, 0, math.rad(80))
	Turn(lffoot, x_axis, 0, math.rad(80))
	Turn(rfleg, x_axis, 0, math.rad(80))
	Turn(rffoot, x_axis, 0, math.rad(80))
	Turn(lbleg, x_axis, 0, math.rad(80))
	Turn(lbfoot, x_axis, 0, math.rad(80))
	Turn(rbleg, x_axis, 0, math.rad(80))
	Turn(rbfoot, x_axis, 0, math.rad(80))
end


function script.Create()
	--StartThread(Walk)
	--StartThread(SmokeUnit)
end

function script.StartMoving()
	--Spring.Echo("Moving")
	StartThread(Walk)
end

function script.StopMoving()
	--Spring.Echo("Stopped moving")
	Signal(SIG_WALK)
	ResetLegs()
end

local function RestoreAfterDelay()
	Sleep( 3000)
	Turn( torso , y_axis, 0, math.rad(70) )
end

function script.AimWeapon(num, heading, pitch)
	--Spring.Echo('Aimweapon',num)
	if num == 1 then
		Signal( SIG_AIM2)
		SetSignalMask( SIG_AIM2)
		Turn( torso , y_axis, heading, math.rad(360) )
		WaitForTurn(torso, y_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif num >= 2 and num <=10 then
		Signal( math.pow(2,num))
		SetSignalMask(math.pow(2,num))
		Turn( torso , y_axis, heading, math.rad(360) )
		WaitForTurn(torso, y_axis)
		StartThread(RestoreAfterDelay)
		return true
	-- elseif num == 10 then
		-- Signal( SIG_AIM2)
		-- SetSignalMask( )
		-- Turn( torso , y_axis, heading, math.rad(360) )
		-- Turn( flakgun, x_axis, -pitch, math.rad(180) )
		-- WaitForTurn(torso, y_axis)
		-- WaitForTurn(flakgun, x_axis)
		-- StartThread(RestoreAfterDelay)
		-- return true
	end
end

function script.FireWeapon(num)
	--Spring.Echo('Fireweapon',num)
	if num <=11 then
		gun_1 = gun_1 + 1
		if gun_1 > 4 then gun_1 = 1 end
	elseif num == 2 then
		EmitSfx(flareflak, 1024+0)
	end
end
function script.Shot(num)
end
function script.AimFromWeapon(num)
	return torso
end

function script.QueryWeapon(num)
	if num == 10 then return flareflak
	else return flares[gun_1] end
end

function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage/maxHealth
	local parts={ lfleg, rfleg, lbleg, rbleg ,lffoot, rffoot, lbfoot, rbfoot,flakgun, barrel1, barrel2, barrel3, barrel4, flare1, flare2, flare3, flare4}
	if severity <= .25  then
		Explode(pelvis, sfxNone + SFX.NO_HEATCLOUD)
		
		return 1
	elseif (severity <= .50 ) then
		Explode(pelvis, sfxNone + SFX.NO_HEATCLOUD)
		
		for i=1, #parts do
			Explode(parts[i], sfxFall + sfxSmoke + sfxExplode + SFX.NO_HEATCLOUD)
		end
		return 1
	elseif (severity <= .99 ) then
		Explode(pelvis, sfxShatter)		
		for i=1, #parts do
			Explode(parts[i], sfxFall + sfxSmoke + sfxExplode + SFX.NO_HEATCLOUD)
		end
		return 2
	else
		Explode(pelvis, sfxShatter)
		for i=1, #parts do
			Explode(parts[i], sfxFall + sfxSmoke + sfxExplode + SFX.NO_HEATCLOUD)
		end
		return 3
	end
end