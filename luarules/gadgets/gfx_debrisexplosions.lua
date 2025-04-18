local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Debris Explosions",
        desc      = "Spawns CEG for debris explosions",
        author    = "Doo",
        date      = "Dec 9th 2017",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

-- TODO: Fold this into one gadget with all the other silly projectile ceg spawners!
-- TODO: piece explo arent even registered
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then

--CEG setup: For more spawn chance of a certain ceg, copy it multiple times in the table...
local cegtospawn = {
    "genericshellexplosion-debris",
    "genericshellexplosion-debris2",
}
local numcegtospawn = #cegtospawn

function gadget:Initialize()
	Script.SetWatchExplosion(-1, true) -- well that doesnt register anything!
end

local spGetProjectileType = Spring.GetProjectileType
local spSpawnCEG = Spring.SpawnCEG
local spGetProjectilePosition = Spring.GetProjectilePosition

function gadget:ProjectileDestroyed(proID) -- Catch debris explosions, get position, pick random ceg, spawn it at position.
	local weapon, piece = spGetProjectileType(proID)
	--Spring.Echo(proID, piece)

	if piece then
				--Spring.Echo("explosion")
        local px, py, pz = spGetProjectilePosition(proID)
        local i = (proID % numcegtospawn) + 1 -- pseudo random
        if px and py and pz then
            spSpawnCEG(cegtospawn[i], px, py, pz, 0, 1, 0, 50, 0)
        end
	end
end

end