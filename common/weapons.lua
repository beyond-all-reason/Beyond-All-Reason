---------------------------------------------------------------------------------------------------
-- common/weapons.lua -----------------------------------------------------------------------------

local math_floor = math.floor
local math_max = math.max

local gameSpeed = Game.gameSpeed
local gameSpeedInv = 1 / gameSpeed

local FRAME_EPS = 1e-3

local function getBeamFiringCycle(weaponDef, reload)
	if weaponDef.beamburst then
		return weaponDef.salvoSize * weaponDef.projectiles,
			math_max(reload, (weaponDef.salvoSize - 1) * weaponDef.salvoDelay)
	end

	-- Damage is spread across all beam frames (which may be just one frame).
	local beamFrames = math_max(1, math_floor(weaponDef.beamtime * gameSpeed))

	local fireTime = weaponDef.customParams.sweepfire_firetime
	if fireTime then
		-- Sweepfire unit scripts fire the beam for `sweepfire_firetime` out of `sweepfire_reloadtime`.
		local fireFrames = math_floor(tonumber(fireTime) * gameSpeed + 0.5)
		return weaponDef.projectiles * fireFrames / beamFrames,
			tonumber(weaponDef.customParams.sweepfire_reloadtime) or reload
	end

	return weaponDef.projectiles, math_max(reload, beamFrames * gameSpeedInv)
end

---------------------------------------------------------------------------------------------------
-- Module functions -------------------------------------------------------------------------------

---@param weaponDef WeaponDef
---@param reload number?
---@return number shots
---@return number period
---@return number intensityMin
local function getFiringCycle(weaponDef, reload)
	-- The engine spends reload in whole frames but provides values to game code with no rounding.
	reload = math_max(1, math_floor(((reload or weaponDef.reload) + FRAME_EPS) * gameSpeed)) * gameSpeedInv
	if weaponDef.type == "BeamLaser" then
		local shots, period = getBeamFiringCycle(weaponDef, reload)
		return shots, period, math_max(weaponDef.minIntensity, 0.5)
	end
	return weaponDef.salvoSize * weaponDef.projectiles, reload, 1.0
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

return {
	GetFiringCycle = getFiringCycle,
	GetDamagePerSecond = getDamagePerSecond,
}
