
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ
local GaiaTeamID = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local noRushModeEnabled = false
if Spring.GetModOptions().norushmode == true then
	noRushModeEnabled = true
    noRushTime = Spring.GetModOptions().norushtime
end

function gadget:GetInfo()
    return {
      name      = "NoRush mode",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
      layer     = -100,
      enabled   = noRushModeEnabled,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local startboxesTable = {}
local startboxWallsList = {}

local teams = Spring.GetTeamList()
for i = 1,#teams do
    local teamID = i - 1
    local allyTeamID = select(6, Spring.GetTeamInfo(teamID))
    local xMin, zMin, xMax, zMax = Spring.GetAllyTeamStartBox(allyTeamID)
    local allyTeamHasStartbox
    if (xMin == 0 and zMin == 0 and xMax == mapsizeX and zMax == mapsizeZ) or teamID == GaiaTeamID then
        allyTeamHasStartbox = false
    else
        allyTeamHasStartbox = true
    end

    startboxesTable[i] = {
        teamID = teamID,
        allyTeamID = allyTeamID,
        allyTeamHasStartbox = allyTeamHasStartbox,
        xMin = xMin,
        zMin = zMin,
        xMax = xMax,
        zMax = zMax,
    }
end

function gadget:GameFrame(n)
   
    if n < noRushTime*30*60 then
        
        -- Kill units outside of their cage
        if n%30 == 10 then
            local units = Spring.GetAllUnits()
            for u = 1,#units do
                local unitID = units[u]
                local unitTeam = Spring.GetUnitTeam(unitID)
                if startboxesTable[unitTeam+1].allyTeamHasStartbox then
                    local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(unitID)
                    if not (unitPosX > startboxesTable[unitTeam+1].xMin-32 and 
                    unitPosX < startboxesTable[unitTeam+1].xMax+32 and 
                    unitPosZ > startboxesTable[unitTeam+1].zMin-32 and 
                    unitPosZ < startboxesTable[unitTeam+1].zMax+32) then
                        Spring.DestroyUnit(unitID, false, false)
                        Spring.SpawnCEG("scavradiation-lightning", unitPosX,unitPosY+40,unitPosZ, 0,0,0)
                    end
                end
            end
        end


         -- spawn purple fog and cages
        for a = 1,10 do
            local particleX = math.random(0, mapsizeX)
            local particleZ = math.random(0, mapsizeZ)
            local particleY = Spring.GetGroundHeight(particleX,particleZ)+math.random(-100,100)
            if particleY < 20 then
                particleY = 20
            end
            local canSpawnParticle = true
            for i = 1,#startboxesTable do
                if startboxesTable[i].allyTeamHasStartbox then
                    if particleX > startboxesTable[i].xMin-128 and 
                    particleX < startboxesTable[i].xMax+128 and 
                    particleZ > startboxesTable[i].zMin-128 and 
                    particleZ < startboxesTable[i].zMax+128 then
                        canSpawnParticle = false

                        canSpawnDefence = false
                        local spawnPosX = math.random(startboxesTable[i].xMin,startboxesTable[i].xMax)
                        local spawnPosZ = math.random(startboxesTable[i].zMin,startboxesTable[i].zMax)
                        local r = math.random(0,3)
                        if r == 0 then -- south edge
                            spawnPosZ = startboxesTable[i].zMax-32
                        elseif r == 1 then  -- east edge
                            spawnPosX = startboxesTable[i].xMax-32
                        elseif r == 2 then  -- south edge
                            spawnPosZ = startboxesTable[i].zMin+32
                        elseif r == 3 then  -- west edge
                            spawnPosX = startboxesTable[i].xMin+32
                        end
                        local spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
                        if spawnPosX > mapsizeX - 64 or spawnPosX < 64 or spawnPosZ > mapsizeZ - 64 or spawnPosZ < 64 then
                            canSpawnDefence = false
                        else
                            canSpawnDefence = true
                        end
                        local testUnits = Spring.GetUnitsInRectangle(spawnPosX-32, spawnPosZ-32, spawnPosX+32, spawnPosZ+32)
                        if #testUnits == 0 and canSpawnDefence then
                            if spawnPosY > 0 then
                                local wall = Spring.CreateUnit(UnitDefNames["corscavfort"].id, spawnPosX, spawnPosY, spawnPosZ, 0, GaiaTeamID)
                                if wall then
                                    Spring.SetUnitMaxHealth(wall, 16000000)
                                    Spring.SetUnitHealth(wall, 16000000)
                                    Spring.SetUnitCosts(wall, {buildTime = 9999999})
                                    table.insert(startboxWallsList, wall)
                                end
                            else
                                local wall = Spring.CreateUnit(UnitDefNames["corfdrag"].id, spawnPosX, spawnPosY, spawnPosZ, 0, GaiaTeamID)
                                if wall then
                                    Spring.SetUnitMaxHealth(wall, 16000000)
                                    Spring.SetUnitHealth(wall, 16000000)
                                    Spring.SetUnitCosts(wall, {buildTime = 9999999})
                                    table.insert(startboxWallsList, wall)
                                end
                            end
                        end
                    end
                end
            end
            if canSpawnParticle == true then
                Spring.SpawnCEG("scavradiation", particleX,particleY,particleZ, 0,0,0)
                Spring.SpawnCEG("scavradiation-lightning", particleX,particleY,particleZ, 0,0,0)
            end
        end
    else
        if #startboxWallsList > 0 then
            if Spring.ValidUnitID(startboxWallsList[1]) then
                Spring.DestroyUnit(startboxWallsList[1], true, false)
            end
            table.remove(startboxWallsList, 1)
        end
    end
end
