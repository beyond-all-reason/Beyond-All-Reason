local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua")
local Mode, Share, Assist, Reclaim, Take = ModeDSL.Mode, ModeDSL.Share, ModeDSL.Assist, ModeDSL.Reclaim, ModeDSL.Take

return Mode("Enabled")
	.Desc("All sharing on with fixed defaults.")
	.Ranked()
	.Allow(Share.Units)
	.Allow(Share.Resources)
	.Tax(Share.Resources, 0.0).Hidden().Locked()
	.Allow(Assist.Allied)
	.Allow(Reclaim.AlliedUnits)
	.Allow(Take)
