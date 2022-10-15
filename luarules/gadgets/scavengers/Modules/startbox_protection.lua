
local function spawnStartBoxProtection(n)
    if ScavengerStartboxExists then
			local chance = 0--math_random(0,1)
			if chance == 0 then
			--mapsizeX
			--mapsizeZ
			--ScavengerStartboxXMin
			--ScavengerStartboxZMin
			--ScavengerStartboxXMax
			--ScavengerStartboxZMax
			--ScavengerTeamID
			--ScavengerAllyTeamID
			--positionCheckLibrary.FlatAreaCheck(posx, posy, posz, posradius)
			--positionCheckLibrary.OccupancyCheck(posx, posy, posz, posradius)
			--ScavSafeAreaMinX
			--ScavSafeAreaMaxX
			--ScavSafeAreaMinZ
			--ScavSafeAreaMaxZ
			local r = math_random(0,3)
			local spread = scavconfig.spawnProtectionConfig.spread
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
						pickedTurret = staticUnitList.BeaconDefencesLand.T0[math_random(1,#staticUnitList.BeaconDefencesLand.T0)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						pickedTurret = staticUnitList.BeaconDefencesLand.T1[math_random(1,#staticUnitList.BeaconDefencesLand.T1)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						pickedTurret = staticUnitList.BeaconDefencesLand.T2[math_random(1,#staticUnitList.BeaconDefencesLand.T2)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						pickedTurret = staticUnitList.BeaconDefencesLand.T3[math_random(1,#staticUnitList.BeaconDefencesLand.T3)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						pickedTurret = staticUnitList.BeaconDefencesLand.T4[math_random(1,#staticUnitList.BeaconDefencesLand.T4)]
					else
						pickedTurret = staticUnitList.BeaconDefencesLand.T0[math_random(1,#staticUnitList.BeaconDefencesLand.T0)]
					end
				elseif spawnPosY <= 0 then
					if spawnTier <= TierSpawnChances.T0 then
						pickedTurret = staticUnitList.BeaconDefencesSea.T0[math_random(1,#staticUnitList.BeaconDefencesSea.T0)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						pickedTurret = staticUnitList.BeaconDefencesSea.T1[math_random(1,#staticUnitList.BeaconDefencesSea.T1)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						pickedTurret = staticUnitList.BeaconDefencesSea.T2[math_random(1,#staticUnitList.BeaconDefencesSea.T2)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						pickedTurret = staticUnitList.BeaconDefencesSea.T3[math_random(1,#staticUnitList.BeaconDefencesSea.T3)]
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						pickedTurret = staticUnitList.BeaconDefencesSea.T4[math_random(1,#staticUnitList.BeaconDefencesSea.T4)]
					else
						pickedTurret = staticUnitList.BeaconDefencesSea.T0[math_random(1,#staticUnitList.BeaconDefencesSea.T0)]
					end
				end

				canSpawnDefence = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
				if canSpawnDefence then
					canSpawnDefence = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
				end

				if canSpawnDefence then
					spawnQueueLibrary.AddToSpawnQueue(pickedTurret, spawnPosX, spawnPosY, spawnPosZ, spawnDirection,ScavengerTeamID,n+150)
					-- Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, spawnPosX, spawnPosY, spawnPosZ, spawnDirection,ScavengerTeamID)
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

-- local function executeStartBoxProtection(n) -- Deal damage
-- 	--ScavSafeAreaMinX
-- 	--ScavSafeAreaMaxX
-- 	--ScavSafeAreaMinZ
-- 	--ScavSafeAreaMaxZ
-- 	if ScavengerStartboxExists then
-- 		local list = Spring.GetUnitsInRectangle(ScavSafeAreaMinX,ScavSafeAreaMinZ,ScavSafeAreaMaxX,ScavSafeAreaMaxZ)
-- 		for i = 1,#list do
-- 			local unitID = list[i]
-- 			local unitTeam = Spring.GetUnitTeam(unitID)
-- 			if unitTeam == Spring.GetGaiaTeamID() then
-- 				Spring.DestroyUnit(unitID, true, true)
-- 			elseif unitTeam ~= ScavengerTeamID then
-- 				local currentHealth,maxHealth = Spring.GetUnitHealth(unitID)
-- 				local damage = maxHealth*(ScavSafeAreaDamage*0.01)
-- 				if damage < currentHealth then
-- 					Spring.SetUnitHealth(unitID,currentHealth-damage)
-- 					local posx, posy, posz = Spring.GetUnitPosition(unitID)
-- 					Spring.SpawnCEG("scavradiation-lightning",posx,posy+40,posz,0,0,0)
-- 				else
-- 					Spring.DestroyUnit(unitID, false, false)
-- 				end
-- 			end
-- 		end
-- 	end
-- end

local function executeStartBoxProtection(n) -- Capture
	--ScavSafeAreaMinX
	--ScavSafeAreaMaxX
	--ScavSafeAreaMinZ
	--ScavSafeAreaMaxZ
	if ScavengerStartboxExists then
		local list = Spring.GetUnitsInRectangle(ScavSafeAreaMinX,ScavSafeAreaMinZ,ScavSafeAreaMaxX,ScavSafeAreaMaxZ)
		for i = 1,#list do
			local unitID = list[i]
			local unitTeam = Spring.GetUnitTeam(unitID)
			if unitTeam == Spring.GetGaiaTeamID() then
				local posx, posy, posz = Spring.GetUnitPosition(unitID)
				Spring.DestroyUnit(unitID, true, true)
				Spring.SpawnCEG("scavradiation-lightning",posx-64,posy+40,posz,0,0,0)
				Spring.SpawnCEG("scavradiation-lightning",posx+64,posy+40,posz,0,0,0)
				Spring.SpawnCEG("scavradiation-lightning",posx,posy+40,posz-64,0,0,0)
				Spring.SpawnCEG("scavradiation-lightning",posx,posy+40,posz+64,0,0,0)
			elseif unitTeam ~= ScavengerTeamID then
				local currentHealth,maxHealth = Spring.GetUnitHealth(unitID)
				local damage = maxHealth*(ScavSafeAreaDamage*0.01)
				local captureLevel = select(4, Spring.GetUnitHealth(unitID))
				Spring.SetUnitHealth(unitID,{capture = captureLevel+0.01})
				local posx, posy, posz = Spring.GetUnitPosition(unitID)
				Spring.SpawnCEG("scavradiation-lightning",posx,posy+40,posz,0,0,0)
				local captureLevel = select(4, Spring.GetUnitHealth(unitID))
				if captureLevel >= 1 then
					Spring.TransferUnit(unitID, ScavengerTeamID, false)
					Spring.SpawnCEG("scavradiation-lightning",posx-64,posy+40,posz,0,0,0)
					Spring.SpawnCEG("scavradiation-lightning",posx+64,posy+40,posz,0,0,0)
					Spring.SpawnCEG("scavradiation-lightning",posx,posy+40,posz-64,0,0,0)
					Spring.SpawnCEG("scavradiation-lightning",posx,posy+40,posz+64,0,0,0)
				end
			end
		end
	end
end

local function spawnStartBoxEffect(n)
	if ScavengerStartboxExists then
		local x = math.random(ScavSafeAreaMinX,ScavSafeAreaMaxX)
		local z = math.random(ScavSafeAreaMinZ,ScavSafeAreaMaxZ)
		local y = Spring.GetGroundHeight(x,z)
		Spring.SpawnCEG("scavradiation",x,y+100,z,0,0,0)
	end
end

local function spawnStartBoxEffect2(n)
	if ScavengerStartboxExists then
		local x = math.random(ScavSafeAreaMinX,ScavSafeAreaMaxX)
		local z = math.random(ScavSafeAreaMinZ,ScavSafeAreaMaxZ)
		local y = Spring.GetGroundHeight(x,z)
		Spring.SpawnCEG("scavradiation-lightning",x,y+100,z,0,0,0)
	end
end

return {
	spawnStartBoxProtection = spawnStartBoxProtection,
	executeStartBoxProtection = executeStartBoxProtection,
	spawnStartBoxEffect = spawnStartBoxEffect,
	spawnStartBoxEffect2 = spawnStartBoxEffect2,
}