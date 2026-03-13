local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

---@type ModeConfig
return {
    key = ModeEnums.Modes.Enabled,
    category = ModeEnums.ModeCategories.Sharing,
    name = "Enabled",
    desc = "All sharing on with fixed defaults.",
    allowRanked = true,
    modOptions = {
        [ModeEnums.ModOptions.UnitSharingMode] = {
            value = ModeEnums.UnitFilterCategory.All,
            locked = true,
        },
        [ModeEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = true,
        },
        [ModeEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.0,
            locked = true,
            ui = "hidden"
        },
        [ModeEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [ModeEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [ModeEnums.ModOptions.AlliedAssistMode] = {
            value = ModeEnums.AlliedAssistMode.Enabled,
            locked = true,
        },
        [ModeEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = ModeEnums.AlliedUnitReclaimMode.Enabled,
            locked = true,
        },
        [ModeEnums.ModOptions.TakeMode] = {
            value = ModeEnums.TakeMode.Enabled,
            locked = true,
        },
    }
}
