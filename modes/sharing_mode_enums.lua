local M = {}

---@class EnabledField
---@field Enabled "enabled"

---@class DisabledField
---@field Disabled "disabled"

---@class AllField
---@field All "all"

---@class NoneField
---@field None "none"

---@class StunDelayField
---@field StunDelay "stun_delay"

---@class TakeDelayField
---@field TakeDelay "take_delay"

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
---@class TakeModeFields : EnabledField, DisabledField, StunDelayField, TakeDelayField

M.ModOptions = {
	AlliedAssistMode = "allied_assist_mode",
	AlliedUnitReclaimMode = "allied_reclaim_mode",
	ConstructorBuildDelay = "constructor_build_delay",
	ResourceSharingEnabled = "resource_sharing_enabled",
	AllowPartialResurrection = "allow_partial_resurrection",
	SharingMode = "sharing_mode",
	TakeMode = "take_mode",
	TakeDelaySeconds = "take_delay_seconds",
	TakeDelayCategory = "take_delay_category",
	TaxResourceSharingAmount = "tax_resource_sharing_amount",
	TaxResourceSharingAmountAtT2 = "tax_resource_sharing_amount_at_t2",
	TaxResourceSharingAmountAtT3 = "tax_resource_sharing_amount_at_t3",
	TechBlocking = "tech_blocking",
	T2TechThreshold = "t2_tech_threshold",
	T3TechThreshold = "t3_tech_threshold",
	UnitSharingMode = "unit_sharing_mode",
	UnitSharingModeAtT2 = "unit_sharing_mode_at_t2",
	UnitSharingModeAtT3 = "unit_sharing_mode_at_t3",
	UnitShareStunSeconds = "unit_share_stun_seconds",
	UnitStunCategory = "unit_stun_category",
}

M.ModeCategories = {
	Sharing = "sharing",
}

M.Modes = {
	Disabled = "disabled",
	Enabled = "enabled",
	EasyTax = "easy_tax",
	Customize = "customize",
	TechCore = "tech_core",
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

---@type TakeModeFields
M.TakeMode = {
	Enabled = "enabled",
	Disabled = "disabled",
	StunDelay = "stun_delay",
	TakeDelay = "take_delay",
}

return M
