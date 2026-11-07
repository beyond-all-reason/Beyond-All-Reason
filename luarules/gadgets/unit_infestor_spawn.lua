--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Infestor Replication",
		desc = "Infestors assist an infestor that built them",
		author = "Hornet",
		date = "Nov 21, 2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- both the builder and the new unit must carry customparams.guards_own_builder
local infestor = {}

-- setup
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.guards_own_builder then
		infestor[unitDefID] = true
	end
end

function gadget:Initialize()
	if table.count(infestor) <= 0 then
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID then
		if infestor[unitDefID] and infestor[Spring.GetUnitDefID(builderID)] then
			Spring.GiveOrderToUnit(unitID, CMD.GUARD, { builderID }, { "shift" })
		end
	end
end
