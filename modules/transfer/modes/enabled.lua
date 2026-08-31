local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua") ---@type TransferModeDSL
local Mode, Transfer, Construction, Take = ModeDSL.Mode, ModeDSL.Transfer, ModeDSL.Construction, ModeDSL.Take

-- stylua: ignore
return Mode("Enabled")
	.Desc("All sharing on with fixed defaults.")
	.Ranked()
	.Allow(Transfer.Units)
	.Allow(Transfer.Resources)
	.Tax(Transfer.Resources, 0.0)
	.Hidden().Sealed()
	.Allow(Construction.Assist)
	.Allow(Construction.Reclaim)
	.Allow(Take)
