local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Custom weapon behaviours",
		desc = "Handler for special weapon behaviours",
		author = "Doo",
		date = "Sept 19th 2017",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local math_clamp = math.clamp
local math_max = math.max
local math_random = math.random
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local math_tau = math.tau
local math_diag = math.diag
local distance3dSquared = math.distance3dSquared

local CallAsTeam = CallAsTeam

local spDeleteProjectile = Spring.DeleteProjectile
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundNormal = Spring.GetGroundNormal
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTeamID = Spring.GetProjectileTeamID
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileTarget = Spring.SetProjectileTarget
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spSpawnCEG = Spring.SpawnCEG
local spSpawnProjectile = Spring.SpawnProjectile

local gravityPerFrame = -Game.gravity / (Game.gameSpeed * Game.gameSpeed)

local targetedGround = string.byte("g")
local targetedUnit = string.byte("u")

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local specialEffectFunction = {}
local weaponCustomParamKeys = {} -- [effect] = { [key] = conversion function }

local weaponDefEffect = {}
---@type table<number, true?>
local torpedoStayUnderwaterDefs = {}

local projectiles = {}
local projectilesData = {}

---@type number
local gameFrame = 0

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function parseCustomParams(weaponDef)
	local success = true

	local effectName = weaponDef.customParams.speceffect

	if not specialEffectFunction[effectName] then
		success = false
		local message = weaponDef.name .. " has bad speceffect: " .. tostring(effectName)
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
	end

	local effectParams = {}

	if weaponCustomParamKeys[effectName] then
		for key, conversion in pairs(weaponCustomParamKeys[effectName]) do
			local value = conversion(weaponDef.customParams[key])
			if value ~= nil then
				effectParams[key] = value
			else
				success = false
				local message = weaponDef.name .. " has bad customparam: " .. tostring(key)
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			end
		end

		-- Modders/tweakdefs are likely to use these values for a while:
		if weaponDef.customParams.def or weaponDef.customParams.when then
			local message = weaponDef.name .. " uses old customparams (def/when)"
			Spring.Log(gadget:GetInfo().name, LOG.DEPRECATED, message)
		end
	end

	if success then
		return effectName, effectParams
	end
end

local function toWeaponDefID(value)
	local spawnDef = WeaponDefNames[value]
	return spawnDef and spawnDef.id or nil
end

local function toPositiveNumber(value)
	value = tonumber(value)
	return value and math_max(0, value) or nil
end

--- Weapon behaviors -----------------------------------------------------------

local function isProjectileFalling(projectileID)
	local _, velocityY = spGetProjectileVelocity(projectileID)
	return velocityY < 0
end

local function isProjectileInWater(projectileID)
	local _, positionY = spGetProjectilePosition(projectileID)
	return positionY ~= nil and positionY <= 0
end

local function equalTargets(target1, target2)
	return target1 == target2
		or (
			type(target1) == "table"
			and type(target2) == "table"
			and target1[1] == target2[1]
			and target1[2] == target2[2]
			and target1[3] == target2[3]
		)
end

local readAs = { read = -1 }

local function readAsTeam(teamID, ...)
	local read = readAs
	read.read = teamID or -1
	return CallAsTeam(read, ...)
end

---@return number? targetX xyz coords
---@return number? targetY
---@return number? targetZ
local function getTargetPositionWithError(projectileID)
	local targetType, target = spGetProjectileTarget(projectileID)
	if targetType == targetedUnit then
		local teamID = spGetProjectileTeamID(projectileID) or spGetUnitTeam(spGetProjectileOwnerID(projectileID) or -1)
		local _, _, _, targetX, targetY, targetZ = readAsTeam(teamID, spGetUnitPosition, target, false, true)
		return targetX, targetY, targetZ -- unit aim position
	elseif targetType == targetedGround then
		return target[1], target[2], target[3]
	end
end

---Translates TargetType integers to the ProjectileTargetType byte-integers needed in SetProjectileTarget.
---@param projectileID integer
---@param target integer|xyz?
---@param targetType TargetType
local function setProjectileTarget(projectileID, target, targetType)
	if targetType == 1 then
		spSetProjectileTarget(projectileID, target, targetedUnit)
		return true
	elseif targetType == 2 then
		spSetProjectileTarget(projectileID, target[1], target[2], target[3])
		return true
	end
end

local getProjectileArgs
do
	---@class ProjectileParams
	local projectileParams = {
		pos = { 0, 0, 0 },
		speed = { 0, 0, 0 },
		gravity = gravityPerFrame,
		ttl = 3000,
		owner = -1,
		team = -1,
	}

	---@return integer weaponDefID
	---@return ProjectileParams projectileParams
	---@return number parentSpeed
	getProjectileArgs = function(params, projectileID)
		local weaponDefID = params.speceffect_def
		local projectile = projectileParams
		local parentSpeed

		local pos = projectile.pos
		pos[1], pos[2], pos[3] = spGetProjectilePosition(projectileID)

		local vel = projectile.speed
		vel[1], vel[2], vel[3], parentSpeed = spGetProjectileVelocity(projectileID)

		projectile.owner = spGetProjectileOwnerID(projectileID) or -1
		projectile.team = spGetProjectileTeamID(projectileID) or spGetUnitTeam(projectile.owner) or -1
		projectile.cegTag = params.cegtag
		projectile.model = params.model

		return weaponDefID, projectile, parentSpeed
	end
end

-- Cruise
-- Missile guidance behavior that avoids crashing into terrain while heading toward the target.
-- Intended to be used with non-homing weapons, since it updates the velocity independently.

weaponCustomParamKeys.cruise = {
	cruise_min_height = toPositiveNumber, -- Minimum ground clearance. Checked each frame, but no lookahead.
	cruise_max_height = toPositiveNumber, -- Maximum ground clearance. Checked each frame, but no lookahead.
	lockon_dist = toPositiveNumber, -- Within this radius, disables the auto ground clearance.
}

local useSmoothMeshHeight = 40 -- altitude used to switch between actual and smoothed terrain normals
local responseRatio = 0 -- response decrease (multiplier (0, 1)) for a damper on excessive responses
do
	local frames = math.round(0.2 * Game.gameSpeed) -- spread the response over N frames
	responseRatio = (1 + 1 / frames - 1 / (frames ^ 2)) / frames -- via taylor expansion
end

local cruiseWaitingDefs = {}
local cruiseEngagedDefs = {}

local function applyCruiseCorrection(
	projectileID,
	elevation,
	cruiseHeight,
	positionX,
	positionY,
	positionZ,
	velocityX,
	velocityY,
	velocityZ
)
	local responseY = 0
	if elevation > 0 then
		local normalX, normalY, normalZ =
			spGetGroundNormal(positionX, positionZ, cruiseHeight - elevation >= useSmoothMeshHeight)
		responseY = velocityY - normalY * (velocityX * normalX + velocityY * normalY + velocityZ * normalZ)
	end
	velocityY = velocityY + (responseY - velocityY) * responseRatio
	positionY = positionY + (cruiseHeight - positionY) * responseRatio
	spSetProjectilePosition(projectileID, positionX, positionY, positionZ)
	spSetProjectileVelocity(projectileID, velocityX, velocityY, velocityZ)
end

-- First-phase `cruise` effect, allowing weapons to ascend before triggering ground avoidance.
specialEffectFunction.cruise = function(params, projectileID)
	local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
	local velocityX, velocityY, velocityZ, speed = spGetProjectileVelocity(projectileID)
	local elevation = math_max(spGetGroundHeight(positionX, positionZ), 0)
	local cruiseHeight = elevation + params.cruise_min_height

	if positionY >= cruiseHeight or velocityY <= speed * 0.125 then
		local avoidGround = cruiseWaitingDefs[spGetProjectileDefID(projectileID)]
		projectiles[projectileID] = avoidGround
		avoidGround(projectileID) -- let the effect care about the `lockon_dist`
	elseif elevation > 0 and speed > 0 and spGetProjectileTimeToLive(projectileID) > 0 then
		local _, normalY = spGetGroundNormal(positionX, positionZ, true)
		if velocityY / speed <= normalY then
			applyCruiseCorrection(
				projectileID,
				elevation,
				cruiseHeight,
				positionX,
				positionY,
				positionZ,
				velocityX,
				velocityY,
				velocityZ
			)
		end
	end

	return false
end

-- Second-phase `cruise` effect, adding a ground-avoidance behavior that uses `cruise_min_height`.
local function cruiseWaiting(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
		local targetX, targetY, targetZ = getTargetPositionWithError(projectileID)
		local distance = params.lockon_dist

		if
			not targetX
			or distance * distance < distance3dSquared(positionX, positionY, positionZ, targetX, targetY, targetZ)
		then
			local elevation = math_max(spGetGroundHeight(positionX, positionZ), 0)
			local cruiseHeight = elevation + params.cruise_min_height
			-- Avoid going below the minimum cruise height while ignoring the maximum cruise height.
			if positionY < cruiseHeight then
				projectiles[projectileID] = cruiseEngagedDefs[spGetProjectileDefID(projectileID)]
				applyCruiseCorrection(
					projectileID,
					elevation,
					cruiseHeight,
					positionX,
					positionY,
					positionZ,
					spGetProjectileVelocity(projectileID)
				)
			end
			return false
		end
	end
	return true
end

-- Third-phase `cruise` effect, adding a ground-following behavior that uses `cruise_max_height`.
local function cruiseEngaged(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local targetX, targetY, targetZ = getTargetPositionWithError(projectileID)
		local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
		local distance = params.lockon_dist

		if
			not targetX
			or distance * distance < distance3dSquared(positionX, positionY, positionZ, targetX, targetY, targetZ)
		then
			local elevation = math_max(spGetGroundHeight(positionX, positionZ), 0)
			local cruiseHeight =
				math_clamp(positionY, elevation + params.cruise_min_height, elevation + params.cruise_max_height)
			local velocityX, velocityY, velocityZ, speed = spGetProjectileVelocity(projectileID)
			-- Follow the ground when it slopes away, but not over steep drops, e.g. sheer cliffs.
			if positionY ~= cruiseHeight and (positionY > cruiseHeight or velocityY > speed * -0.25) then
				applyCruiseCorrection(
					projectileID,
					elevation,
					cruiseHeight,
					positionX,
					positionY,
					positionZ,
					velocityX,
					velocityY,
					velocityZ
				)
			end
			return false
		end
	end
	return true
end

-- Retarget
-- Missile guidance behavior that changes the projectile's target when its intended target is destroyed.
-- This could be made much more efficient by creating an explicit death dependence (in another gadget).
-- The retargeting behavior relies on the owner unit's primary weapon, so ends when it is also destroyed.

-- Uses no weapon customParams.

specialEffectFunction.retarget = function(projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local targetType, target = spGetProjectileTarget(projectileID)

		if targetType == targetedUnit then
			if spGetUnitIsDead(target) ~= false then
				local ownerID = spGetProjectileOwnerID(projectileID)
				-- Hardcoded to retarget only from the primary weapon and only units or ground
				local ownerTargetType, fromUser, ownerTarget = spGetUnitWeaponTarget(ownerID, 1)
				setProjectileTarget(projectileID, ownerTarget, ownerTargetType)
			end
			return false
		end
	else
		return true
	end
end

-- Guidance
-- Missile guidance behavior that changes the projectile's target when the primary weapon changes targets.
-- If the primary weapon stops firing (no LoS/unit dead) the missiles will go for the last location that was targeted.

weaponCustomParamKeys.guidance = {
	guidance_lost_radius = toPositiveNumber,
}

-- General info, since this became long:
-- (1) The primary weapon's targeting must be used as guidance for the guidee weapon.
-- (2) The primary weapon must be continuously firing or burst-firing e.g. BeamLaser.
-- (3) You must add a guidance_lost_radius, even if it is zero, to the guidee weapon.
-- (4) The code below has a bunch of perf hax to cache results for the Legion Medusa.

---@class GuidanceEffectResult
---@field [1] boolean isFiring
---@field [2] TargetType guidanceType
---@field [3] boolean isUserTarget, nil when guidanceType is `0`
---@field [4] integer|xyz guidanceTarget, nil when guidanceType is `0`

local guidanceResults = {} ---@type table<integer, GuidanceEffectResult|xyz>

local lookahead = 0.6667 * Game.gameSpeed -- projectile position lookahead

local function getGuidanceLost(projectileID, radius, targetID)
	local ux, uy, uz
	local teamID = spGetProjectileTeamID(projectileID)

	if radius and radius > 0 then
		ux, uy, uz = readAsTeam(teamID, spGetUnitPosition, targetID, false, true)
	else
		ux, uy, uz = readAsTeam(teamID, spGetUnitPosition, targetID)
	end

	if not ux then
		-- We lost LOS on the target, most likely. Act casual.
		local px, py, pz = spGetProjectilePosition(projectileID)
		local vx, vy, vz = spGetProjectileVelocity(projectileID)
		ux, uy, uz = px + vx * lookahead, py + vy * lookahead, pz + vz * lookahead
	end

	local result = { ux, uy, uz }
	guidanceResults[-targetID - 1] = result
	return result
end

local function guidanceLost(projectileID, radius, targetID)
	local result = guidanceResults[-targetID - 1] or getGuidanceLost(projectileID, radius, targetID)
	local tx, ty, tz = result[1], result[2], result[3]

	if radius and radius > 0 then
		local elevation = math_max(spGetGroundHeight(tx, tz), 0)
		local dx, dy, dz = spGetGroundNormal(tx, tz, true)
		local swerveRadius = radius * (0.25 + 0.75 * math_random())
		local swerveAngle = math_tau * math_random()
		local cosAngle = math_cos(swerveAngle)
		local sinAngle = math_sin(swerveAngle)

		if elevation <= 0 or dy > 0.9 then
			-- Scatter within a ring in the XZ plane.
			tx = tx + swerveRadius * cosAngle
			tz = tz + swerveRadius * sinAngle
		else
			-- Scatter within a ring rotated to align with terrain.
			local ax, ay, az = 0, 1, 0
			local bx = ay * dz - az * dy
			local by = az * dx - ax * dz
			local bz = ax * dy - ay * dx
			local cx = dy * bz - dz * by
			local cy = dz * bx - dx * bz
			local cz = dx * by - dy * bx
			tx = tx + swerveRadius * (cosAngle * bx + sinAngle * cx)
			ty = ty + swerveRadius * (cosAngle * by + sinAngle * cy)
			tz = tz + swerveRadius * (cosAngle * bz + sinAngle * cz)
		end
	end

	local elevation = math_max(spGetGroundHeight(tx, tz), 0)
	spSetProjectileTarget(projectileID, tx, (ty - elevation < 40) and elevation or ((ty + elevation) * 0.5), tz)
end

local noGuidance = { false, 0, false, -1 }

local function getGuidanceResult(ownerID)
	local nextSalvo = spGetUnitWeaponState(ownerID, 1, "nextSalvo")
	local result = nextSalvo and (nextSalvo + 1 >= gameFrame) and { true, spGetUnitWeaponTarget(ownerID, 1) }
		or noGuidance
	guidanceResults[ownerID] = result
	return result
end

specialEffectFunction.guidance = function(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local ownerID = spGetProjectileOwnerID(projectileID)
		local targetType, target = spGetProjectileTarget(projectileID)

		if ownerID and spGetUnitIsDead(ownerID) == false then
			local result = guidanceResults[ownerID] or getGuidanceResult(ownerID)
			if result[1] then
				local guidanceType, guidanceTarget = result[2], result[4]
				if
					equalTargets(guidanceTarget, target)
					or setProjectileTarget(projectileID, guidanceTarget, guidanceType)
				then
					return false
				end
			end
		end

		if targetType == targetedUnit then
			guidanceLost(projectileID, params.guidance_lost_radius, target)
		end

		return false
	end
	return true
end

-- Sector fire
-- Changes the targeting error of a weapon to a section in an annulus between a min and max range.
-- Use a weapon with no other sources of inaccuracy for the gui_attack_aoe indicator to be correct.

weaponCustomParamKeys.sector_fire = {
	-- Forms a ring from the weapon's (max range) * (reduction) to its max range.
	max_range_reduction = function(value)
		value = tonumber(value)
		return value and math.clamp(value, 0, 1) or nil
	end,
	-- Forms a section in that ring between (spread_angle) * 0.5 to the left and right of centerline.
	spread_angle = function(value)
		value = tonumber(value)
		return value and value * math_pi / 180 or nil
	end,
}

specialEffectFunction.sector_fire = function(params, projectileID)
	local rangeReductionMax = params.max_range_reduction
	local transformXZ = 1 - (math_random() ^ (1 + rangeReductionMax)) * rangeReductionMax

	local angleSpread = params.spread_angle * (math_random() - 0.5)
	local transformX = math_cos(angleSpread)
	local transformZ = math_sin(angleSpread)

	local velocityX, velocityY, velocityZ = spGetProjectileVelocity(projectileID)
	velocityX = (velocityX * transformX - velocityZ * transformZ) * transformXZ
	velocityZ = (velocityX * transformZ + velocityZ * transformX) * transformXZ
	spSetProjectileVelocity(projectileID, velocityX, velocityY, velocityZ)

	return true
end

-- Split
-- Create a scatter of projectiles from the top of a trajectory to rain down on the targeted position.
-- Use with a weapon with a high firing arc, or it can cause strange behaviors, e.g. when firing down.

weaponCustomParamKeys.split = {
	speceffect_def = toWeaponDefID, -- name of spawned weapondef (weapon type must be non-hitscan)
	number = tonumber, -- count of projectiles to spawn
	splitexplosionceg = tostring, -- name of spawned CEG (use a small puff, there is no damage)
	cegtag = tostring, -- as `projectileParams.cegTag`
	model = tostring, -- as `projectileParams.model`
}

local function split(params, projectileID)
	local weaponDefID, projectileParams, parentSpeed = getProjectileArgs(params, projectileID)

	spDeleteProjectile(projectileID)

	local pos = projectileParams.pos
	spSpawnCEG(params.splitexplosionceg, pos[1], pos[2], pos[3])

	projectileParams.gravity = gravityPerFrame

	local speed = projectileParams.speed
	local velocityX, velocityY, velocityZ = speed[1], speed[2], speed[3]

	for _ = 1, params.number do
		speed[1] = velocityX + parentSpeed * (math_random(-100, 100) / 880)
		speed[2] = velocityY + parentSpeed * (math_random(-100, 100) / 440)
		speed[3] = velocityZ + parentSpeed * (math_random(-100, 100) / 880)

		spSpawnProjectile(weaponDefID, projectileParams)
	end
end

specialEffectFunction.split = function(params, projectileID)
	if isProjectileFalling(projectileID) then
		split(params, projectileID)
		return true
	end
end

-- Water penetration (cannon)
-- Allows for projectiles that change in behavior between above-water and below-water use.
-- Intended for gravity-effected projectiles like Cannon weapons, which it also can spawn.
-- Will prevent the explosion of weapons otherwise configured to explode on hitting water.

weaponCustomParamKeys.cannonwaterpen = {
	speceffect_def = toWeaponDefID, -- name of spawned weapondef (weapon type must be non-hitscan)
	waterpenceg = tostring, -- name of spawned CEG (use a small splash, there is no damage)
	cegtag = tostring, -- as `projectileParams.cegTag`
	model = tostring, -- as `projectileParams.model`
}

local function cannonWaterPen(params, projectileID)
	local weaponDefID, projectileParams = getProjectileArgs(params, projectileID)

	spDeleteProjectile(projectileID)
	spSpawnCEG(params.waterpenceg, projectileParams.pos[1], projectileParams.pos[2], projectileParams.pos[3])

	projectileParams.gravity = gravityPerFrame * 0.5

	local speed = projectileParams.speed
	speed[1] = speed[1] * 0.5
	speed[2] = speed[2] * 0.5
	speed[3] = speed[3] * 0.5

	spSpawnProjectile(weaponDefID, projectileParams)
end

specialEffectFunction.cannonwaterpen = function(params, projectileID)
	if isProjectileInWater(projectileID) then
		cannonWaterPen(params, projectileID)
		return true
	end
end

-- Water penetration (torpedo)
-- Water entry and continuous surface-depth tracking are separate stages.

weaponCustomParamKeys.torpwaterpen = {
	tracking_turn_radius = tonumber, -- turn radius of a tracking projectile, larger gives stronger correction
}

local surfaceTargetDepth = -2
local surfaceTransitionStartDepth = -12
local surfaceDepthCorrection = 0.025
local minSurfaceEntryDiveSpeed = -0.3
local minSurfaceDiveSpeed = -0.12
local minShoreSurfaceDiveSpeed = -4
local maxUnderwaterSurfaceRiseSpeed = 1.25
local surfaceArrivalLeadFrames = 20
local minSurfaceCorrectionFrames = 8
local surfaceCorrectionRampStartFrames = 50
local surfaceCorrectionRampEndFrames = 20
local minSurfaceTrackingCorrection = 0.2
local maxSurfaceTrackingCorrection = 0.5
local defaultTrackingTurnRadius = 180
local surfaceEntryCorrectionDistance = 180
local waterEntryCorrectionStartDepth = -2
local waterEntryCorrectionFullDepth = -10
local terrainAvoidanceClearance = 6
local terrainAvoidanceLookaheadFrames = 4
local terrainAvoidanceRampDepth = 12
local terrainAvoidanceTargetReleaseDistance = 36
---@type table<integer, boolean?>
local torpedoSurfaceTargets = {}
---@type table<integer, true?>
local torpedoWaterEntryHeadingCorrected = {}
---@type table<integer, true?>
local shoreTorpedoEnteredWater = {}
local shoreTorpedoBreachCeiling = 2

local function getTorpedoTargetPosition(projectileID)
	local targetX, targetY, targetZ = getTargetPositionWithError(projectileID)
	if targetY ~= nil then
		-- Retain only the target class when it leaves sensor coverage. The engine
		-- continues horizontal homing; Lua only needs this for vertical guidance.
		torpedoSurfaceTargets[projectileID] = targetY >= -10
	end
	return targetX, targetY, targetZ, torpedoSurfaceTargets[projectileID]
end

local function getTargetHorizontalVelocityWithError(projectileID, targetID)
	local teamID = spGetProjectileTeamID(projectileID) or spGetUnitTeam(spGetProjectileOwnerID(projectileID) or -1)
	local targetVelocityX, _, targetVelocityZ = readAsTeam(teamID, spGetUnitVelocity, targetID)
	return targetVelocityX, targetVelocityZ
end

local function getSurfaceArrivalFrames(
	projectileID,
	targetID,
	positionX,
	positionZ,
	velocityX,
	velocityZ,
	targetX,
	targetZ
)
	local horizontalSpeed = math_diag(velocityX, velocityZ)
	if horizontalSpeed <= 0.01 then
		return
	end

	local horizontalDistance = math_diag(targetX - positionX, targetZ - positionZ)
	local arrivalFrames = horizontalDistance / horizontalSpeed
	local targetVelocityX, targetVelocityZ = getTargetHorizontalVelocityWithError(projectileID, targetID)
	if targetVelocityX ~= nil and targetVelocityZ ~= nil then
		local predictedTargetX = targetX + targetVelocityX * arrivalFrames
		local predictedTargetZ = targetZ + targetVelocityZ * arrivalFrames
		horizontalDistance = math_diag(predictedTargetX - positionX, predictedTargetZ - positionZ)
		arrivalFrames = horizontalDistance / horizontalSpeed
	end
	return arrivalFrames
end

---@param projectileID integer
---@param positionX number
---@param positionY number
---@param positionZ number
---@param velocityX number
---@param velocityY number
---@param velocityZ number
---@param speed number
---@param desiredVelocityY number
---@param smooth number
---@param predictTerrain boolean?
---@param terrainAvoidanceScale number?
local function setTorpedoPitchVelocity(
	projectileID,
	positionX,
	positionY,
	positionZ,
	velocityX,
	velocityY,
	velocityZ,
	speed,
	desiredVelocityY,
	smooth,
	predictTerrain,
	terrainAvoidanceScale
)
	local horizontalSpeed = math_diag(velocityX, velocityZ)
	if not speed or speed <= 0 or horizontalSpeed <= 0 then
		return
	end

	local terrainX, terrainY, terrainZ = positionX, positionY, positionZ
	if predictTerrain then
		terrainX = terrainX + velocityX * terrainAvoidanceLookaheadFrames
		terrainY = terrainY + velocityY * terrainAvoidanceLookaheadFrames
		terrainZ = terrainZ + velocityZ * terrainAvoidanceLookaheadFrames
	end
	local projectedTerrainClearance = terrainY - spGetGroundHeight(terrainX, terrainZ)
	local terrainAvoidanceBlend = 0.0
	if predictTerrain then
		terrainAvoidanceBlend = math_clamp(
			(terrainAvoidanceClearance + terrainAvoidanceRampDepth - projectedTerrainClearance)
				/ terrainAvoidanceRampDepth,
			0,
			1
		)
	elseif projectedTerrainClearance < terrainAvoidanceClearance then
		terrainAvoidanceBlend = 1
	end
	terrainAvoidanceBlend = terrainAvoidanceBlend * (terrainAvoidanceScale or 1)
	if terrainAvoidanceBlend > 0 then
		local normalX, normalY, normalZ = spGetGroundNormal(terrainX, terrainZ, true)
		local terrainVelocityY = velocityY - normalY * (velocityX * normalX + velocityY * normalY + velocityZ * normalZ)
		if predictTerrain then
			-- Submerged-target avoidance may flatten a dive, but must not create
			-- an upward trajectory that can eject the torpedo from the water.
			terrainVelocityY = math.min(terrainVelocityY, 0)
		end
		local blendedTerrainVelocityY = velocityY + (terrainVelocityY - velocityY) * terrainAvoidanceBlend
		desiredVelocityY = math_max(desiredVelocityY, blendedTerrainVelocityY)
	end

	-- Rebuild the full velocity at the desired pitch. Scaling X and Z together
	-- preserves horizontal heading while normalization preserves total speed.
	desiredVelocityY = math_clamp(desiredVelocityY, -speed, speed)
	local desiredHorizontalSpeed = math.sqrt(math_max(speed * speed - desiredVelocityY * desiredVelocityY, 0))
	local horizontalScale = desiredHorizontalSpeed / horizontalSpeed
	local desiredVelocityX = velocityX * horizontalScale
	local desiredVelocityZ = velocityZ * horizontalScale

	velocityX = velocityX + (desiredVelocityX - velocityX) * smooth
	velocityY = velocityY + (desiredVelocityY - velocityY) * smooth
	velocityZ = velocityZ + (desiredVelocityZ - velocityZ) * smooth

	local correctedSpeed = math_diag(velocityX, velocityY, velocityZ)
	if correctedSpeed > 0 then
		local speedScale = speed / correctedSpeed
		spSetProjectileVelocity(projectileID, velocityX * speedScale, velocityY * speedScale, velocityZ * speedScale)
	end
end

local function torpedoWaterPen(params, projectileID)
	local targetX, targetY, targetZ, surfaceTarget = getTorpedoTargetPosition(projectileID)
	if not isProjectileInWater(projectileID) then
		return false
	end

	local velocityX, velocityY, velocityZ, speed = spGetProjectileVelocity(projectileID)
	local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
	if
		velocityX == nil
		or velocityY == nil
		or velocityZ == nil
		or speed == nil
		or positionX == nil
		or positionY == nil
		or positionZ == nil
	then
		return true
	end
	-- Airborne torpedoes do not home before entering the water. Reset their
	-- horizontal bearing once so entry smoothing cannot amplify a stale heading.
	if not torpedoWaterEntryHeadingCorrected[projectileID] and targetX ~= nil and targetZ ~= nil then
		local targetDirectionX = targetX - positionX
		local targetDirectionZ = targetZ - positionZ
		local targetHorizontalDistance = math_diag(targetDirectionX, targetDirectionZ)
		local horizontalSpeed = math_diag(velocityX, velocityZ)
		if targetHorizontalDistance > 0.01 and horizontalSpeed > 0.01 then
			velocityX = targetDirectionX / targetHorizontalDistance * horizontalSpeed
			velocityZ = targetDirectionZ / targetHorizontalDistance * horizontalSpeed
			spSetProjectileVelocity(projectileID, velocityX, velocityY, velocityZ)
			torpedoWaterEntryHeadingCorrected[projectileID] = true
		end
	end
	if surfaceTarget == nil then
		return false
	end
	if not surfaceTarget then
		-- Preserve native submerged-target tracking while anticipating the
		-- seafloor, then release avoidance near the intended impact point.
		local terrainAvoidanceScale = 1.0
		if targetX ~= nil and targetY ~= nil and targetZ ~= nil then
			local targetDistance = math_diag(positionX - targetX, positionY - targetY, positionZ - targetZ)
			terrainAvoidanceScale = math_clamp(targetDistance / terrainAvoidanceTargetReleaseDistance, 0, 1)
		end
		setTorpedoPitchVelocity(
			projectileID,
			positionX,
			positionY,
			positionZ,
			velocityX,
			velocityY,
			velocityZ,
			speed,
			velocityY,
			0.45,
			true,
			terrainAvoidanceScale
		)
		return false
	end

	local trackingTurnRadius = params and params.tracking_turn_radius or defaultTrackingTurnRadius
	local proximityBlend = 0.0
	local surfaceEntryBlend = 0.0
	local entryDepthBlend = math_clamp(
		(waterEntryCorrectionStartDepth - positionY) / (waterEntryCorrectionStartDepth - waterEntryCorrectionFullDepth),
		0,
		1
	)
	if targetX ~= nil and targetY ~= nil and targetZ ~= nil then
		local distance = math_diag(positionX - targetX, positionY - targetY, positionZ - targetZ)
		proximityBlend = math_clamp(1 - distance / trackingTurnRadius, 0, 1)
		surfaceEntryBlend = math_clamp(1 - distance / surfaceEntryCorrectionDistance, 0, 1)
	end
	local entryTargetDepth = surfaceTransitionStartDepth
		+ (surfaceTargetDepth - surfaceTransitionStartDepth) * surfaceEntryBlend
	local desiredVelocityY = math_clamp(
		(entryTargetDepth - positionY) * surfaceDepthCorrection,
		minSurfaceEntryDiveSpeed,
		maxUnderwaterSurfaceRiseSpeed
	)

	setTorpedoPitchVelocity(
		projectileID,
		positionX,
		positionY,
		positionZ,
		velocityX,
		velocityY,
		velocityZ,
		speed,
		desiredVelocityY,
		(0.3 + 0.55 * proximityBlend) * entryDepthBlend
	)

	-- Keep rounding steep water entries until the torpedo is travelling near
	-- its normal surface-running descent rate, then hand off to tracking.
	if velocityY >= minSurfaceDiveSpeed then
		projectiles[projectileID] = specialEffectFunction.torpsurfacetrack
	end
	return false
end

local function torpedoSurfaceTrack(projectileID)
	local projectileDefID = spGetProjectileDefID(projectileID)
	local stayUnderwater = projectileDefID and torpedoStayUnderwaterDefs[projectileDefID]
	local inWater = isProjectileInWater(projectileID)

	if stayUnderwater and inWater then
		shoreTorpedoEnteredWater[projectileID] = true
	elseif not inWater then
		if shoreTorpedoEnteredWater[projectileID] then
			local _, positionY = spGetProjectilePosition(projectileID)
			local velocityX, velocityY, velocityZ = spGetProjectileVelocity(projectileID)
			if positionY == nil or velocityX == nil or velocityY == nil or velocityZ == nil then
				return false
			end
			local returnSpeed = -positionY

			if velocityY > returnSpeed then
				spSetProjectileVelocity(projectileID, velocityX, returnSpeed, velocityZ)
			end
			return false
		end
		return
	end

	local targetType, targetID = spGetProjectileTarget(projectileID)
	if targetType ~= targetedUnit or not targetID then
		return false
	end

	local targetX, _, targetZ, surfaceTarget = getTorpedoTargetPosition(projectileID)
	if surfaceTarget == false then
		return true
	end
	if surfaceTarget == nil then
		return false
	end

	local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
	local velocityX, velocityY, velocityZ, speed = spGetProjectileVelocity(projectileID)
	if
		positionX == nil
		or positionY == nil
		or positionZ == nil
		or velocityX == nil
		or velocityY == nil
		or velocityZ == nil
		or speed == nil
	then
		return false
	end
	local targetPositionKnown = targetX ~= nil and targetZ ~= nil
	local arrivalFrames
	if targetPositionKnown then
		arrivalFrames = getSurfaceArrivalFrames(
			projectileID,
			targetID,
			positionX,
			positionZ,
			velocityX,
			velocityZ,
			targetX,
			targetZ
		)
	end

	local minDiveSpeed = stayUnderwater and minShoreSurfaceDiveSpeed or minSurfaceDiveSpeed
	local desiredVelocityY = minDiveSpeed
	local correctionStrength = minSurfaceTrackingCorrection
	if arrivalFrames then
		local correctionFrames
		if stayUnderwater and positionY > surfaceTargetDepth then
			correctionFrames = math_max(arrivalFrames, 1)
			correctionStrength = maxSurfaceTrackingCorrection
		else
			correctionFrames = math_max(arrivalFrames - surfaceArrivalLeadFrames, minSurfaceCorrectionFrames)
			local arrivalBlend = math_clamp(
				(surfaceCorrectionRampStartFrames - arrivalFrames)
					/ (surfaceCorrectionRampStartFrames - surfaceCorrectionRampEndFrames),
				0,
				1
			)
			correctionStrength = minSurfaceTrackingCorrection
				+ (maxSurfaceTrackingCorrection - minSurfaceTrackingCorrection) * arrivalBlend
		end
		desiredVelocityY =
			math_clamp((surfaceTargetDepth - positionY) / correctionFrames, minDiveSpeed, maxUnderwaterSurfaceRiseSpeed)
	else
		desiredVelocityY = math_clamp(
			(surfaceTargetDepth - positionY) * surfaceDepthCorrection,
			minDiveSpeed,
			maxUnderwaterSurfaceRiseSpeed
		)
	end

	setTorpedoPitchVelocity(
		projectileID,
		positionX,
		positionY,
		positionZ,
		velocityX,
		velocityY,
		velocityZ,
		speed,
		desiredVelocityY,
		correctionStrength
	)

	if stayUnderwater then
		local currentPositionX, currentPositionY, currentPositionZ = spGetProjectilePosition(projectileID)
		local currentVelocityX, currentVelocityY, currentVelocityZ, currentSpeed = spGetProjectileVelocity(projectileID)
		if
			currentPositionX == nil
			or currentPositionY == nil
			or currentPositionZ == nil
			or currentVelocityX == nil
			or currentVelocityY == nil
			or currentVelocityZ == nil
			or currentSpeed == nil
		then
			return false
		end
		local maxRiseSpeed = shoreTorpedoBreachCeiling - currentPositionY

		if currentVelocityY > maxRiseSpeed then
			setTorpedoPitchVelocity(
				projectileID,
				currentPositionX,
				currentPositionY,
				currentPositionZ,
				currentVelocityX,
				currentVelocityY,
				currentVelocityZ,
				currentSpeed,
				maxRiseSpeed,
				1
			)
		end
	end

	return false
end

specialEffectFunction.torpwaterpen = torpedoWaterPen
specialEffectFunction.torpsurfacetrack = torpedoSurfaceTrack

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	local metatables = {}

	for effectName, effectFunction in pairs(specialEffectFunction) do
		-- Add self-call syntax to weapondef special effects:
		metatables[effectName] = { __call = effectFunction }
	end

	-- cruise speceffect has extra stages with their own effect:
	local cruiseWaitingMetatable = { __call = cruiseWaiting }
	local cruiseEngagedMetatable = { __call = cruiseEngaged }

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams.torpedo_stay_underwater then
			torpedoStayUnderwaterDefs[weaponDefID] = true
		end

		if weaponDef.customParams.speceffect then
			local effectName, effectParams = parseCustomParams(weaponDef)

			if effectName then
				if next(effectParams) then
					-- When configured to a weapon's customParams, call the effect with its `params`:
					weaponDefEffect[weaponDefID] = setmetatable(effectParams, metatables[effectName])

					if effectName == "cruise" then
						cruiseWaitingDefs[weaponDefID] = setmetatable(table.copy(effectParams), cruiseWaitingMetatable)
						cruiseEngagedDefs[weaponDefID] = setmetatable(table.copy(effectParams), cruiseEngagedMetatable)
					end
				else
					-- Otherwise, call the effect directly (skips the `params` arg):
					weaponDefEffect[weaponDefID] = specialEffectFunction[effectName]
				end
			end
		end
	end

	if next(weaponDefEffect) then
		for weaponDefID in pairs(weaponDefEffect) do
			Script.SetWatchProjectile(weaponDefID, true)
		end
		gameFrame = Spring.GetGameFrame()
	else
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No custom weapons found.")
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:ProjectileCreated(projectileID, proOwnerID, weaponDefID)
	if weaponDefEffect[weaponDefID] then
		projectiles[projectileID] = weaponDefEffect[weaponDefID]
	end
end

function gadget:ProjectileDestroyed(projectileID)
	projectiles[projectileID] = nil
	torpedoSurfaceTargets[projectileID] = nil
	torpedoWaterEntryHeadingCorrected[projectileID] = nil
	shoreTorpedoEnteredWater[projectileID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame
	guidanceResults = {}

	for projectileID, effect in pairs(projectiles) do
		if effect(projectileID) then
			projectiles[projectileID] = nil
		end
	end
end
