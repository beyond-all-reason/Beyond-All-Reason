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
				unitDefsWithSmartWeapons[unitDefID].otherWeapon = tonumber(weaponNumber)
			end
			Script.SetWatchWeapon(weaponData.weaponDef, true)
		end
	end
end

local function weaponTargettingCheck(attackerID, targetData)
	if type(targetData) == "number" then
	end
	if not attackerID or not targetData then return false end
	if #targetData == 1 then
		if not spGetUnitWeaponHaveFreeLineOfFire(attackerID, unitSuspendAutoAiming[attackerID].preferredWeapon, targetData[1]) then
			spCallCOBScript ( attackerID, unitSuspendAutoAiming[attackerID].overrideScriptID, 0, unitSuspendAutoAiming[attackerID].otherWeapon)
			return false
		end
	elseif #targetData > 1 then
		if not spGetUnitWeaponHaveFreeLineOfFire(attackerID, unitSuspendAutoAiming[attackerID].preferredWeapon, targetData[1], targetData[2], targetData[3]) then
			spCallCOBScript ( attackerID, unitSuspendAutoAiming[attackerID].overrideScriptID, 0, unitSuspendAutoAiming[attackerID].otherWeapon)
			return true
		else
			return false
		end
	end
end

local function manualCommandIssued(attackerID)
	local returnTargetTable = {}
	if spGetUnitCurrentCommand(attackerID) == cmdAttack then
		local attackTarget = spGetUnitCommands(attackerID, 1)
		returnTargetTable = attackTarget[1].params
		return returnTargetTable
	end
	local setTargetData = ggGetUnitTarget(attackerID) or {}
	--Spring.Echo("setTargetData type", type(setTargetData))
	if type(setTargetData) ~= "number" and setTargetData[1] then
		returnTargetTable = setTargetData
		return returnTargetTable
	end
	return {}
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitDefsWithSmartWeapons[unitDefID] then
		unitSuspendAutoAiming[unitID] = {
			unitDefID = unitDefID,
			preferredWeapon = unitDefsWithSmartWeapons[unitDefID].preferredWeapon,
			otherWeapon = unitDefsWithSmartWeapons[unitDefID].otherWeapon,
			overrideScriptID = Spring.GetCOBScriptID(unitID, "overrideAimingState")
		}
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	unitSuspendAutoAiming[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % frameCheckModulo == 3 then
		for attackerID in pairs(unitSuspendAutoAiming) do
			local targetData = manualCommandIssued(attackerID)
			weaponTargettingCheck(attackerID, targetData)
		end
	end
end