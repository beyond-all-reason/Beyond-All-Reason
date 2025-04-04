local wingr = piece "rwing"
local flare = piece "flare"
local wingl = piece "lwing"
local flapSpeed = math.rad(360)

function script.Create()
	StartThread (flapWings)
end

function script.Killed(recentDamage, maxHealth)

end

function flapWings()
	while (true) do
		for i=1,math.random (1,3) do
			Turn (wingr, z_axis, -math.rad(60),flapSpeed)
			Turn (wingl, z_axis, math.rad(60),flapSpeed)		
			WaitForTurn (wingr,z_axis)
			WaitForTurn (wingr,z_axis)
			Sleep (100)
			Turn (wingr, z_axis, 0,flapSpeed)
			Turn (wingl, z_axis, 0,flapSpeed)
			WaitForTurn (wingr,z_axis)
			WaitForTurn (wingr,z_axis)
		end		
		Sleep (math.random (500,2000))
	end
end


function script.AimFromWeapon1()
	return flare
end
function script.AimFromWeapon2()
	return flare
end

function script.QueryWeapon1()
	return flare
end

function script.QueryWeapon2()
	return flare
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
