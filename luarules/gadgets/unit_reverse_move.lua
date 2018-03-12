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
	refreshrate = 15
	reverseUnit = {}
	function gadget:UnitCreated(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)
		if not (UnitDefs[unitDefID].rSpeed == nil or UnitDefs[unitDefID].rSpeed == 0) then
			reverseUnit[unitID] = true
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", UnitDefs[unitDefID].speed)	
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", 0)		
		end
	end
	
	function gadget:UnitDestroyed(unitID) -- Erase killed units from table
		if reverseUnit[unitID] then
			reverseUnit[unitID] = nil
		end
	end
	
	function gadget:Initialize()
		for ct, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
		end
	end
	
	function gadget:GameFrame(f)
		if f%refreshrate == 0 then
			for unitID, rev in pairs(reverseUnit) do
				local cmd = Spring.GetUnitCommands(unitID, 1)
				local unitDefID = Spring.GetUnitDefID(unitID)
				if cmd and cmd[1] and cmd[1]["options"] and cmd[1]["options"].ctrl then
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", UnitDefs[unitDefID].rSpeed)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", UnitDefs[unitDefID].rSpeed)
				else
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", UnitDefs[unitDefID].speed)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", 0)
				end
			end
		end
	end
end