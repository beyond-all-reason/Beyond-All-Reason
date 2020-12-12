----------------------------------------------------------------------------------------------------------------------------------------
--   If you don't want to have special abilities for your boss, uncomment out the code below so script has something to choose from   --
----------------------------------------------------------------------------------------------------------------------------------------

-- function BossSpecAbiDoNothing(n)

-- end
-- table.insert(BossSpecialAbilitiesEarlyList,BossSpecAbiDoNothing)
-- table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDoNothing)
-- table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiDoNothing)
-- table.insert(BossSpecialAbilitiesEarlyList,BossSpecAbiDoNothing)
-- table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDoNothing)
-- table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiDoNothing)

-------------------------------------------------------------------------------------------------

-- Passive Abilities -- leave the controller function empty if you don't have any passive abilities.
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



-- Abilities

function BossSpecAbiDGun(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 1000, false)
		if nearestEnemy then
			Spring.Echo("[Scavengers] Boss Dgun Activated")
			local NearestBossEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 20000, false)
			local x,y,z = Spring.GetUnitPosition(NearestBossEnemy)
			Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z}, {0})
			Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN, NearestBossEnemy, {0})
		end
	end
end
table.insert(BossSpecialAbilitiesEarlyList,BossSpecAbiDGun)
table.insert(BossSpecialAbilitiesEarlyList,BossSpecAbiDGun)
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDGun)
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDGun)
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDGun)
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDGun)
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDGun)
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDGun)
table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiDGun)

function BossSpecAbiDGunFrenzy(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 500, false)
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
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiDGunFrenzy)
table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiDGunFrenzy)

function BossSpecAbiSuperDGun(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 500, false)
		if nearestEnemy then
			Spring.Echo("[Scavengers] Boss Super Dgun Activated")
			local bossx,bossy,bossz = Spring.GetUnitPosition(FinalBossUnitID)
			local NearestUnits = Spring.GetUnitsInSphere(bossx, bossy, bossz, 500)
			SuperDgunTargets = 0
			for e = 1,#NearestUnits do
				local uID = NearestUnits[e]
				local team = Spring.GetUnitTeam(uID)
				if team ~= GaiaTeamID then
					local x,y,z = Spring.GetUnitPosition(uID)
					if SuperDgunTargets == 0 then
						Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN, uID, {0})
						SuperDgunTargets = 1
					else
						Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN, uID, {"shift"})
					end
				end
			end
		end
	end
end
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiSuperDGun)
table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiSuperDGun)

function BossSpecAbiSelfRepair(n)
	if FinalBossUnitID then
		Spring.Echo("[Scavengers] Boss Self Repair Activated")
		CurrentlyUsedPassiveAbility = "selfrepair"
		AbilityTimer = BossFightCurrentPhase*3
	end
end
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiSelfRepair)
table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiSelfRepair)

function BossSpecAbiFighterWave(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 1000, false)
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
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiFighterWave)
table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiFighterWave)

function BossSpecAbiNearbyTacNuke(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 1000, false)
		if nearestEnemy then
			Spring.Echo("[Scavengers] Boss Is TacNuking")
			local posx, posy, posz = Spring.GetUnitPosition(FinalBossUnitID)
			for i = 1,BossFightCurrentPhase do
				QueueSpawn("scavtacnukespawner_scav", posx+math_random(-750,750), posy, posz+math_random(-750,750), math_random(0,3),GaiaTeamID, n+i*30+math.random(0,60))
			end
		end
	end
end
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiNearbyTacNuke)
table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiNearbyTacNuke)

function BossSpecAbiNearbyEMP(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 1000, false)
		if nearestEnemy then
			Spring.Echo("[Scavengers] Boss Is EMP'ing")
			local posx, posy, posz = Spring.GetUnitPosition(FinalBossUnitID)
			for i = 1,BossFightCurrentPhase do
				QueueSpawn("scavempspawner_scav", posx+math_random(-750,750), posy, posz+math_random(-750,750), math_random(0,3),GaiaTeamID, n+i*30+math.random(0,60))
			end
		end
	end
end
table.insert(BossSpecialAbilitiesMidgameList,BossSpecAbiNearbyEMP)
table.insert(BossSpecialAbilitiesEndgameList,BossSpecAbiNearbyEMP)