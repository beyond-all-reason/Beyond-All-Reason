-- Synced rules shared by Attack and Set Target. Disable all three for aimpoint-only ghost clicks.
return {
	switchUnitTargetToGhost = true, -- On loss of LOS and radar, use the frozen aimpoint if the allyteam has a ghost.
	switchGhostTargetToUnit = true, -- On radar or LOS contact with the same unit, use its unit ID.
	dropTargetWhenGhostExpires = true, -- Remove the Attack or Set Target entry still tied to this allyteam's expired ghost.
}
