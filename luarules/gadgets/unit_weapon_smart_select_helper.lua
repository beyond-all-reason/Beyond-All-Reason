function gadget:GetInfo()
	return {
		name = "Weapon Smart Select Helper",
		desc = "Prevents auto-target units from blocking manual command fire orders for lower priority weapons.",
		author = "SethDGamre",
		date = "2024.11.16",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

--use customparams.smart_weapon_select_priority to define which weapon number is preferred over the other(s) and enable auto-targetting override.

--static
local frameCheckModulo = Game.gameSpeed
local cmdAttack = CMD.ATTACK
local deferredRetentionFrames = Game.gameSpeed * 7.5

--variables
local gameFrame = 0

--functions
local ggGetUnitTarget = GG.GetUnitTarget
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spCallCOBScript = Spring.CallCOBScript
local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
local spGetUnitCommands = Spring.GetUnitCommands

--tables
local smartUnits = {}
local smartWeaponDefs = {}

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
			Spring.Echo("weaponNumber", weaponNumber, weaponDefID)
			if WeaponDefs[weaponDefID].customParams.smart_preferred_weapon then
				smartWeaponDefs[unitDefID] = {}
				smartWeaponDefs[unitDefID].preferredWeapon = weaponNumber
				Spring.Echo("smart_preferred_weapon", weaponNumber)
			end
			if WeaponDefs[weaponDefID].customParams.smart_deferred_weapon then
				smartWeaponDefs[unitDefID].deferredWeapon = weaponNumber
				Spring.Echo("smart_deferred_weapon", weaponNumber)
			end
			if WeaponDefs[weaponDefID].customParams.smart_trajectory_checker then --this is necessary until Spring.GetUnitWeaponHaveFreeLineOfFire doesn't check cannon trajectory from QueryWeaponX() piece in animation script callin
				smartWeaponDefs[unitDefID].trajectoryCheckerWeapon = weaponNumber
				Spring.Echo("smart_trajectory_checker", weaponNumber)
			end
		end
	end
end

local function weaponTargettingCheck(attackerID, targetData)
	if not targetData then return end
	local defData = smartWeaponDefs[smartUnits[attackerID].unitDefID]
	if #targetData == 1 then --unit target
		local canShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckerWeapon, targetData[1])
		if not canShoot then
			spCallCOBScript(attackerID, smartUnits[attackerID].overrideScriptID, 0, defData.deferredWeapon)
			return false
		elseif canShoot and gameFrame > smartUnits[attackerID].overrideExpirationFrame then -- to prevent the enemy from moving their units in and out of high/low LOS to stop firing due to constant readjustment
			spCallCOBScript(attackerID, smartUnits[attackerID].overrideScriptID, 0, defData.preferredWeapon)
			smartUnits[attackerID].overrideExpirationFrame = gameFrame + deferredRetentionFrames
			return true
		end
	elseif #targetData > 1 then --ground target
		local canShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckerWeapon, _, _, _, targetData[1], targetData[2], targetData[3])
		if not canShoot then
			spCallCOBScript(attackerID, smartUnits[attackerID].overrideScriptID, 0, defData.deferredWeapon)
			return true
		elseif canShoot then
			spCallCOBScript(attackerID, smartUnits[attackerID].overrideScriptID, 0, defData.preferredWeapon)
			return false
		end
	else
		
	end
end


local aggroDecayRate = 0.9
local pAggro = 1
local dAggro = 1.5
local function targetCheck(attackerID)
	local attackerData = smartUnits[attackerID]
	local defData = smartWeaponDefs[attackerData.unitDefID]
    local pTargetType, pIsUserTarget, pTarget = Spring.GetUnitWeaponTarget(attackerID, defData.preferredWeapon)
	local dIsUserTarget = select(2, Spring.GetUnitWeaponTarget(attackerID, defData.deferredWeapon))

	attackerData.aggroBias = attackerData.aggroBias * aggroDecayRate
		
	if pTargetType == 1 then
		local preferredCanShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, defData.trajectoryCheckerWeapon, pTarget)
		Spring.Echo("targetID! isuserTarget:", pIsUserTarget)

		if pIsUserTarget and preferredCanShoot then
			attackerData.aggroBias = attackerData.aggroBias + pAggro

		elseif dIsUserTarget then
			attackerData.aggroBias = attackerData.aggroBias - dAggro

		elseif preferredCanShoot then
			attackerData.aggroBias = attackerData.aggroBias + pAggro

		else
			attackerData.aggroBias = attackerData.aggroBias - dAggro
		end

	elseif pTargetType == 2 then
		Spring.Echo("coordinates! isuserTarget:", pIsUserTarget)
	end

	if attackerData.aggroBias >= 0 then
		spCallCOBScript(attackerID, attackerData.overrideScriptID, 0, defData.preferredWeapon)
	else
		spCallCOBScript(attackerID, attackerData.overrideScriptID, 0, defData.deferredWeapon)
	end
	Spring.Echo("aggroBias", attackerData.aggroBias)
end

-- local function manualCommandIssued(attackerID)
--     local returnTargetTable = {}
--     if spGetUnitCurrentCommand(attackerID) == cmdAttack then
--         local attackTarget = spGetUnitCommands(attackerID, 1)
--         if attackTarget and attackTarget[1] and attackTarget[1].params then
--             returnTargetTable = attackTarget[1].params
--         end
--     end
--     local setTargetData = ggGetUnitTarget(attackerID) or {}
--     if setTargetData then
--         if type(setTargetData) == "number" then
--             returnTargetTable[1] = setTargetData
--             return returnTargetTable
-- 		elseif next(setTargetData) then
--             return setTargetData
--         end
--     end
--     return returnTargetTable
-- end


function gadget:UnitCreated(unitID, unitDefID)
	if smartWeaponDefs[unitDefID] then
		smartUnits[unitID] = {
			unitDefID = unitDefID,
			overrideScriptID = Spring.GetCOBScriptID(unitID, "OverrideAimingState"),
			overrideExpirationFrame = gameFrame,
			aggroBias = 0
		}
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	smartUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % frameCheckModulo == 3 then
		gameFrame = frame
		for attackerID in pairs(smartUnits) do
			local targetData = targetCheck(attackerID)
			--weaponTargettingCheck(attackerID, targetData)
		end
	end
end