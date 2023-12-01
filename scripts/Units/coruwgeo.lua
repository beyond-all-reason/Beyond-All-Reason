--pieces
        local base = piece "base"
        local fan1 = piece "fan1"
        local fan2 = piece "fan2"
        local fan3 = piece "fan3"
        local smokespot = piece "smokespot"

-- includes
	--include "dmg_smoke.lua"
	include "animation.lua"

function script.Create()
	--StartThread(animSmoke, unitID, smokespot)
	StartThread(animSpin, unitID, fan1, y_axis, math.rad(180.000000))
	StartThread(animSpin, unitID, fan2, y_axis, math.rad(180.000000))
	StartThread(animSpin, unitID, fan3, y_axis, math.rad(180.000000))
	while true do
		EmitSfx(smokespot,  1024 + 0 )
		Sleep(600 + random(100,200))
	end
end


function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage / maxHealth

	if (severity <= .25) then
		Explode(base, SFX.NONE + SFX.NO_HEATCLOUD)
		return 1 -- corpsetype

	elseif (severity <= .5) then
		Explode(base, SFX.NONE + SFX.NO_HEATCLOUD)
		return 2 -- corpsetype
	else
		Explode(base, SFX.NONE + SFX.NO_HEATCLOUD)
		return 3 -- corpsetype
	end
end