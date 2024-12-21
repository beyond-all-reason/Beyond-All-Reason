function gadget:GetInfo()
    return {
        name      = "Debris Explosions",
        desc      = "Handles debris explosions: removes its damage and adds a CEG effect",
        author    = "Doo",
        date      = "Dec 9th 2017",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return
end


-- CEG setup: For more spawn chance of a certain ceg, copy it multiple times in the table...
local cegtospawn = {
    "genericshellexplosion-debris",
    "genericshellexplosion-debris2",
}
local numcegtospawn = #cegtospawn

function gadget:Initialize()
	Script.SetWatchExplosion(-1, true) -- well that doesnt register anything!
end

function gadget:ProjectileDestroyed(proID) -- Catch debris explosions, get position, pick random ceg, spawn it at position.
	local _, piece = Spring.GetProjectileType(proID)
	if piece then
        local px, py, pz = Spring.GetProjectilePosition(proID)
        local i = (proID % numcegtospawn) + 1 -- pseudo random
        if px and py and pz then
            Spring.SpawnCEG(cegtospawn[i], px, py, pz, 0, 1, 0, 50, 0)
        end
	end
end

-- Remove damage hardcoded in the engine of gibbed pieces of units (hardcoded to 50 damage in engine)
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if weaponDefID == -1 then
		return 0, 0
	end
	return damage, 1
end
