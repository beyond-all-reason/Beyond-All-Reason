-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------Locals ---------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Fog of War check needed for some functions
local noFogOfWar = false
if Spring.GetModOptions().disable_fogofwar then
	noFogOfWar = true
end

-- GaiaTeamID and GaiaAllyTeamID
local GaiaTeamID = Spring.GetGaiaTeamID()
local _,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)

-- Map size
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

-- Get TeamIDs and AllyTeamIDs of Scavengers and Chickens
local teams = Spring.GetTeamList()
local scavengerTeamID
local scavengerAllyTeamID
local chickenTeamID
local chickenAllyTeamID
if Spring.Utilities.Gametype.IsScavengers() or Spring.Utilities.Gametype.IsChickens() then
    local teams = Spring.GetTeamList()
    for i = 1,#teams do
        local luaAI = Spring.GetTeamLuaAI(teams[i])
        if not scavengerTeamID then
            if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
                scavengerTeamID = i - 1
                _,_,_,_,_,scavengerAllyTeamID = Spring.GetTeamInfo(scavengerTeamID)
            end
        end
        if not chickenTeamID then
            if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ChickensAI' then
                chickenTeamID = i - 1
                _,_,_,_,_,chickenAllyTeamID = Spring.GetTeamInfo(chickenTeamID)
            end
        end
    end
end

-- Team Startboxes
local AllyTeamStartboxes = {}
for _,testAllyTeamID in ipairs(Spring.GetAllyTeamList()) do
    local allyTeamHasStartbox = true
    local xMin, zMin, xMax, zMax = Spring.GetAllyTeamStartBox(testAllyTeamID)
    if xMin == 0 and zMin == 0 and xMax == mapSizeX and zMax == mapSizeZ then
        allyTeamHasStartbox = false
    end
    AllyTeamStartboxes[testAllyTeamID+1] = { -- Lua Tables start at 1, AllyTeamID's start at 0, so we have to add 1 everytime
        allyTeamHasStartbox = allyTeamHasStartbox,
        xMin = xMin,
        zMin = zMin,
        xMax = xMax,
        zMax = zMax,
    }
end





-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------- Position Check functions --------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function FlatAreaCheck(posx, posy, posz, posradius, heightTollerance, checkWater) -- Returns true if position is flat enough.
	-- nil fixes
    local posradius = posradius or 1000
    local heightTollerance = heightTollerance or 30
    local deathwater = Game.waterDamage

    -- Check height of test points in all 8 directions.
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )

    -- Compare with original height
    if (not checkWater) and (not deathwater or deathwater == 0) and posy <= 0 then return true end -- Is water, Not Deathwater, No water bottom check. 
	if deathwater > 0 and posy <= 0 then return false end -- Is water, Deathwater
	if testpos1 < posy - heightTollerance or testpos1 > posy + heightTollerance then return false end
    if testpos2 < posy - heightTollerance or testpos2 > posy + heightTollerance then return false end
	if testpos3 < posy - heightTollerance or testpos3 > posy + heightTollerance then return false end
    if testpos4 < posy - heightTollerance or testpos4 > posy + heightTollerance then return false end
    if testpos5 < posy - heightTollerance or testpos5 > posy + heightTollerance then return false end
    if testpos6 < posy - heightTollerance or testpos6 > posy + heightTollerance then return false end
    if testpos7 < posy - heightTollerance or testpos7 > posy + heightTollerance then return false end
    if testpos8 < posy - heightTollerance or testpos8 > posy + heightTollerance then return false end
    
    return true -- Nothing failed, so position is safe

end

local function OccupancyCheck(posx, posy, posz, posradius) -- Returns true if there are no units in the spawn area
	local posradius = posradius or 1000
	local unitcount = #Spring.GetUnitsInRectangle(posx-posradius, posz-posradius, posx+posradius, posz+posradius)
	if unitcount > 0 then
		return false
	else
		return true
	end
end

local function VisibilityCheck(posx, posy, posz, posradius, allyTeamID, checkLoS, checkAirLos, checkRadar) -- Return True when position is not in sensor ranges of specified allyTeam.

	local posradius = posradius or 1000
	if noFogOfWar then
		return OccupancyCheck(posx, posy, posz, posradius*4)
	end
        
    if checkLoS and (
        Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
        Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
        Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
        Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
        Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true) then
        return false
    end
    
    if checkRadar and (
        Spring.IsPosInRadar(posx, posy, posz, allyTeamID) == true or
        Spring.IsPosInRadar(posx + posradius, posy, posz + posradius, allyTeamID) == true or
        Spring.IsPosInRadar(posx + posradius, posy, posz - posradius, allyTeamID) == true or
        Spring.IsPosInRadar(posx - posradius, posy, posz + posradius, allyTeamID) == true or
        Spring.IsPosInRadar(posx - posradius, posy, posz - posradius, allyTeamID) == true) then
        return false
    end

    if checkAirLos and (
        Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true or
        Spring.IsPosInAirLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
        Spring.IsPosInAirLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
        Spring.IsPosInAirLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
        Spring.IsPosInAirLos(posx - posradius, posy, posz - posradius, allyTeamID) == true) then
        return false
    end

	return true
end

local function VisibilityCheckEnemy(posx, posy, posz, posradius, allyTeamID, checkLoS, checkAirLos, checkRadar) -- Return True when position is not in sensor ranges of all enemies of specified allyTeam.
    for _,testAllyTeamID in ipairs(Spring.GetAllyTeamList()) do
		local posCheck = true
        if testAllyTeamID ~= allyTeamID and testAllyTeamID ~= GaiaAllyTeamID then
            posCheck = VisibilityCheck(posx, posy, posz, posradius, testAllyTeamID, checkLoS, checkAirLos, checkRadar)
        end
        if posCheck == false then
            return false
        end
    end
    return true
end

local function StartboxCheck(posx, posy, posz, posradius, allyTeamID, returnTrueWhenNoStartbox) -- Return True when position is within startbox.
    local posradius = posradius or 1000

    if AllyTeamStartboxes[allyTeamID+1].allyTeamHasStartbox == false then
        if returnTrueWhenNoStartbox then
            return true
        else
            return false
        end
    end

    if posx >= AllyTeamStartboxes[allyTeamID+1].xMin and posz >= AllyTeamStartboxes[allyTeamID+1].zMin and posx <= AllyTeamStartboxes[allyTeamID+1].xMax and posz <= AllyTeamStartboxes[allyTeamID+1].zMax then -- Lua Tables start at 1, AllyTeamID's start at 0, so we have to add 1 everytime
        return true
    else
        return false
    end
end

local function MapEdgeCheck(posx, posy, posz, posradius) -- if true then position is far enough from map border
	local posradius = posradius or 1000
	if posx + posradius >= mapSizeX or posx - posradius <= 0 or posz - posradius <= 0 or posz + posradius >= mapSizeZ then
		return false
	else
		return true
	end
end

local function SurfaceCheck(posx, posy, posz, posradius, sea) -- if true then position is safe for either Land or Sea units.
    local posradius = posradius or 1000
	local testpos0 = Spring.GetGroundHeight((posx), (posz))
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )
	local deathwater = Game.waterDamage

    if not sea then -- Test for land units
        if testpos0 <= 0 then return false end
        if testpos1 <= 0 then return false end
        if testpos2 <= 0 then return false end
        if testpos3 <= 0 then return false end
        if testpos4 <= 0 then return false end
        if testpos5 <= 0 then return false end
        if testpos6 <= 0 then return false end
        if testpos7 <= 0 then return false end
        if testpos8 <= 0 then return false end
    else -- Test for sea units
        if testpos0 > 0 then return false end
        if testpos1 > 0 then return false end
        if testpos2 > 0 then return false end
        if testpos3 > 0 then return false end
        if testpos4 > 0 then return false end
        if testpos5 > 0 then return false end
        if testpos6 > 0 then return false end
        if testpos7 > 0 then return false end
        if testpos8 > 0 then return false end
    end

    return true -- nothing failed, so it's good.
end

local function ScavengerSpawnAreaCheck(posx, posy, posz, posradius) -- if true then position is within Scavengers spawn area.
    if scavengerAllyTeamID then
        local scavTechPercentage = Spring.GetGameRulesParam("scavStatsTechPercentage")
        if scavTechPercentage then
            if Spring.GetModOptions().scavspawnarea == true then
                if not AllyTeamStartboxes[scavengerAllyTeamID].allyTeamHasStartbox then return true end -- Scavs do not have a startbox so we allow them to spawn anywhere
                if StartboxCheck(posx, posy, posz, posradius, scavengerAllyTeamID) == true then return true end -- Area is within startbox, so it's for sure in the spawn box.
                
                -- Spawn Box grows with Scavengers tech, getting that into from GameRulesParameter set by Scav gadget
                local SpawnBoxMinX = math.floor(ScavengerStartboxXMin-(((mapSizeX)*0.01)*scavTechPercentage))
                local SpawnBoxMaxX = math.ceil(ScavengerStartboxXMax+(((mapSizeX)*0.01)*scavTechPercentage))
                local SpawnBoxMinZ = math.floor(ScavengerStartboxZMin-(((mapSizeZ)*0.01)*scavTechPercentage))
                local SpawnBoxMaxZ = math.ceil(ScavengerStartboxZMax+(((mapSizeZ)*0.01)*scavTechPercentage))      
                
                if posx < SpawnBoxMinX then return false end
                if posx > SpawnBoxMaxX then return false end
                if posz < SpawnBoxMinZ then return false end
                if posz > SpawnBoxMaxZ then return false end       

                return true
            else
                return true
            end
        else
            if not AllyTeamStartboxes[scavengerAllyTeamID].allyTeamHasStartbox then return true end -- There's no info about tech percentage, but if there's no startbox, we assume they can spawn anywhere, right?
            if StartboxCheck(posx, posy, posz, posradius, scavengerAllyTeamID) == true then return true end -- Area is within startbox, so it's for sure in the spawn box, even if we don't have info about how big spawn box is.
            return false -- but otherwise, don't let them spawn, don't risk spawning in place they shouldn't spawn.
        end
    else
        return false -- Scavs aren't in the game, so they don't have a spawn area.
    end
end

return {
    FlatAreaCheck = FlatAreaCheck,
    OccupancyCheck = OccupancyCheck,
    VisibilityCheck = VisibilityCheck,
    VisibilityCheckEnemy = VisibilityCheckEnemy,
    StartboxCheck = StartboxCheck,
    MapEdgeCheck = MapEdgeCheck,
    SurfaceCheck = SurfaceCheck,

    -- Scavengers
    ScavengerSpawnAreaCheck = ScavengerSpawnAreaCheck,
}
