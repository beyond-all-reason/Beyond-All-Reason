function gadget:GetInfo()
	return {
		name = "D-Gun Behaviour",
		desc = "D-Gun projectiles hug ground, volumetric damage, deterministic damage against Commanders, override interactions with shields",
		author = "Anarchid, Sprung, SethDGamre",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetUnitShieldState = Spring.GetUnitShieldState
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetUnitShieldState = Spring.SetUnitShieldState
local spGetGroundHeight = Spring.GetGroundHeight
local spDeleteProjectile = Spring.DeleteProjectile
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spSpawnExplosion = Spring.SpawnExplosion
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spGetGameFrame = Spring.GetGameFrame

local modOptions = Spring.GetModOptions()
local dgunWeaponsTTL = {}
local dgunWeapons = {}
local dgunTimeouts = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.type == 'DGun' then
		Script.SetWatchProjectile(weaponDefID, true)
		dgunWeapons[weaponDefID] = weaponDef
		dgunWeaponsTTL[weaponDefID] = weaponDef.range / weaponDef.projectilespeed
	end
end

local isCommander = {}
local isDecoyCommander = {}
local commanderNames = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander then
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
	local weaponDefID = spGetProjectileDefID(projectileID)
	local ownerID = spGetProjectileOwnerID(projectileID)
	local x,y,z =spGetProjectilePosition(projectileID)
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

	spSpawnExplosion(x, y ,z, 0, 0, 0, explosionParame)
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if dgunWeapons[weaponDefID] then
		flyingDGuns[proID] = true
		dgunTimeouts[proID] = (spGetGameFrame() + dgunWeaponsTTL[weaponDefID])
	end
end

function gadget:ProjectileDestroyed(proID)
	flyingDGuns[proID] = nil
	groundedDGuns[proID] = nil
	dgunTimeouts[proID] = nil
end

function gadget:GameFrame(frame)
	for proID in pairs(flyingDGuns) do
		-- Fireball is hitscan while in flight, engine only applies AoE damage after hitting the ground,
		-- so we need to add the AoE damage manually for flying projectiles
		addVolumetricDamage(proID)

		local x, y, z = spGetProjectilePosition(proID)
		local h = spGetGroundHeight(x, z)

		if y < h + 1 or y < 0 then -- assume ground or water collision
			-- normalize horizontal velocity
			local dx, _, dz, speed = spGetProjectileVelocity(proID)
			local norm = speed / math.sqrt(dx^2 + dz^2)
			local ndx = dx * norm
			local ndz = dz * norm
			spSetProjectileVelocity(proID, ndx, 0, ndz)

			groundedDGuns[proID] = true
			flyingDGuns[proID] = nil
		end
	end

	for proID in pairs(groundedDGuns) do
		local x, y, z = spGetProjectilePosition(proID)
		-- place projectile slightly under ground to ensure fiery trail
		local verticalOffset = 1
		spSetProjectilePosition(proID, x, math.max(spGetGroundHeight(x, z), 0) - verticalOffset, z)

		-- NB: no removal; do this every frame so that it doesn't fly off a cliff or something
	end

	-- Without defining a time to live (TTL) for the DGun, it will live forever until it reaches maximum range. This means it would deal infinite damage to shields until it depleted them.
	for proID, timeout in pairs(dgunTimeouts) do
		if frame > timeout then
			spDeleteProjectile(proID)
			flyingDGuns[proID] = nil
			groundedDGuns[proID] = nil
			dgunTimeouts[proID] = nil
		end
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if dgunWeapons[weaponDefID] and isCommander[attackerDefID] and (isCommander[unitDefID] or isDecoyCommander[unitDefID]) then
		if isDecoyCommander[unitDefID] then
			return dgunWeapons[weaponDefID].damages[0]
		else
			spDeleteProjectile(projectileID)
			local x, y, z = spGetUnitPosition(unitID)
			spSpawnCEG("dgun-deflect", x, y, z, 0, 0, 0, 0, 0)
			local armorClass = UnitDefs[unitDefID].armorType
			return dgunWeapons[weaponDefID].damages[armorClass]
		end
	end

	return damage
end

local lastShieldFrameCheck = {}

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
	if proID > -1 and dgunTimeouts[proID] then
		local proDefID = spGetProjectileDefID(proID)
		local shieldEnabledState, shieldPower = spGetUnitShieldState(shieldCarrierUnitID)
		local damage = WeaponDefs[proDefID].damages[Game.armorTypes.shields] or WeaponDefs[proDefID].damages[Game.armorTypes.default]

		local gameframe = spGetGameFrame()

		if not modOptions.shieldsrework then
			local damageCooldownFrames = 10
			if shieldPower < damage then return false end

			lastShieldFrameCheck[shieldCarrierUnitID] = lastShieldFrameCheck[shieldCarrierUnitID] or gameframe

			if hitX > 0 and lastShieldFrameCheck[shieldCarrierUnitID] <= gameframe then
				shieldPower = math.max(shieldPower - damage, 0)
				spSetUnitShieldState(shieldCarrierUnitID, shieldEmitterWeaponNum, shieldEnabledState, shieldPower)
				lastShieldFrameCheck[shieldCarrierUnitID] = gameframe + damageCooldownFrames
			end
		end

		-- Engine does not provide a way for shields to stop DGun projectiles, they will impact once and carry on through,
		-- need to manually move them back a bit so the next touchdown hits the shield
		if shieldPower > 0 then
			-- Extra offset required to avoid edgecase where projectile penetrates, value chosen empirically
			local offsetFactor = 1.1
			local dx, dy, dz, speed = spGetProjectileVelocity(proID)
			local magnitude = math.sqrt(dx^2 + dy^2 + dz^2)
			local normalX, normalY, normalZ = dx / magnitude, dy / magnitude, dz / magnitude

			local x, y, z = spGetProjectilePosition(proID)
			local newX = x - speed * normalX * offsetFactor
			local newY = y - speed * normalY * offsetFactor
			local newZ = z - speed * normalZ * offsetFactor

			spSetProjectilePosition(proID, newX, newY, newZ)
		end

		return false
	end
end
