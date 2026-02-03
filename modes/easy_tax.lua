local SharedEnums = VFS.Include("modes/global_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.Modes.EasyTax,
    name = "Easy Tax",
    desc = "Anti co-op sharing tax mode. Leverages stun to penalize sharing.",
    allowRanked = true,
    modOptions = {
        [SharedEnums.ModOptions.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.CombatUnits,
            locked = true,
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
            locked = true,
        },
        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
        },
        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
        },
        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
        },
        [SharedEnums.ModOptions.AlliedAssistMode] = {
            value = false,
            locked = true,
        },
        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = true,
            locked = false,
        },
        [SharedEnums.ModOptions.AllowPartialResurrection] = {
            value = false,
            locked = true,
        },
    }
}
