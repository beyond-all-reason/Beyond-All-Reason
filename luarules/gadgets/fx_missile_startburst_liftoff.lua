

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

local missiles = {} --subMissiles that are below the surface still
local missileWeapons = {}

for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'StarburstLauncher' then
        if weaponDef.cegTag == 'missiletrailsmall-starburst' then
            missileWeapons[weaponDef.id] = {((weaponDef.uptime+0.33)*30), 'missiletrailmedium-starburst'}
        elseif weaponDef.cegTag == 'missiletrailmedium-starburst' then
            missileWeapons[weaponDef.id] = {((weaponDef.uptime+0.33)*30), 'missiletraillarge-starburst'}
        elseif weaponDef.cegTag == 'missiletraillarge-starburst' then
            missileWeapons[weaponDef.id] = {((weaponDef.uptime+0.33)*30), 'missiletraillarge-starburst'}
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
        missiles[proID] = {Spring.GetGameFrame() + missileWeapons[weaponDefID][1], missileWeapons[weaponDefID][2]}
    end
end


function gadget:ProjectileDestroyed(proID)
    if missileWeapons[weaponDefID] then
        missiles[proID] = nil
    end
end


function gadget:GameFrame(gf)
    if gf % 2 == 1 then
        for proID, missile in pairs(missiles) do
            if gf <= missile[1] then
                local x,y,z = GetProjectilePosition(proID)
                if y and y > 0 then
                    local dirX,dirY,dirZ = GetProjectileDirection(proID)
                    Spring.SpawnCEG(missile[2],x,y,z,dirX,dirY,dirZ)
                else
                    missiles[proID] = nil
                end
            else
                missiles[proID] = nil
            end
        end
    end
end


