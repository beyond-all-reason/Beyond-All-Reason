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

if scavengersAIEnabled or (Spring.GetModOptions and (tonumber(Spring.GetModOptions().ruins) or 0) ~= 0) then
	ruinSpawnEnabled = true
else
	ruinSpawnEnabled = false
end

VFS.Include('luarules/gadgets/scavengers/API/poschecks.lua')
GaiaTeamID = Spring.GetGaiaTeamID()
_,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)

function SpawnRuin(name, posx, posy, posz, facing)
	local r = math.random(1,2)
	if r == 1 then
		local fe = Spring.CreateFeature(name.."_dead", posx, Spring.GetGroundHeight(posx, posz), posz, facing, GaiaAllyTeamID)
		Spring.SetFeatureResurrect(fe, name)
	else
		local u = Spring.CreateUnit(name, posx, Spring.GetGroundHeight(posx, posz), posz, facing, GaiaTeamID)
		Spring.SetUnitNeutral(u, true)
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
			elseif posy <= 0 then
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


