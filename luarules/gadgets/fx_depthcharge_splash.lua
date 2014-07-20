function gadget:GetInfo()
  return {
    name      = "Depthcharge splash",
    desc      = "Makes splashes for depth-charges and torpedoes entering the water",
    version   = "cake",
    author    = "Bluestone",
    date      = "July 2014",
    license   = "GNU GPL, v3 or later",
    layer     = 0,
    enabled   = true,  --  loaded by default?
  }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local GetProjectilePosition = Spring.GetProjectilePosition
local random = math.random

--local splashCEG = "watersplash_extrasmall"
--local bubblesCEG = "small_water_bubbles"
local emergeCEG = "watersplash_emerge"

local depthChargeWeapons = {
    [WeaponDefNames["armdl_coax_depthcharge"].id] = true,
    [WeaponDefNames["cordl_coax_depthcharge"].id] = true,
    [WeaponDefNames["armlun_armlun_depthcharge"].id] = true,
    [WeaponDefNames["corsok_corsok_depthcharge"].id] = true,
    [WeaponDefNames["armlance_armair_torpedo"].id] = true,
    [WeaponDefNames["cortitan_armair_torpedo"].id] = true,
    [WeaponDefNames["armseap_armseap_weapon1"].id] = true,
    [WeaponDefNames["corseap_armseap_weapon1"].id] = true,
}

function gadget:Initialize()
    for wDID,_ in pairs(depthChargeWeapons) do
        Script.SetWatchWeapon(wDID, true)
    end
end

local missiles = {} --Depthcharges that are above the surface still

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if depthChargeWeapons[weaponDefID] then
        missiles[proID] = true
    end
end

function gadget:ProjectileDestroyed(proID)
    if depthChargeWeapons[weaponDefID] then
        missiles[proID] = nil
    end    
end


function gadget:GameFrame(n)
    for proID,_ in pairs(missiles) do
        local x,y,z = GetProjectilePosition(proID)
        if y then
            if y<0 then
                Spring.SpawnCEG(emergeCEG,x,0,z)
                missiles[proID] = nil
            end
        else
            missiles[proID] = nil
        end
    end
end


