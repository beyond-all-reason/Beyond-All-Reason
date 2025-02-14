-- Animate spinning parts after the model was built
function animSpin(id, piece, axis, speed)
	local last_inbuilt, inProgress = true
	
	while (true) do
		inProgress = Spring.GetUnitIsBeingBuilt(id)
		if (inProgress ~= last_inbuilt) then
			last_inbuilt = inProgress
			if (inProgress) then
				StopSpin( piece, axis, speed )
			else
				Spin( piece, axis, speed )
			end
		end
		Sleep(1000)
	end
end


-- Start smoke effect after the model was built
function animSmoke(id, piece)
	local SMOKE, last_inbt, inProgress = 257, true

	while (true) do
		inProgress = Spring.GetUnitIsBeingBuilt(id)
		if (inProgress ~= last_inbt) then
			last_inbt = inProgress
			if (not inProgress) then
				while (true) do
					EmitSfx(piece, SFX.BLACK_SMOKE)
					Sleep(100)
				end
			end
		end
		Sleep(1000)
	end
end


-- Start fire2 at low health level
function animBurn(id, piece)
	local last_inb, inProgress = true

	while (true) do
		inProgress = Spring.GetUnitIsBeingBuilt(id)
		if (inProgress ~= last_inb) then
			last_inb = inProgress
			if (!inProgress) then
				while (true) do
					if (GetUnitValue(COB.HEALTH)<=10) then
						EmitSfx(piece, 1024+0)
					end
					Sleep(100)
				end
			end
		end
		Sleep(1000)
	end
end
