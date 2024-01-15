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



local isBuilding = {}
local isInfestor = {}
for udid, ud in pairs(UnitDefs) do
	if string.find(ud.name, 'leginfestor') then
		isInfestor[udid] = true
		Spring.Echo(udid)
	end
	if ud.isBuilding then
		isBuilding[udid] = true
	end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID and isInfestor[unitDefID] and isInfestor[Spring.GetUnitDefID(builderID)] then
		local OrderUnit = Spring.GiveOrderToUnit
		OrderUnit(unitID, CMD.GUARD, { builderID },            { "shift" })
	end
end

