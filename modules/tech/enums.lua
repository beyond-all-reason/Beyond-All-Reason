local M = {}

M.ModOptions = {
	TechBlocking = "tech_blocking",
	T2TechThreshold = "t2_tech_threshold",
	T3TechThreshold = "t3_tech_threshold",
	-- transfer's grants, varied by tier: what a team may share and at what tax once it reaches Tech 2 and Tech 3
	UnitSharingModeAtT2 = "unit_sharing_mode_at_t2",
	UnitSharingModeAtT3 = "unit_sharing_mode_at_t3",
	TaxResourceSharingAmountAtT2 = "tax_resource_sharing_amount_at_t2",
	TaxResourceSharingAmountAtT3 = "tax_resource_sharing_amount_at_t3",
}

return M
