---------------------------------------------------------------------------------------------------
-- common/weapons.lua -----------------------------------------------------------------------------

local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local gameSpeed = Game.gameSpeed
local gameSpeedInv = 1 / gameSpeed

local FRAME_EPS = 1e-3

local function getBurstFrames(weaponDef)
	if weaponDef.type == "BeamLaser" and not weaponDef.beamburst then
		-- Damage is spread across all beam frames (which may be just one frame).
		local beamFrames = math_max(1, math_floor(weaponDef.beamtime * gameSpeed))

		local fireTime = tonumber(weaponDef.customParams.sweepfire_firetime)
		if fireTime then
			-- Sweepfire unit scripts fire the beam for `sweepfire_firetime` out of `sweepfire_reloadtime`.
			local fireFrames = math_max(1, math_floor(fireTime * gameSpeed + 0.5))
			local cycleTime = tonumber(weaponDef.customParams.sweepfire_reloadtime) or 0
			return weaponDef.projectiles * fireFrames / beamFrames, fireFrames, math_floor(cycleTime * gameSpeed + 0.5)
		end

		return weaponDef.projectiles, beamFrames, beamFrames
	end

	local salvoFrames = math_max(1, math_floor(weaponDef.salvoDelay * gameSpeed))
	return weaponDef.salvoSize * weaponDef.projectiles,
		(weaponDef.salvoSize - 1) * salvoFrames + 1,
		weaponDef.salvoSize * salvoFrames
end

local function getIntensityMin(weaponDef)
	return weaponDef.type == "BeamLaser" and math_max(weaponDef.minIntensity, 0.5) or 1.0
end

---------------------------------------------------------------------------------------------------
-- Module functions -------------------------------------------------------------------------------

---@param weaponDef WeaponDef
---@param reload number?
---@return number shots
---@return number period
---@return number intensityMin
local function getFiringCycle(weaponDef, reload)
	local reloadFrames
	if reload then
		reloadFrames = math_max(1, math_floor(reload * gameSpeed + FRAME_EPS))
	else
		reloadFrames = math_max(1, math_floor(weaponDef.reload * gameSpeed))
	end
	local shots, _, cycleFrames = getBurstFrames(weaponDef)
	return shots, math_max(reloadFrames, cycleFrames) * gameSpeedInv, getIntensityMin(weaponDef)
end

---@param weaponDef WeaponDef
---@param damage number
---@param reload number?
---@return number minDamagePerSecond At maximum range.
---@return number maxDamagePerSecond At point blank.
local function getDamagePerSecond(weaponDef, damage, reload)
	local shots, period, intensityMin = getFiringCycle(weaponDef, reload)
	local maxDamagePerSecond = damage * shots / period
	return maxDamagePerSecond * intensityMin, maxDamagePerSecond
end

---Counts at most the first second of a longer burst.
---@param weaponDef WeaponDef
---@param damage number
---@return number minDamagePerBurst At maximum range.
---@return number maxDamagePerBurst At point blank.
local function getDamagePerBurst(weaponDef, damage)
	local shots, burstFrames = getBurstFrames(weaponDef)
	local maxDamagePerBurst = damage * shots * math_min(1, gameSpeed / burstFrames)
	return maxDamagePerBurst * getIntensityMin(weaponDef), maxDamagePerBurst
end

return {
	GetFiringCycle = getFiringCycle,
	GetDamagePerSecond = getDamagePerSecond,
	GetDamagePerBurst = getDamagePerBurst,
}
