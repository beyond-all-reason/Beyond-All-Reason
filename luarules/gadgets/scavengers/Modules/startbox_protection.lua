
function spawnStartBoxProtection(n)
    if ScavSafeAreaExist then
			local chance = math_random(0,10)
			if chance == 0 then
			--mapsizeX
			--mapsizeZ
			--ScavengerStartboxXMin
			--ScavengerStartboxZMin
			--ScavengerStartboxXMax
			--ScavengerStartboxZMax
			--GaiaTeamID
			--GaiaAllyTeamID
			--posCheck(posx, posy, posz, posradius)
			--posOccupied(posx, posy, posz, posradius)
			--ScavSafeAreaMinX
			--ScavSafeAreaMaxX
			--ScavSafeAreaMinZ
			--ScavSafeAreaMaxZ
			local r = math_random(0,3)
			local r2 = math_random(0,80)
			local spread = spawnProtectionConfig.spread
			local spawnPosX = math_random(ScavSafeAreaMinX,ScavSafeAreaMaxX)
			local spawnPosZ = math_random(ScavSafeAreaMinZ,ScavSafeAreaMaxZ)
			if r == 0 then -- south edge
				spawnPosZ = ScavSafeAreaMaxZ
				spawnDirection = 0
			elseif r == 1 then  -- east edge
				spawnPosX = ScavSafeAreaMaxX
				spawnDirection = 1
			elseif r == 2 then  -- south edge
				spawnPosZ = ScavSafeAreaMinZ
				spawnDirection = 2
			elseif r == 3 then  -- west edge
				spawnPosX = ScavSafeAreaMinX
				spawnDirection = 3
			end
			if r2 == 0 then
				spawnPosX = math_random(ScavSafeAreaMinX,ScavSafeAreaMaxX)
				spawnPosZ = math_random(ScavSafeAreaMinZ,ScavSafeAreaMaxZ)
			end
			canSpawnDefence = true
			if spawnPosX > mapsizeX - 128 or spawnPosX < 128 or spawnPosZ > mapsizeZ - 128 or spawnPosZ < 128 then
				canSpawnDefence = false
			end
			spawnPosX = spawnPosX + math_random(-spread*2,spread*2)
			spawnPosZ = spawnPosZ + math_random(-spread*2,spread*2)
			if spawnPosX > mapsizeX - 128 or spawnPosX < 128 or spawnPosZ > mapsizeZ - 128 or spawnPosZ < 128 then
				canSpawnDefence = false
			end
			if canSpawnDefence then
				local spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
				local spawnTier = math_random(1,100)

				if spawnPosY > 0 then
					if spawnTier <= TierSpawnChances.T0 then
						pickedTurret = StartboxDefenceStructuresT0[math_random(1,#StartboxDefenceStructuresT0)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						pickedTurret = StartboxDefenceStructuresT1[math_random(1,#StartboxDefenceStructuresT1)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						pickedTurret = StartboxDefenceStructuresT2[math_random(1,#StartboxDefenceStructuresT2)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						pickedTurret = StartboxDefenceStructuresT3[math_random(1,#StartboxDefenceStructuresT3)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						pickedTurret = StartboxDefenceStructuresT4[math_random(1,#StartboxDefenceStructuresT4)]
					else
						pickedTurret = StartboxDefenceStructuresT0[math_random(1,#StartboxDefenceStructuresT0)]
					end
				elseif spawnPosY <= 0 then
					if spawnTier <= TierSpawnChances.T0 then
						pickedTurret = StartboxDefenceStructuresT0Sea[math_random(1,#StartboxDefenceStructuresT0Sea)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						pickedTurret = StartboxDefenceStructuresT1Sea[math_random(1,#StartboxDefenceStructuresT1Sea)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						pickedTurret = StartboxDefenceStructuresT2Sea[math_random(1,#StartboxDefenceStructuresT2Sea)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						pickedTurret = StartboxDefenceStructuresT3Sea[math_random(1,#StartboxDefenceStructuresT3Sea)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						pickedTurret = StartboxDefenceStructuresT4Sea[math_random(1,#StartboxDefenceStructuresT4Sea)]
					else
						pickedTurret = StartboxDefenceStructuresT0Sea[math_random(1,#StartboxDefenceStructuresT0Sea)]
					end
				end

				canSpawnDefence = posCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
				if canSpawnDefence then
					canSpawnDefence = posOccupied(spawnPosX, spawnPosY, spawnPosZ, spread)
				end

				if canSpawnDefence then
					QueueSpawn(pickedTurret..scavconfig.unitnamesuffix, spawnPosX, spawnPosY, spawnPosZ, spawnDirection,GaiaTeamID,n+90)
					Spring.CreateUnit("scavengerdroppod_scav", spawnPosX, spawnPosY, spawnPosZ, spawnDirection,GaiaTeamID)
				end
			end
			spawnPosX = nil
			spawnPosZ = nil
			spawnDirection = nil
			canSpawnDefence = nil
			pickedTurret = nil
		end
	end
end

function executeStartBoxProtection(n)
	--ScavSafeAreaMinX
	--ScavSafeAreaMaxX
	--ScavSafeAreaMinZ
	--ScavSafeAreaMaxZ
	if ScavSafeAreaExist then
		local list = Spring.GetUnitsInRectangle(ScavSafeAreaMinX,ScavSafeAreaMinZ,ScavSafeAreaMaxX,ScavSafeAreaMaxZ)
		for i = 1,#list do
			local unitID = list[i]
			local unitTeam = Spring.GetUnitTeam(unitID)
			if unitTeam ~= GaiaTeamID then
				local currentHealth,maxHealth = Spring.GetUnitHealth(unitID)
				local damage = maxHealth*(ScavSafeAreaGenerator*0.01)
				if damage < currentHealth then
					Spring.SetUnitHealth(unitID,currentHealth-damage)
					local posx, posy, posz = Spring.GetUnitPosition(unitID)
					Spring.SpawnCEG("scavradiation-lightning",posx,posy+40,posz,0,0,0)
				else
					Spring.DestroyUnit(unitID, false, false)
				end
			end
		end
	end
end

function spawnStartBoxEffect(n)
	if ScavSafeAreaExist then
		local x = math.random(ScavSafeAreaMinX,ScavSafeAreaMaxX)
		local z = math.random(ScavSafeAreaMinZ,ScavSafeAreaMaxZ)
		local y = Spring.GetGroundHeight(x,z)
		Spring.SpawnCEG("scavradiation",x,y+100,z,0,0,0)
	end
end

function spawnStartBoxEffect2(n)
	if ScavSafeAreaExist then
		local x = math.random(ScavSafeAreaMinX,ScavSafeAreaMaxX)
		local z = math.random(ScavSafeAreaMinZ,ScavSafeAreaMaxZ)
		local y = Spring.GetGroundHeight(x,z)
		Spring.SpawnCEG("scavradiation-lightning",x,y+100,z,0,0,0)
	end
end
