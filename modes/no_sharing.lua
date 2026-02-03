local SharedEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.Modes.NoSharing,
    name = "No Sharing",
    desc = "Disable all sharing; apply a 30% tax; lock most controls.",
    allowRanked = true,
    modOptions = {
        [SharedEnums.ModOptions.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.Disabled,
            locked = true
        },
        [SharedEnums.ModOptions.ResourceSharingEnabled] = {
            value = false,
            locked = true
        },
        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
            ui = "hidden"
        },
        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [SharedEnums.ModOptions.AlliedAssistMode] = {
            value = false,
            locked = true
        },
        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = false,
            locked = true
        },
    }
}
