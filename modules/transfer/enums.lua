local ResourceTypes = VFS.Include("gamedata/resource_types.lua")

local M = {}

M.PolicyType = {
	MetalTransfer = "metal_transfer",
	EnergyTransfer = "energy_transfer",
	UnitTransfer = "unit_transfer",
}

M.ResourceType = ResourceTypes

M.ResourceCommunicationCase = {
	OnSelf = 1,
	OnTaxFree = 2,
	OnTaxed = 3,
	OnDisabled = 4,
}

M.UnitCommunicationCase = {
	OnSelf = 1,
	OnFullyShareable = 2,
	OnPartiallyShareable = 3,
	OnPolicyDisabled = 4,
	OnSelectionValidationFailed = 5,
	OnTechBlocked = 6,
}

M.UnitValidationOutcome = {
	Failure = "Failure",
	PartialSuccess = "PartialSuccess",
	Success = "Success",
}

M.ModeCategories = {
	Transfer = "transfer",
}

M.Modes = {
	Disabled = "disabled",
	Enabled = "enabled",
	EasyTax = "easy_tax",
	Customize = "customize",
	TechCore = "tech_core",
}

M.ModOptions = {
	ResourceSharingEnabled = "resource_sharing_enabled",
	TransferMode = "transfer_mode",
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

---@class StunDelayField
---@field StunDelay "stun_delay"

---@class TakeDelayField
---@field TakeDelay "take_delay"

---@class TakeModeFields : EnabledField, DisabledField, StunDelayField, TakeDelayField

---@type TakeModeFields
M.TakeMode = {
	Enabled = "enabled",
	Disabled = "disabled",
	StunDelay = "stun_delay",
	TakeDelay = "take_delay",
}

return M
