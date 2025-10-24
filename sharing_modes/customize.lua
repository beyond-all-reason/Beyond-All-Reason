local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.SharingModes.Customize,
    name = "Customize",
    desc = "Choose your own settings.",
    allowRanked = true,
    modOptions = {
        [SharedEnums.ModOptions.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.Enabled,
            locked = false,
        },
        [SharedEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = false,
        },
        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0,
            locked = false
        },
        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = false
        },
        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = false
        },
        [SharedEnums.ModOptions.AlliedAssistMode] = {
            value = SharedEnums.AlliedAssistMode.Enabled,
            locked = false
        },
        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted,
            locked = false
        },
    }
}
