local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.SharingModes.LimitedSharing,
    name = "Limited Sharing",
    desc = "Allow T2 constructor sharing and payment, otherwise restrict sharing.",
    allowRanked = true,
    modOptions = {
        [SharedEnums.ModOptions.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.T2Cons,
            locked = true,
        },
        [SharedEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = true,
        },
        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
        },
        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 440,
            locked = false,
        },
        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = false,
        },
        [SharedEnums.ModOptions.AlliedAssist] = {
            value = SharedEnums.AlliedAssistMode.Enabled,
            locked = false,
        },
        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = SharedEnums.AlliedUnitReclaimMode.Enabled,
            locked = false,
        },
    }
}
