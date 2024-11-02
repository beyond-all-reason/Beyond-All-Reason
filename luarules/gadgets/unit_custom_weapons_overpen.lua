function gadget:GetInfo()
	return {
		name    = 'Penetrator Weapons',
		desc    = 'Customizes weapons to overpenetrate targets that they destroy.',
		author  = 'efrec',
		version = '1.0',
		date    = '2024-10',
		license = 'GNU GPL, v2 or later',
		layer   = -999991, -- Damage otherwise inflated in api_damage_stats.lua
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

-- Current issues
-- 1. When a penetrator leaves behind a wreck, it can damage the wreck, also.
-- 2. Projectile visuals overshoot the target somewhat, even when not piercing.
-- 3. Collisions trigger events without order; distant units are damaged first.
-- 4. No visual feedback for a weaker projectile vs. one at its full strength.

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageThreshold = 0.1 -- Minimum damage% vs. max health that will penetrate.
local inertiaModifier = 2.0 -- Gradually reduces velocity with loss of damage.

-- Default customparam values

local penaltyDefault   = 0.01 -- Additional damage% loss per hit.

local falloffPerType  = { -- Whether the projectile loses damage per hit.
	DGun              = false ,
	Cannon            = true  ,
	LaserCannon       = true  ,
	BeamLaser         = true  ,
	LightningCannon   = false , -- Use customparams.spark_forkdamage instead.
	Flame             = false , -- Use customparams.single_hit_multi instead.
	MissileLauncher   = true  ,
	StarburstLauncher = true  ,
	TorpedoLauncher   = true  ,
	AircraftBomb      = true  ,
}

local slowingPerType = { -- Whether the projectile loses velocity, as well.
	DGun              = false ,
	Cannon            = true  ,
	LaserCannon       = false ,
	BeamLaser         = false ,
	LightningCannon   = false , -- Use customparams.spark_forkdamage instead.
	Flame             = false , -- Use customparams.single_hit_multi instead.
	MissileLauncher   = true  ,
	StarburstLauncher = true  ,
	TorpedoLauncher   = true  ,
	AircraftBomb      = true  ,
}

--------------------------------------------------------------------------------
--
--    customparams = {
--        overpenetrate := true
--        overpenetrate_falloff := <boolean> | nil (see defaults)
--        overpenetrate_slowing := <boolean> | nil (see defaults)
--        overpenetrate_penalty := <number> | nil (see defaults)
--    }
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local min  = math.min
local sqrt = math.sqrt

local spGetFeatureHealth       = Spring.GetFeatureHealth
local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectilePosition  = Spring.GetProjectilePosition
local spGetProjectileVelocity  = Spring.GetProjectileVelocity
local spGetUnitHealth          = Spring.GetUnitHealth
local spGetUnitIsDead          = Spring.GetUnitIsDead
local spGetUnitPosition        = Spring.GetUnitPosition
local spGetUnitRadius          = Spring.GetUnitRadius
local spSetProjectileVelocity  = Spring.SetProjectileVelocity

local spAddUnitDamage          = Spring.AddUnitDamage
local spDeleteProjectile       = Spring.DeleteProjectile
local spValidFeatureID         = Spring.ValidFeatureID

local armorDefault = Game.armorTypes.default
local armorShields = Game.armorTypes.shields

--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

-- Find all weapons with an over-penetration behavior.

local weaponParams = {}
local unitArmorType = {}

-- Track projectiles and their remaining damage and sequence their collisions.

local projectiles = {}
local projectileHits = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function loadPenetratorWeaponDefs()
	local function tobool(value)
		return value ~= nil and value ~= false and value ~= 0
	end

	---Prevent a divide-by-zero by substituting arbitrary, small damage values.
	local function toSafeDamageArray(damages)
		local safeDamageArray = {}
		for ii = 0, #Game.armorTypes do
			safeDamageArray[ii] = damages[ii] ~= 0 and damages[ii] or 1
		end
		return safeDamageArray
	end

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		local custom = weaponDef.customParams
		if weaponDef.noExplode and tobool(custom.overpenetrate) then
			local params = {
				damages = toSafeDamageArray(weaponDef.damages),
				falloff = tobool(custom.overpenetrate_falloff == nil and falloffPerType[weaponDef.type] or custom.overpenetrate_falloff),
				slowing = tobool(custom.overpenetrate_slowing == nil and slowingPerType[weaponDef.type] or custom.overpenetrate_slowing),
				penalty = math.max(0, tonumber(custom.overpenetrate_penalty or penaltyDefault)),
				weapon  = weaponDefID,
			}

			if params.slowing and not params.falloff then
				params.slowing = false
			end

			if custom.shield_damage then
				local multiplier = tonumber(custom.beamtime_damage_reduction_multiplier or 1)
				params.damages[armorShields] = tonumber(custom.shield_damage) * multiplier
			end

			weaponParams[weaponDefID] = params
		end
	end

	return (table.count(weaponParams) > 0)
end

---Projectiles with noexplode can move after colliding, so we infer an impact location.
---The hit can be a glance, so find the nearest point, not a line/sphere intersection.
local function getCollisionPosition(projectileID, targetID, isUnit)
	local px, py, pz = spGetProjectilePosition(projectileID)
	local dx, dy, dz = spGetProjectileDirection(projectileID)
	local mx, my, mz, radius, _
	if targetID then
		if isUnit then
			_, _, _, mx, my, mz = spGetUnitPosition(targetID, true)
			radius = spGetUnitRadius(targetID)
		else
			_, _, _, mx, my, mz = Spring.GetFeaturePosition(targetID, true)
			radius = Spring.GetFeatureRadius(targetID)
		end
	end
	if px and mx then -- Nearest point on a line/ray to the surface of a sphere:
		local t = min(0, dx * (mx - px) + dy * (my - py) + dz * (mz - pz))
		local d = sqrt((px + t*dx - mx)^2 + (py + t*dy - my)^2 + (pz + t*dz - mz)^2) - radius
		if radius + d ~= 0 then
			local radiusNorm = radius / (radius + d)
			px = mx + (px + t*dx - mx) * radiusNorm
			py = my + (py + t*dy - my) * radiusNorm
			pz = mz + (pz + t*dz - mz) * radiusNorm
		else -- The ray passes through the midpoint.
			px = mx - dx * radius
			py = mx - dy * radius
			pz = mx - dz * radius
		end
	end
	return px, py, pz
end

local function addPenetratorCollision(targetID, isUnit, armorType, damage, projectileID, penetrator)
	local health, healthMax
	if isUnit then
		health, healthMax = spGetUnitHealth(targetID)
	else
		health, healthMax = spGetFeatureHealth(targetID)
	end

	projectileHits[projectileID] = penetrator

	local collisions = penetrator.collisions
	collisions[#collisions+1] = {
		targetID  = targetID,
		isUnit    = isUnit,
		health    = health,
		healthMax = healthMax,
		armorType = armorType,
		damage    = damage,
	}
end

local function sortPenetratorCollisions(a, b)
	return a.distanceSquared <= b.distanceSquared
end

---Generic damage against shields using the default engine shields.
local function addShieldDamage(shieldUnitID, shieldWeaponIndex, damageToShields, weaponDefID, projectileID)
	local exhausted, damageDone = false, 0
	local state, health = Spring.GetUnitShieldState(shieldUnitID)
	local SHIELD_STATE_ENABLED = 1 -- nb: not boolean
	if state == SHIELD_STATE_ENABLED and health > 0 then
		local healthLeft = math.max(0, health - damageToShields)
		if shieldWeaponIndex then
			Spring.SetUnitShieldState(shieldUnitID, shieldWeaponIndex, healthLeft)
		else
			Spring.SetUnitShieldState(shieldUnitID, healthLeft)
		end
		if healthLeft > 0 then
			exhausted, damageDone = true, damageToShields
		else
			exhausted, damageDone = false, health
		end
	end
	return exhausted, damageDone
end

--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
	if not loadPenetratorWeaponDefs() then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No weapons with over-penetration found. Removing.")
		gadgetHandler:RemoveGadget(self)
		return
	end

	for weaponDefID, params in pairs(weaponParams) do
		Script.SetWatchProjectile(weaponDefID, true)
	end

	for unitDefID, unitDef in ipairs(UnitDefs) do
		unitArmorType[unitDefID] = unitDef.armorType
	end
end

function gadget:GameFrame(gameFrame)
	-- stopgap until no longer handling multiple different shield behaviors
	local addShieldDamage = GG.AddShieldDamage or addShieldDamage

	for projectileID, penetrator in pairs(projectileHits) do
		projectileHits[projectileID] = nil

		local collisions = penetrator.collisions
		local params = penetrator.params

		local exhausted = false
		local speedRatio = 1

		if #collisions > 1 then
			for index = 1, #collisions do
				local collision = collisions[index]
				collision.distanceSquared = math.huge
				if collision.targetID then
					local cx, cy, cz
					if collision.collideX then
						cx, cy, cz = collision.collideX, collision.collideY, collision.collideZ
					else
						cx, cy, cz = getCollisionPosition(projectileID, collision.targetID, collision.isUnit)
					end
					if cx then
						local sx, sy, sz = cx - penetrator.x, cy - penetrator.y, cz - penetrator.z
						collision.distanceSquared = sx * sx + sy * sy + sz * sz
					end
				end
			end
			table.sort(collisions, sortPenetratorCollisions)
		end

		for index = 1, #collisions do
			local collision = collisions[index]
			local targetID = collision.targetID

			if targetID and not collision.shieldID then
				local targetIsValid
				if collision.isUnit then
					targetIsValid = spGetUnitIsDead(targetID) == false
				else
					targetIsValid = spValidFeatureID(targetID)
				end
				if targetIsValid then
					local damage = collision.damage
					local damageToArmorType = params.damages[collision.armorType]

					local damageLeftBefore = penetrator.damageLeft
					local damageBase = min(damage, damageToArmorType) * damageLeftBefore
					local damageLeftAfter = damageLeftBefore - collision.health / damageBase - params.penalty
					damage = damage * damageLeftBefore

					if damageToArmorType * damageLeftAfter > 1 and collision.healthMax * damageThreshold <= damageBase then
						if params.falloff then
							penetrator.damageLeft = damageLeftAfter
							if params.slowing then
								speedRatio = speedRatio * (1 + inertiaModifier * damageLeftAfter) / (1 + inertiaModifier * damageLeftBefore)
							end
						end
					else
						exhausted = true
					end

					if collision.isUnit then
						spAddUnitDamage(targetID, damage, 0, penetrator.ownerID, params.weapon)
					else
						Spring.SetFeatureHealth(targetID, collision.health - damage)
					end
				end
			elseif collision.shieldID then
				if spGetUnitIsDead(targetID) == false then
					local damageLeftBefore = penetrator.damageLeft
					local damageToShields = collision.damage
					local deleted, damage = addShieldDamage(targetID, collision.shieldID, damageToShields * damageLeftBefore, params.weapon, projectileID)
					local damageLeftAfter = damageLeftBefore - damage / damageToShields - params.penalty
					if deleted or damageToShields * damageLeftAfter < 1 then
						exhausted = true
					elseif params.falloff then
						penetrator.damageLeft = damageLeftAfter
						if params.slowing then
							speedRatio = speedRatio * (1 + inertiaModifier * damageLeftAfter) / (1 + inertiaModifier * damageLeftBefore)
						end
					end
				end
			elseif not targetID then
				exhausted = true
			end

			if exhausted then
				break
			end
		end

		if exhausted then
			projectiles[projectileID] = nil
			spDeleteProjectile(projectileID)
		else
			penetrator.collisions = {}
			if speedRatio < 1 then
				local vx, vy, vz = spGetProjectileVelocity(projectileID)
				spSetProjectileVelocity(projectileID, vx * speedRatio, vy * speedRatio, vz * speedRatio)
			end
		end
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	local params = weaponParams[weaponDefID]
	if params then
		local x, y, z = spGetProjectilePosition(projectileID)
		projectiles[projectileID] = {
			collisions = {},
			damageLeft = 1,
			ownerID    = ownerID,
			params     = params,
			x          = x,
			y          = y,
			z          = z,
		}
	end
end

local exhaustionEvent = {}

function gadget:ProjectileDestroyed(projectileID)
	local penetrator = projectiles[projectileID]
	if penetrator then
		projectileHits[projectileID] = penetrator
		local collisions = penetrator.collisions
		collisions[#collisions+1] = exhaustionEvent
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	local penetrator = projectiles[projectileID]
	if penetrator then
		if damage > 0 then
			addPenetratorCollision(unitID, true, unitArmorType[unitDefID], damage, projectileID, penetrator)
		end
		return 0, 0
	end
end

function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	local penetrator = projectiles[projectileID]
	if penetrator then
		if damage > 0 then
			addPenetratorCollision(featureID, false, armorDefault, damage, projectileID, penetrator)
		end
		return 0, 0
	end
end

function gadget:ShieldPreDamaged(projectileID, attackerID, shieldWeaponIndex, shieldUnitID, bounceProjectile, beamWeaponIndex, beamUnitID, startX, startY, startZ, hitX, hitY, hitZ)
	local penetrator = projectiles[projectileID]
	if penetrator then
		local damage = penetrator.params.damages[armorShields]
		if damage > 1 then
			projectileHits[projectileID] = penetrator
			local collisions = penetrator.collisions
			collisions[#collisions+1] = {
				targetID = shieldUnitID,
				shieldID = shieldWeaponIndex,
				damage   = damage,
				collideX = hitX,
				collideY = hitY,
				collideZ = hitZ,
			}
		end
		return true
	end
end
