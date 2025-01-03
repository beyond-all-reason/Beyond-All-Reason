function gadget:GetInfo()
	return {
		name      = "Remove dead units",
		desc      = "Remove dead units from engine lists where possible",
		license   = "GNU GPL, v2 or later",
		layer     = -1999999,
		enabled   = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	Spring.SetUnitNoSelect(unitID, true)
	if Spring.SetUnitNoGroup then
		Spring.SetUnitNoGroup(unitID, true)
	else
		Spring.SetUnitGroup(unitID, -1)
	end
end
