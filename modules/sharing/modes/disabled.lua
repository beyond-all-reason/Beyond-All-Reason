local ModeDSL = VFS.Include("modules/sharing/mode_dsl.lua")
local Mode, Share, Assist, Reclaim, Take = ModeDSL.Mode, ModeDSL.Share, ModeDSL.Assist, ModeDSL.Reclaim, ModeDSL.Take

return Mode("Disabled")
	.Desc("Disable all sharing; apply a 30% tax; lock most controls.")
	.Ranked()
	.Deny(Share.Units)
	.Deny(Share.Resources)
	.Tax(Share.Resources, 0.30).Hidden().Unlocked()
	.Deny(Assist.Allied)
	.Deny(Reclaim.AlliedUnits)
	.Deny(Take).Unlocked()
