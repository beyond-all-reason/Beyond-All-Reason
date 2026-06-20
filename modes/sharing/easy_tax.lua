local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

---@type ModeConfig
return {
	key = ModeEnums.Modes.EasyTax,
	category = ModeEnums.ModeCategories.Sharing,
	name = "Easy Tax",
	desc = "Anti co-op sharing tax mode. Tax on resource sharing, assist, and resurrection. Eco buildings stunned, mobile constructors debuffed.",
	allowRanked = true,
	-- Curated preset: structural choices are locked to the mode's intent; only the
	-- intensity dials (rates/durations) stay editable. Use Customize for full control.
	modOptions = {
		[ModeEnums.ModOptions.UnitSharingMode] = {
			value = ModeEnums.UnitFilterCategory.All,
			locked = true,
		},
		[ModeEnums.ModOptions.UnitShareStunSeconds] = {
			value = 30,
			locked = false,
		},
		[ModeEnums.ModOptions.UnitStunCategory] = {
			value = ModeEnums.UnitFilterCategory.Resource,
			locked = true,
		},
		[ModeEnums.ModOptions.ConstructorBuildDelay] = {
			value = 30,
			locked = false,
		},
		[ModeEnums.ModOptions.ResourceSharingEnabled] = {
			value = true,
			locked = true,
		},
		[ModeEnums.ModOptions.TaxResourceSharingAmount] = {
			value = 0.30,
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
			value = ModeEnums.AllowPartialResurrection.Enabled,
			locked = true,
		},
		[ModeEnums.ModOptions.TakeMode] = {
			value = ModeEnums.TakeMode.StunDelay,
			locked = true,
		},
		[ModeEnums.ModOptions.TakeDelaySeconds] = {
			value = 30,
			locked = false,
		},
		[ModeEnums.ModOptions.TakeDelayCategory] = {
			value = ModeEnums.UnitCategory.Resource,
			locked = true,
		},
	},
}
