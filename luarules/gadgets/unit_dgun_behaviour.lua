local enabled = Spring.GetModOptions().newdgun

function gadget:GetInfo()
	return {
		name = "D-Gun Behaviour",
		desc = "D-Gun projectiles hug ground, deterministic damage against Commanders",
		author = "Anarchid, Sprung",
		layer = 0,
		enabled = false -- Disabled for now because d-gun has been replaced with EMP weapon
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
	for proID in pairs(flyingDGuns) do
		local x, y, z = Spring.GetProjectilePosition(proID)
		local h = Spring.GetGroundHeight(x, z)

		if y < h + 1 then -- assume ground collision
			-- normalize horizontal velocity
			local dx, _, dz, speed = Spring.GetProjectileVelocity(proID)
			local norm = speed / math.sqrt(dx^2 + dz^2)
			local ndx = dx * norm
			local ndz = dz * norm
			Spring.SetProjectileVelocity(proID, ndx, 0, ndz)

			groundedDGuns[proID] = true
			flyingDGuns[proID] = nil
		end
	end

	for proID in pairs(groundedDGuns) do
		local x, y, z = Spring.GetProjectilePosition(proID)
		local h = Spring.GetGroundHeight(x, z)
		local weaponDefID = Spring.GetProjectileDefID(proID)
		local size = WeaponDefs[weaponDefID].size
		-- Projectile placed 2x effect size underground to leave nice fiery trail
		Spring.SetProjectilePosition(proID, x, h - 2 * size, z)

		-- NB: no removal; do this every frame so that
		-- it doesn't fly off a cliff or something
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if isDGun[weaponDefID] and isCommander[unitDefID] and isCommander[attackerDefID] then
		damagedUnits[projectileID] = damagedUnits[projectileID] or {}

		if damagedUnits[projectileID][unitID] then
			return 0
		else
			local armorClass = UnitDefs[unitDefID].armorType
			local dgunFixedDamage = WeaponDefs[weaponDefID].damages[armorClass]
			damagedUnits[projectileID][unitID] = true
			return dgunFixedDamage
		end
	end

	return damage
end

function gadget:Initialize()
	for weaponDefID, weaponDef in ipairs(WeaponDefs) do
		if weaponDef.type == 'DGun' then
			Script.SetWatchProjectile(weaponDefID, true)
			isDGun[weaponDefID] = true
		end
	end

	for unitDefID, unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.iscommander then
			isCommander[unitDefID] = true
		end
	end
end
