local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Weapon Smart Select",
		desc = "Integrates with smart_weapon_select.h and animation scripts to switch firing modes.",
		author = "SethDGamre",
		date = "2024.12.7",
		license = "GNU GPL, v2 or later",
		layer = 1, --must layer after unit_set_target_by_type.lua
		enabled = true
	}
end

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
local frameCheckModulo = Game.gameSpeed -- once per second is sufficient
local aggroDecayRate = 0.7 --aggro is multiplied by this until it falls within priority aiming state range
local aggroDecayCap = 10  -- this caps the aggro decay so that misfire state can last a significant amount of time
local aggroPriorityCap = 1 --The maximum aggro that can be accumulated. This prevents manual targetting from getting stuck in a fire mode for too long.
local aggroBackupCap = -16 --Like above, but a negative value because backup is triggered with negative aggro.
local gameSpeed = Game.gameSpeed

--misfire occurs when the weapon thinks it can shoot a target due to faulty Spring.GetUnitWeaponHaveFreeLineOfFire return values. We must detect when this failure occurs and force high for a long duration.
local misfireMultiplier = Game.gameSpeed * 1.5
local minimumMisfireFrames = Game.gameSpeed * 7
local misfireTallyDecayRate = 0.985 -- the misfire penalty that makes the misfire state last longer the more cumulative times it happens decays at this rate
local misfireMultiplierAddition = 1 -- every time the misfire happens, it increases by this number. The tally is squared to make each cumulative misfire exponentially more punishing
local minMisfireTally = 2 -- This is used to prevent misfire from being super punishing the first few times it triggers.
local backupMisfireAggro = -200 --how much aggro is given multiplied by the misfireTallyMultiplier^2 when priority weapon fails to fire.

local priorityAutoAggro = 12 -- how much aggro is accumulated per frameCheckModulo that the priority weapon successfully aims
local priorityManualAggro = 24 -- how much aggro is accumulated per frameCheckModulo that the priority weapon successfully aims with a manually assigned target
local prioritySwitchThreshold = -5 --the aggro at which priority weapon switch is triggered. Aggro is decayed closer to 0 every frameCheckModulo

local backupAutoAggro = 8 -- how much aggro is accumulated per frameCheckModulo that the priority weapon fails to aim
local backupManualAggro = 16 --how much aggro is accumulated per frameCheckModulo that the priority weapon fails to aim with a manually assigned target
local backupSwitchThreshold = backupAutoAggro * 1.2 * -1 --the aggro at which backup weapon switch is triggered. Aggro is decayed closer to 0 every frameCheckModulo

local priorityCooldownFrames = Game.gameSpeed * 1.5 -- so that no matter how the aggro weights are set, the mode switches will happen no sooner than this.
local backupCooldownFrames = Game.gameSpeed * 4

local PRIORITY_AIMINGSTATE = 0
local BACKUP_AIMINGSTATE = 1
local AUTO_TOGGLESTATE = 2
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
local spSetUnitTarget = Spring.SetUnitTarget
local mathMin = math.min
local mathMax = math.max

local smartUnits = {}
local smartUnitDefs = {}
local modeSwitchFrames = {}

-- Add with other local function declarations
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc

include("luarules/configs/customcmds.h.lua")

local trajectoryCmdDesc = {
    id = CMD_SMART_TOGGLE,
    type = CMDTYPE.ICON_MODE,
    tooltip = 'trajectory_tooltip',
    name = 'trajectory_toggle',
    cursor = 'cursornormal',
    action = 'trajectory_toggle',
    params = { AUTO_TOGGLESTATE, "trajectory_low", "trajectory_high", "trajectory_auto" },
}
local defaultCmdDesc = trajectoryCmdDesc

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_SMART_TOGGLE)
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
					smartUnitDefs[unitDefID].failedToFireFrameThreshold = WeaponDefs[weaponDefID].customParams.smart_misfire_frames or mathMax(WeaponDefs[weaponDefID].reload * misfireMultiplier, minimumMisfireFrames)
					smartUnitDefs[unitDefID].reloadFrames = math.floor(WeaponDefs[weaponDefID].reload * Game.gameSpeed)
					if def.speed and def.speed ~= 0 then
						smartUnitDefs[unitDefID].canMove = true
					end
					if def.customParams and def.customParams.smart_weapon_cmddesc then
						if def.customParams.smart_weapon_cmddesc == "trajectory" then
							smartUnitDefs[unitDefID].smartCmdDesc = trajectoryCmdDesc
						end
					else
						smartUnitDefs[unitDefID].smartCmdDesc = defaultCmdDesc
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

local function updatePredictedShotFrame(attackerID, unitData, defData)
	if unitData.predictedShotFrame < gameFrame - defData.failedToFireFrameThreshold then
		unitData.predictedShotFrame = mathMax(
			spGetUnitWeaponState(attackerID, defData.priorityWeapon, 'reloadFrame'),
			spGetUnitWeaponState(attackerID, defData.backupWeapon, 'reloadFrame')
		)
	end
end

local function failureToFireCheck(attackerID, data, defData)
	if not data.suspendMisfireUntilFrame or data.aggroBias < prioritySwitchThreshold then return false end

	updatePredictedShotFrame(attackerID, data, defData)

	if data.predictedShotFrame < gameFrame - defData.failedToFireFrameThreshold and
		gameFrame > data.suspendMisfireUntilFrame then
		return true
	else
		return false
	end
end

local function handleMisfire(data, defData)
	data.misfireTallyMultiplier = data.misfireTallyMultiplier + misfireMultiplierAddition

	if data.misfireTallyMultiplier < minMisfireTally then
		data.aggroBias = aggroBackupCap
	else
		data.aggroBias = backupMisfireAggro * data.misfireTallyMultiplier ^ data.misfireTallyMultiplier
	end

	data.suspendMisfireUntilFrame = gameFrame + defData.failedToFireFrameThreshold
end

--switch the fire mode in the middle of the next reloadtime when available to both make transitions at the ideal time
--and completely eliminate indecisive wobbling
local function queueSwitchFrame(attackerID, data, defData, setState)
	if data.state ~= setState and data.switchCooldownFrame < gameFrame then
		local idealSubtraction = defData.reloadFrames * 0.75 -- so the switch occurs soon after a shot
		local idealAddition = defData.reloadFrames - idealSubtraction
		local maxSubtraction = gameSpeed * 2 -- so that very slow reloading units don't refuse to switch within too large of a time frame
		local idealFrame
		
		updatePredictedShotFrame(attackerID, data, defData)

		if data.predictedShotFrame < gameFrame then
			-- we're so far past the last reloadtime, weapon is either stuck or otherwise can't fire
			spCallCOBScript(attackerID, data.setStateScriptID, 0, setState)
		else
			-- is now just before the ideal frame to switch on?
			local tooCloseToFiringToSwitchFrame = mathMax(data.predictedShotFrame - idealSubtraction, data.predictedShotFrame - maxSubtraction)
			if tooCloseToFiringToSwitchFrame <= gameFrame then
				-- remaining possibility, queue switch for after next predicted shot
				idealFrame = math.floor(data.predictedShotFrame + idealAddition)
				modeSwitchFrames[idealFrame] = modeSwitchFrames[idealFrame] or {}
				modeSwitchFrames[idealFrame][attackerID] = setState
			else
				spCallCOBScript(attackerID, data.setStateScriptID, 0, setState)
			end

		end
		
		data.state = setState
		if data.state == PRIORITY_AIMINGSTATE then
			data.switchCooldownFrame = gameFrame + priorityCooldownFrames
		else
			data.switchCooldownFrame = gameFrame + backupCooldownFrames
		end
	end
end

local function updateAimingState(attackerID)
	if smartUnits[attackerID].toggleState ~= AUTO_TOGGLESTATE then
		return
	end
	local data = smartUnits[attackerID]
	local defData = smartUnitDefs[data.unitDefID]

	-- Get target information for the priority and backup weapons
	local priorityTargetType, priorityIsUserTarget, priorityTarget = spGetUnitWeaponTarget(attackerID, defData.priorityWeapon)
	local backupIsUserTarget, backupTarget = select(2, spGetUnitWeaponTarget(attackerID, defData.backupWeapon))

	-- Determine if the priority weapon can shoot the target
	local priorityCanShoot = false
	--we store some aspect of the target number to see if it matches last check's target. Used to reset a misfire condition.
	local newMatchTargetNumber = 0 --the engine equivalent of nil is 0 here.

	if priorityTargetType == UNIT_TARGET then
		priorityCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckWeapon, priorityTarget)
		newMatchTargetNumber = priorityTarget
		spSetUnitTarget(attackerID, priorityTarget, false, priorityIsUserTarget, defData.backupWeapon)
	elseif priorityTargetType == GROUND_TARGET then
		priorityCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckWeapon, nil, nil, nil, priorityTarget[1], priorityTarget[2], priorityTarget[3])
		newMatchTargetNumber = priorityTarget[1]
		spSetUnitTarget(attackerID, priorityTarget[1], priorityTarget[2], priorityTarget[3], false, priorityIsUserTarget, defData.backupWeapon)
	end

	-- prevent misfire from triggering when a target is first acquired from idle state
	if backupTarget or priorityTarget then
		if data.suspendMisfireUntilFrame and newMatchTargetNumber ~= 0 and newMatchTargetNumber ~= data.lastTargetMatchNumber then
			data.lastTargetMatchNumber = newMatchTargetNumber
			data.suspendMisfireUntilFrame = gameFrame + defData.failedToFireFrameThreshold
		elseif not data.suspendMisfireUntilFrame then
			data.suspendMisfireUntilFrame = gameFrame + defData.failedToFireFrameThreshold
		end
	elseif not backupTarget and not priorityTarget then
		data.suspendMisfireUntilFrame = nil
	end

	-- check if priority weapon is stuck trying to aim but failing to fire when it should
	local failureToFire = false
	if defData.canMove then
		if not spGetUnitEstimatedPath(attackerID) then -- If it's moving, it might fail to shoot or gain LOS from movement
			failureToFire = failureToFireCheck(attackerID, data, defData)
		end
	else
		failureToFire = failureToFireCheck(attackerID, data, defData)
	end

	-- add or subtract aggro based on weapon targetting conditions
	if priorityIsUserTarget and priorityCanShoot then
		if failureToFire then
			handleMisfire(data, defData)
		else
			if data.aggroBias < aggroBackupCap then --if a misfire happened and a manual command is issued, we want to ensure it isn't stuck in backup mode.
				data.aggroBias = aggroBackupCap
			else
				data.aggroBias = mathMin(data.aggroBias + priorityManualAggro, aggroPriorityCap)
			end
		end
	elseif backupIsUserTarget then
		data.aggroBias = mathMax(data.aggroBias - backupManualAggro, aggroBackupCap)
	else
		if failureToFire then
			handleMisfire(data, defData)
		elseif priorityCanShoot then
			data.aggroBias = mathMin(data.aggroBias + priorityAutoAggro, aggroPriorityCap)
		elseif backupIsUserTarget ~= nil and data.aggroBias > aggroBackupCap then
			data.aggroBias = mathMax(data.aggroBias - backupAutoAggro, aggroBackupCap)
		end
	end

	-- Switch aiming state based on aggro bias thresholds
	if data.aggroBias >= prioritySwitchThreshold then
		data.aggroBias = mathMax(data.aggroBias * aggroDecayRate, data.aggroBias - aggroDecayCap)
		queueSwitchFrame(attackerID, data, defData, PRIORITY_AIMINGSTATE)
	elseif data.aggroBias < backupSwitchThreshold then
		data.aggroBias = mathMin(data.aggroBias * aggroDecayRate, data.aggroBias + aggroDecayCap)
		queueSwitchFrame(attackerID, data, defData, BACKUP_AIMINGSTATE)
	else
		data.aggroBias = data.aggroBias * aggroDecayRate
	end

	-- Decay misfire tally multiplier, so that if the conditions change that caused the misfire it can revert to a normal state over time.
	data.misfireTallyMultiplier = data.misfireTallyMultiplier * misfireTallyDecayRate
end

local function toggleTrajectory(unitID, state)
    local cmdDescID = spFindUnitCmdDesc(unitID, CMD_SMART_TOGGLE)
    if cmdDescID then
		local unitData = smartUnits[unitID]
        state = (state % 3)
        trajectoryCmdDesc.params[1] = state
        spEditUnitCmdDesc(unitID, cmdDescID, {params = trajectoryCmdDesc.params})
		unitData.toggleState = state
		unitData.state = state
		if state ~= AUTO_TOGGLESTATE then
			spCallCOBScript(unitID, smartUnits[unitID].setStateScriptID, 0, state)
		end
    end
end

function gadget:UnitCreated(unitID, unitDefID)
	if smartUnitDefs[unitDefID] then
		local scriptID = Spring.GetCOBScriptID(unitID, "SetAimingState")
		if scriptID then
			smartUnits[unitID] = {
				unitDefID = unitDefID,
				setStateScriptID = scriptID,
				aggroBias = 0,
				predictedShotFrame = 0,
				misfireTallyMultiplier = 0,
				lastTargetMatchNumber = 0, --this exists so that a player switching targets frequently doesn't trigger a faulty misfire.
				switchCooldownFrame = 0,
				state = PRIORITY_AIMINGSTATE,
				toggleState = AUTO_TOGGLESTATE
			}
			spCallCOBScript(unitID, smartUnits[unitID].setStateScriptID, 0, PRIORITY_AIMINGSTATE)
			
			smartUnitDefs[unitDefID].smartCmdDesc.params[1] = AUTO_TOGGLESTATE
			spInsertUnitCmdDesc(unitID, smartUnitDefs[unitDefID].smartCmdDesc)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	smartUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % frameCheckModulo == 3 then
		gameFrame = frame
		for attackerID in pairs(smartUnits) do
			updateAimingState(attackerID)
		end
	end 
	local switchModeQueue = modeSwitchFrames[frame]
	if switchModeQueue then
		for unitID, setState in pairs(switchModeQueue) do
			local data = smartUnits[unitID]
			if data then
				spCallCOBScript(unitID, data.setStateScriptID, 0, setState)
			end
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if smartUnitDefs[unitDefID] and cmdID == CMD_SMART_TOGGLE then
        toggleTrajectory(unitID, cmdParams[1])
        return false  -- command was used
    end
    return true  -- command was not used
end
