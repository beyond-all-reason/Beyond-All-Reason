
function gadget:GetInfo()
  return {
    name      = "Collision Damage Modifier",
    desc      = "Modifies collision and fall event damage",
    author    = "REVENGE",
    date      = "06 Jan 2013",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  -- DISABLED FOR BUGGINESS!
  }
end

-- Thanks to Google Frog for raising the issue and implementing his "Fall damage" gadget

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
    return
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Note: 10 should restore close to original behavior since Kloot changed the multiplier
-- from 0.2f -> 0.02f in the source code
local UNIT_DAMAGE_MULT = 10 -- Unit<->Unit collisions
local FALL_DAMAGE_MULT = 10 -- Unit<->Ground collisions

-- weaponDefID -1 --> debris collision
-- weaponDefID -2 --> ground collision
-- weaponDefID -3 --> object collision
-- weaponDefID -4 --> fire damage
-- weaponDefID -5 --> kill damage

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	-- unit collision
	if weaponDefID == -3 and attackerID == nil then
		--[[Spring code:
			const float impactDamageMult = std::min(impactSpeed * collider->mass * MASS_MULT, MAX_UNIT_SPEED);
			]]
		-- Damage upper limit is given by MAX_UNIT_SPEED, which is 1e3f as of 91.0
	
		return damage * UNIT_DAMAGE_MULT	
	end
	
	-- ground collision
	if weaponDefID == -2 and attackerID == nil then		
		--[[Spring code:
			const float impactSpeed = midPos.IsInBounds()?
			-speed.dot(ground->GetNormal(midPos.x, midPos.z)):
			-speed.dot(UpVector);
			impactDamageMult = impactSpeed * owner->mass * 0.2f --(is 0.02f as of latest)
			]]
		-- Fall damage does not appear to be limited by a ceiling (hurr hurr)

		return damage * FALL_DAMAGE_MULT
	end
	return damage
end