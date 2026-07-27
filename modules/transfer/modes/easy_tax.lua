local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua")
local Mode, Share, Assist, Reclaim, Resurrect, Build, Take =
	ModeDSL.Mode, ModeDSL.Share, ModeDSL.Assist, ModeDSL.Reclaim, ModeDSL.Resurrect, ModeDSL.Build, ModeDSL.Take

return Mode("Easy Tax")
	.Desc("Anti co-op sharing tax mode. Tax on resource sharing, assist, and resurrection. Eco buildings stunned, mobile constructors debuffed.")
	.Ranked()
	.Allow(Share.Units)
	.Stun(Share.Units.Resource, 30)
	.Delay(Build.Constructors, 30)
	.Allow(Share.Resources)
	.Tax(Share.Resources, 0.30)
	.Allow(Assist.Allied)
	.Allow(Reclaim.AlliedUnits)
	.Allow(Resurrect.Partial)
	.Stun(Take)
	.Delay(Take.Resource, 30)
