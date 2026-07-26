local ModeDSL = VFS.Include("modules/sharing/mode_dsl.lua")
local Mode, Share, Assist, Reclaim, Resurrect, Build, Take, Tech =
	ModeDSL.Mode, ModeDSL.Share, ModeDSL.Assist, ModeDSL.Reclaim, ModeDSL.Resurrect, ModeDSL.Build, ModeDSL.Take, ModeDSL.Tech

-- Every policy exposed unlocked; values are only the starting point (RetainValues).
return Mode("Customize")
	.Desc("Tweak everything. Switching to Customize keeps the current mode's settings as a starting point (defaults if you start here).")
	.Ranked()
	.RetainValues()
	.Open(Tech, 1, 1.5).Unlocked()
	.Allow(Share.Units).Unlocked()
	.Deny(Share.Units.AtT2).Unlocked()
	.Deny(Share.Units.AtT3).Unlocked()
	.Stun(Share.Units.Resource, 0).Unlocked()
	.Delay(Build.Constructors, 0).Unlocked()
	.Allow(Share.Resources).Unlocked()
	.Tax(Share.Resources, 0).Unlocked()
	.Tax(Share.Resources.AtT2, -1).Unlocked()
	.Tax(Share.Resources.AtT3, -1).Unlocked()
	.Allow(Assist.Allied).Unlocked()
	.Allow(Reclaim.AlliedUnits).Unlocked()
	.Allow(Resurrect.Partial).Unlocked()
	.Allow(Take).Unlocked()
	.Delay(Take.Resource, 30).Unlocked()
