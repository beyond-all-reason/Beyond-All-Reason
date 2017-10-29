local base = piece "base"
local f = 0

function Sink()
	StartThread(MoveDown)
end

function MoveDown()
	while f > -50 do
		Move(base, 2, f)
		f = f - 0.03
		Sleep(1)
	end
end