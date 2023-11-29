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
-- damageCeg - ceg to spawn when damage is dealt
-- time - how long the effect should stay
-- damage - damage per second
-- range - from center to edge, in elmos
-- resistance - defines which units are resistant to this type of damage when it matches with 'areadamageresistance' customparameter in a unit.

local TimedDamageWeapons = {
    [WeaponDefNames.raptor_land_assault_acid_t2_v1_acidspit.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 100,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_allterrain_arty_acid_t2_v1_acidspit.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 200,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_allterrain_arty_acid_t4_v1_acidspit.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 200,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_air_bomber_acid_t2_v1_acidbomb.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 100,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_land_swarmer_acids_t2_v1_acidspit.id] = {
        ceg = "acid-area-75",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 40,
        range = 75,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_allterrain_swarmer_acid_t2_v1_acidspit.id] = {
        ceg = "acid-area-75",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 40,
        range = 75,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_allterrain_assault_acid_t2_v1_acidspit.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 100,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_turret_acid_t2_v1_acidspit.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 200,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_turret_acid_t3_v1_acidspit.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 200,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_turret_acid_t4_v1_acidspit.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 200,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_matriarch_acid_acidgoo.id] = {
        ceg = "acid-area-75",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 40,
        range = 75,
        resistance = "_RAPTORACID_",
    },
    [WeaponDefNames.raptor_matriarch_acid_spike_acid_blob.id] = {
        ceg = "acid-area-75",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 40,
        range = 75,
        resistance = "_RAPTORACID_",
    },


	[WeaponDefNames.legbart_clusternapalm.id] = {
        ceg = "fire-area-75",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 30,
        range = 75,
        resistance = "test",
    },
	[WeaponDefNames.legbar_clusternapalm.id] = {
        ceg = "fire-area-75",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 30,
        range = 75,
        resistance = "test",
    },
	[WeaponDefNames.leginc_heatraylarge.id] = {
        ceg = "fire-incinerator",
        damageCeg = "burnflamexl",
        time = 3,
        damage = 0,
        range = 37,
        resistance = "test",
    },
	[WeaponDefNames.leginf_rapidnapalm.id] = {
        ceg = "fire-area-75",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 30,
        range = 75,
        resistance = "test",
    },
	[WeaponDefNames.legnap_napalmbombs.id] = {
        ceg = "fire-area-150",
        damageCeg = "burnflamexl",
        time = 15,
        damage = 30,
        range = 150,
        resistance = "test",
    },
	[WeaponDefNames.legcom_napalmmissile.id] = {
        ceg = "fire-area-150",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 75,
        range = 100,
        resistance = "test",
    },
	[WeaponDefNames.legcomlvl2_napalmmissile.id] = {
        ceg = "fire-area-150",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 75,
        range = 100,
        resistance = "test",
    },
	[WeaponDefNames.legcomlvl3_napalmmissile.id] = {
        ceg = "fire-area-150",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 150,
        range = 150,
        resistance = "test",
    },
	[WeaponDefNames.legcomlvl4_napalmmissile.id] = {
        ceg = "fire-area-150",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 150,
        range = 150,
        resistance = "test",
    },
	[WeaponDefNames.legbart_scav_clusternapalm.id] = {
        ceg = "fire-area-75",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 30,
        range = 75,
        resistance = "test",
    },
	[WeaponDefNames.legbar_scav_clusternapalm.id] = {
        ceg = "fire-area-75",
        damageCeg = "burnflamexl",
        time = 10,
		damage = 30,
        range = 70,
        resistance = "test",
    },
	[WeaponDefNames.leginc_scav_heatraylarge.id] = {
        ceg = "fire-incinerator",
        damageCeg = "burnflamexl",
        time = 3,
        damage = 0,
        range = 37,
        resistance = "test",
    },
	[WeaponDefNames.leginf_scav_rapidnapalm.id] = {
        ceg = "fire-area-75",
        damageCeg = "burnflamexl",
        time = 10,
        damage = 30,
        range = 75,
        resistance = "test",
    },
	[WeaponDefNames.legnap_scav_napalmbombs.id] = {
        ceg = "fire-area-150",
        damageCeg = "burnflamexl",
        time = 15,
        damage = 30,
        range = 150,
        resistance = "test",
    },

}

local TimedDamageDyingUnits = {
    [UnitDefNames.raptor_land_assault_acid_t2_v1.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 100,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [UnitDefNames.raptor_allterrain_arty_acid_t2_v1.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 100,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [UnitDefNames.raptor_allterrain_arty_acid_t4_v1.id] = {
        ceg = "acid-area-150",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 100,
        range = 150,
        resistance = "_RAPTORACID_",
    },
    [UnitDefNames.raptor_land_swarmer_acids_t2_v1.id] = {
        ceg = "acid-area-75",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 40,
        range = 75,
        resistance = "_RAPTORACID_",
    },
    [UnitDefNames.raptor_allterrain_swarmer_acid_t2_v1.id] = {
        ceg = "acid-area-75",
        damageCeg = "acid-damage-gen",
        time = 10,
        damage = 40,
        range = 75,
        resistance = "_RAPTORACID_",
    },
}

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- local aliveExplosions = {}

-- local function getRandomFreeExplosionID()
--     local attempts = 0
--     repeat 
--         attempts = attempts + 1
--         local number = math.random(1,100000)
--         if not aliveExplosions[number] then
--             return number
--         end
--     until attempts >= 100000
--     return nil
-- end

local aliveExplosions = {}
local aliveExplosionsCounter = 1

function gadget:Initialize()
    for id, a in pairs(TimedDamageWeapons) do
        Script.SetWatchExplosion(id, true)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
    if TimedDamageWeapons[weaponDefID] then
        local currentTime = Spring.GetGameSeconds()
        if py <= math.max(Spring.GetGroundHeight(px, pz), 0) + TimedDamageWeapons[weaponDefID].range*0.5 then
            aliveExplosions[aliveExplosionsCounter] = {
                x = px,
                y = math.max(Spring.GetGroundHeight(px, pz), 0),
                z = pz,
                endTime = currentTime + TimedDamageWeapons[weaponDefID].time,
                damage = TimedDamageWeapons[weaponDefID].damage,
                range = TimedDamageWeapons[weaponDefID].range,
                ceg = TimedDamageWeapons[weaponDefID].ceg,
                cegSpawned = false,
                damageCeg = TimedDamageWeapons[weaponDefID].damageCeg,
                resistance = TimedDamageWeapons[weaponDefID].resistance,
            }
            aliveExplosionsCounter = aliveExplosionsCounter + 1
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if TimedDamageDyingUnits[unitDefID] then
        local currentTime = Spring.GetGameSeconds()
        local px, py, pz = Spring.GetUnitPosition(unitID)
        if py <= math.max(Spring.GetGroundHeight(px, pz), 0) + TimedDamageDyingUnits[unitDefID].range*0.5 then
            aliveExplosions[aliveExplosionsCounter] = {
                x = px,
                y = math.max(Spring.GetGroundHeight(px, pz), 0),
                z = pz,
                endTime = currentTime + TimedDamageDyingUnits[unitDefID].time,
                damage = TimedDamageDyingUnits[unitDefID].damage,
                range = TimedDamageDyingUnits[unitDefID].range,
                ceg = TimedDamageDyingUnits[unitDefID].ceg,
                cegSpawned = false,
                damageCeg = TimedDamageDyingUnits[unitDefID].damageCeg,
                resistance = TimedDamageDyingUnits[unitDefID].resistance,
            }
            aliveExplosionsCounter = aliveExplosionsCounter + 1
        end
    end
end

function gadget:GameFrame(frame)
    if frame%22 == 10 then
        local currentTime = Spring.GetGameSeconds()
        for explosionID, explosionStats in pairs(aliveExplosions) do
        --for i = 1,#aliveExplosions do
            if explosionStats.endTime >= currentTime then
                local x = explosionStats.x
                local z = explosionStats.z
                local y = explosionStats.y or Spring.GetGroundHeight(x,z)
                if explosionStats.cegSpawned == false then
                    Spring.SpawnCEG(explosionStats.ceg, x, y + 8, z, 0, 0, 0)
                    explosionStats.cegSpawned = true
                end
                local damage = explosionStats.damage*0.733
                local range = explosionStats.range
                local resistance = explosionStats.resistance
                local unitsInRange = Spring.GetUnitsInSphere(x, y, z, range)
                for j = 1,#unitsInRange do
                    local unitID = unitsInRange[j]
                    local unitDefID = Spring.GetUnitDefID(unitID)
                    if (not UnitDefs[unitDefID].canFly) and (not (UnitDefs[unitDefID].customParams and UnitDefs[unitDefID].customParams.areadamageresistance and string.find(UnitDefs[unitDefID].customParams.areadamageresistance, resistance))) then
                        local health = Spring.GetUnitHealth(unitID)
                        if health > damage then
                            Spring.SetUnitHealth(unitID, health - damage)
                        else
                            Spring.DestroyUnit(unitID, false, false)
                        end
                        local ux, uy, uz = Spring.GetUnitPosition(unitID)
                        Spring.SpawnCEG(explosionStats.damageCeg, ux, uy + 8, uz, 0, 0, 0)
                    end
                end
                local featuresInRange = Spring.GetFeaturesInSphere(x, y, z, range)
                for j = 1,#featuresInRange do
                    local featureID = featuresInRange[j]
                    local health = Spring.GetFeatureHealth(featureID)
                    if health > damage then
                        Spring.SetFeatureHealth(featureID, health - damage)
                    else
                        Spring.DestroyFeature(featureID)
                    end
                    local ux, uy, uz = Spring.GetFeaturePosition(featureID)
                    Spring.SpawnCEG(explosionStats.damageCeg, ux, uy + 8, uz, 0, 0, 0)
                end
            else -- This explosion is outdated, we can remove it from the list
                aliveExplosions[explosionID] = nil
            end
        end
    end
end
