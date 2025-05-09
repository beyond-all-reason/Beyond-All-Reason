local function SwapUnit(unitID, newUnitName)
    -- Collect info about unit
    local unitDefID = Spring.GetUnitDefID(unitID)
    local unitTeam = Spring.GetUnitTeam(unitID)
    local unitHealth, unitMaxHealth, unitParalyze, unitCapture, unitBuildProgress = Spring.GetUnitHealth(unitID)
    local unitExperience = Spring.GetUnitExperience(unitID)
    local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(unitID)
    local unitDirectionX, unitDirectionY, unitDirectionZ = Spring.GetUnitDirection(unitID)
    local unitVelocityX, unitVelocityY, unitVelocityZ = Spring.GetUnitVelocity(unitID)
    local unitResurrected = Spring.GetUnitRulesParam(unitID, "resurrected")

    -- Spawn new unit, and if successful, despawn old one.
    local newUnitID = Spring.CreateUnit(newUnitName, unitPosX, unitPosY, unitPosZ, 0, unitTeam)
    if newUnitID then
        Spring.DestroyUnit(unitID, false, true)
        GG.ScavengersSpawnEffectUnitID(newUnitID)
        
        -- Apply stats of old unit to new one
        Spring.SetUnitExperience(newUnitID, unitExperience)
        local newUnitMaxHealth = select(2, Spring.GetUnitHealth(newUnitID))
        local newUnitHealth = (unitHealth/unitMaxHealth)*newUnitMaxHealth
        Spring.SetUnitHealth(newUnitID, newUnitHealth, unitCapture, unitParalyze, unitBuildProgress)
        Spring.SetUnitDirection(newUnitID, unitDirectionX, unitDirectionY, unitDirectionZ)
        Spring.SetUnitVelocity(newUnitID, unitVelocityX, unitVelocityY, unitVelocityZ)
        if unitResurrected then
            Spring.SetUnitRulesParam(newUnitID, "resurrected", 1, {inlos=true})
        end
    end
end

return {
    SwapUnit = SwapUnit,
}