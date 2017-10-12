

-- disabled it... cause not all missile weapons have flighttime defined, but can run out of fuel when they dont traight fly to maxrange


function gadget:GetInfo()
  return {
    name      = "Missile smoke",
    desc      = "addes smoke ceg after missile flighttime is over",
    version   = "tart",
    author    = "Floris",
    date      = "October 2017",
    license   = "GNU GPL, v3 or later",
    layer     = 0,
    enabled   = false,  --  loaded by default?
  }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local totalTime = 0

local GetProjectilePosition = Spring.GetProjectilePosition
local GetProjectileDirection = Spring.GetProjectileDirection
local random = math.random

local missileWeapons = {}

for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'MissileLauncher' then
        if weaponDef.cegTag == 'missiletrailsmall' then
            missileWeapons[weaponDef.id] = {weaponDef.flightTime, 'missiletrailsmall-smoke'}
        end
    end
end


function gadget:Initialize()
    for wDID,_ in pairs(missileWeapons) do
        Script.SetWatchWeapon(wDID, true)
    end
end

local missiles = {} --subMissiles that are below the surface still

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if missileWeapons[weaponDefID] then
        missiles[proID] = {Spring.GetGameFrame()-5 + missileWeapons[weaponDefID][1], missileWeapons[weaponDefID][2]}
    end
end

function gadget:ProjectileDestroyed(proID)
    if missileWeapons[weaponDefID] then
        missiles[proID] = nil
    end
end

function gadget:GameFrame(gf)

    for proID, missile in pairs(missiles) do
        local x,y,z = GetProjectilePosition(proID)
        if y then
            if y > 0 and random() < 0.95 and gf > missile[1] then
                local dirX,dirY,dirZ = GetProjectileDirection(proID)
                Spring.SpawnCEG(missile[2],x,y,z,dirX,dirY,dirZ)
            end
        else
            missiles[proID] = nil
        end
    end
end


