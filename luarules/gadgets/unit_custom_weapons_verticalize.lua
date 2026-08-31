local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name = "Starburst cruise and verticalize",
		desc = "Trajectory alchemy for projectiles that must not hit terrain",
		author = "efrec",
		license = "GNU GPL, v2 or later",
		layer = -10000, -- before other gadgets can process projectiles
		enabled = true,
	}
end

-- Requires a StarburstLauncher weapondef with the customparam values:
-- cruise_and_verticalize  := true     gate for the weapondef's registration
-- cruise_altitude         := number?  height above ground at level, else "auto"
-- uptime_max              := number?  in seconds, overrides the weaponDef
-- cruise_chase_factor     := number?  [0, 2] 0:=hard turn 1:=constant 2:=chases
--                                     else 0.2, not a flag, value is fractional

--------------------------------------------------------------------------------
-- [1] Cruise altitude is set by the launcher and uptime -----------------------
--                                                                            --
--    cruise altitude  x------------------------------x                       --
--                    /                                \                      --
--                   /                                  \                     --
--  end uptime pos  x                                    x   verticalized     --
--                  |                                    |                    --
--                  |                                    |                    --
-- launch position  x                                    |                    --
--                                                       |                    --
--                                                       x   target position  --
--                                                                            --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- [2] Cruise altitude is set by the target position ---------------------------
--                                                                            --
--                     x------------------------------x   cruise altitude     --
--                    /                                \                      --
--                   /                                  \                     --
-- ascend position  x                                    x   verticalized     --
--                  |                                    |                    --
--                  |                                    |                    --
--  end uptime pos  x                                    x   target position  --
--                  |                                                         --
--                  |                                                         --
-- launch position  x                                                         --
--                                                                            --
--------------------------------------------------------------------------------

-- We do things the way we do because the `turnToTarget` flag shuts off tracking
-- in StarburstProjectile.cpp once the projectile gets within about a 8.1 degree
-- angle to the target position. I don't want to rely on frame-perfect copies of
-- engine behavior in the game lua. Also, we want to shape the vertical descent.

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local cruiseHeightMin = 50 -- note: barely above ground
local cruiseHeightMax = 3000 -- note: not all that high up
local checkWindowFrames = 6 -- count of polling frames used to predict new phases
local chaseFactorDefault = 0.2 -- [0, 2] where 0 is a clean quarter-turn onto target

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_diag = math.diag
local math_pi = math.pi
local math_acos = math.acos
local math_sin = math.sin
local math_asin = math.asin

local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileVelocity = Spring.SetProjectileVelocity

local targetedUnit = string.byte("u")

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weapons = {}
local projectiles = {}
local moveControl = {}
local scheduled = {}

local gameFrame = 0
local inSpawnProjectile = false

--------------------------------------------------------------------------------
-- Vectors minilib -------------------------------------------------------------

local ARC_EPSILON = 1e-6
local ARC_NORMAL_EPSILON = 1 - 1e-6

local function distanceXZ(position1, position2)
	return math_diag(position1[1] - position2[1], position1[3] - position2[3])
end

local function isInCylinder(vector, origin, radius)
	local v1, v3 = vector[1], vector[3]
	local o1, o3 = origin[1], origin[3]
	return radius * radius >= (v1 - o1) * (v1 - o1) + (v3 - o3) * (v3 - o3)
end

local positionGuidance = { 0, 0, 0, isInCylinder = isInCylinder }
local velocityGuidance = { 0, 0, 0, 0 }

local function getPosition(projectileID)
	local position = positionGuidance
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	return position
end

local function getVelocity(projectileID)
	local velocity = velocityGuidance
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return velocity
end

local function getPositionAndVelocity(projectileID)
	local position, velocity = positionGuidance, velocityGuidance
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return position, velocity
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function getVerticalizeWeapon(weaponDef)
	if weaponDef.type ~= "StarburstLauncher" or weaponDef.interceptor ~= 0 then
		return
	end
	if weaponDef.turnRate <= 0 then
		return
	end

	local cruiseHeight = tonumber(weaponDef.customParams.cruise_altitude) or "auto"
	local upTimeMax = tonumber(weaponDef.customParams.uptime_max) or weaponDef.uptime
	local chaseFactor = tonumber(weaponDef.customParams.cruise_chase_factor) or chaseFactorDefault

	local acceleration = weaponDef.weaponAcceleration
	local speedMin = weaponDef.startvelocity
	local speedMax = weaponDef.projectilespeed
	local turnRate = weaponDef.turnRate
	local upTimeMin = weaponDef.uptime

	local upTimeMinFrames = upTimeMin * Game.gameSpeed
	local upTimeMaxFrames = upTimeMax * Game.gameSpeed

	local accelerationFrames = 0.0
	if acceleration and acceleration ~= 0.0 then
		accelerationFrames = math_min((speedMax - speedMin) / acceleration, upTimeMinFrames)
	end

	local turnSpeedMin = speedMin + accelerationFrames * acceleration
	local turnHeightMin = turnSpeedMin * upTimeMinFrames - accelerationFrames * (turnSpeedMin - speedMin) * 0.5

	-- The initial turn uses the engine's rotation and acceleration during the entire arc.
	-- A quarter-turn raises its entry radius by (1 - 2/pi) of the radius gained via accel.
	local turnSpeedTop = math_min(turnSpeedMin + acceleration * math_pi * 0.5 / turnRate, speedMax)
	local ascentRadius = (turnSpeedMin + (turnSpeedTop - turnSpeedMin) * (1 - 2 / math_pi)) / turnRate

	-- The final turn uses MoveControl and widened by the chase factor, at up to speedMax.
	local diveRadiusMax = (1 + chaseFactor) * speedMax / turnRate

	if cruiseHeight == "auto" then
		cruiseHeight = turnHeightMin + ascentRadius
	end

	cruiseHeight = math_clamp(cruiseHeight, cruiseHeightMin, cruiseHeightMax)

	if diveRadiusMax > cruiseHeight then
		local message = weaponDef.name .. " drops on a turn wider than its cruise height so impacts on a curve."
		Spring.Log(gadget:GetInfo().name, LOG.NOTICE, message)
	end

	return {
		acceleration = acceleration,
		speedMax = speedMax,
		speedMin = speedMin,
		turnRate = turnRate,

		heightIntoTurn = turnHeightMin,
		rangeMaximum = weaponDef.range,
		upTimeMaxFrames = upTimeMaxFrames,
		upTimeMinFrames = upTimeMinFrames,

		cruiseHeight = cruiseHeight,
		ascentRadius = ascentRadius,
		diveRadiusMax = diveRadiusMax,
		chaseFactor = chaseFactor,
		diveSpeedGain = math_pi * acceleration * (1 + chaseFactor) / turnRate,

		tracking = weaponDef.tracks and turnRate or 0,
		gravity = weaponDef.myGravity ~= 0 and -weaponDef.myGravity or nil,
		cegTag = weaponDef.cegTag,
	}
end

local function scheduleAt(projectileID, frame)
	local bin = scheduled[frame]
	if not bin then
		bin = {}
		scheduled[frame] = bin
	end
	bin[#bin + 1] = projectileID
end

local function getUnitPositionWithError(unitID, teamID)
	return CallAsTeam(teamID, Spring.GetUnitPosition, unitID)
end

local function getTargetPosition(projectileID)
	local xyz
	local targetType, target = Spring.GetProjectileTarget(projectileID)
	if type(target) == "table" then
		xyz = target
	elseif targetType == targetedUnit then
		xyz = { getUnitPositionWithError(target, Spring.GetProjectileTeamID(projectileID)) }
		xyz[2] = math_max(Spring.GetGroundHeight(xyz[1], xyz[3]), 0)
	end
	return xyz
end

-- Launching -------------------------------------------------------------------

local function getUptime(projectile, height)
	local speedMin = projectile.speedMin
	local speedMax = projectile.speedMax
	local acceleration = projectile.acceleration

	if acceleration == 0 or speedMin == speedMax then
		return height / speedMax
	end

	if height < speedMin then
		return 0
	end

	local accelTime = (speedMax - speedMin) / acceleration
	local accelDistance = speedMin * accelTime + 0.5 * acceleration * accelTime * accelTime

	if accelDistance <= height then
		local flatTime = (height - accelDistance) / speedMax
		local speedAvg = (flatTime * speedMax + accelTime * (speedMax + speedMin) * 0.5) / (flatTime + accelTime)
		return height / speedAvg
	end

	-- Solve d = 0.5 a t^2 + v_0 t for time t:
	local a, b, c = 0.5 * acceleration, speedMin, -height
	local discriminant = b * b - 4 * a * c

	if discriminant < 0 then
		return 0
	end

	discriminant = math_sqrt(discriminant)
	local t1 = (-b + discriminant) / (2 * a)
	local t2 = (-b - discriminant) / (2 * a)
	return (t1 >= 0 and t2 >= 0) and math_min(t1, t2) or (t1 >= 0 and t1 or t2)
end

---@class ProjectileParams
---@field cegtag number
---@field maxRange number
---@field tracking number
---@field upTime number
local projectileParams = {
	pos = positionGuidance,
	speed = velocityGuidance,
}

local function respawn(weapon, projectileID, projectile, upTimeFrames)
	if upTimeFrames <= 0 then
		local target = projectile.target
		Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
		return false
	end

	local weaponDefID = assert(Spring.GetProjectileDefID(projectileID))
	local spawnParams = projectileParams
	spawnParams.owner = Spring.GetProjectileOwnerID(projectileID) or -1
	spawnParams.team = Spring.GetProjectileTeamID(projectileID)
	spawnParams.ttl = Spring.GetProjectileTimeToLive(projectileID) or 1e6
	spawnParams["end"] = projectile.target
	spawnParams.gravity = weapon.gravity
	spawnParams.cegtag = weapon.cegTag -- note: is lower case
	spawnParams.maxRange = weapon.rangeMaximum -- zero disables StarburstProjectile turn/tracking
	spawnParams.tracking = weapon.tracking
	spawnParams.upTime = upTimeFrames
	getVelocity(projectileID) -- populates spawnParams.speed
	spawnParams.speed[4] = nil -- engine needs `xyz`

	Spring.DeleteProjectile(projectileID)

	inSpawnProjectile = true
	local respawnID = Spring.SpawnProjectile(weaponDefID, spawnParams)
	inSpawnProjectile = false

	if not respawnID then
		return false
	end

	projectiles[respawnID] = projectile
	scheduleAt(respawnID, math_max(gameFrame + math_floor(upTimeFrames) - checkWindowFrames, gameFrame + 1))
	Spring.SetProjectileTarget(
		respawnID,
		projectile.target[1],
		projectile.ascendHeight + weapon.ascentRadius,
		projectile.target[3]
	)
	return true
end

local function register(projectileID, weaponDefID)
	if inSpawnProjectile then
		return
	end

	local position = getPosition(projectileID)
	local target = getTargetPosition(projectileID)
	if not target then
		return
	end

	local weapon = weapons[weaponDefID] ---@type table
	local ascentRadius = weapon.ascentRadius
	local ascentAboveLauncher = position[2] + weapon.heightIntoTurn
	local ascentAboveTarget = target[2] + weapon.cruiseHeight - ascentRadius
	local ascendHeight = math_max(ascentAboveLauncher, ascentAboveTarget)

	local projectile = {
		acceleration = weapon.acceleration,
		speedMax = weapon.speedMax,
		speedMin = weapon.speedMin,
		turnRate = weapon.turnRate,
		chaseFactor = weapon.chaseFactor,
		diveSpeedGain = weapon.diveSpeedGain,
		target = target,
		ascendHeight = ascendHeight,
		diveRadiusMax = weapon.diveRadiusMax,

		phase = 1,
		pitch = 2,
		cruiseEndInverse = 0,
	}

	local targetDistance = distanceXZ(position, target)
	local upTimeFrames =
		math_clamp(getUptime(projectile, ascendHeight - position[2]), weapon.upTimeMinFrames, weapon.upTimeMaxFrames)

	if upTimeFrames >= weapon.upTimeMinFrames + 0.5 then
		if respawn(weapon, projectileID, projectile, upTimeFrames) then
			return
		end
		upTimeFrames = weapon.upTimeMinFrames
	end

	if targetDistance <= ascentRadius * 0.5 then
		return -- Nothing to guide, with the target this far inside the ascent turn.
	end

	projectiles[projectileID] = projectile
	scheduleAt(projectileID, math_max(gameFrame + math_floor(upTimeFrames) - checkWindowFrames, gameFrame + 1))

	local targetHeight = ascendHeight + ascentRadius
	Spring.SetProjectileTarget(projectileID, target[1], targetHeight, target[3])
end

-- Flight plan phases ----------------------------------------------------------

local function ascend(projectileID, projectile, frame)
	local position, velocity = getPositionAndVelocity(projectileID)

	if velocity[4] <= 0 then
		return frame + 1
	end

	-- Hand off at the ascend height or, on a climb cut short, once it stops climbing.
	if velocity[2] > 0 and projectile.ascendHeight - position[2] >= velocity[2] then
		return frame + 1
	end

	projectile.phase = projectile.phase + 1

	local pitchAngle = math_asin(math_clamp(math_abs(velocity[2]) / velocity[4], 0, 1))
	local turnFrames = pitchAngle / projectile.turnRate

	local speedMax = projectile.speedMax
	local dropRadiusFrames = (distanceXZ(position, projectile.target) - projectile.diveRadiusMax) / speedMax

	return frame + math_floor(math_min(turnFrames, dropRadiusFrames)) - checkWindowFrames
end

-- Descent curvature is constant at radius r := (1 + chase) * v / turnRate.
-- The radius increases with chase factor, then. Once r exceeds the height,
-- which has to be avoided by tuning the weapondef properly and has no fix,
-- the projectile flies in on a wider drop and impacts before verticalized.
--
-- That impact comes before the quarter turn, then, at acos(1 - height/r).
-- Taking the quarter turn as the arc length is therefore an upper bound:
--     v^2 = speed^2 + 2 * acceleration * arc
--  => v^2 - diveSpeedGain * v - speed^2 = 0
local function getDiveSpeed(projectile, speed)
	local gain = projectile.diveSpeedGain
	local diveSpeed = 0.5 * (gain + math_sqrt(gain * gain + 4 * speed * speed))
	return math_min(diveSpeed, projectile.speedMax)
end

local function turnToLevel(projectileID, projectile, frame)
	local velocity = getVelocity(projectileID)
	if velocity[4] <= 0 then
		return frame + 1
	end

	local pitch = math_asin(math_clamp(velocity[2] / velocity[4], -1, 1))

	-- Pitch is constant while still climbing, too, so wait out an early hand-off.
	if pitch >= math_pi * 0.5 - projectile.turnRate then
		projectile.pitch = pitch
		return frame + 1
	end

	-- StarburstProjectile disables turning at 8.1 degrees to target, then keeps constant pitch.
	if projectile.pitch - pitch > projectile.turnRate * 0.5 then
		projectile.pitch = pitch
		return frame + 1
	end

	projectile.phase = projectile.phase + 1
	local cruiseEndRadius = (1 + projectile.chaseFactor) * getDiveSpeed(projectile, velocity[4]) / projectile.turnRate
	local cruiseDistance = distanceXZ(getPosition(projectileID), projectile.target) - cruiseEndRadius
	return frame + math_floor(cruiseDistance / projectile.speedMax) - checkWindowFrames
end

local function cruise(projectileID, projectile, frame)
	local position, velocity = getPositionAndVelocity(projectileID)
	if velocity[4] <= 0 then
		return frame + 1 -- guidance will div0
	end

	-- Most vertical-launch missiles accelerate slowly so are still gaining speed here.
	local target = projectile.target
	local cruiseEndRadius = (1 + projectile.chaseFactor) * getDiveSpeed(projectile, velocity[4]) / projectile.turnRate
	if not position:isInCylinder(target, cruiseEndRadius) then
		return frame + 1
	end

	-- We leave the engine `phase` tracking and begin using lua's scripted MoveControl.
	moveControl[projectileID] = projectile

	projectile.cruiseEndInverse = 1 / cruiseEndRadius
	projectile.px, projectile.py, projectile.pz = position[1], position[2], position[3]
	projectile.vx, projectile.vy, projectile.vz = velocity[1], velocity[2], velocity[3]
	projectile.speed = velocity[4]
	Spring.SetProjectileMoveControl(projectileID, true)
	Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
end

local function verticalize(projectileID, projectile)
	local px, py, pz = projectile.px, projectile.py, projectile.pz
	local vx, vy, vz = projectile.vx, projectile.vy, projectile.vz
	local speed = projectile.speed

	local target = projectile.target
	local dx = target[1] - px
	local dz = target[3] - pz
	local distance = math_diag(dx, dz)

	-- We don't have many weapondef-invariant checks left, so this
	-- may be useful only for consistently shaping the drop, now.
	local sinPitch = 1 - distance * projectile.cruiseEndInverse
	if sinPitch < 0 then
		sinPitch = 0
	end
	local cosPitch = math_sqrt(1 - sinPitch * sinPitch)

	-- Unit vector towards target
	local tx, ty, tz = 0, -sinPitch, 0
	if distance > 0 then
		local distInverse = cosPitch / distance
		tx = dx * distInverse
		tz = dz * distInverse
	end

	local cosAngle = (vx * tx + vy * ty + vz * tz) / speed
	if cosAngle > 1 then
		cosAngle = 1
	elseif cosAngle < -1 then
		cosAngle = -1
	end

	-- Spherical-lerp velocity toward the target up to the turnRate.
	-- A vanishing sine is parallel or antiparallel so keeps steady.
	local sinAngle = math_sqrt(1 - cosAngle * cosAngle)
	if sinAngle > ARC_EPSILON then
		local angle = math_acos(cosAngle)
		local factor = projectile.turnRate / angle
		if factor < ARC_NORMAL_EPSILON then
			local weight1 = math_sin((1 - factor) * angle) / speed
			local weight2 = math_sin(factor * angle)
			local scale = speed / sinAngle
			vx = (vx * weight1 + tx * weight2) * scale
			vy = (vy * weight1 + ty * weight2) * scale
			vz = (vz * weight1 + tz * weight2) * scale
		else
			vx, vy, vz = tx * speed, ty * speed, tz * speed
		end
	end

	local speedNew = math_min(speed + projectile.acceleration, projectile.speedMax)
	local ratio = speedNew / speed
	vx, vy, vz = vx * ratio, vy * ratio, vz * ratio
	px, py, pz = px + vx, py + vy, pz + vz

	projectile.px, projectile.py, projectile.pz = px, py, pz
	projectile.vx, projectile.vy, projectile.vz = vx, vy, vz
	projectile.speed = speed * ratio

	spSetProjectilePosition(projectileID, px, py, pz)
	spSetProjectileVelocity(projectileID, vx, vy, vz)
end

local enginePhases = { ascend, turnToLevel, cruise } -- end into => verticalize

local function updatePhases(checkList, frame)
	for i = 1, #checkList do
		local projectileID = checkList[i]
		local projectile = projectiles[projectileID] -- may have been destroyed
		if projectile then
			repeat
				local checkFrame = enginePhases[projectile.phase](projectileID, projectile, frame)
				if not checkFrame then
					break
				elseif checkFrame > frame then
					scheduleAt(projectileID, checkFrame)
					break
				end
			until false
		end
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:GameFrame(frame)
	gameFrame = frame

	local checkList = scheduled[frame]
	if checkList then
		scheduled[frame] = nil
		updatePhases(checkList, frame)
	end

	for projectileID, projectile in pairs(moveControl) do
		verticalize(projectileID, projectile)
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if weapons[weaponDefID] then
		register(projectileID, weaponDefID)
	end
end

function gadget:ProjectileDestroyed(projectileID, ownerID, weaponDefID)
	projectiles[projectileID] = nil
	moveControl[projectileID] = nil
end

function gadget:Initialize()
	for weaponDefID = 0, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponDefID]
		if weaponDef.customParams.cruise_and_verticalize then
			local weapon = getVerticalizeWeapon(weaponDef)
			if weapon then
				weapons[weaponDefID] = weapon
				Script.SetWatchProjectile(weaponDefID, true)
			end
		end
	end

	if not next(weapons) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No weapons found.")
		gadgetHandler:RemoveGadget()
		return
	end
end
