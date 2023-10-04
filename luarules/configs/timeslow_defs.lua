------------------------
-- Config


if Spring.GetModOptions().emprework == true then

	local MAX_SLOW_FACTOR = 0.9
	-- Max slow damage on a unit = MAX_SLOW_FACTOR * current health
	-- Slowdown of unit = slow damage / current health
	-- So MAX_SLOW_FACTOR is the limit for how much units can be slowed

	local DEGRADE_TIMER = 0.5
	-- Time in seconds before the slow damage a unit takes starts to decay

	local DEGRADE_FACTOR = 0.04
	-- Units will lose DEGRADE_FACTOR*(current health) slow damage per second

	local UPDATE_PERIOD = 15 -- I'd prefer if this was not changed



	------------------------
	-- Send the Config

	local weaponArray = {}

	for name, data in pairs(WeaponDefNames) do
		local cp = data.customParams
		if cp.timeslow_damagefactor or cp.timeslow_damage or cp.timeslow_onlyslow then
			local custom = {scaleSlow = true}
			custom.slowDamage = cp.timeslow_damage or ((cp.timeslow_damagefactor or (cp.timeslow_onlyslow and 1)) * cp.raw_damage)
			custom.overslow = cp.timeslow_overslow_frames and (cp.timeslow_overslow_frames * DEGRADE_FACTOR / 30)
			custom.onlySlow = (cp.timeslow_onlyslow) or false
			custom.smartRetarget = cp.timeslow_smartretarget and tonumber(cp.timeslow_smartretarget) or nil
			custom.smartRetargetHealth = cp.timeslow_smartretargethealth and tonumber(cp.timeslow_smartretargethealth) or nil
			custom.rawDamage = tonumber(cp.raw_damage)
			weaponArray[data.id] = custom
		end
	end

	return weaponArray, MAX_SLOW_FACTOR, DEGRADE_TIMER*30/UPDATE_PERIOD, DEGRADE_FACTOR*UPDATE_PERIOD/30, UPDATE_PERIOD


end