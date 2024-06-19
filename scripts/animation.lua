-- Animate spinning parts after the model was built
function animSpin(getid, getpiece, getaxis, getspeed)
	local id=getid
	local piece=getpiece
	local axis=getaxis
	local speed=getspeed
	local last_inbuilt = true

	while (true) do
		local inProgress = Spring.GetUnitIsBeingBuilt(id)
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
function animSmoke(getid, getpiece)
	local id=getid
	local piece=getpiece
	local SMOKE = 257
	local last_inbt = true

	while (true) do
		local inProgress = Spring.GetUnitIsBeingBuilt(id)
		if (inProgress ~= last_inbt) then
			last_inbt = inProgress
			if (inProgress) then
				--nothing
			else
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
function animBurn(getid, getpiece)
	local id=getid
	local piece=getpiece
	local last_inb = true

	while (true) do
		local inProgress = Spring.GetUnitIsBeingBuilt(id)
		if (inProgress ~= last_inb) then
			last_inb = inProgress
			if (inProgress) then
				--nothing
			else
				while (true) do
					local health = GetUnitValue(COB.HEALTH)
					if (health<=10) then
						EmitSfx(piece, 1024+0)
					end
					Sleep(100)
				end
			end
		end
		Sleep(1000)
	end
end