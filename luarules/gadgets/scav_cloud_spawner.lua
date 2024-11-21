function gadget:GetInfo()
    return {
    name = "Scav Cloud Spawner",
    desc = "Spawns Cloud that represents Scav spawning area",
    author = "Damgam",
    date = "2023",
    license = "GNU GPL, v2 or later",
    layer = 0,
    enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() or not Spring.Utilities.Gametype.IsScavengers() then
    return
end

local teams = Spring.GetTeamList()
for _, teamID in ipairs(teams) do
    local teamLuaAI = Spring.GetTeamLuaAI(teamID)
    if (teamLuaAI and string.find(teamLuaAI, "Scavengers")) then
        scavTeamID = teamID
        scavAllyTeamID = select(6, Spring.GetTeamInfo(scavTeamID))
        break
    end
end

local mapx = Game.mapSizeX
local mapz = Game.mapSizeZ
local cloudMult = math.ceil((math.ceil(((mapx+mapz)*0.5)/512)^2)/18)
local maxMists = (#teams-2)*(cloudMult*0.25)
local aliveMists = {}
local aliveWrecks = {}
local mistDefIDs = {
    [UnitDefNames["scavmist_scav"].id] = true,
    [UnitDefNames["scavmistxl_scav"].id] = true,
    [UnitDefNames["scavmistxxl_scav"].id] = true,
}

function gadget:GameFrame(frame)
    for _ = 1, cloudMult do
        if math.random(0,6) == 0 then
            local randomx = math.random(0, mapx)
            local randomz = math.random(0, mapz)
            local randomy = Spring.GetGroundHeight(randomx, randomz)
            if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
                Spring.SpawnCEG("scavradiation",randomx,randomy+100,randomz,0,0,0)
            end

            randomx = math.random(0, mapx)
            randomz = math.random(0, mapz)
            randomy = Spring.GetGroundHeight(randomx, randomz)

            if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
                Spring.SpawnCEG("scavradiation-lightning",randomx,randomy+100,randomz,0,0,0)

                --if math.random(0, 10) == 0 then
                --    if Spring.GetGameRulesParam("scavTechAnger") > 10 and Spring.GetGameRulesParam("scavTechAnger") < 50 and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames["scavmist_scav"].id) < maxMists then
                --        local mist = Spring.CreateUnit("scavmist_scav", randomx, randomy, randomz, math.random(0,3), scavTeamID)
                --        if mist then
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --        end
                --    end
                --elseif math.random(0, 10) == 0 then
                --    if Spring.GetGameRulesParam("scavTechAnger") > 40 and Spring.GetGameRulesParam("scavTechAnger") < 90 and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames["scavmistxl_scav"].id) < maxMists then
                --        local mist = Spring.CreateUnit("scavmistxl_scav", randomx, randomy, randomz, math.random(0,3), scavTeamID)
                --        if mist then
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --        end
                --    end
                --elseif math.random(0, 10) == 0 then
                --    if Spring.GetGameRulesParam("scavTechAnger") > 80 and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames["scavmistxxl_scav"].id) < maxMists then
                --        local mist = Spring.CreateUnit("scavmistxxl_scav", randomx, randomy, randomz, math.random(0,3), scavTeamID)
                --        if mist then
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                --        end
                --    end
                --end
            end

            for i = 1,5 do
                randomx = math.random(0, mapx)
                randomz = math.random(0, mapz)
                randomy = Spring.GetGroundHeight(randomx, randomz)

                if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
                    Spring.SpawnCEG("scavmistxl",randomx,randomy+100,randomz,0,0,0)
                end
            end
        end
    end

    if frame%30 == 21 then
        for unitID, unitDefID in pairs(aliveMists) do
            local posx, posy, posz = Spring.GetUnitPosition(unitID)
            if not GG.IsPosInRaptorScum(posx, posy, posz) then
                Spring.DestroyUnit(unitID, true, true)
            elseif math.random(0,360) == 0 and Spring.GetTeamUnitDefCount(scavTeamID, unitDefID) > maxMists - math.ceil(maxMists*0.05) then
                Spring.DestroyUnit(unitID, true, true)
            end
        end
    end

    for featureID, data in pairs(aliveWrecks) do
        if featureID%30 == frame%30 then
            --Spring.Echo("featureID", featureID, frame)
            local posx, posy, posz = Spring.GetFeaturePosition(featureID)
            if GG.IsPosInRaptorScum(posx, posy, posz) then
                --Spring.Echo("isInScum", GG.IsPosInRaptorScum(posx, posy, posz))
                if data.resurrectable and data.resurrectable ~= "" then
                    --Spring.Echo("resurrectable", data.resurrectable)
                    if data.lastResurrectionCheck == select(3, Spring.GetFeatureHealth(featureID)) then
                        local random = math.random()
                        Spring.SetFeatureResurrect(featureID, data.ressurectable, data.facing, data.lastResurrectionCheck+(0.05*random*data.age))
                        Spring.SpawnCEG("scav-spawnexplo", posx, posy, posz, 0,0,0)
                        --Spring.Echo("resurrecting", data.lastResurrectionCheck)
                        SendToUnsynced("featureReclaimFrame", featureID, data.lastResurrectionCheck+(0.05*random*data.age))
                    end
                    if aliveWrecks[featureID].lastResurrectionCheck >= 1 then
                        Spring.CreateUnit(data.resurrectable, posx, posy, posz, data.facing, scavTeamID)
                        Spring.DestroyFeature(featureID)
                    end
                    aliveWrecks[featureID].lastResurrectionCheck = select(3, Spring.GetFeatureHealth(featureID))
                    aliveWrecks[featureID].age = aliveWrecks[featureID].age+0.0166
                else
                    local featureHealth, featureMaxHealth = Spring.GetFeatureHealth(featureID)
                    Spring.SpawnCEG("scaspawn-trail", posx, posy, posz, 0,0,0)
                    local random = math.random()
                    Spring.SetFeatureHealth(featureID, featureHealth-(featureMaxHealth*0.05*random))
                    SendToUnsynced("featureReclaimFrame", featureID, featureHealth-(featureMaxHealth*0.05*random))
                    --Spring.Echo("killing", featureHealth)
                    if featureHealth <= 0 then
                        Spring.DestroyFeature(featureID)
                    end
                end
            end
        end
    end

end

function gadget:UnitCreated(unitID, unitDefID)
    if mistDefIDs[unitDefID] then
        aliveMists[unitID] = unitDefID
    end
end

function gadget:UnitDestroyed(unitID, unitDefID)
    if mistDefIDs[unitDefID] then
        aliveMists[unitID] = nil
    end
end

function gadget:FeatureCreated(featureID, featureAllyTeamID)
    aliveWrecks[featureID] = {age = 0, resurrectable = Spring.GetFeatureResurrect(featureID), facing = select(2, Spring.GetFeatureResurrect(featureID)), lastResurrectionCheck = 0}
end

function gadget:FeatureDestroyed(featureID, featureAllyTeamID)
    aliveWrecks[featureID] = nil
end