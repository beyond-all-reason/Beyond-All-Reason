local foot1 = piece "foot1"
local foot2 = piece "foot2"
local body = piece "body"

local SIG_WALK = 2

local tspeed = math.rad (180)
local ta = math.rad (30)

local volume 			= 0.5
local soundPause 		= 300
local lastSound 		= 0
local PlaySoundFile 	= Spring.PlaySoundFile
local GetUnitPosition 	= Spring.GetUnitPosition
local GetGameFrame 		= Spring.GetGameFrame

function walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)		
	while (true) do
		Turn (foot1, x_axis, ta, tspeed)
		Turn (foot2, x_axis, -ta, tspeed)
		WaitForTurn (foot2, x_axis)
		WaitForTurn (foot2, x_axis)
		
		Turn (foot1, x_axis, -ta, tspeed)
		Turn (foot2, x_axis, ta, tspeed)
		WaitForTurn (foot2, x_axis)
		WaitForTurn (foot2, x_axis)
		Sleep (10)
	end	
end

function stopwalk()
	Signal(SIG_WALK) --stop the walk thread
	Turn (foot1, x_axis, 0, tspeed)
	Turn (foot2, x_axis, 0, tspeed)
	Turn (body, x_axis, math.rad (0), math.rad (45))
end

function script.StartMoving()
	--Spring.Echo ("start moving")
	Turn (body, x_axis, math.rad (10), math.rad (45))
	if  GetGameFrame () -lastSound > soundPause then
		local snd
		local rnd = math.random (0,100)
		local x,y,z = GetUnitPosition(unitID)
		if  rnd < 35 then
			snd = 'sounds/critters/duckcall1.wav'
		elseif rnd < 70 then
			snd = 'sounds/critters/duckcall2.wav'
		else
			snd = 'sounds/critters/duckcall3.wav'
		end
		--PlaySoundFile(snd,volume,x,y,z,0,0,0,'sfx')
		lastSound = GetGameFrame ()
	end
	StartThread(walk)
end
	
function script.StopMoving()
	StartThread(stopwalk)
end

function script.QueryWeapon1() return body end

function script.AimFromWeapon1() return body end

function script.AimWeapon1( heading, pitch )
	return true
end

function script.Shot1()
	
end
--[[
function script.Killed(recentDamage, maxHealth)
	local snd
	local rnd = math.random (0,100)
	local x,y,z = GetUnitPosition(unitID)
	
	if  rnd < 50 then
		snd = 'sounds/critters/duckcry1.wav'
	else
		snd = 'sounds/critters/duckcry2.wav'
	end
	PlaySoundFile(snd,volume,x,y,z,0,0,0,'battle')
end
]]--

