function gadget:GetInfo()
  return {
    name      = "subMissile splash",
    desc      = "Makes splashes for missiles that emerge from the water",
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

local splashCEG = "watersplash_extrasmall"
local bubblesCEG = "small_water_bubbles"
local emergeCEG = "watersplash_emerge"

local subMissileWeapons = {
    -- hardcoded because wDef.subMissile apparently doesn't exist
    [WeaponDefNames["armatl_armatl_torpedo"].id] = true,
    [WeaponDefNames["coratl_coratl_torpedo"].id] = true,
}

function gadget:Initialize()
    for wDID,_ in pairs(subMissileWeapons) do
        Script.SetWatchWeapon(wDID, true)
    end
end

local missiles = {} --subMissiles that are below the surface still

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if subMissileWeapons[weaponDefID] then
        missiles[proID] = true
        local x,_,z = GetProjectilePosition(proID)
        Spring.SpawnCEG(splashCEG,x,0,z)
    end
end

function gadget:ProjectileDestroyed(proID)
    if subMissileWeapons[weaponDefID] then
        missiles[proID] = nil
    end    
end


function gadget:GameFrame(n)
    for proID,_ in pairs(missiles) do
        local x,y,z = GetProjectilePosition(proID)
        if y then
            if random() < 0.4 then
                Spring.SpawnCEG(bubblesCEG,x,y,z)
            end
            if y>0 then
                Spring.SpawnCEG(emergeCEG,x,0,z)
                missiles[proID] = nil
            end
        else
            missiles[proID] = nil
        end
    end
end


