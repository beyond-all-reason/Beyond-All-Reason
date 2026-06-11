local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Dead Unit",
		desc = "Remove behaviours from dead units",
		license = "GNU GPL, v2 or later",
		layer = -1999999,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	Engine.Unsynced.SetUnitNoSelect(unitID, true)
	if Engine.Unsynced.SetUnitNoGroup then
		Engine.Unsynced.SetUnitNoGroup(unitID, true)
	else
		Engine.Unsynced.SetUnitGroup(unitID, -1)
	end
end
