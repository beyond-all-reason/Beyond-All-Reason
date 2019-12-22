function gadget:GetInfo()
  return {
    name      = "gaia civilian unit spawner",
    desc      = "units spawn and wander around the map",
    author    = "Damgam",
    date      = "2019",
    layer     = -100,
    enabled   = true,
	}
end

local devswitch = 1
if (Spring.GetModOptions() == nil or Spring.GetModOptions().civilians == nil or Spring.GetModOptions().civilians == 0) and devswitch == 0 then
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
local spawnmultiplier = Spring.GetModOptions().civilians or 1
if devswitch == 1 then
	spawnmultiplier = 1
end

local T1KbotUnits = {"corak", "corcrash", "cornecro", "corstorm", "corthud", "armflea", "armham", "armjeth", "armpw", "armrectr", "armrock", "armwar",}
local T2KbotUnits = {}
local T3KbotUnits = {}

local T1TankUnits = { "corfav", "corgarp", "corgator", "corlevlr", "cormist", "corraid", "corwolv", "armart", "armfav", "armflash", "armjanus", "armpincer", "armsam", "armstump",}
local T2TankUnits = {}
local T3TankUnits = {}

local T1SeaUnits = {"coresupp", "corpship", "corpt", "correcl", "corroy", "corsub", "corgarp", "armdecade", "armpship", "armpt", "armrecl", "armroy", "armsub","armpincer",}
local T2SeaUnits = {}
local T3SeaUnits = {}

local T1AirUnits = {"corbw", "corshad", "corveng", "armfig", "armkam", "armthund",}
local T2AirUnits = {}
local T3AirUnits = {}

local T1LandBuildings = {}
local T2LandBuildings = {}
local T3LandBuildings = {}

local T1SeaBuildings = {}
local T2SeaBuildings = {}
local T3SeaBuildings = {}

local timer = Spring.GetGameSeconds()




------------------------------------------------------------------------

function gadget:Initialize()

	-- local mo = Spring.GetModOptions()
	-- if mo and tonumber(mo.civilians)==0 then
		-- Spring.Echo("[Civilians] Disabled via ModOption")
		-- gadgetHandler:RemoveGadget(self)
	-- end

end

function gadget:GameFrame(n)
	if n%10 == 0 and n > 9000 then
		Spring.SetTeamColor(GaiaTeamID, math.random(0,255)/255, math.random(0,255)/255, math.random(0,255)/255)
	end
	if n%30 == 0 and n > 9000 then
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
						if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true then
							failedspawn = true
							break
						elseif Spring.IsPosInRadar(posx, posy, posz, allyTeamID) == true then
							failedspawn = true
							break
						elseif Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true then
							failedspawn = true
							break
						else
							failedspawn = false
						end
					end
				end
			end
			
			--spawn units
			if not failedspawn then
				local groupsize = (n/5)*spawnmultiplier*teamcount
				local spawnkbot = T1KbotUnits[math.random(1,#T1KbotUnits)]
				local spawntank = T1TankUnits[math.random(1,#T1TankUnits)]
				local spawnsea = T1SeaUnits[math.random(1,#T1SeaUnits)]
				local spawnair = T1AirUnits[math.random(1,#T1AirUnits)]
				local airrng = math.random(0,5)
				--local turretrng = math.random(0,5)
				local kbottankrng = math.random(0,1)
				if airrng == 0 then
					local cost = UnitDefNames[spawnair].metalCost + UnitDefNames[spawnair].energyCost
					local groupsize = math.ceil(groupsize/cost)
					for i = 1,groupsize do
						Spring.CreateUnit(spawnair, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
					end
				elseif posy > 10 then
					if kbottankrng == 0 then
						local cost = UnitDefNames[spawnkbot].metalCost + UnitDefNames[spawnkbot].energyCost
						local groupsize = math.ceil(groupsize/cost)
						for i = 1,groupsize do
							Spring.CreateUnit(spawnkbot, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
						end
					else
						local cost = UnitDefNames[spawntank].metalCost + UnitDefNames[spawntank].energyCost
						local groupsize = math.ceil(groupsize/cost)
						for i = 1,math.ceil(groupsize) do
							Spring.CreateUnit(spawntank, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
						end
					end
				else
					local cost = UnitDefNames[spawnsea].metalCost + UnitDefNames[spawnsea].energyCost
					local groupsize = math.ceil(groupsize/cost)
					for i = 1,math.ceilgroupsize do
						Spring.CreateUnit(spawnsea, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
					end
				end
			end
		end
		--move idle units
		local civilianunits = Spring.GetTeamUnits(GaiaTeamID)
		if civilianunits then
			for i = 1,#civilianunits do
				local givemeorder = civilianunits[i]
				if n%360 == 0 then
					-- placeholder for surrending part
				end
				if Spring.GetCommandQueue(givemeorder, 0) <= 1 then
					local nearest = Spring.GetUnitNearestEnemy(givemeorder, 200000, false)
					local x,y,z = Spring.GetUnitPosition(nearest)
					local x = x + math.random(-50,50)
					local z = z + math.random(-50,50)
					Spring.GiveOrderToUnit(givemeorder, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
				end
			end
		end
	end
end









































