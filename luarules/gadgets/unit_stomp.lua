function gadget:GetInfo()
  return {
    name      = "Experimental Bots Steps Damages",
    desc      = "Controls damages done by exp units footsteps",
    author    = "Doo",
    date      = "July 2017",
    license   = "Whatever you want, lua will make it",
    layer     = 0,
    enabled   = true
  }
end

if (not gadgetHandler:IsSyncedCode()) then return end
-- Exhaustive list of all units that will take damages from krog's footsteps (must be completed)
local StompedUnits = {}
for udid, ud in pairs(UnitDefs) do
	if string.find(ud.name, 'armfav') then       -- using string.find to _scav units are included aswell
		StompedUnits[udid] = true
	end
	if string.find(ud.name, 'corfav') then
		StompedUnits[udid] = true
	end
	if string.find(ud.name, 'corak') then
		StompedUnits[udid] = true
	end
	if string.find(ud.name, 'armpw') then
		StompedUnits[udid] = true
	end
	if string.find(ud.name, 'armflea') then
		StompedUnits[udid] = true
	end
end

local krogkickWeapon = {}
local kargkickWeapon = {}
for weaponDefID, def in pairs(WeaponDefs) do
	if def.name == "corkrog_krogkick" then
		krogkickWeapon[weaponDefID] = true
	end
	if def.name == "corkarg_kargkick" then
		kargkickWeapon[weaponDefID] = true
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if WeaponDefs[weaponDefID] then
		if krogkickWeapon[weaponDefID] then
			if (unitTeam) and (attackerTeam) then
			if Spring.AreTeamsAllied(unitTeam, attackerTeam) == false then

				if StompedUnits[unitDefID] then
					return 2000, 0
				else
					return 0, 0
				end
			else
				return 0, 0
			end
			end
		elseif kargkickWeapon[weaponDefID] then
			return 0, 0
		end
	end
	return damage, nil
end