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
local ggGetUnitTargetIndex = GG.getUnitTargetIndex
local spGetUnitCommands = Spring.GetUnitCommands

--tables
local unitSuspendAutoAiming = {}
local unitDefsWithSmartWeapons = {}

for unitDefID, def in ipairs(UnitDefs) do
	if def.customParams.smart_weapon_select_priority then
		unitDefsWithSmartWeapons[unitDefID] = def.customParams.smart_weapon_select_priority
		for weaponNumber, weaponData in ipairs(def.weapons) do
			--Spring.Echo("smart_weapon_select_priority", def.name, weaponNumber, weaponData)
			Script.SetWatchWeapon(weaponData.weaponDef, true)
		end
	end
end

local function manualCommandIssued(attackerID)
	local firstCommand = spGetUnitCommands(attackerID, 1)
	if next(firstCommand) then
		if (firstCommand[1].id) == cmdAttack then
			--Spring.Echo("firstCommand", attackerID)
			return true
		end
	elseif ggGetUnitTargetIndex(attackerID) then
		--Spring.Echo("ggGetUnitTargetIndex", attackerID, ggGetUnitTargetIndex(attackerID))
		return true
	else
		return false
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitDefsWithSmartWeapons[unitDefID] then
		unitSuspendAutoAiming[unitID] = false
		--Spring.Echo("unit Added!", unitID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	unitSuspendAutoAiming[unitID] = nil
	--Spring.Echo("unit destroyed!", unitID)
end

function gadget:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
	if unitSuspendAutoAiming[attackerID] == true then
		--Spring.Echo("no autotarget!!", attackerID)
		return false, false
	else
		--Spring.Echo("yes autotarget!!", attackerID)
		return false, true
	end
end

function gadget:GameFrame(frame)
	if frame % frameCheckModulo == 3 then
		for attackerID in pairs(unitSuspendAutoAiming) do
			--Spring.Echo("gameFrame Check!!!", attackerID)
			if manualCommandIssued(attackerID) == true then
				unitSuspendAutoAiming[attackerID] = true
				--Spring.Echo("true")
			else
				unitSuspendAutoAiming[attackerID] = false
				--Spring.Echo("false")
			end
		end
	end
end