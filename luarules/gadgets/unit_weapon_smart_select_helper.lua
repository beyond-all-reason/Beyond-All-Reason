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
1. use customparams.smart_preferred_weapon = true for the higher priority smart select weapon.
2. use customparams.smart_deferred_weapon = true for the fallback weapon when smart_preferred_weapon doesn't have a target, or cannot shoot the manually selected target.
3. use customparams.smart_trajectory_checker = true for the weapon that should be used for trajectory checks for the preferredWeapon. Ideally this is a static point slightly lower than preferred_weapon
3. in the unit's .bos animation script, #include "smart_weapon_select.h"  ideally at the beginning of the file.
4. in the preferred AimWeaponX() function, add the following at the beginning:
	if (AimingState != AIMING_PREFERRED){
		return(0);
	}
5. in the deferred AimWeaponX() function, add the following at the beginning:
	if (AimingState != AIMING_DEFERRED){
		return(0);
	}
6. If using a dummy weapon, return (0); in its AimWeaponX() function and QueryWeaponX(piecenum) should be set to static piece lower than the turret.
]]

--static
local frameCheckModulo = Game.gameSpeed
local failedToFireMultiplier = Game.gameSpeed * 1.25
local aggroDecayRate = 0.85
local tallyDecayRate = 0.98
local pManualAggro = 11
local pAutoAggro = 4
local dManualAggro = 9
local dAutoAggro = 3
local dErrorAggro = -1000
local errorRecencyThreshold = Game.gameSpeed * 15
local errorTallyMultiplierCap = 4
local switchDeferredThreshold = -pAutoAggro * 4
local switchPreferredThreshold = -1
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

--tables
local smartUnits = {}
local smartUnitDefWeaponNumbers = {}

function gadget:Initialize()
    local units = Spring.GetAllUnits()
    local spGetUnitDefID = Spring.GetUnitDefID
    for i = 1, #units do
        gadget:UnitCreated(units[i], spGetUnitDefID(units[i]))
    end
end


function gadget:UnitCreated(unitID, unitDefID)
	if smartUnitDefWeaponNumbers[unitDefID] then
		smartUnits[unitID] = {
			unitDefID = unitDefID,
			setStateScriptID = Spring.GetCOBScriptID(unitID, "SetAimingState"),
			aggroBias = 0,
			preferredReloadFrame = 0,
			errorTallyMultiplier = 0,
		}
	end
end


for unitDefID, def in ipairs(UnitDefs) do
	if def.weapons then
		local weapons = def.weapons
		for weaponNumber, weaponData in pairs(weapons) do
			local weaponDefID = weapons[weaponNumber].weaponDef
			if WeaponDefs[weaponDefID] and WeaponDefs[weaponDefID].customParams then
				if WeaponDefs[weaponDefID].customParams.smart_preferred_weapon then
					smartUnitDefWeaponNumbers[unitDefID] = smartUnitDefWeaponNumbers[unitDefID] or {}
					smartUnitDefWeaponNumbers[unitDefID].preferredWeapon = weaponNumber
					smartUnitDefWeaponNumbers[unitDefID].failedToFireFrameThreshold = WeaponDefs[weaponDefID].reload * failedToFireMultiplier
					if def.speed and def.speed ~= 0 then
						smartUnitDefWeaponNumbers[unitDefID].canMove = true
					end
				end
				if WeaponDefs[weaponDefID].customParams.smart_deferred_weapon then
					smartUnitDefWeaponNumbers[unitDefID] = smartUnitDefWeaponNumbers[unitDefID] or {}
					smartUnitDefWeaponNumbers[unitDefID].deferredWeapon = weaponNumber
				end
				if WeaponDefs[weaponDefID].customParams.smart_trajectory_checker then
					smartUnitDefWeaponNumbers[unitDefID] = smartUnitDefWeaponNumbers[unitDefID] or {}
					smartUnitDefWeaponNumbers[unitDefID].trajectoryCheckWeapon = weaponNumber
				end
			end
		end
	end
end


local function failureToFireCheck(attackerID, attackerData, defData)
    if attackerData.preferredReloadFrame < gameFrame - defData.failedToFireFrameThreshold then
        attackerData.preferredReloadFrame = mathMax(
            spGetUnitWeaponState(attackerID, defData.preferredWeapon, 'reloadFrame'),
			spGetUnitWeaponState(attackerID, defData.deferredWeapon, 'reloadFrame')
        )
    end

    if attackerData.preferredReloadFrame < gameFrame - defData.failedToFireFrameThreshold and
	attackerData.preferredReloadFrame > gameFrame - errorRecencyThreshold then --to ensure it isn't just an old reload
		return true
    else
		return false
    end
end


local function updateAimingState(attackerID)
    local attackerData = smartUnits[attackerID]
    local defData = smartUnitDefWeaponNumbers[attackerData.unitDefID]

    local pTargetType, pIsUserTarget, pTarget = spGetUnitWeaponTarget(attackerID, defData.preferredWeapon)
    local dIsUserTarget = select(2, spGetUnitWeaponTarget(attackerID, defData.deferredWeapon))
	
    attackerData.aggroBias = attackerData.aggroBias * aggroDecayRate
	attackerData.errorTallyMultiplier = attackerData.errorTallyMultiplier * tallyDecayRate
    
    local preferredCanShoot = false
    if pTargetType == 1 then
        preferredCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckWeapon, pTarget)
    elseif pTargetType == 2 then
        preferredCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckWeapon, nil, nil, nil, pTarget[1], pTarget[2], pTarget[3])
    end

	local failureToFire = false
	if defData.canMove then
		if not spGetUnitEstimatedPath(attackerID) then
			failureToFire = failureToFireCheck(attackerID, attackerData, defData)
		end
	else
		failureToFire = failureToFireCheck(attackerID, attackerData, defData)
	end

    if pIsUserTarget and preferredCanShoot then
        if failureToFire then
            attackerData.errorTallyMultiplier = mathMin(attackerData.errorTallyMultiplier + 1, errorTallyMultiplierCap)
            attackerData.aggroBias = dErrorAggro * attackerData.errorTallyMultiplier ^ attackerData.errorTallyMultiplier
        else
            attackerData.aggroBias = attackerData.aggroBias + pManualAggro
        end
    elseif dIsUserTarget then
        attackerData.aggroBias = attackerData.aggroBias - dManualAggro
    else
		if failureToFire then
			attackerData.errorTallyMultiplier = mathMin(attackerData.errorTallyMultiplier + 1, errorTallyMultiplierCap)
			attackerData.aggroBias = dErrorAggro * attackerData.errorTallyMultiplier ^ attackerData.errorTallyMultiplier
        elseif preferredCanShoot then
            attackerData.aggroBias = attackerData.aggroBias + pAutoAggro
        elseif dIsUserTarget ~= nil then --deferred has a target
            attackerData.aggroBias = attackerData.aggroBias - dAutoAggro
        end
    end

    if attackerData.aggroBias >= switchPreferredThreshold then
		spCallCOBScript(attackerID, attackerData.setStateScriptID, 0, defData.preferredWeapon)
	elseif attackerData.aggroBias < switchDeferredThreshold then
		spCallCOBScript(attackerID, attackerData.setStateScriptID, 0, defData.deferredWeapon)
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