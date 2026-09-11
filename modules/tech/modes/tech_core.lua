local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua") ---@type TransferModeDSL
local Mode, Transfer, Construction, Take, Tech =
	ModeDSL.Mode, ModeDSL.Transfer, ModeDSL.Construction, ModeDSL.Take, ModeDSL.Tech

return Mode("Tech Core")
	.Desc(
		"Tech levels gate unit construction. Build Keystone buildings to advance. Sharing unlocks with tech. Legion's mex economy is rebalanced for the universal Voussoir."
	)
	.Ranked()
	.Gate(Tech, 1, 1.5)
	.Deny(Transfer.Units)
	.Allow(Transfer.Units.Constructors.AtT2)
	.Deny(Transfer.Units.AtT3)
	.Allow(Transfer.Resources)
	.Tax(Transfer.Resources, 0.6)
	.Tax(Transfer.Resources.AtT2, 0.5)
	.Tax(Transfer.Resources.AtT3, 0.4)
	.Allow(Construction.Assist)
	.Allow(Construction.Reclaim)
	.Deny(Construction.Resurrect)
	.Defer(Take)
	.Delay(Take.Resource, 60)
