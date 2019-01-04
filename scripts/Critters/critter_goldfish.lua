local wingr = piece "fin1"
local wingl = piece "fin2"
local tail = piece "tail"
local body = piece "body"

local flapSpeed = math.rad(400)

function script.Create()
--	Spring.Echo ("goldfish here")
	StartThread (flapFins)
end

function script.Killed(recentDamage, maxHealth)

end

function flapFins()
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
		Sleep (math.random (200,1000))
		for i=1,3,1 do
			Turn (tail, x_axis, math.rad(30),flapSpeed)
			WaitForTurn (tail,x_axis)
			Turn (tail, x_axis, 0,flapSpeed)
			WaitForTurn (tail,x_axis)
			Turn (body, x_axis, math.rad (math.random (-20,20)) , flapSpeed/2)
		end
	end
end
