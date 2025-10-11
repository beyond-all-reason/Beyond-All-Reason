-- Mod Options for Team Transfer Framework
-- This file can be safely included from both synced and unsynced contexts

---@class TeamTransferModOptions
local M = {}

M.Options = {
	TaxResourceSharingAmount = "tax_resource_sharing_amount",
	PlayerMetalSendThreshold = "player_metal_send_threshold",
	PlayerEnergySendThreshold = "player_energy_send_threshold",
}

return M
