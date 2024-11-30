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
local unitSuspendAutoAiming = {}
local unitDefsWithSmartWeapons = {}

for unitDefID, def in ipairs(UnitDefs) do
	if def.customParams.smart_weapon_select_priority then
		unitDefsWithSmartWeapons[unitDefID] = {preferredWeapon = tonumber(def.customParams.smart_weapon_select_priority)}
		for weaponNumber, weaponData in ipairs(def.weapons) do
			if weaponNumber ~= unitDefsWithSmartWeapons[unitDefID].preferredWeapon then
				unitDefsWithSmartWeapons[unitDefID].deferredWeapon = tonumber(weaponNumber)
			end
		end
	end
end

local function weaponTargettingCheck(attackerID, targetData)
	if not attackerID or not targetData then return end
	if #targetData == 1 then --unit target
		local canShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, unitSuspendAutoAiming[attackerID].preferredWeapon, targetData[1])
		if not canShoot then
			spCallCOBScript(attackerID, unitSuspendAutoAiming[attackerID].overrideScriptID, 0, unitSuspendAutoAiming[attackerID].deferredWeapon)
			return false
		elseif canShoot and gameFrame > unitSuspendAutoAiming[attackerID].overrideExpirationFrame then
			spCallCOBScript(attackerID, unitSuspendAutoAiming[attackerID].overrideScriptID, 0, unitSuspendAutoAiming[attackerID].preferredWeapon)
			unitSuspendAutoAiming[attackerID].overrideExpirationFrame = gameFrame + deferredRetentionFrames
			return true
		end
	elseif #targetData > 1 then --ground target
		local canShoot = spGetUnitWeaponHaveFreeLineOfFire(attackerID, unitSuspendAutoAiming[attackerID].preferredWeapon, _, _, _, targetData[1], targetData[2], targetData[3])
		if not canShoot then
			spCallCOBScript(attackerID, unitSuspendAutoAiming[attackerID].overrideScriptID, 0, unitSuspendAutoAiming[attackerID].deferredWeapon)
			return true
		elseif canShoot then
			spCallCOBScript(attackerID, unitSuspendAutoAiming[attackerID].overrideScriptID, 0, unitSuspendAutoAiming[attackerID].preferredWeapon)
			return false
		end
	end
end

local function manualCommandIssued(attackerID)
    local returnTargetTable = {}
    if spGetUnitCurrentCommand(attackerID) == cmdAttack then
        local attackTarget = spGetUnitCommands(attackerID, 1)
        if attackTarget and attackTarget[1] and attackTarget[1].params then
            returnTargetTable = attackTarget[1].params
        end
    end
    local setTargetData = ggGetUnitTarget(attackerID) or {}
    if setTargetData then
        if type(setTargetData) == "number" then
            returnTargetTable[1] = setTargetData
            return returnTargetTable
		elseif next(setTargetData) then
            return setTargetData
        end
    end
    return returnTargetTable
end


function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitDefsWithSmartWeapons[unitDefID] then
		unitSuspendAutoAiming[unitID] = {
			unitDefID = unitDefID,
			preferredWeapon = unitDefsWithSmartWeapons[unitDefID].preferredWeapon,
			deferredWeapon = unitDefsWithSmartWeapons[unitDefID].deferredWeapon,
			overrideScriptID = Spring.GetCOBScriptID(unitID, "OverrideAimingState"),
			overrideExpirationFrame = gameFrame
		}
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	unitSuspendAutoAiming[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % frameCheckModulo == 3 then
		gameFrame = frame
		for attackerID in pairs(unitSuspendAutoAiming) do
			local targetData = manualCommandIssued(attackerID)
			weaponTargettingCheck(attackerID, targetData)
		end
	end
end