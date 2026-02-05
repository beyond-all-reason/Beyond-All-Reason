local GlobalEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = GlobalEnums.Modes.Enabled,
    name = "Enabled",
    desc = "All sharing on with fixed defaults.",
    allowRanked = true,
    modOptions = {
        [GlobalEnums.ModOptions.UnitSharingMode] = {
            value = GlobalEnums.UnitSharingMode.Enabled,
            locked = true,
        },
        [GlobalEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = true,
        },
        [GlobalEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.0,
            locked = true,
            ui = "hidden"
        },
        [GlobalEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [GlobalEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [GlobalEnums.ModOptions.AlliedAssistMode] = {
            value = true,
            locked = true,
        },
        [GlobalEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = true,
            locked = true,
        },
    }
}
