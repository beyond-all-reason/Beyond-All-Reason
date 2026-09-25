-- modules/verticalize.lua
--
-- The cruise-and-verticalize flight program for StarburstLauncher weapons.

-- Requires a StarburstLauncher weapondef with the customparam values:
-- cruise_and_verticalize  := true
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

local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_diag = math.diag
local math_pi = math.pi
local math_asin = math.asin
local distance2D = math.distance2d
local distance2DSquared = math.distance2dSquared
local quadraticRoots = math.quadraticRoots

local slerp = VFS.Include("common/vectors.lua").slerp

local cruiseHeightMin = 50 -- note: barely above ground
local cruiseHeightMax = 3000 -- note: not all that high up
local checkWindowFrames = 6 -- count of polling frames used to predict new phases
local chaseFactorDefault = 0.2 -- [0, 2] where 0 is a clean quarter-turn onto target

---@class VerticalizeWeapon
---@field acceleration number
---@field speedMax number
---@field speedMin number
---@field turnRate number
---@field heightIntoTurn number
---@field rangeMaximum number
---@field upTimeMaxFrames number
---@field upTimeMinFrames number
---@field cruiseHeight number
---@field ascentRadius number
---@field diveRadiusMax number
---@field chaseFactor number
---@field diveSpeedGain number
---@field tracking number
---@field gravity number?
---@field cegTag string

---@class VerticalizeProjectile
---@field acceleration number
---@field speedMax number
---@field speedMin number
---@field turnRate number
---@field chaseFactor number
---@field diveSpeedGain number
---@field target xyz
---@field ascendHeight number
---@field diveRadiusMax number
---@field phase integer
---@field pitch number
---@field cruiseEndInverse number
---@field px number?
---@field py number?
---@field pz number?
---@field vx number?
---@field vy number?
---@field vz number?
---@field speed number?

---@return VerticalizeWeapon?
local function getVerticalizeWeapon(weaponDef)
	if not weaponDef.customParams.cruise_and_verticalize then
		return
	end
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

local function getUptime(projectile, height)
	local speedMin = projectile.speedMin
	local speedMax = projectile.speedMax
	local acceleration = projectile.acceleration

	if acceleration == 0.0 or speedMin == speedMax then
		return height / speedMax
	end

	if height < speedMin then
		return 0.0
	end

	local accelTime = (speedMax - speedMin) / acceleration
	local accelDistance = speedMin * accelTime + 0.5 * acceleration * accelTime * accelTime

	if accelDistance <= height then
		local flatTime = (height - accelDistance) / speedMax
		local speedAvg = (flatTime * speedMax + accelTime * (speedMax + speedMin) * 0.5) / (flatTime + accelTime)
		return height / speedAvg
	end

	local t1, t2 = quadraticRoots(0.5 * acceleration, speedMin, -height)

	if not t1 then
		return 0.0
	end

	return (t1 >= 0 and t2 >= 0) and math_min(t1, t2) or (t1 >= 0 and t1 or t2)
end

---@param weapon VerticalizeWeapon
---@param position xyz
---@param target xyz
---@return number
local function getAscendHeight(weapon, position, target)
	local ascentRadius = weapon.ascentRadius
	local ascentAboveLauncher = position[2] + weapon.heightIntoTurn
	local ascentAboveTarget = target[2] + weapon.cruiseHeight - ascentRadius
	return math_max(ascentAboveLauncher, ascentAboveTarget)
end

---@param weapon VerticalizeWeapon
---@param target xyz
---@param ascendHeight number
---@return VerticalizeProjectile
local function newProjectile(weapon, target, ascendHeight)
	return {
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
		pitch = 2.0,
		cruiseEndInverse = 0.0,
	}
end

---@param weapon VerticalizeWeapon
---@param projectile VerticalizeProjectile
---@param position xyz
---@return number
local function getUpTimeFrames(weapon, projectile, position)
	local upTime = getUptime(projectile, projectile.ascendHeight - position[2])
	return math_clamp(upTime, weapon.upTimeMinFrames, weapon.upTimeMaxFrames)
end

---@param weapon VerticalizeWeapon
---@param upTimeFrames number
---@return boolean
local function shouldRespawn(weapon, upTimeFrames)
	return upTimeFrames >= weapon.upTimeMinFrames + 0.5
end

---@param upTimeFrames number
---@param frame integer
---@return integer
local function getFirstCheckFrame(upTimeFrames, frame)
	return math_max(frame + math_floor(upTimeFrames) - checkWindowFrames, frame + 1)
end

---@param weapon VerticalizeWeapon
---@param position xyz
---@param target xyz
---@return boolean
local function isTargetInsideAscentTurn(weapon, position, target)
	local targetDistance = distance2D(position[1], position[3], target[1], target[3])
	return targetDistance <= weapon.ascentRadius * 0.5
end

---@param weapon VerticalizeWeapon
---@param projectile VerticalizeProjectile
---@return number
local function getAimHeight(weapon, projectile)
	return projectile.ascendHeight + weapon.ascentRadius
end

---@param projectile VerticalizeProjectile
---@param position xyz
---@param velocity xyzw
---@param frame integer
---@return integer
local function ascend(projectile, position, velocity, frame)
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
	local target = projectile.target
	local targetDistance = distance2D(position[1], position[3], target[1], target[3])
	local dropRadiusFrames = (targetDistance - projectile.diveRadiusMax) / speedMax

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
---@param projectile VerticalizeProjectile
---@param speed number
---@return number
local function getDiveSpeed(projectile, speed)
	local gain = projectile.diveSpeedGain
	local diveSpeed = 0.5 * (gain + math_sqrt(gain * gain + 4 * speed * speed))
	return math_min(diveSpeed, projectile.speedMax)
end

---@param projectile VerticalizeProjectile
---@param position xyz
---@param velocity xyzw
---@param frame integer
---@return integer
local function turnToLevel(projectile, position, velocity, frame)
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
	local target = projectile.target
	local cruiseDistance = distance2D(position[1], position[3], target[1], target[3]) - cruiseEndRadius
	return frame + math_floor(cruiseDistance / projectile.speedMax) - checkWindowFrames
end

---@param projectile VerticalizeProjectile
---@param position xyz
---@param velocity xyzw
---@param frame integer
---@return integer?
local function cruise(projectile, position, velocity, frame)
	if velocity[4] <= 0 then
		return frame + 1 -- guidance will div0
	end

	-- Most vertical-launch missiles accelerate slowly so are still gaining speed here.
	local target = projectile.target
	local cruiseEndRadius = (1 + projectile.chaseFactor) * getDiveSpeed(projectile, velocity[4]) / projectile.turnRate
	local targetDistanceSquared = distance2DSquared(position[1], position[3], target[1], target[3])
	if targetDistanceSquared > cruiseEndRadius * cruiseEndRadius then
		return frame + 1
	end

	projectile.cruiseEndInverse = 1 / cruiseEndRadius
	projectile.px, projectile.py, projectile.pz = position[1], position[2], position[3]
	projectile.vx, projectile.vy, projectile.vz = velocity[1], velocity[2], velocity[3]
	projectile.speed = velocity[4]
end

---@param projectile VerticalizeProjectile
local function verticalize(projectile)
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
	local tx, ty, tz = 0.0, -sinPitch, 0.0
	if distance > 0 then
		local distInverse = cosPitch / distance
		tx = dx * distInverse
		tz = dz * distInverse
	end

	vx, vy, vz = slerp(vx, vy, vz, speed, tx, ty, tz, projectile.turnRate)

	local speedNew = math_min(speed + projectile.acceleration, projectile.speedMax)
	local ratio = speedNew / speed
	vx, vy, vz = vx * ratio, vy * ratio, vz * ratio
	px, py, pz = px + vx, py + vy, pz + vz

	projectile.px, projectile.py, projectile.pz = px, py, pz
	projectile.vx, projectile.vy, projectile.vz = vx, vy, vz
	projectile.speed = speed * ratio
end

local enginePhases = { ascend, turnToLevel, cruise } -- end into => verticalize

---@param projectile VerticalizeProjectile
---@param position xyz
---@param velocity xyzw
---@param frame integer
---@return integer?
local function updateFlightPhase(projectile, position, velocity, frame)
	return enginePhases[projectile.phase](projectile, position, velocity, frame)
end

return {
	checkWindowFrames = checkWindowFrames,
	getVerticalizeWeapon = getVerticalizeWeapon,
	getUptime = getUptime,
	getAscendHeight = getAscendHeight,
	newProjectile = newProjectile,
	getUpTimeFrames = getUpTimeFrames,
	shouldRespawn = shouldRespawn,
	getFirstCheckFrame = getFirstCheckFrame,
	isTargetInsideAscentTurn = isTargetInsideAscentTurn,
	getAimHeight = getAimHeight,
	updateFlightPhase = updateFlightPhase,
	verticalize = verticalize,
}
