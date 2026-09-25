-- modules/starburst.lua
--
-- The engine's StarburstProjectile trajectory, for prediction and drawing.

local math_min = math.min
local math_sqrt = math.sqrt
local math_cos = math.cos

local turnRateDefault = 0.06
local turnToTargetDot = 0.99

---@class StarburstWeapon
---@field acceleration number
---@field speedMax number
---@field turnRate number
---@field tracking number
---@field maxGoodDif number

---@class Starburst
---@field dirX number
---@field dirY number
---@field dirZ number
---@field speed number
---@field ascentFrames integer
---@field turnToTarget boolean

---@return StarburstWeapon?
local function getStarburstWeapon(weaponDef)
	if weaponDef.type ~= "StarburstLauncher" then
		return
	end

	local turnRate = weaponDef.turnRate
	if turnRate == 0 then
		turnRate = turnRateDefault
	end
	local tracking = weaponDef.tracks and (weaponDef.turnRate or 0) or 0

	return {
		acceleration = weaponDef.weaponAcceleration,
		speedMax = weaponDef.projectilespeed,
		turnRate = turnRate,
		tracking = tracking,
		maxGoodDif = math_cos(tracking * 0.6),
	}
end

---@param dirX number
---@param dirY number
---@param dirZ number
---@param speed number
---@param ascentFrames integer
---@param turnToTarget boolean
---@return Starburst
local function newStarburst(dirX, dirY, dirZ, speed, ascentFrames, turnToTarget)
	return {
		dirX = dirX,
		dirY = dirY,
		dirZ = dirZ,
		speed = speed,
		ascentFrames = ascentFrames,
		turnToTarget = turnToTarget,
	}
end

---@param starburst Starburst
---@param weapon StarburstWeapon
---@param targetDirX number
---@param targetDirY number
---@param targetDirZ number `targetDir` is the unit vector from the projectile to its target
local function stepStarburst(starburst, weapon, targetDirX, targetDirY, targetDirZ)
	local speed = starburst.speed

	if starburst.ascentFrames > 0 then
		starburst.speed = math_min(speed + weapon.acceleration, weapon.speedMax)
		starburst.ascentFrames = starburst.ascentFrames - 1
		return
	end

	local dirX, dirY, dirZ = starburst.dirX, starburst.dirY, starburst.dirZ
	local directionDotTarget = dirX * targetDirX + dirY * targetDirY + dirZ * targetDirZ
	local steerRate
	if starburst.turnToTarget then
		if directionDotTarget > turnToTargetDot then
			dirX, dirY, dirZ = targetDirX, targetDirY, targetDirZ
			starburst.turnToTarget = false
		else
			steerRate = weapon.turnRate
		end
	else
		speed = math_min(speed + weapon.acceleration, weapon.speedMax)
		if directionDotTarget > weapon.maxGoodDif then
			dirX, dirY, dirZ = targetDirX, targetDirY, targetDirZ
		elseif weapon.tracking > 0 then
			steerRate = weapon.tracking
		end
	end

	if steerRate then
		local turnX = targetDirX - dirX * directionDotTarget
		local turnY = targetDirY - dirY * directionDotTarget
		local turnZ = targetDirZ - dirZ * directionDotTarget
		local turnLength = math_sqrt(turnX * turnX + turnY * turnY + turnZ * turnZ)
		if turnLength > 0 then
			turnX, turnY, turnZ = turnX / turnLength, turnY / turnLength, turnZ / turnLength
			dirX = dirX + turnX * steerRate
			dirY = dirY + turnY * steerRate
			dirZ = dirZ + turnZ * steerRate
			local directionLength = math_sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
			dirX, dirY, dirZ = dirX / directionLength, dirY / directionLength, dirZ / directionLength
		end
	end

	starburst.dirX, starburst.dirY, starburst.dirZ = dirX, dirY, dirZ
	starburst.speed = speed
end

return {
	getStarburstWeapon = getStarburstWeapon,
	newStarburst = newStarburst,
	stepStarburst = stepStarburst,
}
