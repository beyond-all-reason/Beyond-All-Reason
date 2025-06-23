local gadget = gadget ---@type Gadget

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

local stompable = {
	armfav = true,
	corfav = true,
	armflea = true,
	corak = true,
	armpw = true,
	leggob = true
}
local stompableCopy = table.copy(stompable)
for name,v in pairs(stompableCopy) do
	stompable[name..'_scav'] = true
end
local stompableDefs = {}
for udid, ud in pairs(UnitDefs) do
	if stompable[ud.name] then
		stompableDefs[udid] = v
	end
end

local krogkickWeapon = {}
for weaponDefID, def in pairs(WeaponDefs) do
	if string.find(def.name, 'krogkick') then
		krogkickWeapon[weaponDefID] = true
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if krogkickWeapon[weaponDefID] then
		if unitTeam and attackerTeam then
			if Spring.AreTeamsAllied(unitTeam, attackerTeam) == false then
				if stompableDefs[unitDefID] then
					return 2000, 0
				else
					return 0, 0
				end
			else
				return 0, 0
			end
		end
	end
	return damage, 1
end
