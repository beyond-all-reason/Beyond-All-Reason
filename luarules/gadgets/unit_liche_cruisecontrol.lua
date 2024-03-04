--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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


if UnitDefNames.armliche then
    local liche = {}
    liche[UnitDefNames.armliche.id] = true

    if (UnitDefNames.armliche_scav) then
        liche[UnitDefNames.armliche_scav.id] = true
    end
    --epic liche will not respect restrictions, it either dips anyway or flat out refuses to bomb; omission is not an oversight


    function gadget:UnitFinished(unitID, unitDefID, unitTeam)
        if liche[unitDefID] then
            spMoveCtrlSetAirMoveTypeData(unitID, {attackSafetyDistance = 3000})
        end
    end
else
    gadgetHandler:RemoveGadget(self)
end
