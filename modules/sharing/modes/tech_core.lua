local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

---@type ModeConfig
return {
	key = ModeEnums.Modes.TechCore,
	category = ModeEnums.ModeCategories.Sharing,
	name = "Tech Core",
	desc = "Tech levels gate unit construction. Build Keystone buildings to advance. Sharing unlocks with tech. Legion's mex economy is rebalanced for the universal Voussoir.",
	allowRanked = true,
	-- curated preset: structural choices locked; only pacing dials (thresholds, tax rates, take delay) stay editable.
	modOptions = {
		[ModeEnums.ModOptions.TechBlocking] = {
			value = true,
			locked = true,
		},
		[ModeEnums.ModOptions.T2TechThreshold] = {
			value = 1,
			locked = false,
		},
		[ModeEnums.ModOptions.T3TechThreshold] = {
			value = 1.5,
			locked = false,
		},
		[ModeEnums.ModOptions.UnitSharingMode] = {
			value = ModeEnums.UnitFilterCategory.None,
			locked = true,
		},
		[ModeEnums.ModOptions.UnitSharingModeAtT2] = {
			value = ModeEnums.UnitFilterCategory.Constructors,
			locked = true,
		},
		[ModeEnums.ModOptions.UnitSharingModeAtT3] = {
			value = ModeEnums.UnitFilterCategory.None,
			locked = true,
		},
		[ModeEnums.ModOptions.ResourceSharingEnabled] = {
			value = true,
			locked = true,
		},
		[ModeEnums.ModOptions.TaxResourceSharingAmount] = {
			value = 0.6000000000,
			locked = false,
		},
		[ModeEnums.ModOptions.TaxResourceSharingAmountAtT2] = {
			value = 0.5000000000,
			locked = false,
		},
		[ModeEnums.ModOptions.TaxResourceSharingAmountAtT3] = {
			value = 0.4000000000,
			locked = false,
		},
		[ModeEnums.ModOptions.AlliedAssistMode] = {
			value = ModeEnums.AlliedAssistMode.Enabled,
			locked = true,
		},
		[ModeEnums.ModOptions.AlliedUnitReclaimMode] = {
			value = ModeEnums.AlliedUnitReclaimMode.Enabled,
			locked = true,
		},
		[ModeEnums.ModOptions.AllowPartialResurrection] = {
			value = ModeEnums.AllowPartialResurrection.Disabled,
			locked = true,
		},
		[ModeEnums.ModOptions.TakeMode] = {
			value = ModeEnums.TakeMode.TakeDelay,
			locked = true,
		},
		[ModeEnums.ModOptions.TakeDelaySeconds] = {
			value = 60,
			locked = false,
		},
		[ModeEnums.ModOptions.TakeDelayCategory] = {
			value = ModeEnums.UnitCategory.Resource,
			locked = true,
		},
	},
}
