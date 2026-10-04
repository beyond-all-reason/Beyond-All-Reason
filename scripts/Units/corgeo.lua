--pieces
        local base = piece "base"
        local smokespot = piece "smokespot"
	local dmgPieces = { piece "base" }

-- includes
	include "dmg_smoke.lua"
	include "animation.lua"

function script.Create()
	StartThread(animSmoke, unitID, smokespot)
	StartThread(animBurn, unitID, smokespot)
	StartThread(dmgsmoke, dmgPieces)
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