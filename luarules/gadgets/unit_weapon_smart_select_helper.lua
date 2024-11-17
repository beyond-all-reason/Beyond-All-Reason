function gadget:GetInfo()
	return {
		name = "Weapon Smart Select Helper",
		desc = "Prevents auto-target units from blocking manual command fire orders for lower priority weapons.",
		author = "SethDGamre",
		date = "2024.11.16",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

--use customparams.smart_weapon_select_priority to define which weapon number is preferred over the other(s) and enable auto-targetting override.

--tables
local smartWeaponsWatch = {}
local unitDefsWithSmartWeapons = {}

for unitDefID, def in ipairs(UnitDefs) do
	if def.customParams.smart_weapon_select_priority then
		smartWeaponsWatch[unitDefID] = def.customParams.smart_weapon_select_priority
		for weaponNumber, weaponData in ipairs(def.weapons) do
			Spring.Echo("smart_weapon_select_priority", weaponData.name, weaponNumber, weaponData)
			Script.SetWatchWeapon(weaponData.weaponDef, true)
		end
	end
end

-- function gadget:GameFrame(frame)
	
-- end

-- function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
-- 	Spring.Echo("AllowCommand", unitID, unitDefID, unitTeam, cmdID)
-- 	return true
-- end

function gadget:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
	Spring.Echo("AllowWeaponTargetCheck", attackerID, attackerWeaponNum, attackerWeaponDefID, Spring.GetGameFrame())
	return false, true
end