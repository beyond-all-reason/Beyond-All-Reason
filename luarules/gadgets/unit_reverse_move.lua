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
		local unitDefID = Spring.GetUnitDefID(unitID)
		if not (UnitDefs[unitDefID].rSpeed == nil or UnitDefs[unitDefID].rSpeed == 0) then
			-- Spring.Echo("Setting for "..unitID)
			reverseUnit[unitID] = true
				if (UnitDefs[unitDefID].rSpeed/UnitDefs[unitDefID].speed) >= 50 then
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 300)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 140)
				else
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 180)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 160)
				end
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
		local unitDefID = Spring.GetUnitDefID(unitID)
				if a ~= 0 and not (UnitDefs[unitDefID].isBuilder == true) then
					if (UnitDefs[unitDefID].rSpeed/UnitDefs[unitDefID].speed) >= 50 then
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 5000000)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 90)
					else
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 5000000)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
					end
				else
					if (UnitDefs[unitDefID].rSpeed/UnitDefs[unitDefID].speed) >= 50 then
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 300)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 140)
					else
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 180)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 160)
					end
				end
		end
	end
end
