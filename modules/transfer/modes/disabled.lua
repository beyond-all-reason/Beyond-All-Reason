local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua")
local Mode, Transfer, Construction, Take = ModeDSL.Mode, ModeDSL.Transfer, ModeDSL.Construction, ModeDSL.Take

return Mode("Disabled")
	.Desc("Disable all sharing; apply a 30% tax; lock most controls.")
	.Ranked()
	.Deny(Transfer.Units)
	.Deny(Transfer.Resources)
	.Tax(Transfer.Resources, 0.30).Hidden().Unlocked()
	.Deny(Construction.Assist)
	.Deny(Construction.Reclaim)
	.Deny(Take).Unlocked()
