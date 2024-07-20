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

                if math.random(0, 100) == 0 then
                    if Spring.GetGameRulesParam("scavTechAnger") > 10 and Spring.GetGameRulesParam("scavTechAnger") < 50 and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames["scavmist_scav"].id) < maxMists then
                        local mist = Spring.CreateUnit("scavmist_scav", randomx, randomy, randomz, math.random(0,3), scavTeamID)
                        if mist then
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                        end
                    end
                elseif math.random(0, 100) == 0 then
                    if Spring.GetGameRulesParam("scavTechAnger") > 40 and Spring.GetGameRulesParam("scavTechAnger") < 90 and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames["scavmistxl_scav"].id) < maxMists then
                        local mist = Spring.CreateUnit("scavmistxl_scav", randomx, randomy, randomz, math.random(0,3), scavTeamID)
                        if mist then
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                        end
                    end
                elseif math.random(0, 100) == 0 then
                    if Spring.GetGameRulesParam("scavTechAnger") > 80 and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames["scavmistxxl_scav"].id) < maxMists then
                        local mist = Spring.CreateUnit("scavmistxxl_scav", randomx, randomy, randomz, math.random(0,3), scavTeamID)
                        if mist then
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                            Spring.GiveOrderToUnit(mist, CMD.PATROL, {randomx+math.random(-256,256), randomy, randomz+math.random(-256,256)}, {"shift"})
                        end
                    end
                end
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
            if math.random(0,360) == 0 and Spring.GetTeamUnitDefCount(scavTeamID, unitDefID) > maxMists - math.ceil(maxMists*0.05) then
                Spring.DestroyUnit(unitID, true, true)
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