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

local SetUnitNoSelect = Spring.SetUnitNoSelect
local SetUnitNoGroup = Spring.SetUnitNoGroup

local function setUnitNoGroup(_, unitID, noGroup)
	SetUnitNoGroup(unitID, noGroup)
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("setUnitNoGroup", setUnitNoGroup)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("setUnitNoGroup")
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	SetUnitNoSelect(unitID, true)
	SetUnitNoGroup(unitID, true)
end
