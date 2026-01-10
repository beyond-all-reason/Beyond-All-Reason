local M = {}
M.__index = M

M.ModOptions = {
	AlliedAssistMode = "allied_assist_mode",
	AlliedUnitReclaimMode = "allied_reclaim_mode",
	PlayerEnergySendThreshold = "player_energy_send_threshold",
	PlayerMetalSendThreshold = "player_metal_send_threshold",
	ResourceSharingEnabled = "resource_sharing_enabled",
	SharingMode = "sharing_mode",
	TaxResourceSharingAmount = "tax_resource_sharing_amount",
	UnitSharingMode = "unit_sharing_mode",
}

M.SharingModes = {
	NoSharing = "no_sharing",
	LimitedSharing = "limited_sharing",
	Enabled = "enabled",
	Customize = "customize",
}

M.PolicyType = Spring and Spring.PolicyType or {
	MetalTransfer = 1,
	EnergyTransfer = 2,
	UnitTransfer = 3,
}

M.TransferCategory = M.PolicyType

M.ResourceType = {
	METAL = "metal",
	ENERGY = "energy",
}

M.ResourceTypes = { M.ResourceType.METAL, M.ResourceType.ENERGY }

M.ResourceCommunicationCase = {
	OnSelf = 1,
	OnTaxFree = 2,
	OnTaxedThreshold = 3,
	OnTaxed = 4,
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

M.UnitSharingMode = {
	Disabled = "disabled",
	CombatT2Cons = "combat_t2_cons",
	CombatUnits = "combat",
	Economic = "economic",
	EconomicPlusBuildings = "economic_plus_buildings",
	Enabled = "enabled",
	T2Cons = "t2_cons",
}

M.UnitType = {
	Combat = "combat",
	Economic = "economic",
	Utility = "utility",
	T2Constructor = "t2_constructor",
}

M.AlliedAssistMode = {
	Disabled = "disabled",
	Enabled = "enabled",
}

M.AlliedUnitReclaimMode = {
	Disabled = "disabled",
	EnabledAutomationRestricted = "enabled_automation_restricted",
}

return M
