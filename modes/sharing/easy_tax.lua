local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

---@type ModeConfig
return {
    key = ModeEnums.Modes.EasyTax,
    category = ModeEnums.ModeCategories.Sharing,
    name = "Easy Tax",
    desc = "Anti co-op sharing tax mode. Leverages stun to penalize sharing.",
    allowRanked = true,
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
            locked = false,
        },
        [ModeEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = false,
        },
        [ModeEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
        },
        [ModeEnums.ModOptions.AlliedAssistMode] = {
            value = ModeEnums.AlliedAssistMode.Disabled,
            locked = false,
        },
        [ModeEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = ModeEnums.AlliedUnitReclaimMode.Enabled,
            locked = false,
        },
        [ModeEnums.ModOptions.AllowPartialResurrection] = {
            value = ModeEnums.AllowPartialResurrection.Disabled,
            locked = false,
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
            locked = false,
        },
    }
}
