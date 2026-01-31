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
            bounds = {
                min = 0,
                max = 100000,
            }
        },
        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = false,
        },
        [SharedEnums.ModOptions.TransportDropper] = {
            value = true,
            locked = false,
            ui = "hidden",
        },
        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted,
            locked = false,
        },
    }
}
