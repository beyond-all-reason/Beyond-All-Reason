local M = {}

---@class EnabledField
---@field Enabled "enabled"

---@class DisabledField
---@field Disabled "disabled"

---@class AllField
---@field All "all"

---@class NoneField
---@field None "none"

---@class UnitCategoryFields
---@field Combat "combat"
---@field Buildings "buildings"
---@field Constructors "constructors"
---@field Resource "resource"
---@field NonCombat "non_combat"

---@class AlliedAssistModeFields : EnabledField, DisabledField
---@class AlliedUnitReclaimModeFields : EnabledField, DisabledField
---@class AllowPartialResurrectionFields : EnabledField, DisabledField
---@class UnitFilterCategoryFields : UnitCategoryFields, AllField, NoneField

M.ModOptions = {
	AlliedAssistMode = "allied_assist_mode",
	AlliedUnitReclaimMode = "allied_reclaim_mode",
	ConstructorBuildDelay = "constructor_build_delay",
	AllowPartialResurrection = "allow_partial_resurrection",
}

---@type AlliedAssistModeFields
M.AlliedAssistMode = {
	Enabled = "enabled",
	Disabled = "disabled",
}

---@type AlliedUnitReclaimModeFields
M.AlliedUnitReclaimMode = {
	Enabled = "enabled",
	Disabled = "disabled",
}

---@type AllowPartialResurrectionFields
M.AllowPartialResurrection = {
	Enabled = "enabled",
	Disabled = "disabled",
}

M.UnitType = {
	Combat = "combat",
	Commander = "commander",
	Constructor = "constructor",
	Factory = "factory",
	Resource = "resource",
	Utility = "utility",
}

---@type UnitCategoryFields
M.UnitCategory = {
	Combat = "combat",
	Buildings = "buildings",
	Constructors = "constructors",
	Resource = "resource",
	NonCombat = "non_combat",
}

---@type UnitFilterCategoryFields
M.UnitFilterCategory = {
	All = "all",
	None = "none",
	Combat = "combat",
	Buildings = "buildings",
	Constructors = "constructors",
	Resource = "resource",
	NonCombat = "non_combat",
}

return M
