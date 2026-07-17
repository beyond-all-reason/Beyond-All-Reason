local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

---@type ModeConfig
return {
	key = ModeEnums.Modes.Customize,
	category = ModeEnums.ModeCategories.Sharing,
	name = "Customize",
	desc = "Tweak everything. Switching to Customize keeps the current mode's settings as a starting point (defaults if you start here).",
	allowRanked = true,
	-- non-sticky: keeps current values; entries below only expose/unlock options (values ignored by lobby).
	retainValues = true,
	modOptions = {
		[ModeEnums.ModOptions.TechBlocking] = {
			value = false,
			locked = false,
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
			value = ModeEnums.UnitFilterCategory.All,
			locked = false,
		},
		[ModeEnums.ModOptions.UnitSharingModeAtT2] = {
			value = ModeEnums.UnitFilterCategory.None,
			locked = false,
		},
		[ModeEnums.ModOptions.UnitSharingModeAtT3] = {
			value = ModeEnums.UnitFilterCategory.None,
			locked = false,
		},
		[ModeEnums.ModOptions.UnitShareStunSeconds] = {
			value = 0,
			locked = false,
		},
		[ModeEnums.ModOptions.UnitStunCategory] = {
			value = ModeEnums.UnitFilterCategory.Resource,
			locked = false,
		},
		[ModeEnums.ModOptions.ConstructorBuildDelay] = {
			value = 0,
			locked = false,
		},
		[ModeEnums.ModOptions.ResourceSharingEnabled] = {
			value = true,
			locked = false,
		},
		[ModeEnums.ModOptions.TaxResourceSharingAmount] = {
			value = 0,
			locked = false,
		},
		[ModeEnums.ModOptions.TaxResourceSharingAmountAtT2] = {
			value = -1,
			locked = false,
		},
		[ModeEnums.ModOptions.TaxResourceSharingAmountAtT3] = {
			value = -1,
			locked = false,
		},
		[ModeEnums.ModOptions.AlliedAssistMode] = {
			value = ModeEnums.AlliedAssistMode.Enabled,
			locked = false,
		},
		[ModeEnums.ModOptions.AlliedUnitReclaimMode] = {
			value = ModeEnums.AlliedUnitReclaimMode.Enabled,
			locked = false,
		},
		[ModeEnums.ModOptions.AllowPartialResurrection] = {
			value = ModeEnums.AllowPartialResurrection.Enabled,
			locked = false,
		},
		[ModeEnums.ModOptions.TakeMode] = {
			value = ModeEnums.TakeMode.Enabled,
			locked = false,
		},
		[ModeEnums.ModOptions.TakeDelaySeconds] = {
			value = 30,
			locked = false,
		},
		[ModeEnums.ModOptions.TakeDelayCategory] = {
			value = ModeEnums.UnitCategory.Resource,
			locked = false,
		},
	},
}
