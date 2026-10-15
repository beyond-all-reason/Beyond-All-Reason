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

local MAX_SLOW_FACTOR = 0.9
local UPDATE_FRAMES = math.round(0.5 * Game.gameSpeed, 0)

local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local spValidUnitID = Spring.ValidUnitID
local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitRulesParam = Spring.SetUnitRulesParam

local LOS_ACCESS = { inlos = true }

local SLOW_BRAKE_BOOST = 1000 -- so a unit decelerates into its new max speed instead of coasting
local SLOW_STEP = 1 / 64 -- quantize so an undecayed slow rewrites identical factors
local SLOW_STEP_INV = 64
local SLOW_RELOAD_RATE_MIN = 0.01

local SOURCE = "timeslow"
Spring.SetGameRulesParam(SOURCE, 1)

local slowedUnits = {}

local function removeUnit(unitID)
	slowedUnits[unitID] = nil
end

local function applySlow(unitID, percent)
	local setUnitModifier = GG.UnitAttributes.SetUnitModifier
	local setUnitWeaponModifier = GG.UnitAttributes.SetUnitWeaponModifier

	if percent <= 0.0 then
		setUnitModifier(unitID, "speed", nil, SOURCE)
		setUnitModifier(unitID, "turnRate", nil, SOURCE)
		setUnitModifier(unitID, "maxAcc", nil, SOURCE)
		setUnitModifier(unitID, "maxDec", nil, SOURCE)
		setUnitModifier(unitID, "buildSpeed", nil, SOURCE)
		setUnitWeaponModifier(unitID, nil, "reloadTime", nil, SOURCE)
		return
	end

	local moveFactor = 1.0 - math_min(percent, MAX_SLOW_FACTOR)
	setUnitModifier(unitID, "speed", moveFactor, SOURCE)
	setUnitModifier(unitID, "turnRate", moveFactor, SOURCE)
	setUnitModifier(unitID, "maxAcc", moveFactor, SOURCE)
	setUnitModifier(unitID, "maxDec", SLOW_BRAKE_BOOST, SOURCE)
	setUnitModifier(unitID, "buildSpeed", moveFactor, SOURCE)

	local reloadTime = 1 / math_max(1.0 - percent * 2.0, SLOW_RELOAD_RATE_MIN)
	setUnitWeaponModifier(unitID, nil, "reloadTime", reloadTime, SOURCE)
end

local function updateSlow(unitID)
	local health, maxHealth, paralyzeDamage = spGetUnitHealth(unitID)
	if not health then
		return
	end

	if paralyzeDamage < 5 then
		applySlow(unitID, 0.0)
		spSetUnitRulesParam(unitID, SOURCE, nil, LOS_ACCESS)
		return true
	end

	local maxSlow = health * MAX_SLOW_FACTOR
	if paralyzeDamage > maxSlow then
		paralyzeDamage = maxSlow
	end

	local percentSlow = paralyzeDamage / maxHealth
	percentSlow = math_floor(percentSlow * SLOW_STEP_INV + 0.5) * SLOW_STEP

	spSetUnitRulesParam(unitID, SOURCE, percentSlow, LOS_ACCESS)
	applySlow(unitID, percentSlow)
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
	if weaponID and paralyzer and spValidUnitID(unitID) then
		slowedUnits[unitID] = true
		updateSlow(unitID)
	end
end

function gadget:GameFrame(f)
	if (f - 1) % UPDATE_FRAMES == 0 then
		for unitID in pairs(slowedUnits) do
			if updateSlow(unitID) then
				removeUnit(unitID)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	removeUnit(unitID)
end

function gadget:Initialize()
	slowedUnits = {}
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local _, _, paralyzeDamage = spGetUnitHealth(unitID)
		if paralyzeDamage >= 5 then
			slowedUnits[unitID] = true
			updateSlow(unitID)
		end
	end
end
