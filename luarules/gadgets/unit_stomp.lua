function gadget:GetInfo()
	return {
		name      = "Experimental Bots Steps Damages",
		desc      = "Controls damages done by exp units footsteps",
		author    = "Doo",
		date      = "July 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Exhaustive list of all units that will take damages from krog's footsteps (must be completed)
local isStompedUnit = {}
for udid, ud in pairs(UnitDefs) do
	if string.find(ud.name, 'armfav') then       -- using string.find to _scav units are included aswell
		isStompedUnit[udid] = true
	end
	if string.find(ud.name, 'corfav') then
		isStompedUnit[udid] = true
	end
	if string.find(ud.name, 'corak') then
		isStompedUnit[udid] = true
	end
	if string.find(ud.name, 'armpw') then
		isStompedUnit[udid] = true
	end
	if string.find(ud.name, 'armflea') then
		isStompedUnit[udid] = true
	end
	if string.find(ud.name, 'leggob') then
		isStompedUnit[udid] = true
	end
end

local krogkickWeapon = {}
local kargkickWeapon = {}
for weaponDefID, def in pairs(WeaponDefs) do
	if string.find(def.name, 'krogkick') then
		krogkickWeapon[weaponDefID] = true
	end
	if string.find(def.name, 'kargkick') then
		kargkickWeapon[weaponDefID] = true
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if krogkickWeapon[weaponDefID] then
		if unitTeam and attackerTeam then
			if Spring.AreTeamsAllied(unitTeam, attackerTeam) == false then
				if isStompedUnit[unitDefID] then
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
	return damage, 1
end
