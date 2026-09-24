--- verticalize_flight_path.lua
---
--- Traces the flight path of a cruise_and_verticalize weapon's projectile.
--- Gives a closed-form solution that can be drawn quickly and efficiently.
--- Must update with luarules/gadgets/unit_custom_weapons_verticalize.lua.
---
--- You ever worry you're just telling players how to cheat? I sure don't.

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local CHASE_FACTOR_DEFAULT = 0.2
local CRUISE_HEIGHT_MIN = 50
local CRUISE_HEIGHT_MAX = 3000

local ARC_SEGMENTS = 8

--------------------------------------------------------------------------------
-- Internals -------------------------------------------------------------------

local math_max = math.max
local math_min = math.min
local math_clamp = math.clamp
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi
local half_pi = math_pi * 0.5

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
		heightIntoTurn = heightIntoTurn,
		cruiseHeight = math_clamp(cruiseHeight, CRUISE_HEIGHT_MIN, CRUISE_HEIGHT_MAX),
		ascentRadius = ascentRadius,
		diveRadius = (1.0 + chaseFactor) * speedMax / turnRate,
	}
end

---Fills the arrays with the path from launch to target, ending exactly on the target.
---@param plan table
---@param pathX number[]
---@param pathY number[]
---@param pathZ number[]
---@return integer? count Nil when the target sits so far inside the ascent turn that the gadget
---leaves the missile to the engine's own starburst flight.
---@return number? length
local function getFlightPath(plan, lx, ly, lz, tx, ty, tz, pathX, pathY, pathZ)
	local dx, dz = tx - lx, tz - lz
	local distance = math_sqrt(dx * dx + dz * dz)
	local ascentRadius = plan.ascentRadius

	if distance <= ascentRadius * 0.5 then
		return
	end

	local dirX, dirZ = dx / distance, dz / distance
	local ascendHeight = math_max(ly + plan.heightIntoTurn, ty + plan.cruiseHeight - ascentRadius)
	local diveRadius = plan.diveRadius

	-- A short shot has no level stretch, so both turns shrink until they meet.
	local turnsWidth = ascentRadius + diveRadius
	if turnsWidth > distance then
		local scale = distance / turnsWidth
		ascentRadius = ascentRadius * scale
		diveRadius = diveRadius * scale
	end

	local cruiseY = ascendHeight + ascentRadius
	local diveReach = distance - diveRadius

	pathX[1], pathY[1], pathZ[1] = lx, ly, lz
	pathX[2], pathY[2], pathZ[2] = lx, ascendHeight, lz
	local count = 2

	for i = 1, ARC_SEGMENTS do
		local angle = i / ARC_SEGMENTS * half_pi
		local reach = ascentRadius * (1.0 - math_cos(angle))
		count = count + 1
		pathX[count] = lx + dirX * reach
		pathY[count] = ascendHeight + ascentRadius * math_sin(angle)
		pathZ[count] = lz + dirZ * reach
	end

	-- A dive wider than the height above its target meets the ground before it turns vertical.
	for i = 0, ARC_SEGMENTS do
		local angle = i / ARC_SEGMENTS * half_pi
		local reach = diveReach + diveRadius * math_sin(angle)
		count = count + 1
		pathX[count] = lx + dirX * reach
		pathY[count] = math_max(cruiseY - diveRadius * (1.0 - math_cos(angle)), ty)
		pathZ[count] = lz + dirZ * reach
	end

	count = count + 1
	pathX[count], pathY[count], pathZ[count] = tx, ty, tz

	local length = 0
	for i = 2, count do
		local sx, sy, sz = pathX[i] - pathX[i - 1], pathY[i] - pathY[i - 1], pathZ[i] - pathZ[i - 1]
		length = length + math_sqrt(sx * sx + sy * sy + sz * sz)
	end

	return count, length
end

---@param plan table
---@param length number
---@return number frames
local function getTravelFrames(plan, length)
	local speedMin, speedMax, acceleration = plan.speedMin, plan.speedMax, plan.acceleration
	if acceleration <= 0.0 or speedMin >= speedMax then
		return length / speedMax
	end

	local accelerationFrames = (speedMax - speedMin) / acceleration
	local accelerationLength = (speedMin + speedMax) * 0.5 * accelerationFrames
	if accelerationLength <= length then
		return accelerationFrames + (length - accelerationLength) / speedMax
	end

	-- Arrives before reaching top speed.
	return (math_sqrt(speedMin * speedMin + 2 * acceleration * length) - speedMin) / acceleration
end

--------------------------------------------------------------------------------
-- Export ----------------------------------------------------------------------

return {
	GetFlightPlan = getFlightPlan,
	GetFlightPath = getFlightPath,
	GetTravelFrames = getTravelFrames,
}
