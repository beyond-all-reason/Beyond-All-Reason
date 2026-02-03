local SharedEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.Modes.Customize,
    name = "Customize",
    desc = "Choose your own settings.",
    allowRanked = true,
    modOptions = {
        [SharedEnums.ModOptions.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.Enabled,
            locked = false,
        },
        [SharedEnums.ModOptions.UnitShareStunSeconds] = {
            value = 30,
            locked = false,
        },
        [SharedEnums.ModOptions.UnitStunCategory] = {
            value = SharedEnums.UnitStunCategory.EconomicAndBuilders,
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
            value = true,
            locked = false
        },
        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = true,
            locked = false
        },
        [SharedEnums.ModOptions.AllowPartialResurrection] = {
            value = true,
            locked = false,
        },
    }
}
