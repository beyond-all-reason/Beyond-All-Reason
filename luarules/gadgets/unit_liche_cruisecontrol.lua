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



local licheId = UnitDefNames.armliche.id

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    if unitDefID == licheId then
        local opts = {}
        opts.attackSafetyDistance = 3000
        Spring.MoveCtrl.SetAirMoveTypeData(unitID, opts)
    end
end
