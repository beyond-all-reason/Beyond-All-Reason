function gadget:GetInfo()
	return {
		name = "ReverseMovementHandler",
		desc = "Sets reverse speeds/angles/distances",
		author = "[Fx]Doo",
		date = "27 of July 2017",
		license = "Free",
		layer = 0,
		enabled = true
	}
end


if (gadgetHandler:IsSyncedCode()) then
	function gadget:UnitCreated(unitID)
		unitDefID = Spring.GetUnitDefID(unitID)
		if not (UnitDefs[unitDefID].rSpeed == nil or UnitDefs[unitDefID].rSpeed == 0) then
			-- Spring.Echo("Setting for "..unitID)
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 512)
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 140)
		end
	end
end