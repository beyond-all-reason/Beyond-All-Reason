-- Disable BAR's default robot commander initial spawn so game_zombie_defense_mvp.lua handles HQ & Military deployment
function gadget:GetInfo()
	return {
		name = "Initial Spawn",
		desc = "Disabled in BAR Zombie Defense MVP (handled by Zombie Defense Gadget)",
		author = "BAR Zombie Defense",
		version = "v1.0",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end
