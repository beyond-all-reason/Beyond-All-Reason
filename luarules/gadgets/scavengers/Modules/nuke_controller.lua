
local function sendRandomNukeOrder(n, scav)
    local unitRange = Spring.GetUnitMaxRange(scav)

    if unitRange and unitRange > 0 then
        -- local nearestVisibleEnemy = Spring.GetUnitNearestEnemy(scav, unitRange, true)
        -- if nearestVisibleEnemy then
        --     local enemyDefID = Spring.GetUnitDefID(nearestVisibleEnemy)
        --     local enemyCanFly = UnitDefs[enemyDefID].canFly
        --     if enemyCanFly == false then
        --         local posx, posy, posz = Spring.GetUnitPosition(nearestVisibleEnemy)
        --         Spring.GiveOrderToUnit(scav, CMD.ATTACK, {posx,posy,posz}, {})
        --     end
        -- end
        
        local posx, posy, posz = Spring.GetUnitPosition(scav)
        local possibleTargets = Spring.GetUnitsInCylinder(posx, posz, unitRange)
        local targetnum = #possibleTargets

        if targetnum and targetnum > 1 then
            local r = math_random(1,targetnum)
            local targetID = possibleTargets[r]
            local targetTeam = Spring.GetUnitTeam(targetID)
			local targetNeutral = Spring.GetUnitNeutral(targetID)

            if targetTeam ~= ScavengerTeamID and targetNeutral == false then
                local targetDefID = Spring.GetUnitDefID(targetID)
                local targetCanFly = UnitDefs[targetDefID].canFly

				if targetCanFly == false then
                    local tx, ty, tz = Spring.GetUnitPosition(targetID)
                    Spring.GiveOrderToUnit(scav, CMD.ATTACK,{tx,ty,tz}, {})
                end
            end
        end
    end
end

return {
	SendRandomNukeOrder = sendRandomNukeOrder
}