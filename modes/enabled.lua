local SharedEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.Modes.Enabled,
    name = "Enabled",
    desc = "All sharing on with fixed defaults.",
    allowRanked = true,
    modOptions = {
        [SharedEnums.ModOptions.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.Enabled,
            locked = true,
        },
        [SharedEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = true,
        },
        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.0,
            locked = true,
            ui = "hidden"
        },
        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [SharedEnums.ModOptions.AlliedAssistMode] = {
            value = true,
            locked = true,
        },
        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = true,
            locked = true,
        },
    }
}
