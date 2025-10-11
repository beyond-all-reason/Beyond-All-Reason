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
local inertiaModifier = 2.0 -- Gradually reduces velocity with loss of damage.

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
local spGetGroundHeight        = Spring.GetGroundHeight
local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectilePosition  = Spring.GetProjectilePosition
local spGetProjectileVelocity  = Spring.GetProjectileVelocity
local spGetUnitHealth          = Spring.GetUnitHealth
local spGetUnitIsDead          = Spring.GetUnitIsDead
local spGetUnitPosition        = Spring.GetUnitPosition
local spGetUnitRadius          = Spring.GetUnitRadius
local spGetWaterLevel          = Spring.GetWaterLevel
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
			local params = {
				damages  = toSafeDamageArray(weaponDef.damages),
				falloff  = tobool(custom.overpenetrate_falloff == nil and falloffPerType[weaponDef.type] or custom.overpenetrate_falloff),
				slowing  = tobool(custom.overpenetrate_slowing == nil and slowingPerType[weaponDef.type] or custom.overpenetrate_slowing),
				penalty  = max(0, tonumber(custom.overpenetrate_penalty or penaltyDefault)),
				weaponID = weaponDefID,
				impulse  = weaponDef.damages.impulseFactor,
			}

			if params.slowing and not params.falloff then
				params.slowing = false
			end

			if custom.shield_damage then
				local multiplier = tonumber(custom.beamtime_damage_reduction_multiplier or 1)
				params.damages[armorShields] = tonumber(custom.shield_damage) * multiplier
			end

			weaponParams[weaponDefID] = params

			if weaponDef.waterWeapon then
				waterWeapons[weaponDefID] = true
			end
		end
	end
	return (table.count(weaponParams) > 0)
end

---Projectiles with noexplode can move after colliding, so we infer an impact location.
---The hit can be a glance, so find the nearest point, not a line/sphere intersection.
---Slow explosion speeds can delay us until after position and direction are knowable.
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
			py = my - dy * radius
			pz = mz - dz * radius
		end
	end
	return px, py, pz
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
	local function sortByDistanceSquared(a, b)
		return a.distanceSquared < b.distanceSquared
	end

	sortPenetratorCollisions = function (collisions, projectileID, penetrator)
		for index = 1, #collisions do
			local collision = collisions[index]
			local distanceSquared, cx, cy, cz
			if collision.targetID then
				if collision.hitX then
					cx, cy, cz = collision.hitX, collision.hitY, collision.hitZ
				else
					cx, cy, cz = getCollisionPosition(projectileID, collision.targetID, collision.isUnit)
				end
			end
			if cx then
				cx, cy, cz = cx - penetrator.posX, cy - penetrator.posY, cz - penetrator.posZ
				distanceSquared = cx * cx + cy * cy + cz * cz
			else
				distanceSquared = math.huge
			end
			collision.distanceSquared = distanceSquared
		end
		table.sort(collisions, sortByDistanceSquared)
	end
end

---Generic damage against shields using the default engine shields.
-- TODO: Remove this function when shieldsrework modoption is made mandatory. However:
-- TODO: If future modoptions might override the rework, then keep this function.
local function addShieldDamage(shieldUnitID, shieldWeaponIndex, damageToShields, weaponDefID, projectileID)
	local exhausted, damageDone = false, 0
	local state, health = Spring.GetUnitShieldState(shieldUnitID)
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

function gadget:GameFramePost(gameFrame)
	-- Remove `or addShieldDamage` when shieldsrework is adopted.
	local addShieldDamage = GG.AddShieldDamage or addShieldDamage
	local setVelocityControl = GG.SetVelocityControl

	for projectileID, penetrator in pairs(projectileHits) do
		projectileHits[projectileID] = nil

		local collisions = penetrator.collisions

		if collisions[2] then
			sortPenetratorCollisions(collisions, projectileID, penetrator)
		end

		local speedRatio = 1

		for index = 1, #collisions do
			local collision = collisions[index]
			local targetID = collision.targetID

			if not targetID then
				speedRatio = 0
			elseif collision.shieldID then
				if spGetUnitIsDead(targetID) == false then
					local weapon = penetrator.params
					local damageLeftBefore = penetrator.damageLeft
					local damageToShields = collision.damage
					local deleted, damage = addShieldDamage(targetID, collision.shieldID, damageToShields * damageLeftBefore, weapon.weaponID, projectileID)
					local damageLeftAfter = damageLeftBefore - damage / damageToShields - weapon.penalty
					if deleted or damageToShields * damageLeftAfter < 1 then
						speedRatio = 0
					elseif weapon.falloff then
						if weapon.slowing then
							speedRatio = speedRatio * (1 + inertiaModifier * damageLeftAfter) / (1 + inertiaModifier * damageLeftBefore)
						end
						penetrator.damageLeft = damageLeftAfter
					end
				end
			else
				local targetIsValid
				if collision.isUnit then
					targetIsValid = spGetUnitIsDead(targetID) == false
				else
					targetIsValid = spValidFeatureID(targetID)
				end

				if targetIsValid then
					local weapon = penetrator.params
					local damage = collision.damage
					local damageToArmorType = weapon.damages[collision.armorType]

					local damageLeftBefore = penetrator.damageLeft
					local damageBase = min(damage, damageToArmorType) * damageLeftBefore
					local damageLeftAfter = damageLeftBefore - collision.health / damageBase - weapon.penalty
					damage = damage * damageLeftBefore

					local impulse = weapon.impulse
					if damageToArmorType * damageLeftAfter > 1 and collision.healthMax * damageThreshold <= damageBase then
						if weapon.falloff then
							if weapon.slowing then
								speedRatio = speedRatio * (1 + inertiaModifier * damageLeftAfter) / (1 + inertiaModifier * damageLeftBefore)
							end
							penetrator.damageLeft = damageLeftAfter
						end
					else
						impulse = impulse * (1 + inertiaModifier) / (1 + inertiaModifier * damageLeftBefore)
						speedRatio = 0
					end

					if collision.isUnit then
						if setVelocityControl and impulse > 1 then
							setVelocityControl(targetID, true)
						end
						impulse = impulse * damageBase
						spAddUnitDamage(
							targetID, damage, nil,
							penetrator.ownerID, weapon.weaponID,
							penetrator.dirX * impulse,
							penetrator.dirY * impulse,
							penetrator.dirZ * impulse
						)
					else
						-- Features do not have an impulse limiter (like unit_collision_damage_behavior),
						-- so apply damage only with no impulse. They also must be destroyed manually:
						local health = collision.health - damage
						if health > 1 then
							Spring.SetFeatureHealth(targetID, health)
						else
							Spring.DestroyFeature(targetID)
						end
					end
				end
			end

			if speedRatio == 0 then
				break
			end
		end

		if speedRatio == 0 then
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
		local damage = penetrator.params.damages[armorShields]
		if damage > 1 then
			projectileHits[projectileID] = penetrator
			local collisions = penetrator.collisions
			collisions[#collisions+1] = {
				targetID = shieldUnitID,
				shieldID = shieldWeaponIndex,
				damage   = damage,
				hitX     = hitX,
				hitY     = hitY,
				hitZ     = hitZ,
			}
		end
		return true
	end
end
