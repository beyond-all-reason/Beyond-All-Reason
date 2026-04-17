if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Aim Compensation",
		desc    = "Reaims shots to compensate for engine behaviors and BAR def configurations.",
		author  = "efrec",
		date    = "2026-04",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true, -- auto-disables
	}
end

-- This gadget compensates for some weaknesses in Recoil's targeting (lead prediction + aiming):
-- (1) Lead prediction begins behind the "true" intercept and then catches up on each iteration.
-- (2) Lead prediction iterations exit very early when the target is leaving the weapon's range.
-- (3) Without accurateLeading > 0, the base prediction method makes no trajectory compensation.

-- We also are compensating for some of BAR's unitdef and weapondef configurations, namely:
-- (1) Our unit radii are not necessarily good fits of the unit's actual collision volumes.
-- (2) Our collision volumes are not necessarily good fits of the unit's actual dimensions.
-- (3) We use targetBorder = 1 so that units visibly within weapon range can be fired upon.
-- (4) We do not make use of accurateLeading in our unitdefs (It is not a weapondef value).

-- The above might not be self-explanatory to you. I find that the gadget's code outline helps:

-- When a projectile is fired...
-- 1. Infer the ranging/targeting used by the engine when placing and aiming the shot.
-- 2. Construct our preferred target position with compensation to compare against.
--    a. Time change. When a target is exiting range, the trajectory equations are unsolvable.
--       To be more specific, they contain a positive, nonzero, "imaginary" component of time.
--       We _add_ this imaginary component to our real component to construct our final point.
--    b. Border change. Our calculations attempt to hit the target at its center-mass. When a
--       target is missable due to accuracy constraints, and the projectile has a substantial
--       area of effect, we introduce a moderate bias toward firing at the target unit's base.
--       This bias is stronger against approaching targets and weaker against retreating ones.
-- 3. Clamp the new target position to be within the weapon's maximum targeting volume.
--    a. As needed, also clamp this final target position to the surface or to a low altitude.
--       Different targeting volumes do this differently e.g. ballistics use a line-intercept.
-- 4. Rotate the projectile's velocity by the difference in the launch angles between the two
--    trajectories determined by re-aiming at the points determined in (1) and (3).
--
-- Alternatively, if we only want to add range corrections, which are a bit safer:
-- 4. Pitch (and only pitch) the projectile up/down by the difference of launch angles between
--    the trajectories determined by aiming at the points determined in (1) and (3).
--    a. As needed, also reduce the inaccuracy in XZ introduced by the weapondef's accuracy or
--       spray angles, since pitching up and down amplifies these errors a significant amount.

-- TODO: Try to establish a more consistent notation.
-- TODO: Linear algebra is rough to code without inlining. Try some optimizations.
-- TODO: I'm not sure that I have satisfied the constraints of some high-trajectory weapons.
-- TODO: Heightmod, dance, wobble are all trajectory modifications with different effects.

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

-- Avoid overshooting by aiming max-range shots onto terrain, but also try not to
-- force shots to reaim arbitrarily low, causing them to hit walls and/or allies.
local surfaceTargetAltitude = 10.0

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

-- For lack of a better term or whatever

local math_abs = math.abs
local math_max = math.max
local math_clamp = math.clamp
local math_sqrt = math.sqrt
local math_diag = math.diag
local dist2dSquared = math.distance2dSquared
local dist3dSquared = math.distance3dSquared
local math_cos = math.cos
local math_sin = math.sin
local math_acos = math.acos

---@diagnostic disable-next-line: undefined-global
local CallAsTeam = CallAsTeam

local spGetGroundHeight = Spring.GetGroundHeight
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTeamID = Spring.GetProjectileTeamID
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spValidUnitID = Spring.ValidUnitID

local gameSpeed = Game.gameSpeed
local gravityPerFrame = -Game.gravity / (gameSpeed ^ 2)

---@diagnostic disable-next-line: undefined-field
local TAANG2RAD = math.tau / COBSCALE
local TARGETTYPE_UNIT = ("u"):byte()

local TRAJECTORY_LOW = 0
local TRAJECTORY_HIGH = 1
local TRAJECTORY_UNIT = 2
local TRAJECTORY_DEFAULT = TRAJECTORY_LOW

local RAD_EPSILON = 1e-6
local NAN_EPSILON = 1e-5
local DIST_EPSILON = 1e0

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weaponAimCorrection = table.new(#WeaponDefs, 1) -- [0] is hashed

local clampToCone, clampToCylinder, clampToSphere

local shortDuration = 0.3333 * gameSpeed
local instantWeapons = { LightningCannon = true, Rifle = true, }
local reaimEffects = { guidance = true, sector_fire = true }
local spreadDistanceMax = Game.squareSize * Game.footprintScale * 5 -- Use a large-ish unit as an accuracy cutoff

local function getAimCorrectionParams(weaponDef)
	-- There are plenty of cases that make no sense or can cause errors. Avoid them.
	local isFakeWeapon = weaponDef.customParams.bogus == "1" or tonumber(weaponDef.customParams.weapons_group or -1) <= -1
	local isShieldWeapon = weaponDef.type == "Shield"
	local isInstantHit = instantWeapons[weaponDef.type] or weaponDef.projectilespeed * shortDuration >= weaponDef.range
	local isNonballistic = weaponDef.myGravity >= 0

	if isFakeWeapon or isShieldWeapon or isNonballistic or isInstantHit then
		return false
	end

	-- These may be fine but have reduced support for some other reason like performance.
	local isHighTrajectory = weaponDef.highTrajectory == 1 or (weaponDef.type == "StarburstLauncher" and weaponDef.uptime >= 3)
	local canTrackTarget = weaponDef.tracks and weaponDef.turnRate > weaponDef.projectilespeed * 0.1
	local hasReaimEffect = weaponDef.customParams.speceffect and reaimEffects[weaponDef.customParams.speceffect]
	local hasLowAccuracy = (weaponDef.accuracy + weaponDef.sprayAngle) * TAANG2RAD * weaponDef.range >= spreadDistanceMax + weaponDef.damageAreaOfEffect * 0.5
	local hasLargeSalvo = weaponDef.salvoSize >= 6

	if weaponDef.customParams.aim_compensation ~= "true" then
		if isHighTrajectory or canTrackTarget or hasReaimEffect or hasLowAccuracy or hasLargeSalvo then
			return false
		end
	end

	-- NB: Recoil likely does not form proper trajectory envelopes due to max projectile speed.
	-- A falling projectile at terminal velocity "gains" orientation toward dirDown, not speed.
	local clampToTargetingVolume

	-- TODO: We don't know the targeting volume for slaved weapons. These can't be processed from weapondefs, though:
	-- local targetingDef = weaponDef
	-- if weaponDef.customParams.speceffect == "guidance" then
	-- 	targetingDef = need to check the weapon, not the weapondef
	-- end

	if weaponDef.cylinderTargeting >= 1 then
		clampToTargetingVolume = clampToCylinder
	elseif weaponDef.myGravity < 0 and (not weaponDef.tracks or weaponDef.turnRate < -weaponDef.myGravity) then
		clampToTargetingVolume = clampToCone
	else
		-- Maybe we can have a gravity-affected weapon with spherical targeting for nonsense reasons
		-- like a high-trajectory weapon that reuses the laser ranging method from the Legion Medusa.
		clampToTargetingVolume = clampToSphere
	end

	local leadLimit = false
		or weaponDef.leadLimit < 0 and 250 -- The engine has some technical-seeming limit like this.
		or weaponDef.leadLimit + weaponDef.leadBonus * 0.25 -- We just bake in some unit XP for now.

	return {
		gravity      = weaponDef.myGravity,
		heightMod    = weaponDef.heightMod,
		range        = weaponDef.range,
		speed        = weaponDef.projectilespeed,
		targetBorder = weaponDef.targetBorder,
		trajectory   = weaponDef.highTrajectory,

		clamp        = clampToTargetingVolume,

		leadingSteps = -1, -- not a weapondef property but a weapon property
		leadLimit    = leadLimit,
	}
end

for weaponDefID = 0, #WeaponDefs do
	local weaponDef = WeaponDefs[weaponDefID]
	if weaponDef.targetBorder > 0 and weaponDef.customParams.aim_compensation ~= "false" then
		weaponAimCorrection[weaponDefID] = getAimCorrectionParams(weaponDef)
	else
		weaponAimCorrection[weaponDefID] = false
	end
end

for unitDefID = 1, #UnitDefs do
	local unitDef = UnitDefs[unitDefID]
	for index, weapon in ipairs(unitDef.weapons) do
		local aimParams = weaponAimCorrection[weapon.weaponDef]
		if aimParams then
			-- BAR units currently do not use accurateLeading. Still, for balance testing:
			aimParams.leadingSteps = math_max(aimParams.leadingSteps, weapon.accurateLeading)
		end
	end
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function dot(ax, ay, az, bx, by, bz)
	return ax * bx + ay * by + az * bz
end

local function cross(ax, ay, az, bx, by, bz)
	return
		ay * bz - az * by,
		az * bx - ax * bz,
		ax * by - ay * bx
end

local function isOnSurface(x, y, z)
	return y <= math_max(spGetGroundHeight(x, z), 0) + 1
end

local function getPredictTimeAdapter(unitID, projectileID, params)
	local ux, uy, uz, ax, ay, az = spGetUnitPosition(unitID, false, true)
	local px, py, pz = spGetProjectilePosition(projectileID)
	return px, py, pz, ax, ay, az, params.speed -- ! todo: fetch once, use multiple times, ideally
end

--------------------------------------------------------------------------------
-- Engine targeting reproduction -----------------------------------------------

-- This section reproduces the following CWeapon methods from Recoil:
-- GetPredictTime, GetAccuratePredictTime, GetLeadVec, GetLeadTargetPosition

local function getPredictTime(ax, ay, az, bx, by, bz, speed)
	return math_diag(bx - ax, by - ay, bz - az) / speed
end

local function getAccuratePredictTime(unitID, projectileID, params, isHighTrajectory)
	-- Uses no LOS access and no error parameters.
	local ux, uy, uz = spGetUnitPosition(unitID)
	local uvx, uvy, uvz = spGetUnitVelocity(unitID)

	local px, py, pz = spGetProjectilePosition(projectileID)
	local projSpeed = params.speed
	local predictMult = params.predictBoost -- ignoring random seed and attackerXP
	local gravity = params.gravity

	local dx = 0.0
	local dy = 0.0
	local dz = 0.0
	local gg = gravity * gravity
	local ss = projSpeed * projSpeed
	local t1 = 1.0
	local dt1 = 1.0
	local temp1 = 1.0
	local temp2 = 1.0
	local cc = 1.0

	local predictTime = getPredictTime(px, py, pz, ux, uy, uz, projSpeed)
	local deltaTime = predictTime

	-- Generally, `leadingSteps` is not equal to `accurateLeading`. See setup code.
	for i = 1, params.leadingSteps do
		if deltaTime < 1 then
			break
		end

		dx = ux + uvx * predictMult * predictTime - px
		dy = uy + uvy * predictMult * predictTime - py
		dz = uz + uvz * predictMult * predictTime - pz

		cc = -ss - dy * gravity
		temp1 = dot(dx, dy, dz, dx, dy, dz) * gg
		temp2 = cc * cc

		if temp1 >= temp2 then
			break
		end

		t1 = math_sqrt((-cc + (isHighTrajectory and math_sqrt(temp2 - temp1) or 0)) / (gg * 0.5))
		dt1 = (t1 - predictTime) / deltaTime

		if math_abs(dt1 + NAN_EPSILON) < 1 then
			predictTime = t1
			break
		end

		deltaTime = t1 - predictTime
		predictTime = t1
	end

	return predictTime
end

local function getLeadVec(unitID, projectileID, params, isHighTrajectory)
	local predictTime

	if params.leadingSteps > 0 then
		predictTime = getAccuratePredictTime(unitID, projectileID, params, isHighTrajectory)
	else
		predictTime = getPredictTime(getPredictTimeAdapter(unitID, projectileID, params))
	end

	if not predictTime then
		return
	end

	local predictMult = 1 -- We have to infer this.
	predictTime = predictTime * predictMult

	local uvx, uvy, uvz, unitSpeed = spGetUnitVelocity(unitID) -- We get these values too many times.

	local leadX = uvx * predictTime
	local leadY = uvy * predictTime
	local leadZ = uvz * predictTime
	local leadDistance = unitSpeed * predictTime

	if leadDistance > params.leadLimit then
		local ratio = params.leadLimit / (leadDistance + 0.01) -- We don't account for unit XP yet.
		leadX, leadY, leadZ = leadX * ratio, leadY * ratio, leadZ * ratio
	end

	return leadX, leadY, leadZ
end

local function getEngineTargetPosition(unitID, projectileID, params, isHighTrajectory)
	-- Get the error position for this one case.
	local ux, uy, uz, ax, ay, az = CallAsTeam(spGetProjectileTeamID(projectileID), spGetUnitPosition, unitID, false, true)
	if not ax then
		return
	end

	local lx, ly, lz = getLeadVec(unitID, projectileID, params, isHighTrajectory)
	if not lx then
		return
	end

	return ax + lx, ay + ly, az + lz
end

--------------------------------------------------------------------------------
-- Full-range targeting solution -----------------------------------------------

-- "Clamping" fits a target point to anywhere on or within the targeting volume.
-- After allowing for absurd (out-of-range) solutions, we clamp them to reality.

function clampToCylinder(fromX, fromY, fromZ, toX, toY, toZ, range, radius)
	local d2 = dist2dSquared(fromX, fromZ, toX, toZ)

	if d2 > range * range and d2 < (range + radius) * (range + radius) then -- todo: change from spherical to cylindrical test
		local d = math_sqrt(d2)
		local t = range / d
		toX = fromX + (toX - fromX) * t
		toY = fromY + math_clamp(toY - fromY, range * -2, range * 2) -- Assumes cylinder targeting with a multiplier of 2.
		toZ = fromZ + (toZ - fromZ) * t
	end

	return toX, toY, toZ
end

function clampToSphere(fromX, fromY, fromZ, toX, toY, toZ, range, radius)
	local d2 = dist3dSquared(fromX, fromY, fromZ, toX, toY, toZ)

	if d2 > range * range and d2 <= (range + radius) * (range + radius) then
		-- AimPos is out of range, but nearest targetBorder is within range:
		local d = math_sqrt(d2)
		local t = (range - radius) / d
		toX = fromX + (toX - fromX) * t
		toY = fromY + (toY - fromY) * t
		toZ = fromZ + (toZ - fromZ) * t
	end

	return toX, toY, toZ
end

function clampToCone(fromX, fromY, fromZ, toX, toY, toZ, range, radius)
	local dx, dy, dz = toX - fromX, toY - fromY, toZ - fromZ
	local dxzSquared = dx * dx + dz * dz
	local heightCone = range * range / -gravityPerFrame
	local radiusAtY = math_max(range * dy / heightCone, 0.0)

	if radiusAtY <= 0 and dxzSquared <= radius * radius then
		-- Probably bad to fire gravity-affected projectiles at dirUp:
		toX, toY, toZ = fromX, fromY + heightCone, fromZ
	elseif dxzSquared > radiusAtY * radiusAtY and dxzSquared <= (radiusAtY + radius) * (radiusAtY + radius) then
		-- todo: Not as good as it should be considering the projectile is under gravity:
		local t = radiusAtY / math_sqrt(dxzSquared)
		toX = fromX + dx * t
		toY = fromY + dy * t
		toZ = fromZ + dz * t
	end

	return toX, toY, toZ
end

local function clampToAltitude(x, y, z, unitRadius)
	local elevation = math_max(spGetGroundHeight(x, z), 0)
	local altitude = math_max(unitRadius, surfaceTargetAltitude)
	y = math_clamp(y, elevation, elevation + altitude)
	return x, y, z
end

local function getBetterTargetPosition(unitID, projectileID, params, isHighTrajectory, compensationType, isSurfaceTarget)
	-- Uses no LOS access and no error parameters.
	local ux, uy, uz, umx, umy, umz, uax, uay, uaz = spGetUnitPosition(unitID, true, true)
	local uvx, uvy, uvz, unitSpeed = spGetUnitVelocity(unitID)

	local px, py, pz = spGetProjectilePosition(projectileID)
	local projSpeed = params.speed
	local predictMult = params.predictBoost -- ignoring random seed and attackerXP
	local gravity = params.gravity

	local dx = 0.0
	local dy = 0.0
	local dz = 0.0
	local gg = gravity * gravity
	local ss = projSpeed * projSpeed
	local t1 = 1.0
	local dt1 = 1.0
	local temp1 = 1.0
	local temp2 = 1.0
	local cc = 1.0

	if compensationType == "short" and isSurfaceTarget then
		ux, uy, uz = (ux + uax) * 0.5, (uy + uay) * 0.5, (uz + uaz) * 0.5
	else
		ux, uy, uz = umx, umy, umz
	end

	local predictTime = getPredictTime(px, py, pz, ux, uy, uz, projSpeed)
	local deltaTime = predictTime

	-- As "better target position" would imply, enforce at least one iteration.
	for i = 1, math_max(params.leadingSteps, 1) do
		if deltaTime < 1 then
			break
		end

		dx = ux + uvx * predictMult * predictTime - px
		dy = uy + uvy * predictMult * predictTime - py
		dz = uz + uvz * predictMult * predictTime - pz

		cc = -ss - dy * gravity
		temp1 = dot(dx, dy, dz, dx, dy, dz) * gg
		temp2 = cc * cc

		if temp1 >= temp2 then
			-- Since we clamp to within the targeting volume after this step, time past-range is fine.
			-- So, materialize the imaginary time component of the solution from the nearest approach:
			local approachDistance = math_sqrt(temp1 - temp2) / gravity
			t1 = t1 + approachDistance / projSpeed
			break
		end

		t1 = math_sqrt((-cc + (isHighTrajectory and math_sqrt(temp2 - temp1) or 0)) / (gg * 0.5))
		dt1 = (t1 - predictTime) / deltaTime

		if math_abs(dt1 + NAN_EPSILON) < 1 then
			predictTime = t1
			break
		end

		deltaTime = t1 - predictTime
		predictTime = t1
	end

	predictTime = predictTime * predictMult

	local leadX = uvx * predictTime
	local leadY = uvy * predictTime
	local leadZ = uvz * predictTime
	local leadDistance = unitSpeed * predictTime

	if leadDistance > params.leadLimit then
		local ratio = params.leadLimit / (leadDistance + 0.01)
		leadX, leadY, leadZ = leadX * ratio, leadY * ratio, leadZ * ratio
	end

	-- Refetch the unit position, this time with error.
	ux, uy, uz, umx, umy, umz, uax, uay, uaz = CallAsTeam(spGetProjectileTeamID(projectileID), spGetUnitPosition, unitID, true, true)

	if compensationType == "short" and isSurfaceTarget then
		ux, uy, uz = (ux + uax) * 0.5, (uy + uay) * 0.5, (uz + uaz) * 0.5
	else
		ux, uy, uz = uax, uay, uaz
	end

	return ux + leadX, uy + leadY, uz + leadZ
end

--------------------------------------------------------------------------------
-- Final aim compensation solution ---------------------------------------------

local projectiles = 0
local compensated = 0
local compensation = {}

local function getAimDirection(params, trajectory, dx, dy, dz, predictTime)
	local gravity = params.gravity
	local speed = params.speed

	local a = 0.25 * gravity * gravity
	local b = dy * gravity - speed * speed
	local c = dot(dx, dy, dz, dx, dy, dz)
	local d = b * b - 4 * a * c
	if d < 0 then
		return
	end

	local dd = math_sqrt(d)
	local t1 = (-b - dd) / (2 * a)
	local t2 = (-b + dd) / (2 * a)

	local t = t1
	local e = NAN_EPSILON

	if trajectory == TRAJECTORY_HIGH then
		if t2 > e then
			t = t2
		else
			return
		end
	else
		if t1 > e then
			if t2 > e and math_abs(predictTime - t1) > math_abs(predictTime - t2) then
				t = t2
			end
		elseif t2 > e then
			t = t2
		else
			return
		end
	end

	local vx = dx / t
	local vy = dy / t - 0.5 * gravity * t
	local vz = dz / t
	local vw = math_diag(vx, vy, vz)

	if vw > e then
		return vx / vw, vy / vw, vz / vw
	end
end

local function buildRotation(dx0, dy0, dz0, dx1, dy1, dz1)
	local angle = math_acos(math_clamp(dot(dx0, dy0, dz0, dx1, dy1, dz1), -1.0, 1.0))
	if angle <= RAD_EPSILON then
		return 0.0
	end

	local axisX, axisY, axisZ = cross(dx0, dy0, dz0, dx1, dy1, dz1)
	local axisMag = math_diag(axisX, axisY, axisZ)
	if axisMag <= NAN_EPSILON then
		return 0.0 -- avoid math_normalize to exit when parallel/antiparallel here
	end

	axisX = axisX / axisMag
	axisY = axisY / axisMag
	axisZ = axisZ / axisMag

	return angle, axisX, axisY, axisZ
end

local function applyRotation(angle, axisX, axisY, axisZ, vx, vy, vz)
	local cosAngle = math_cos(angle)
	local sinAngle = math_sin(angle)
	local cosTerm = (1 - cosAngle) * dot(axisX, axisY, axisZ, vx, vy, vz)

	local resultX = vx * cosAngle + (axisY * vz - axisZ * vy) * sinAngle + axisX * cosTerm
	local resultY = vy * cosAngle + (axisZ * vx - axisX * vz) * sinAngle + axisY * cosTerm
	local resultZ = vz * cosAngle + (axisX * vy - axisY * vx) * sinAngle + axisZ * cosTerm

	return angle, resultX, resultY, resultZ
end

local function applyAimCorrection(projectileID, ownerID, params)
	-- Leave these in until we've collected enough weapon performance statistics.
	compensation[projectileID] = "none"
	projectiles = projectiles + 1

	local targetType, targetID = spGetProjectileTarget(projectileID)
	if targetType ~= TARGETTYPE_UNIT then
		return
	else
		assert(type(targetID) == "number")
		if not spValidUnitID(targetID) then
			return
		end
	end

	local unitDefID, unitRadius = spGetUnitDefID(targetID), spGetUnitRadius(targetID)
	if not unitDefID or unitRadius == 0 then
		return
	end

	local uvx, uvy, uvz, unitSpeed = spGetUnitVelocity(targetID)
	local pvx, pvy, pvz, projSpeed = spGetProjectileVelocity(projectileID)
	if unitSpeed * projSpeed <= NAN_EPSILON then
		return
	end

	local ux, uy, uz, midX, midY, midZ, aimX, aimY, aimZ = spGetUnitPosition(targetID, true, true)
	local px, py, pz = spGetProjectilePosition(projectileID)

	local direction = dot(uvx, uvy, uvz, pvx, pvy, pvz) / projSpeed / unitSpeed
	local separation = math_max(math_diag(midX - px, midY - py, midZ - pz) - unitRadius, 0) / params.range
	local isSurfaceTarget = isOnSurface(ux, uy, uz)

	-- We use two types of aim correction, determined by the target's relative distance and speed.
	-- 1. Surface targets can be hit indirectly by shooting at their base. This also limits overshooting.
	-- 2. Receding targets should be targeted through their center-mass. This avoids shots falling short.
	local compensationType

	if direction <= 0 and isSurfaceTarget and (separation <= 0.3333 or separation + direction < -0.3333) then
		compensationType = "short"
	elseif direction >= 0.75 or separation + direction >= 1.5 then
		compensationType = "long"
	else
		return
	end

	local trajectory = params.trajectory
	if trajectory == TRAJECTORY_UNIT then
		if spValidUnitID(ownerID) then
			trajectory = spGetUnitStates(ownerID).trajectory and TRAJECTORY_HIGH or TRAJECTORY_LOW
		else
			trajectory = TRAJECTORY_DEFAULT -- Projectile was probably spawned via game code.
		end
	end

	local isHighTrajectory = trajectory == TRAJECTORY_HIGH

	local ex, ey, ez, engineTime = getEngineTargetPosition(unitID, projectileID, params, isHighTrajectory)
	if not ex then
		return
	end

	local bx, by, bz, betterTime = getBetterTargetPosition(unitID, projectileID, params, isHighTrajectory, compensationType, isSurfaceTarget)
	if not bx then
		return
	end

	bx, by, bz = params.clamp(px, py, pz, bx, by, bz, params.range, unitRadius)

	if isSurfaceTarget and separation + direction >= 0.75 then
		bx, by, bz = clampToAltitude(bx, by, bz)
	end

	local edx, edy, edz = getAimDirection(params, trajectory, ex - px, ey - py, ez - pz, engineTime)
	if not edx then
		return
	end

	local bdx, bdy, bdz = getAimDirection(params, trajectory, bx - px, by - py, bz - pz, betterTime)
	if not bdx then
		return
	end

	-- This is a tempting thought but we have no clue what our weapon is: -- TODO
	-- Spring.GetUnitWeaponTryTarget(ownerID, ...)

	local angle, ax, ay, az = buildRotation(edx, edy, edz, bdx, bdy, bdz)
	if angle <= RAD_EPSILON or angle * (params.range * separation) ^ 2 <= DIST_EPSILON then
		return
	end

	spSetProjectileVelocity(projectileID, applyRotation(angle, ax, ay, az, vx, vy, vz))

	-- Statistics gathering:
	compensation[projectileID] = compensationType
	compensated = compensated + 1
end

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

function gadget:Initialize()
	if not next(weaponAimCorrection) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No weapons with under-range issues.")
		gadgetHandler:RemoveGadget()
		return
	end

	for weaponDefID, params in pairs(weaponAimCorrection) do
		if params then
			Script.SetWatchProjectile(weaponDefID, true)
		end
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if weaponAimCorrection[weaponDefID] then
		applyAimCorrection(projectileID, ownerID, weaponAimCorrection[weaponDefID])
	end
end
