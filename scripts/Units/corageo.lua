--pieces
        local base = piece "base"
        local fan1 = piece "fan1"
        local fan2 = piece "fan2"
        local fan3 = piece "fan3"
        local rod1 = piece "rod1"
        local rod2 = piece "rod2"
        local rod3 = piece "rod3"
	
        local smokespot = piece "smokespot"
	local dmgPieces = { piece "base" }

-- includes
	include "dmg_smoke.lua"
	include "animation.lua"

function script.Create()
	Hide (fan2)
	Hide (fan3)
	Turn (fan2, y_axis, math.rad(-119), math.rad (900))
	Turn (fan3, y_axis, math.rad(119), math.rad (900))
	Sleep (10)
	Show(fan2)
	Show(fan3)
	StartThread(animSmoke, unitID, smokespot)
	StartThread(animBurn, unitID, smokespot)
	StartThread(dmgsmoke, dmgPieces)
	StartThread(animSpin, unitID, fan1, z_axis, math.rad(90.000000))
	StartThread(animSpin, unitID, fan2, z_axis, math.rad(90.000000))
	StartThread(animSpin, unitID, fan3, z_axis, math.rad(90.000000))
	StartThread(rods)
end



function rods()
	isInLoop = true
	while (true) do
		Move(rod1, y_axis, 5, 2)
		Sleep (1000)
		Move(rod2, y_axis, 5, 2)
		Sleep (1000)
		Move(rod3, y_axis, 5, 2)
		Move(rod1, y_axis, 0, 2)
		Sleep (1000)
		Move(rod2, y_axis, 0, 2)
		Sleep (1000)
		Move(rod3, y_axis, 0, 2)
	end
end
        
function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage / maxHealth

	if (severity <= .25) then
		Explode(fan1,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(fan2,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(fan3,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		return 1 -- corpsetype

	elseif (severity <= .5) then
		Explode(fan1,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(fan2,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(fan3,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		return 2 -- corpsetype
	else
		Explode(fan1,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(fan2,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		Explode(fan3,SFX.EXPLODE + SFX.NO_HEATCLOUD)
		return 3 -- corpsetype
	end
end