-- To be done
local GaiaTeamID = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local function NearbyCapture(unitID, difficulty, range)
    if not difficulty then difficulty = 1 end
    if not range then range = 256 end

    local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)

    local x,y,z = Spring.GetUnitPosition(unitID)
    local nearbyUnits = Spring.GetUnitsInCylinder(x, z, range)

    local captureDamage = 0
    for i = 1,#nearbyUnits do
        local attackerID = nearbyUnits[i]
        if attackerID ~= unitID then
            local buildProgress = select(5, Spring.GetUnitHealth(unitID))
            if buildProgress == 1 then
                local attackerAllyTeamID = Spring.GetUnitAllyTeam(attackerID)
                if attackerAllyTeamID == unitAllyTeam then
                    captureDamage = captureDamage - ((UnitDefs[Spring.GetUnitDefID(attackerID)].metalCost/1000)*0.01)/difficulty
                elseif attackerAllyTeamID ~= GaiaAllyTeamID then
                    captureDamage = captureDamage + ((UnitDefs[Spring.GetUnitDefID(attackerID)].metalCost/1000)*0.01)/difficulty
                end
            end
        end
    end
    if captureDamage ~= 0 then
        local captureProgress = select(4, Spring.GetUnitHealth(unitID)) + captureDamage
        Spring.SetUnitHealth(unitID, {capture = captureProgress})
        if captureProgress < 0 then
            Spring.SetUnitHealth(unitID, {capture = 0})
        elseif captureProgress >= 1 then
            Spring.SetUnitHealth(unitID, {capture = 0})
            local nearestAttacker = Spring.GetUnitNearestEnemy(unitID, range*2, false)
            if nearestAttacker then
                Spring.TransferUnit(unitID, Spring.GetUnitTeam(nearestAttacker), false)
            end
        end
    end
end

return {
    NearbyCapture = NearbyCapture,
}
