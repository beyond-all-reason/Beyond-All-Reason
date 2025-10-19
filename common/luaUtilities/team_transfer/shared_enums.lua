local M = {}
M.__index = M

M.TransferCategory = {
	MetalTransfer = "metal_transfer",
	EnergyTransfer = "energy_transfer",
	UnitTransfer = "unit_transfer"
}

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
	Success = "Success",
	Failure = "Failure",
	PartialSuccess = "PartialSuccess",
}

M.UnitSharingMode = {
	Disabled = "disabled",
	Enabled = "enabled",
	CombatUnits = "combat",
	Economic = "economic",
	EconomicPlusBuildings = "economic_plus_buildings",
	T2Cons = "t2_cons",
	CombatT2Cons = "combat_t2_cons",
}

M.UnitType = {
	Combat = "combat",
	Economic = "economic",
	Utility = "utility",
	T2Constructor = "t2_constructor",
}

return M
