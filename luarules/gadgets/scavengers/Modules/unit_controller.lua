Spring.Echo("[Scavengers] Unit Controller initialized")

local function selfDestructionControls(n, scav, scavDef, friendly)
	UnitRange = {}
	Constructing = {}
	--Constructing[scav] = false
	local _,_,_,_,buildProgress = Spring.GetUnitHealth(scav)
	if buildProgress == 1 then
		if selfdx[scav] then
			oldselfdx[scav] = selfdx[scav]
		end
		if selfdy[scav] then
			oldselfdy[scav] = selfdy[scav]
		end
		if selfdz[scav] then
			oldselfdz[scav] = selfdz[scav]
		end
		selfdx[scav],selfdy[scav],selfdz[scav] = Spring.GetUnitPosition(scav)
		if UnitDefs[scavDef].maxWeaponRange < 800 then
			UnitRange[scav] = 800
		else
			UnitRange[scav] = UnitDefs[scavDef].maxWeaponRange
		end
		if scavConstructor[scav] then
			local metalMake, metalUse = Spring.GetUnitResources(scav)
			if metalUse > 0 then
				Constructing[scav] = true
			else
				Constructing[scav] = false
			end
		end
		if (oldselfdx[scav] and oldselfdy[scav] and oldselfdz[scav]) and (oldselfdx[scav] > selfdx[scav]-20 and oldselfdx[scav] < selfdx[scav]+20) and (oldselfdy[scav] > selfdy[scav]-20 and oldselfdy[scav] < selfdy[scav]+20) and (oldselfdz[scav] > selfdz[scav]-20 and oldselfdz[scav] < selfdz[scav]+20) then
			if selfdx[scav] < mapsizeX and selfdx[scav] > 0 and selfdz[scav] < mapsizeZ and selfdz[scav] > 0 then
				if not scavConstructor[scav] or Constructing[scav] == false then
					local scavhealth, scavmaxhealth, scavparalyze = Spring.GetUnitHealth(scav)
					for q = 1,5 do
						local posx = math.random(selfdx[scav] - 400, selfdx[scav] + 400)
						local posz = math.random(selfdz[scav] - 400, selfdz[scav] + 400)
						local telstartposy = Spring.GetGroundHeight(selfdx[scav], selfdz[scav])
						local telendposy = Spring.GetGroundHeight(posx, posz)
						local poscheck = positionCheckLibrary.VisibilityCheckEnemy(posx, telendposy, posz, 100, ScavengerAllyTeamID, true, false, false)
						if (-(UnitDefs[scavDef].minWaterDepth) > telendposy) and (-(UnitDefs[scavDef].maxWaterDepth) < telendposy) and scavparalyze == 0 and (poscheck == true or friendly == true) then
							Spring.SpawnCEG("scav-spawnexplo",selfdx[scav],telstartposy,selfdz[scav],0,0,0)
							Spring.SpawnCEG("scav-spawnexplo",posx,telendposy,posz,0,0,0)
							Spring.SetUnitPosition(scav, posx, posz)
							Spring.GiveOrderToUnit(scav, CMD.STOP, 0, 0)
							break
						end
					end
				end
			end
			--Spring.DestroyUnit(scav, false, true)
		end
	end
	UnitRange[scav] = nil
	Constructing[scav] = nil
end

local function armyMoveOrdersInitialPhase(n, scav, scavDef)
	UnitRange = {}
	if UnitDefs[scavDef].maxWeaponRange and UnitDefs[scavDef].maxWeaponRange > 100 then
		UnitRange[scav] = UnitDefs[scavDef].maxWeaponRange
	else
		UnitRange[scav] = 100
	end
	local range = UnitRange[scav]
	
	local posx, posy, posz = Spring.GetUnitPosition(scav)
	local x = math.random(0, mapsizeX)
	local z = math.random(0, mapsizeZ)
	local y = Spring.GetGroundHeight(x,z)
	if (-(UnitDefs[scavDef].minWaterDepth) > y) and (-(UnitDefs[scavDef].maxWaterDepth) < y) or UnitDefs[scavDef].canFly then
		if positionCheckLibrary.VisibilityCheckEnemy(x, y, z, range, ScavengerAllyTeamID, true, true, true) then
			Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift", "alt", "ctrl"})
		end
	end
end

local function armyMoveOrders(n, scav, scavDef)
	UnitRange = {}
	if UnitDefs[scavDef].maxWeaponRange and UnitDefs[scavDef].maxWeaponRange > 100 then
		UnitRange[scav] = UnitDefs[scavDef].maxWeaponRange
	else
		UnitRange[scav] = 100
	end
	attackTarget = Spring.GetUnitNearestEnemy(scav, 200000, true)
	
	if not BossWaveStarted or BossWaveStarted == false then
		attackTarget = Spring.GetUnitNearestEnemy(scav, 200000, true)
	elseif FinalBossUnitID then
		if scav == FinalBossUnitID then
			if AliveEnemyCommanders and AliveEnemyCommandersCount > 0 then
				if AliveEnemyCommandersCount > 1 then
					for i = 1,AliveEnemyCommandersCount do
						-- let's get nearest commander
						local separation = Spring.GetUnitSeparation(scav,AliveEnemyCommanders[i])
						if not lowestSeparation then
							lowestSeparation = separation
							attackTarget = AliveEnemyCommanders[i]
						end
						if separation < lowestSeparation then
							lowestSeparation = separation
							attackTarget = AliveEnemyCommanders[i]
						end
					end
					lowestSeparation = nil
				elseif AliveEnemyCommandersCount == 1 then
					attackTarget = AliveEnemyCommanders[1]
				end
			end
		else
			attackTarget = FinalBossUnitID
		end
	else
		attackTarget = Spring.GetUnitNearestEnemy(scav, 200000, true)
	end
	-- if attackTarget == nil then
	-- 	attackTarget = Spring.GetUnitNearestEnemy(scav, 200000, false)
	-- end
	if attackTarget then
		local x,y,z = Spring.GetUnitPosition(attackTarget)
		local y = Spring.GetGroundHeight(x, z)
		if (-(UnitDefs[scavDef].minWaterDepth) > y) and (-(UnitDefs[scavDef].maxWaterDepth) < y) or UnitDefs[scavDef].canFly then
			local range = UnitRange[scav]
			if range < 100 then 
				range = 100 
			end
			local x = x + math_random(-range*0.75,range*0.75)
			local z = z + math_random(-range*0.75,range*0.75)
			local transporting = Spring.GetUnitIsTransporting(scav)
			if transporting and #transporting > 0 then
				Spring.GiveOrderToUnit(scav, CMD.UNLOAD_UNIT,{x,y,z}, {"shift", "alt", "ctrl"})
			elseif FinalBossUnitID and (scav ~= FinalBossUnitID) then
				if math.random(0,4) == 0 then
					Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
				else
					Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift", "alt", "ctrl"})
				end
			elseif FinalBossUnitID and (scav == FinalBossUnitID) then
				if math.random(0,4) == 0 then
					Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
				else
					Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift", "alt", "ctrl"})
				end
			elseif not FinalBossUnitID then
				if UnitDefs[scavDef].canFly then
					Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
				elseif UnitRange[scav] > scavconfig.unitControllerModuleConfig.minimumrangeforfight then
					if math.random(0,4) == 0 then
						Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift", "alt", "ctrl"})
					else
						Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
					end
				else
					if math.random(0,4) == 0 then
						Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
					else
						Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift", "alt", "ctrl"})
					end
				end
			else
				if math.random(0,1) == 0 then
					Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift", "alt", "ctrl"})
				else
					Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
				end
			end
		else
			local x = math.random(0, mapsizeX)
			local z = math.random(0, mapsizeZ)
			local y = Spring.GetGroundHeight(x,z)
			if (-(UnitDefs[scavDef].minWaterDepth) > y) and (-(UnitDefs[scavDef].maxWaterDepth) < y) or UnitDefs[scavDef].canFly then
				Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
			end
		end
	else
		local x = math.random(0, mapsizeX)
		local z = math.random(0, mapsizeZ)
		local y = Spring.GetGroundHeight(x,z)
		if (-(UnitDefs[scavDef].minWaterDepth) > y) and (-(UnitDefs[scavDef].maxWaterDepth) < y) or UnitDefs[scavDef].canFly then
			Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
		end
	end
	attackTarget = nil
end

return {
	SelfDestructionControls = selfDestructionControls,
	ArmyMoveOrdersInitialPhase = armyMoveOrdersInitialPhase,
	ArmyMoveOrders = armyMoveOrders,
}
