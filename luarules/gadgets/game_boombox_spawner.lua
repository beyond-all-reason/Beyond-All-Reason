function gadget:GetInfo()
    return {
        name      = "Boombox Spawner",
        desc      = "Spawns Easter Egg Boomboxes on the map that play special music when captured",
        author    = "Damgam",
        date      = "2024",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

return -- kill it for now

if not gadgetHandler:IsSyncedCode() then
    return
end

local AliveBoomboxes = {}
local SelfDQueue = {}
local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

for i = 1,100 do
    if math.random(1,10) == 1 then -- April Fools odds
    -- if math.random(1,2137) == 1 then -- Normal Day odds
        for j = 1,1000 do
            local posx = math.random(math.floor(Game.mapSizeX*0.1), math.ceil(Game.mapSizeX*0.9))
            local posz = math.random(math.floor(Game.mapSizeX*0.1), math.ceil(Game.mapSizeX*0.9))
            local posy = Spring.GetGroundHeight(posx, posz)
            if posy > 0 and positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 64, 25, true) then
                local boomboxID = Spring.CreateUnit("boombox", posx, posy, posz, "west", Spring.GetGaiaTeamID())
                if boomboxID then
                    AliveBoomboxes[boomboxID] = true
                    break
                end
            end
        end

    end
end

function gadget:GameFrame(frame)
    if frame == 1 then
        for unitID, _ in pairs(AliveBoomboxes) do
            Spring.SetUnitNeutral(unitID, true)
            Spring.SetUnitStealth(unitID, true)
            Spring.SetUnitNoMinimap(unitID, true)
            Spring.SetUnitMaxHealth(unitID, 1000)
            Spring.SetUnitHealth(unitID, 1000)
            Spring.SetUnitSensorRadius(unitID, 'los', 0)
            Spring.SetUnitSensorRadius(unitID, 'airLos', 0)
            Spring.SetUnitSensorRadius(unitID, 'radar', 0)
            Spring.SetUnitSensorRadius(unitID, 'sonar', 0)
        end
    end
    if frame%60 == 0 then
        for unitID, _ in pairs(AliveBoomboxes) do
            Spring.SetUnitHealth(unitID, 10000000)
        end
        for unitID, time in pairs(SelfDQueue) do
            if Spring.GetGameFrame() > time then
                Spring.DestroyUnit(unitID)
                SelfDQueue[unitID] = nil
                AliveBoomboxes[unitID] = nil
                break
            end
        end
    end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
    if UnitDefs[unitDefID].name == "boombox" then
        SelfDQueue[unitID] = Spring.GetGameFrame()+90
    end
end