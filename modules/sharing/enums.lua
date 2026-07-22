local ResourceTypes = VFS.Include("gamedata/resource_types.lua")

local M = {}

M.PolicyType = {
	MetalTransfer = "metal_transfer",
	EnergyTransfer = "energy_transfer",
	UnitTransfer = "unit_transfer",
}

M.ResourceType = ResourceTypes

-- Policy pipeline categories; values ARE the policies/<value>.lua filenames
-- (ModuleHandler.LoadPolicies keys pipelines by filename).
M.PolicyCategory = {
	Resource = "resource",
	Unit = "unit",
}

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

M.UnitType = {
	Combat = "combat",
	Commander = "commander",
	Constructor = "constructor",
	Factory = "factory",
	Resource = "resource",
	Utility = "utility",
}

return M
