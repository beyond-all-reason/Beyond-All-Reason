function gadget:GetInfo()
	return {
		name    = 'Impactor Over-Penetration',
		desc    = 'Projectiles punch through targets with custom stop behavior.',
		author  = 'efrec',
		version = '1.0',
		date    = '2024-10',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return false end


--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageThreshold  = 0.1 -- Minimum damage% vs. max health that will penetrate.
local explodeThreshold = 0.3 -- Minimum damage% that detonates, rather than piercing.
local hardStopIncrease = 2.0 -- Reduces the impulse falloff when damage is reduced.
local maxVisualLatency = 0.1 -- Max time spent in non-existence before respawning.

-- Default customparam values

local penaltyDefault   = 0.02 -- Additional damage% loss per hit.

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
--        overpenetrate_respawn_def := <string> | nil (spawns same weaponDef)
--    }
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local min  = math.min
local atan = math.atan
local cos  = math.cos

local spGetProjectileDirection  = Spring.GetProjectileDirection
local spGetProjectilePosition   = Spring.GetProjectilePosition
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity   = Spring.GetProjectileVelocity
local spGetUnitHealth           = Spring.GetUnitHealth
local spGetUnitPosition         = Spring.GetUnitPosition
local spGetUnitRadius           = Spring.GetUnitRadius
local spSpawnExplosion          = Spring.SpawnExplosion
local spSpawnProjectile         = Spring.SpawnProjectile

local gameSpeed  = Game.gameSpeed
local mapGravity = Game.gravity / (gameSpeed * gameSpeed) * (-1)

--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

local maxRespawnLatency = maxVisualLatency * gameSpeed

-- Find all weapons with an over-penetration behavior.

local weaponParams = {}
local explosionParams = {}
local unitArmorType = {}

-- Keep track of projectiles, respawning projectiles, and remaining damage.

local projectiles = {}
local respawning = {}
local waiting = {}
local ignoreRespawn = false
local gameFrame

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function loadPenetratorWeaponDefs()
	local function tobool(value)
		return value ~= nil and value ~= false and value ~= 0
	end

	-- Prevents a divide-by-zero by substituting arbitrary, small damage values.
	local function getSafeDamageArray(damages)
		local safeDamages = {}
		local armorTypesBaseIndex = 0
		for ii = armorTypesBaseIndex, #Game.armorTypes do
			safeDamages[ii] = damages[ii] ~= 0 and damages[ii] or 1
		end
		return safeDamages
	end

	local weaponDefBaseIndex = 0
	for weaponDefID = weaponDefBaseIndex, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponDefID]
		local custom = weaponDef.customParams
		if custom and tobool(custom.overpenetrate) then
			local params = {
				damages = getSafeDamageArray(weaponDef.damages),
				falloff = tobool(custom.overpenetrate_falloff == nil and falloffPerType[weaponDef.type] or custom.overpenetrate_falloff),
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

			if custom.overpenetrate_respawn_def then
				local respawnDefID = (WeaponDefNames[custom.overpenetrate_respawn_def] or weaponDef).id
				if respawnDefID ~= weaponDefID then
					params.respawnDefID = respawnDefID
					local respawnDef = WeaponDefs[respawnDefID]

					local oldDefVelocity = weaponDef.weaponvelocity
					local newDefVelocity = respawnDef.weaponvelocity
					params.speedRatio = newDefVelocity / oldDefVelocity

					local oldDefLifetime = weaponDef.flighttime or 0
					local newDefLifetime = respawnDef.flighttime or 0
					if oldDefLifetime <= 0 then
						oldDefLifetime = math.max(1, math.ceil(weaponDef.range / oldDefVelocity))
					end
					if newDefLifetime <= 0 then
						newDefLifetime = math.max(1, math.ceil(respawnDef.range / newDefVelocity))
					end
					params.ttlRatio = newDefLifetime / oldDefLifetime
				end
			end

			weaponParams[weaponDefID] = params
		end
	end

	-- Make corrections for mismatched main-penetrator and respawn-penetrator defs:
	for weaponDefID, params in pairs(weaponParams) do
		if params.respawnDefID then
			local respawnDefID = params.respawnDefID
			local respawnParams = weaponParams[respawnDefID]
			if (not params.slowing) or (not respawnParams.slowing) then
				params.speedRatio = nil
			end
			if params.falloff and (not respawnParams.falloff) then
				params.speedRatio = nil
			end
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
				projectileID       = -1,
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

---Translate the remaining energy of a projectile to its speed and impulse.
local function inertia(damageLeft)
	local modifier = hardStopIncrease
	return (1 + modifier) / (1 + modifier * damageLeft)
end

---Create an explosion around the impact point of a projectile (with an explode_def).
local function spawnPenetratorExplosion(explosionDefID, projectileID, attackerID, targetID, isUnit)
	local px, py, pz = spGetProjectilePosition(projectileID)
	local dx, dy, dz = spGetProjectileDirection(projectileID)
	local explosion = explosionParams[explosionDefID]
	explosion.owner = attackerID
	explosion.projectileID = projectileID
	if explosion.impactOnly then
		if isUnit then
			explosion.hitFeature = nil
			explosion.hitUnit = targetID
		else
			explosion.hitFeature = targetID
			explosion.hitUnit = nil
		end
	end
	spSpawnExplosion(px, py, pz, dx, dy, dz, explosion)
end

---Remove a projectile from tracking and determine its effect on the target.
local function getPenetratorDamage(targetID, isUnit, health, healthMax, damageToArmorType, damage, projectileID, attackerID)
	local penetrator = projectiles[projectileID]
	local damageBase = min(damage, damageToArmorType)
	local damageLeft = penetrator.damageLeft
	local weaponData = penetrator.params

	local damageIsDecreasing = weaponData.falloff
	if damageIsDecreasing then
		damage = damage * damageLeft
		damageBase = damageBase * damageLeft
		damageLeft = damageLeft - health / damageBase - weaponData.penalty
	end

	if damageLeft > 0 and damageBase >= healthMax * damageThreshold then
		-- Projectile over-penetrates the target.
		local respawnDefID = weaponData.respawnDefID
		if respawnDefID and not weaponParams[respawnDefID].falloff then
			penetrator.damageLeft = 1
		elseif damageIsDecreasing then
			penetrator.damageLeft = damageLeft
		end
		respawning[projectileID] = penetrator
		return damage
	else
		-- Projectile arrests on impact with the target.
		local explosionDefID = weaponData.explosionDefID
		if explosionDefID then
			spawnPenetratorExplosion(explosionDefID, projectileID, attackerID, targetID, isUnit)
		end
		local damageDone = min(1, damageBase / damageToArmorType)
		return damage, inertia(damageDone) * damageDone
	end
end

---Simulate over-penetration by recreating the original projectile or creating a new one.
local function spawnPenetratorProjectile(targetID, isUnit, radius, mx, my, mz, weaponDefID, projectileID, attackerID)
	local penetrator = respawning[projectileID]
	local weaponData = penetrator.params
	local px, py, pz = spGetProjectilePosition(projectileID)
	local timeToLive = spGetProjectileTimeToLive(projectileID)
	local vx, vy, vz, speed = spGetProjectileVelocity(projectileID)

	if speed == 0 then return end

	if weaponData.slowing then
		local speedLeft = inertia(penetrator.damageLeft)
		vx, vy, vz, speed = vx * speedLeft, vy * speedLeft, vz * speedLeft, speed * speedLeft
	end

	if weaponData.respawnDefID then
		weaponDefID = weaponData.respawnDefID
		penetrator.params = weaponParams[weaponDefID] -- nil if not also a penetrator
		local speedLeft = weaponData.speedRatio -- nil if either def is non-inertial, e.g. lasers
		if not speedLeft then
			speedLeft = WeaponDefs[weaponDefID].weaponvelocity / speed
			if penetrator.params.slowing then
				-- This outcome makes no sense, but it hasn't been ruled out, so calc it:
				speedLeft = speedLeft * inertia(penetrator.damageLeft)
			end
		end
		vx, vy, vz, speed = vx * speedLeft, vy * speedLeft, vz * speedLeft, speed * speedLeft
		timeToLive = timeToLive * weaponData.ttlRatio
	end

	-- Get the time to travel to a position opposite the target's sphere collider.
	local frames = (radius / speed) * (2/3) * (
		cos(atan((mx - px) / radius - vx / speed)) +
		cos(atan((my - py) / radius - vy / speed)) +
		cos(atan((mz - pz) / radius - vz / speed))
	)

	if frames < timeToLive and frames < maxRespawnLatency then
		local projectileParams = {
			owner = attackerID,
			pos   = { px + frames * vx, py + frames * vy, pz + frames * vz },
			speed = { vx, vy - mapGravity * 0.5 * frames ^ 2, vz },
			ttl   = timeToLive,
		}

		-- Penetrators accumulate error to bias their respawns to the next frame.
		-- This minimizes both the net positional error after multiple respawns
		-- and the risk of a very-fast penetrator frame-skipping through targets.
		local predict = frames + penetrator.frameError

		-- This also biases the respawn time to the next frame:
		if predict < 0.5 then
			ignoreRespawn = true
			local spawnID = spSpawnProjectile(weaponDefID, projectileParams)
			ignoreRespawn = false
			if spawnID and penetrator.params then
				penetrator.frameError = predict -- Time gain => increase error
				projectiles[spawnID] = penetrator
			end
		else
			local spawn = {
				frame            = gameFrame + predict,
				projectileDefID  = weaponDefID,
				projectileParams = projectileParams,
				ownerID          = attackerID,
			}
			projectileParams.ttl = timeToLive - predict -- Time loss => forward error
			if penetrator.params then
				penetrator.frameError = 0 -- => reset error
				spawn.penetrator = penetrator
			end
			waiting[#waiting+1] = spawn
		end
	else
		local explosionDefID = weaponData.explosionDefID
		if explosionDefID then
			spawnPenetratorExplosion(explosionDefID, projectileID, attackerID, targetID, isUnit)
		end
	end
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

	gameFrame = Spring.GetGameFrame()
end

function gadget:GameFrame(frame)
	local checkFrame = frame + 0.5
	ignoreRespawn = true
	for index, spawn in pairs(waiting) do
		if spawn.frame <= checkFrame then
			local projectileID = spSpawnProjectile(spawn.projectileDefID, spawn.projectileParams)
			if projectileID then
				projectiles[projectileID] = spawn.penetrator
			end
			waiting[index] = nil
		end
	end
	ignoreRespawn = false
	gameFrame = frame
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if weaponParams[weaponDefID] and not ignoreRespawn then
		projectiles[projectileID] = {
			damageLeft = 1,
			frameError = 0,
			ownerID    = ownerID,
			params     = weaponParams[weaponDefID],
		}
	end
end

function gadget:ProjectileDestroyed(projectileID)
	if projectiles[projectileID] then
		local penetrator = projectiles[projectileID]
		projectiles[projectileID] = nil
		local explosionDefID = penetrator.params.explosionDefID
		if explosionDefID then
			spawnPenetratorExplosion(explosionDefID, projectileID, penetrator.ownerID)
		end
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	local penetrator = projectiles[projectileID]
	if penetrator then
		if damage > 0 then
			local health, healthMax = spGetUnitHealth(unitID)
			local damageToArmorType = penetrator.params.damages[unitArmorType[unitDefID]]
			return getPenetratorDamage(unitID, true, health, healthMax, damageToArmorType, damage, projectileID, attackerID)
		end
		projectiles[projectileID] = nil
	end
end

function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	local penetrator = projectiles[projectileID]
	if penetrator then
		if damage > 0 then
			local health, healthMax = Spring.GetFeatureHealth(featureID)
			local damageToArmorType = penetrator.params.damages[0]
			return getPenetratorDamage(featureID, false, health, healthMax, damageToArmorType, damage, projectileID, attackerID)
		end
		projectiles[projectileID] = nil
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	if respawning[projectileID] then
		if damage > 0 then
			local radius = spGetUnitRadius(unitID)
			local _, _, _, mx, my, mz = spGetUnitPosition(unitID, true)
			spawnPenetratorProjectile(unitID, true, radius, mx, my, mz, weaponDefID, projectileID, attackerID)
		end
		respawning[projectileID] = nil
	end
end

function gadget:FeatureDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	if respawning[projectileID] then
		if damage > 0 then
			local radius = Spring.GetFeatureRadius(featureID)
			local _, _, _, mx, my, mz = Spring.GetFeaturePosition(featureID, true)
			spawnPenetratorProjectile(featureID, false, radius, mx, my, mz, weaponDefID, projectileID, attackerID)
		end
		respawning[projectileID] = nil
	end
end
