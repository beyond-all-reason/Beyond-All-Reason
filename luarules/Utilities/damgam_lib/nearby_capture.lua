-- To be done
local GaiaTeamID = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local function NearbyCapture(unitID, difficulty, range)
    local difficulty = difficulty
    if not difficulty then difficulty = 1 end
    local range = range
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
                local attackerDefID = Spring.GetUnitDefID(attackerID)
                local attackerMetalCost = UnitDefs[attackerDefID].metalCost
                local capturePower = ((attackerMetalCost/1000)*0.01)/difficulty
                if attackerAllyTeamID == unitAllyTeam then
                    captureDamage = captureDamage - capturePower
                elseif attackerAllyTeamID ~= GaiaAllyTeamID then
                    captureDamage = captureDamage + capturePower
                end
            end
        end
    end
    if captureDamage ~= 0 then
        local captureProgress = select(4, Spring.GetUnitHealth(unitID))
        if captureProgress+captureDamage < 0 then
            Spring.SetUnitHealth(unitID, {capture = 0})
        elseif captureProgress+captureDamage >= 1 then
            local nearestAttacker = Spring.GetUnitNearestEnemy(unitID, range*2, false)
            if nearestAttacker then
                local attackerTeamID = Spring.GetUnitTeam(nearestAttacker)
                Spring.TransferUnit(unitID, attackerTeamID, false)
                Spring.SetUnitHealth(unitID, {capture = 0.75})
            end
        else
            Spring.SetUnitHealth(unitID, {capture = captureProgress + captureDamage})
        end
    end
end

return { 
    NearbyCapture = NearbyCapture,
}