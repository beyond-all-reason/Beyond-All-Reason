-- disabled it... cause not all missile weapons have flighttime defined,
-- but can run out of fuel when they dont traight fly to maxrange


local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Missile smoke",
        desc      = "addes smoke ceg after missile flighttime is over",
        version   = "tart",
        author    = "Floris",
        date      = "October 2017",
		license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = false,
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local totalTime = 0

local GetProjectilePosition = Spring.GetProjectilePosition
local GetProjectileDirection = Spring.GetProjectileDirection
local random = math.random

local missiles = {} --subMissiles that are below the surface still
local missileWeapons = {}

for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'MissileLauncher' then
        if weaponDef.cegTag == 'missiletrailsmall' then
            missileWeapons[weaponDef.id] = 'missiletrailsmall-smoke'
        elseif weaponDef.cegTag == 'missiletrailsmall-simple' then
            missileWeapons[weaponDef.id] = 'missiletrailsmall-simple-smoke'
        elseif weaponDef.cegTag == 'missiletrailsmall-red' then
            missileWeapons[weaponDef.id] = 'missiletrailsmall-red-smoke'
        elseif weaponDef.cegTag == 'missiletrailmedium' then
            missileWeapons[weaponDef.id] = 'missiletrailmedium-smoke'
        elseif weaponDef.cegTag == 'missiletrailmedium-red' then
            missileWeapons[weaponDef.id] = 'missiletrailmedium-smoke'
        elseif weaponDef.cegTag == 'missiletraillarge' then
            missileWeapons[weaponDef.id] = 'missiletraillarge-smoke'
        elseif weaponDef.cegTag == 'missiletraillarge-red' then
            missileWeapons[weaponDef.id] = 'missiletraillarge-smoke'
        elseif weaponDef.cegTag == 'missiletrailtiny' then
            missileWeapons[weaponDef.id] = 'missiletrailtiny-smoke'
        elseif weaponDef.cegTag == 'missiletrailaa' then
            missileWeapons[weaponDef.id] = 'missiletrailaa-smoke'
        --elseif weaponDef.cegTag == 'missiletrailfighter' then
        --    missileWeapons[weaponDef.id] = 'missiletrailfighter-smoke'
        end
    end
end


function gadget:Initialize()
    for wDID,_ in pairs(missileWeapons) do
        Script.SetWatchProjectile(wDID, true)
    end
end


function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if missileWeapons[weaponDefID] then
        missiles[proID] = {Spring.GetGameFrame()-4 + Spring.GetProjectileTimeToLive(proID), missileWeapons[weaponDefID]}
    end
end


function gadget:ProjectileDestroyed(proID)
	missiles[proID] = nil
end


function gadget:GameFrame(gf)
    for proID, missile in pairs(missiles) do
        if gf > missile[1] then
            local x,y,z = GetProjectilePosition(proID)
            if y and y > 0 then
                local dirX,dirY,dirZ = GetProjectileDirection(proID)
                Spring.SpawnCEG(missile[2],x,y,z,dirX,dirY,dirZ)
            else
                missiles[proID] = nil
            end
        end
    end
end


