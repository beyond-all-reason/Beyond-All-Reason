--all we care about is how high the commander is when the COM_BLAST happens
--this is much simper than checking if the com has just been unloaded from a trans or not, with essentially the same gameplay; coms don't levitate/bounce much
--if the com is more than 10 off the ground, the comblast damage is reduced. consequence is that COM_BLAST should not be used for anything else

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "unit_combomb_full_damage",
		desc      = "Flying Combombs Do Less Damage",
		author    = "TheFatController, Bluestone",
		date      = "Dec 2012",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end


if not gadgetHandler:IsSyncedCode() then
	return false
end

local COM_BLAST = WeaponDefNames['commanderexplosion'].id

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam) --we use UnitPreDamaged so as we get in before unit_transportfix has its effect

	--Spring.Echo("UnitPreDamaged called with unitID " .. unitID .. " and attackerID ", attackerID)

	if weaponDefID == COM_BLAST and attackerID ~= nil and Spring.ValidUnitID(attackerID) then -- we control the damage inflicted on units by the COM_BLAST. Very rarely an invalid attackerID is returned with weaponID=COM_BLAST, I have no idea why/how.
		--Spring.Echo("weapon is comblast from unloaded com " .. attackerID)
		local x,y,z = Spring.GetUnitBasePosition(attackerID)
		local h = Spring.GetGroundHeight(x,z)
		--Spring.Echo(x .. " " .. y .. " " .. z .. " " .. h)
		if y-h > 10 then
			local newdamage = select(2, Spring.GetUnitHealth(unitID)) * 0.6
			if newdamage < 400 then
				newdamage = 400
			end
			if newdamage > damage then
				newdamage = damage
			end
			--Spring.Echo("new damage is " .. newdamage .. ", old damage is " .. damage .. ", hp is " .. hp)
			return newdamage,0
		end
	end
	return damage,1
end


