--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Infestor Replication",
		desc = "Infestors assist an infestor that built them",
		author = "Hornet",
		date = "Nov 21, 2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end



function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if (builderID) then
		if (UnitDefNames.leginfestor.id == unitDefID) and (Spring.GetUnitDefID(builderID) == UnitDefNames.leginfestor.id) then
			local OrderUnit = Spring.GiveOrderToUnit
			OrderUnit(unitID, CMD.GUARD, { builderID }, { "shift" })
		end
	end
end

