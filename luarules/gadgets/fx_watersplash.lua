
function gadget:GetInfo()
  return {
    name      = "Watereffects",
    desc      = "Make splash sound in water",
    version   = "1.1",
    author    = "Jools ,Nixtux",
    date      = "April,2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,  --  loaded by default?
  }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end
	
local abs = math.abs
local GetGroundBlocked = Spring.GetGroundBlocked
local nonexplosiveWeapons = {
	LaserCannon = true,
	BeamLaser = true,
	EmgCannon = true,
	Flame = true,
	LightningCannon = true,
}

local CORE_SEADVBOMB = WeaponDefNames['corsb_core_seaadvbomb'].id --corsb gets a special ceg with less particles, because it has lots of bouncing bombs

local splashCEG1					= "watersplash_extrasmall"
local splashCEG2					= "watersplash_small"
local splashCEG3					= "watersplash_large"
local splashCEG4					= "watersplash_extralarge"
	
function gadget:Explosion(weaponID, px, py, pz, ownerID)
	local isWater = Spring.GetGroundHeight(px,pz) < 0
	local aoe = WeaponDefs[weaponID]["damageAreaOfEffect"] / 2
	local wType = WeaponDefs[weaponID].type
	if not nonexplosiveWeapons[wType] and isWater and abs(py) <= aoe and (not GetGroundBlocked(px, pz)) and weaponID ~= CORE_SEAADVBOMB then
        if  aoe >= 8 and aoe < 16 then
			Spring.SpawnCEG(splashCEG1, px, 0, pz)
		elseif aoe >= 16 and aoe < 48 then
			Spring.SpawnCEG(splashCEG2, px, 0, pz)
		elseif aoe >= 48 and aoe < 64 then
			Spring.SpawnCEG(splashCEG3, px, 0, pz)
		elseif aoe >= 64 and aoe < 300 then
			Spring.SpawnCEG(splashCEG4, px, 0, pz)
		end
		return true
	else
		return false
	end
end

function gadget:Initialize()
	for _,wDef in pairs(WeaponDefs) do
		if wDef.damageAreaOfEffect ~= nil and wDef.damageAreaOfEffect >8 and (not nonexplosiveWeapons[wDef.type]) then
			Script.SetWatchWeapon(wDef.id, true)
		end
	end
end
