local foot1 = piece "foot1"
local foot2 = piece "foot2"
local body = piece "body"
local wing1 = piece "wing1"
local wing2 = piece "wing2"
local flare1 = piece "flare1"
local flare2 = piece "flare2"
local tail = piece "tail"

local SIG_WALK = 2

local tspeed = math.rad (180)
local ta = math.rad (30)
local volume 			= 0.5
local soundPause 		= 300
local lastSound		 	= 0
local PlaySoundFile 	= Spring.PlaySoundFile
local GetUnitPosition 	= Spring.GetUnitPosition
local GetGameFrame 		= Spring.GetGameFrame
function script.Create ()
	--Spin (wing2,x_axis, 0.5)
end

bodyWiggleAxis = z_axis --z while walking, y while swimming
function walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)
	Sleep (math.random (0, 100))
	while (true) do
		Turn (foot1, x_axis, ta, tspeed)
		Turn (foot2, x_axis, -ta, tspeed)
		Turn (body, bodyWiggleAxis, -ta/4, tspeed)
		WaitForTurn (foot2, x_axis)
		WaitForTurn (foot2, x_axis)
		
		Turn (foot1, x_axis, -ta, tspeed)
		Turn (foot2, x_axis, ta, tspeed)
		Turn (body, bodyWiggleAxis, ta/4, tspeed)
		WaitForTurn (foot2, x_axis)
		WaitForTurn (foot2, x_axis)
		Sleep (10)
		
		WaitForTurn (wing1, z_axis, math.rad(math.random(-20,20)), tspeed)
		WaitForTurn (wing2, z_axis, math.rad(math.random(-20,20)), tspeed)		
	end	
end

function stopwalk()
	Signal(SIG_WALK) --stop the walk thread
	Turn (foot1, x_axis, 0, tspeed)
	Turn (foot2, x_axis, 0, tspeed)
	--Turn (body, x_axis, math.rad (0), math.rad (45))
end

function script.StartMoving()
	--Spring.Echo ("start moving")
	--Turn (body, x_axis, math.rad (10), math.rad (45))
	StartThread(walk)
end
	
function script.StopMoving()
	StartThread(stopwalk)
	
	Turn (body, z_axis, 0, tspeed*2)
	Turn (body, y_axis, 0, tspeed*2)
end

function script.setSFXoccupy (curTerrainType)
	if curTerrainType == 2 then
		Turn (body, x_axis, math.rad(80), tspeed)
		--bodyWiggleAxis = y_axis
	end
	if curTerrainType == 4 or curTerrainType == 1 then	--must be stupid like this or they change to walking too late and clip into shore
		StartThread (jump)
		Turn (body, x_axis, 0, tspeed*2)
		--bodyWiggleAxis = z_axis
	end	--[[
	if  GetGameFrame () -lastSound > soundPause then
		local x,y,z = GetUnitPosition(unitID)
		local snd = 'sounds/critters/penbray2.wav'
		PlaySoundFile(snd,volume,x,y,z,0,0,0,'sfx')
		lastSound = GetGameFrame ()
	end]]--
	--Spring.Echo (curTerrainType)
end

local lastJump = 0
function jump()
	if  GetGameFrame () -lastJump < 40 then return end
	local x,y,z = GetUnitPosition(unitID)
	local snd = 'sounds/critters/penbray1.wav'
	Move (body, y_axis, 15,40)
	WaitForMove (body,y_axis)
	Move (body, y_axis, 0,40)
	lastJump = Spring.GetGameFrame ()
	--PlaySoundFile(snd,volume,x,y,z,0,0,0,'battle')
end


function script.AimFromWeapon1()
	return flare1
end
function script.AimFromWeapon2()
	return flare2
end

function script.QueryWeapon1()
	return flare1
end

function script.QueryWeapon2()
	return flare2
end


function script.AimWeapon1(heading, pitch)
	return true
end
function script.AimWeapon2(heading, pitch)
	return true
end

function script.FireWeapon1()
	return true
end
function script.FireWeapon2()
	return true
end

function script.Shot1()
end

function script.Killed(recentDamage, maxHealth)
	local snd
	local rnd = math.random (0,100)
	local x,y,z = GetUnitPosition(unitID)
	
	if  rnd < 35 then
		snd = 'sounds/critters/pensquawk1.wav'
	elseif rnd < 70 then
		snd = 'sounds/critters/pensquawk2.wav'
	else
		snd = 'sounds/critters/pensquawk3.wav'
	end
	--PlaySoundFile(snd,volume,x,y,z,0,0,0,'battle')
end
