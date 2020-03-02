
function spawnStartBoxProtection(n)
    --mapsizeX
    --mapsizeZ
    --ScavengerStartboxXMin
    --ScavengerStartboxZMin
    --ScavengerStartboxXMax
    --ScavengerStartboxZMax
    --GaiaTeamID
    --GaiaAllyTeamID
    --posCheck(posx, posy, posz, posradius)
    --posOccupied(posx, posy, posz, posradius)
    local r = math.random(0,3)
    local r2 = math.random(0,10)
    local spawnPosX = math.random(ScavengerStartboxXMin,ScavengerStartboxXMax)
    local spawnPosZ = math.random(ScavengerStartboxZMin,ScavengerStartboxZMax)
    if r == 0 then -- south edge
        spawnPosZ = ScavengerStartboxZMax
        spawnDirection = 0
    elseif r == 1 then  -- east edge
        spawnPosX = ScavengerStartboxXMax
        spawnDirection = 1
    elseif r == 2 then  -- south edge
        spawnPosZ = ScavengerStartboxZMin
        spawnDirection = 2
    elseif r == 3 then  -- west edge
        spawnPosX = ScavengerStartboxXMin
        spawnDirection = 3
    end
    if r2 == 0 then
        spawnPosX = math.random(ScavengerStartboxXMin,ScavengerStartboxXMax)
        spawnPosZ = math.random(ScavengerStartboxZMin,ScavengerStartboxZMax)
    end
    canSpawnDefence = true
    if spawnPosX == mapsizeX or spawnPosX == 0 or spawnPosZ == mapsizeZ or spawnPosZ == 0 then
        canSpawnDefence = false
    end
    if canSpawnDefence then
        local spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)

        local spawnTier = math.random(1,100)
        if spawnTier <= TierSpawnChances.T0 then
            pickedTurret = StartboxDefenceStructuresT0[math.random(1,#StartboxDefenceStructuresT0)]
        elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
            pickedTurret = StartboxDefenceStructuresT1[math.random(1,#StartboxDefenceStructuresT1)]
        elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
            pickedTurret = StartboxDefenceStructuresT2[math.random(1,#StartboxDefenceStructuresT2)]
        elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
            pickedTurret = StartboxDefenceStructuresT3[math.random(1,#StartboxDefenceStructuresT3)]
        elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
            pickedTurret = StartboxDefenceStructuresT4[math.random(1,#StartboxDefenceStructuresT4)]
        else
            pickedTurret = StartboxDefenceStructuresT0[math.random(1,#StartboxDefenceStructuresT0)]
        end

        canSpawnDefence = posCheck(spawnPosX, spawnPosY, spawnPosZ, 80)
        if canSpawnDefence then
            canSpawnDefence = posOccupied(spawnPosX, spawnPosY, spawnPosZ, 80)
        end
        
        if canSpawnDefence then
            Spring.CreateUnit(pickedTurret..scavconfig.unitnamesuffix, spawnPosX, spawnPosY, spawnPosZ, spawnDirection,GaiaTeamID)
            Spring.CreateUnit("scavengerdroppod_scav", spawnPosX, spawnPosY, spawnPosZ, spawnDirection,GaiaTeamID)
        end
    end

    
    spawnPosX = nil
    spawnPosZ = nil
    spawnDirection = nil
    canSpawnDefence = nil
    pickedTurret = nil
end