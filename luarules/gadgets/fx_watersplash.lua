
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

LUAUI_DIRNAME							= 'LuaUI/'
local random  = math.random
local abs = math.abs
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
	
	local splashCEG1					= "torpbomb"
	local splashCEG2					= "Watersplash_Small"
	local splashCEG3					= "Watersplash_Large"
	local sndWater 						= "Sounds/SPLSHBIG.WAV"
	local GetGroundBlocked					= Spring.GetGroundBlocked

	
	function gadget:Explosion(weaponID, px, py, pz, ownerID)
		local isWater = Spring.GetGroundHeight(px,pz) < 0
		local aoe = WeaponDefs[weaponID]["damageAreaOfEffect"] / 2
		local wType = WeaponDefs[weaponID].type
		if not nonexplosiveWeapons[wType] and isWater and abs(py) <= aoe then
			if aoe >= 16 and aoe < 48 and (not GetGroundBlocked(px, pz)) then
				Spring.SpawnCEG(splashCEG2, px, 0, pz)
			elseif aoe >= 48 and (not GetGroundBlocked(px, pz))  then
				Spring.SpawnCEG(splashCEG3, px, 0, pz)
			end
			return true
		else
			return false
		end
	end
	
	function gadget:Initialize()
		--Spring.SendCommands ("cheat") 
		--Spring.SendCommands ("globallos")
		--Spring.SendCommands ("nocost")
	
		for id,Def in pairs(WeaponDefs) do
			local weaponID
			if Def.damageAreaOfEffect ~= nil and Def.damageAreaOfEffect > 16 and not nonexplosiveWeapons[Def.type] then
				Script.SetWatchWeapon(Def.id, true)
			end
		end
	end
end