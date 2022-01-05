local airUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/air.lua")

local function passiveAbilityController(currentFrame)
	if not AbilityTimer then AbilityTimer = 0 end
	if AbilityTimer < 1 then CurrentlyUsedPassiveAbility = "none" end
	AbilityTimer = AbilityTimer - 1
	
	if CurrentlyUsedPassiveAbility == "none" then
		return
	elseif CurrentlyUsedPassiveAbility == "selfrepair" then -- TODO: Add sound and visual effects here
		local currentbosshealth = Spring.GetUnitHealth(FinalBossUnitID)
		--local initialbosshealth = unitSpawnerModuleConfig.FinalBossHealth*teamcount*spawnmultiplier
		local healing = initialbosshealth*0.0000250*BossFightCurrentPhase
		if currentbosshealth < initialbosshealth then
			Spring.SetUnitHealth(FinalBossUnitID, currentbosshealth+healing)
		end
	end
end

local abilities = {}

abilities.dGun = function(currentFrame)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 1500, false)
		if nearestEnemy then
			--Spring.Echo("[Scavengers] Boss Dgun Activated")
			local NearestBossEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 20000, false)
			local x,y,z = Spring.GetUnitPosition(NearestBossEnemy)
			Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN,{x,y,z}, {0})
			Spring.GiveOrderToUnit(FinalBossUnitID, CMD.DGUN, NearestBossEnemy, {0})
		end
	end
end

abilities.dGunFrenzy = function(currentFrame)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 750, false)
		if nearestEnemy then
			--Spring.Echo("[Scavengers] Boss Frenzy Dgun Activated")
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

abilities.superDGun = function(currentFrame)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 750, false)
		if nearestEnemy then
			--Spring.Echo("[Scavengers] Boss Super Dgun Activated")
			local bossx,bossy,bossz = Spring.GetUnitPosition(FinalBossUnitID)
			local NearestUnits = Spring.GetUnitsInSphere(bossx, bossy, bossz, 750)
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

abilities.selfRepair = function(currentFrame)
	if FinalBossUnitID then
		--Spring.Echo("[Scavengers] Boss Self Repair Activated")
		CurrentlyUsedPassiveAbility = "selfrepair"
		AbilityTimer = BossFightCurrentPhase*3
	end
end

abilities.airWave = function(n)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 250, false)
		if nearestEnemy then
			--Spring.Echo("[Scavengers] Boss Fighter Reinforcements Activated")
			local fighters = {}
			table.mergeInPlace(fighters, airUnitList.T0)
			table.mergeInPlace(fighters, airUnitList.T1)
			table.mergeInPlace(fighters, airUnitList.T2)
			table.mergeInPlace(fighters, airUnitList.T3)
			local fighter = fighters[math_random(1,#fighters)]
			local bossx, bossy, bossz = Spring.GetUnitPosition(FinalBossUnitID)
			for i = 1,5*BossFightCurrentPhase*spawnmultiplier do
				QueueSpawn(fighter, bossx+(math.random(-300, 300)), bossy+2000, bossz+(math.random(-300, 300)), math_random(0,3),GaiaTeamID, n+i+1)
			end
		end
	end
end

abilities.tacticalNuke = function(currentFrame)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 2000, false)
		if nearestEnemy then
			--Spring.Echo("[Scavengers] Boss Is TacNuking")
			local bossx,bossy,bossz = Spring.GetUnitPosition(FinalBossUnitID)
			local NearestUnits = Spring.GetUnitsInSphere(bossx, bossy, bossz, 500)
			if #NearestUnits > 5 then
				for i = 1,BossFightCurrentPhase do
					for t = 1,10 do
						local target = NearestUnits[math_random(1,#NearestUnits)]
						local targetTeam = Spring.GetUnitTeam(target)
						if targetTeam ~= GaiaTeamID then
							local x,y,z = Spring.GetUnitPosition(target)
							QueueSpawn("scavtacnukespawner_scav", x+math_random(-50,50), y, z+math_random(-50,50), math_random(0,3),GaiaTeamID, currentFrame+i+math.random(0,60))
							break
						end
					end
				end
			end
		end
	end
end

abilities.EMP = function(currentFrame)
	if FinalBossUnitID then
		local nearestEnemy = Spring.GetUnitNearestEnemy(FinalBossUnitID, 2000, false)
		if nearestEnemy then
			--Spring.Echo("[Scavengers] Boss Is TacNuking")
			local bossx,bossy,bossz = Spring.GetUnitPosition(FinalBossUnitID)
			local NearestUnits = Spring.GetUnitsInSphere(bossx, bossy, bossz, 500)
			if #NearestUnits > 5 then
				for i = 1,BossFightCurrentPhase do
					for t = 1,10 do
						local target = NearestUnits[math_random(1,#NearestUnits)]
						local targetTeam = Spring.GetUnitTeam(target)
						if targetTeam ~= GaiaTeamID then
							local x,y,z = Spring.GetUnitPosition(target)
							QueueSpawn("scavempspawner_scav", x+math_random(-50,50), y, z+math_random(-50,50), math_random(0,3),GaiaTeamID, currentFrame+i+math.random(0,60))
							break
						end
					end
				end
			end
		end
	end
end

local earlyAbilities = {
	abilities.dGun,
	abilities.dGun,
	abilities.dGun,
	abilities.dGun,
	abilities.dGun,
	abilities.dGun,
	abilities.dGun,
	abilities.dGun,
	abilities.dGun,
	abilities.dGun,
	abilities.superDGun,
	abilities.selfRepair,
	abilities.airWave,
}

local midgameAbilities = {
	abilities.dGun,
	abilities.dGunFrenzy,
	abilities.superDGun,
	abilities.selfRepair,
	abilities.airWave
	abilities.tacticalNuke,
	abilities.EMP,
}

local endGameAbilities = {
	abilities.dGun,
	abilities.dGunFrenzy,
	abilities.superDGun,
	abilities.selfRepair,
	abilities.airWave,
	abilities.tacticalNuke,
	abilities.EMP,
}

return {
	Passive = passiveAbilityController,
	Early   = earlyAbilities,
	Midgame = midgameAbilities,
	Endgame = endGameAbilities,
}