local foot1 = piece "foot1"
local foot2 = piece "foot2"
local body = piece "body"

local SIG_WALK = 2

local tspeed = math.rad (180)
local ta = math.rad (30)

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
