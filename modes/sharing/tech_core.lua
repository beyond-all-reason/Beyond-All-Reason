local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

---@type ModeConfig
return {
    key = ModeEnums.Modes.TechCore,
    category = ModeEnums.ModeCategories.Sharing,
    name = "Tech Core",
    desc = "Tech levels gate unit construction. Build Catalyst buildings to advance. Sharing unlocks with tech.",
    allowRanked = true,
    modOptions = {
        [ModeEnums.ModOptions.TechBlocking] = {
            value = true,
            locked = true,
        },
        [ModeEnums.ModOptions.T2TechThreshold] = {
            value = 1,
            locked = false,
        },
        [ModeEnums.ModOptions.T3TechThreshold] = {
            value = 1.5,
            locked = false,
        },
        [ModeEnums.ModOptions.UnitSharingMode] = {
            value = ModeEnums.UnitFilterCategory.Transport,
            locked = false,
        },
        [ModeEnums.ModOptions.UnitSharingModeAtT2] = {
            value = ModeEnums.UnitFilterCategory.T2Cons,
            locked = false,
        },
        [ModeEnums.ModOptions.UnitSharingModeAtT3] = {
            value = ModeEnums.UnitFilterCategory.All,
            locked = false,
        },
        [ModeEnums.ModOptions.ResourceSharingEnabled] = {
            value = true,
            locked = false,
        },
        [ModeEnums.ModOptions.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
        },
        [ModeEnums.ModOptions.TaxResourceSharingAmountAtT2] = {
            value = 0.20,
            locked = false,
        },
        [ModeEnums.ModOptions.TaxResourceSharingAmountAtT3] = {
            value = 0.10,
            locked = false,
        },
        [ModeEnums.ModOptions.AlliedAssistMode] = {
            value = ModeEnums.AlliedAssistMode.Enabled,
            locked = false,
        },
        [ModeEnums.ModOptions.AlliedUnitReclaimMode] = {
            value = ModeEnums.AlliedUnitReclaimMode.Disabled,
            locked = false,
        },
        [ModeEnums.ModOptions.AllowPartialResurrection] = {
            value = ModeEnums.AllowPartialResurrection.Disabled,
            locked = false,
        },
        [ModeEnums.ModOptions.TakeMode] = {
            value = ModeEnums.TakeMode.TakeDelay,
            locked = true,
        },
        [ModeEnums.ModOptions.TakeDelaySeconds] = {
            value = 30,
            locked = false,
        },
        [ModeEnums.ModOptions.TakeDelayCategory] = {
            value = ModeEnums.UnitCategory.Resource,
            locked = false,
        },
    }
}
