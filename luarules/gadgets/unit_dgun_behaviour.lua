local gadget = gadget ---@type Gadget

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
local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetGroundHeight = Spring.GetGroundHeight
local spDeleteProjectile = Spring.DeleteProjectile
local spSpawnExplosion = Spring.SpawnExplosion
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spGetGameFrame = Spring.GetGameFrame

local mathSqrt = math.sqrt
local mathMax = math.max
local pairsNext = next

local addShieldDamage -- see unit_shield_behaviour

local dgunData = {}
local dgunDef = {}
local dgunTimeouts = {}
local dgunShieldPenetrations = {}

local function generateWeaponTtlFunction(weaponDef)
	local range = weaponDef.range
	local speed = weaponDef.projectilespeed

	-- Not handling anything between 0 and 1:
	if weaponDef.cylinderTargeting >= 1 then
		return function(unitID, projectileID)
			local ux, uy, uz = spGetUnitPosition(unitID)
			local px, py, pz = spGetProjectilePosition(projectileID)
			local dx, dy, dz = spGetProjectileDirection(projectileID)
			local projection = (px - ux) * dx + (pz - uz) * dz
			return (range - projection) / speed
		end
	else -- treat all other as cylinder == 0:
		return function(unitID, projectileID)
			local _, _, _, ux, uy, uz = spGetUnitPosition(unitID, true)
			local px, py, pz = spGetProjectilePosition(projectileID)
			local dx, dy, dz = spGetProjectileDirection(projectileID)
			local projection = (px - ux) * dx + (py - uy) * dy + (pz - uz) * dz
			return (range - projection) / speed
		end
	end
end

for weaponDefID = 0, #WeaponDefs do
	local weaponDef = WeaponDefs[weaponDefID]
	if weaponDef.type == 'DGun' then
		Script.SetWatchProjectile(weaponDefID, true)
		dgunDef[weaponDefID] = weaponDef
		dgunDef[weaponDefID].ttl = generateWeaponTtlFunction(weaponDef)
	end
end

local isCommander = {}
local isDecoyCommander = {}
local commanderNames = {}

for unitDefID = 1, #UnitDefs do
	local unitDef = UnitDefs[unitDefID]
	if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander then
		isCommander[unitDefID] = true
		commanderNames[unitDef.name] = true
	end
end

for unitDefID = 1, #UnitDefs do
	local unitDef = UnitDefs[unitDefID]
	if unitDef.customParams.decoyfor and commanderNames[unitDef.customParams.decoyfor] then
		isDecoyCommander[unitDefID] = true
	end
end

commanderNames = nil

local flyingDGuns = {}
local groundedDGuns = {}

local function addVolumetricDamage(projectileID)
	local projectileData = dgunData[projectileID]
	local weaponDefID = projectileData.weaponDefID
	local x, y, z = spGetProjectilePosition(projectileID)
	local explosionParame = {
		weaponDef = weaponDefID,
		owner = projectileData.proOwnerID,
		projectileID = projectileID,
		damages = dgunDef[weaponDefID].damages,
		hitUnit = 1,
		hitFeature = 1,
		craterAreaOfEffect = dgunDef[weaponDefID].craterAreaOfEffect,
		damageAreaOfEffect = dgunDef[weaponDefID].damageAreaOfEffect,
		edgeEffectiveness = dgunDef[weaponDefID].edgeEffectiveness,
		explosionSpeed = dgunDef[weaponDefID].explosionSpeed,
		impactOnly = dgunDef[weaponDefID].impactOnly,
		ignoreOwner = dgunDef[weaponDefID].noSelfDamage,
		damageGround = true,
	}

	spSpawnExplosion(x, y, z, 0, 0, 0, explosionParame)
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if dgunDef[weaponDefID] then
		dgunData[proID] = { proOwnerID = proOwnerID, weaponDefID = weaponDefID }
		flyingDGuns[proID] = true
		dgunTimeouts[proID] = spGetGameFrame() + dgunDef[weaponDefID].ttl(proOwnerID, proID)
	end
end

function gadget:ProjectileDestroyed(proID)
	flyingDGuns[proID] = nil
	groundedDGuns[proID] = nil
	dgunTimeouts[proID] = nil
	dgunShieldPenetrations[proID] = nil
	dgunData[proID] = nil
end

function gadget:GameFrame(frame)
	for proID in pairsNext, flyingDGuns do
		-- Fireball is hitscan while in flight, engine only applies AoE damage after hitting the ground,
		-- so we need to add the AoE damage manually for flying projectiles
		addVolumetricDamage(proID)

		local x, y, z = spGetProjectilePosition(proID)
		local h = spGetGroundHeight(x, z)

		if y < h + 1 or y < 0 then -- assume ground or water collision
			-- normalize horizontal velocity
			local dx, _, dz, speed = spGetProjectileVelocity(proID)
			local horizontalMagnitude = mathSqrt(dx ^ 2 + dz ^ 2)

			-- Safeguard against division by zero (when projectile has no horizontal velocity)
			if horizontalMagnitude > 1e-5 and speed > 0 then
				local norm = speed / horizontalMagnitude
				local ndx = dx * norm
				local ndz = dz * norm
				spSetProjectileVelocity(proID, ndx, 0, ndz)
			end

			groundedDGuns[proID] = true
			flyingDGuns[proID] = nil
		end
	end

	for proID in pairsNext, groundedDGuns do
		local x, y, z = spGetProjectilePosition(proID)
		-- place projectile slightly under ground to ensure fiery trail
		local verticalOffset = 1
		spSetProjectilePosition(proID, x, mathMax(spGetGroundHeight(x, z), 0) - verticalOffset, z)

		-- NB: no removal; do this every frame so that it doesn't fly off a cliff or something
	end

	-- Without defining a time to live (TTL) for the DGun, it will live forever until it reaches maximum range. This means it would deal infinite damage to shields until it depleted them.
	for proID, timeout in pairsNext, dgunTimeouts do
		if frame > timeout then
			spDeleteProjectile(proID)
			flyingDGuns[proID] = nil
			groundedDGuns[proID] = nil
			dgunTimeouts[proID] = nil
		end
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID,
							   attackerDefID, attackerTeam)
	if dgunDef[weaponDefID] and isCommander[attackerDefID] and (isCommander[unitDefID] or isDecoyCommander[unitDefID]) then
		if isDecoyCommander[unitDefID] then
			return dgunDef[weaponDefID].damages[0]
		else
			spDeleteProjectile(projectileID)
			local x, y, z = spGetUnitPosition(unitID)
			spSpawnCEG("dgun-deflect", x, y, z, 0, 0, 0, 0, 0)
			local armorClass = UnitDefs[unitDefID].armorType
			return dgunDef[weaponDefID].damages[armorClass]
		end
	end

	return damage
end

---@type ShieldPreDamagedCallback
local function shieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
	if proID > -1 and dgunData[proID] then
		local proData = dgunData[proID]
		local weaponDefID = proData.weaponDefID
		local shieldBreak = dgunShieldPenetrations[proID] or {}

		if not shieldBreak[shieldCarrierUnitID] then
			local mitigated = addShieldDamage(shieldCarrierUnitID, nil, weaponDefID)

			if not mitigated then
				shieldBreak[shieldCarrierUnitID] = true
				dgunShieldPenetrations[proID] = shieldBreak
				return true
			end

			-- DGuns do not get bounced back by shields, so we reset its position ourselves.
			local dx, dy, dz = spGetProjectileDirection(proID)
			local speed = dgunDef[weaponDefID].projectilespeed
			spSetProjectilePosition(proID, hitX - dx * speed, hitY - dy * speed, hitZ - dz * speed)
		end

		return true
	end
end

function gadget:Initialize()
	if not GG.Shields then
		Spring.Log("ScriptedWeapons", LOG.ERROR, "Shields API unavailable (dgun)")
		return
	end

	addShieldDamage = GG.Shields.AddShieldDamage
	GG.Shields.RegisterShieldPreDamaged(dgunData, shieldPreDamaged)
end
