local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "subMissile splash",
        desc      = "Makes splashes for missiles that emerge from the water",
        version   = "cake",
        author    = "Bluestone",
        date      = "July 2014",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = false,
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local GetProjectilePosition = Spring.GetProjectilePosition
local GetProjectileDirection = Spring.GetProjectileDirection
local random = math.random

local splashCEG = "torpedo-launch"

local subMissileWeapons = {}

for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'TorpedoLauncher' then
        --if weaponDef.visuals.modelName == 'objects3d/minitorpedo.3do' then
        --    subMissileWeapons[weaponDef.id] = 'torpedotrail-tiny'
        if weaponDef.visuals.modelName == 'objects3d/torpedo.s3o' or weaponDef.visuals.modelName == 'objects3d/torpedo.3do' then
            subMissileWeapons[weaponDef.id] = 'torpedotrail-small'
        elseif weaponDef.visuals.modelName == 'objects3d/coradvtorpedo.s3o' or weaponDef.visuals.modelName == 'objects3d/Advtorpedo.3do' then
            subMissileWeapons[weaponDef.id] = 'torpedotrail-large'
        else
            subMissileWeapons[weaponDef.id] = 'torpedotrail-small'
        end
    end
end


function gadget:Initialize()
    for wDID,_ in pairs(subMissileWeapons) do
        Script.SetWatchProjectile(wDID, true)
    end
end

local missiles = {} --subMissiles that are below the surface still

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if subMissileWeapons[weaponDefID] then
        missiles[proID] = subMissileWeapons[weaponDefID]
        local x,_,z = GetProjectilePosition(proID)
        Spring.SpawnCEG(splashCEG,x,0,z)
    end
end

function gadget:ProjectileDestroyed(proID)
	missiles[proID] = nil
end

function gadget:GameFrame(n)
    for proID, CEG in pairs(missiles) do
        local x,y,z = GetProjectilePosition(proID)
        if y then
            if y < 0 and random() < 0.95 then
                local dirX,dirY,dirZ = GetProjectileDirection(proID)
                Spring.SpawnCEG(CEG,x,y,z,dirX,dirY,dirZ)
            end
        else
            missiles[proID] = nil
        end
    end
end
