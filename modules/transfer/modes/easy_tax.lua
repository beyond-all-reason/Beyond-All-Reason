local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua")
local Mode, Transfer, Construction, Take =
	ModeDSL.Mode, ModeDSL.Transfer, ModeDSL.Construction, ModeDSL.Take

return Mode("Easy Tax")
	.Desc("Anti co-op sharing tax mode. Tax on resource sharing, assist, and resurrection. Eco buildings stunned, mobile constructors debuffed.")
	.Ranked()
	.Allow(Transfer.Units)
	.Stun(Transfer.Units.Resource, 30)
	.Delay(Construction.Build, 30)
	.Allow(Transfer.Resources)
	.Tax(Transfer.Resources, 0.30)
	.Allow(Construction.Assist)
	.Allow(Construction.Reclaim)
	.Allow(Construction.Resurrect)
	.Stun(Take)
	.Delay(Take.Resource, 30)
