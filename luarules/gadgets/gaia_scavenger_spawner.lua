function gadget:GetInfo()
  return {
    name      = "gaia scavenger unit spawner",
    desc      = "Spawner of units",
    author    = "Damgam",
    date      = "2019",
    layer     = -100,
    enabled   = true,
	}
end

local devswitch = 1
if (Spring.GetModOptions() == nil or Spring.GetModOptions().scavengers == nil or tonumber(Spring.GetModOptions().scavengers) == 0) and devswitch == 0 then
	return
end

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end


------------------------------------------------------------------------

local GaiaTeamID  = Spring.GetGaiaTeamID()
local _,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)
local teamcount = #Spring.GetTeamList() - 2
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ
local spawnmultiplier = tonumber(Spring.GetModOptions().scavengers) or 1
if devswitch == 1 then
	spawnmultiplier = 1
end
local failcounter = 0
--local discoscavengers = tonumber(Spring.GetModOptions().discoscavengers) or 0

local T1KbotUnits = {"corak", "corcrash", "cornecro", "corstorm", "corthud", "armham", "armjeth", "armpw", "armrectr", "armrock", "armwar",}
local T2KbotUnits = {"coraak", "coramph", "corcan", "corhrk", "cormando", "cormort", "corpyro", "corroach", "corsktl", "corsumo", "cortermite", "armaak", "armamph", "armfast", "armfboy", "armfido", "armmav", "armsnipe", "armspid", "armsptk", "armvader", "armzeus", }

local T1TankUnits = { "corgarp", "corgator", "corlevlr", "cormist", "corraid", "corwolv", "armart", "armflash", "armjanus", "armpincer", "armsam", "armstump",}
local T2TankUnits = {"corban", "corgol", "cormart", "corparrow", "correap", "corseal", "corsent", "cortrem", "corvroc", "armbull", "armcroc", "armlatnk", "armmanni", "armmart", "armmerl", "armst", "armyork",}

local T1SeaUnits = {"coresupp", "corpship", "corpt", "correcl", "corroy", "corsub", "corgarp", "armdecade", "armpship", "armpt", "armrecl", "armroy", "armsub","armpincer",}
local Hovercrafts = {"corah", "corhal", "cormh", "corsh", "corsnap", "corsok", "armah", "armanac", "armlun", "armmh", "armsh", }
local T2SeaUnits = {"corarch", "corbats", "corblackhy", "corcrus", "cormship", "corshark", "armbats", "armcrus", "armepoch", "armmship", "armsubk", "coraak", "coramph", "corroach", "corsktl", "armaak", "armamph", "armvader", "corparrow", "corseal", "armcroc", }

local T1AirUnits = {"corbw", "corshad", "corveng", "armfig", "armkam", "armthund",}
local Seaplanes = {"corcut", "corhunt", "corsb", "corseap", "corsfig", "armsaber", "armsb", "armseap", "armsehak", "armsfig",}
local T2AirUnits = {"corape", "corcrw", "corhurc", "cortitan", "corvamp", "armblade", "armbrawl", "armhawk", "armlance", "armliche", "armpnix", "armstil",}

local Tech3Units = {"corcat", "corjugg", "corkarg", "corkrog", "corshiva", "armbanth", "armmar", "armraz", "armvang",}

local T1LandBuildings = {}
local T2LandBuildings = {}
local T3LandBuildings = {}

local T1SeaBuildings = {}
local T2SeaBuildings = {}
local T3SeaBuildings = {}

--local timer = Spring.GetGameSeconds()

local red = 125
local green = 125
local blue = 125

local dx = {}
local dy = {}
local dz = {}
local olddx = {}
local olddy = {}
local olddz = {}
local selfdestructcounter = 0



------------------------------------------------------------------------

function gadget:Initialize()
	-- Spring.SetTeamColor(GaiaTeamID, 0, 0, 0)
	-- local mo = Spring.GetModOptions()
	-- if mo and tonumber(mo.scavengers)==0 then
		-- Spring.Echo("[scavengers] Disabled via ModOption")
		-- gadgetHandler:RemoveGadget(self)
	-- end

end

function gadget:GameFrame(n)
	if n == 100 then
		Spring.SetTeamResource(GaiaTeamID, "ms", 100000)
		Spring.SetTeamResource(GaiaTeamID, "es", 100000)
		Spring.SetGlobalLos(GaiaAllyTeamID, true)
	end
	if n%5 == 0 and n > 9000 then
		red = red + math.random(-10,10)
		green = green + math.random(-10,10)
		blue = blue + math.random(-10,10)
		if red < 0 then red = 0 elseif red > 255 then red = 255 elseif green < 0 then green = 0 elseif green > 255 then green = 255 elseif blue < 0 then blue = 0 elseif blue > 255 then blue = 255 end
		Spring.SetTeamColor(GaiaTeamID, red/255, green/255, blue/255)
	end
	if n%30 == 0 and n > 9000 then
		Spring.SetTeamResource(GaiaTeamID, "m", 100000)
		Spring.SetTeamResource(GaiaTeamID, "e", 100000)
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		local spawnchance = math.random(1,math.ceil(((gaiaUnitCount*5)/teamcount)+2))
		--local spawnchance = 1 -- dev purpose
		if spawnchance == 1 or failedspawn then
			failedspawn = false
			-- check positions
			local posx = math.random(400,mapsizeX-400)
			local posz = math.random(400,mapsizeZ-400)
			local posy = Spring.GetGroundHeight(posx, posz)
			
			testpos1 = Spring.GetGroundHeight(posx + math.random(-100,100), posz + math.random(-100,100))
			testpos2 = Spring.GetGroundHeight(posx + math.random(-100,100), posz + math.random(-100,100))
			testpos3 = Spring.GetGroundHeight(posx + math.random(-100,100), posz + math.random(-100,100))
			testpos4 = Spring.GetGroundHeight(posx + math.random(-100,100), posz + math.random(-100,100))
			if testpos1 < posy - 10 or testpos1 > posy + 10 then
				failedspawn = true
			elseif testpos2 < posy - 10 or testpos2 > posy + 10 then
				failedspawn = true
			elseif testpos3 < posy - 10 or testpos3 > posy + 10 then
				failedspawn = true
			elseif testpos4 < posy - 10 or testpos4 > posy + 10 then
				failedspawn = true
			end
			
			if not failedspawn then

				for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
					if allyTeamID ~= GaiaAllyTeamID then
						if  failcounter < 60 and Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true then
							failedspawn = true
							failcounter = failcounter + 1
							if devswitch == 1 then
								Spring.Echo("Failed to spawn Scavenger group. Failcounter: " ..failcounter)
							end
							break
						elseif failcounter < 15 and Spring.IsPosInRadar(posx, posy, posz, allyTeamID) == true then
							failedspawn = true
							failcounter = failcounter + 1
							if devswitch == 1 then
								Spring.Echo("Failed to spawn Scavenger group. Failcounter: " ..failcounter)
							end
							break
						elseif failcounter < 15 and Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true then
							failedspawn = true
							failcounter = failcounter + 1
							if devswitch == 1 then
								Spring.Echo("Failed to spawn Scavenger group. Failcounter: " ..failcounter)
							end
							break
						else
							failedspawn = false
						end
					end
				end
			end
			
			--spawn units
			if not failedspawn then
				failcounter = 0
				local groupsize = ((n/3)+#Spring.GetAllUnits())*spawnmultiplier*teamcount
				local airrng = math.random(0,5)
				local kbottankrng = math.random(0,1)
				if airrng == 0 then
					Spring.CreateUnit("corca", posx, posy, posz, math.random(0,3),GaiaTeamID)
					if Spring.GetGameSeconds() < 600 then
						spawnair = T1AirUnits[math.random(1,#T1AirUnits)]
					elseif Spring.GetGameSeconds() >= 600 and Spring.GetGameSeconds() < 1200 then
						local r = math.random(0,3)
						if r == 0 then
							spawnair = Seaplanes[math.random(1,#Seaplanes)]
							groupsize = groupsize*1.3
						else
							spawnair = T1AirUnits[math.random(1,#T1AirUnits)]
						end
					elseif Spring.GetGameSeconds() >= 1200 then
						local r = math.random(0,3)
						if r == 0 then
							spawnair = Seaplanes[math.random(1,#Seaplanes)]
							groupsize = groupsize*1.4
						elseif r == 1 then
							spawnair = T1AirUnits[math.random(1,#T1AirUnits)]
							groupsize = groupsize*1.3
						else
							spawnair = T2AirUnits[math.random(1,#T2AirUnits)]
							groupsize = groupsize*1.6
						end
					end
					
					local cost = UnitDefNames[spawnair].metalCost + UnitDefNames[spawnair].energyCost
					local groupsize = math.ceil(groupsize/cost)
					for i=1, groupsize do
						Spring.CreateUnit(spawnair, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
					end
					Spring.Echo("Spawned Scavenger group: " ..groupsize.. " " ..UnitDefNames[spawnair].humanName.. "s")
				elseif posy > 10 then
					Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
					Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
					if kbottankrng == 0 then
						
						if Spring.GetGameSeconds() < 1200 then
							spawnkbot = T1KbotUnits[math.random(1,#T1KbotUnits)]
						else
							local r = math.random(0,2)
							if r == 0 then
								spawnkbot = T1KbotUnits[math.random(1,#T1KbotUnits)]
								groupsize = groupsize*1.3
								Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
							else
								spawnkbot = T2KbotUnits[math.random(1,#T2KbotUnits)]
								groupsize = groupsize*1.6
								Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
								Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
							end
						end
						
						local cost = UnitDefNames[spawnkbot].metalCost + UnitDefNames[spawnkbot].energyCost
						local groupsize = math.ceil(groupsize/cost)
						for i=1, groupsize do
							Spring.CreateUnit(spawnkbot, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
						end
						Spring.Echo("Spawned Scavenger group: " ..groupsize.. " " ..UnitDefNames[spawnkbot].humanName.. "s")
					else
						if Spring.GetGameSeconds() < 600 then
							spawntank = T1TankUnits[math.random(1,#T1TankUnits)]
						elseif Spring.GetGameSeconds() >= 600 and Spring.GetGameSeconds() < 1200 then
							local r = math.random(0,3)
							if r == 0 then
								spawntank = Hovercrafts[math.random(1,#Hovercrafts)]
								groupsize = groupsize*1.3
								Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
							else
								spawntank = T1TankUnits[math.random(1,#T1TankUnits)]
							end
						elseif Spring.GetGameSeconds() >= 1200 then
							local r = math.random(0,3)
							if r == 0 then
								spawntank = Hovercrafts[math.random(1,#Hovercrafts)]
								groupsize = groupsize*1.4
								Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
							elseif r == 1 then
								spawntank = T1TankUnits[math.random(1,#T1TankUnits)]
								groupsize = groupsize*1.3
								Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
							else
								spawntank = T2TankUnits[math.random(1,#T2TankUnits)]
								groupsize = groupsize*1.6
								Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
								Spring.CreateUnit("cornecro", posx, posy, posz, math.random(0,3),GaiaTeamID)
							end
						end
						
						local cost = UnitDefNames[spawntank].metalCost + UnitDefNames[spawntank].energyCost
						local groupsize = math.ceil(groupsize/cost)
						for i=1, groupsize do
							Spring.CreateUnit(spawntank, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
						end
						Spring.Echo("Spawned Scavenger group: " ..groupsize.. " " ..UnitDefNames[spawntank].humanName.. "s")
					end
					local t3random = math.random(0,5)
					if Spring.GetGameSeconds() > 2400 and t3random == 0 then
						spawnT3 = Tech3Units[math.random(1,#Tech3Units)]
						Spring.CreateUnit(spawnT3, posx, posy, posz, math.random(0,3),GaiaTeamID)
					end
				else
					Spring.CreateUnit("corcsa", posx, posy, posz, math.random(0,3),GaiaTeamID)
					if Spring.GetGameSeconds() < 600 then
						spawnsea = T1SeaUnits[math.random(1,#T1SeaUnits)]
					elseif Spring.GetGameSeconds() >= 600 and Spring.GetGameSeconds() < 1200 then
						local r = math.random(0,3)
						if r == 0 then
							spawnsea = Hovercrafts[math.random(1,#Hovercrafts)]
							groupsize = groupsize*1.3
						else
							spawnsea = T1SeaUnits[math.random(1,#T1SeaUnits)]
						end
					elseif Spring.GetGameSeconds() >= 1200 then
						local r = math.random(0,3)
						if r == 0 then
							spawnsea = Hovercrafts[math.random(1,#Hovercrafts)]
							groupsize = groupsize*1.3
						elseif r == 1 then
							spawnsea = T1SeaUnits[math.random(1,#T1SeaUnits)]
						else
							spawnsea = T2SeaUnits[math.random(1,#T2SeaUnits)]
							groupsize = groupsize*1.6
						end
					end
					
					local cost = UnitDefNames[spawnsea].metalCost + UnitDefNames[spawnsea].energyCost
					local groupsize = math.ceil(groupsize/cost)
					for i=1, groupsize do
						Spring.CreateUnit(spawnsea, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
					end
					Spring.Echo("Spawned Scavenger group: " ..groupsize.. " " ..UnitDefNames[spawnsea].humanName.. "s")
				end
			end
		end
		--move idle units
		local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
		if scavengerunits then
			for i = 1,#scavengerunits do
				local givemeorder = scavengerunits[i]
				if n%900 == 0 then
					if dx[givemeorder] then
						olddx[givemeorder] = dx[givemeorder]
					end
					if dy[givemeorder] then
						olddy[givemeorder] = dy[givemeorder]
					end
					if dz[givemeorder] then
						olddz[givemeorder] = dz[givemeorder]
					end
					dx[givemeorder],dy[givemeorder],dz[givemeorder] = Spring.GetUnitPosition(givemeorder)
					if (olddx[givemeorder] and olddy[givemeorder] and olddz[givemeorder]) and (olddx[givemeorder] > dx[givemeorder]-10 and olddx[givemeorder] < dx[givemeorder]+10) and (olddy[givemeorder] > dy[givemeorder]-10 and olddy[givemeorder] < dy[givemeorder]+10) and (olddz[givemeorder] > dz[givemeorder]-10 and olddz[givemeorder] < dz[givemeorder]+10) then
						Spring.DestroyUnit(givemeorder, true, false)
						selfdestructcounter = selfdestructcounter + 1
					end
				end
				if Spring.GetCommandQueue(givemeorder, 0) <= 1 then
					local nearest = Spring.GetUnitNearestEnemy(givemeorder, 200000, false)
					local x,y,z = Spring.GetUnitPosition(nearest)
					local x = x + math.random(-50,50)
					local z = z + math.random(-50,50)
					Spring.GiveOrderToUnit(givemeorder, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
					
				end
			end
			if selfdestructcounter and selfdestructcounter > 0 and devswitch == 1 then
				Spring.Echo("Self Destructed "..selfdestructcounter.." Scavenger units.")
				selfdestructcounter = 0
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
		dx[unitID] = nil
		dy[unitID] = nil
		dz[unitID] = nil
		olddx[unitID] = nil
		olddy[unitID] = nil
		olddz[unitID] = nil
	end
end







































