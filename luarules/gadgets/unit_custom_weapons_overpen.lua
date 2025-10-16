local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Penetrator Weapons',
		desc    = 'Customizes weapons to overpenetrate targets that they destroy.',
		author  = 'efrec',
		version = '1.0',
		date    = '2024-10',
		license = 'GNU GPL, v2 or later',
		layer   = -1, -- before unit_collision_damage_behavior, unit_shield_behaviour
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return false end


--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageThreshold = 0.1 -- Minimum damage% vs. max health that will penetrate.

-- Default customparam values

local penaltyDefault = 0.01 -- Additional damage% loss per hit.

local falloffPerType  = { -- Whether the projectile loses damage per hit.
	DGun              = false ,
	Cannon            = true  ,
	LaserCannon       = true  ,
	BeamLaser         = true  ,
	LightningCannon   = false , -- Use customparams.spark_forkdamage instead.
	Flame             = false ,
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
	Flame             = false ,
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

local abs  = math.abs
local max  = math.max
local min  = math.min
local sqrt = math.sqrt

local spGetFeatureHealth       = Spring.GetFeatureHealth
local spGetFeaturePosition     = Spring.GetFeaturePosition
local spGetFeatureRadius       = Spring.GetFeatureRadius
local spGetGroundHeight        = Spring.GetGroundHeight
local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectilePosition  = Spring.GetProjectilePosition
local spGetProjectileVelocity  = Spring.GetProjectileVelocity
local spGetUnitHealth          = Spring.GetUnitHealth
local spGetUnitIsDead          = Spring.GetUnitIsDead
local spGetUnitPosition        = Spring.GetUnitPosition
local spGetUnitRadius          = Spring.GetUnitRadius
local spGetUnitShieldState     = Spring.GetUnitShieldState
local spGetWaterLevel          = Spring.GetWaterLevel

local spSetFeatureHealth       = Spring.SetFeatureHealth
local spSetProjectilePosition  = Spring.SetProjectilePosition
local spSetProjectileVelocity  = Spring.SetProjectileVelocity
local spSetProjectileMoveCtrl  = Spring.SetProjectileMoveControl

local spAddUnitDamage          = Spring.AddUnitDamage
local spDeleteProjectile       = Spring.DeleteProjectile
local spDestroyFeature         = Spring.DestroyFeature
local spValidFeatureID         = Spring.ValidFeatureID

local armorDefault = Game.armorTypes.default
local armorShields = Game.armorTypes.shields

--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

-- Find all weapons with an over-penetration behavior.

local weaponParams = {}
local waterWeapons = {}
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
		if weaponDef.impactOnly and weaponDef.noExplode and tobool(custom.overpenetrate) then
			local params = table.new(#Game.armorTypes, 1 + 5) -- `0` is stored in hash part

			local damages = toSafeDamageArray(weaponDef.damages)
			for i = 0, #Game.armorTypes do
				params[i] = damages[i]
			end

			params.falloff  = tobool(custom.overpenetrate_falloff == nil and falloffPerType[weaponDef.type] or custom.overpenetrate_falloff)
			params.slowing  = tobool(custom.overpenetrate_slowing == nil and slowingPerType[weaponDef.type] or custom.overpenetrate_slowing)
			params.penalty  = max(0, tonumber(custom.overpenetrate_penalty or penaltyDefault))
			params.weaponID = weaponDefID
			params.impulse  = weaponDef.damages.impulseFactor

			if params.slowing and not params.falloff then
				params.slowing = false
			end

			if custom.shield_damage then
				local multiplier = tonumber(custom.beamtime_damage_reduction_multiplier or 1)
				params[armorShields] = tonumber(custom.shield_damage) * multiplier
			end

			weaponParams[weaponDefID] = params

			if weaponDef.waterWeapon then
				waterWeapons[weaponDefID] = true
			end
		end
	end
	return (table.count(weaponParams) > 0)
end

local function dot3(a, b, c, d, e, f)
	return a * d + b * e + c * f
end

---Projectiles with noexplode can move after colliding, so we infer an impact location.
---The hit can be a glance, so find the nearest point, not a line/sphere intersection.
---Slow explosion speeds can delay us until after position and direction are knowable.
local function getCollisionPosition(projectileID, targetID, isUnit)
	local px, py, pz = spGetProjectilePosition(projectileID)
	local dx, dy, dz = spGetProjectileDirection(projectileID)
	local mx, my, mz, radius, _
	if px then
		if isUnit then
			_, _, _, mx, my, mz = spGetUnitPosition(targetID, true)
			radius = spGetUnitRadius(targetID)
		else
			_, _, _, mx, my, mz = spGetFeaturePosition(targetID, true)
			radius = spGetFeatureRadius(targetID)
		end
	end

	if not mx then
		return px, py, pz -- invalid target
	end

	local radiusSq = radius * radius
	local travel = -1e3 - radius

	-- Undo the travel of the ray (massive overshoot is okay) so we can
	-- do much faster math and without my code agent committing sepuku.
	px = px + dx * travel
	py = py + dy * travel
	pz = pz + dz * travel

	local rx = mx - px
	local ry = my - py
	local rz = mz - pz
	local b = dot3(rx, ry, rz, dx, dy, dz)
	local c = dot3(rx, ry, rz, rx, ry, rz) - radiusSq

	-- Construction with a ray-sphere rather than line-sphere argument
	-- can fail but offers better precision for more accurate visuals:
	if b * b < radiusSq and c > 0 then
		return px, py, pz -- ray-sphere disjoint
	end

	-- Nearest approach, relative to sphere center:
	local ax = rx - dx * b
	local ay = ry - dy * b
	local az = rz - dz * b
	local a = dot3(ax, ay, az, ax, ay, az)

	if a >= radiusSq then
		return mx + ax, my + ay, mz + az -- ray-sphere approach
	else
		local separation = sqrt(radiusSq - a)
		return
			mx - ax - dx * separation, -- ray-sphere intersection
			my - ay - dy * separation,
			mz - az - dz * separation
	end
end

local function addPenetratorProjectile(projectileID, ownerID, params)
	local dx, dy, dz = spGetProjectileDirection(projectileID)
	local px, py, pz = spGetProjectilePosition(projectileID)
	projectiles[projectileID] = {
		collisions = {},
		damageLeft = 1,
		ownerID    = ownerID,
		params     = params,
		posX       = px,
		posY       = py,
		posZ       = pz,
		dirX       = dx,
		dirY       = dy,
		dirZ       = dz,
	}
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
		health    = max(health, 1),
		healthMax = healthMax,
		armorType = armorType,
		damage    = damage,
	}
end

local sortPenetratorCollisions
do
	local table_sort = table.sort
	local math_huge = math.huge

	local function sortByDistanceSquared(a, b)
		return a.distanceSquared < b.distanceSquared
	end

	sortPenetratorCollisions = function(collisions, projectileID, penetrator)
		for index = 1, #collisions do
			local collision = collisions[index]
			local distanceSquared, cx, cy, cz
			if collision.targetID then
				if collision.hitX then
					cx, cy, cz = collision.hitX, collision.hitY, collision.hitZ
				else
					cx, cy, cz = getCollisionPosition(projectileID, collision.targetID, collision.isUnit)
					collision.hitX, collision.hitY, collision.hitZ = cx, cy, cz
				end
			end
			if cx then
				local dx, dy, dz = cx - penetrator.posX, cy - penetrator.posY, cz - penetrator.posZ
				distanceSquared = dx * dx + dy * dy + dz * dz
			else
				distanceSquared = math_huge
			end
			collision.distanceSquared = distanceSquared
		end
		table_sort(collisions, sortByDistanceSquared)
	end
end

local function falloffRatio(before, after)
	return (1 + 2 * after) / (1 + 2 * before)
end

---Due to our time-travel shenanigans, move the projectile backwards (remove its momentum?)
-- and delete it only after that. This may help to correct projectile visuals. Not sure.
local function exhaust(projectileID, collision)
	local cx, cy, cz
	if not collision.hitX then
		if collision.targetID then
			cx, cy, cz = getCollisionPosition(projectileID, collision.targetID, collision.isUnit)
		end
	else
		cx, cy, cz = collision.hitX, collision.hitY, collision.hitZ
	end
	if cx then
		spSetProjectileMoveCtrl(projectileID, true)
		spSetProjectilePosition(projectileID, cx, cy, cz)
		spSetProjectileVelocity(projectileID, 0, 0, 0) -- Messes up smoke trails.
	end
	projectiles[projectileID] = nil
	spDeleteProjectile(projectileID)
end

---Generic damage against shields using the default engine shields.
-- TODO: Remove this function when shieldsrework modoption is made mandatory. However:
-- TODO: If future modoptions might override the rework, then keep this function.
local function addShieldDamageDefault(shieldUnitID, shieldWeaponIndex, damageToShields, weaponDefID, projectileID)
	if shieldUnitID then
		local exhausted, damageDone = false, 0
		local state, health = spGetUnitShieldState(shieldUnitID)
		local SHIELD_STATE_ENABLED = 1 -- nb: not boolean
		if state == SHIELD_STATE_ENABLED and health > 0 then
			local healthLeft = max(0, health - damageToShields)
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

function gadget:GameFramePost()
	local addShieldDamage = GG.AddShieldDamage or addShieldDamageDefault
	local setVelocityControl = GG.SetVelocityControl

	local projectileHits = projectileHits
	for projectileID, penetrator in pairs(projectileHits) do
		projectileHits[projectileID] = nil
		local collisions = penetrator.collisions

		if collisions[2] then
			sortPenetratorCollisions(collisions, projectileID, penetrator)
		end

		local lastHit
		local weapon, damageLeftBefore = penetrator.params, penetrator.damageLeft
		local hasFalloff, penalty, factor = weapon.falloff, weapon.penalty, weapon.impulse
		local damageLeft = damageLeftBefore

		for index = 1, #collisions do
			local collision = collisions[index]

			local targetID = collision.targetID
			local shieldNumber = targetID and collision.shieldID
			local isTargetUnit = targetID and (collision.isUnit or shieldNumber) and true or false

			if not targetID or (isTargetUnit and spGetUnitIsDead(targetID) ~= false) or (not isTargetUnit and not spValidFeatureID(targetID)) then
				lastHit = collision
				break
			end

			-- Damage from the engine includes bonuses (flanking) and penalties (edge, intensity)
			-- but has not accounted for the damage falloff from the overpenetration effect, yet.
			local damageEngine, damageArmor = collision.damage, weapon[collision.armorType]
			local damageDealt, damageBase = damageEngine * damageLeft, min(damageEngine, damageArmor) * damageLeft

			if shieldNumber then
				local deleted, damage = addShieldDamage(targetID, shieldNumber, damageDealt, weapon.weaponID, projectileID)
				damageLeft = deleted and 0 or damageLeft - damage / damageDealt - penalty -- shields force falloff
			else
				damageLeft = damageLeft - penalty - (hasFalloff and collision.health / damageBase or 0)

				if isTargetUnit then
					local impulse = damageBase * factor * falloffRatio(damageLeft, 1) -- inverse ratio
					setVelocityControl(targetID, true)
					spAddUnitDamage(
						targetID,
						damageDealt,
						0,
						penetrator.ownerID,
						weapon.weaponID,
						penetrator.dirX * impulse,
						penetrator.dirY * impulse,
						penetrator.dirZ * impulse
					)
				else
					local health = collision.health - damageDealt
					if health > 1 then
						spSetFeatureHealth(targetID, health)
					else
						spDestroyFeature(targetID)
					end
				end
			end

			if damageArmor * damageLeft > 1 and damageBase >= collision.healthMax * damageThreshold then
				collisions[index] = nil
			else
				lastHit = collision
				break
			end
		end

		if lastHit then
			exhaust(projectileID, lastHit)
		else
			penetrator.damageLeft = damageLeft
			if weapon.slowing then
				local speedRatio = falloffRatio(damageLeftBefore, damageLeft)
				local vx, vy, vz = spGetProjectileVelocity(projectileID)
				spSetProjectileVelocity(projectileID, vx * speedRatio, vy * speedRatio, vz * speedRatio)
			end
		end
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	local params = weaponParams[weaponDefID]
	if params then
		addPenetratorProjectile(projectileID, ownerID, params)
	end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
	if projectileID and projectiles[projectileID] then
		-- Only process collisions with terrain or water.
		local elevation = spGetGroundHeight(px, pz)

		if not waterWeapons[weaponDefID] then
			elevation = max(elevation, spGetWaterLevel(px, pz))
		end

		if abs(elevation - py) < 0.5 then
			local penetrator = projectiles[projectileID]
			projectileHits[projectileID] = penetrator
			local collisions = penetrator.collisions
			collisions[#collisions+1] = {
				hitX = px,
				hitY = py,
				hitZ = pz,
			}
		end
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
		local damage = penetrator.params[armorShields]
		if damage > 1 and shieldUnitID and shieldWeaponIndex then
			projectileHits[projectileID] = penetrator
			local state, health = spGetUnitShieldState(shieldUnitID, shieldWeaponIndex)
			local collisions = penetrator.collisions
			collisions[#collisions+1] = {
				targetID  = shieldUnitID,
				shieldID  = shieldWeaponIndex,
				healthMax = health,
				damage    = damage,
				hitX      = hitX,
				hitY      = hitY,
				hitZ      = hitZ,
			}
		end
		return true
	end
end
