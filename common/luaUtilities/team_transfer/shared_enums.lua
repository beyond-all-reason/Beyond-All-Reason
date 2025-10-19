local M = {}
M.__index = M

M.TransferCategory = {
	MetalTransfer = "metal_transfer",
	EnergyTransfer = "energy_transfer",
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

return M
