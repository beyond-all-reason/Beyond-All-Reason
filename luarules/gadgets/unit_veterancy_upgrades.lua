local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name    = "Unit Veterancy Upgrades",
		desc    = "Applies unit and weapon bonuses as units gain XP",
		author  = "efrec",
		version = "1.0",
		date    = "2026-03",
		license = "GNU GPL, v2 or later",
		layer   = 1000, -- delay until after damaging effects resolve to xp gain
		enabled = Spring.GetModOptions().veterancy_upgrades,
	}
end

-- Unit experience rework
-- 
-- The engine's base XP system produces granular bonuses when units deal damage to enemies.
-- 
-- The "veterancies" system instead uses fixed ranks with fixed upgrades at rank increase.
-- Different unit types (to be determined) will have different default ranks and upgrades.
-- Custom ranks and upgrades will be configurable via unitdefs so also supports tweakdefs.

-- customparams[prefix .. name] = number|"default", where "default" refers to some XP scale.
local customParamPrefix = "veterancy_" -- e.g. `veterancy_health = "default"`
local weaponParamIgnore = "no_veterancy_" -- e.g. `no_veterancy_reload = true`.

local defaultVeterancyUpgrades = {
	"health",
	"reload",
}

---@alias Veterancy { add:(fun(unitDef:table, upgrades:VeterancyUpgrade[]):boolean), create:fun(unitID)?, effect:VeterancyEffect }
---@alias VeterancyEffect fun(unitID:integer, upgrade:VeterancyUpgrade, experience:number) Applied on experience gain.
---@alias VeterancyUpgrade { [1]:VeterancyEffect, [2]:any|false, [3]:any|false } Compact upgrade information per-unitdef.

local table_new = table.new
local math_floor = math.floor
local math_round = math.round
local math_max = math.max
local math_min = math.min

local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitWeaponDamages = Spring.GetUnitWeaponDamages
local spGetUnitWeaponState = Spring.GetUnitWeaponState

local spSetUnitHealth = Spring.SetUnitHealth
local spSetUnitMaxHealth = Spring.SetUnitMaxHealth
local spSetUnitMaxRange = Spring.SetUnitMaxRange
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spSetUnitWeaponDamages = Spring.SetUnitWeaponDamages
local spSetUnitWeaponState = Spring.SetUnitWeaponState

local spGetCOBScriptID = Spring.GetCOBScriptID
local spCallCOBScript = Spring.CallCOBScript
local spGetScriptEnv = Spring.UnitScript.GetScriptEnv
local spCallLuaScript = Spring.UnitScript.CallAsUnit

local function callUnitScript(unitID, luaEnv, methodName, ...)
	if luaEnv then
		if luaEnv[methodName] then
			spCallLuaScript(unitID, luaEnv[methodName], ...)
		end
	elseif spGetCOBScriptID(unitID, methodName) then
		spCallCOBScript(unitID, methodName, 0, ...)
	end
end

local gameSpeed = Game.gameSpeed
local gameSpeedInverse = 1 / gameSpeed

local armorTypeMin = 0
local armorTypeMax = #Game.armorTypes

local autoHealInterval = math_round(Game.gameSpeed * 0.5) -- match engine interval
local autoHealFraction = Game.gameSpeed / autoHealInterval

local powerScale = Spring.GetModOptions().veterancy_power_scale
local healthScale = Spring.GetModOptions().veterancy_health_scale
local reloadScale = Spring.GetModOptions().veterancy_reload_scale
local damageScale = Spring.GetModOptions().veterancy_damage_scale

-- Code ------------------------------------------------------------------------

local veterancyEffects = {} ---@type table<string, Veterancy>
local onUnitCreated = {}

local function addVeterancyUpgrades(unitDef, veterancyList)
	local upgrades = {}
	local onCreate = {}
	for _, name in ipairs(veterancyList) do
		if veterancyEffects[name] then
			local upgrade = veterancyEffects[name]
			local result = upgrade.add(unitDef, upgrades)
			if result and upgrade.create then
				onCreate[#onCreate + 1] = upgrade.create
			end
		end
	end
	if next(upgrades) then
		if onCreate[1] then
			onUnitCreated[unitDef.id] = onCreate
		end
		return upgrades
	else
		return false
	end
end

local function applyVeterancyEffects(unitID, experience, upgrades)
	local limExperience = experience / (experience + 1) -- (0.0, 1.0)
	for index = 1, #upgrades do
		local upgrade = upgrades[index]
		local effect = upgrade[1]
		effect(unitID, upgrade, limExperience)
	end
end

local unitVeterancyUpgrades = table_new(#UnitDefs, 0)
local queuedExperienceGains = {}

-- Increases to autoheal and idle autoheal have to be handled in game code.
local unitAutoHeal = {}

-- Cache strings rather than creating garbage in a hot loop.
local mtAppendKeyToName = {
	__index = function(self, key)
		local result = self.name .. tostring(key)
		self[key] = result
		return result
	end
}
local call = setmetatable({}, {
	__index = function(self, key)
		local tbl = table_new(6, 1)
		tbl.name = key
		self[key] = tbl
		setmetatable(tbl, mtAppendKeyToName)
		return tbl
	end
})

local function getScale(unitDef, key, fallback)
	return tonumber(unitDef.customParams[customParamPrefix .. key] or fallback)
		or fallback or 0
end

local function ignoreWeapon(weaponDef, key)
	return weaponDef.customParams[weaponParamIgnore .. key]
end

-- The engine will cast to int, which truncates. We prefer rounding, on net, and
-- we want to enforce a one-frame floor for reloading, stockpiling, bursts, etc.
local function toFrameTime(seconds)
	return math_max(math_round(seconds * gameSpeed), 1) * gameSpeedInverse
end

local function getBurstStats(weaponDef)
	local stats = {}
	if weaponDef.type == "BeamLaser" and not weaponDef.beamburst then
		stats.salvoSize = 1
		stats.salvoDelay = weaponDef.beamtime
		stats.salvoTime = weaponDef.beamtime
	else
		stats.salvoSize = weaponDef.salvoSize
		stats.salvoDelay = weaponDef.salvoDelay
		stats.salvoTime = stats.salvoSize * stats.salvoDelay
	end
	stats.salvoDelay = toFrameTime(stats.salvoDelay)
	stats.salvoTime = toFrameTime(stats.salvoTime)
	return stats
end

local armorTargetIndex = armorTypeMin - 1
local damagesTemp = table.new(armorTypeMax, 1 - armorTypeMin)

local function getDamages(weaponDef)
	local damages = table.new(armorTypeMax, 1 - armorTypeMin)
	damages[armorTargetIndex] = armorTypeMin
	local armorDamage = weaponDef.damages[armorTypeMin]
	for i = armorTypeMin, armorTypeMax do
		damages[i] = weaponDef.damages[i]
		if damages[i] > armorDamage then
			damages[armorTargetIndex], armorDamage = i, damages[i]
		end
	end
	if armorDamage > 0 then
		return damages
	end
end

local function scaleDamages(unitID, weaponNum, damages, damageMult)
	-- Avoid updates that do not change damage to the primary armor target:
	local armorTarget = damages[armorTargetIndex]
	local armorDamage = spGetUnitWeaponDamages(unitID, weaponNum, armorTarget)
	if armorDamage == math_round(damages[armorTarget] * damageMult) then
		return
	end

	-- Avoid nArmorTypes engine calls that repeat parsing of simple inputs:
	local d = damagesTemp
	for i = armorTypeMin, armorTypeMax do
		d[i] = math_round(damages[i] * damageMult)
	end
	spSetUnitWeaponDamages(unitID, weaponNum, d)
	spSetUnitRulesParam(unitID, "veterancy_damages_multiplier", damageMult)
end

local function getReloadStats(weaponDef)
	local weaponUpgrade = { reloadTime = weaponDef.reload }
	local stats = getBurstStats(weaponDef)
	-- BeamLaser weapons cannot scale in burst duration; not really, anyway.
	-- They have an internal `salvoDamageMult` so would need damage scaling.
	if stats and stats.salvoSize > 1 and stats.salvoTime > gameSpeedInverse then
		weaponUpgrade.salvoSize = stats.salvoSize
		weaponUpgrade.salvoTime = stats.salvoTime
	end
	return weaponUpgrade
end

-- Unit veterancies ------------------------------------------------------------

-- Some effects are duplicated in-engine so are conditional on our modrules:

-- TODO: We cannot script unit power.
veterancyEffects.power = {
	add = function(unitDef, upgrades) return false end,
}

veterancyEffects.health = {
	add = function(unitDef, upgrades)
		local scale = getScale(unitDef, "health", healthScale)
		if scale <= 0 then
			return false
		end

		---@type VeterancyUpgrade
		local upgrade = {
			veterancyEffects.health.effect,
			scale,
			unitDef.health,
		}

		upgrades[#upgrades + 1] = upgrade
		return true
	end,

	effect = function(unitID, upgrade, experience)
		local healthMaxXP = math_floor(upgrade[3] * (1 + upgrade[2] * experience))
		local health, healthMax = spGetUnitHealth(unitID)
		if healthMaxXP == math_floor(healthMax) then
			return
		end

		spSetUnitMaxHealth(unitID, healthMaxXP)
		spSetUnitHealth(unitID, health * healthMaxXP / healthMax)
	end,
}

veterancyEffects.reload = {
	add = function(unitDef, upgrades)
		-- Dynamic reloads per-weapon are scaled at the unit-level for consistency.
		local scale = getScale(unitDef, "reload", reloadScale)
		if scale <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.reload.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not ignoreWeapon(weaponDef, "reload") then
				hasUpgradeWeapon = true
				upgrade[index + offset] = weaponDef.reload
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadDiv = 1 + upgrade[2] * experience
		for index = 3, #upgrade do
			if upgrade[index] then
				-- This method combines reloadTime with reloadSpeed as an aggregate stat:
				local reloadTime = toFrameTime(upgrade[index] / reloadDiv)
				local weapon = index - 2
				spSetUnitWeaponState(unitID, weapon, "reloadTime", reloadTime)
				callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weapon], reloadTime * 1000)
			end
		end
		-- Assumes it is safe not to include a call to "SetMaxReloadTime". See scripted_reload.
	end,
}

-- Units with "scripted" reload times need to be scaled via this method,
-- under the assumption that the unit otherwise gains no reload bonuses;
-- e.g. it might be odd but is not unreasonable to use this with reload.
veterancyEffects.scripted_reload = {
	add = function(unitDef, upgrades)
		-- Shares its scaling customparam with `reload`:
		local scale = getScale(unitDef, "scripted_reload", reloadScale)
		if scale <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.scripted_reload.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not ignoreWeapon(weaponDef, "scripted_reload") then
				hasUpgradeWeapon = true
				upgrade[index + offset] = weaponDef.reload
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadMax = 0
		local reloadDiv = 1 + upgrade[2] * experience

		for index = 3, #upgrade do
			local weapon = index - 2
			if upgrade[index] then
				-- This method combines reloadTime with reloadSpeed as an aggregate stat:
				local reloadTime = toFrameTime(upgrade[index] / reloadDiv)
				spSetUnitWeaponState(unitID, weapon, "reloadTime", reloadTime)
				callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weapon], reloadTime * 1000)
				reloadMax = math_max(reloadMax, gameSpeedInverse, reloadTime)
			else
				-- The weapon has a non-scripted reload time, so we fetch its live value:
				reloadMax = math_max(reloadMax, gameSpeedInverse, spGetUnitWeaponState(unitID, weapon, "reloadTimeXP"))
			end
		end

		-- The unit might have a scripted reload time solely to know this value:
		callUnitScript(unitID, unitLuaEnv, "SetMaxReloadTime", reloadMax * 1000)
	end,
}

-- This is not "accuracy" but "ownerExpAccWeight", which is a catch-all for scaling multiple stats.
-- NOTE: This is included for something like "completeness" but is barely functional as-advertised.
veterancyEffects.acc_weight = {
	add = function(unitDef, upgrades)
		-- Dynamic accuracies per-weapon are scaled at the unit-level for consistency.
		local scale = getScale(unitDef, "acc_weight", 0)
		if scale <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.acc_weight.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not ignoreWeapon(weaponDef, "acc_weight") then
				-- FIXME: We cannot modify: predictSpeedMod, leadLimit, targetMoveError, movingAccuracy, wobble.
				hasUpgradeWeapon = true
				upgrade[index + offset] = {
					accuracy   = weaponDef.accuracy,
					sprayAngle = weaponDef.sprayAngle,
				}
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local accuracyWeightDiv = 1 + upgrade[2] * experience
		for index = 3, #upgrade do
			if upgrade[index] then
				local weapon = index - 2
				spSetUnitWeaponState(unitID, weapon, "accuracy", upgrade[index].accuracy / accuracyWeightDiv)
				spSetUnitWeaponState(unitID, weapon, "sprayAngle", upgrade[index].sprayAngle / accuracyWeightDiv)
			end
		end
	end,
}

-- The rest of the veterancy effects have no equivalent function in the engine:

veterancyEffects.autoheal = {
	add = function(unitDef, upgrades)
		-- Autoheal can start at zero, and we'd rather not scale against health.
		local valueMaxXP = getScale(unitDef, "autoheal", 0)
		if valueMaxXP <= 0 then
			return false
		end

		---@type VeterancyUpgrade
		local upgrade = {
			veterancyEffects.autoheal.effect,
			valueMaxXP,
		}

		if upgrade[2] > 0 and upgrade[3] > 0 then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local autoHeal = upgrade[2] * experience
		unitAutoHeal[unitID] = autoHeal
		spSetUnitRulesParam(unitID, "veterancy_autoheal", autoHeal)
	end,
}

-- TODO: We do not scale weapon-less weapondefs' damages, e.g. missile ship clusters, impact clusters.
veterancyEffects.damages = {
	add = function(unitDef, upgrades)
		-- Dynamic damages per-weapon are scaled at the unit-level for consistency.
		local scale = getScale(unitDef, "damage", damageScale)
		if scale <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.damages.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			local damages = nil
			if not ignoreWeapon(weaponDef, "damages") and weaponDef.customParams.bogus ~= "1" then
				damages = getDamages(weaponDef)
			end
			if damages then
				hasUpgradeWeapon = true
				upgrade[index + offset] = damages
			else
				upgrade[index + offset] = false
			end
		end
		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local damageMult = 1 + upgrade[2] * experience
		for index = 3, #upgrade do
			if upgrade[index] then
				scaleDamages(unitID, index - 2, upgrade[index], damageMult)
			end
		end
	end,
}

-- TODO: Compensation for TTL, projectile speed, etc., depending on the weaponDef.
veterancyEffects.range = {
	add = function(unitDef, upgrades)
		-- Dynamic ranges per-weapon are scaled at the unit-level for consistency.
		local scale = getScale(unitDef, "range", 0)
		if scale <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.range.effect, scale, 0 } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not ignoreWeapon(weaponDef, "range") then
				hasUpgradeWeapon = true
				upgrade[3] = math_max(weaponDef.range, upgrade[3])
				upgrade[index + offset] = weaponDef.range
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			local customMaxRange = tonumber(unitDef.customParams.maxrange or 0) or 0
			if (customMaxRange ~= 0 and customMaxRange < upgrade[3]) or unitDef.customParams.nomaxrangexpscale then
				upgrade[3] = false
			end
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local experienceCurved = (3 * experience) / (2 * experience + 1) -- limExperience = (3 * xp) / (3 * xp + 1).
		local rangeMult = (1 + upgrade[2] * experienceCurved)

		if upgrade[3] then
			spSetUnitMaxRange(unitID, math_floor(upgrade[3] * rangeMult))
		end

		for index = 4, #upgrade do
			if upgrade[index] then
				spSetUnitWeaponState(unitID, index - 3, "range", math_floor(upgrade[index] * rangeMult))
			end
		end
	end,
}

-- When a weapon's reload time equals its burst duration, faster reloads provide no benefit.
-- This XP upgrade continues to scale the burst rate with faster reloads (up to 1/30th sec).
-- NOTE: Weapon sounds usually trigger only once per burst and play the sound of many shots.
veterancyEffects.reload_then_burst = {
	add = function(unitDef, upgrades)
		-- Shares its scaling customparam with `reload`:
		local scale = getScale(unitDef, "reload_then_burst", reloadScale)
		if scale <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.reload_then_burst.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not ignoreWeapon(weaponDef, "reload") and not ignoreWeapon(weaponDef, "burst") then
				hasUpgradeWeapon = true
				upgrade[index + offset] = getReloadStats(weaponDef)
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadDiv = 1 + upgrade[2] * experience
		for index = 3, #upgrade do
			if upgrade[index] then
				local reloadTime = upgrade[index].reloadTime
				local salvoDuration = upgrade[index].salvoTime
				local weapon = index - 2

				local reloadWanted = toFrameTime(reloadTime / reloadDiv)

				if salvoDuration and reloadWanted < salvoDuration then
					local salvoSize = upgrade[index].salvoSize
					local salvoDelay
					if reloadTime <= salvoDuration then
						-- When reload and burst are the same, each scales with full unit XP.
						salvoDelay = toFrameTime(reloadWanted / salvoSize)
					else
						-- Else, the burst and the reload-below-burst split the full unit XP.
						local difference = (salvoDuration - reloadWanted) * 0.5
						reloadWanted = toFrameTime(reloadWanted - difference)
						salvoDelay = toFrameTime((salvoDuration - difference) / salvoSize)
					end
					spSetUnitWeaponState(unitID, weapon, "burstRate", salvoDelay)
				end

				spSetUnitWeaponState(unitID, weapon, "reloadTime", reloadWanted)
				callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weapon], reloadWanted * 1000)
			end
		end
	end,
}

-- When a weapon's reload time equals its burst duration, faster reloads provide no benefit.
-- This XP upgrade continues to scale the weapon's DPS output by directly increasing damage.
-- NOTE: Preferable to reload_then_burst usually but we have no scaling damage vfx just yet.
veterancyEffects.reload_then_damage = {
	add = function(unitDef, upgrades)
		-- Shares its scaling customparams with `reload`/`damage`, but does not check `damageScale`:
		local unitReloadScale = getScale(unitDef, "reload", reloadScale)
		local unitDamageScale = getScale(unitDef, "damage", unitReloadScale)
		if unitReloadScale <= 0 and unitDamageScale <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.reload_then_damage.effect, unitReloadScale, unitDamageScale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]

			local reloads
			if not ignoreWeapon(weaponDef, "reload") then
				reloads = getReloadStats(weaponDef)
			end

			local damages
			if not ignoreWeapon(weaponDef, "damages") then -- allow bogus weapons so paired fake/real weapons scale together
				damages = getDamages(weaponDef)
			end

			if reloads and damages then
				hasUpgradeWeapon = true
				upgrade[index + offset] = table.merge(reloads, damages)
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadDiv = 1 + upgrade[2] * experience
		local damageMult = 1 + upgrade[3] * experience
		for index = 4, #upgrade do
			if upgrade[index] then
				local reloadTime = upgrade[index].reloadTime
				local salvoTime = upgrade[index].salvoTime
				local weapon = index - 3

				local reloadWanted = toFrameTime(reloadTime / reloadDiv)
				local weaponDamageMult = 1

				if salvoTime then
					if reloadTime > salvoTime then
						if reloadWanted < salvoTime then
							reloadWanted = salvoTime
							-- Get the XP with equal reload time and burst duration.
							local weaponReloadXP = (reloadTime / salvoTime - 1) / upgrade[2]
							local weaponDamageXP = experience - weaponReloadXP
							weaponDamageMult = 1 + upgrade[3] * weaponDamageXP
						end
					else
						weaponDamageMult = damageMult
					end
				end

				spSetUnitWeaponState(unitID, weapon, "reloadTime", reloadWanted)
				callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weapon], reloadWanted * 1000)

				if weaponDamageMult > 1 then
					scaleDamages(unitID, weapon, upgrade[index], weaponDamageMult)
				end
			end
		end
	end,
}

-- Engine callins --------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local onCreated = onUnitCreated[unitDefID]
	if onCreated then
		for i = 1, #onCreated do
			onCreated[i](unitID)
		end
	end
end

function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	if unitVeterancyUpgrades[unitDefID] then
		queuedExperienceGains[unitID] = unitDefID
	end
end

function gadget:GameFramePost(frame)
	for unitID, unitDefID in pairs(queuedExperienceGains) do
		if spGetUnitIsDead(unitID) == false then
			applyVeterancyEffects(unitID, spGetUnitExperience(unitID), unitVeterancyUpgrades[unitDefID])
		end
		queuedExperienceGains[unitID] = nil
	end

	if frame % autoHealInterval == 0 then
		for unitID, autoHeal in pairs(unitAutoHeal) do
			if spGetUnitIsDead(unitID) == false then
				local health, healthMax = spGetUnitHealth(unitID)
				if health < healthMax then
					spSetUnitHealth(unitID, math_min(health + autoHeal * autoHealFraction, healthMax))
				end
			else
				unitAutoHeal[unitID] = nil
			end
		end
	end
end

function gadget:Initialize()
	-- Without this, many XP gains may be too small to reach g:UnitExperience.
	-- We still do not capture some updates, e.g. nuclear explosions vs walls.
	-- TODO: Move this into the game setup? Or something? Why in a gadget?
	Spring.SetExperienceGrade(0.01)

	local keys = table.map(veterancyEffects, function(v, k) return true, (k:gsub(customParamPrefix, "")) end)

	for unitDefID, unitDef in ipairs(UnitDefs) do
		local unitParams = unitDef.customParams
		local veterancies = {}
		for key in pairs(keys) do
			if unitParams[key] then
				veterancies[#veterancies + 1] = key
			end
		end
		if not veterancies[1] then
			veterancies = defaultVeterancyUpgrades
		end
		unitVeterancyUpgrades[unitDefID] = addVeterancyUpgrades(unitDef, veterancies)
	end

	if not table.any(unitVeterancyUpgrades, function(v) return v end) then
		gadgetHandler:RemoveGadget()
		return
	end

	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, unitDefID)
		if spGetUnitIsDead(unitID) == false and spGetUnitExperience(unitID) > 0 then
			local unitDefID = Spring.GetUnitDefID(unitID)
			applyVeterancyEffects(unitID, spGetUnitExperience(unitID), unitVeterancyUpgrades[unitDefID])
		end
	end
end
