local GlobalEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = GlobalEnums.Modes.EasyTax,
    name = "Easy Tax",
    desc = "Anti co-op sharing tax mode. Leverages stun to penalize sharing.",
    allowRanked = true,
    modOptions = {
        [GlobalEnums.ModOptions.UnitSharingMode] = {
            value = GlobalEnums.UnitSharingMode.Enabled,
            locked = true,
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
            locked = true,
        },
        [GlobalEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
        },
        [GlobalEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
        },
        [GlobalEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
        },
        [GlobalEnums.ModOptions.AlliedAssistMode] = {
            value = false,
            locked = true,
        },
        [GlobalEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = true,
            locked = false,
        },
        [GlobalEnums.ModOptions.AllowPartialResurrection] = {
            value = false,
            locked = true,
        },
    }
}
