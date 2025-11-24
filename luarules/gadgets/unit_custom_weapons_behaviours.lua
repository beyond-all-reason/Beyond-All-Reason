local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Custom weapon behaviours",
		desc    = "Handler for special weapon behaviours",
		author  = "Doo",
		date    = "Sept 19th 2017",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local math_random = math.random
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local math_tau = math.tau
local distance3dSquared = math.distance3dSquared

local spDeleteProjectile = Spring.DeleteProjectile
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundNormal = Spring.GetGroundNormal
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileTarget = Spring.SetProjectileTarget
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spSpawnCEG = Spring.SpawnCEG
local spSpawnProjectile = Spring.SpawnProjectile

local gravityPerFrame = -Game.gravity / (Game.gameSpeed * Game.gameSpeed)

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local specialEffectFunction = {}
local weaponCustomParamKeys = {} -- [effect] = { [key] = conversion function }

local weaponDefEffect = {}

local projectiles = {}
local projectilesData = {}

local gameFrame = 0

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function parseCustomParams(weaponDef)
	local success = true

	local effectName = weaponDef.customParams.speceffect

	if not specialEffectFunction[effectName] then
		local message = weaponDef.name .. " has bad speceffect: " .. tostring(effectName)
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	local effectParams = {}

	if weaponCustomParamKeys[effectName] then
		for key, conversion in pairs(weaponCustomParamKeys[effectName]) do
			if weaponDef.customParams[key] then
				local value = conversion(weaponDef.customParams[key])
				if value ~= nil then
					effectParams[key] = value
				else
					local message = weaponDef.name .. " has bad customparam: " .. tostring(key)
					Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

					success = false
				end
			end
		end
	end

	-- Modders/tweakdefs are likely to use these values for a while:
	if weaponDef.customParams.def or weaponDef.customParams.when then
		local message = weaponDef.name .. " uses old customparams (def/when)"
		Spring.Log(gadget:GetInfo().name, LOG.DEPRECATED, message)
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
	return value and math.max(0, value) or nil
end

--- Weapon behaviors -----------------------------------------------------------

local function isProjectileFalling(projectileID)
	local _, velocityY = spGetProjectileVelocity(projectileID)
	return velocityY < 0
end

local function isProjectileInWater(projectileID)
	local _, positionY = spGetProjectilePosition(projectileID)
	return positionY <= 0
end

local function equalTargets(target1, target2)
	return target1 == target2 or (
		type(target1) == "table" and
		type(target2) == "table" and
		target1[1] == target2[1] and
		target1[2] == target2[2] and
		target1[3] == target2[3]
	)
end

local getProjectileArgs
do
	---@class ProjectileParams
	local projectileParams = {
		pos     = { 0, 0, 0 },
		speed   = { 0, 0, 0 },
		gravity = gravityPerFrame,
		ttl     = 3000,
	}

	---@return integer weaponDefID
	---@return ProjectileParams projectileParams
	---@return number parentSpeed
	getProjectileArgs = function(params, projectileID)
		local weaponDefID = params.speceffect_def

		local projectileParams = projectileParams

		local pos = projectileParams.pos
		pos[1], pos[2], pos[3] = spGetProjectilePosition(projectileID)

		local vel = projectileParams.speed
		local parentSpeed
		vel[1], vel[2], vel[3], parentSpeed = spGetProjectileVelocity(projectileID)

		projectileParams.owner = spGetProjectileOwnerID(projectileID)
		projectileParams.cegTag = params.cegtag
		projectileParams.model = params.model

		return weaponDefID, projectileParams, parentSpeed
	end
end

-- Cruise
-- Missile guidance behavior that avoids crashing into terrain while heading toward the target.
-- Intended to be used with non-homing weapons, since it updates the velocity independently.

weaponCustomParamKeys.cruise = {
	cruise_min_height = toPositiveNumber, -- Minimum ground clearance. Checked each frame, but no lookahead.
	lockon_dist       = toPositiveNumber, -- Within this radius, disables the auto ground clearance.
}

local function applyCruiseCorrection(projectileID, positionX, positionY, positionZ, velocityX, velocityY, velocityZ)
	local normalX, normalY, normalZ = spGetGroundNormal(positionX, positionZ)
	local codirection = velocityX * normalX + velocityY * normalY + velocityZ * normalZ
	velocityY = velocityY - normalY * codirection -- NB: can be a little strong on uneven terrain
	spSetProjectilePosition(projectileID, positionX, positionY, positionZ)
	spSetProjectileVelocity(projectileID, velocityX, velocityY, velocityZ)
end

specialEffectFunction.cruise = function(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
		local velocityX, velocityY, velocityZ, speed = spGetProjectileVelocity(projectileID)
		local targetType, target = spGetProjectileTarget(projectileID)

		local targetX, targetY, targetZ
		if targetType == targetedUnit then
			local _; -- declare a local sink var for unused values
			_, _, _, targetX, targetY, targetZ = spGetUnitPosition(target, false, true)
		elseif targetType == targetedGround then
			targetX, targetY, targetZ = target[1], target[2], target[3]
		end

		local distance = params.lockon_dist

		if distance * distance < distance3dSquared(positionX, positionY, positionZ, targetX, targetY, targetZ) then
			local cruiseHeight = spGetGroundHeight(positionX, positionZ) + params.cruise_min_height

			if positionY < cruiseHeight then
				projectilesData[projectileID] = true
				applyCruiseCorrection(projectileID, positionX, cruiseHeight, positionZ, velocityX, velocityY, velocityZ)
			elseif projectilesData[projectileID]
				and positionY > cruiseHeight
				and velocityY > speed * -0.25 -- Avoid going into steep dives, e.g. after cliffs.
			then
				applyCruiseCorrection(projectileID, positionX, cruiseHeight, positionZ, velocityX, velocityY, velocityZ)
			end

			return false
		end
	end

	projectilesData[projectileID] = nil

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
				local ownerTargetType, _, ownerTarget = spGetUnitWeaponTarget(ownerID, 1)

				if ownerTargetType == 1 then
					spSetProjectileTarget(projectileID, ownerTarget, targetedUnit)
				elseif ownerTargetType == 2 then
					spSetProjectileTarget(projectileID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
				end
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

-- Based on retarget
-- Uses no weapon customParams.

-- Guidance weapon must be the primary and have burst/reload > 1 frame.
-- This is hackish but works well to prevent spammy retargeting anyway.
weaponCustomParamKeys.guidance = {
	guidance_miss_radius = toPositiveNumber,
}

local function guidanceLost(radius, projectileID, targetID)
	local tx, ty, tz

	if radius > 0 then
		local _, _, _, ux, uy, uz = spGetUnitPosition(targetID, false, true)
		local elevation = max(spGetGroundHeight(ux, uz), 0)
		local dx, dy, dz, slope = spGetGroundNormal(ux, uz, true)
		local swerveRadius = radius * (0.25 + 0.75 * math_random())
		local swerveAngle = math_tau * math_random()
		local cosAngle = math_cos(swerveAngle)
		local sinAngle = math_sin(swerveAngle)

		if elevation <= 0 or slope <= 0.1 then
			-- Scatter within a ring in the XZ plane.
			tx = ux + swerveRadius * cosAngle
			ty = uy
			tz = uz + swerveRadius * sinAngle
		else
			-- Scatter within a ring rotated to align with terrain.
			local ax, ay, az = 0, 1, 0
			if dy >= 0.99 then ax, ay = 1, 0 end
			local bx = ay * dz - az * dy
			local by = az * dx - ax * dz
			local bz = ax * dy - ay * dx
			local cx = dy * bz - dz * by
			local cy = dz * bx - dx * bz
			local cz = dx * by - dy * bx
			tx = ux + swerveRadius * (cosAngle + bx + sinAngle * cx)
			ty = uy + swerveRadius * (cosAngle + by + sinAngle * cy)
			tz = uz + swerveRadius * (cosAngle + bz + sinAngle * cz)
		end
	else
		tx, ty, tz = spGetUnitPosition(targetID)
	end

	local elevation = max(spGetGroundHeight(tx, tz), 0)
	spSetProjectileTarget(projectileID, tx, (ty - elevation < 40) and elevation or ((ty + elevation) * 0.5), tz)
end

---@class GuidanceEffectResult
---@field [1] boolean isFiring
---@field [2] TargetType guidanceType
---@field [3] boolean isUserTarget
---@field [4] integer|xyz guidanceTarget

local guidanceResults = {} ---@type table<integer, GuidanceEffectResult>

specialEffectFunction.guidance = function(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local ownerID = spGetProjectileOwnerID(projectileID)
		local targetType, target = spGetProjectileTarget(projectileID)

		if ownerID and spGetUnitIsDead(ownerID) == false then
			local result = guidanceResults[ownerID]
			if not result then
				result = { spGetUnitWeaponState(ownerID, 1, "nextSalvo") + 1 >= gameFrame, spGetUnitWeaponTarget(ownerID, 1) } ---@diagnostic disable-line
				guidanceResults[ownerID] = result
			end
			if result[1] and result[2] then
				local guidanceType, guidanceTarget = result[2], result[4]
				if not equalTargets(guidanceTarget, target) then
					if guidanceType == 1 then
						spSetProjectileTarget(projectileID, guidanceTarget, targetedUnit)
						return false
					elseif guidanceType == 2 then
						spSetProjectileTarget(projectileID, guidanceTarget[1], guidanceTarget[2], guidanceTarget[3])
						return false
					end
				end
			end
		end

		if targetType == targetedUnit then
			guidanceLost(params.guidance_miss_radius, projectileID, target)
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
	speceffect_def    = toWeaponDefID, -- name of spawned weapondef (weapon type must be non-hitscan)
	number            = tonumber, -- count of projectiles to spawn
	splitexplosionceg = tostring, -- name of spawned CEG (use a small puff, there is no damage)
	cegtag            = tostring, -- as `projectileParams.cegTag`
	model             = tostring, -- as `projectileParams.model`
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
	waterpenceg    = tostring, -- name of spawned CEG (use a small splash, there is no damage)
	cegtag         = tostring, -- as `projectileParams.cegTag`
	model          = tostring, -- as `projectileParams.model`
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
-- Torpedoes are tracking with very high turn rates which causes problems depending on initial conditions.
-- This eliminates vertical velocity so torpedo bombers work in shallows and sets a lower initial speed.

-- Uses no weapon customParams.

local function torpedoWaterPen(projectileID)
	local velocityX, velocityY, velocityZ = spGetProjectileVelocity(projectileID)
	local targetType, targetID = spGetProjectileTarget(projectileID)

	-- Underwater projectiles have low visibility. Remaining on surface is preferable.
	-- Only dive below the water's surface if the target is likely an underwater unit.
	local diveSpeed = 0

	if targetType == targetedUnit and targetID then
		local _, unitDepth = spGetUnitPosition(targetID)
		-- BAR trivia: Ships are at depth = -1, and subs at depth < -10.
		if unitDepth and unitDepth < -10 then
			-- Apply brake without halting, otherwise it will overshoot close targets.
			diveSpeed = velocityY / 6
			velocityX, velocityZ = velocityX / 1.3, velocityZ / 1.3
		end
	end

	spSetProjectileVelocity(projectileID, velocityX, diveSpeed, velocityZ)
end

specialEffectFunction.torpwaterpen = function(projectileID)
	if isProjectileInWater(projectileID) then
		torpedoWaterPen(projectileID)
		return true
	end
end

-- Water penetration with retargeting (torpedo)
-- This is a WIP solution for massed torpedo gunships to get value out of otherwise-wasted shots.
-- Limited to use by tweakdefs/modders for now and the (unmaintained?) Hornet balance test packs.

-- Torpedoes are semi-magical to prevent hitting allied units while skimming the water's surface,
-- so remain active when overkilling targets. This simplifies micro and discourages the knowledge
-- check of perfect torpedo bombing outside AA range since `retarget` needs continued proximity.

-- Uses no weapon customParams.

do
	local retarget = specialEffectFunction.retarget
	local torpedoWaterPen = specialEffectFunction.torpwaterpen

	specialEffectFunction.torpwaterpenretarget = function(projectileID)
		if retarget(projectileID) then
			projectiles[projectileID] = torpedoWaterPen
			return torpedoWaterPen(projectileID)
		elseif torpedoWaterPen(projectileID) then
			projectiles[projectileID] = retarget
		end
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	local metatables = {}

	for effectName, effectFunction in pairs(specialEffectFunction) do
		-- Add self-call syntax to weapondef special effects:
		metatables[effectName] = { __call = effectFunction }
	end

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams.speceffect then
			local effectName, effectParams = parseCustomParams(weaponDef)

			if effectName then
				if next(effectParams) then
					-- When configured to a weapon's customParams, call the effect with its `params`:
					weaponDefEffect[weaponDefID] = setmetatable(effectParams, metatables[effectName])
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
	projectilesData[projectileID] = nil
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
