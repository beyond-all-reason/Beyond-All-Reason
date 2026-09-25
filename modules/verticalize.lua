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

local math_min = math.min
local math_clamp = math.clamp
local math_pi = math.pi
local quadraticRoots = math.quadraticRoots

local cruiseHeightMin = 50 -- note: barely above ground
local cruiseHeightMax = 3000 -- note: not all that high up
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

return {
	getVerticalizeWeapon = getVerticalizeWeapon,
	getUptime = getUptime,
}
