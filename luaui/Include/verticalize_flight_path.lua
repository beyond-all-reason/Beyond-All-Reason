--- verticalize_flight_path.lua
---
--- Traces the flight path of a cruise_and_verticalize weapon's projectile.
---
--- Replays the full engine turn and gadget turn only when the aim changes.
--- Must update with luarules/gadgets/unit_custom_weapons_verticalize.lua.
---
--- You ever worry you're just telling players how to cheat? I sure don't.

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local CHASE_FACTOR_DEFAULT = 0.2
local CRUISE_HEIGHT_MIN = 50
local CRUISE_HEIGHT_MAX = 3000

-- Engine stage 2 turns this far short of the aim direction and then snaps to it.
local SNAP_DOT = 0.99
local ARC_EPSILON = 1e-6
local ARC_NORMAL_EPSILON = 1 - 1e-6
local FRAMES_LIMIT = 30 * 120
local RECORD_EVERY = 2

--------------------------------------------------------------------------------
-- Internals -------------------------------------------------------------------

local math_max = math.max
local math_min = math.min
local math_clamp = math.clamp
local math_floor = math.floor
local math_ceil = math.ceil
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_acos = math.acos
local math_pi = math.pi
local half_pi = math_pi * 0.5

local function append(pathX, pathY, pathZ, count, x, y, z)
	count = count + 1
	pathX[count], pathY[count], pathZ[count] = x, y, z
	return count
end

-- Fully copied
local function getUptime(plan, height)
	local speedMin = plan.speedMin
	local speedMax = plan.speedMax
	local acceleration = plan.acceleration

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

-- Engine motion: climb, then turn toward level, then fly at level
local function getClimb(plan, frames)
	local speedMin, speedMax, acceleration = plan.speedMin, plan.speedMax, plan.acceleration
	if frames <= 0 then
		return 0.0, speedMin
	end
	if acceleration <= 0 then
		return frames * speedMin, speedMin
	end

	local cappedFrame = math_ceil((speedMax - speedMin) / acceleration)
	if frames < cappedFrame then
		return frames * speedMin + acceleration * frames * (frames + 1) * 0.5, speedMin + acceleration * frames
	end

	local rising = cappedFrame - 1
	return rising * speedMin + acceleration * rising * cappedFrame * 0.5 + (frames - rising) * speedMax, speedMax
end

-- Gadget motion: the projectiles starts to dive at a radius set by its current speed.
local function getDiveRadius(plan, speed)
	local gain = plan.diveSpeedGain
	local diveSpeed = math_min(0.5 * (gain + math_sqrt(gain * gain + 4 * speed * speed)), plan.speedMax)
	return (1.0 + plan.chaseFactor) * diveSpeed / plan.turnRate
end

--------------------------------------------------------------------------------
-- Exported functions ----------------------------------------------------------

---@param weaponDef table
---@return table? plan Nil for a weapon the gadget does not steer.
local function getFlightPlan(weaponDef)
	if weaponDef.type ~= "StarburstLauncher" or weaponDef.interceptor ~= 0 then
		return
	end
	if not weaponDef.customParams.cruise_and_verticalize or weaponDef.turnRate <= 0 then
		return
	end

	local acceleration = weaponDef.weaponAcceleration or 0.0
	local speedMin = weaponDef.startvelocity
	local speedMax = weaponDef.projectilespeed
	local turnRate = weaponDef.turnRate
	local upTimeMinFrames = weaponDef.uptime * Game.gameSpeed
	local upTimeMaxFrames = (tonumber(weaponDef.customParams.uptime_max) or weaponDef.uptime) * Game.gameSpeed

	local accelerationFrames = 0.0
	if acceleration ~= 0 then
		accelerationFrames = math_min((speedMax - speedMin) / acceleration, upTimeMinFrames)
	end

	local turnSpeedMin = speedMin + accelerationFrames * acceleration
	local heightIntoTurn = turnSpeedMin * upTimeMinFrames - accelerationFrames * (turnSpeedMin - speedMin) * 0.5
	local turnSpeedTop = math_min(turnSpeedMin + acceleration * half_pi / turnRate, speedMax)
	local ascentRadius = (turnSpeedMin + (turnSpeedTop - turnSpeedMin) * (1.0 - 2.0 / math_pi)) / turnRate

	local chaseFactor = tonumber(weaponDef.customParams.cruise_chase_factor) or CHASE_FACTOR_DEFAULT
	local cruiseHeight = tonumber(weaponDef.customParams.cruise_altitude) or (heightIntoTurn + ascentRadius)

	return {
		acceleration = acceleration,
		speedMin = speedMin,
		speedMax = speedMax,
		turnRate = turnRate,
		chaseFactor = chaseFactor,
		diveSpeedGain = math_pi * acceleration * (1.0 + chaseFactor) / turnRate,
		upTimeMinFrames = upTimeMinFrames,
		upTimeMaxFrames = upTimeMaxFrames,
		heightIntoTurn = heightIntoTurn,
		cruiseHeight = math_clamp(cruiseHeight, CRUISE_HEIGHT_MIN, CRUISE_HEIGHT_MAX),
		ascentRadius = ascentRadius,
	}
end

---Fills the arrays with the path the missile flies, from launch to where it meets the target's
---height, which for a well-tuned weapon is the target itself.
---@param plan table
---@param pathX number[]
---@param pathY number[]
---@param pathZ number[]
---@return integer? count Nil when the gadget leaves the missile to the engine's own starburst flight.
---@return number? length
---@return number? frames
local function getFlightPath(plan, lx, ly, lz, tx, ty, tz, pathX, pathY, pathZ)
	local dx, dz = tx - lx, tz - lz
	if dx * dx + dz * dz <= 0 then
		return
	end
	local distance = math_sqrt(dx * dx + dz * dz)

	local ascentRadius = plan.ascentRadius
	local ascendHeight = math_max(ly + plan.heightIntoTurn, ty + plan.cruiseHeight - ascentRadius)

	local upTimeFrames = math_clamp(getUptime(plan, ascendHeight - ly), plan.upTimeMinFrames, plan.upTimeMaxFrames)
	if upTimeFrames < plan.upTimeMinFrames + 0.5 then
		if distance <= ascentRadius * 0.5 then
			return
		end
		upTimeFrames = plan.upTimeMinFrames
	end

	-- The engine truncates the uptime to a whole frame and counts it down before it climbs.
	local frames = math_floor(upTimeFrames) - 1
	local climbHeight, speed = getClimb(plan, frames)

	local count = append(pathX, pathY, pathZ, 0, lx, ly, lz)
	local px, py, pz = lx, ly + climbHeight, lz
	count = append(pathX, pathY, pathZ, count, px, py, pz)

	local turnRate, acceleration, speedMax = plan.turnRate, plan.acceleration, plan.speedMax
	local aimX, aimY, aimZ = tx, ascendHeight + ascentRadius, tz
	local dirX, dirY, dirZ = 0.0, 1.0, 0.0

	-- turn toward the aim point at a constant speed
	while frames < FRAMES_LIMIT do
		frames = frames + 1
		local ax, ay, az = aimX - px, aimY - py, aimZ - pz
		local aimLength = math_sqrt(ax * ax + ay * ay + az * az)
		ax, ay, az = ax / aimLength, ay / aimLength, az / aimLength

		local snapped = ax * dirX + ay * dirY + az * dirZ > SNAP_DOT
		if snapped then
			dirX, dirY, dirZ = ax, ay, az
		else
			local ex, ey, ez = ax - dirX, ay - dirY, az - dirZ
			local along = ex * dirX + ey * dirY + ez * dirZ
			ex, ey, ez = ex - dirX * along, ey - dirY * along, ez - dirZ * along
			local sideLength = math_sqrt(ex * ex + ey * ey + ez * ez)
			if sideLength > 0 then
				ex, ey, ez = ex / sideLength, ey / sideLength, ez / sideLength
			end
			dirX, dirY, dirZ = dirX + ex * turnRate, dirY + ey * turnRate, dirZ + ez * turnRate
			local dirLength = math_sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
			dirX, dirY, dirZ = dirX / dirLength, dirY / dirLength, dirZ / dirLength
		end

		px, py, pz = px + dirX * speed, py + dirY * speed, pz + dirZ * speed
		if snapped then
			count = append(pathX, pathY, pathZ, count, px, py, pz)
			break
		elseif frames % RECORD_EVERY == 0 then
			count = append(pathX, pathY, pathZ, count, px, py, pz)
		end
	end

	-- fly straight on and speed up, until the gadget finds it inside a radius
	local cruiseEndInverse
	while frames < FRAMES_LIMIT do
		frames = frames + 1
		speed = math_min(speed + acceleration, speedMax)
		px, py, pz = px + dirX * speed, py + dirY * speed, pz + dirZ * speed

		local cruiseEndRadius = getDiveRadius(plan, speed)
		local rx, rz = px - tx, pz - tz
		if cruiseEndRadius * cruiseEndRadius >= rx * rx + rz * rz then
			cruiseEndInverse = 1 / cruiseEndRadius
			count = append(pathX, pathY, pathZ, count, px, py, pz)
			break
		elseif frames % RECORD_EVERY == 0 then
			count = append(pathX, pathY, pathZ, count, px, py, pz)
		end
	end

	-- The gadget's verticalize stage, copied in full
	local vx, vy, vz = dirX * speed, dirY * speed, dirZ * speed
	while cruiseEndInverse and frames < FRAMES_LIMIT do
		local ddx, ddz = tx - px, tz - pz
		local reach = math_sqrt(ddx * ddx + ddz * ddz)

		local sinPitch = 1 - reach * cruiseEndInverse
		if sinPitch < 0 then
			sinPitch = 0
		end
		local cosPitch = math_sqrt(1 - sinPitch * sinPitch)

		local ux, uy, uz = 0.0, -sinPitch, 0.0
		if reach > 0 then
			local reachInverse = cosPitch / reach
			ux, uz = ddx * reachInverse, ddz * reachInverse
		end

		local cosAngle = (vx * ux + vy * uy + vz * uz) / speed
		if cosAngle > 1 then
			cosAngle = 1
		elseif cosAngle < -1 then
			cosAngle = -1
		end

		local sinAngle = math_sqrt(1 - cosAngle * cosAngle)
		if sinAngle > ARC_EPSILON then
			local angle = math_acos(cosAngle)
			local factor = turnRate / angle
			if factor < ARC_NORMAL_EPSILON then
				local weight1 = math_sin((1 - factor) * angle) / speed
				local weight2 = math_sin(factor * angle)
				local scale = speed / sinAngle
				vx = (vx * weight1 + ux * weight2) * scale
				vy = (vy * weight1 + uy * weight2) * scale
				vz = (vz * weight1 + uz * weight2) * scale
			else
				vx, vy, vz = ux * speed, uy * speed, uz * speed
			end
		end

		local ratio = math_min(speed + acceleration, speedMax) / speed
		vx, vy, vz = vx * ratio, vy * ratio, vz * ratio
		speed = speed * ratio

		local nx, ny, nz = px + vx, py + vy, pz + vz
		frames = frames + 1
		if ny <= ty then
			local k = (py - ty) / (py - ny)
			count = append(pathX, pathY, pathZ, count, px + vx * k, ty, pz + vz * k)
			break
		end
		px, py, pz = nx, ny, nz
		if frames % RECORD_EVERY == 0 then
			count = append(pathX, pathY, pathZ, count, px, py, pz)
		end
	end

	local length = 0
	for i = 2, count do
		local sx, sy, sz = pathX[i] - pathX[i - 1], pathY[i] - pathY[i - 1], pathZ[i] - pathZ[i - 1]
		length = length + math_sqrt(sx * sx + sy * sy + sz * sz)
	end

	return count, length, frames
end

--------------------------------------------------------------------------------
-- Export ----------------------------------------------------------------------

return {
	GetFlightPlan = getFlightPlan,
	GetFlightPath = getFlightPath,
}
