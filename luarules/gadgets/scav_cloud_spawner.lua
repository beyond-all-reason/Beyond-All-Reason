local gadget = gadget ---@type Gadget

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

if not Spring.Utilities.Gametype.IsScavengers() then
    return
end

if gadgetHandler:IsSyncedCode() then -- Synced 
    local teams = Spring.GetTeamList()
    local scavTeamID = Spring.Utilities.GetScavTeamID()
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
    
    VFS.Include('common/wav.lua')
    local cooldown = 0 -- 1 minute cooldown at the start

    local mRandom = math.random
    local spGetGroundHeight = Spring.GetGroundHeight
    local spSpawnCEG = Spring.SpawnCEG
    local spPlaySoundFile = Spring.PlaySoundFile
    local spGetUnitPosition = Spring.GetUnitPosition
    local spDestroyUnit = Spring.DestroyUnit
    local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount
    local spGetFeaturePosition = Spring.GetFeaturePosition
    local spGetFeatureResurrect = Spring.GetFeatureResurrect
    local spGetFeatureHealth = Spring.GetFeatureHealth
    local spSetFeatureResurrect = Spring.SetFeatureResurrect
    local spSetFeatureHealth = Spring.SetFeatureHealth
    local spDestroyFeature = Spring.DestroyFeature
    local spCreateUnit = Spring.CreateUnit
    local SendToUnsynced = SendToUnsynced

    function gadget:GameFrame(frame)
        for _ = 1, cloudMult do
            if mRandom(0,10) == 0 then
                local randomx = mRandom(0, mapx)
                local randomz = mRandom(0, mapz)
                local randomy = spGetGroundHeight(randomx, randomz)
                if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
                    spSpawnCEG("scavradiation",randomx,randomy+100,randomz,0,0,0)
                end

                randomx = mRandom(0, mapx)
                randomz = mRandom(0, mapz)
                randomy = spGetGroundHeight(randomx, randomz)

                if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
                    spSpawnCEG("scavradiation-lightning",randomx,randomy+100,randomz,0,0,0)
                    spPlaySoundFile("thunder" .. mRandom(1,5), 1.5, randomx, randomy+100, randomz)

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
                    randomx = mRandom(0, mapx)
                    randomz = mRandom(0, mapz)
                    randomy = spGetGroundHeight(randomx, randomz)

                    if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
                        spSpawnCEG("scavmistxl",randomx,randomy+100,randomz,0,0,0)
                    end
                end
            end
        end

        if frame%30 == 21 then
            for unitID, unitDefID in pairs(aliveMists) do
                local posx, posy, posz = spGetUnitPosition(unitID)
                if not GG.IsPosInRaptorScum(posx, posy, posz) then
                    spDestroyUnit(unitID, true, true)
                elseif mRandom(0,360) == 0 and spGetTeamUnitDefCount(scavTeamID, unitDefID) > maxMists - math.ceil(maxMists*0.05) then
                    spDestroyUnit(unitID, true, true)
                end
            end
        end

        for featureID, data in pairs(aliveWrecks) do
            if featureID%30 == frame%30 then
                --Spring.Echo("featureID", featureID, frame)
                local posx, posy, posz = spGetFeaturePosition(featureID)
                if GG.IsPosInRaptorScum(posx, posy, posz) then
                    --Spring.Echo("isInScum", GG.IsPosInRaptorScum(posx, posy, posz))
                    aliveWrecks[featureID].resurrectable = spGetFeatureResurrect(featureID)
                    if data.resurrectable and data.resurrectable ~= "" then
                        --Spring.Echo("resurrectable", data.resurrectable)
                        if data.lastResurrectionCheck == select(3, spGetFeatureHealth(featureID)) then
                            local random = mRandom()
                            spSetFeatureResurrect(featureID, data.ressurectable, data.facing, data.lastResurrectionCheck+(0.05*random*data.age))
                            GG.ScavengersSpawnEffectFeatureID(featureID)
                            --Spring.Echo("resurrecting", data.lastResurrectionCheck)
                            SendToUnsynced("featureReclaimFrame", featureID, data.lastResurrectionCheck+(0.05*random*data.age))
                        end
                        if aliveWrecks[featureID].lastResurrectionCheck >= 1 then
                            spCreateUnit(data.resurrectable, posx, posy, posz, data.facing, scavTeamID)
                            spDestroyFeature(featureID)
                        end
                        aliveWrecks[featureID].lastResurrectionCheck = select(3, spGetFeatureHealth(featureID))
                        aliveWrecks[featureID].age = aliveWrecks[featureID].age+0.0166
                    else
                        local featureHealth, featureMaxHealth = spGetFeatureHealth(featureID)
                        spSpawnCEG("scaspawn-trail", posx, posy, posz, 0,0,0)
                        local random = mRandom()
                        spSetFeatureHealth(featureID, featureHealth-(featureMaxHealth*0.05*random))
                        SendToUnsynced("featureReclaimFrame", featureID, featureHealth-(featureMaxHealth*0.05*random))
                        --Spring.Echo("killing", featureHealth)
                        if featureHealth <= 0 then
                            spDestroyFeature(featureID)
                        end
                    end
                end
            end
        end

        cooldown = cooldown - 1
        --Spring.Echo("SoundStreamTime", Spring.GetSoundStreamTime())
        local randomx = mRandom(0, mapx)
        local randomz = mRandom(0, mapz)
        local randomy = spGetGroundHeight(randomx, randomz)
        if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
            if cooldown < 0 then
                local synth = "scavsynth" .. mRandom(1,12)
                spPlaySoundFile(synth, 4, randomx, randomy, randomz)
                cooldown = mRandom(20,40)*30
                --cooldown = ReadWAV("sounds/atmos/scavsynth1").Length*30
            else
                cooldown = cooldown - 2
            end
        end
    end

    function gadget:UnitCreated(unitID, unitDefID)
        if mistDefIDs[unitDefID] then
            aliveMists[unitID] = unitDefID
        end
    end

    function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
        if mistDefIDs[unitDefID] then
            aliveMists[unitID] = nil
        end
    end

    function gadget:FeatureCreated(featureID, featureAllyTeamID)
        local resurrectable, facing = spGetFeatureResurrect(featureID)
        aliveWrecks[featureID] = {age = 0, resurrectable = resurrectable, facing = facing, lastResurrectionCheck = 0}
    end

    function gadget:FeatureDestroyed(featureID, featureAllyTeamID)
        aliveWrecks[featureID] = nil
    end
else -- Unsynced

end
