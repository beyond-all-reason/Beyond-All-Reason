Spring.Echo("[Scavengers] Constructor Controller initialized")

VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/UnitLists/constructors.lua")
Blueprints2List = VFS.DirList('luarules/gadgets/scavengers/Blueprints/'..GameShortName..'/Constructor/','*.lua')
for i = 1,#Blueprints2List do
	VFS.Include(Blueprints2List[i])
	Spring.Echo("Scav Blueprints Directory: " ..Blueprints2List[i])
end
local constructortimer = constructorControllerModuleConfig.constructortimerstart

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
	Spring.GiveOrderToUnit(scav, CMD.RESURRECT,{mapcenterX+math.random(-100,100),mapcenterY,mapcenterZ+math.random(-100,100),mapdiagonal}, {})
	--Spring.GiveOrderToUnit(scav, CMD.RECLAIM,{mapcenterX+math.random(-100,100),mapcenterY,mapcenterZ+math.random(-100,100),mapdiagonal}, {"shift"})
end

function CollectorOrders(n, scav)
	local mapcenterX = mapsizeX/2
	local mapcenterZ = mapsizeZ/2
	local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
	local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
	Spring.GiveOrderToUnit(scav, CMD.RECLAIM,{mapcenterX+math.random(-100,100),mapcenterY,mapcenterZ+math.random(-100,100),mapdiagonal}, {})
	--Spring.GiveOrderToUnit(scav, CMD.RECLAIM,{mapcenterX+math.random(-100,100),mapcenterY,mapcenterZ+math.random(-100,100),mapdiagonal}, {"shift"})
end

function SpawnConstructor()
	local posx = math.random(250,mapsizeX-250)
	local posz = math.random(250,mapsizeZ-250)
	local posy = Spring.GetGroundHeight(posx, posz)
	local posradius = 48
	canSpawnCommanderHere = posCheck(posx, posy, posz, posradius)
	if canSpawnCommanderHere then
		canSpawnCommanderHere = posLosCheck(posx, posy, posz,posradius)
	end
	if canSpawnCommanderHere then
		canSpawnCommanderHere = posOccupied(posx, posy, posz, posradius)
	end
	if canSpawnCommanderHere then
		if constructortimer > constructorControllerModuleConfig.constructortimer then
			constructortimer = constructortimer - constructorControllerModuleConfig.constructortimer
			local r = ConstructorsList[math.random(1,#ConstructorsList)]
			local r2 = Resurrectors[math.random(1,#Resurrectors)]
			local r3 = ResurrectorsSea[math.random(1,#ResurrectorsSea)]
			Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+posradius, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-posradius, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz+posradius, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz+posradius, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz-posradius, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz-posradius, math.random(0,3),GaiaTeamID)
			Spring.CreateUnit(r..scavconfig.unitnamesuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
			if posy > 0 then
				Spring.CreateUnit(r2..scavconfig.unitnamesuffix, posx+32, posy, posz, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r2..scavconfig.unitnamesuffix, posx-32, posy, posz, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r2..scavconfig.unitnamesuffix, posx, posy, posz+32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r2..scavconfig.unitnamesuffix, posx, posy, posz-32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r2..scavconfig.unitnamesuffix, posx+32, posy, posz+32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r2..scavconfig.unitnamesuffix, posx-32, posy, posz-32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r2..scavconfig.unitnamesuffix, posx-32, posy, posz+32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r2..scavconfig.unitnamesuffix, posx+32, posy, posz-32, math.random(0,3),GaiaTeamID)
			else
				--Spring.CreateUnit(r3..scavconfig.unitnamesuffix, posx+32, posy, posz, math.random(0,3),GaiaTeamID)
				--Spring.CreateUnit(r3..scavconfig.unitnamesuffix, posx-32, posy, posz, math.random(0,3),GaiaTeamID)
				--Spring.CreateUnit(r3..scavconfig.unitnamesuffix, posx, posy, posz+32, math.random(0,3),GaiaTeamID)
				--Spring.CreateUnit(r3..scavconfig.unitnamesuffix, posx, posy, posz-32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r3..scavconfig.unitnamesuffix, posx+32, posy, posz+32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r3..scavconfig.unitnamesuffix, posx-32, posy, posz-32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r3..scavconfig.unitnamesuffix, posx-32, posy, posz+32, math.random(0,3),GaiaTeamID)
				Spring.CreateUnit(r3..scavconfig.unitnamesuffix, posx+32, posy, posz-32, math.random(0,3),GaiaTeamID)
			end
		else
			constructortimer = constructortimer + 1
		end
	else
		constructortimer = constructortimer + 1
	end
end			
	
function ConstructNewBlueprint(n, scav)
	local x,y,z = Spring.GetUnitPosition(scav)
	local posx = math.random(x-1000,x+1000)
	local posz = math.random(z-1000,z+1000)
	local posy = Spring.GetGroundHeight(posx, posz)
	if posy > 0 then
		if n > scavconfig.timers.Tech3 then
			local r = math.random(0,1)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT3[math.random(1,#ScavengerConstructorBlueprintsT3)]
			else
				blueprint = ScavengerConstructorBlueprintsT2[math.random(1,#ScavengerConstructorBlueprintsT2)]
			end
		elseif n > scavconfig.timers.Tech2 then
			local r = math.random(0,1)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT2[math.random(1,#ScavengerConstructorBlueprintsT2)]
			else
				blueprint = ScavengerConstructorBlueprintsT1[math.random(1,#ScavengerConstructorBlueprintsT1)]
			end
		elseif n > scavconfig.timers.Tech1 then
			local r = math.random(0,1)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT1[math.random(1,#ScavengerConstructorBlueprintsT1)]
			else
				blueprint = ScavengerConstructorBlueprintsT0[math.random(1,#ScavengerConstructorBlueprintsT0)]
			end
		else
			blueprint = ScavengerConstructorBlueprintsT0[math.random(1,#ScavengerConstructorBlueprintsT0)]
		end
	elseif posy <= 0 then	
		if n > scavconfig.timers.Tech3 then
			local r = math.random(0,1)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT3Sea[math.random(1,#ScavengerConstructorBlueprintsT3Sea)]
			else
				blueprint = ScavengerConstructorBlueprintsT2Sea[math.random(1,#ScavengerConstructorBlueprintsT2Sea)]
			end
		elseif n > scavconfig.timers.Tech2 then
			local r = math.random(0,1)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT2Sea[math.random(1,#ScavengerConstructorBlueprintsT2Sea)]
			else
				blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
			end
		elseif n > scavconfig.timers.Tech1 then
			local r = math.random(0,1)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
			else
				blueprint = ScavengerConstructorBlueprintsT0Sea[math.random(1,#ScavengerConstructorBlueprintsT0Sea)]
			end
		else
			blueprint = ScavengerConstructorBlueprintsT0Sea[math.random(1,#ScavengerConstructorBlueprintsT0Sea)]
		end	
	end
							
	posradius = blueprint(scav, posx, posy, posz, GaiaTeamID, true)
	canConstructHere = posOccupied(posx, posy, posz, posradius)
	if canConstructHere then
		canConstructHere = posCheck(posx, posy, posz, posradius)
	end
	if canConstructHere then
		-- let's do this shit
		blueprint(scav, posx, posy, posz, GaiaTeamID, false)
		local x = math.random(x-1000,x+1000)
		local z = math.random(z-1000,z+1000)
		local y = Spring.GetGroundHeight(x,z)
		Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
		local x = math.random(x-100,x+100)
		local z = math.random(z-100,z+100)
		local y = Spring.GetGroundHeight(x,z)
		Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
	else
		local x,y,z = Spring.GetUnitPosition(scav)
		local x = math.random(x-500,x+500)
		local z = math.random(z-500,z+500)
		local y = Spring.GetGroundHeight(x,z)
		Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
		local x,y,z = Spring.GetUnitPosition(scav)
		local x = math.random(x-100,x+100)
		local z = math.random(z-100,z+100)
		local y = Spring.GetGroundHeight(x,z)
		Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
	end
end