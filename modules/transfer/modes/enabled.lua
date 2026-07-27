local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua")
local Mode, Transfer, Assist, Reclaim, Take = ModeDSL.Mode, ModeDSL.Transfer, ModeDSL.Assist, ModeDSL.Reclaim, ModeDSL.Take

return Mode("Enabled")
	.Desc("All sharing on with fixed defaults.")
	.Ranked()
	.Allow(Transfer.Units)
	.Allow(Transfer.Resources)
	.Tax(Transfer.Resources, 0.0).Hidden().Locked()
	.Allow(Assist.Allied)
	.Allow(Reclaim.AlliedUnits)
	.Allow(Take)
