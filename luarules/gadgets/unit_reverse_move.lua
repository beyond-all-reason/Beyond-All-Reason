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
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 0)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 0)
				else -- If not penetrator/arti/banisher/tremor
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 0)
					Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 0)
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
	
	function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	-- allowreverse = "Reverse is not allowed"
	if cmdID == 1 then
	x,y,z = cmdParams[4],cmdParams[5],cmdParams[6]
	xu, yu, zu = Spring.GetUnitPosition(unitID)
	if x ~= nil then
	if y ~= nil then
	if z ~= nil then
	distance = math.sqrt((x-xu)^2 + (z-zu)^2)
	else
	distance = 1000
	end

	-- Spring.Echo(distance)
		if (reverseUnit[unitID]) then
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
					if distance < 700 then
						-- allowreverse = "Reverse is allowed"
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 700)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
					else
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 0)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 0)	
					end
				else -- If not penetrator/arti/banisher/tremor
					if distance < 350 then
						-- allowreverse = "Reverse is allowed"
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 350)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
					else
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 0)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 0)						
					end
				end
			else -- If not Targetting + facing unit + not a builder
				if (UnitDefs[unitDefID].rSpeed/UnitDefs[unitDefID].speed) >= 50 then -- If penetrator/arti/banisher/tremor
					if distance < 350 then	
						-- allowreverse = "Reverse is allowed"
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 350)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
					else
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 0)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 0)
					end
				else -- If not penetrator/arti/banisher/tremor
					if distance < 175 then	
						-- allowreverse = "Reverse is allowed"
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 175)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 120)
					else
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 0)
						Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 0)
					end

					end
				end

		end

	else
		if (reverseUnit[unitID]) then
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 0)
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 0)
		end
	end

end
end
end
end