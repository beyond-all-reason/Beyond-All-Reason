--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Liche Cruise Control",
		desc = "Prevent Liches diving when attacking",
		author = "Hornet, Robert",
		date = "March 1st, 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spMoveCtrlSetAirMoveTypeData = Spring.MoveCtrl.SetAirMoveTypeData

local liche = {}
local epicliche = {}

if UnitDefNames.armliche then
    liche[UnitDefNames.armliche.id] = true
    if (UnitDefNames.armliche_scav) then
        liche[UnitDefNames.armliche_scav.id] = true
    end
	if UnitDefNames.armlichet4 then
		epicliche[UnitDefNames.armlichet4.id] = true
	end
	if UnitDefNames.armlichet4_scav then
		epicliche[UnitDefNames.armlichet4_scav.id] = true
	end
    --epic liche will not respect restrictions, it either dips anyway or flat out refuses to bomb; omission is not an oversight

end

function gadget:Initialize()
	if table.count(liche) <= 0 and table.count(epicliche) <= 0 then
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if liche[unitDefID] then
		spMoveCtrlSetAirMoveTypeData(unitID, "attackSafetyDistance", 3000)
	end
	if epicliche[unitDefID] then
		spMoveCtrlSetAirMoveTypeData(unitID, "attackSafetyDistance", 20000)
	end
end
