local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua") ---@type TransferModeDSL
local Mode, Transfer, Construction, Take = ModeDSL.Mode, ModeDSL.Transfer, ModeDSL.Construction, ModeDSL.Take

-- stylua: ignore
return Mode("Disabled")
	.Desc(
		"No sharing of any kind: no resources, no units, no assisting or reclaiming an ally, no /take. Most sharing options are locked."
	)
	.Ranked()
	.Deny(Transfer.Units)
	.Deny(Transfer.Resources)
	.Tax(Transfer.Resources, 0.30)
	.Hidden().Unlocked()
	.Deny(Construction.Assist)
	.Deny(Construction.Reclaim)
	.Deny(Take).Unlocked()
