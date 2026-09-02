-- Keystone build script: shield-gate model has no builder rig, so keep it permanently in build stance and nanolathe from the base piece.

local base = piece("base")

function script.Create()
	SetUnitValue(COB.INBUILDSTANCE, 1)
end

function script.QueryNanoPiece()
	return base
end

function script.StartBuilding()
	SetUnitValue(COB.INBUILDSTANCE, 1)
end

function script.StopBuilding() end

function script.Killed(recentDamage, maxHealth)
	Explode(base, SFX.NONE + SFX.NO_HEATCLOUD)
	return 1
end
