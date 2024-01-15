function gadget:GetInfo()
	return {
		name = "D-Gun Behaviour",
		desc = "D-Gun projectiles hug ground, volumetric damage, deterministic damage against Commanders",
		author = "Anarchid, Sprung",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end
local dgunWeapons = {}
for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.type == 'DGun' then
		Script.SetWatchProjectile(weaponDefID, true)
		dgunWeapons[weaponDefID] = weaponDef
	end
end

local isCommander = {}
local isDecoyCommander = {}
local commanderNames = {}
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
		commanderNames[unitDef.name] = true
	end
end
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams.decoyfor and commanderNames[unitDef.customParams.decoyfor] then
		isDecoyCommander[unitDefID] = true
	end
end
commanderNames = nil

local flyingDGuns = {}
local groundedDGuns = {}

local function addVolumetricDamage(projectileID)
	local weaponDefID = Spring.GetProjectileDefID(projectileID)
	local ownerID = Spring.GetProjectileOwnerID(projectileID)
	local x,y,z = Spring.GetProjectilePosition(projectileID)
	local explosionParame ={
		weaponDef = weaponDefID,
		owner = ownerID,
		projectileID = projectileID,
		damages = dgunWeapons[weaponDefID].damages,
		hitUnit = 1,
		hitFeature = 1,
		craterAreaOfEffect = dgunWeapons[weaponDefID].craterAreaOfEffect,
		damageAreaOfEffect = dgunWeapons[weaponDefID].damageAreaOfEffect,
		edgeEffectiveness = dgunWeapons[weaponDefID].edgeEffectiveness,
		explosionSpeed = dgunWeapons[weaponDefID].explosionSpeed,
		impactOnly = dgunWeapons[weaponDefID].impactOnly,
		ignoreOwner = dgunWeapons[weaponDefID].noSelfDamage,
		damageGround = true,
	}
	Spring.SpawnExplosion(x, y ,z, 0, 0, 0, explosionParame)
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if dgunWeapons[weaponDefID] then
		flyingDGuns[proID] = true
	end
end

function gadget:ProjectileDestroyed(proID)
	flyingDGuns[proID] = nil
	groundedDGuns[proID] = nil
end

function gadget:GameFrame()
	for proID in pairs(flyingDGuns) do
		-- Fireball is hitscan while in flight, engine only applies AoE damage after hitting the ground,
		-- so we need to add the AoE damage manually for flying projectiles
		addVolumetricDamage(proID)

		local x, y, z = Spring.GetProjectilePosition(proID)
		local h = Spring.GetGroundHeight(x, z)

		if y < h + 1 or y < 0 then -- assume ground or water collision
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
		-- place projectile slightly under ground to ensure fiery trail
		local verticalOffset = 1
		Spring.SetProjectilePosition(proID, x, math.max(Spring.GetGroundHeight(x, z), 0) - verticalOffset, z)

		-- NB: no removal; do this every frame so that it doesn't fly off a cliff or something
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if dgunWeapons[weaponDefID] and isCommander[attackerDefID] and (isCommander[unitDefID] or isDecoyCommander[unitDefID]) then
		if isDecoyCommander[unitDefID] then
			return dgunWeapons[weaponDefID].damages[0]
		else
			Spring.DeleteProjectile(projectileID)
			local x, y, z = Spring.GetUnitPosition(unitID)
			Spring.SpawnCEG("dgun-deflect", x, y, z, 0, 0, 0, 0, 0)
			local armorClass = UnitDefs[unitDefID].armorType
			return dgunWeapons[weaponDefID].damages[armorClass]
		end
	end
	return damage
end
