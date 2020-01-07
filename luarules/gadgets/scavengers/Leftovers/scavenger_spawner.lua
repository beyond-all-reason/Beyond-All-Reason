-- function gadget:GetInfo()
  -- return {
    -- name      = "gaia scavenger unit spawner",
    -- desc      = "Spawner of units",
    -- author    = "Damgam + tweaks by IceXuick",
    -- date      = "2019",
    -- layer     = -100,
    -- enabled   = true,
	-- }
-- end

local devswitch = 0
-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

ScavengerBlueprintsStart = {}
ScavengerBlueprintsT1 = {}
ScavengerBlueprintsT2 = {}
ScavengerBlueprintsT3 = {}
ScavengerBlueprintsStartSea = {}
ScavengerBlueprintsT1Sea = {}
ScavengerBlueprintsT2Sea = {}
ScavengerBlueprintsT3Sea = {}

ScavengerConstructorBlueprintsStart = {}
ScavengerConstructorBlueprintsT1 = {}
ScavengerConstructorBlueprintsT2 = {}
ScavengerConstructorBlueprintsT3 = {}
ScavengerConstructorBlueprintsStartSea = {}
ScavengerConstructorBlueprintsT1Sea = {}
ScavengerConstructorBlueprintsT2Sea = {}
ScavengerConstructorBlueprintsT3Sea = {}

ConfigsList = VFS.DirList('luarules/configs/ScavengerBlueprints/','*.lua')
for i = 1,#ConfigsList do
	VFS.Include(ConfigsList[i])
	Spring.Echo("Scav Blueprints Directory: " ..ConfigsList[i])
end

ConfigsList2 = VFS.DirList('luarules/configs/ScavengerBlueprints/Constructor/','*.lua')
for i = 1,#ConfigsList2 do
	VFS.Include(ConfigsList2[i])
	Spring.Echo("Scav Constructor Blueprints Directory: " ..ConfigsList2[i])
end

------------------------------------------------------------------------

local GaiaTeamID  = Spring.GetGaiaTeamID()
local _,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)
local teamcount = #Spring.GetTeamList() - 2
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ
local deathwater = Game.waterDamage
local spawnmultiplier = tonumber(Spring.GetModOptions().scavengers) or 1
if devswitch == 1 then
	spawnmultiplier = 1
end
local failcounter = 0

local nameSuffix = '_scav'

local T1KbotUnits = {"corak", "corcrash", "cornecro", "corstorm", "corthud", "armham", "armjeth", "armpw", "armrectr", "armrock", "armwar",}
local T2KbotUnits = {"coraak", "coramph", "corcan", "corhrk", "cormando", "cormort", "corpyro", "corroach", "corsktl", "corsumo", "cortermite", "armaak", "armamph", "armfast", "armfboy", "armfido", "armmav", "armsnipe", "armspid", "armsptk", "armvader", "armzeus",}

local T1TankUnits = {"corgarp", "corgator", "corlevlr", "cormist", "corraid", "corwolv", "armart", "armflash", "armjanus", "armpincer", "armsam", "armstump",}
local T2TankUnits = {"corban", "corgol", "cormart", "corparrow", "correap", "corseal", "corsent", "cortrem", "corvroc", "armbull", "armcroc", "armlatnk", "armmanni", "armmart", "armmerl", "armst", "armyork",}

local T1SeaUnits = {"coresupp", "corpship", "corpt", "correcl", "corroy", "corsub", "corgarp", "armdecade", "armpship", "armpt", "armrecl", "armroy", "armsub","armpincer",}
local Hovercrafts = {"corah", "corhal", "cormh", "corsh", "corsnap", "armah", "armanac", "armmh", "armsh", }
local T2SeaUnits = {"corarch", "corcrus", "corshark", "armcrus", "armsubk", "coraak", "coramph", "corroach", "corsktl", "armaak", "armamph", "armvader", "corparrow", "corseal", "armcroc",}

local T1AirUnits = {"corbw", "corshad", "corveng", "armfig", "armkam", "armthund",}
local Seaplanes = {"corcut", "corhunt", "corsb", "corsfig", "armsaber", "armsb", "armsehak", "armsfig",}
local T2AirUnits = {"corape", "corcrw", "corhurc", "corvamp", "armblade", "armbrawl", "armhawk", "armliche", "armpnix", "armstil",}

local Tech3Units = {"corcat", "corjugg", "corkarg", "corkrog", "corshiva", "armbanth", "armmar", "armraz", "armvang",}
local Tech3Sea = {"armepoch", "corblackhy", "corbats", "cormship", "armbats", "armmship",}

--local T1LandBuildings = {"armllt", "corllt"}
--local T2LandBuildings = {}
--local T3LandBuildings = {}

--local T1SeaBuildings = {}
--local T2SeaBuildings = {}
--local T3SeaBuildings = {}

--local timer = Spring.GetGameSeconds()

local dx = {}
local dy = {}
local dz = {}
local olddx = {}
local olddy = {}
local olddz = {}
local selfdestructcounter = 0
local posx = 0
local posy = 0
local posz = 0
local posradius = 0
local canSpawnHere = false
local canBuildHere = false
local blueprint = 0
local radiusCheck = false
local commandertimer = 0
local commanderlimit = #Spring.GetAllyTeamList()



------------------------------------------------------------------------

function gadget:Initialize()
	-- local mo = Spring.GetModOptions()
	-- if mo and tonumber(mo.scavengers)==0 then
		-- Spring.Echo("[scavengers] Disabled via ModOption")
		-- gadgetHandler:RemoveGadget(self)
	-- end



end

local function posCheck(posx, posy, posz, posradius)
	-- if true then can spawn
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )
	if deathwater > 0 and posy <= 0 then
		return false
	elseif testpos1 < posy - 30 or testpos1 > posy + 30 then
		return false
	elseif testpos2 < posy - 30 or testpos2 > posy + 30 then
		return false
	elseif testpos3 < posy - 30 or testpos3 > posy + 30 then
		return false
	elseif testpos4 < posy - 30 or testpos4 > posy + 30 then
		return false
	elseif testpos5 < posy - 30 or testpos5 > posy + 30 then
		return false
	elseif testpos6 < posy - 30 or testpos6 > posy + 30 then
		return false
	elseif testpos7 < posy - 30 or testpos7 > posy + 30 then
		return false
	elseif testpos8 < posy - 30 or testpos8 > posy + 30 then
		return false
	else
		return true
	end
end

local function posOccupied(posx, posy, posz, posradius)
	-- if true then can spawn
	local unitcount = #Spring.GetUnitsInRectangle(posx-posradius, posz-posradius, posx+posradius, posz+posradius)
	if unitcount > 0 then
		return false
	else
		return true
	end
end

local function posLosCheck(posx, posy, posz, posradius)
	-- if true then can spawn
	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= GaiaAllyTeamID then
			if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInRadar(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz - posradius, allyTeamID) == true then
				return false
			end
		end
	end
	return true
end

--local function buildBlueprint(blueprint)
	--blueprint
--end

function OldSpawnGadgetCrap(n)
	if n == 100 then
		Spring.Echo("Scavenger Spawner initialized")
		Spring.SetTeamResource(GaiaTeamID, "ms", 100000)
		Spring.SetTeamResource(GaiaTeamID, "es", 100000)
		Spring.SetGlobalLos(GaiaAllyTeamID, false)
	end
	if n%300 == 0 then
		Spring.SetTeamResource(GaiaTeamID, "ms", 100000)
		Spring.SetTeamResource(GaiaTeamID, "es", 100000)
		Spring.SetTeamResource(GaiaTeamID, "m", 100000)
		Spring.SetTeamResource(GaiaTeamID, "e", 100000)
	end
	if n%90 == 0 and n > 3000 then
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		local spawnchance = math.random(0,60)
		if spawnchance == 0 or canBuildHere == false then
			posx = math.random(200,mapsizeX-200)
			posz = math.random(200,mapsizeZ-200)
			posy = Spring.GetGroundHeight(posx, posz)
			--blueprint = ScavengerBlueprintsStart[math.random(1,#ScavengerBlueprintsStart)]
			if posy > 0 then
				if n > 60000 then
					local r = math.random(0,1)
					if r == 0 then
						blueprint = ScavengerBlueprintsT3[math.random(1,#ScavengerBlueprintsT3)]
					else
						blueprint = ScavengerBlueprintsT2[math.random(1,#ScavengerBlueprintsT2)]
					end
				elseif n > 39000 then
					local r = math.random(0,2)
					if r == 0 then
						blueprint = ScavengerBlueprintsT2[math.random(1,#ScavengerBlueprintsT2)]
					elseif r == 1 then
						blueprint = ScavengerBlueprintsT1[math.random(1,#ScavengerBlueprintsT1)]
					else
						blueprint = ScavengerBlueprintsStart[math.random(1,#ScavengerBlueprintsStart)]
					end
				elseif n > 18000 then
					local r = math.random(0,1)
					if r == 0 then
						blueprint = ScavengerBlueprintsT1[math.random(1,#ScavengerBlueprintsT1)]
					else
						blueprint = ScavengerBlueprintsStart[math.random(1,#ScavengerBlueprintsStart)]
					end
				else
					blueprint = ScavengerBlueprintsStart[math.random(1,#ScavengerBlueprintsStart)]
				end
			elseif posy <= 0 then	
				if n > 60000 then
					local r = math.random(0,3)
					if r == 0 then
						blueprint = ScavengerBlueprintsT3Sea[math.random(1,#ScavengerBlueprintsT3Sea)]
					elseif r == 1 then
						blueprint = ScavengerBlueprintsT2Sea[math.random(1,#ScavengerBlueprintsT2Sea)]
					elseif r == 2 then
						blueprint = ScavengerBlueprintsT1Sea[math.random(1,#ScavengerBlueprintsT1Sea)]
					else
						blueprint = ScavengerBlueprintsStartSea[math.random(1,#ScavengerBlueprintsStartSea)]
					end
				elseif n > 39000 then
					local r = math.random(0,2)
					if r == 0 then
						blueprint = ScavengerBlueprintsT2Sea[math.random(1,#ScavengerBlueprintsT2Sea)]
					elseif r == 1 then
						blueprint = ScavengerBlueprintsT1Sea[math.random(1,#ScavengerBlueprintsT1Sea)]
					else
						blueprint = ScavengerBlueprintsStartSea[math.random(1,#ScavengerBlueprintsStartSea)]
					end
				elseif n > 18000 then
					local r = math.random(0,1)
					if r == 0 then
						blueprint = ScavengerBlueprintsT1Sea[math.random(1,#ScavengerBlueprintsT1Sea)]
					else
						blueprint = ScavengerBlueprintsStartSea[math.random(1,#ScavengerBlueprintsStartSea)]
					end
				else
					blueprint = ScavengerBlueprintsStartSea[math.random(1,#ScavengerBlueprintsStartSea)]
				end	
			end
			posradius = blueprint(posx, posy, posz, GaiaTeamID, true)
			canBuildHere = posLosCheck(posx, posy, posz, posradius)
			if canBuildHere then
				canBuildHere = posOccupied(posx, posy, posz, posradius)
			end
			if canBuildHere then
				canBuildHere = posCheck(posx, posy, posz, posradius)
			end
		
			if canBuildHere then
				-- let's do this shit
				blueprint(posx, posy, posz, GaiaTeamID, false)
			end
		end
	end
		
	if n%30 == 0 and n > 9000 then
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		local spawnchance = math.random(0,math.ceil((((gaiaUnitCount)/teamcount)+2)*(#Spring.GetAllyTeamList() - 1)/spawnmultiplier))
		--local spawnchance = 1 -- dev purpose
		if spawnchance == 0 or canSpawnHere == false then
			-- check positions
			local posx = math.random(300,mapsizeX-300)
			local posz = math.random(300,mapsizeZ-300)
			local posy = Spring.GetGroundHeight(posx, posz)
			-- minimum size needed for succesful spawn
			local posradius = 100
			canSpawnHere = posCheck(posx, posy, posz, posradius)
			if canSpawnHere then
				canSpawnHere = posLosCheck(posx, posy, posz,posradius)
			end
			if canSpawnHere then
				canSpawnHere = posOccupied(posx, posy, posz, posradius)
			end
			--spawn units
			if canSpawnHere then
				local groupsize = (((n)+#Spring.GetAllUnits())*spawnmultiplier*teamcount)/(#Spring.GetAllyTeamList())
				local airrng = math.random(0,5)
				local kbottankrng = math.random(0,1)
				if commanderlimit > Spring.GetTeamUnitDefCount(GaiaTeamID, UnitDefNames.armcom_scav.id) + Spring.GetTeamUnitDefCount(GaiaTeamID, UnitDefNames.corcom_scav.id) then
					local r = math.random(0,1)
					if r == 0 then
						Spring.CreateUnit("armcom"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
					else
						Spring.CreateUnit("corcom"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
					end
				end
				
				if airrng == 0 then
					--Spring.CreateUnit("corca"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
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
						Spring.CreateUnit(spawnair..nameSuffix, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
					end
					if devswitch == 1 then
						Spring.Echo("Spawned Scavenger group: " ..groupsize.. " " ..UnitDefNames[spawnair].humanName.. "s")
					end
				elseif posy > -10 then
					Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
					Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
					if kbottankrng == 0 then
						
						if Spring.GetGameSeconds() < 1200 then
							spawnkbot = T1KbotUnits[math.random(1,#T1KbotUnits)]
						else
							local r = math.random(0,2)
							if r == 0 then
								spawnkbot = T1KbotUnits[math.random(1,#T1KbotUnits)]
								groupsize = groupsize*1.3
								Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
							else
								spawnkbot = T2KbotUnits[math.random(1,#T2KbotUnits)]
								groupsize = groupsize*1.6
								Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
								Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
							end
						end
						
						local cost = UnitDefNames[spawnkbot].metalCost + UnitDefNames[spawnkbot].energyCost
						local groupsize = math.ceil(groupsize/cost)
						for i=1, groupsize do
							Spring.CreateUnit(spawnkbot..nameSuffix, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
						end
						if devswitch == 1 then
							Spring.Echo("Spawned Scavenger group: " ..groupsize.. " " ..UnitDefNames[spawnkbot].humanName.. "s")
						end
					else
						if Spring.GetGameSeconds() < 600 then
							spawntank = T1TankUnits[math.random(1,#T1TankUnits)]
						elseif Spring.GetGameSeconds() >= 600 and Spring.GetGameSeconds() < 1200 then
							local r = math.random(0,3)
							if r == 0 then
								spawntank = Hovercrafts[math.random(1,#Hovercrafts)]
								groupsize = groupsize*1.3
								Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
							else
								spawntank = T1TankUnits[math.random(1,#T1TankUnits)]
							end
						elseif Spring.GetGameSeconds() >= 1200 then
							local r = math.random(0,3)
							if r == 0 then
								spawntank = Hovercrafts[math.random(1,#Hovercrafts)]
								groupsize = groupsize*1.4
								Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
							elseif r == 1 then
								spawntank = T1TankUnits[math.random(1,#T1TankUnits)]
								groupsize = groupsize*1.3
								Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
							else
								spawntank = T2TankUnits[math.random(1,#T2TankUnits)]
								groupsize = groupsize*1.6
								Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
								Spring.CreateUnit("cornecro"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
							end
						end
						
						local cost = UnitDefNames[spawntank].metalCost + UnitDefNames[spawntank].energyCost
						local groupsize = math.ceil(groupsize/cost)
						for i=1, groupsize do
							Spring.CreateUnit(spawntank..nameSuffix, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
						end
						if devswitch == 1 then
							Spring.Echo("Spawned Scavenger group: " ..groupsize.. " " ..UnitDefNames[spawntank].humanName.. "s")
						end
					end
					local t3random = math.random(0,5)
					if Spring.GetGameSeconds() > 2400 and t3random == 0 then
						spawnT3 = Tech3Units[math.random(1,#Tech3Units)]
						Spring.CreateUnit(spawnT3..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
					end
				else
					--Spring.CreateUnit("corcsa"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
					if Spring.GetGameSeconds() < 600 then
						spawnsea = T1SeaUnits[math.random(1,#T1SeaUnits)]
						spawnair = T1AirUnits[math.random(1,#T1AirUnits)]
					elseif Spring.GetGameSeconds() >= 600 and Spring.GetGameSeconds() < 1200 then
						local r = math.random(0,3)
						if r == 0 then
							spawnsea = Hovercrafts[math.random(1,#Hovercrafts)]
							spawnair = T1AirUnits[math.random(1,#T1AirUnits)]
						else
							spawnsea = T1SeaUnits[math.random(1,#T1SeaUnits)]
							spawnair = T1AirUnits[math.random(1,#T1AirUnits)]
						end
					elseif Spring.GetGameSeconds() >= 1200 then
						local r = math.random(0,3)
						if r == 0 then
							spawnsea = Hovercrafts[math.random(1,#Hovercrafts)]
							spawnair = Seaplanes[math.random(1,#Seaplanes)]
						elseif r == 1 then
							spawnsea = T1SeaUnits[math.random(1,#T1SeaUnits)]
							spawnair = Seaplanes[math.random(1,#Seaplanes)]
						else
							spawnsea = T2SeaUnits[math.random(1,#T2SeaUnits)]
							spawnair = Seaplanes[math.random(1,#Seaplanes)]
						end
					end
					local t3random = math.random(0,5)
					if Spring.GetGameSeconds() > 2400 and t3random == 0 then
						spawnT3 = Tech3Sea[math.random(1,#Tech3Sea)]
						Spring.CreateUnit(spawnT3..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
					end
					
					local cost = (UnitDefNames[spawnsea].metalCost + UnitDefNames[spawnsea].energyCost + UnitDefNames[spawnair].metalCost + UnitDefNames[spawnair].energyCost)/2 
					local groupsize = math.ceil(groupsize/cost)
					for i=1, groupsize do
						local r = math.random(0,1)
						if r == 0 then
							Spring.CreateUnit(spawnsea..nameSuffix, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
						elseif r == 1 then
							Spring.CreateUnit(spawnair..nameSuffix, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
						end
					end
					if devswitch == 1 then
						Spring.Echo("Spawned Scavenger group: "..groupsize.." "..UnitDefNames[spawnsea].humanName.."s and/or "..UnitDefNames[spawnair].humanName.. "s")
					end
				end
			end
		end
		--move idle units
		local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
		if scavengerunits then
			for i = 1,#scavengerunits do
				local scav = scavengerunits[i]
				local scavDef = Spring.GetUnitDefID(scav)
				local scavStructure = UnitDefs[scavDef].isBuilding
				if UnitDefs[scavDef].name == "cormaw"..nameSuffix or UnitDefs[scavDef].name == "armclaw"..nameSuffix or UnitDefs[scavDef].name == "cornanotc"..nameSuffix or UnitDefs[scavDef].name == "armnanotc"..nameSuffix or UnitDefs[scavDef].name == "armcom"..nameSuffix or UnitDefs[scavDef].name == "corcom"..nameSuffix then
                    scavStructure = true
                end
				if not scavStructure and n%900 == 0 then
					if dx[scav] then
						olddx[scav] = dx[scav]
					end
					if dy[scav] then
						olddy[scav] = dy[scav]
					end
					if dz[scav] then
						olddz[scav] = dz[scav]
					end
					dx[scav],dy[scav],dz[scav] = Spring.GetUnitPosition(scav)
					if (olddx[scav] and olddy[scav] and olddz[scav]) and (olddx[scav] > dx[scav]-10 and olddx[scav] < dx[scav]+10) and (olddy[scav] > dy[scav]-10 and olddy[scav] < dy[scav]+10) and (olddz[scav] > dz[scav]-10 and olddz[scav] < dz[scav]+10) then
						Spring.DestroyUnit(scav, true, false)
						selfdestructcounter = selfdestructcounter + 1
					end
				end
				if (not scavStructure and Spring.GetCommandQueue(scav, 0) <= 1) or (string.find(UnitDefs[scavDef].name, "com_scav") and Spring.GetCommandQueue(scav, 0) <= 1) then
						
						if string.find(UnitDefs[scavDef].name,"com_scav") then
							local x,y,z = Spring.GetUnitPosition(scav)
							local posx = math.random(x-1000,x+1000)
							local posz = math.random(z-1000,z+1000)
							local posy = Spring.GetGroundHeight(posx, posz)
							if posy > 0 then
								if n > 50000 then
									local r = math.random(0,1)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT3[math.random(1,#ScavengerConstructorBlueprintsT3)]
									else
										blueprint = ScavengerConstructorBlueprintsT2[math.random(1,#ScavengerConstructorBlueprintsT2)]
									end
								elseif n > 36000 then
									local r = math.random(0,2)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT2[math.random(1,#ScavengerConstructorBlueprintsT2)]
									elseif r == 1 then
										blueprint = ScavengerConstructorBlueprintsT1[math.random(1,#ScavengerConstructorBlueprintsT1)]
									else
										blueprint = ScavengerConstructorBlueprintsStart[math.random(1,#ScavengerConstructorBlueprintsStart)]
									end
								elseif n > 18000 then
									local r = math.random(0,1)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT1[math.random(1,#ScavengerConstructorBlueprintsT1)]
									else
										blueprint = ScavengerConstructorBlueprintsStart[math.random(1,#ScavengerConstructorBlueprintsStart)]
									end
								else
									blueprint = ScavengerConstructorBlueprintsStart[math.random(1,#ScavengerConstructorBlueprintsStart)]
								end
							elseif posy <= 0 then	
								if n > 60000 then
									local r = math.random(0,3)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT3Sea[math.random(1,#ScavengerConstructorBlueprintsT3Sea)]
									elseif r == 1 then
										blueprint = ScavengerConstructorBlueprintsT2Sea[math.random(1,#ScavengerConstructorBlueprintsT2Sea)]
									elseif r == 2 then
										blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
									else
										blueprint = ScavengerConstructorBlueprintsStartSea[math.random(1,#ScavengerConstructorBlueprintsStartSea)]
									end
								elseif n > 39000 then
									local r = math.random(0,2)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT2Sea[math.random(1,#ScavengerConstructorBlueprintsT2Sea)]
									elseif r == 1 then
										blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
									else
										blueprint = ScavengerConstructorBlueprintsStartSea[math.random(1,#ScavengerConstructorBlueprintsStartSea)]
									end
								elseif n > 18000 then
									local r = math.random(0,1)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
									else
										blueprint = ScavengerConstructorBlueprintsStartSea[math.random(1,#ScavengerConstructorBlueprintsStartSea)]
									end
								else
									blueprint = ScavengerConstructorBlueprintsStartSea[math.random(1,#ScavengerConstructorBlueprintsStartSea)]
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
						else
							local nearest = Spring.GetUnitNearestEnemy(scav, 200000, false)
							local x,y,z = Spring.GetUnitPosition(nearest)
							local x = x + math.random(-50,50)
							local z = z + math.random(-50,50)
							Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
						end
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

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if unitTeam == GaiaTeamID then
    	-- CMD.CLOAK = 37382
        Spring.GiveOrderToUnit(unitID,37382,{1},{""})
        -- Fire At Will
        Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},{""})
		if UnitDefs[unitDefID].name == "scavcommander" then
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},{""})
		end
    end
end