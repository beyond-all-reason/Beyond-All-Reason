
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

LUAUI_DIRNAME= 'LuaUI/'
local random  = math.random
local abs = math.abs
local GetGroundBlocked = Spring.GetGroundBlocked
local nonexplosiveWeapons = {
	LaserCannon = true,
	BeamLaser = true,
	EmgCannon = true,
	Flame = true,
	LightningCannon = true,
}

if not gadgetHandler:IsSyncedCode() then
	-------------------
	-- UNSYNCED PART --
	-------------------
	
else
	-----------------
	-- SYNCED PART --
	-----------------
	
  	local splashCEG1					= "Watersplash_Extrasmall"
	local splashCEG2					= "Watersplash_Small"
	local splashCEG3					= "Watersplash_Large"
	local splashCEG4					= "Watersplash_Extralarge"

	
	function gadget:Explosion(weaponID, px, py, pz, ownerID)
		local isWater = Spring.GetGroundHeight(px,pz) < 0
		local aoe = WeaponDefs[weaponID]["damageAreaOfEffect"] / 2
		local wType = WeaponDefs[weaponID].type
				if not nonexplosiveWeapons[wType] and isWater and abs(py) <= aoe and (not GetGroundBlocked(px, pz)) then
			if aoe >= 8 and aoe < 16 then
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
	
		for id,Def in pairs(WeaponDefs) do
			local weaponID
			if Def.damageAreaOfEffect ~= nil and Def.damageAreaOfEffect >8 and not nonexplosiveWeapons[Def.type] then
				Script.SetWatchWeapon(Def.id, true)
			end
		end
	end
end