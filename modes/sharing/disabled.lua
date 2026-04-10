local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

---@type ModeConfig
return {
    key = ModeEnums.Modes.Disabled,
    category = ModeEnums.ModeCategories.Sharing,
    name = "Disabled",
    desc = "Disable all sharing; apply a 30% tax; lock most controls.",
    allowRanked = true,
    modOptions = {
        [ModeEnums.ModOptions.UnitSharingMode] = {
            value = ModeEnums.UnitFilterCategory.None,
            locked = true
        },
        [ModeEnums.ModOptions.ResourceSharingEnabled] = {
            value = false,
            locked = true
        },
        [ModeEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
            ui = "hidden"
        },
        [ModeEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [ModeEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [ModeEnums.ModOptions.AlliedAssistMode] = {
            value = ModeEnums.AlliedAssistMode.Disabled,
            locked = true
        },
        [ModeEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = ModeEnums.AlliedUnitReclaimMode.Disabled,
            locked = true
        },
        [ModeEnums.ModOptions.TakeMode] = {
            value = ModeEnums.TakeMode.Disabled,
            locked = false,
        },
    }
}
