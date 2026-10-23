---@alias TransferPolicyType "metal_transfer" | "energy_transfer" | "unit_transfer"

local VFS = VFS

local ResourceTypes = VFS.Include("gamedata/resource_types.lua")

local M = {}

M.PolicyType = {
	MetalTransfer = "metal_transfer",
	EnergyTransfer = "energy_transfer",
	UnitTransfer = "unit_transfer",
}

M.ResourceType = ResourceTypes

M.ResourceTermsCase = {
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
}

M.UnitValidationOutcome = {
	Failure = "Failure",
	PartialSuccess = "PartialSuccess",
	Success = "Success",
}

M.ModeCategories = {
	Transfer = "transfer",
}

M.ModOptions = {
	ResourceSharingEnabled = "resource_sharing_enabled",
	TaxResourceSharingAmount = "tax_resource_sharing_amount",
	UnitSharingMode = "unit_sharing_mode",
	UnitShareStunSeconds = "unit_share_stun_seconds",
	UnitStunCategory = "unit_stun_category",
}

---@class StunDelayField
---@field StunDelay "stun_delay"

return M
