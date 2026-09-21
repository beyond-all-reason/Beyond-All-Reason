if not Spring.GetModOptions().emprework then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Slowing",
		desc = "Unit movement and firerate slowing effects, used by EMP Rework",
		author = "Google Frog , (MidKnight made orig)",
		date = "2010-05-31",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local spValidUnitID = Spring.ValidUnitID
local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitRulesParam = Spring.SetUnitRulesParam

local LOS_ACCESS = { inlos = true }

local SLOW_MOVE_MAX = 0.9
local SLOW_BRAKE_BOOST = 1000 -- so a unit decelerates into its new max speed instead of coasting
local SLOW_STEP = 1 / 64 -- quantize so an undecayed slow rewrites identical factors
local SLOW_STEP_INV = 64
local SLOW_RELOAD_RATE_MIN = 0.01
local ATTRIBUTE_SOURCE = "timeslow"

local _, MAX_SLOW_FACTOR, DEGRADE_TIMER, _, UPDATE_PERIOD = include("LuaRules/Configs/timeslow_defs.lua")
local slowedUnits = {}

Spring.SetGameRulesParam("slowState", 1)

local function applySlow(unitID, percent)
	local setUnitModifier = GG.UnitAttributes.SetUnitModifier

	if percent <= 0.0 then
		setUnitModifier(unitID, "speed", nil, ATTRIBUTE_SOURCE)
		setUnitModifier(unitID, "turnRate", nil, ATTRIBUTE_SOURCE)
		setUnitModifier(unitID, "maxAcc", nil, ATTRIBUTE_SOURCE)
		setUnitModifier(unitID, "maxDec", nil, ATTRIBUTE_SOURCE)
		setUnitModifier(unitID, "buildSpeed", nil, ATTRIBUTE_SOURCE)
		setUnitModifier(unitID, "reloadTime", nil, ATTRIBUTE_SOURCE)
		return
	end

	local moveFactor = 1.0 - math_min(percent, SLOW_MOVE_MAX)
	setUnitModifier(unitID, "speed", moveFactor, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "turnRate", moveFactor, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "maxAcc", moveFactor, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "maxDec", SLOW_BRAKE_BOOST, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "buildSpeed", moveFactor, ATTRIBUTE_SOURCE)

	local reloadTime = 1 / math_max(1 - percent * 2, SLOW_RELOAD_RATE_MIN)
	setUnitModifier(unitID, "reloadTime", reloadTime, ATTRIBUTE_SOURCE)
end

local function updateSlow(unitID, state)
	local health, maxHealth, paralyzeDamage, capture, build = spGetUnitHealth(unitID)
	if health then
		local maxSlow = health * (MAX_SLOW_FACTOR + (state.extraSlowBound or 0))
		if paralyzeDamage > maxSlow then
			paralyzeDamage = maxSlow
		end

		local percentSlow = paralyzeDamage / maxHealth
		percentSlow = math_floor(percentSlow * SLOW_STEP_INV + 0.5) * SLOW_STEP
		if paralyzeDamage < 5 then
			percentSlow = 0
		end

		spSetUnitRulesParam(unitID, "slowState", percentSlow, LOS_ACCESS)
		applySlow(unitID, percentSlow)
	end
end

function gadget:UnitPreDamaged(
	unitID,
	unitDefID,
	unitTeam,
	damage,
	paralyzer,
	weaponID,
	attackerID,
	attackerDefID,
	attackerTeam
)
	if not weaponID or not paralyzer or not spValidUnitID(unitID) then
		return
	else
		if not slowedUnits[unitID] then
			slowedUnits[unitID] = {
				slowDamage = damage,
				degradeTimer = DEGRADE_TIMER,
			}
		else
			slowedUnits[unitID].slowDamage = slowedUnits[unitID].slowDamage + damage
			slowedUnits[unitID].degradeTimer = DEGRADE_TIMER
		end
		updateSlow(unitID, slowedUnits[unitID])
	end
end

local function removeUnit(unitID)
	slowedUnits[unitID] = nil
end

function gadget:GameFrame(f)
	if (f - 1) % UPDATE_PERIOD == 0 then
		for unitID, state in pairs(slowedUnits) do
			if state.degradeTimer <= 0 then
				--local health = spGetUnitHealth(unitID) or 0
				--state.slowDamage = state.slowDamage - health*DEGRADE_FACTOR
			else
				state.degradeTimer = state.degradeTimer - 1
			end

			local _, _, paralyzeDamage = spGetUnitHealth(unitID)
			if paralyzeDamage < 5 then
				updateSlow(unitID, state)
				removeUnit(unitID)
			else
				updateSlow(unitID, state)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	removeUnit(unitID)
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local _, _, paralyzeDamage = spGetUnitHealth(unitID)
		if paralyzeDamage >= 5 then
			slowedUnits[unitID] = {
				slowDamage = paralyzeDamage,
				degradeTimer = DEGRADE_TIMER,
			}
			updateSlow(unitID, slowedUnits[unitID])
		end
	end
end
