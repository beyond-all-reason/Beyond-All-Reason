Spring.Echo("[Scavengers] Constructor Controller initialized")

VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/UnitLists/constructors.lua")
Blueprints2List = VFS.DirList('luarules/gadgets/scavengers/Blueprints/Constructor/','*.lua')
for i = 1,#Blueprints2List do
	VFS.Include(Blueprints2List[i])
	Spring.Echo("Scav Blueprints Directory: " ..Blueprints2List[i])
end
local constructortimer = constructorControllerModule.constructortimer - 10

function SpawnConstructor()
	local posx = math.random(200,mapsizeX-200)
	local posz = math.random(200,mapsizeZ-200)
	local posy = Spring.GetGroundHeight(posx, posz)
	local posradius = 30
	canSpawnCommanderHere = posCheck(posx, posy, posz, posradius)
	if canSpawnCommanderHere then
		canSpawnCommanderHere = posLosCheck(posx, posy, posz,posradius)
	end
	if canSpawnCommanderHere then
		canSpawnCommanderHere = posOccupied(posx, posy, posz, posradius)
	end
	if canSpawnCommanderHere then
		if constructortimer > constructorControllerModule.constructortimer then
			constructortimer = constructortimer - constructorControllerModule.constructortimer
			local r = ConstructorsList[math.random(1,#ConstructorsList)]
			Spring.CreateUnit(r..scavconfig.unitnamesuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
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
			local r = math.random(0,2)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT2[math.random(1,#ScavengerConstructorBlueprintsT2)]
			elseif r == 1 then
				blueprint = ScavengerConstructorBlueprintsT1[math.random(1,#ScavengerConstructorBlueprintsT1)]
			else
				blueprint = ScavengerConstructorBlueprintsT0[math.random(1,#ScavengerConstructorBlueprintsT0)]
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
			local r = math.random(0,3)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT3Sea[math.random(1,#ScavengerConstructorBlueprintsT3Sea)]
			elseif r == 1 then
				blueprint = ScavengerConstructorBlueprintsT2Sea[math.random(1,#ScavengerConstructorBlueprintsT2Sea)]
			elseif r == 2 then
				blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
			else
				blueprint = ScavengerConstructorBlueprintsT0Sea[math.random(1,#ScavengerConstructorBlueprintsT0Sea)]
			end
		elseif n > scavconfig.timers.Tech2 then
			local r = math.random(0,2)
			if r == 0 then
				blueprint = ScavengerConstructorBlueprintsT2Sea[math.random(1,#ScavengerConstructorBlueprintsT2Sea)]
			elseif r == 1 then
				blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
			else
				blueprint = ScavengerConstructorBlueprintsT0Sea[math.random(1,#ScavengerConstructorBlueprintsT0Sea)]
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