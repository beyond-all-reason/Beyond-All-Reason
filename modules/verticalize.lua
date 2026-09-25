-- modules/verticalize.lua
--
-- The cruise-and-verticalize flight program for StarburstLauncher weapons.

-- Requires a StarburstLauncher weapondef with the customparam values:
-- cruise_and_verticalize  := true
-- cruise_altitude         := number?  height above ground at level, else "auto"
-- uptime_max              := number?  in seconds, overrides the weaponDef
-- cruise_chase_factor     := number?  [0, 2] 0:=hard turn 1:=constant 2:=chases
--                                     else 0.2, not a flag, value is fractional

local cruiseHeightMin = 50 -- note: barely above ground
local cruiseHeightMax = 3000 -- note: not all that high up
local checkWindowFrames = 6 -- count of polling frames used to predict new phases
local chaseFactorDefault = 0.2 -- [0, 2] where 0 is a clean quarter-turn onto target

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

local spGetGroundHeight = Spring.GetGroundHeight
local spTraceRayGroundBetweenPositions = Spring.TraceRayGroundBetweenPositions

local Vectors = VFS.Include("common/vectors.lua")
local dirUp = Vectors.dirUp
local slerp = Vectors.slerp

local Starburst = VFS.Include("modules/starburst.lua")
local newStarburst = Starburst.newStarburst
local stepStarburst = Starburst.stepStarburst

local simulationFramesMax = 3000
local pathFrameInterval = 4
local turnToTargetDot = 0.99

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
---@field waterWeapon boolean

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
---@field px number
---@field py number
---@field pz number
---@field vx number
---@field vy number
---@field vz number
---@field speed number

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
		waterWeapon = weaponDef.waterWeapon and true or false,
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

local phasePosition = { 0.0, 0.0, 0.0 }
local phaseVelocity = { 0.0, 0.0, 0.0, 0.0 }

---@param weapon VerticalizeWeapon
---@param starburstWeapon StarburstWeapon
---@param projectile VerticalizeProjectile
---@param starburst Starburst
---@param position xyz
---@param aim xyz
---@param checkFrame integer? nil when the gadget does not check this projectile's flight phases
---@param isMoveControl boolean
---@param path number[][]? the x, y and z arrays of the draw path
---@return number impactX
---@return number impactY
---@return number impactZ
---@return integer pathCount
local function simulateToImpact(
	weapon,
	starburstWeapon,
	projectile,
	starburst,
	position,
	aim,
	checkFrame,
	isMoveControl,
	path
)
	local x, y, z = position[1], position[2], position[3]
	local aimX, aimY, aimZ = aim[1], aim[2], aim[3]
	local dirX, dirY, dirZ = starburst.dirX, starburst.dirY, starburst.dirZ
	local speed, ascentFrames, turnToTarget = starburst.speed, starburst.ascentFrames, starburst.turnToTarget

	local pathX, pathY, pathZ
	local pathCount = 0
	if path then
		pathX, pathY, pathZ = path[1], path[2], path[3]
		pathCount = 1
		pathX[1], pathY[1], pathZ[1] = x, y, z
	end

	for frame = 0, simulationFramesMax do
		if checkFrame and frame >= checkFrame then
			local nextFrame
			repeat
				phasePosition[1], phasePosition[2], phasePosition[3] = x, y, z
				phaseVelocity[1] = dirX * speed
				phaseVelocity[2] = dirY * speed
				phaseVelocity[3] = dirZ * speed
				phaseVelocity[4] = speed
				nextFrame = updateFlightPhase(projectile, phasePosition, phaseVelocity, frame)
			until not nextFrame or nextFrame > frame
			checkFrame = nextFrame
			isMoveControl = not nextFrame
		end

		local x0, y0, z0 = x, y, z
		if isMoveControl then
			verticalize(projectile)
			x, y, z = projectile.px, projectile.py, projectile.pz
		else
			local dx, dy, dz = aimX - x, aimY - y, aimZ - z
			local length = math_sqrt(dx * dx + dy * dy + dz * dz)
			if length > 0 then
				dirX, dirY, dirZ, speed, ascentFrames, turnToTarget = stepStarburst(
					starburstWeapon,
					dirX,
					dirY,
					dirZ,
					speed,
					ascentFrames,
					turnToTarget,
					dx / length,
					dy / length,
					dz / length
				)
			end
			x, y, z = x + dirX * speed, y + dirY * speed, z + dirZ * speed
		end

		local groundY = spGetGroundHeight(x, z)
		local hitX, hitY, hitZ
		if y < groundY then
			local _
			_, hitX, hitY, hitZ = spTraceRayGroundBetweenPositions(x0, y0, z0, x, y, z, false)
			if not hitX then
				hitX, hitY, hitZ = x, groundY, z
			end
		elseif y <= 0.0 and not weapon.waterWeapon then
			local fraction = y0 > 0.0 and y0 / (y0 - y) or 0.0
			hitX, hitY, hitZ = x0 + (x - x0) * fraction, 0.0, z0 + (z - z0) * fraction
		end

		if hitX then
			if path then
				pathCount = pathCount + 1
				pathX[pathCount], pathY[pathCount], pathZ[pathCount] = hitX, hitY, hitZ
			end
			return hitX, hitY, hitZ, pathCount
		end

		if path and (frame + 1) % pathFrameInterval == 0 then
			pathCount = pathCount + 1
			pathX[pathCount], pathY[pathCount], pathZ[pathCount] = x, y, z
		end
	end

	return x, y, z, pathCount
end

---@param weapon VerticalizeWeapon
---@param starburstWeapon StarburstWeapon
---@param position xyz where the launcher spawns the projectile
---@param direction xyz the launch direction
---@param target xyz
---@param path number[][]? the x, y and z arrays of the draw path
---@return number impactX
---@return number impactY
---@return number impactZ
---@return integer pathCount
local function getLaunchTrajectory(weapon, starburstWeapon, position, direction, target, path)
	local projectile = newProjectile(weapon, target, getAscendHeight(weapon, position, target))
	local upTimeFrames = getUpTimeFrames(weapon, projectile, position)

	local upTime = math_floor(weapon.upTimeMinFrames)
	local checkFrame
	if shouldRespawn(weapon, upTimeFrames) then
		upTime = math_floor(upTimeFrames)
		checkFrame = getFirstCheckFrame(upTimeFrames, 0)
	elseif not isTargetInsideAscentTurn(weapon, position, target) then
		checkFrame = getFirstCheckFrame(upTimeFrames, 0)
	end

	local aim = target
	if checkFrame then
		aim = { target[1], getAimHeight(weapon, projectile), target[3] }
	end

	local ascentFrames = math_max(upTime - 1, 0) -- decremented before the first update in-engine
	local starburst = newStarburst(direction[1], direction[2], direction[3], weapon.speedMin, ascentFrames, true)

	return simulateToImpact(weapon, starburstWeapon, projectile, starburst, position, aim, checkFrame, false, path)
end

---@param weapon VerticalizeWeapon
---@param starburstWeapon StarburstWeapon
---@param position xyz
---@param velocity xyzw
---@param elapsedFrames integer the frames since the projectile was fired
---@param aim xyz the projectile's current target
---@param target xyz the target on the ground
---@return number impactX
---@return number impactY
---@return number impactZ
---@return boolean isFromLaunch
local function getInFlightImpact(weapon, starburstWeapon, position, velocity, elapsedFrames, aim, target)
	local vx, vy, vz, speed = velocity[1], velocity[2], velocity[3], velocity[4]
	local impactX, impactY, impactZ

	-- Exact launch point is knowable while the projectile is still perfectly vertical:
	if vx == 0 and vz == 0 and vy > 0 then
		local climb, climbSpeed = 0, weapon.speedMin
		for _ = 1, elapsedFrames do
			climbSpeed = math_min(climbSpeed + weapon.acceleration, weapon.speedMax)
			climb = climb + climbSpeed
		end
		local launch = { position[1], position[2] - climb, position[3] }
		impactX, impactY, impactZ = getLaunchTrajectory(weapon, starburstWeapon, launch, dirUp, target)
		return impactX, impactY, impactZ, true
	end

	local dirX, dirY, dirZ = vx / speed, vy / speed, vz / speed
	local targetDX, targetDY, targetDZ = aim[1] - position[1], aim[2] - position[2], aim[3] - position[3]
	local targetLength = math_sqrt(targetDX * targetDX + targetDY * targetDY + targetDZ * targetDZ)
	local turnToTarget = true
	if targetLength > 0 then
		turnToTarget = (dirX * targetDX + dirY * targetDY + dirZ * targetDZ) / targetLength <= turnToTargetDot
	end
	local starburst = newStarburst(dirX, dirY, dirZ, speed, 0, turnToTarget)

	if aim[2] > target[2] + 1 then
		local projectile = newProjectile(weapon, target, aim[2] - weapon.ascentRadius)
		impactX, impactY, impactZ =
			simulateToImpact(weapon, starburstWeapon, projectile, starburst, position, aim, 0, false)
		return impactX, impactY, impactZ, false
	end

	local projectile = newProjectile(weapon, target, aim[2])
	local cruiseEndRadius = (1 + weapon.chaseFactor) * getDiveSpeed(projectile, speed) / weapon.turnRate
	local targetDistance = distance2D(position[1], position[3], target[1], target[3])

	if vy < 0 and targetDistance <= cruiseEndRadius then
		projectile.cruiseEndInverse = 1 / cruiseEndRadius
		projectile.px, projectile.py, projectile.pz = position[1], position[2], position[3]
		projectile.vx, projectile.vy, projectile.vz = vx, vy, vz
		projectile.speed = speed
		impactX, impactY, impactZ =
			simulateToImpact(weapon, starburstWeapon, projectile, starburst, position, aim, nil, true)
	else
		impactX, impactY, impactZ =
			simulateToImpact(weapon, starburstWeapon, projectile, starburst, position, aim, nil, false)
	end

	return impactX, impactY, impactZ, false
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
	getLaunchTrajectory = getLaunchTrajectory,
	getInFlightImpact = getInFlightImpact,
}
