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
	
	function CheckWeaponTarget(Xt,Yt,Zt,Xu,Yu,Zu,DXu,DZu)
	DXt = (Xt - Xu)/ math.sqrt((Xt - Xu)^2 + (Zt - Zu)^2)
	DZt = (Zt - Zu)/ math.sqrt((Xt - Xu)^2 + (Zt - Zu)^2)
	i = DXu * DXt + DZu * DZt
	-- Spring.Echo(i)
	if i > 0 then
	-- Spring.Echo("Facing Target")
	return true
	else
	return false
	end
	end
	
	function gadget:GameFrame(f)
	-- Spring.Echo("XXX")
		for unitID, canReverse in pairs(reverseUnit) do
		a, b, c, d, e = Spring.GetUnitWeaponTarget(unitID, 1)
		if a ~= 0 then
		if a == 2 then
		Xt, Yt, Zt = c[1], c[2], c[3]
		end
		if a == 1 then
		Xt, Yt, Zt = Spring.GetUnitPosition(c)
		end
		if a == 3 then
		Xt, Yt, Zt = Spring.GetProjectilePosition(c)
		end
		Xu,Yu,Zu = Spring.GetUnitPosition(unitID)
		DXu,DYu,DZu = Spring.GetUnitDirection(unitID)
		DXu = DXu/math.sqrt((DXu^2 + DZu^2))
		DZu = DZu/math.sqrt((DXu^2 + DZu^2))
		isFront = CheckWeaponTarget(Xt,Yt,Zt,Xu,Yu,Zu,DXu,DZu)
		end
		local unitDefID = Spring.GetUnitDefID(unitID)
				if a ~= 0 and isFront == true and not (UnitDefs[unitDefID].isBuilder == true) then
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
