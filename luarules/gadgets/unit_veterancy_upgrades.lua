local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name    = "Unit Veterancy Upgrades",
		desc    = "Applies special unit and weapon bonuses when units earn XP",
		author  = "efrec",
		version = "1.0",
		date    = "2026-03",
		license = "GNU GPL, v2 or later",
		layer   = 1000, -- delay until after damaging effects resolve to xp gain
		enabled = Spring.GetModOptions().veterancy_upgrades,
	}
end

-- TODO: We should use shared code for changes to unit attributes (but not unit_attributes).
-- That file is just kind of a mess imo. I'm not sure about its "true" vs abandoned intents.

-- TODO: The GDD requires veterancy effects to be level-up effects that occur one at a time.
-- These upgrades apply every time that XP is gained, provided the amount gained is >= 0.01.
-- Since some XP gains are below this threshold, upgrades should never consider an XP-delta.

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
	for _, name in ipairs(table.getUniqueArray(veterancyList)) do
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
	-- Canonical BAR experience limit curve. Gaze upon it.
	local experienceCurved = (3 * experience) / (1 + 3 * experience)

	for index = 1, #upgrades do
		local upgrade = upgrades[index]
		local effect = upgrade[1]
		effect(unitID, upgrade, experienceCurved)
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

-- The engine will cast to int, which truncates. We prefer rounding, on net, and
-- we want to enforce a one-frame floor for reloading, stockpiling, bursts, etc.
local function toFrameTime(seconds)
	return math_max(math_round(seconds * gameSpeed), 1) * gameSpeedInverse + 1e-7
end

-- Unit veterancies ------------------------------------------------------------

-- Some effects are duplicated in-engine so are conditional on our modrules:

-- TODO: We cannot script unit power.
veterancyEffects.power = {
	add = function(unitDef, upgrades) return false end,
}

veterancyEffects.health = {
	add = function(unitDef, upgrades)
		local scale = tonumber(unitDef.customParams.veterancy_health_scale or healthScale)
		if (scale or 0) <= 0 then
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
		local scale = tonumber(unitDef.customParams.veterancy_reload_scale or reloadScale)
		if (scale or 0) <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.reload.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not weaponDef.customParams.noreloadxpscale then
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
		local scale = tonumber(unitDef.customParams.veterancy_reload_scale or reloadScale)
		if (scale or 0) <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.scripted_reload.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not weaponDef.customParams.noscriptreloadxpscale then -- OK to be a bogus weapon
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

-- The rest of the veterancy effects have no equivalent function in the engine:

veterancyEffects.autoheal = {
	add = function(unitDef, upgrades)
		-- With continuous XP, we have to use a scale value rather than a constant
		local scale = tonumber(unitDef.customParams.veterancy_autoheal_scale or 0)
		if (scale or 0) <= 0 then
			return false
		end

		---@type VeterancyUpgrade
		local upgrade = {
			veterancyEffects.autoheal.effect,
			scale,
			unitDef.health, -- Not scaled against autoheal, which might begin at zero.
		}

		if upgrade[2] > 0 and upgrade[3] > 0 then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local healScale = 1 + upgrade[2] * experience
		local autoHealExtra = upgrade[3] * healScale
		unitAutoHeal[unitID] = autoHealExtra
		spSetUnitRulesParam(unitID, "veterancy_autoheal", autoHealExtra)
	end,
}

local armorTargetIndex = armorTypeMin - 1
local damagesTemp = table.new(armorTypeMax, 1 - armorTypeMin)

veterancyEffects.damages = {
	add = function(unitDef, upgrades)
		-- Dynamic damages per-weapon are scaled at the unit-level for consistency.
		local scale = tonumber(unitDef.customParams.veterancy_damage_scale or damageScale)
		if (scale or 0) <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.damages.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			local damages = nil
			if not weaponDef.customParams.nodamagexpscale and weaponDef.customParams.bogus ~= "1" then
				damages = table.new(armorTypeMax, 1 - armorTypeMin)
				damages[armorTargetIndex] = armorTypeMin
				local armorDamage = weaponDef.damages[armorTypeMin]
				for i = armorTypeMin, armorTypeMax do
					damages[i] = weaponDef.damages[i]
					if damages[i] > armorDamage then
						damages[armorTargetIndex], armorDamage = i, damages[i]
					end
				end
				if armorDamage <= 0 then
					damages = nil
				end
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
				local damages = upgrade[index]
				local weapon = index - 2

				-- Avoid updates that do not change damage to the primary armor target:
				local armorTarget = damages[armorTargetIndex]
				local armorDamage = spGetUnitWeaponDamages(unitID, weapon, armorTarget)
				if armorDamage == math_round(damages[armorTarget] * damageMult) then
					return
				end

				-- Avoid nArmorTypes engine calls that repeat parsing of simple inputs:
				local d = damagesTemp
				for i = armorTypeMin, armorTypeMax do
					d[i] = math_round(damages[i] * damageMult)
				end
				spSetUnitWeaponDamages(unitID, weapon, d)
				spSetUnitRulesParam(unitID, "veterancy_damages_multiplier", damageMult)
			end
		end
	end,
}

-- TODO: Compensation for TTL, projectile speed, etc., depending on the weaponDef.
veterancyEffects.range = {
	add = function(unitDef, upgrades)
		-- Dynamic ranges per-weapon are scaled at the unit-level for consistency.
		local scale = tonumber(unitDef.customParams.veterancy_range_scale or 0)
		if (scale or 0) <= 0 then
			return false
		end

		local customMaxRange = tonumber(unitDef.customParams.maxrange or 0) or 0

		---@type VeterancyUpgrade
		local upgrade = {
			veterancyEffects.range.effect,
			scale,
			customMaxRange,
		}
		local offset = #upgrade

		if upgrade[2] <= 0 then
			return false
		end

		local hasUpgradeWeapon = false
		local weaponMaxRange = 0

		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			weaponMaxRange = math_max(weaponDef.range, weaponMaxRange)
			if not weaponDef.customParams.norangexpscale then -- OK to be a bogus weapon
				hasUpgradeWeapon = true
				upgrade[index + offset] = weaponDef.range
				upgrade[3] = math_max(weaponDef.range, upgrade[3])
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			if customMaxRange ~= 0 then
				weaponMaxRange = math_min(customMaxRange, weaponMaxRange)
			end

			if upgrade[3] < weaponMaxRange or unitDef.customParams.nomaxrangexpscale then
				upgrade[3] = false
			end

			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local rangeMult = (1 + upgrade[2] * experience)

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
		local scale = tonumber(unitDef.customParams.veterancy_reload_scale or reloadScale)
		if (scale or 0) <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.reload.effect, scale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not weaponDef.customParams.noreloadxpscale then
				hasUpgradeWeapon = true
				upgrade[index + offset] = {
					reload = weaponDef.reload,
					burst  = weaponDef.salvoSize * weaponDef.salvoDelay,
					salvo  = weaponDef.salvoSize,
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
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadDiv = 1 + upgrade[2] * experience
		for index = 3, #upgrade do
			if upgrade[index] then
				local burst = upgrade[index].burst
				local salvo = upgrade[index].salvo
				local reload = upgrade[index].reload
				local weapon = index - 2

				local burstDuration = burst * salvo
				local reloadWanted = toFrameTime(reload / reloadDiv)
				if reloadWanted < burstDuration then
					-- When reload and burst are the same, treat each as fully scaling with XP.
					local salvoDelay
					if reload <= burstDuration then
						salvoDelay = reloadWanted
					else
						-- Else, we rescale the burst and the reload-below-burst by half, each.
						local difference = (burstDuration - reloadWanted) * 0.5
						reloadWanted = toFrameTime(reloadWanted - difference)
						salvoDelay = toFrameTime((burstDuration - difference) / salvo)
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
veterancyEffects.reload_then_damage = {
	add = function(unitDef, upgrades)
		-- Shares its scaling customparams with `reload`/`damage`, but does not check `damageScale`:
		local unitReloadScale = tonumber(unitDef.customParams.veterancy_reload_scale or reloadScale)
		local unitDamageScale = tonumber(unitDef.customParams.veterancy_damage_scale or unitReloadScale)
		if (unitReloadScale or 0) <= 0 and (unitDamageScale or 0) <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.reload.effect, unitReloadScale, unitDamageScale } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]

			local reloads
			if not weaponDef.customParams.noreloadxpscale then
				reloads = {
					reload = weaponDef.reload,
					burst  = weaponDef.salvoSize * weaponDef.salvoDelay,
				}
			end

			local damages
			if not weaponDef.customParams.nodamagexpscale and weaponDef.customParams.bogus ~= "1" then
				damages = table.new(armorTypeMax, 1 - armorTypeMin)
				damages[armorTargetIndex] = armorTypeMin
				local armorDamage = weaponDef.damages[armorTypeMin]
				for i = armorTypeMin, armorTypeMax do
					damages[i] = weaponDef.damages[i]
					if damages[i] > armorDamage then
						damages[armorTargetIndex], armorDamage = i, damages[i]
					end
				end
				if armorDamage <= 0 then
					damages = nil
				end
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
				local burst = upgrade[index].burst
				local reload = upgrade[index].reload
				local weapon = index - 2

				local weaponDamageMult = 1
				if reload > burst then
					local reloadWanted = toFrameTime(reload / reloadDiv)
					if reloadWanted < burst then
						reloadWanted = burst
						-- Get the XP with equal reload time and burst duration.
						local weaponReloadXP = (reload / burst - 1) / upgrade[2]
						local weaponDamageXP = experience - weaponReloadXP
						weaponDamageMult = 1 + upgrade[3] * weaponDamageXP
					end
					spSetUnitWeaponState(unitID, weapon, "reloadTime", reloadWanted)
					callUnitScript(unitID, unitLuaEnv, call.SetReloadTime[weapon], reloadWanted * 1000)
				else
					weaponDamageMult = damageMult
				end
				if weaponDamageMult <= 1 then
					return
				end

				local damages = upgrade[index]
				local armorTarget = damages[armorTargetIndex]
				local armorDamage = spGetUnitWeaponDamages(unitID, weapon, armorTarget)
				if armorDamage == math_round(damages[armorTarget] * weaponDamageMult) then
					return
				end
				local d = damagesTemp
				for i = armorTypeMin, armorTypeMax do
					d[i] = math_round(damages[i] * weaponDamageMult)
				end
				spSetUnitWeaponDamages(unitID, weapon, d)
				spSetUnitRulesParam(unitID, "veterancy_damages_multiplier", weaponDamageMult)
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

	for unitDefID, unitDef in ipairs(UnitDefs) do
		local veterancies
		if type(unitDef.customParams.veterancy_upgrades) == "string" then
			veterancies = unitDef.customParams.veterancy_upgrades:split(", ")
		else
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
