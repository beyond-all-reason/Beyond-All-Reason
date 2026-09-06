local ModeDSL = VFS.Include("modules/transfer/mode_dsl.lua") ---@type TransferModeDSL
local Mode, Transfer, Construction, Take, Tech =
	ModeDSL.Mode, ModeDSL.Transfer, ModeDSL.Construction, ModeDSL.Take, ModeDSL.Tech
local TechModule = VFS.Include("modules/tech/contract.lua") ---@type TechContract

-- stylua: ignore
return Mode("Customize")
	.Desc(
		"Tweak everything. Switching to Customize keeps the current mode's settings as a starting point (defaults if you start here)."
	)
	.Ranked()
	.RetainValues()
	.Uses(TechModule)
	.Open(Tech, 1, 1.5).Unlocked()
	.Allow(Transfer.Units).Unlocked()
	.Deny(Transfer.Units.AtT2).Unlocked()
	.Deny(Transfer.Units.AtT3).Unlocked()
	.Stun(Transfer.Units.Resource, 0).Unlocked()
	.Delay(Construction.Build, 0).Unlocked()
	.Allow(Transfer.Resources).Unlocked()
	.Tax(Transfer.Resources, 0).Unlocked()
	.Tax(Transfer.Resources.AtT2, -1).Unlocked()
	.Tax(Transfer.Resources.AtT3, -1).Unlocked()
	.Allow(Construction.Assist).Unlocked()
	.Allow(Construction.Reclaim).Unlocked()
	.Allow(Construction.Resurrect).Unlocked()
	.Allow(Take).Unlocked()
	.Delay(Take.Resource, 30).Unlocked()
