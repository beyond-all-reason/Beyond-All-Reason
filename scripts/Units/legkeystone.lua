-- Keystone build script. The shield-gate model has no builder rig, so the stock
-- gate COB never sets INBUILDSTANCE nor exposes a nanolathe piece. Without build
-- stance the engine's CBuilder::StartBuild bails every frame (inWaitStance), so a
-- placed nanoframe just sits there and never progresses. The Keystone is an
-- immobile construction turret, so put it in build stance permanently and emit
-- the build beam from the base piece.

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

function script.StopBuilding()
end

function script.Killed(recentDamage, maxHealth)
	Explode(base, SFX.NONE + SFX.NO_HEATCLOUD)
	return 1
end
