function skip()
    return (Spring.GetGameFrame() > 0) == false
end

function setup()
    Test.clearMap()
end

function cleanup()
    Test.clearMap()
end

local function createUnits(transDef, pawnDef)
    local trans = SyncedRun(function(t,p)
        local x,z = Game.mapSizeX/2, Game.mapSizeZ/2
        local y = Spring.GetGroundHeight(x,z)
        return Spring.CreateUnit(t,x,y,z,0,0)
    end, transDef)
    local pawns = {}
    for i=1,4 do
        pawns[i] = SyncedRun(function(def,idx)
            local x,z = Game.mapSizeX/2 + idx*20, Game.mapSizeZ/2 + idx*20
            local y = Spring.GetGroundHeight(x,z)
            return Spring.CreateUnit(def,x,y,z,0,0)
        end, pawnDef, i)
    end
    return trans, pawns
end

local function runCapacityTest(transDef)
    local trans, pawns = createUnits(transDef, "armpw")
    for _,u in ipairs(pawns) do
        Spring.GiveOrderToUnit(u, CMD.LOAD_ONTO, {trans}, 0)
    end
    Test.waitUntil(function()
        local list = Spring.GetUnitIsTransporting(trans)
        return list and #list == 4
    end, 180)
    assert(#Spring.GetUnitIsTransporting(trans) == 4)
end

function test()
    if not Spring.GetUnitDefID then return end
    if not Test.headless then
        return
    end
    -- flag on
    Spring.SendCommands("luarules changeModOption fixtransportermultiload 1")
    runCapacityTest("corseah")
    runCapacityTest("armdfly")
    -- flag off
    Spring.SendCommands("luarules changeModOption fixtransportermultiload 0")
    local trans,_ = createUnits("corseah","armpw")
    Test.waitFrames(1)
    assert(#Spring.GetUnitIsTransporting(trans) == 0)
end
