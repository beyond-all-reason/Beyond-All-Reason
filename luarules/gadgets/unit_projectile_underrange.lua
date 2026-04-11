if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Projectile Aim Correction",
		desc    = "Reaims projectiles as though they had `targetBorder = 0`",
		author  = "efrec",
		date    = "2026-04",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true, -- auto-disables
	}
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

-- Try to prevent noticeable corrections with nearby targets. The typical angle
-- difference between the initial velocity and the post-correction velocity is
-- from 1 to 4 degrees. Closer targets tend to cause angles from 5 to 8 degrees.
local correctionAngleMax = math.rad(12)

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp
local math_sqrt = math.sqrt
local math_diag = math.diag
local dist2dSquared = math.distance2dSquared
local dist3dSquared = math.distance3dSquared
local math_cos = math.cos
local math_sin = math.sin
local math_acos = math.acos

local CallAsTeam = CallAsTeam

local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTeamID = Spring.GetProjectileTeamID
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spValidUnitID = Spring.ValidUnitID

local gameSpeed = Game.gameSpeed
local gravityPerFrame = -Game.gravity / (gameSpeed ^ 2)

local ARC_EPSILON = 1e-6
local TAANG2RAD = math.tau / COBSCALE
local UNIT = string.byte("u")
local TRAJECTORY_UNIT = 2

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weaponAimCorrection = table.new(#WeaponDefs, 1) -- [0] is hashed

local function clampToCylinder(fromX, fromY, fromZ, toX, toY, toZ, range, radius)
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

local function clampToSphere(fromX, fromY, fromZ, toX, toY, toZ, range, radius)
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

local function clampToCone(fromX, fromY, fromZ, toX, toY, toZ, range, radius)
	local dx, dy, dz = toX - fromX, toY - fromY, toZ - fromZ
	local dxzSquared = dx * dx + dz * dz
	local heightCone = range * range / gravityPerFrame
	local radiusAtY = math_max(range * dy / heightCone, 0)

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

local instantDuration = 0.3333 * Game.gameSpeed -- Fast enough, anyway
local instantWeapons = { LightningCannon = true, Rifle = true, }
local reaimEffects = { guidance = true, sector_fire = true }
local spreadDistanceMax = Game.squareSize * Game.footprintScale * 5 -- Use the reference dimension of a large-ish unit as an accuracy cutoff

local function getAimCorrectionParams(weaponDef)
	local isFakeWeapon = weaponDef.range <= 10 or weaponDef.customParams.bogus == "1"
	local isShieldWeapon = weaponDef.type == "Shield"
	local isInstantHit = instantWeapons[weaponDef.type] or weaponDef.projectilespeed * instantDuration >= weaponDef.range
	local isHighTrajectory = weaponDef.highTrajectory == 1 or (weaponDef.type == "StarburstLauncher" and weaponDef.uptime >= 3)
	local canTrackTarget = weaponDef.tracks and weaponDef.turnRate > weaponDef.projectilespeed * 0.1
	local hasReaimEffect = weaponDef.customParams.speceffect and reaimEffects[weaponDef.customParams.speceffect]
	local hasLowAccuracy = (weaponDef.accuracy + weaponDef.sprayAngle) * TAANG2RAD * weaponDef.range >= spreadDistanceMax + weaponDef.damageAreaOfEffect * 0.5
	local hasLargeSalvo = weaponDef.salvoSize >= 6

	if isFakeWeapon or isShieldWeapon or isInstantHit or isHighTrajectory or canTrackTarget or hasReaimEffect or hasLowAccuracy or hasLargeSalvo then
		return false
	end

	local clampToTargetingVolume

	if weaponDef.cylinderTargeting >= 1 then
		clampToTargetingVolume = clampToCylinder
	elseif weaponDef.gravityAffected then -- todo: gravity over projectile lifetime should be >> some value
		clampToTargetingVolume = clampToCone
	else
		clampToTargetingVolume = clampToSphere
	end

	local angleMax = correctionAngleMax -- todo: different weapons may need different amounts of correction

	return {
		angleMax     = angleMax,

		targetBorder = weaponDef.targetBorder,
		range        = weaponDef.range,
		speed        = weaponDef.projectilespeed,

		leadLimit    = math.abs(weaponDef.leadLimit),
		leadBonus    = weaponDef.leadBonus,
		predictBoost = weaponDef.predictBoost,

		gravity      = weaponDef.gravityAffected, -- todo: handle special gravities
		heightMod    = weaponDef.heightMod,
		trajectory   = weaponDef.highTrajectory,

		clamp        = clampToTargetingVolume,
	}
end

for weaponDefID = 0, #WeaponDefs do
	local weaponDef = WeaponDefs[weaponDefID]
	if weaponDef.targetBorder > 0 and not weaponDef.customParams.no_border_correction then
		weaponAimCorrection[weaponDefID] = getAimCorrectionParams(weaponDef)
	else
		weaponAimCorrection[weaponDefID] = false
	end
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

---Build the rotation around a non-trivial origin <o> of a vector <a> toward a vector <b>.
local function buildRotation(ox, oy, oz, ax, ay, az, bx, by, bz, angleMax)
	local ux, uy, uz = ax - ox, ay - oy, az - oz
	local vx, vy, vz = bx - ox, by - oy, bz - oz

	local uw = math_diag(ux, uy, uz)
	local vw = math_diag(vx, vy, vz)

	if uw == 0 or vw == 0 then
		return 0, 0, 0, 0
	end

	local cosAngle = math_clamp((ux * vx + uy * vy + uz * vz) / uw / vw, -1, 1)
	local angle = math_acos(cosAngle)
	local factor = math_min(1, angleMax / angle)

	if factor <= ARC_EPSILON then
		return 0, 0, 0, 0
	end

	if factor >= 1 - ARC_EPSILON then
		return vx / vw, vy / vw, vz / vw, angle
	end

	if math_abs(cosAngle) < 1 - ARC_EPSILON then
		local weight1 = math_sin(angle * (1 - factor)) / uw
		local weight2 = math_sin(angle * (    factor)) / vw
		local rescale = uw / math_sin(angle)
		local cx = (ux * weight1 + vx * weight2) * rescale
		local cy = (uy * weight1 + vy * weight2) * rescale
		local cz = (uz * weight1 + vz * weight2) * rescale
		local cw = math_diag(cx, cy, cz)
		return cx / cw, cy / cw, cz / cw, angle * factor
	end
end

local function applyRotation(rx, ry, rz, angle, px, py, pz)
	local crossX = ry * pz - rz * py
	local crossY = rz * px - rx * pz
	local crossZ = rx * py - ry * px
	local dot = rx * px + ry * py + rz * pz
	local cosAngle = math_cos(angle)
	local sinAngle = math_sin(angle)
	return
		px * cosAngle + crossX * sinAngle + dot * rx * (1 - cosAngle),
		py * cosAngle + crossY * sinAngle + dot * ry * (1 - cosAngle),
		pz * cosAngle + crossZ * sinAngle + dot * rz * (1 - cosAngle)
end

local function getTargetData(targetID)
	local _, _, _, midX, midY, midZ, aimX, aimY, aimZ = spGetUnitPosition(targetID, true, true)
	return midX, midY, midZ, aimX, aimY, aimZ, spGetUnitDefID(targetID), spGetUnitRadius(targetID)
end

local readAs = { read = -1 }
local function readAsTeam(teamID, ...)
	local read = readAs
	read.read = teamID or -1
	return CallAsTeam(read, ...)
end

local function updateAimDirection(projectileID, params, targetID)
	local midX, midY, midZ, aimX, aimY, aimZ, targetDefID, targetRadius = getTargetData(targetID)
	if not midX or not targetDefID or targetRadius == 0 then
		return
	end

	local uvx, uvy, uvz, unitSpeed = spGetUnitVelocity(targetID)
	local pvx, pvy, pvz, projSpeed = spGetProjectileVelocity(projectileID)
	if not uvx or (projSpeed or 0) == 0 then
		return
	end

	-- todo: High trajectories need to use a counter-rotation for reaiming.
	if params.trajectory == TRAJECTORY_UNIT and pvy >= math_diag(pvx, pvz) then
		return
	end

	local px, py, pz = spGetProjectilePosition(projectileID)
	local pdx, pdy, pdz = spGetProjectileDirection(projectileID)

	local targetX, targetY, targetZ = midX, midY, midZ -- The inferred targetBorder-based position.
	local aimPosX, aimPosY, aimPosZ = aimX, aimY, aimZ -- The new, preferred aimPos-based position.

	local targetBorderRadius = params.targetBorder * targetRadius
	targetX = targetX - pdx * targetBorderRadius
	targetY = targetY - pdy * targetBorderRadius
	targetZ = targetZ - pdz * targetBorderRadius

	local timeRemainingMax = params.leadLimit / (unitSpeed + projSpeed) -- close enough

	for convergenceStep = 1, 2 do
		local timeRemainingMid = math_min(math_diag(targetX - px, targetY - py, targetZ - pz) / projSpeed, timeRemainingMax)
		targetX = targetX + uvx * timeRemainingMid
		targetY = targetY + uvy * timeRemainingMid
		targetZ = targetZ + uvz * timeRemainingMid

		local timeRemainingAim = math_min(math_diag(aimX - px, aimY - py, aimZ - pz) / projSpeed, timeRemainingMax)
		aimPosX = aimX + uvx * timeRemainingAim
		aimPosY = aimY + uvy * timeRemainingAim
		aimPosZ = aimZ + uvz * timeRemainingAim
	end

	targetX, targetY, targetZ = params.clamp(px, py, pz, targetX, targetY, targetZ, params.range, targetRadius)
	aimPosX, aimPosY, aimPosZ = params.clamp(px, py, pz, aimPosX, aimPosY, aimPosZ, params.range, targetRadius)

	local rx, ry, rz, rw = buildRotation(px, py, pz, targetX, targetY, targetZ, aimPosX, aimPosY, aimPosZ, params.angleMax)

	if (rw or 0) == 0 then
		return
	end

	spSetProjectileVelocity(projectileID, applyRotation(rx, ry, rz, rw, pvx, pvy, pvz))
end

local function applyAimCorrection(projectileID, ownerID, params)
	local targetType, targetID = spGetProjectileTarget(projectileID)
	if targetType ~= UNIT or not spValidUnitID(targetID) then
		return
	end
	local teamID = spGetUnitTeam(ownerID) or spGetProjectileTeamID(projectileID)
	readAsTeam(teamID, updateAimDirection, projectileID, params, targetID)
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

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
