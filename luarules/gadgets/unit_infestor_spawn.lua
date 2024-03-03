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



local infestorId = UnitDefNames.leginfestor.id

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if (builderID) then
        if (infestorId == unitDefID) and (Spring.GetUnitDefID(builderID) == infestorId) then
            local OrderUnit = Spring.GiveOrderToUnit
            OrderUnit(unitID, CMD.GUARD, { builderID }, { "shift" })
        end
    end
end
