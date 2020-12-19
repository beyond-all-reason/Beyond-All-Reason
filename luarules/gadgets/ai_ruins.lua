-- these are used in poschecks.lua so arent localized here
mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
GaiaTeamID = Spring.GetGaiaTeamID()
GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local GameShortName = Game.gameShortName
local RuinSpawns = ((math.ceil(mapsizeX+mapsizeZ)/500)+30)*10

local scavengersAIEnabled = false
local scavengerAllyTeamID
local teams = Spring.GetTeamList()
for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengersAIEnabled = true
		scavengerAllyTeamID = select(6, Spring.GetTeamInfo(i - 1))
		break
	end
end

local ruinSpawnEnabled = false
if (Spring.GetModOptions and (Spring.GetModOptions().ruins or "disabled") == "enabled") then--or scavengersAIEnabled then
	ruinSpawnEnabled = true
end

VFS.Include('luarules/gadgets/scavengers/API/poschecks.lua')

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
		if patrol and patrol == true and canmove and speed > 0 then
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

local BlueprintsList = VFS.DirList('luarules/gadgets/scavengers/Ruins/'..GameShortName..'/','*.lua')
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
	if n > 30 and n%10 == 0 and n <= RuinSpawns then
		for i = 1,100 do
			local pickedRuin = RuinsList[math.random(1,#RuinsList)]
			local pickedRuinSea = RuinsListSea[math.random(1,#RuinsListSea)]
			local seaRuinChance = math.random(1,2)
			local posx = math.random(0,mapsizeX)
			local posz = math.random(0,mapsizeZ)
			local posy = Spring.GetGroundHeight(posx, posz)
			local posradius, canBuildHere
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


