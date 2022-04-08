
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ
local GaiaTeamID = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local noRushModeEnabled = false
local noRushTime = Spring.GetModOptions().norushtime
if Spring.GetModOptions().norushmode == true then
	noRushModeEnabled = true
end

function gadget:GetInfo()
    return {
      name      = "NoRush mode",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
      layer     = -100,
      enabled   = true,
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

local mapRestrictionNorth = Spring.GetModOptions().map_restrictions_shrinknorth
local mapRestrictionSouth = Spring.GetModOptions().map_restrictions_shrinksouth
local mapRestrictionWest = Spring.GetModOptions().map_restrictions_shrinkwest
local mapRestrictionEast = Spring.GetModOptions().map_restrictions_shrinkeast

local XMinMapBorder = (mapsizeX*(mapRestrictionWest/100))
local XMaxMapBorder = mapsizeX - (mapsizeX*(mapRestrictionEast/100))
local ZMinMapBorder = (mapsizeZ*(mapRestrictionNorth/100))
local ZMaxMapBorder = mapsizeZ - (mapsizeZ*(mapRestrictionSouth/100))

local mapRestrictionsEnabled = true
if XMinMapBorder == 0 and XMaxMapBorder == mapsizeX and ZMinMapBorder == 0 and ZMaxMapBorder == mapsizeZ then
    mapRestrictionsEnabled = false
end

if mapRestrictionsEnabled == true then
    Spring.MarkerAddPoint(XMinMapBorder, Spring.GetGroundHeight(XMinMapBorder, ZMinMapBorder), ZMinMapBorder, "Map Restriction Corner", true)
    Spring.MarkerAddPoint(XMaxMapBorder, Spring.GetGroundHeight(XMaxMapBorder, ZMinMapBorder), ZMinMapBorder, "Map Restriction Corner", true)
    Spring.MarkerAddPoint(XMinMapBorder, Spring.GetGroundHeight(XMinMapBorder, ZMaxMapBorder), ZMaxMapBorder, "Map Restriction Corner", true)
    Spring.MarkerAddPoint(XMaxMapBorder, Spring.GetGroundHeight(XMaxMapBorder, ZMaxMapBorder), ZMaxMapBorder, "Map Restriction Corner", true)
end

if noRushModeEnabled == false and mapRestrictionsEnabled == false then
    return
end

local unitPositionTable = {}
function gadget:GameFrame(n)
    -- Kill units outside of their cage
    if n < noRushTime*30*60 and noRushModeEnabled == true then
        if n%10 == 5 then
            local units = Spring.GetAllUnits()
            for u = 1,#units do
                local unitID = units[u]
                local unitTeam = Spring.GetUnitTeam(unitID)
                if unitTeam ~= Spring.GetGaiaTeamID() and startboxesTable[unitTeam+1].allyTeamHasStartbox then
                    local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(unitID)
                    if not (unitPosX > startboxesTable[unitTeam+1].xMin and 
                    unitPosX < startboxesTable[unitTeam+1].xMax and 
                    unitPosZ > startboxesTable[unitTeam+1].zMin and 
                    unitPosZ < startboxesTable[unitTeam+1].zMax) then
                        if unitPositionTable[unitID] then
                            Spring.SpawnCEG("scav-spawnexplo", unitPosX, unitPosY, unitPosZ, 0,0,0)
                            Spring.SpawnCEG("scav-spawnexplo", unitPositionTable[unitID].x, Spring.GetGroundHeight(unitPositionTable[unitID].x, unitPositionTable[unitID].z), unitPositionTable[unitID].z, 0,0,0)
                            Spring.SetUnitPosition(unitID, unitPositionTable[unitID].x, unitPositionTable[unitID].z)
                            
                            local newUnitPosX, newUnitPosY, newUnitPosZ = Spring.GetUnitPosition(unitID)
                            if not (newUnitPosX > startboxesTable[unitTeam+1].xMin and 
                            newUnitPosX < startboxesTable[unitTeam+1].xMax and 
                            newUnitPosZ > startboxesTable[unitTeam+1].zMin and 
                            newUnitPosZ < startboxesTable[unitTeam+1].zMax) then
                                Spring.DestroyUnit(unitID, false, false)
                                Spring.SpawnCEG("scavradiation-lightning", newUnitPosX,newUnitPosY+40,newUnitPosZ, 0,0,0)
                            end
                        else
                            Spring.DestroyUnit(unitID, false, false)
                            Spring.SpawnCEG("scavradiation-lightning", unitPosX,unitPosY+40,unitPosZ, 0,0,0)
                        end
                    else
                        unitPositionTable[unitID] = {x = unitPosX, z = unitPosZ}
                    end
                end
            end
        end
    elseif (n >= noRushTime*30*60 and mapRestrictionsEnabled == true) or (noRushModeEnabled == false and mapRestrictionsEnabled == true) then
        if n%10 == 5 then
            local units = Spring.GetAllUnits()
            for u = 1,#units do
                local unitID = units[u]
                local unitTeam = Spring.GetUnitTeam(unitID)
                if unitTeam ~= Spring.GetGaiaTeamID() then
                    local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(unitID)
                    if (unitPosX < XMinMapBorder or 
                    unitPosX > XMaxMapBorder or 
                    unitPosZ < ZMinMapBorder or 
                    unitPosZ > ZMaxMapBorder) and
                    unitPosX > 0 and 
                    unitPosX < mapsizeX and 
                    unitPosZ > 0 and 
                    unitPosZ < mapsizeZ then
                        if unitPositionTable[unitID] then
                            Spring.SpawnCEG("scav-spawnexplo", unitPosX, unitPosY, unitPosZ, 0,0,0)
                            Spring.SpawnCEG("scav-spawnexplo", unitPositionTable[unitID].x, Spring.GetGroundHeight(unitPositionTable[unitID].x, unitPositionTable[unitID].z), unitPositionTable[unitID].z, 0,0,0)
                            Spring.SetUnitPosition(unitID, unitPositionTable[unitID].x, unitPositionTable[unitID].z)
                            
                            local newUnitPosX, newUnitPosY, newUnitPosZ = Spring.GetUnitPosition(unitID)
                            if (newUnitPosX < XMinMapBorder or 
                            newUnitPosX > XMaxMapBorder or 
                            newUnitPosZ < ZMinMapBorder or 
                            newUnitPosZ > ZMaxMapBorder) and
                            newUnitPosX > 0 and 
                            newUnitPosX < mapsizeX and 
                            newUnitPosZ > 0 and 
                            newUnitPosZ < mapsizeZ then
                                Spring.DestroyUnit(unitID, false, false)
                                Spring.SpawnCEG("scavradiation-lightning", newUnitPosX,newUnitPosY+40,newUnitPosZ, 0,0,0)
                            end
                        else
                            Spring.DestroyUnit(unitID, false, false)
                            Spring.SpawnCEG("scavradiation-lightning", unitPosX,unitPosY+40,unitPosZ, 0,0,0)
                        end
                    else
                        unitPositionTable[unitID] = {x = unitPosX, z = unitPosZ}
                    end
                end
            end
        end
    end

        -- spawn purple fog and cages
    for a = 1,5 do
        local particleX = math.random(0, mapsizeX)
        local particleZ = math.random(0, mapsizeZ)
        local particleY = Spring.GetGroundHeight(particleX,particleZ)+math.random(-100,100)
        if particleY < 20 then
            particleY = 20
        end
        local canSpawnParticle = true
        local boxesCount = #startboxesTable
        if n < noRushTime*30*60 and noRushModeEnabled then
            for i = 1,boxesCount do
                if noRushModeEnabled then
                    if startboxesTable[i].allyTeamHasStartbox then
                        if particleX > startboxesTable[i].xMin-256 and 
                        particleX < startboxesTable[i].xMax+256 and 
                        particleZ > startboxesTable[i].zMin-256 and 
                        particleZ < startboxesTable[i].zMax+256 then
                            canSpawnParticle = false

                            canSpawnDefence = false
                            local spawnPosX = math.random(startboxesTable[i].xMin,startboxesTable[i].xMax)
                            local spawnPosZ = math.random(startboxesTable[i].zMin,startboxesTable[i].zMax)
                            local r = math.random(0,3)
                            if r == 0 then -- south edge
                                spawnPosZ = startboxesTable[i].zMax
                            elseif r == 1 then  -- east edge
                                spawnPosX = startboxesTable[i].xMax
                            elseif r == 2 then  -- south edge
                                spawnPosZ = startboxesTable[i].zMin
                            elseif r == 3 then  -- west edge
                                spawnPosX = startboxesTable[i].xMin
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
                                        Spring.SetUnitMaxHealth(wall, 10000000)
                                        Spring.SetUnitHealth(wall, 10000000)
                                        Spring.SetUnitCosts(wall, {buildTime = 10000000})
                                        table.insert(startboxWallsList, wall)
                                    end
                                else
                                    local wall = Spring.CreateUnit(UnitDefNames["corfdrag"].id, spawnPosX, spawnPosY, spawnPosZ, 0, GaiaTeamID)
                                    if wall then
                                        Spring.SetUnitMaxHealth(wall, 10000000)
                                        Spring.SetUnitHealth(wall, 10000000)
                                        Spring.SetUnitCosts(wall, {buildTime = 10000000})
                                        table.insert(startboxWallsList, wall)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- MapRestriction Box
        if (n >= noRushTime*30*60 and mapRestrictionsEnabled == true) or (noRushModeEnabled == false and mapRestrictionsEnabled == true) then
            if particleX > XMinMapBorder-256 and particleX < XMaxMapBorder+256 and particleZ > ZMinMapBorder-256 and particleZ < ZMaxMapBorder+256 then
                canSpawnParticle = false
            end

            canSpawnDefence = false
            local spawnPosX = math.random(XMinMapBorder,XMaxMapBorder)
            local spawnPosZ = math.random(ZMinMapBorder,ZMaxMapBorder)
            local r = math.random(0,3)
            if r == 0 then -- south edge
                spawnPosZ = ZMaxMapBorder-32
            elseif r == 1 then  -- east edge
                spawnPosX = XMaxMapBorder-32
            elseif r == 2 then  -- south edge
                spawnPosZ = ZMinMapBorder+32
            elseif r == 3 then  -- west edge
                spawnPosX = XMinMapBorder+32
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
                        Spring.SetUnitMaxHealth(wall, 10000000)
                        Spring.SetUnitHealth(wall, 10000000)
                        Spring.SetUnitCosts(wall, {buildTime = 10000000})
                    end
                else
                    local wall = Spring.CreateUnit(UnitDefNames["corfdrag"].id, spawnPosX, spawnPosY, spawnPosZ, 0, GaiaTeamID)
                    if wall then
                        Spring.SetUnitMaxHealth(wall, 10000000)
                        Spring.SetUnitHealth(wall, 10000000)
                        Spring.SetUnitCosts(wall, {buildTime = 10000000})
                    end
                end
            end
        end

        if canSpawnParticle == true then
            Spring.SpawnCEG("scavradiation", particleX,particleY,particleZ, 0,0,0)
            --Spring.SpawnCEG("scavradiation-lightning", particleX,particleY,particleZ, 0,0,0)
        end
    end
    
    if #startboxWallsList > 0 and n >= noRushTime*30*60 then
        -- if Spring.GetUnitIsDead(startboxWallsList[1]) == false then
        if Spring.ValidUnitID(startboxWallsList[1]) then
            Spring.DestroyUnit(startboxWallsList[1], true, false)
        end
        --table.remove(startboxWallsList, 1)
    end

    if (n >= noRushTime*30*60 and #startboxWallsList == 0) and mapRestrictionsEnabled == false then
        gadgetHandler:RemoveGadget(self)
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
    unitPositionTable[unitID] = nil
    for i = 1, #startboxWallsList do
        if unitID == startboxWallsList[i] then
            table.remove(startboxWallsList, i)
            break
        end
    end
end