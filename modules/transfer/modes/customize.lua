local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua")
local Mode, Transfer, Assist, Reclaim, Resurrect, Build, Take, Tech =
	ModeDSL.Mode, ModeDSL.Transfer, ModeDSL.Assist, ModeDSL.Reclaim, ModeDSL.Resurrect, ModeDSL.Build, ModeDSL.Take, ModeDSL.Tech

-- Every policy exposed unlocked; values are only the starting point (RetainValues).
return Mode("Customize")
	.Desc("Tweak everything. Switching to Customize keeps the current mode's settings as a starting point (defaults if you start here).")
	.Ranked()
	.RetainValues()
	.Open(Tech, 1, 1.5).Unlocked()
	.Allow(Transfer.Units).Unlocked()
	.Deny(Transfer.Units.AtT2).Unlocked()
	.Deny(Transfer.Units.AtT3).Unlocked()
	.Stun(Transfer.Units.Resource, 0).Unlocked()
	.Delay(Build.Constructors, 0).Unlocked()
	.Allow(Transfer.Resources).Unlocked()
	.Tax(Transfer.Resources, 0).Unlocked()
	.Tax(Transfer.Resources.AtT2, -1).Unlocked()
	.Tax(Transfer.Resources.AtT3, -1).Unlocked()
	.Allow(Assist.Allied).Unlocked()
	.Allow(Reclaim.AlliedUnits).Unlocked()
	.Allow(Resurrect.Partial).Unlocked()
	.Allow(Take).Unlocked()
	.Delay(Take.Resource, 30).Unlocked()
