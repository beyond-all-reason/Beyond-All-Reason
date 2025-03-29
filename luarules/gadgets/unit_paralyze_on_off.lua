local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Paralyze On Off Behavior',
        desc      = 'Turns units off if stunned in 1 hit',
        author    = 'Itanthias',
        version   = 'v1.0',
        date      = 'May 2023',
        license   = 'GNU GPL, v2 or later',
        layer     = 12, -- check after all paralyze damage modifiers
        enabled   = true
    }
end


if not gadgetHandler:IsSyncedCode() then
    return false
end

local off_on_stun = {} 
for uDefID, uDef in pairs(UnitDefs) do
	-- should be mostly units, like jammers, that are scripted to turn off
	-- when stunned that should have this parameter set
	off_on_stun[uDefID] = uDef.customParams.off_on_stun or false
end

function gadget:UnitPreDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, projID, aID, aDefID, aTeam)
    if paralyzer then --check if paralyzer
		if off_on_stun[uDefID] == "true" then --check if should be turned off on stun
			-- check to see if this hit will stun 
			local health, maxHealth, paralyzeDamage = Spring.GetUnitHealth(uID)
			if paralyzeDamage + damage > maxHealth then
				-- turn off unit if it will stun
				Spring.SetUnitCOBValue(uID, COB.ACTIVATION, 0)
			end
		end
    end
    return damage, 1
end
