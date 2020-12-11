
-- phase control
function ScavBossPhaseControl(bosshealthpercentage)
	if bosshealthpercentage >= 90 then
		BossFightCurrentPhase = 1
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesEarlyList
	elseif bosshealthpercentage >= 80 then
		BossFightCurrentPhase = 2
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 70 then
		BossFightCurrentPhase = 3
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 60 then
		BossFightCurrentPhase = 4
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 50 then
		BossFightCurrentPhase = 5
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 40 then
		BossFightCurrentPhase = 6
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 30 then
		BossFightCurrentPhase = 7
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 20 then
		BossFightCurrentPhase = 8
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesEndgameList
	elseif bosshealthpercentage >= 10 then
		BossFightCurrentPhase = 9
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesEndgameList
	else
		BossFightCurrentPhase = 10
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesEmergencyList
	end
end

function BossPassiveAbilityController(n)
	if not AbilityTimer then AbilityTimer = 0 end
	if AbilityTimer < 1 then CurrentlyUsedPassiveAbility = "none" end
	AbilityTimer = AbilityTimer - 1
	
	if CurrentlyUsedPassiveAbility == "none" then
		return
	elseif CurrentlyUsedPassiveAbility == "selfrepair" then -- Gonna need sound and visual effects here
		local currentbosshealth = Spring.GetUnitHealth(FinalBossUnitID)
		local initialbosshealth = unitSpawnerModuleConfig.FinalBossHealth*teamcount*spawnmultiplier
		local healing = initialbosshealth*0.000025*BossFightCurrentPhase
		if currentbosshealth < initialbosshealth then
			Spring.SetUnitHealth(FinalBossUnitID, currentbosshealth+healing)
		end
	end
end






-- special abilities

function BossSpecAbiDGun(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 2000, false)
		if nearestEnemy then
			Spring.Echo("[Scavengers] Boss Dgun Activated")
			local NearestBossEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 20000, false)
			local x,y,z = Spring.GetUnitPosition(NearestBossEnemy)
			Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z}, {0})
			Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN, NearestBossEnemy, {0})
		end
	end
end

function BossSpecAbiDGunFrenzy(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 2000, false)
		if nearestEnemy then
			Spring.Echo("[Scavengers] Boss Frenzy Dgun Activated")
			local r = math_random(1,4)
			local x,y,z = Spring.GetUnitPosition(FinalBossUnitID)
			if r == 1 then -- clockwise
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z-100}, {})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+50,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z-50}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z+50}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+50,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-50,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z+50}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z-50}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-50,y,z-100}, {"shift"})
			elseif r == 2 then -- anticlockwise
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z+100}, {})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+50,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z+50}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z-50}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+50,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-50,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z-50}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z+50}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-50,y,z+100}, {"shift"})
			elseif r == 3 then -- clockwise but less
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z-100}, {})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z-100}, {"shift"})
			elseif r == 4 then -- anticlockwise but less
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z+100}, {})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z+100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x+100,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z-100}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z}, {"shift"})
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x-100,y,z+100}, {"shift"})
			end
		end
	end
end

function BossSpecAbiRetreat(n)
	if FinalBossUnitID then
		AbilityTimer = BossFightCurrentPhase*3
		for q = 1,100 do
			local bossx, bossy, bossz = Spring.GetUnitPosition(FinalBossUnitID)
			local posx = math.random(100, mapsizeX-100)
			local posz = math.random(100, mapsizeZ-100)
			local telstartposy = Spring.GetGroundHeight(bossx, bossz)
			local telendposy = Spring.GetGroundHeight(posx, posz)
			canTeleport = posLosCheckOnlyLOS(posx, telendposy, posz, 100)
			if canTeleport == true then
				canTeleport = posCheck(posx, telstartposy, posz, 1)
			end
			if canTeleport == true then
				Spring.Echo("[Scavengers] Boss Self Repair Activated")
				CurrentlyUsedPassiveAbility = "selfrepair"
				Spring.SpawnCEG("scav-spawnexplo",bossx,telstartposy,bossz,0,0,0)
				Spring.SpawnCEG("scav-spawnexplo",posx,telendposy,posz,0,0,0)
				Spring.SetUnitPosition(FinalBossUnitID, posx, posz)
				Spring.GiveOrderToUnit(FinalBossUnitID, CMD.STOP, 0, 0)
				break
			end
		end
	end
end

function BossSpecAbiFighterWave(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 2000, false)
		if nearestEnemy then
			Spring.Echo("[Scavengers] Boss Fighter Reinforcements Activated")
			local r = math_random(1,4)
			local fighters = {"armhawk_scav", "corvamp_scav",}
			local fighter = fighters[math_random(1,2)]
			local bossx, bossy, bossz = Spring.GetUnitPosition(FinalBossUnitID)
			for i = 1,2*BossFightCurrentPhase*spawnmultiplier do
				if r == 1 then
					local posx = 0
					local posz = math.random(0,mapsizeZ)
					local posy = Spring.GetGroundHeight(posx, posy)
					QueueSpawn(fighter, posx, posy, posz, math_random(0,3),GaiaTeamID, n+i+1)
				elseif r == 2 then
					local posx = mapsizeX
					local posz = math.random(0,mapsizeZ)
					local posy = Spring.GetGroundHeight(posx, posy)
					QueueSpawn(fighter, posx, posy, posz, math_random(0,3),GaiaTeamID, n+i+1)
				elseif r == 3 then
					local posx = math.random(0,mapsizeX)
					local posz = 0
					local posy = Spring.GetGroundHeight(posx, posy)
					QueueSpawn(fighter, posx, posy, posz, math_random(0,3),GaiaTeamID, n+i+1)
				elseif r == 4 then
					local posx = math.random(0,mapsizeX)
					local posz = mapsizeZ
					local posy = Spring.GetGroundHeight(posx, posy)
					QueueSpawn(fighter, posx, posy, posz, math_random(0,3),GaiaTeamID, n+i+1)
				end
			end
		end
	end
end

function BossSpecAbiNearbyNuke(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 1000, false)
		if nearestEnemy then
			Spring.Echo("[Scavengers] Boss Is TacNuking")
			local posx, posy, posz = Spring.GetUnitPosition(FinalBossUnitID)
			for i = 1,BossFightCurrentPhase do
				QueueSpawn("scavnukespawner_scav", posx+math_random(-750,750), posy, posz+math_random(-750,750), math_random(0,3),GaiaTeamID, n+i*30+math.random(0,60))
			end
		end
	end
end





BossSpecialAbilitiesEarlyList = {
	BossSpecAbiDGun,
}

BossSpecialAbilitiesMidgameList = {
	BossSpecAbiDGun,
	BossSpecAbiDGun,
	BossSpecAbiDGun,
	BossSpecAbiDGun,
	BossSpecAbiDGun,
	BossSpecAbiDGun,
	BossSpecAbiDGunFrenzy,
	BossSpecAbiFighterWave,
	BossSpecAbiNearbyNuke,
}

BossSpecialAbilitiesEndgameList = {
	BossSpecAbiDGun,
	BossSpecAbiDGunFrenzy,
	BossSpecAbiFighterWave,
	BossSpecAbiNearbyNuke,
}

BossSpecialAbilitiesEmergencyList = {
	BossSpecAbiNearbyNuke,
	BossSpecAbiRetreat,
}

