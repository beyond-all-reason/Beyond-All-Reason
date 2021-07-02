Spring.Echo("[Scavengers] Constructor Controller initialized")

VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/constructors.lua")
local blueprintsController = VFS.Include("luarules/gadgets/scavengers/Blueprints/BYAR/constructor_blueprint_controller.lua")
local constructortimer = constructorControllerModuleConfig.constructortimerstart

scavvoicenotif = 2

function AssistantOrders(n, scav)
	local x,y,z = Spring.GetUnitPosition(scav)
	Spring.GiveOrderToUnit(scav, CMD.PATROL,{x-100,y,z}, {"shift"})
	Spring.GiveOrderToUnit(scav, CMD.PATROL,{x+100,y,z}, {"shift"})
	Spring.GiveOrderToUnit(scav, CMD.PATROL,{x,y,z-100}, {"shift"})
	Spring.GiveOrderToUnit(scav, CMD.PATROL,{x,y,z+100}, {"shift"})
end

function ResurrectorOrders(n, scav)
	local mapcenterX = mapsizeX/2
	local mapcenterZ = mapsizeZ/2
	local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
	local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
	Spring.GiveOrderToUnit(scav, CMD.RESURRECT,{mapcenterX+math_random(-100,100),mapcenterY,mapcenterZ+math_random(-100,100),mapdiagonal}, 0)
end

function CapturerOrders(n, scav)
	local mapcenterX = mapsizeX/2
	local mapcenterZ = mapsizeZ/2
	local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
	local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
	Spring.GiveOrderToUnit(scav, CMD.CAPTURE,{mapcenterX+math_random(-100,100),mapcenterY,mapcenterZ+math_random(-100,100),mapdiagonal}, 0)
	
	local nearestenemy = Spring.GetUnitNearestEnemy(scav, 999999, false)
	Spring.GiveOrderToUnit(scav, CMD.CAPTURE,{nearestenemy}, {"shift"})
	local x,y,z = Spring.GetUnitPosition(nearestenemy)
	Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"meta", "shift", "alt"})
end

function CollectorOrders(n, scav)
	local mapcenterX = mapsizeX/2
	local mapcenterZ = mapsizeZ/2
	local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
	local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
	Spring.GiveOrderToUnit(scav, CMD.RECLAIM,{mapcenterX+math_random(-100,100),mapcenterY,mapcenterZ+math_random(-100,100),mapdiagonal}, 0)
end

function ReclaimerOrders(n, scav)
	local nearestenemy = Spring.GetUnitNearestEnemy(scav, 999999, false)
	Spring.GiveOrderToUnit(scav, CMD.RECLAIM,{nearestenemy}, 0)
	local x,y,z = Spring.GetUnitPosition(nearestenemy)
	Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"meta", "shift", "alt"})
end

function SpawnConstructor(n)
	if (constructortimer > constructorControllerModuleConfig.constructortimer or CountScavConstructors() < constructorControllerModuleConfig.minimumconstructors ) and numOfSpawnBeacons > 0 and constructortimer > (constructorControllerModuleConfig.constructortimer/10) then
		local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
		SpawnBeacons = {}
		for i = 1,#scavengerunits do
			local scav = scavengerunits[i]
			local scavDef = Spring.GetUnitDefID(scav)
			if scavSpawnBeacon[scav] then
				table.insert(SpawnBeacons,scav)
			end
		end
		for b = 1,10 do
			local pickedBeaconTest = SpawnBeacons[math_random(1,#SpawnBeacons)]
			local _,_,pickedBeaconParalyze,pickedBeaconCaptureProgress = Spring.GetUnitHealth(pickedBeaconTest)
			if pickedBeaconCaptureProgress == 0 and pickedBeaconParalyze == 0 then
				pickedBeacon = pickedBeaconTest
				break
			else
				pickedBeacon = 16000000 -- high number that UnitID should never pick
			end
		end
		if pickedBeacon == 16000000 then
			return
		end
		posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
		local nearestEnemy = Spring.GetUnitNearestEnemy(pickedBeacon, 99999, false)
		local nearestEnemyTeam = Spring.GetUnitTeam(nearestEnemy)
		if nearestEnemyTeam == bestTeam then
			canSpawnCommanderHere = true
		else
			local r = math_random(0,4)
			if r == 0 then
				canSpawnCommanderHere = true
			else
				canSpawnCommanderHere = false
			end
		end
		if canSpawnCommanderHere then
			--Spring.GiveOrderToUnit(pickedBeacon, CMD.SELFD,{}, {"shift"})
			if not anothercommander then
				ScavSendNotification("scav_scavcomdetected")
				anothercommander = true
			else
				local s = math_random(0,scavvoicenotif)
					if s == 0 then
						ScavSendNotification("scav_scavadditionalcomdetected")
					elseif s == 1 then
						ScavSendNotification("scav_scavanotherscavcomdetected")
					elseif s == 2 then
						ScavSendNotification("scav_scavnewcomentered")
					elseif s == 3 then
						ScavSendNotification("scav_scavcomspotted")
					elseif s == 4 then
						ScavSendNotification("scav_scavcomnewdetect")
					else
						ScavSendMessage("A Scavenger Commander detected")
					end
				if scavvoicenotif < 20 then
					scavvoicenotif = scavvoicenotif + 1
				end
			end
			SpawnBeacon(n)
			if constructorControllerModuleConfig.useresurrectors then
				Spring.CreateUnit("scavengerdroppod_scav", posx+32, posy, posz, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-32, posy, posz, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+32, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-32, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx+32, posy, posz+32, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-32, posy, posz+32, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-32, posy, posz-32, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx+32, posy, posz-32, math_random(0,3),GaiaTeamID)
				if posy > 0 then
					local r2 = Resurrectors[math_random(1,#Resurrectors)]
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx+32, posy, posz, math_random(0,3),GaiaTeamID,n+150+1)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx-32, posy, posz, math_random(0,3),GaiaTeamID,n+150+2)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz+32, math_random(0,3),GaiaTeamID,n+150+3)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz-32, math_random(0,3),GaiaTeamID,n+150+4)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx+32, posy, posz+32, math_random(0,3),GaiaTeamID,n+150+5)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx-32, posy, posz-32, math_random(0,3),GaiaTeamID,n+150+6)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx-32, posy, posz+32, math_random(0,3),GaiaTeamID,n+150+7)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx+32, posy, posz-32, math_random(0,3),GaiaTeamID,n+150+8)
				elseif constructorControllerModuleConfig.searesurrectors == true then
					local r3 = ResurrectorsSea[math_random(1,#ResurrectorsSea)]
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx+32, posy, posz+32, math_random(0,3),GaiaTeamID,n+150+1)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx-32, posy, posz-32, math_random(0,3),GaiaTeamID,n+150+2)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx-32, posy, posz+32, math_random(0,3),GaiaTeamID,n+150+3)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx+32, posy, posz-32, math_random(0,3),GaiaTeamID,n+150+4)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx+32, posy, posz+32, math_random(0,3),GaiaTeamID,n+150+5)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx-32, posy, posz-32, math_random(0,3),GaiaTeamID,n+150+6)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx-32, posy, posz+32, math_random(0,3),GaiaTeamID,n+150+7)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx+32, posy, posz-32, math_random(0,3),GaiaTeamID,n+150+8)
				end
			end
			constructortimer = 0
			local r = ConstructorsList[math_random(1,#ConstructorsList)]
			QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID,n+150)
			Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
		else
			constructortimer = constructortimer +  math.ceil(n/constructorControllerModuleConfig.constructortimerreductionframes)
		end
	else
		constructortimer = constructortimer +  math.ceil(n/constructorControllerModuleConfig.constructortimerreductionframes)
	end
end

ConstructorNumberOfRetries = {}
function ConstructNewBlueprint(n, unitID)
	local unitCount = Spring.GetTeamUnitCount(GaiaTeamID)
	local unitCountBuffer = 200

	if unitCount + unitCountBuffer >= scavMaxUnits then
		local mapCenterX = mapsizeX / 2
		local mapCenterZ = mapsizeZ / 2
		local mapCenterY = Spring.GetGroundHeight(mapCenterX, mapCenterZ)
		local mapDiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
		Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, { mapCenterX + math_random(-100, 100), mapCenterY, mapCenterZ + math_random(-100, 100), mapDiagonal}, 0)
		Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, { mapCenterX + math_random(-100, 100), mapCenterY, mapCenterZ + math_random(-100, 100), mapDiagonal}, {"shift"})

		return
	end

	local landBlueprint, seaBlueprint, blueprint

	if not ConstructorNumberOfRetries[unitID] then
		ConstructorNumberOfRetries[unitID] = 0
	end
	ConstructorNumberOfRetries[unitID] = ConstructorNumberOfRetries[unitID] + 1

	local spawnTierChance = math_random(1,100)
	if spawnTierChance <= TierSpawnChances.T0 then
		landBlueprint = blueprintsController.GetRandomLandBlueprint(blueprintsController.Tiers.T0)
	elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 then
		landBlueprint = blueprintsController.GetRandomLandBlueprint(blueprintsController.Tiers.T1)
	elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
		landBlueprint = blueprintsController.GetRandomLandBlueprint(blueprintsController.Tiers.T2)
	elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
		landBlueprint = blueprintsController.GetRandomLandBlueprint(blueprintsController.Tiers.T3)
	elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
		landBlueprint = blueprintsController.GetRandomLandBlueprint(blueprintsController.Tiers.T4)
	else
		landBlueprint = blueprintsController.GetRandomLandBlueprint(blueprintsController.Tiers.T0)
	end

	-- if spawnTierChance <= TierSpawnChances.T0 then
	-- 	seaBlueprint = blueprintsController.GetRandomSeaBlueprint(blueprintsController.Tiers.T0)
	-- elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 then
	-- 	seaBlueprint = blueprintsController.GetRandomSeaBlueprint(blueprintsController.Tiers.T1)
	-- elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
	-- 	seaBlueprint = blueprintsController.GetRandomSeaBlueprint(blueprintsController.Tiers.T2)
	-- elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
	-- 	seaBlueprint = blueprintsController.GetRandomSeaBlueprint(blueprintsController.Tiers.T3)
	-- elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
	-- 	seaBlueprint = blueprintsController.GetRandomSeaBlueprint(blueprintsController.Tiers.T4)
	-- else
	-- 	seaBlueprint = blueprintsController.GetRandomSeaBlueprint(blueprintsController.Tiers.T0)
	-- end

	for i = 1,50 do
		local x,y,z = Spring.GetUnitPosition(unitID)
		local posX = math_random( x - (50 * ConstructorNumberOfRetries[unitID]), x + (50 * ConstructorNumberOfRetries[unitID]))
		local posZ = math_random( z - (50 * ConstructorNumberOfRetries[unitID]), z + (50 * ConstructorNumberOfRetries[unitID]))
		local posY = Spring.GetGroundHeight(posX, posZ)

		if posY > 0 then
			blueprint = landBlueprint
		elseif posY <= 0 then
			-- blueprint = seaBlueprint
			break
		end

		local blueprintRadiusBuffer = 48
		local blueprintRadius = blueprint.radius + blueprintRadiusBuffer
		local canConstructHere = posOccupied(posX, posY, posZ, blueprintRadius)
									and posCheck(posX, posY, posZ, blueprintRadius)
									and posSafeAreaCheck(posX, posY, posZ, blueprintRadius)
									and posMapsizeCheck(posX, posY, posZ, blueprintRadius)

		if canConstructHere then
			Spring.GiveOrderToUnit(unitID, CMD.MOVE,{posX+math.random(-blueprintRadius,blueprintRadius),posY+500,posZ+math.random(-blueprintRadius,blueprintRadius)}, {"shift"})

			for _, building in ipairs(blueprint.buildings) do
				Spring.GiveOrderToUnit(unitID, -building.unitDefID, { posX + building.xOffset, posY + building.yOffset, posZ + building.zOffset, building.direction }, {"shift"})
			end

			ConstructorNumberOfRetries[unitID] = 0
			break
		end
	end
end

function SpawnResurrectorGroup(n)
	if ScavSafeAreaExist then 
		--ResurrectorSpawnCount = math.ceil(math.random(0,math.ceil(teamcount*spawnmultiplier))+1)
		local spawnTierChance = math.random(1,100)
		if spawnTierChance <= TierSpawnChances.T0 then
			ResurrectorSpawnCount = 1
		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 then
			ResurrectorSpawnCount = math.random(1,2)
		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
			ResurrectorSpawnCount = math.random(3,5)
		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
			ResurrectorSpawnCount = math.random(6,10)
		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
			ResurrectorSpawnCount = math.random(11,20)
		else
			ResurrectorSpawnCount = 0
		end
		if ResurrectorSpawnCount == 0 then
			return
		end
		local posx = math.random(ScavSafeAreaMinX, ScavSafeAreaMaxX)
		local posz = math.random(ScavSafeAreaMinZ, ScavSafeAreaMaxZ)
		local posy = Spring.GetGroundHeight(posx, posz)
		local posradius = 32
		for a = 1,100 do
			canSpawnHere = posCheck(posx, posy, posz, posradius)
			if canSpawnHere == true then
				canSpawnHere = posOccupied(posx, posy, posz, posradius)
			end
			if canSpawnHere == true then
				for y = 1,ResurrectorSpawnCount do
					if posy > -20 then
						local r2 = Resurrectors[math_random(1,#Resurrectors)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID,n+(y*1)+150)
					else
						local r3 = ResurrectorsSea[math_random(1,#ResurrectorsSea)]
						QueueSpawn(r3..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID,n+(y*1)+150)
					end
				end
				break
			end
		end
	end
end