-- Regression test for commander resurrection at the map edge
function test()
    local worldMinX = Game.mapSizeX - Game.mapSizeX -- should be 0
    local spawnZ = Game.mapSizeZ * 0.5
    local spawnY = Spring.GetGroundHeight(worldMinX, spawnZ)
    local featureID = Spring.CreateFeature("armcom_dead", worldMinX - 20, spawnY, spawnZ)
    assert(featureID, "failed to create commander wreck")

    local unitID = Spring.ResurrectUnit(featureID)
    assert(unitID, "resurrect returned nil")
    assert(not Spring.GetUnitIsDead(unitID), "unit is dead after resurrection")

    local x, y, z = Spring.GetUnitPosition(unitID)
    assert(Spring.TestMoveOrder(Spring.GetUnitDefID(unitID), x, y, z), "unit cannot move from edge")
end
