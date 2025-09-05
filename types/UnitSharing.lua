---@meta

---@alias UnitSharingMode "enabled" | "t2cons" | "combat" | "combat_t2cons" | "disabled"

---@class UnitSharing
---@field getUnitSharingMode fun(): UnitSharingMode Get the current unit sharing mode from mod options
---@field isT2ConstructorDef fun(unitDef: table?): boolean Check if a unit definition is a T2 constructor
---@field isEconomicUnitDef fun(unitDef: table?): boolean Check if a unit definition is economic (energy, metal, factory, assist)
---@field isUnitShareAllowedByMode fun(unitDefID: number, mode?: UnitSharingMode): boolean Check if a unit can be shared based on the current mode
---@field countUnshareable fun(unitIDs: number[], mode?: UnitSharingMode): number, number, number Count shareable, unshareable, and total units (returns shareable, unshareable, total)
---@field shouldShowShareButton fun(unitIDs: number[], mode?: UnitSharingMode): boolean Determine if the share button should be shown for the given units
---@field blockMessage fun(unshareable: number?, mode?: UnitSharingMode): string? Get the appropriate block message for the sharing mode
---@field clearCache fun() Clear the internal unit cache
---@field isCacheInitialized fun(mode?: UnitSharingMode): boolean Check if cache is initialized for a mode
---@field getCacheStats fun(): table<UnitSharingMode, number> Get cache statistics for debugging
