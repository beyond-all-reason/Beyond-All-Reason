local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.SharingModes.NoSharing,
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
            value = SharedEnums.AlliedAssistMode.Disabled,
            locked = true
        },
        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = SharedEnums.AlliedUnitReclaimMode.Disabled,
            locked = true
        },
    }
}
