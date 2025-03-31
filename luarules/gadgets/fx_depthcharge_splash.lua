local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Depthcharge splash",
        desc      = "Makes splashes for depth-charges and torpedoes entering the water",
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
local random = math.random


local depthChargeWeapons = {}
for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'TorpedoLauncher' then
        --if weaponDef.visuals.modelName == 'objects3d/minitorpedo.3do' then
        --    depthChargeWeapons[weaponID] = 'splash-tiny'
        if weaponDef.visuals.modelName == 'objects3d/torpedo.s3o' or weaponDef.visuals.modelName == 'objects3d/cordepthcharge.s3o'
        or weaponDef.visuals.modelName == 'objects3d/torpedo.3do' or weaponDef.visuals.modelName == 'objects3d/depthcharge.3do' then
            depthChargeWeapons[weaponID] = 'splash-torpedo'
        elseif weaponDef.visuals.modelName == 'objects3d/coradvtorpedo.s3o' or weaponDef.visuals.modelName == 'objects3d/Advtorpedo.3do' then
            depthChargeWeapons[weaponID] = 'splash-tiny'
        else
            depthChargeWeapons[weaponID] = 'splash-torpedo'
        end
    end
end

function gadget:Initialize()
    for wDID,_ in pairs(depthChargeWeapons) do
        Script.SetWatchProjectile(wDID, true)
    end
end

local missiles = {} --Depthcharges that are above the surface still

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if depthChargeWeapons[weaponDefID] then
        local _,y,_ = GetProjectilePosition(proID)
        if y > 0 then
            missiles[proID] = depthChargeWeapons[weaponDefID]
        end
    end
end

function gadget:ProjectileDestroyed(proID)
	missiles[proID] = nil
end


function gadget:GameFrame(n)
    for proID,_ in pairs(missiles) do
        local x,y,z = GetProjectilePosition(proID)
        if y then
            if y < 0 then
                Spring.SpawnCEG(missiles[proID],x,0,z)
                missiles[proID] = nil
            end
        else
            missiles[proID] = nil
        end
    end
end


