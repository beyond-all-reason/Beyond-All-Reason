local GlobalEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = GlobalEnums.Modes.LimitedSharing,
    name = "Limited Sharing",
    desc = "Allow T2 constructor sharing and payment, otherwise restrict sharing.",
    allowRanked = true,
    modOptions = {
        [GlobalEnums.ModOptions.UnitSharingMode] = {
            value = GlobalEnums.UnitSharingMode.T2Cons,
            locked = true,
        },
        [GlobalEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = true,
        },
        [GlobalEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
        },
        [GlobalEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 440,
            locked = false,
        },
        [GlobalEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = false,
        },
        [GlobalEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = true,
            locked = false,
        },
    }
}
