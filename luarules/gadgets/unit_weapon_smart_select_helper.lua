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
1. use weapondef.customparams.smart_priority = true for the higher priority smart select weapon.
2. use weapondef.customparams.smart_backup = true for the fallback weapon when smart_backup doesn't have a target, or cannot shoot the manually selected target.
3. use weapondef.customparams.smart_trajectory_checker = true for the weapon that should be used for trajectory checks for the priorityWeapon. Ideally this is a static point slightly lower than preferred_weapon
3. in the unit's .bos animation script, #include "smart_weapon_select.h"  ideally at the beginning of the file.
4. in the preferred AimWeaponX() function, add the following at the beginning:
	if (AimingState != AIMING_PRIORITY){
		return(0);
	}
5. in the deferred AimWeaponX() function, add the following at the beginning:
	if (AimingState != AIMING_BACKUP){
		return(0);
	}
6. If using a dummy weapon, return (0); in its AimWeaponX() function and QueryWeaponX(piecenum) should be set to static piece lower than the turret.

****OPTIONAL*****
use weapondef.customparams.smart_error_frames to override the default reloadtime derivitive frames error threshold
]]

--static
local frameCheckModulo = Game.gameSpeed
local failedToFireMultiplier = Game.gameSpeed * 1.25
local minimumFailedToFireFrames = Game.gameSpeed * 4
local aggroDecayRate = 0.65 --aggro is multiplied by this until it falls within priority aiming state range
local aggroDecayCap = 10 -- this caps the aggro decay so that error state can last a significant amount of time
local errorTallyDecayRate = 0.99  -- the error penalty that makes the error state last longer the more cumulative times it happens decays at this rate
local errorMultiplierAddition = 1 -- every time the error happens, it increases by this number. The tally is squared to make each cumulative error exponentially more punishing
local PRIORITY_AIMINGSTATE = 1
local BACKUP_AIMINGSTATE = 2

local priorityAutoAggro = 12 -- how much aggro is accumulated per frameCheckModulo that the priority weapon successfully aims
local priorityManualAggro = priorityAutoAggro * 4 -- how much aggro is accumulated per frameCheckModulo that the priority weapon successfully aims with a manually assigned target
local prioritySwitchThreshold = -1  --the aggro at which priority weapon switch is triggered. Aggro is decayed closer to 0 every frameCheckModulo

local backupAutoAggro = 4 -- how much aggro is accumulated per frameCheckModulo that the priority weapon fails to aim
local backupManualAggro = priorityAutoAggro * 3 --how much aggro is accumulated per frameCheckModulo that the priority weapon fails to aim with a manually assigned target
local backupErrorAggro = -300 --how much aggro is given multiplied by the errorTallyMultiplier^2 when priority weapon fails to fire.
local backupSwitchThreshold = -backupAutoAggro * 1.5 --the aggro at which backup weapon switch is triggered. Aggro is decayed closer to 0 every frameCheckModulo

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
local unitDefData = {}

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
					unitDefData[unitDefID] = unitDefData[unitDefID] or {}
					unitDefData[unitDefID].priorityWeapon = weaponNumber
					unitDefData[unitDefID].failedToFireFrameThreshold = WeaponDefs[weaponDefID].customParams.smart_error_frames or
						mathMax(WeaponDefs[weaponDefID].reload * failedToFireMultiplier, minimumFailedToFireFrames)
					if def.speed and def.speed ~= 0 then
						unitDefData[unitDefID].canMove = true
					end
				end
				if WeaponDefs[weaponDefID].customParams.smart_backup then
					unitDefData[unitDefID] = unitDefData[unitDefID] or {}
					unitDefData[unitDefID].backupWeapon = weaponNumber
				end
				if WeaponDefs[weaponDefID].customParams.smart_trajectory_checker then
					unitDefData[unitDefID] = unitDefData[unitDefID] or {}
					unitDefData[unitDefID].trajectoryCheckWeapon = weaponNumber
				end
			end
		end
	end
end


function gadget:UnitCreated(unitID, unitDefID)
	if unitDefData[unitDefID] then
		smartUnits[unitID] = {
			unitDefID = unitDefID,
			setStateScriptID = Spring.GetCOBScriptID(unitID, "SetAimingState"),
			aggroBias = 0,
			failedShotFrame = 0,
			errorTallyMultiplier = 0,
		}
		spCallCOBScript(unitID, smartUnits[unitID].setStateScriptID, 0, unitDefData[unitDefID].priorityWeapon)
	end
end

local function failureToFireCheck(attackerID, data, defData)
	if not data.suspendErrorUntilFrame then return false end

	if data.failedShotFrame < gameFrame - defData.failedToFireFrameThreshold then
		data.failedShotFrame = mathMax(
			spGetUnitWeaponState(attackerID, defData.priorityWeapon, 'reloadFrame'),
			spGetUnitWeaponState(attackerID, defData.backupWeapon, 'reloadFrame')
		)
	end

	if data.failedShotFrame < gameFrame - defData.failedToFireFrameThreshold and
		gameFrame > data.suspendErrorUntilFrame then
		return true
	else
		return false
	end
end


local function updateAimingState(attackerID)
	local data = smartUnits[attackerID]
	local defData = unitDefData[data.unitDefID]

	local priorityTargetType, priorityIsUserTarget, priorityTarget = spGetUnitWeaponTarget(attackerID, defData.priorityWeapon)
	local backupIsUserTarget, backupTarget = select(2, spGetUnitWeaponTarget(attackerID, defData.backupWeapon))

	local preferredCanShoot = false
	if priorityTargetType == PRIORITY_AIMINGSTATE then
		preferredCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckWeapon, priorityTarget)
	elseif priorityTargetType == BACKUP_AIMINGSTATE then
		preferredCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckWeapon, nil, nil, nil,
			priorityTarget[1], priorityTarget[2], priorityTarget[3])
	end

	if not data.suspendErrorUntilFrame and (backupTarget or priorityTarget) then
		data.suspendErrorUntilFrame = gameFrame + defData.failedToFireFrameThreshold
	elseif not backupTarget and not priorityTarget then
		data.suspendErrorUntilFrame = nil
	end

	local failureToFire = false
	if defData.canMove then
		if not spGetUnitEstimatedPath(attackerID) then --if it's moving, it'll probably fail to shoot from slow turn speed, or gain LOS from movement
			failureToFire = failureToFireCheck(attackerID, data, defData)
		end
	else
		failureToFire = failureToFireCheck(attackerID, data, defData)
	end

	if priorityIsUserTarget and preferredCanShoot then
		if failureToFire then
			data.errorTallyMultiplier = data.errorTallyMultiplier + errorMultiplierAddition
			data.aggroBias = backupErrorAggro * data.errorTallyMultiplier ^ data.errorTallyMultiplier
		else
			data.aggroBias = data.aggroBias + priorityManualAggro
		end
	elseif backupIsUserTarget then
		data.aggroBias = data.aggroBias - backupManualAggro
	else
		if failureToFire then
			data.errorTallyMultiplier = data.errorTallyMultiplier + errorMultiplierAddition
			data.aggroBias = backupErrorAggro * data.errorTallyMultiplier ^ data.errorTallyMultiplier
			data.suspendErrorUntilFrame = gameFrame + defData.failedToFireFrameThreshold
		elseif preferredCanShoot then
			data.aggroBias = data.aggroBias + priorityAutoAggro
		elseif backupIsUserTarget ~= nil then
			data.aggroBias = data.aggroBias - backupAutoAggro
		end
	end

	data.errorTallyMultiplier = data.errorTallyMultiplier * errorTallyDecayRate
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
