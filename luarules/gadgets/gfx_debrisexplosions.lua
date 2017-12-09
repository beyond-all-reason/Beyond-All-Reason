function gadget:GetInfo()
  return {
    name      = "Debris Explosions",
    desc      = "Spawns CEG for debris explosions",
    author    = "Doo",
    date      = "Dec 9th 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then

--CEG setup: For more spawn chance of a certain ceg, copy it multiple times in the table...
cegtospawn = {
    "genericshellexplosion-debris",
    "genericshellexplosion-debris",
    "genericshellexplosion-debris",
    "genericshellexplosion-debris",
    "genericshellexplosion-debris",
    "genericshellexplosion-debris2",
    "genericshellexplosion-debris2",
    "genericshellexplosion-debris2",
    "genericshellexplosion-debris2",
    "genericshellexplosion-debris2",
    "genericshellexplosion-debris2",
}

function gadget:Initialize()
	Script.SetWatchWeapon(-1, true)
end

function gadget:ProjectileDestroyed(proID) -- Catch debris explosions, get position, pick random ceg, spawn it at position.
	local weapon, piece = Spring.GetProjectileType(proID)
	if piece == true then
	-- Spring.Echo("explosion")
	local px, py, pz = Spring.GetProjectilePosition(proID)
	local i = math.random(1,#cegtospawn)
	if cegtospawn[i] and px and py and pz then
	Spring.SpawnCEG(cegtospawn[i], px, py, pz, 0, 1, 0, 50, 0)
	end
	end
end

end	