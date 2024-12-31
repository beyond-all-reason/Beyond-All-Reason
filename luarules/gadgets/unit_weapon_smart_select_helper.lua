function gadget:GetInfo()
	return {
		name = "Weapon Smart Select",
		desc = "Integrates with smart_weapon_select.h and animation scripts to switch firing modes.",
		author = "SethDGamre",
		date = "2024.12.7",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true
	}
end

--increment this counter for every hour of your life wasted on smart select: 52

if not gadgetHandler:IsSyncedCode() then return end

--[[
Integration Checklist:
1. Weapon def custom params
	smart_priority | <boolean> true for the higher priority smart select weapon.
	smart_backup   | <boolean>= true for the fallback smart select weapon, used when smart_backup cannot shoot a target.
	smart_trajectory_checker | <boolean> true for the weapon that should be used for trajectory checks for the priorityWeapon. Ideally this is a static point slightly lower than preferred_weapon.
3. This requires integration into the unit's animation .bos script to work. Follow the instructions in "smart_weapon_select.h" .bos header.

****OPTIONAL*****
use Weapon def custom param smart_misfire_frames | <number> to override the default reloadtime derivative frames misfire threshold.
This may be necessary if the turret's turn speed is so slow it triggers false misfires.
]]

--static
local frameCheckModulo = Game.gameSpeed
local aggroDecayRate = 0.65 --aggro is multiplied by this until it falls within priority aiming state range
local aggroDecayCap = 10 -- this caps the aggro decay so that misfire state can last a significant amount of time

--misfire occurs when the weapon thinks it can shoot a target due to faulty Spring.GetUnitWeaponHaveFreeLineOfFire return values. We must detect when this failure occurs and force high for a long duration.
local misfireMultiplier = Game.gameSpeed * 1.25
local minimumMisfireFrames = Game.gameSpeed * 4
local misfireTallyDecayRate = 0.99  -- the misfire penalty that makes the misfire state last longer the more cumulative times it happens decays at this rate
local misfireMultiplierAddition = 1 -- every time the misfire happens, it increases by this number. The tally is squared to make each cumulative misfire exponentially more punishing
local backupMisfireAggro = -300 --how much aggro is given multiplied by the misfireTallyMultiplier^2 when priority weapon fails to fire.

local priorityAutoAggro = 12 -- how much aggro is accumulated per frameCheckModulo that the priority weapon successfully aims
local priorityManualAggro = priorityAutoAggro * 4 -- how much aggro is accumulated per frameCheckModulo that the priority weapon successfully aims with a manually assigned target
local prioritySwitchThreshold = -1  --the aggro at which priority weapon switch is triggered. Aggro is decayed closer to 0 every frameCheckModulo

local backupAutoAggro = 4 -- how much aggro is accumulated per frameCheckModulo that the priority weapon fails to aim
local backupManualAggro = priorityAutoAggro * 3 --how much aggro is accumulated per frameCheckModulo that the priority weapon fails to aim with a manually assigned target
local backupSwitchThreshold = -backupAutoAggro * 1.5 --the aggro at which backup weapon switch is triggered. Aggro is decayed closer to 0 every frameCheckModulo

local PRIORITY_AIMINGSTATE = 1
local BACKUP_AIMINGSTATE = 2
local UNIT_TARGET = 1
local GROUND_TARGET = 2
--variables
local gameFrame = 0

--functions
local spCallCOBScript = Spring.CallCOBScript
local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitEstimatedPath = Spring.GetUnitEstimatedPath
local mathMin = math.min
local mathMax = math.max

local smartUnits = {}
local smartUnitDefs = {}

function gadget:Initialize()
	local units = Spring.GetAllUnits()
	local spGetUnitDefID = Spring.GetUnitDefID
	for i = 1, #units do
		gadget:UnitCreated(units[i], spGetUnitDefID(units[i]))
	end
end

for unitDefID, def in ipairs(UnitDefs) do
	if def.weapons then
		local weapons = def.weapons
		for weaponNumber, weaponData in pairs(weapons) do
			local weaponDefID = weapons[weaponNumber].weaponDef
			if WeaponDefs[weaponDefID] and WeaponDefs[weaponDefID].customParams then
				if WeaponDefs[weaponDefID].customParams.smart_priority then
					smartUnitDefs[unitDefID] = smartUnitDefs[unitDefID] or {}
					smartUnitDefs[unitDefID].priorityWeapon = weaponNumber
					smartUnitDefs[unitDefID].failedToFireFrameThreshold = WeaponDefs[weaponDefID].customParams.smart_misfire_frames or
						mathMax(WeaponDefs[weaponDefID].reload * misfireMultiplier, minimumMisfireFrames)
					if def.speed and def.speed ~= 0 then
						smartUnitDefs[unitDefID].canMove = true
					end
				end
				if WeaponDefs[weaponDefID].customParams.smart_backup then
					smartUnitDefs[unitDefID] = smartUnitDefs[unitDefID] or {}
					smartUnitDefs[unitDefID].backupWeapon = weaponNumber
				end
				if WeaponDefs[weaponDefID].customParams.smart_trajectory_checker then
					smartUnitDefs[unitDefID] = smartUnitDefs[unitDefID] or {}
					smartUnitDefs[unitDefID].trajectoryCheckWeapon = weaponNumber
				end
			end
		end
	end
end


function gadget:UnitCreated(unitID, unitDefID)
	if smartUnitDefs[unitDefID] then
		smartUnits[unitID] = {
			unitDefID = unitDefID,
			setStateScriptID = Spring.GetCOBScriptID(unitID, "SetAimingState"),
			aggroBias = 0,
			failedShotFrame = 0,
			misfireTallyMultiplier = 0,
		}
		spCallCOBScript(unitID, smartUnits[unitID].setStateScriptID, 0, smartUnitDefs[unitDefID].priorityWeapon)
	end
end

local function failureToFireCheck(attackerID, data, defData)
	if not data.suspendMisfireUntilFrame then return false end

	if data.failedShotFrame < gameFrame - defData.failedToFireFrameThreshold then
		data.failedShotFrame = mathMax(
			spGetUnitWeaponState(attackerID, defData.priorityWeapon, 'reloadFrame'),
			spGetUnitWeaponState(attackerID, defData.backupWeapon, 'reloadFrame')
		)
	end

	if data.failedShotFrame < gameFrame - defData.failedToFireFrameThreshold and
		gameFrame > data.suspendMisfireUntilFrame then
		return true
	else
		return false
	end
end


local function updateAimingState(attackerID)
	local data = smartUnits[attackerID]
	local defData = smartUnitDefs[data.unitDefID]

	local priorityTargetType, priorityIsUserTarget, priorityTarget = spGetUnitWeaponTarget(attackerID, defData.priorityWeapon)
	local backupIsUserTarget, backupTarget = select(2, spGetUnitWeaponTarget(attackerID, defData.backupWeapon))

	local priorityCanShoot = false
	if priorityTargetType == UNIT_TARGET then
		priorityCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckWeapon, priorityTarget)
	elseif priorityTargetType == GROUND_TARGET then
		priorityCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckWeapon, nil, nil, nil, priorityTarget[1], priorityTarget[2], priorityTarget[3])
	end

	if not data.suspendMisfireUntilFrame and (backupTarget or priorityTarget) then
		data.suspendMisfireUntilFrame = gameFrame + defData.failedToFireFrameThreshold
	elseif not backupTarget and not priorityTarget then
		data.suspendMisfireUntilFrame = nil
	end

	local failureToFire = false
	if defData.canMove then
		if not spGetUnitEstimatedPath(attackerID) then --if it's moving, it'll probably fail to shoot from slow turn speed, or gain LOS from movement
			failureToFire = failureToFireCheck(attackerID, data, defData)
		end
	else
		failureToFire = failureToFireCheck(attackerID, data, defData)
	end

	if priorityIsUserTarget and priorityCanShoot then
		if failureToFire then
			data.misfireTallyMultiplier = data.misfireTallyMultiplier + misfireMultiplierAddition
			data.aggroBias = backupMisfireAggro * data.misfireTallyMultiplier ^ data.misfireTallyMultiplier
		else
			data.aggroBias = data.aggroBias + priorityManualAggro
		end
	elseif backupIsUserTarget then
		data.aggroBias = data.aggroBias - backupManualAggro
	else
		if failureToFire then
			data.misfireTallyMultiplier = data.misfireTallyMultiplier + misfireMultiplierAddition
			data.aggroBias = backupMisfireAggro * data.misfireTallyMultiplier ^ data.misfireTallyMultiplier
			data.suspendMisfireUntilFrame = gameFrame + defData.failedToFireFrameThreshold
		elseif priorityCanShoot then
			data.aggroBias = data.aggroBias + priorityAutoAggro
		elseif backupIsUserTarget ~= nil then
			data.aggroBias = data.aggroBias - backupAutoAggro
		end
	end

	data.misfireTallyMultiplier = data.misfireTallyMultiplier * misfireTallyDecayRate
	if data.aggroBias >= prioritySwitchThreshold then
		data.aggroBias = mathMax(data.aggroBias * aggroDecayRate, data.aggroBias - aggroDecayCap)
		spCallCOBScript(attackerID, data.setStateScriptID, 0, PRIORITY_AIMINGSTATE)
	elseif data.aggroBias < backupSwitchThreshold then
		data.aggroBias = mathMin(data.aggroBias * aggroDecayRate, data.aggroBias + aggroDecayCap)
		spCallCOBScript(attackerID, data.setStateScriptID, 0, BACKUP_AIMINGSTATE)
	else
		data.aggroBias = data.aggroBias * aggroDecayRate
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	smartUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % frameCheckModulo == 3 then
		gameFrame = frame
		for attackerID in pairs(smartUnits) do
			updateAimingState(attackerID)
		end
	end
end
