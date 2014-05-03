function gadget:GetInfo()
  return {
    name      = "Debris Damage",
    desc      = "Controls damage done by flying unit debris",
    author    = "Bluestone",
    date      = "May 2014",
    license   = "Horses",
    layer     = 0,
    enabled   = true
  }
end

if (not gadgetHandler:IsSyncedCode()) then return end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	-- debris damage occurs when weaponDefID == -1
	-- in this case attackerID and attackerDefID are nil
	if weaponDefID == -1 then 
		return math.min(damage, math.random(15,35)), nil
	end
	return damage, nil
end