function gadget:GetInfo()
  return {
    name      = "gaia civilian unit spawner",
    desc      = "units spawn and wander around the map",
    author    = "Damgam, some code from critters by Floris",
    date      = "2019",
    layer     = -100,
    enabled   = true,
	}
end

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end


------------------------------------------------------------------------

local GaiaTeamID  = Spring.GetGaiaTeamID()
local teamcount = #Spring.GetTeamList() - 2
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ
local spawnmultiplier = Spring.GetModOptions().civilians or 1

local T1LandUnits = {"corak", "corcrash", "cornecro", "corstorm", "corthud",}
local T2LandUnits = {}
local T3LandUnits = {}

local T1SeaUnits = {"coresupp", "corpship", "corpt", "correcl", "corroy", "corsub",}
local T2SeaUnits = {}
local T3SeaUnits = {}

local T1LandBuildings = {}
local T2LandBuildings = {}
local T3LandBuildings = {}

local timer = Spring.GetGameSeconds()




------------------------------------------------------------------------

function gadget:Initialize()

	local mo = Spring.GetModOptions()
	if mo and tonumber(mo.civilians)==0 then
		Spring.Echo("[Civilians] Disabled via ModOption")
		gadgetHandler:RemoveGadget(self)
	end

end

function gadget:GameFrame(n)
	if n%30 == 0 and n > 9000 then
		local spawnchance = math.random(1,60)
		--local spawnchance = 1 -- dev purpose
		if spawnchance == 1 or failedspawn then
			failedspawn = false
			-- check positions
			local posx = math.random(50,mapsizeX-50)
			local posz = math.random(50,mapsizeZ-50)
			local posy = Spring.GetGroundHeight(posx, posz)
			
			local testpos1 = Spring.GetGroundHeight(posx + math.random(-50,50), posz + math.random(-50,50))
			Spring.Echo(testpos1)
			local testpos2 = Spring.GetGroundHeight(posx + math.random(-50,50), posz + math.random(-50,50))
			local testpos3 = Spring.GetGroundHeight(posx + math.random(-50,50), posz + math.random(-50,50))
			local testpos4 = Spring.GetGroundHeight(posx + math.random(-50,50), posz + math.random(-50,50))
			if testpos1 < posy - 30 or testpos1 > posy + 30 then
				failedspawn = true
			elseif testpos2 < posy - 30 or testpos2 > posy + 30 then
				failedspawn = true
			elseif testpos3 < posy - 30 or testpos3 > posy + 30 then
				failedspawn = true
			elseif testpos4 < posy - 30 or testpos4 > posy + 30 then
				failedspawn = true
			end
			
			if not failedspawn then	
				for i = 0,teamcount do
					if Spring.IsPosInLos(posx, posy, posz, i) == true then
						failedspawn = true
						break
					elseif Spring.IsPosInRadar(posx, posy, posz, i) == true then
						failedspawn = true
						break
					elseif Spring.IsPosInAirLos(posx, posy, posz, i) == true then
						failedspawn = true
						break
					else
						failedspawn = false
					end
				end
			end
			
			--spawn units
			if not failedspawn then
				local landspawn = math.random(1,#T1LandUnits)
				local seaspawn = math.random(1,#T1SeaUnits)
				local posx = posx + math.random(-50,50)
				local posz = posz + math.random(-50,50)
				local posy = Spring.GetGroundHeight(posx, posz) 
				local groupsize = math.ceil((n/3600)*spawnmultiplier)
				local spawnland = T1LandUnits[landspawn]
				local spawnsea = T1SeaUnits[seaspawn]
				if posy > 10 then
					for i = 1,groupsize do
						Spring.CreateUnit(spawnland, posx, posy, posz, math.random(0,3),GaiaTeamID)
					end
				else
					for i = 1,math.ceil(groupsize/10) do
						Spring.CreateUnit(spawnsea, posx, posy, posz, math.random(0,3),GaiaTeamID)
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









































