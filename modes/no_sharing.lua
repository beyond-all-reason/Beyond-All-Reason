local GlobalEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = GlobalEnums.Modes.NoSharing,
    name = "No Sharing",
    desc = "Disable all sharing; apply a 30% tax; lock most controls.",
    allowRanked = true,
    modOptions = {
        [GlobalEnums.ModOptions.UnitSharingMode] = {
            value = GlobalEnums.UnitSharingMode.Disabled,
            locked = true
        },
        [GlobalEnums.ModOptions.ResourceSharingEnabled] = {
            value = false,
            locked = true
        },
        [GlobalEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
            ui = "hidden"
        },
        [GlobalEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [GlobalEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [GlobalEnums.ModOptions.AlliedAssistMode] = {
            value = false,
            locked = true
        },
        [GlobalEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = false,
            locked = true
        },
    }
}
