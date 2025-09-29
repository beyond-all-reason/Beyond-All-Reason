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
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

-- Map size
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local landLevel
local seaLevel

local scavengerAllyTeamID = Spring.Utilities.GetScavAllyTeamID()

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
    local lavaLevel = Spring.GetGameRulesParam("lavaLevel")

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
    if lavaLevel and posy <= lavaLevel then return false end -- Is lava
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

local function LandOrSeaCheck(posx, posy, posz, posradius) -- returns string, "land", "sea", "mixed", "death"
    local posradius = posradius or 1000
    local deathwater = Game.waterDamage
    local lavaLevel = Spring.GetGameRulesParam("lavaLevel")

        -- Check height of test points in all 8 directions.
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )

    local minimumheight = math.min(testpos1, testpos2, testpos3, testpos4, testpos5, testpos6, testpos7, testpos8)
    local maximumheight = math.max(testpos1, testpos2, testpos3, testpos4, testpos5, testpos6, testpos7, testpos8)

    if (deathwater > 0 and minimumheight <= 0) or (lavaLevel and (minimumheight <= lavaLevel)) then
        return "death"
    end
    
    if minimumheight <= 0 and maximumheight <= 0 then
        return "sea"
    end

    if minimumheight > 0 and maximumheight > 0 then
        return "land"
    end

    if minimumheight <= 0 and maximumheight > 0 then
        return "mixed"
    end
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

local function ResourceCheck(posx, posz, posradius) -- Returns true if there are no resources in the spawn area
    local posradiusSquared = posradius * posradius
    local metalSpots = GG["resource_spot_finder"].metalSpotsList
    if metalSpots then
        for _,spot in ipairs(metalSpots) do
            if math.distance2dSquared(spot.x, spot.z, posx, posz) < posradiusSquared then
                return false
            end
        end
    end

    local geoSpots = GG["resource_spot_finder"].geoSpotsList
    if geoSpots then
        for _,spot in ipairs(geoSpots) do
            if math.distance2dSquared(spot.x, spot.z, posx, posz) < posradiusSquared then
                return false
            end
        end
    end
    return true
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

local function StartboxCheck(posx, posy, posz, allyTeamID, returnTrueWhenNoStartbox) -- Return True when position is within startbox.
    --local posradius = posradius or 1000
    if not returnTrueWhenNoStartbox then returnTrueWhenNoStartbox = false end

    if allyTeamID == GaiaAllyTeamID then 
        return not returnTrueWhenNoStartbox
    end
    local startbox = AllyTeamStartboxes[allyTeamID+1]

    if startbox.allyTeamHasStartbox == false then
        return not returnTrueWhenNoStartbox
    end

    if posx >= startbox.xMin and posz >= startbox.zMin and posx <= startbox.xMax and posz <= startbox.zMax then -- Lua Tables start at 1, AllyTeamID's start at 0, so we have to add 1 everytime
        return not returnTrueWhenNoStartbox
    else
        return returnTrueWhenNoStartbox
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
    local lavaLevel = Spring.GetGameRulesParam("lavaLevel")

    if deathwater > 0 and posy <= 0 then return false end -- Is water, Deathwater
    if lavaLevel and posy <= lavaLevel then return false end -- Is lava

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
    local posradius = posradius or 1000
    if scavengerAllyTeamID then
        local scavTechPercentage = Spring.GetGameRulesParam("scavStatsTechPercentage")
        if scavTechPercentage then
            if Spring.GetModOptions().scavspawnarea == true then
                if not AllyTeamStartboxes[scavengerAllyTeamID+1].allyTeamHasStartbox then return true end -- Scavs do not have a startbox so we allow them to spawn anywhere
                if StartboxCheck(posx, posy, posz, scavengerAllyTeamID) == true then return true end -- Area is within startbox, so it's for sure in the spawn box.
                
                -- Spawn Box grows with Scavengers tech, getting that into from GameRulesParameter set by Scav gadget
                local SpawnBoxMinX = math.floor(AllyTeamStartboxes[scavengerAllyTeamID+1].xMin-(((mapSizeX)*0.01)*scavTechPercentage))
                local SpawnBoxMaxX = math.ceil(AllyTeamStartboxes[scavengerAllyTeamID+1].xMax+(((mapSizeX)*0.01)*scavTechPercentage))
                local SpawnBoxMinZ = math.floor(AllyTeamStartboxes[scavengerAllyTeamID+1].zMin-(((mapSizeZ)*0.01)*scavTechPercentage))
                local SpawnBoxMaxZ = math.ceil(AllyTeamStartboxes[scavengerAllyTeamID+1].zMax+(((mapSizeZ)*0.01)*scavTechPercentage))      
                
                if posx < SpawnBoxMinX then return false end
                if posx > SpawnBoxMaxX then return false end
                if posz < SpawnBoxMinZ then return false end
                if posz > SpawnBoxMaxZ then return false end       

                return true
            else
                return true
            end
        else
            if not AllyTeamStartboxes[scavengerAllyTeamID+1].allyTeamHasStartbox then return true end -- There's no info about tech percentage, but if there's no startbox, we assume they can spawn anywhere, right?
            if StartboxCheck(posx, posy, posz, scavengerAllyTeamID) == true then return true end -- Area is within startbox, so it's for sure in the spawn box, even if we don't have info about how big spawn box is.
            return false -- but otherwise, don't let them spawn, don't risk spawning in place they shouldn't spawn.
        end
    else
        return false -- Scavs aren't in the game, so they don't have a spawn area.
    end
end

local function LavaCheck(posx, posy, posz, posradius) -- Returns false if area is in lava
    local posradius = posradius or 1000
    local lavaLevel = Spring.GetGameRulesParam("lavaLevel")
    if lavaLevel and posy <= lavaLevel then return false end -- Is lava
    return true
end

local function MapIsLandOrSea()
    if not landLevel then
        local grid = (math.ceil(mapSizeX/16))*(math.ceil(mapSizeZ/16))
        local x = 0
        local z = 0
        local y = 0
        local landNodes = 0
        local seaNodes = 0
        for i = 1,grid do
            if x <= mapSizeX then
                y = Spring.GetGroundHeight(x,z)
                if y > -15 then
                    landNodes = landNodes + 1
                elseif y <= -15 then
                    seaNodes = seaNodes + 1
                end
                x = x + 16
            elseif x > mapSizeX then
                x = 0
                z = z + 16
                if z > mapSizeZ then
                    break
                end
                
                y = Spring.GetGroundHeight(x,z)
                if y > 0 then
                    landNodes = landNodes + 1
                elseif y <= 0 then
                    seaNodes = seaNodes + 1
                end
            end
        end
        landLevel = math.ceil((landNodes/grid)*10000)/100
        seaLevel = math.ceil((seaNodes/grid)*10000)/100
    end
    --Spring.Echo("LandLevel", landLevel.." "..seaLevel)
    return landLevel, seaLevel
end

return {
    FlatAreaCheck = FlatAreaCheck,
    OccupancyCheck = OccupancyCheck,
    VisibilityCheck = VisibilityCheck,
    VisibilityCheckEnemy = VisibilityCheckEnemy,
    StartboxCheck = StartboxCheck,
    MapEdgeCheck = MapEdgeCheck,
    SurfaceCheck = SurfaceCheck,
    LavaCheck = LavaCheck,
    MapIsLandOrSea = MapIsLandOrSea,
    LandOrSeaCheck = LandOrSeaCheck,
    ResourceCheck = ResourceCheck,

    -- Scavengers
    ScavengerSpawnAreaCheck = ScavengerSpawnAreaCheck,
}
