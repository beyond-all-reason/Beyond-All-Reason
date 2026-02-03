local GlobalEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = GlobalEnums.Modes.Customize,
    name = "Customize",
    desc = "Choose your own settings.",
    allowRanked = true,
    modOptions = {
        [GlobalEnums.ModOptions.UnitSharingMode] = {
            value = GlobalEnums.UnitSharingMode.Enabled,
            locked = false,
        },
        [GlobalEnums.ModOptions.UnitShareStunSeconds] = {
            value = 30,
            locked = false,
        },
        [GlobalEnums.ModOptions.UnitStunCategory] = {
            value = GlobalEnums.UnitStunCategory.EconomicPlusBuildings,
            locked = false,
        },
        [GlobalEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = false,
        },
        [GlobalEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0,
            locked = false
        },
        [GlobalEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = false
        },
        [GlobalEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = false
        },
        [GlobalEnums.ModOptions.AlliedAssistMode] = {
            value = true,
            locked = false
        },
        [GlobalEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = true,
            locked = false
        },
        [GlobalEnums.ModOptions.AllowPartialResurrection] = {
            value = true,
            locked = false,
        },
    }
}
