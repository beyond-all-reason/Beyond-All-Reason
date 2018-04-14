

-- disabled it... cause not all missile weapons have flighttime defined, but can run out of fuel when they dont traight fly to maxrange


function gadget:GetInfo()
  return {
    name      = "Starburst Missile Liftoff",
    desc      = "",
    version   = "tart",
    author    = "Floris",
    date      = "February 2018",
    license   = "GNU GPL, v3 or later",
    layer     = 0,
    enabled   = true,  --  loaded by default?
  }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local GetProjectilePosition = Spring.GetProjectilePosition
local GetProjectileDirection = Spring.GetProjectileDirection
local GetGroundHeight = Spring.GetGroundHeight

local missiles = {} --subMissiles that are below the surface still
local missileWeapons = {}

for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'StarburstLauncher' then
        if weaponDef.cegTag == 'missiletrailsmall-starburst' then
            missileWeapons[weaponDef.id] = {
                0,
                'missiletrailsmall-starburst-vertical', ((weaponDef.uptime+0.1)*30), ((weaponDef.uptime+0.6)*30),
                'missilegroundsmall-liftoff', 60, 90,
                'missilegroundsmall-liftoff-fire', 25, 45
            }
        elseif weaponDef.cegTag == 'missiletrailmedium-starburst' then
            missileWeapons[weaponDef.id] = {
                0,
                'missiletrailmedium-starburst-vertical', ((weaponDef.uptime+0.1)*30), ((weaponDef.uptime+0.6)*30),
                'missilegroundmedium-liftoff', 80, 120,
                'missilegroundmedium-liftoff-fire', 35, 55
            }
        elseif weaponDef.cegTag == 'missiletrail-juno' then
            missileWeapons[weaponDef.id] = {
                0,
                'missiletrail-juno-starburst', ((weaponDef.uptime+0.1)*30), ((weaponDef.uptime+0.6)*30),
                'missilegroundlarge-liftoff', 80, 120,
                'missilegroundlarge-liftoff-fire', 40, 80
            }
        elseif weaponDef.cegTag == 'antimissiletrail' then
            missileWeapons[weaponDef.id] = {
                0,
                'antimissiletrail-starburst', ((weaponDef.uptime+0.1)*30), ((weaponDef.uptime+0.6)*30),
                'missilegroundlarge-liftoff', 80, 120,
                'missilegroundlarge-liftoff-fire', 40, 80
            }
        elseif weaponDef.cegTag == 'cruisemissiletrail-emp' then
            missileWeapons[weaponDef.id] = {
                0,
                'cruisemissiletrail-starburst', ((weaponDef.uptime+0.1)*30), ((weaponDef.uptime+0.6)*30),
                'missilegroundlarge-liftoff', 90, 166,
                'missilegroundlarge-liftoff-fire', 55, 120
            }
        elseif weaponDef.cegTag == 'cruisemissiletrail-tacnuke' then
            missileWeapons[weaponDef.id] = {
                15,
                'cruisemissiletrail-starburst', ((weaponDef.uptime+0.1)*30), ((weaponDef.uptime+0.6)*30),
                'missilegroundlarge-liftoff', 90, 166,
                'missilegroundlarge-liftoff-fire', 55, 120
            }
        elseif weaponDef.cegTag == 'NUKETRAIL' then
            missileWeapons[weaponDef.id] = {
                0,
                'nuketrail-starburst', ((weaponDef.uptime+0.1)*30), ((weaponDef.uptime+0.6)*30),
                'missilegroundhuge-liftoff', 150, 220,
                'missilegroundhuge-liftoff-fire', 80, 190
            }
        end
    end
end


function gadget:Initialize()
    for wDID,_ in pairs(missileWeapons) do
        Script.SetWatchWeapon(wDID, true)
    end
end


function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if missileWeapons[weaponDefID] then
        local x,y,z = GetProjectilePosition(proID)
        local groundHeight = GetGroundHeight(x,z)
        if groundHeight < 0 then
            groundHeight = 0
        end
        local gf = Spring.GetGameFrame()
        missiles[proID] = {
            weaponDefID,
            groundHeight + missileWeapons[weaponDefID][1],
            gf,
            missileWeapons[weaponDefID][2],
            gf + missileWeapons[weaponDefID][3],
            gf + missileWeapons[weaponDefID][4],

            missileWeapons[weaponDefID][5],
            groundHeight + missileWeapons[weaponDefID][6],
            groundHeight + missileWeapons[weaponDefID][7],

            missileWeapons[weaponDefID][8],
            groundHeight + missileWeapons[weaponDefID][9],
            groundHeight + missileWeapons[weaponDefID][10],
        }
    end
end


function gadget:ProjectileDestroyed(proID)
    if missileWeapons[weaponDefID] then
        missiles[proID] = nil
    end
end


function gadget:GameFrame(gf)
    for proID, missile in pairs(missiles) do
        if gf <= missile[6] then
            local x,y,z = GetProjectilePosition(proID)
            if y and y > 0 then
                local dirX,dirY,dirZ = GetProjectileDirection(proID)
                if gf <= missile[5] or gf % 2 == 1 then
                    -- add extra missiletrail
                    Spring.SpawnCEG(missile[4],x,y,z,dirX,dirY,dirZ)
                    if y <= missile[8] or (y <= missile[9] and gf % 2 == 1) then
                        -- add ground dust
                        Spring.SpawnCEG(missile[7],x,missile[2],z,dirX,dirY,dirZ)
                    end
                    if y <= missile[11] or (y <= missile[12] and gf % 2 == 1) then
                        --add ground fire
                        Spring.SpawnCEG(missile[10],x,missile[2],z,dirX,dirY,dirZ)
                    end
                end
            else
                missiles[proID] = nil
            end
        else
            missiles[proID] = nil
        end
    end
end


