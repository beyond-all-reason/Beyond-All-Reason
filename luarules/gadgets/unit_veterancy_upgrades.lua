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

-- Veterancy effect names
--
-- Replacements for engine scaling:
-- - power
-- - health
-- - reload
-- - acc_weight
--
-- Custom veterancy upgrades:
-- - autoheal
-- - damages
-- - range
-- - reload_then_burst
-- - reload_then_damages

-- customparams[prefix .. name] = number|"default", where "default" refers to some XP scale.
local customParamPrefix = "veterancy_" -- e.g. `veterancy_health = "default"`
local weaponParamIgnore = "no_veterancy_" -- e.g. `no_veterancy_reload = true`.

local defaultVeterancyUpgrades = {
	"health",
	"reload",
}

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

local gameSpeed = Game.gameSpeed
local gameSpeedInverse = 1 / gameSpeed

local armorTypeMin = 0
local armorTypeMax = #Game.armorTypes

local autoHealInterval = math_round(Game.gameSpeed * 0.5) -- match engine interval
local autoHealFraction = autoHealInterval / Game.gameSpeed

local powerScale = Spring.GetModOptions().veterancy_power_scale
local healthScale = Spring.GetModOptions().veterancy_health_scale
local reloadScale = Spring.GetModOptions().veterancy_reload_scale
local damageScale = Spring.GetModOptions().veterancy_damage_scale

-- Unit scripts ----------------------------------------------------------------

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
		local tbl = table.new(6, 1)
		tbl.name = key
		self[key] = tbl
		setmetatable(tbl, mtAppendKeyToName)
		return tbl
	end
})

-- Unit statistics -------------------------------------------------------------

-- The engine will cast to int, which truncates. We prefer rounding, on net, and
-- we want to enforce a one-frame floor for reloading, stockpiling, bursts, etc.
local function toFrameTime(seconds)
	return math_max(math_round(seconds * gameSpeed), 1) * gameSpeedInverse
end

-- Weapon stat collectors

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

local damagesTemp = table.new(armorTypeMax + 1, 0)

local function getDamages(weaponDef)
	local damages = table.new(armorTypeMax + 1, 0)
	local armorTarget = armorTypeMin
	local armorDamage = weaponDef.damages[armorTypeMin]
	for i = armorTypeMin, armorTypeMax do
		damages[i] = weaponDef.damages[i]
		if damages[i] > armorDamage then
			armorTarget, armorDamage = i, damages[i]
		end
	end
	damages[armorTypeMax + 1] = armorTarget
	if armorDamage > 0 then
		return damages
	end
end

local function scaleDamages(unitID, weaponNum, damages, damageMult)
	-- Avoid updates that do not change damage to the primary armor target:
	local armorTarget = damages[armorTypeMax + 1]
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

local function ignoreWeapon(weaponDef, key)
	return weaponDef.customParams[weaponParamIgnore .. key]
end

local function collectReload(weaponDef)
	return not ignoreWeapon(weaponDef, "reload") and weaponDef.reload
end

local function collectScriptedReload(weaponDef)
	return not ignoreWeapon(weaponDef, "scripted_reload") and weaponDef.reload
end

local function collectAccWeight(weaponDef)
	-- FIXME: We cannot modify: predictSpeedMod, leadLimit, targetMoveError, movingAccuracy, wobble.
	return not ignoreWeapon(weaponDef, "acc_weight") and {
		accuracy   = weaponDef.accuracy,
		sprayAngle = weaponDef.sprayAngle,
	}
end

local function collectDamages(weaponDef)
	return not ignoreWeapon(weaponDef, "damages") and weaponDef.customParams.bogus ~= "1" and getDamages(weaponDef)
end

local function collectRange(weaponDef, upgrade)
	if not ignoreWeapon(weaponDef, "range") then
		upgrade.customRangeMax = math_max(weaponDef.range, upgrade.customRangeMax)
		return weaponDef.range
	else
		return false
	end
end

local function collectReloadBurst(weaponDef)
	return not ignoreWeapon(weaponDef, "reload") and not ignoreWeapon(weaponDef, "burst") and getReloadStats(weaponDef)
end

local function collectReloadDamages(weaponDef)
	return not ignoreWeapon(weaponDef, "reload")
		and not ignoreWeapon(weaponDef, "damages")
		and table.merge(getReloadStats(weaponDef), getDamages(weaponDef))
end

-- Unit veterancies ------------------------------------------------------------

---@class VeterancyDefinition
---@field add fun(self:VeterancyDefinition, unitDef:table, upgrades:UnitDefVeterancy[]):boolean
---@field create? fun(self:UnitDefVeterancy, unitID:integer) Called at unit creation.
---@field effect fun(self:UnitDefVeterancy, unitID:integer, experience:number) Applied on experience gain.

---@class UnitDefVeterancy
---@field effect fun(self:UnitDefVeterancy, unitID:integer, experience:number) Applied on experience gain.
---@field factor number The scaling factor for the upgrade against unit XP.
---@field weapons? (table|number|false)[] Weapons data passed to veterancy effects that upgrade weapons.

local unitVeterancyUpgrades = table.new(#UnitDefs, 0) ---@type (UnitDefVeterancy|false)[]
local onUnitCreated = {}

local queuedExperienceGains = {}
local unitAutoHeal = {}

local veterancyEffects = {} ---@type table<string, VeterancyDefinition>

---@return UnitDefVeterancy[]|false
local function addVeterancyUpgrades(unitDef, veterancyList)
	local upgrades = {}
	local onCreate = {}
	for _, name in ipairs(veterancyList) do
		if veterancyEffects[name] then
			local upgrade = veterancyEffects[name]
			local result = upgrade:add(unitDef, upgrades)
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

local function collectWeaponUpgrades(unitDef, upgradeList, upgrade, collect)
	local hasWeapon = false
	local weapons = table.ensureTable(upgrade, "weapons")

	for index, weapon in ipairs(unitDef.weapons) do
		local value = collect(WeaponDefs[weapon.weaponDef], upgrade)
		weapons[index] = value or false
		hasWeapon = (hasWeapon or value) and true
	end

	if hasWeapon then
		upgradeList[#upgradeList + 1] = upgrade
	end

	return hasWeapon
end

local function getScaleFactor(unitDef, key, default)
	default = default or 0
	return tonumber(unitDef.customParams[customParamPrefix .. key] or default) or default
end

local function applyVeterancyEffects(unitID, experience, upgrades)
	local limExperience = experience / (experience + 1) -- (0.0, 1.0)
	for _, upgrade in ipairs(upgrades) do
		upgrade:effect(unitID, limExperience)
	end
end

-- Definitions -----------------------------------------------------------------

-- Some effects are duplicated in-engine so are conditional on our modrules:

-- TODO: We cannot script unit power.
veterancyEffects.power = {
	add = function(self, unitDef, upgrades) return false end,
	effect = function(self, unitID, experience) end,
}

veterancyEffects.health = {
	-- NB: This `self` refers to the definition while effect's `self` is the per-unit upgrade.
	add = function(self, unitDef, upgrades)
		local scaleFactor = getScaleFactor(unitDef, "health", healthScale)
		if scaleFactor <= 0 then
			return false
		end

		local upgrade = {
			effect = self.effect,
			factor = scaleFactor,
			health = unitDef.health,
		}

		upgrades[#upgrades + 1] = upgrade
		return true
	end,

	effect = function(self, unitID, experience)
		local healthMaxXP = math_floor((1 + experience * self.factor) * self.health)
		local health, healthMax = spGetUnitHealth(unitID)
		if healthMaxXP == math_floor(healthMax) then
			return
		end

		spSetUnitMaxHealth(unitID, healthMaxXP)
		spSetUnitHealth(unitID, health * healthMaxXP / healthMax)
	end,
}

veterancyEffects.reload = {
	add = function(self, unitDef, upgrades)
		-- Dynamic reloads per-weapon are scaled at the unit-level for consistency.
		local scaleFactor = getScaleFactor(unitDef, "reload", reloadScale)
		if scaleFactor <= 0 then
			return false
		end

		local upgrade = {
			effect  = self.effect,
			factor  = scaleFactor,
		}

		return collectWeaponUpgrades(unitDef, upgrades, upgrade, collectReload)
	end,

	effect = function(self, unitID, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadDiv = 1 + experience * self.factor
		for weaponNum = 1, #self.weapons do
			if self.weapons[weaponNum] then
				-- This method combines reloadTime with reloadSpeed as an aggregate stat:
				local reloadTime = toFrameTime(self.weapons[weaponNum] / reloadDiv)
				spSetUnitWeaponState(unitID, weaponNum, "reloadTime", reloadTime)
				callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weaponNum], reloadTime * 1000)
			end
		end
		-- Assumes it is safe not to include a call to "SetMaxReloadTime". See scripted_reload.
		-- TODO: Unit scripts need a review first but should make ^that call for animation reasons.
	end,
}

-- Units with "scripted" reload times need to be scaled via this method,
-- under the assumption that the unit otherwise gains no reload bonuses;
-- e.g. it might be odd but is not unreasonable to use this with reload.
veterancyEffects.scripted_reload = {
	add = function(self, unitDef, upgrades)
		-- Shares its scaling customparam with `reload`:
		local scaleFactor = getScaleFactor(unitDef, "scripted_reload", reloadScale)
		if scaleFactor <= 0 then
			return false
		end

		local upgrade = {
			effect  = self.effect,
			factor  = scaleFactor,
		}

		return collectWeaponUpgrades(unitDef, upgrades, upgrade, collectScriptedReload)
	end,

	effect = function(self, unitID, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadMax = 0
		local reloadDiv = 1 + upgrade[2] * experience

		for weaponNum = 1, #self.weapons do
			if self.weapons[weaponNum] then
				-- This method combines reloadTime with reloadSpeed as an aggregate stat:
				local reloadTime = toFrameTime(self.weapons[weaponNum] / reloadDiv)
				spSetUnitWeaponState(unitID, weaponNum, "reloadTime", reloadTime)
				callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weaponNum], reloadTime * 1000)
				reloadMax = math_max(reloadMax, gameSpeedInverse, reloadTime)
			else
				-- The weapon has a non-scripted reload time, so we fetch its live value:
				reloadMax = math_max(reloadMax, gameSpeedInverse, spGetUnitWeaponState(unitID, weaponNum, "reloadTimeXP"))
			end
		end

		-- The unit might have a scripted reload time solely to know this value:
		callUnitScript(unitID, unitLuaEnv, "SetMaxReloadTime", reloadMax * 1000)
	end,
}

-- This is not "accuracy" but "ownerExpAccWeight", which is a catch-all for scaling multiple stats.
-- NOTE: This is included for something like "completeness" but is barely functional as-advertised.
veterancyEffects.acc_weight = {
	add = function(self, unitDef, upgrades)
		-- Dynamic accuracies per-weapon are scaled at the unit-level for consistency.
		local scaleFactor = getScaleFactor(unitDef, "acc_weight", 0)
		if scaleFactor <= 0 then
			return false
		end

		local upgrade = {
			effect = self.effect,
			factor = scaleFactor,
		}

		return collectWeaponUpgrades(unitDef, upgrades, upgrade, collectAccWeight)
	end,

	effect = function(self, unitID, experience)
		local accuracyWeightDiv = 1 + experience * self.factor
		for weaponNum = 1, #self.weapons do
			if self.weapons[weaponNum] then
				spSetUnitWeaponState(unitID, weaponNum, "accuracy", self.weapons[weaponNum].accuracy / accuracyWeightDiv)
				spSetUnitWeaponState(unitID, weaponNum, "sprayAngle", self.weapons[weaponNum].sprayAngle / accuracyWeightDiv)
			end
		end
	end,
}

-- The rest of the veterancy effects have no equivalent function in the engine:

veterancyEffects.autoheal = {
	add = function(self, unitDef, upgrades)
		-- Autoheal can start at zero, and we'd rather not scale against health.
		local autoHealMax = getScaleFactor(unitDef, "autoheal", 0)
		if autoHealMax <= 0 then
			return false
		end

		local upgrade = {
			effect = self.effect,
			factor = autoHealMax,
		}

		upgrades[#upgrades + 1] = upgrade
		return true
	end,

	effect = function(self, unitID, experience)
		local autoHeal = experience * self.factor
		unitAutoHeal[unitID] = autoHeal
		spSetUnitRulesParam(unitID, "veterancy_autoheal", autoHeal)
	end,
}

-- TODO: We do not scale weapon-less weapondefs' damages, e.g. missile ship clusters, impact clusters.
-- TODO: We can scale damages without increased impulse by reducing the impulse factor proprtionately.
-- TODO: Other effects scale with damage, too, like cratering strength. Some do not, like firestarter.
veterancyEffects.damages = {
	add = function(self, unitDef, upgrades)
		-- Dynamic damages per-weapon are scaled at the unit-level for consistency.
		local scaleFactor = getScaleFactor(unitDef, "damage", damageScale)
		if scaleFactor <= 0 then
			return false
		end

		local upgrade = {
			effect = self.effect,
			factor = scaleFactor,
		}

		return collectWeaponUpgrades(unitDef, upgrades, upgrade, collectDamages)
	end,

	effect = function(self, unitID, experience)
		local damageMult = 1 + experience * self.factor
		for weaponNum = 1, #self.weapons do
			if self.weapons[weaponNum] then
				scaleDamages(unitID, weaponNum, self.weapons[weaponNum], damageMult)
			end
		end
	end,
}

-- TODO: Compensation for TTL, projectile speed, etc., depending on the weaponDef.
veterancyEffects.range = {
	add = function(self, unitDef, upgrades)
		-- Dynamic ranges per-weapon are scaled at the unit-level for consistency.
		local scaleFactor = getScaleFactor(unitDef, "range", 0)
		if scaleFactor <= 0 then
			return false
		end

		local upgrade = {
			effect = self.effect,
			factor = scaleFactor,
			customRangeMax = 0,
		}

		local hasUpgrades = collectWeaponUpgrades(unitDef, upgrades, upgrade, collectRange)

		if hasUpgrades then
			-- Units have an engagement range with a bad property name ("maxrange").
			-- We may or may not be scaling that engagement range with weapon range:
			local customMaxRange = tonumber(unitDef.customParams.maxrange or 0) or 0
			if customMaxRange ~= 0 and customMaxRange < upgrade.customMaxRange then
				upgrade.customMaxRange = false
			elseif unitDef.customParams.nomaxrangexpscale then
				upgrade.customMaxRange = false
			end
			return true
		else
			return false
		end
	end,

	effect = function(self, unitID, experience)
		local experienceCurved = (3 * experience) / (2 * experience + 1) -- limExperience = (3 * xp) / (3 * xp + 1).
		local rangeMult = (1 + experienceCurved * self.factor)

		if self.customRangeMax then
			spSetUnitMaxRange(unitID, math_floor(self.customRangeMax * rangeMult))
		end

		for weaponNum = 1, #self.weapons do
			if self.weapons[weaponNum] then
				spSetUnitWeaponState(unitID, weaponNum, "range", math_floor(self.weapons[weaponNum] * rangeMult))
			end
		end
	end,
}

-- When a weapon's reload time equals its burst duration, faster reloads provide no benefit.
-- This XP upgrade continues to scale the burst rate with faster reloads (up to 1/30th sec).
-- NOTE: Weapon sounds usually trigger only once per burst and play the sound of many shots.
veterancyEffects.reload_then_burst = {
	add = function(self, unitDef, upgrades)
		local scaleFactor = getScaleFactor(unitDef, "reload_then_burst", reloadScale)
		if scaleFactor <= 0 then
			return false
		end

		local upgrade = {
			effect = self.effect,
			factor = scaleFactor,
		}

		return collectWeaponUpgrades(unitDef, upgrades, upgrade, collectReloadBurst)
	end,

	effect = function(self, unitID, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadDiv = 1 + experience * self.factor
		for weaponNum = 1, #self.weapons do
			if self.weapons[weaponNum] then
				local reloadTime = self.weapons[weaponNum].reloadTime
				local salvoDuration = self.weapons[weaponNum].salvoTime
				local reloadWanted = toFrameTime(reloadTime / reloadDiv)

				if salvoDuration and reloadWanted < salvoDuration then
					local salvoSize = self.weapons[weaponNum].salvoSize
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
					spSetUnitWeaponState(unitID, weaponNum, "burstRate", salvoDelay)
				end

				spSetUnitWeaponState(unitID, weaponNum, "reloadTime", reloadWanted)
				callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weaponNum], reloadWanted * 1000)
			end
		end
	end,
}

-- When a weapon's reload time equals its burst duration, faster reloads provide no benefit.
-- This XP upgrade continues to scale the weapon's DPS output by directly increasing damage.
-- NOTE: Preferable to reload_then_burst usually but we have no scaling damage vfx just yet.
veterancyEffects.reload_then_damages = {
	add = function(self, unitDef, upgrades)
		-- Shares its scaling customparams with `reload`/`damage`, but does not check `damageScale`:
		local unitReloadScale = getScaleFactor(unitDef, "reload", reloadScale)
		local unitDamageScale = getScaleFactor(unitDef, "damage", unitReloadScale)
		if unitReloadScale <= 0 and unitDamageScale <= 0 then
			return false
		end

		local upgrade = {
			effect = self.effect,
			reloadFactor = unitReloadScale,
			damageFactor = unitDamageScale,
		}

		return collectWeaponUpgrades(unitDef, upgrades, upgrade, collectReloadDamages)
	end,

	effect = function(self, unitID, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadDiv = 1 + experience * self.reloadFactor
		local damageMult = 1 + experience * self.damageFactor
		for weaponNum = 1, #self.weapons do
			if self.weapons[weaponNum] then
				local reloadTime = self.weapons[weaponNum].reloadTime
				local salvoTime = self.weapons[weaponNum].salvoTime
				local weapon = weaponNum - 3

				local reloadWanted = toFrameTime(reloadTime / reloadDiv)
				local weaponDamageMult = 1

				if salvoTime then
					if reloadTime > salvoTime then
						if reloadWanted < salvoTime then
							reloadWanted = salvoTime
							-- Get the remaining XP after the reload time and burst time are equal:
							local weaponReloadXP = (reloadTime / salvoTime - 1) / self.reloadFactor
							local weaponDamageXP = (experience - weaponReloadXP)
							weaponDamageMult = 1 + weaponDamageXP * self.damageFactor
						end
					else
						weaponDamageMult = damageMult
					end
				end

				spSetUnitWeaponState(unitID, weapon, "reloadTime", reloadWanted)
				callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weapon], reloadWanted * 1000)

				if weaponDamageMult > 1 then
					scaleDamages(unitID, weapon, self.weapons[weaponNum], weaponDamageMult)
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

	local customKeyMap = table.map(veterancyEffects, function(_, key) return key, customParamPrefix .. key end)
	for unitDefID, unitDef in ipairs(UnitDefs) do
		local veterancyList = {}
		local customParams = unitDef.customParams
		for customKey, veterancyKey in pairs(customKeyMap) do
			if customParams[customKey] ~= nil then
				veterancyList[#veterancyList + 1] = veterancyKey
			end
		end
		if not veterancyList[1] then
			veterancyList = defaultVeterancyUpgrades
		end
		unitVeterancyUpgrades[unitDefID] = addVeterancyUpgrades(unitDef, veterancyList)
	end

	if not table.any(unitVeterancyUpgrades, function(v) return v end) then
		gadgetHandler:RemoveGadget()
		return
	end

	for _, unitID in pairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
		if spGetUnitIsDead(unitID) == false and spGetUnitExperience(unitID) > 0 then
			local unitDefID = Spring.GetUnitDefID(unitID)
			applyVeterancyEffects(unitID, spGetUnitExperience(unitID), unitVeterancyUpgrades[unitDefID])
		end
	end
end
