local enabled = Spring.GetModOptions().newdgun

function gadget:GetInfo()
	return {
		name = "D-Gun Behaviour",
		desc = "Alters D-Gun projectile behaviour, deterministic damage against Commanders",
		author = "Anarchid, Sprung",
		layer = 0,
		enabled = enabled
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local isDGun = {}
local isCommander = {}
local flyingDGuns = {}
local groundedDGuns = {}
local damagedUnits = {}

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if isDGun[weaponDefID] then
		flyingDGuns[proID] = true
	end
end

function gadget:ProjectileDestroyed(proID)
	flyingDGuns[proID] = nil
	groundedDGuns[proID] = nil
	damagedUnits[proID] = nil
end

function gadget:GameFrame()
	for proID in pairs (flyingDGuns) do
		local x, y, z = Spring.GetProjectilePosition (proID)
		local h = Spring.GetGroundHeight (x, z)
		if y < h + 1 then -- assume ground collision
			groundedDGuns[proID] = true
			flyingDGuns[proID] = false
		end
	end

	for proID in pairs (groundedDGuns) do
		local x, y, z = Spring.GetProjectilePosition (proID)
		local h = Spring.GetGroundHeight (x, z)
		Spring.SetProjectilePosition (x, h, z)

		-- normalize horizontal velocity
		local dx, _, dz, speed = Spring.GetProjectileVelocity (proID)
		local norm = speed / (dx^2 + dz^2)
		local ndx = dx^2 * norm
		local ndz = dz^2 * norm
		Spring.SetProjectileVelocity (ndx, 0, ndz)

		-- NB: no removal; do this every frame so that
		-- it doesn't fly off a cliff or something
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if isDGun[weaponDefID] then
		if isCommander[unitDefID] and isCommander[attackerDefID] then
			local armorClass = UnitDefs[unitDefID].armorType
			local dgunFixedDamage = WeaponDefs[weaponDefID].damages[armorClass]

			damagedUnits[projectileID] = damagedUnits[projectileID] or {}

			if damagedUnits[projectileID][unitID] then
				return 0
			else
				damagedUnits[projectileID][unitID] = true
				return dgunFixedDamage
			end
		end
	end

	return damage
end

function gadget:Initialize()
	for weaponDefID, weaponDef in ipairs(WeaponDefs) do
		if weaponDef.type == 'DGun' then
			isDGun[weaponDefID] = true
		end
	end

	for unitDefID, unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.iscommander then
			isCommander[unitDefID] = true
		end
	end
end
