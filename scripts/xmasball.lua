local base = piece "base"
local f = 0

function script.Create()
	Turn (base, x_axis, math.random()*360, 90)
	Turn (base, y_axis, math.random()*360, 90)
	Turn (base, z_axis, math.random()*360, 90)
end

function Sink()
	StartThread(MoveDown)
end

function MoveDown()
	while f > -900 do
		Move(base, 2, f)
		f = f - 0.04
		Sleep(1)
	end
end