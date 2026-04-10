local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

---@type ModeConfig
return {
    key = ModeEnums.Modes.Customize,
    category = ModeEnums.ModeCategories.Sharing,
    name = "Customize",
    desc = "Choose your own settings.",
    allowRanked = true,
    modOptions = {
        [ModeEnums.ModOptions.UnitSharingMode] = {
            value = ModeEnums.UnitFilterCategory.All,
            locked = false,
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
            value = 0,
            locked = false
        },
        [ModeEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = false
        },
        [ModeEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = false
        },
        [ModeEnums.ModOptions.AlliedAssistMode] = {
            value = ModeEnums.AlliedAssistMode.Enabled,
            locked = false
        },
        [ModeEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = ModeEnums.AlliedUnitReclaimMode.Enabled,
            locked = false
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
    }
}
