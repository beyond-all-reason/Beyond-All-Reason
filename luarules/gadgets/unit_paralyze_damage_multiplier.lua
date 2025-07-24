local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Paralyze Damage Multiplier',
        desc      = 'Applies Paralyze damage resistance',
        author    = 'Niobium',
        version   = 'v1.0',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end


if not gadgetHandler:IsSyncedCode() then
    return false
end

local paralyzeMultipliers = {} -- paralyzeMultipliers[uDefID] = uDef.customParams.paralyzemultiplier or 1
for uDefID, uDef in pairs(UnitDefs) do
	paralyzeMultipliers[uDefID] = uDef.customParams.paralyzemultiplier or 1
end

function gadget:UnitPreDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, projID, aID, aDefID, aTeam)
    if paralyzer then
        -- apply customParams paralyse multiplier
        local paralyzeMultiplier = paralyzeMultipliers[uDefID]
		
		
		if Spring.GetModOptions().emprework==true then
		
			if paralyzeMultiplier==1 then
				--paralyzeMultiplier = 0.6 --a new default EMP resistance for everything
			end
		
		end
		return damage * paralyzeMultiplier, paralyzeMultiplier
    end
    return damage, 1
end
