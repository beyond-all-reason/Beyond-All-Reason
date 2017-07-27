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
reverseUnit = {}
	function gadget:UnitCreated(unitID)
		unitDefID = Spring.GetUnitDefID(unitID)
		if not (UnitDefs[unitDefID].rSpeed == nil or UnitDefs[unitDefID].rSpeed == 0) then
			Spring.Echo("Setting for "..unitID)
			reverseUnit[unitID] = true
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 512)
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 140)
		end
	end
	
	function gadget:UnitDestroyed(unitID)
		if reverseUnit[unitID] then
			reverseUnit[unitID] = nil
		end
	end
	
	function gadget:GameFrame(f)
	-- Spring.Echo("XXX")
		for unitID, canReverse in pairs(reverseUnit) do
		a, b, c, d, e = Spring.GetUnitWeaponTarget(unitID, 1)
				if a ~= 0 then
					-- Spring.Echo(unitID.." is targetting")
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 150000)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 90)
				else
					-- Spring.Echo(unitID.." stopped targetting")
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 512)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 140)
				end
		end
	end
end
