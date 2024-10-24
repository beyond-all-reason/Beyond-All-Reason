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
-- 5. Aimpoints are often too low to align through more than one enemy unit.
-- 6. Probably should replace explode_def with explode_ceg, unless it's in use.
-- 7. Damage is consumed but not dealt to crashing aircraft. Hard to care about.

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageThreshold  = 0.1 -- Minimum damage% vs. max health that will penetrate.
local explodeThreshold = 0.3 -- Minimum damage% that detonates, rather than piercing.
local hardStopIncrease = 2.0 -- Reduces the impulse falloff when damage is reduced.

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

local slowdownPerType = { -- Whether the projectile loses velocity, as well.
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
--        overpenetrate_explode_def := <string> | nil
--    }
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local min  = math.min
local sqrt = math.sqrt

local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectilePosition  = Spring.GetProjectilePosition
local spGetProjectileVelocity  = Spring.GetProjectileVelocity
local spGetUnitHealth          = Spring.GetUnitHealth
local spGetUnitPosition        = Spring.GetUnitPosition
local spGetUnitRadius          = Spring.GetUnitRadius
local spSetProjectileVelocity  = Spring.SetProjectileVelocity
local spDeleteProjectile       = Spring.DeleteProjectile
local spSpawnExplosion         = Spring.SpawnExplosion
local spSpawnProjectile        = Spring.SpawnProjectile

local gameSpeed  = Game.gameSpeed
local mapGravity = Game.gravity / (gameSpeed * gameSpeed) * (-1)
local untyped    = Game.armorTypes.default

--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

-- Find all weapons with an over-penetration behavior.

local weaponParams = {}
local explosionParams = {}
local unitArmorType = {}

-- Track projectiles and their remaining damage and prevent re-collisions.

local projectiles = {}
local collisions = {}

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

	local weaponDefBaseIndex = 0
	for weaponDefID = weaponDefBaseIndex, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponDefID]
		local custom = weaponDef.customParams
		if weaponDef.noExplode and tobool(custom.overpenetrate) then
			local params = {
				damages = toSafeDamageArray(weaponDef.damages),
				falloff = tobool(custom.overpenetrate_falloff == nil and falloffPerType [weaponDef.type] or custom.overpenetrate_falloff),
				slowing = tobool(custom.overpenetrate_slowing == nil and slowdownPerType[weaponDef.type] or custom.overpenetrate_slowing),
				penalty = math.max(0, tonumber(custom.overpenetrate_penalty or penaltyDefault)),
			}

			if params.slowing and not params.falloff then
				params.slowing = false
			end

			if custom.overpenetrate_explode_def then
				local explosionDef = WeaponDefNames[custom.overpenetrate_explode_def]
				params.explosionDefID = explosionDef and explosionDef.id or nil
			end

			weaponParams[weaponDefID] = params
		end
	end

	-- Spring.SpawnExplosion merges these explosion params into a default-initialized table,
	-- so default values can be ignored from the lua side to pass less data to the engine:
	local explosionDefaults = {
		craterAreaOfEffect   = 0,
		damageAreaOfEffect   = 0,
		edgeEffectiveness    = 0,
		explosionSpeed       = 0,
		gfxMod               = 0,
		maxGroundDeformation = 0,
		impactOnly           = false,
		ignoreOwner          = false,
		damageGround         = false,
	}

	for weaponDefID, params in pairs(weaponParams) do
		if params.explosionDefID then
			local explosionDefID = params.explosionDefID
			local explosionDef = WeaponDefs[explosionDefID]

			local cached = {
				weaponDef          = explosionDefID,
				damages            = explosionDef.damages,
				damageAreaOfEffect = explosionDef.damageAreaOfEffect,
				edgeEffectiveness  = explosionDef.edgeEffectiveness,
				explosionSpeed     = explosionDef.explosionSpeed,
				ignoreOwner        = explosionDef.noSelfDamage,
				damageGround       = explosionDef.damageground,
				craterAreaOfEffect = explosionDef.craterAreaOfEffect,
				impactOnly         = explosionDef.impactOnly,
				hitFeature         = explosionDef.impactOnly and -1 or nil,
				hitUnit            = explosionDef.impactOnly and -1 or nil,
				owner              = -1,
			}

			for key, value in pairs(explosionDefaults) do
				if cached[key] == value then
					cached[key] = nil
				end
			end

			explosionParams[explosionDefID] = cached
		end
	end

	return (next(weaponParams) ~= nil)
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
	if mx then
		-- Nearest point on a line/ray to the surface of a sphere:
		local t = min(0, dx * (mx - px) + dy * (my - py) + dz * (mz - pz))
		local d = sqrt((px + t*dx - mx)^2 + (py + t*dy - my)^2 + (pz + t*dz - mz)^2) - radius
		if radius + d ~= 0 then
			px = mx + (px + t*dx - mx) * radius / (radius + d)
			py = my + (py + t*dy - my) * radius / (radius + d)
			pz = mz + (pz + t*dz - mz) * radius / (radius + d)
		else -- The ray passes through the midpoint.
			px = mx - dx * radius
			py = mx - dy * radius
			pz = mx - dz * radius
		end
	end
	return px, py, pz, dx, dy, dz
end

---Reorder stored PreDamaged events by their proximity to the start position.
local function orderByTrajectory(a, b)
	return a.sx ^ 2 + a.sy ^ 2 + a.sz ^ 2 <=
	       b.sx ^ 2 + b.sy ^ 2 + b.sz ^ 2
end

--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
	if not loadPenetratorWeaponDefs() then
		Spring.Log(gadget:GetInfo().name, LOG.INFO,
			"No weapons with over-penetration found. Removing.")
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

function gadget:GameFrame(frame)
	local mod = hardStopIncrease
	for projectileID, penetrator in pairs(collisions) do
		local weaponData = penetrator.params
		local x, y, z = penetrator.x, penetrator.y, penetrator.z

		if #penetrator.impacts > 1 then
			for index, impact in ipairs(penetrator.impacts) do
				impact.sx = impact.collideX - x
				impact.sy = impact.collideY - y
				impact.sz = impact.collideZ - z
			end
	
			if true then
				-- check if the collisions had to be reordered (!) to process correctly
				local first = penetrator.impacts[1]
				table.sort(penetrator.impacts, orderByTrajectory)
				if #penetrator.impacts > 1 and first.targetID ~= penetrator.impacts[1].targetID then
					for index, impact in ipairs(penetrator.impacts) do
						Spring.MarkerAddPoint(impact.collideX, impact.collideY, impact.collideZ, index)
					end
				end
			else
				table.sort(penetrator.impacts, orderByTrajectory)
			end
		end

		local exhausted = false
		local speedRatio = 1

		for index, impact in ipairs(penetrator.impacts) do
			if impact.isDestroy then				
				exhausted = true
			else
				local damage = impact.damage
				local damageToArmorType = penetrator.damages[impact.armorType]
				local damageBase = min(damage, damageToArmorType)
	
				local damageLeftBefore = penetrator.damageLeft
				local damageLeftAfter
				if weaponData.falloff then
					damage = damage * damageLeftBefore
					damageBase = damageBase * damageLeftBefore
					damageLeftAfter = damageLeftBefore - impact.health / damageBase - weaponData.penalty
				else
					damageLeftAfter = 1
				end
	
				local impulse = 1
				if damageToArmorType * damageLeftAfter > 1 and impact.healthMax * damageThreshold <= damageBase then
					penetrator.damageLeft = damageLeftAfter
					if weaponData.slowing then
						speedRatio = speedRatio * (1 + mod * damageLeftAfter) / (1 + mod * damageLeftBefore)
					end
				else
					exhausted = true
					impulse = (1 + mod) / (1 + mod * min(1, damageBase / damageToArmorType))
				end
	
				if impact.isUnit then
					Spring.AddUnitDamage(impact.targetID, damage, 0, penetrator.ownerID, penetrator.weaponDefID, impulse * impact.headingX, impulse * impact.headingY, impulse * impact.headingZ)
				else
					Spring.SetFeatureHealth(impact.targetID, impact.health - damage)
				end
			end

			if exhausted then
				collisions[projectileID] = nil
				projectiles[projectileID] = nil
				spDeleteProjectile(projectileID)
				if penetrator.explosion then
					local explosion = penetrator.explosion
					explosion.owner = penetrator.ownerID
					if explosion.impactOnly then
						if impact.isUnit then
							explosion.hitFeature = nil
							explosion.hitUnit = impact.targetID
						else
							explosion.hitFeature = impact.targetID
							explosion.hitUnit = nil
						end
					end
					spSpawnExplosion(impact.collideX, impact.collideY, impact.collideZ, -impact.headingX, -impact.headingY, -impact.headingZ, explosion)
				end
				break
			end
		end

		if not exhausted and speedRatio < 1 then
			local vx, vy, vz = spGetProjectileVelocity(projectileID)
			spSetProjectileVelocity(projectileID, vx * speedRatio, vy * speedRatio, vz * speedRatio)
		end
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	local params = weaponParams[weaponDefID]
	if params then
		local explosionDefID = params.explosionDefID
		local explosion = explosionDefID and explosionParams[explosionDefID] or nil
		local x, y, z = Spring.GetProjectilePosition(projectileID)
		collisions[projectileID] = nil
		projectiles[projectileID] = {
			damageLeft  = 1,
			damages     = params.damages,
			explosion   = explosion,
			ownerID     = ownerID,
			params      = params,
			weaponDefID = weaponDefID,
			-- {Unit,Feature}PreDamaged events can occur out of logical order.
			-- So we record them, sort by their positions, and replay them.
			impacts     = {},
			x           = x,
			y           = y,
			z           = z,
		}
	end
end

function gadget:ProjectileDestroyed(projectileID)
	local penetrator = projectiles[projectileID]
	if penetrator then
		if penetrator.explosion then
			local px, py, pz = spGetProjectilePosition(projectileID)
			if px then
				local dx, dy, dz = spGetProjectileDirection(projectileID)
				local impacts = penetrator.impacts
				impacts[#impacts+1] = {
					isDestroy = true,
					collideX  = px,
					collideY  = py,
					collideZ  = pz,
					headingX  = dx,
					headingY  = dy,
					headingZ  = dz,
				}
			end
			projectiles[projectileID] = nil
		end
	end
end

local function eventData(targetID, isUnit, health, healthMax, armorType, damage, collideX, collideY, collideZ, headingX, headingY, headingZ)
	return {
		targetID  = targetID,
		isUnit    = isUnit,
		health    = health,
		healthMax = healthMax,
		armorType = armorType,
		damage    = damage,
		collideX  = collideX,
		collideY  = collideY,
		collideZ  = collideZ,
		headingX  = headingX,
		headingY  = headingY,
		headingZ  = headingZ,
	}
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	local penetrator = projectiles[projectileID]
	if penetrator then
		if damage > 1 then
			collisions[projectileID] = penetrator
			local health, healthMax = spGetUnitHealth(unitID)
			local cx, cy, cz, dx, dy, dz = getCollisionPosition(projectileID, unitID, true)
			local impacts = penetrator.impacts
			impacts[#impacts+1] = eventData(
				unitID, true, health, healthMax, unitArmorType[unitDefID],
				damage, cx, cy, cz, dx, dy, dz
			)
		end
		return 0, 0
	end
end

function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	local penetrator = projectiles[projectileID]
	if penetrator then
		if damage > 1 then
			collisions[projectileID] = penetrator
			local health, healthMax = Spring.GetFeatureHealth(featureID)
			local cx, cy, cz, dx, dy, dz = getCollisionPosition(projectileID, featureID, false)
			local impacts = penetrator.impacts
			impacts[#impacts+1] = eventData (
				featureID, false, health, healthMax, untyped,
				damage, cx, cy, cz, dx, dy, dz
			)
		end
		return 0, 0
	end
end
