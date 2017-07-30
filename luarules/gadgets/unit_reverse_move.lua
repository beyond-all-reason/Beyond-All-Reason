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
		if not (UnitDefs[unitDefID].rSpeed == nil or UnitDefs[unitDefID].rSpeed == 0) then -- If unitID has a defined MaxReverseVelocity ~= 0.
			reverseUnit[unitID] = true -- Add to reverse units table
				if (UnitDefs[unitDefID].rSpeed/UnitDefs[unitDefID].speed) >= 50 then -- If penetrator/arti/banisher/tremor
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 300)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 140)
				else -- If not penetrator/arti/banisher/tremor
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 180)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 160)
				end
		end
	end
	
	function gadget:UnitDestroyed(unitID) -- Erase killed units from table
		if reverseUnit[unitID] then
			reverseUnit[unitID] = nil
		end
	end
	
	function CheckWeaponTarget(DXt, DXu, DXu, DZu) -- Check if unit is facing target
		i = DXu * DXt + DZu * DZt -- ScalarProduct. If < 0 then target is behind unit
		if i > 0 then
			return true -- When facing target
		else
			return false -- When not
		end
	end
	
	function gadget:GameFrame(f)
	-- Spring.Echo("XXX")
		for unitID, canReverse in pairs(reverseUnit) do
			a, b, c, d, e = Spring.GetUnitWeaponTarget(unitID, 1)
			
			if a ~= 0 then -- Has a target
				if a == 2 then -- Target = ground
					Xt, Yt, Zt = c[1], c[2], c[3]
				end
				if a == 1 then -- Target = unit
					Xt, Yt, Zt = Spring.GetUnitPosition(c)
				end
				if a == 3 then -- Target = projectile
					Xt, Yt, Zt = Spring.GetProjectilePosition(c)
				end
				Xu,Yu,Zu = Spring.GetUnitPosition(unitID)
				DXu,DYu,DZu = Spring.GetUnitDirection(unitID)
				DXu = DXu/math.sqrt((DXu^2 + DZu^2)) -- UnitDirectionX normalized on XoZ plane
				DZu = DZu/math.sqrt((DXu^2 + DZu^2)) -- UnitDirectionZ normalized on XoZ plane 
				DXt = (Xt - Xu)/ math.sqrt((Xt - Xu)^2 + (Zt - Zu)^2) -- Unit-Target DirectionX normalized on XoZ plane
				DZt = (Zt - Zu)/ math.sqrt((Xt - Xu)^2 + (Zt - Zu)^2) -- Unit-Target DirectionZ normalized on XoZ plane
				isFront = CheckWeaponTarget(DXt, DXu, DXu, DZu) -- Call for CheckWeaponTarget() to check if unit is facing its target
			end
			
			
		local unitDefID = Spring.GetUnitDefID(unitID)
			if a ~= 0 and isFront == true and not (UnitDefs[unitDefID].isBuilder == true) then -- When Targetting + facing unit + not a builder
				if (UnitDefs[unitDefID].rSpeed/UnitDefs[unitDefID].speed) >= 50 then -- If penetrator/arti/banisher/tremor
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 400)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
				else -- If not penetrator/arti/banisher/tremor
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 250)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
				end
			else -- If not Targetting + facing unit + not a builder
				if (UnitDefs[unitDefID].rSpeed/UnitDefs[unitDefID].speed) >= 50 then -- If penetrator/arti/banisher/tremor
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 400)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
				else -- If not penetrator/arti/banisher/tremor
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 250)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
				end
			end
		end
	end
end
