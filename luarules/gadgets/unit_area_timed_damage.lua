function gadget:GetInfo()
	return {
		name = 'Area Timed Damage Handler',
		desc = '',
		author = 'Damgam',
		version = '1.0',
		date = '2022',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
    return
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ceg - ceg to spawn when explosion happens
-- ceg - ceg to spawn when damage is dealt
-- time - how long the effect should stay
-- damage - damage per second
-- range - from center to edge, in elmos

local TimedDamageWeapons = {
    [WeaponDefNames.chickenacidassault_acidspit.id] = {
        ceg = "acid-area-256", 
        damageCeg = "acid-damage-gen", 
        time = 10,
        damage = 5,
        range = 256,
    },
}

local TimedDamageDyingUnits = {
    [UnitDefNames.chickenacidassault.id] = {
        ceg = "", 
        damageCeg = "acid-damage-gen", 
        time = 10,
        damage = 5,
        range = 256,
    },
}

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

local aliveExplosions = {}

function gadget:Initialize()
    for id, a in pairs(TimedDamageWeapons) do 
        Script.SetWatchExplosion(id, true)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
    if TimedDamageWeapons[weaponDefID] then
        local currentTime = Spring.GetGameSeconds()
        aliveExplosions[#aliveExplosions+1] = { 
            x = px, 
            y = py, 
            z = pz, 
            endTime = currentTime + TimedDamageWeapons[weaponDefID].time, 
            damage = TimedDamageWeapons[weaponDefID].damage,
            range = TimedDamageWeapons[weaponDefID].range,
            ceg = TimedDamageWeapons[weaponDefID].ceg,
            cegSpawned = false,
            damageCeg = TimedDamageWeapons[weaponDefID].damageCeg,
        }
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if TimedDamageDyingUnits[unitDefID] then
        local currentTime = Spring.GetGameSeconds()
        local px, py, pz = Spring.GetUnitPosition(unitID)
        aliveExplosions[#aliveExplosions+1] = { 
            x = px, 
            y = py, 
            z = pz, 
            endTime = currentTime + TimedDamageDyingUnits[unitDefID].time, 
            damage = TimedDamageDyingUnits[unitDefID].damage,
            range = TimedDamageDyingUnits[unitDefID].range,
            ceg = TimedDamageDyingUnits[unitDefID].ceg,
            cegSpawned = false,
            damageCeg = TimedDamageDyingUnits[unitDefID].damageCeg,
        }
    end
end

function gadget:GameFrame(frame)
    if frame%22 == 10 then
        if #aliveExplosions > 0 then
            local safeForCleanup = true
            local currentTime = Spring.GetGameSeconds()
            for i = 1,#aliveExplosions do
                if aliveExplosions[i].endTime >= currentTime then
                    safeForCleanup = false
                    
                    local x = aliveExplosions[i].x
                    local z = aliveExplosions[i].z
                    local y = aliveExplosions[i].y or Spring.GetGroundHeight(x,z)
                    
                    if aliveExplosions[i].cegSpawned == false then
                        Spring.SpawnCEG(aliveExplosions[i].ceg, x, y + 8, z, 0, 0, 0)
                        aliveExplosions[i].cegSpawned = true
                    end
                    
                    local damage = aliveExplosions[i].damage
                    local range = aliveExplosions[i].range

                    local unitsInRange = Spring.GetUnitsInSphere(x, y, z, range)
                    for j = 1,#unitsInRange do
                        local unitID = unitsInRange[j]
                        if not UnitDefs[Spring.GetUnitDefID(unitID)].canFly then
                            local health = Spring.GetUnitHealth(unitID)
                            if health > damage then
                                Spring.SetUnitHealth(unitID, health - damage)
                            else
                                Spring.DestroyUnit(unitID, false, false)
                            end
                            local ux, uy, uz = Spring.GetUnitPosition(unitID)
                            Spring.SpawnCEG(aliveExplosions[i].damageCeg, ux, uy + 8, uz, 0, 0, 0)
                        end
                    end
                end
            end
           
            if aliveExplosions[1].endTime < currentTime then -- The oldest explosion is outdated, it's safe to remove it
                table.remove(aliveExplosions, 1)
            end

            if #aliveExplosions > 1000 then -- There's too many explosions! Most likely something went wrong, cleaning up the oldest explosion to save memory.
                Spring.Echo("TimedDamageExplosionTable Emergency Cleanup")
                table.remove(aliveExplosions, 1)
            end

            if safeForCleanup then -- No explosions are alive, we can safely clear the table without messing with table functions
                aliveExplosions = {}
            end
        end
    end
end