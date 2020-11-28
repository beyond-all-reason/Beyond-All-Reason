mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
GaiaTeamID = Spring.GetGaiaTeamID()
GameShortName = Game.gameShortName

local RuinSpawns = (math.ceil(mapsizeX+mapsizeZ)/500)+30

local teams = Spring.GetTeamList()

for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengersAIEnabled = true
		scavengerAITeamID = i - 1
		_,_,_,_,_,scavengerAllyTeamID = Spring.GetTeamInfo(scavengerAITeamID)
		break
	end
end

if scavengersAIEnabled or (Spring.GetModOptions and (Spring.GetModOptions().ruins or "disabled") == "enabled") then
	ruinSpawnEnabled = true
else
	ruinSpawnEnabled = false
end

VFS.Include('luarules/gadgets/scavengers/API/poschecks.lua')
GaiaTeamID = Spring.GetGaiaTeamID()
_,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)

function SpawnRuin(name, posx, posy, posz, facing, patrol)
	local r = math.random(1,100)
	if r < 30 and FeatureDefNames[name.."_heap"] then
		local fe = Spring.CreateFeature(name.."_heap", posx, Spring.GetGroundHeight(posx, posz), posz, facing, GaiaTeamID)
		Spring.SetFeatureAlwaysVisible(fe, true)
	elseif r < 60 and FeatureDefNames[name.."_dead"] then
		local fe = Spring.CreateFeature(name.."_dead", posx, Spring.GetGroundHeight(posx, posz), posz, facing, GaiaTeamID)
		Spring.SetFeatureAlwaysVisible(fe, true)
		Spring.SetFeatureResurrect(fe, name)
	elseif r < 90 then
		local u = Spring.CreateUnit(name, posx, Spring.GetGroundHeight(posx, posz), posz, facing, GaiaTeamID)
		Spring.SetUnitNeutral(u, true)
		Spring.GiveOrderToUnit(u,CMD.FIRE_STATE,{1},0)
		Spring.GiveOrderToUnit(u,CMD.MOVE_STATE,{0},0)
		Spring.SetUnitAlwaysVisible(u, true)
		local udefid = Spring.GetUnitDefID(u)
		local rrange = UnitDefs[udefid].radarRadius
		local canmove = UnitDefs[udefid].canMove
		local speed = UnitDefs[udefid].speed
		if (patrol and patrol == true) and canmove and speed > 0 then
			for i = 1,6 do
				Spring.GiveOrderToUnit(u, CMD.PATROL,{posx+(math.random(-200,200)),posy+100,posz+(math.random(-200,200))}, {"shift", "alt", "ctrl"})
			end
		end
		if rrange and rrange > 1000 then
			Spring.GiveOrderToUnit(u,CMD.ONOFF,{0},0)
		end
	else
	
	end
end

BlueprintsList = VFS.DirList('luarules/gadgets/scavengers/Ruins/'..GameShortName..'/','*.lua')
RuinsList = {}
RuinsListSea = {}
for i = 1,#BlueprintsList do
	VFS.Include(BlueprintsList[i])
	Spring.Echo("Ruin Blueprints Directory: " ..BlueprintsList[i])
end




function gadget:GetInfo()
    return {
      name      = "ruin spawn",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
      layer     = -100,
      enabled   = ruinSpawnEnabled,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GameFrame(n)
	if n > 30 and n <= RuinSpawns then
		for i = 1,100 do
			pickedRuin = RuinsList[math.random(1,#RuinsList)]
			pickedRuinSea = RuinsListSea[math.random(1,#RuinsListSea)]
			seaRuinChance = math.random(1,2)
			local posx = math.random(0,mapsizeX)
			local posz = math.random(0,mapsizeZ)
			local posy = Spring.GetGroundHeight(posx, posz)
			if posy > 0 then
				posradius = pickedRuin(posx, posy, posz, GaiaTeamID, true)
				canBuildHere = posLosCheck(posx, posy, posz, posradius)
				if canBuildHere then
					canBuildHere = posMapsizeCheck(posx, posy, posz, posradius)
				end
				if canBuildHere then
					canBuildHere = posOccupied(posx, posy, posz, posradius)
				end
				if canBuildHere then
					canBuildHere = posCheck(posx, posy, posz, posradius)
				end
				if canBuildHere then
					canBuildHere = posLandCheck(posx, posy, posz, posradius)
				end

				if canBuildHere then
					pickedRuin(posx, posy, posz, GaiaTeamID, false)
					break
				end
			elseif posy <= 0 and seaRuinChance == 1 then
				posradius = pickedRuinSea(posx, posy, posz, GaiaTeamID, true)
				canBuildHere = posLosCheck(posx, posy, posz, posradius)
				if canBuildHere then
					canBuildHere = posMapsizeCheck(posx, posy, posz, posradius)
				end
				if canBuildHere then
					canBuildHere = posOccupied(posx, posy, posz, posradius)
				end
				if canBuildHere then
					canBuildHere = posCheck(posx, posy, posz, posradius)
				end
				if canBuildHere then
					canBuildHere = posSeaCheck(posx, posy, posz, posradius)
				end

				if canBuildHere then
					pickedRuinSea(posx, posy, posz, GaiaTeamID, false)
					break
				end
			end
		end
	end
end


