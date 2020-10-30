Spring.Echo("[Scavengers] Constructor Controller initialized")

VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/UnitLists/constructors.lua")
Blueprints2List = VFS.DirList('luarules/gadgets/scavengers/Blueprints/'..GameShortName..'/Constructor/','*.lua')
for i = 1,#Blueprints2List do
	VFS.Include(Blueprints2List[i])
	Spring.Echo("Scav Blueprints Directory: " ..Blueprints2List[i])
end
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
	if (constructortimer > constructorControllerModuleConfig.constructortimer or CountScavConstructors() < constructorControllerModuleConfig.minimumconstructors ) and numOfSpawnBeacons > 0 and constructortimer > 4 then
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
				pickedBeacon = 1234567890
			end
		end
		if pickedBeacon == 1234567890 then
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
			posradius = 48
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
				Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz+posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz+posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz-posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz-posradius, math_random(0,3),GaiaTeamID)
				if posy > 0 then
					local r2 = Resurrectors[math_random(1,#Resurrectors)]
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx+32, posy, posz, math_random(0,3),GaiaTeamID,n+90+1)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx-32, posy, posz, math_random(0,3),GaiaTeamID,n+90+2)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz+32, math_random(0,3),GaiaTeamID,n+90+3)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz-32, math_random(0,3),GaiaTeamID,n+90+4)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx+32, posy, posz+32, math_random(0,3),GaiaTeamID,n+90+5)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx-32, posy, posz-32, math_random(0,3),GaiaTeamID,n+90+6)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx-32, posy, posz+32, math_random(0,3),GaiaTeamID,n+90+7)
					QueueSpawn(r2..scavconfig.unitnamesuffix, posx+32, posy, posz-32, math_random(0,3),GaiaTeamID,n+90+8)
				elseif constructorControllerModuleConfig.searesurrectors == true then
					local r3 = ResurrectorsSea[math_random(1,#ResurrectorsSea)]
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx+32, posy, posz+32, math_random(0,3),GaiaTeamID,n+90+1)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx-32, posy, posz-32, math_random(0,3),GaiaTeamID,n+90+2)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx-32, posy, posz+32, math_random(0,3),GaiaTeamID,n+90+3)
					QueueSpawn(r3..scavconfig.unitnamesuffix, posx+32, posy, posz-32, math_random(0,3),GaiaTeamID,n+90+4)
				end
			end
			constructortimer = constructortimer - constructorControllerModuleConfig.constructortimer
			local r = ConstructorsList[math_random(1,#ConstructorsList)]
			QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID,n+90)
			Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
		else
			constructortimer = constructortimer +  math.ceil(n/constructorControllerModuleConfig.constructortimerreductionframes)
		end
	else
		constructortimer = constructortimer +  math.ceil(n/constructorControllerModuleConfig.constructortimerreductionframes)
	end
end

ConstructorNumberOfRetries = {}
function ConstructNewBlueprint(n, scav)
	if not ConstructorNumberOfRetries[scav] then
		ConstructorNumberOfRetries[scav] = 0
	end
	ConstructorNumberOfRetries[scav] = ConstructorNumberOfRetries[scav] + 1
	local x,y,z = Spring.GetUnitPosition(scav)
	local posx = math_random(x-(50*ConstructorNumberOfRetries[scav]),x+(50*ConstructorNumberOfRetries[scav]))
	local posz = math_random(z-(50*ConstructorNumberOfRetries[scav]),z+(50*ConstructorNumberOfRetries[scav]))
	local posy = Spring.GetGroundHeight(posx, posz)
	local spawnTier = math_random(1,100)
	local unitCount = Spring.GetTeamUnitCount(GaiaTeamID)
	if unitCount + 200 < scavMaxUnits then
		if posy > 0 then
			if spawnTier <= TierSpawnChances.T0 then
					blueprint = ScavengerConstructorBlueprintsT0[math_random(1,#ScavengerConstructorBlueprintsT0)]
			elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
					blueprint = ScavengerConstructorBlueprintsT1[math_random(1,#ScavengerConstructorBlueprintsT1)]
			elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
					blueprint = ScavengerConstructorBlueprintsT2[math_random(1,#ScavengerConstructorBlueprintsT2)]
			elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
					blueprint = ScavengerConstructorBlueprintsT3[math_random(1,#ScavengerConstructorBlueprintsT3)]
			elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
					blueprint = ScavengerConstructorBlueprintsT3[math_random(1,#ScavengerConstructorBlueprintsT3)]
			else
				blueprint = ScavengerConstructorBlueprintsT0[math_random(1,#ScavengerConstructorBlueprintsT0)]
			end
		elseif posy <= 0 then
			if spawnTier <= TierSpawnChances.T0 then
					blueprint = ScavengerConstructorBlueprintsT0Sea[math_random(1,#ScavengerConstructorBlueprintsT0Sea)]
			elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
					blueprint = ScavengerConstructorBlueprintsT1Sea[math_random(1,#ScavengerConstructorBlueprintsT1Sea)]
			elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
					blueprint = ScavengerConstructorBlueprintsT2Sea[math_random(1,#ScavengerConstructorBlueprintsT2Sea)]
			elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
					blueprint = ScavengerConstructorBlueprintsT3Sea[math_random(1,#ScavengerConstructorBlueprintsT3Sea)]
			elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
					blueprint = ScavengerConstructorBlueprintsT3Sea[math_random(1,#ScavengerConstructorBlueprintsT3Sea)]
			else
				blueprint = ScavengerConstructorBlueprintsT0Sea[math_random(1,#ScavengerConstructorBlueprintsT0Sea)]
			end
		end
	else
		local mapcenterX = mapsizeX/2
		local mapcenterZ = mapsizeZ/2
		local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
		local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
		Spring.GiveOrderToUnit(scav, CMD.RECLAIM,{mapcenterX+math_random(-100,100),mapcenterY,mapcenterZ+math_random(-100,100),mapdiagonal}, 0)
		Spring.GiveOrderToUnit(scav, CMD.RECLAIM,{mapcenterX+math_random(-100,100),mapcenterY,mapcenterZ+math_random(-100,100),mapdiagonal}, {"shift"})
	end

	posradius = blueprint(scav, posx, posy, posz, GaiaTeamID, true) + 48
	canConstructHere = posOccupied(posx, posy, posz, posradius)
	if canConstructHere then
		canConstructHere = posCheck(posx, posy, posz, posradius)
	end
	if canConstructHere then
		canConstructHere = posSafeAreaCheck(posx, posy, posz, posradius)
	end
	if canConstructHere then
		canConstructHere = posMapsizeCheck(posx, posy, posz, posradius)
	end

	if canConstructHere then
		-- let's do this shit
		Spring.GiveOrderToUnit(scav, CMD.MOVE,{posx+math.random(-posradius,posradius),posy+500,posz+math.random(-posradius,posradius)}, {"shift"})
		blueprint(scav, posx, posy, posz, GaiaTeamID, false)
		ConstructorNumberOfRetries[scav] = 0
	else
		return
	end
	-- if canConstructHere then
		-- -- let's do this shit
		-- blueprint(scav, posx, posy, posz, GaiaTeamID, false)
		-- local x = math_random(x-1000,x+1000)
		-- local z = math_random(z-1000,z+1000)
		-- local y = Spring.GetGroundHeight(x,z)
		-- Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
		-- local x = math_random(x-100,x+100)
		-- local z = math_random(z-100,z+100)
		-- local y = Spring.GetGroundHeight(x,z)
		-- Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
	-- else
		-- local x,y,z = Spring.GetUnitPosition(scav)
		-- local x = math_random(x-500,x+500)
		-- local z = math_random(z-500,z+500)
		-- local y = Spring.GetGroundHeight(x,z)
		-- Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
		-- local x,y,z = Spring.GetUnitPosition(scav)
		-- local x = math_random(x-100,x+100)
		-- local z = math_random(z-100,z+100)
		-- local y = Spring.GetGroundHeight(x,z)
		-- Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
	-- end
end